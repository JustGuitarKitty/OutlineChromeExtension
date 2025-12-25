# Outline Proxy - Chrome Extension

Chrome extension for connecting to Outline VPN servers. Fully open source — built from source.

## Installation

### Windows

1. [Download ZIP](../../archive/refs/heads/main.zip) and extract
2. Open PowerShell in the extracted folder (where `install.ps1` is located)
3. Run `powershell -ExecutionPolicy Bypass -File .\install.ps1`

The script will automatically:
- Request administrator privileges
- Download and build the native host
- Download sslocal (shadowsocks-rust)
- Register the native messaging host

After running:
1. Chrome → `chrome://extensions` → Developer mode → Load unpacked → select `extension` folder
2. Copy Extension ID (shown at the bottom of the extension card) and enter when the script asks

### Linux / macOS

1. [Download ZIP](../../archive/refs/heads/main.zip) and extract
2. Open terminal in the project folder
3. Run `sh ./install.sh`

### Uninstall

```bash
# Windows
powershell -ExecutionPolicy Bypass -File .\uninstall.ps1

# Linux/macOS
sh ./uninstall.sh
```

---

## Requirements

- **Windows:** PowerShell 5.1+, Go 1.21+
- **Linux/macOS:** bash, Go 1.21+, curl
- Chrome, Edge or Brave
- Outline Access Key (`ss://...`)

---

## How it works

```
Chrome Extension
      │
      ▼ (Native Messaging)
Native Host + sslocal
      │
      ▼ (Shadowsocks)
Outline VPN Server
```

The extension uses Native Messaging to communicate with a local host that runs sslocal (shadowsocks-rust) and proxies traffic through the Outline server.

## License

MIT
