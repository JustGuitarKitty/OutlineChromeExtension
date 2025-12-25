package main

import (
	"encoding/binary"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"sync"
)

// Message types for Chrome Native Messaging
type Message struct {
	Type   string  `json:"type"`
	Config *Config `json:"config,omitempty"`
	Error  string  `json:"error,omitempty"`
}

type Config struct {
	Server     string `json:"server"`
	ServerPort int    `json:"serverPort"`
	LocalPort  int    `json:"localPort"`
	Method     string `json:"method"`
	Password   string `json:"password"`
}

var (
	ssProcess *exec.Cmd
	ssLock    sync.Mutex
	logFile   *os.File
)

func init() {
	// Setup logging
	logPath := filepath.Join(os.TempDir(), "outline-proxy.log")
	var err error
	logFile, err = os.OpenFile(logPath, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0644)
	if err == nil {
		log.SetOutput(logFile)
	}
}

func main() {
	log.Println("Outline Proxy Native Host started")

	// Send ready message
	sendMessage(Message{Type: "READY"})

	// Read messages from Chrome
	for {
		msg, err := readMessage()
		if err != nil {
			if err == io.EOF {
				log.Println("Chrome disconnected")
				break
			}
			log.Printf("Error reading message: %v", err)
			continue
		}

		log.Printf("Received message: %s", msg.Type)
		handleMessage(msg)
	}

	// Cleanup
	stopSS()

	if logFile != nil {
		logFile.Close()
	}
}

func readMessage() (*Message, error) {
	// Native messaging protocol: 4-byte length prefix (little endian) + JSON
	var length uint32
	if err := binary.Read(os.Stdin, binary.LittleEndian, &length); err != nil {
		return nil, err
	}

	if length > 1024*1024 {
		return nil, fmt.Errorf("message too large: %d", length)
	}

	data := make([]byte, length)
	if _, err := io.ReadFull(os.Stdin, data); err != nil {
		return nil, err
	}

	var msg Message
	if err := json.Unmarshal(data, &msg); err != nil {
		return nil, err
	}

	return &msg, nil
}

func sendMessage(msg Message) {
	data, err := json.Marshal(msg)
	if err != nil {
		log.Printf("Error marshaling message: %v", err)
		return
	}

	length := uint32(len(data))
	if err := binary.Write(os.Stdout, binary.LittleEndian, length); err != nil {
		log.Printf("Error writing length: %v", err)
		return
	}

	if _, err := os.Stdout.Write(data); err != nil {
		log.Printf("Error writing data: %v", err)
	}
}

func handleMessage(msg *Message) {
	switch msg.Type {
	case "START":
		if msg.Config == nil {
			sendMessage(Message{Type: "ERROR", Error: "Missing config"})
			return
		}
		startSS(msg.Config)

	case "STOP":
		stopSS()
		sendMessage(Message{Type: "DISCONNECTED"})

	case "STATUS":
		ssLock.Lock()
		running := ssProcess != nil && ssProcess.Process != nil
		ssLock.Unlock()

		if running {
			sendMessage(Message{Type: "CONNECTED"})
		} else {
			sendMessage(Message{Type: "DISCONNECTED"})
		}

	default:
		sendMessage(Message{Type: "ERROR", Error: "Unknown message type"})
	}
}

func getSSLocalPath() string {
	// Look for sslocal in same directory as this executable
	exePath, err := os.Executable()
	if err != nil {
		return ""
	}

	dir := filepath.Dir(exePath)

	var name string
	if runtime.GOOS == "windows" {
		name = "sslocal.exe"
	} else {
		name = "sslocal"
	}

	path := filepath.Join(dir, name)
	if _, err := os.Stat(path); err == nil {
		return path
	}

	// Also check current directory
	if _, err := os.Stat(name); err == nil {
		return name
	}

	return ""
}

func startSS(config *Config) {
	ssLock.Lock()
	defer ssLock.Unlock()

	// Stop existing process
	if ssProcess != nil && ssProcess.Process != nil {
		ssProcess.Process.Kill()
		ssProcess.Wait()
		ssProcess = nil
	}

	ssPath := getSSLocalPath()
	if ssPath == "" {
		log.Println("sslocal not found")
		sendMessage(Message{Type: "ERROR", Error: "sslocal not found. Please run the installer."})
		return
	}

	log.Printf("Starting sslocal: %s", ssPath)

	// Build sslocal command
	// sslocal -s server:port -k password -m method -l local_port --protocol socks
	serverAddr := fmt.Sprintf("%s:%d", config.Server, config.ServerPort)
	localAddr := fmt.Sprintf("127.0.0.1:%d", config.LocalPort)

	args := []string{
		"-s", serverAddr,
		"-k", config.Password,
		"-m", config.Method,
		"-b", localAddr,
		"--protocol", "socks",
	}

	log.Printf("sslocal args: %v", args)

	ssProcess = exec.Command(ssPath, args...)

	// Redirect output to log
	ssProcess.Stdout = logFile
	ssProcess.Stderr = logFile

	if err := ssProcess.Start(); err != nil {
		log.Printf("Failed to start sslocal: %v", err)
		sendMessage(Message{Type: "ERROR", Error: fmt.Sprintf("Failed to start: %v", err)})
		ssProcess = nil
		return
	}

	log.Printf("sslocal started with PID %d", ssProcess.Process.Pid)

	// Monitor process in background
	go func() {
		err := ssProcess.Wait()
		log.Printf("sslocal exited: %v", err)
		ssLock.Lock()
		ssProcess = nil
		ssLock.Unlock()
	}()

	sendMessage(Message{Type: "CONNECTED"})
}

func stopSS() {
	ssLock.Lock()
	defer ssLock.Unlock()

	if ssProcess != nil && ssProcess.Process != nil {
		log.Println("Stopping sslocal...")
		ssProcess.Process.Kill()
		ssProcess.Wait()
		ssProcess = nil
		log.Println("sslocal stopped")
	}
}
