<#
.SYNOPSIS
    Builds everything into a single installer archive
#>

$ErrorActionPreference = "Stop"

Write-Host "`n  Building Outline Proxy Installer...`n" -ForegroundColor Cyan

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$distDir = Join-Path $scriptDir "dist"
$nativeHostDir = Join-Path $scriptDir "native-host"

# Create dist folder
if (Test-Path $distDir) { Remove-Item $distDir -Recurse -Force }
New-Item -ItemType Directory -Path $distDir | Out-Null

# 1. Build native host
Write-Host "  [1/4] Building native host..." -ForegroundColor Yellow
Push-Location $nativeHostDir
$env:CGO_ENABLED = "0"
go build -ldflags="-s -w" -o "outline-proxy-host.exe" .
Pop-Location
Copy-Item (Join-Path $nativeHostDir "outline-proxy-host.exe") $distDir

# 2. Download sslocal
Write-Host "  [2/4] Downloading sslocal..." -ForegroundColor Yellow
$ssVersion = "1.21.2"
$ssUrl = "https://github.com/shadowsocks/shadowsocks-rust/releases/download/v$ssVersion/shadowsocks-v$ssVersion.x86_64-pc-windows-msvc.zip"
$tempZip = Join-Path $env:TEMP "ss.zip"
$tempExtract = Join-Path $env:TEMP "ss-extract"

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Invoke-WebRequest -Uri $ssUrl -OutFile $tempZip -UseBasicParsing
Expand-Archive -Path $tempZip -DestinationPath $tempExtract -Force
Copy-Item (Join-Path $tempExtract "sslocal.exe") $distDir
Remove-Item $tempZip, $tempExtract -Recurse -Force

# 3. Copy extension
Write-Host "  [3/4] Copying extension..." -ForegroundColor Yellow
$extDist = Join-Path $distDir "extension"
Copy-Item (Join-Path $scriptDir "extension") $extDist -Recurse

# Generate icons if missing
$iconsDir = Join-Path $extDist "icons"
Add-Type -AssemblyName System.Drawing
@(16, 48, 128) | ForEach-Object {
    $size = $_
    $iconPath = Join-Path $iconsDir "icon$size.png"
    if (-not (Test-Path $iconPath)) {
        $bitmap = New-Object System.Drawing.Bitmap($size, $size)
        $g = [System.Drawing.Graphics]::FromImage($bitmap)
        $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
            (New-Object System.Drawing.Point(0,0)),
            (New-Object System.Drawing.Point($size,$size)),
            [System.Drawing.Color]::FromArgb(102,126,234),
            [System.Drawing.Color]::FromArgb(118,75,162)
        )
        $g.FillRectangle($brush, 0, 0, $size, $size)
        $bitmap.Save($iconPath)
        $g.Dispose(); $bitmap.Dispose(); $brush.Dispose()
    }
}

# 4. Create setup script
Write-Host "  [4/5] Creating setup script..." -ForegroundColor Yellow

$setupScript = @'
@echo off
setlocal enabledelayedexpansion
title Outline Proxy Installer
color 0B

echo.
echo   ====================================
echo      Outline Proxy - Quick Setup
echo   ====================================
echo.
echo   VPN for browser only.
echo   Games go direct, no lag.
echo.

:: Check admin
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo   [!] Requesting administrator rights...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

set "INSTALL_DIR=%LOCALAPPDATA%\OutlineProxy"
set "SCRIPT_DIR=%~dp0"

echo   [1/4] Installing files...
if not exist "%INSTALL_DIR%" mkdir "%INSTALL_DIR%"
copy /Y "%SCRIPT_DIR%outline-proxy-host.exe" "%INSTALL_DIR%\" >nul
copy /Y "%SCRIPT_DIR%sslocal.exe" "%INSTALL_DIR%\" >nul
echo         Done.

echo   [2/4] Opening Chrome to install extension...
echo.
echo   In Chrome:
echo   1. Enable "Developer mode" (top right)
echo   2. Click "Load unpacked"
echo   3. Select: %SCRIPT_DIR%extension
echo.
start "" "chrome" "chrome://extensions"

echo   After loading the extension, copy the Extension ID
echo   (shown under the extension name).
echo.
set /p EXT_ID="   Paste Extension ID here: "

echo.
echo   [3/4] Registering native host...

:: Create manifest with actual extension ID
(
echo {
echo   "name": "com.outline.proxy",
echo   "description": "Outline Proxy Native Host",
echo   "path": "%INSTALL_DIR:\=\\%\\outline-proxy-host.exe",
echo   "type": "stdio",
echo   "allowed_origins": ["chrome-extension://%EXT_ID%/"]
echo }
) > "%INSTALL_DIR%\com.outline.proxy.json"

:: Register
reg add "HKCU\Software\Google\Chrome\NativeMessagingHosts\com.outline.proxy" /ve /t REG_SZ /d "%INSTALL_DIR%\com.outline.proxy.json" /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Edge\NativeMessagingHosts\com.outline.proxy" /ve /t REG_SZ /d "%INSTALL_DIR%\com.outline.proxy.json" /f >nul 2>&1
echo         Done.

echo   [4/4] Restarting Chrome...
taskkill /F /IM chrome.exe >nul 2>&1
timeout /t 2 >nul
start "" "chrome" "chrome://extensions"

echo.
echo   ====================================
echo      Installation Complete!
echo   ====================================
echo.
echo   Chrome has been restarted.
echo   Now click on the extension icon,
echo   paste your ss:// key and connect!
echo.

pause
'@

$setupScript | Set-Content (Join-Path $distDir "setup.bat") -Encoding ASCII

# 5. Create uninstall script
Write-Host "  [5/5] Creating uninstall script..." -ForegroundColor Yellow

$uninstallScript = @'
@echo off
title Outline Proxy Uninstaller
color 0C

echo.
echo   ====================================
echo      Outline Proxy - Uninstall
echo   ====================================
echo.

:: Check admin
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo   [!] Requesting administrator rights...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

set "INSTALL_DIR=%LOCALAPPDATA%\OutlineProxy"

echo   [1/2] Removing files...
if exist "%INSTALL_DIR%" (
    rmdir /S /Q "%INSTALL_DIR%"
    echo         Done.
) else (
    echo         Already removed.
)

echo   [2/2] Removing registry entries...
reg delete "HKCU\Software\Google\Chrome\NativeMessagingHosts\com.outline.proxy" /f >nul 2>&1
reg delete "HKCU\Software\Microsoft\Edge\NativeMessagingHosts\com.outline.proxy" /f >nul 2>&1
echo         Done.

echo.
echo   ====================================
echo      Uninstall Complete!
echo   ====================================
echo.
echo   Don't forget to remove the extension
echo   from chrome://extensions
echo.

pause
'@

$uninstallScript | Set-Content (Join-Path $distDir "uninstall.bat") -Encoding ASCII

# Create ZIP
Write-Host "`n  Creating ZIP archive..." -ForegroundColor Yellow
$zipPath = Join-Path $scriptDir "OutlineProxy-Windows.zip"
if (Test-Path $zipPath) { Remove-Item $zipPath }
Compress-Archive -Path "$distDir\*" -DestinationPath $zipPath

Write-Host "`n  ========================================" -ForegroundColor Green
Write-Host "       Build Complete!" -ForegroundColor Green
Write-Host "  ========================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Output: " -NoNewline
Write-Host "OutlineProxy-Windows.zip" -ForegroundColor Cyan
Write-Host ""
Write-Host "  User experience:" -ForegroundColor Yellow
Write-Host "  1. Download ZIP"
Write-Host "  2. Extract anywhere"
Write-Host "  3. Run setup.bat"
Write-Host "  4. Load extension in Chrome"
Write-Host "  5. Paste ss:// key and connect!"
Write-Host ""
