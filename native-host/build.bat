@echo off
echo Building Outline Proxy Native Host...
echo.

cd /d "%~dp0"

:: Check if Go is installed
where go >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Go is not installed. Please install Go from https://go.dev
    pause
    exit /b 1
)

echo Downloading dependencies...
go mod tidy

echo.
echo Building for Windows amd64...
set GOOS=windows
set GOARCH=amd64
go build -ldflags="-s -w" -o outline-proxy-host.exe .

if %errorlevel% neq 0 (
    echo [ERROR] Build failed!
    pause
    exit /b 1
)

echo.
echo Build successful!
echo Output: outline-proxy-host.exe
echo.
pause
