<#
.SYNOPSIS
    Outline Proxy - One-click installer
.DESCRIPTION
    Installs Chrome extension for browser VPN.
#>

# Self-elevation: request admin rights automatically
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe "-NoExit -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# Colors
function Write-Step { param($msg) Write-Host "`n[$((Get-Date).ToString('HH:mm:ss'))] " -NoNewline -ForegroundColor DarkGray; Write-Host $msg -ForegroundColor Cyan }
function Write-OK { param($msg) Write-Host "  [OK] $msg" -ForegroundColor Green }
function Write-Err { param($msg) Write-Host "  [ERROR] $msg" -ForegroundColor Red }
function Write-Info { param($msg) Write-Host "  $msg" -ForegroundColor Gray }

$banner = @"

   ____        _   _ _              ____
  / __ \      | | | (_)            |  _ \
 | |  | |_   _| |_| |_ _ __   ___  | |_) |_ __ _____  ___   _
 | |  | | | | | __| | | '_ \ / _ \ |  __/| '__/ _ \ \/ / | | |
 | |__| | |_| | |_| | | | | |  __/ | |   | | | (_) >  <| |_| |
  \____/ \__,_|\__|_|_|_| |_|\___| |_|   |_|  \___/_/\_\\__, |
                                                         __/ |
                                                        |___/

"@

Write-Host $banner -ForegroundColor Magenta

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$extensionDir = Join-Path $scriptDir "extension"
$nativeHostDir = Join-Path $scriptDir "native-host"
$installDir = "$env:LOCALAPPDATA\OutlineProxy"
$hostExeName = "outline-proxy-host.exe"
$ssLocalExeName = "sslocal.exe"
$manifestName = "com.outline.proxy.json"

# Shadowsocks-rust release
$ssRustVersion = "1.21.2"
$ssRustUrl = "https://github.com/shadowsocks/shadowsocks-rust/releases/download/v$ssRustVersion/shadowsocks-v$ssRustVersion.x86_64-pc-windows-msvc.zip"

# ============================================
# Step 1: Check/Install Go
# ============================================
Write-Step "Checking Go installation..."

$goInstalled = $null -ne (Get-Command go -ErrorAction SilentlyContinue)

if (-not $goInstalled) {
    Write-Info "Go not found. Installing via winget..."

    try {
        winget install GoLang.Go --silent --accept-package-agreements --accept-source-agreements
        # Refresh PATH
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
        Write-OK "Go installed"
    } catch {
        Write-Err "Failed to install Go automatically"
        Write-Info "Please install Go manually from https://go.dev/dl/"
        Read-Host "Press Enter to exit"
        exit 1
    }
} else {
    $goVersion = (go version) -replace "go version ", ""
    Write-OK "Go found: $goVersion"
}

# ============================================
# Step 2: Download shadowsocks-rust
# ============================================
Write-Step "Downloading shadowsocks-rust v$ssRustVersion..."

$tempDir = Join-Path $env:TEMP "outline-proxy-install"
$zipPath = Join-Path $tempDir "shadowsocks.zip"

if (-not (Test-Path $tempDir)) {
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
}

try {
    Write-Info "Downloading from GitHub..."
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $ssRustUrl -OutFile $zipPath -UseBasicParsing

    Write-Info "Extracting..."
    Expand-Archive -Path $zipPath -DestinationPath $tempDir -Force

    Write-OK "Downloaded sslocal.exe"
} catch {
    Write-Err "Failed to download shadowsocks-rust: $_"
    Write-Info "Please check your internet connection"
    Read-Host "Press Enter to exit"
    exit 1
}

# ============================================
# Step 3: Build Native Host
# ============================================
Write-Step "Building native host..."

Push-Location $nativeHostDir
try {
    Write-Info "Compiling..."
    $env:CGO_ENABLED = "0"
    $buildOutput = go build -ldflags="-s -w" -o $hostExeName . 2>&1

    if (-not (Test-Path $hostExeName)) {
        throw "Build failed: $buildOutput"
    }

    $size = [math]::Round((Get-Item $hostExeName).Length / 1KB, 1)
    Write-OK "Built successfully ($size KB)"
} catch {
    Write-Err "Build failed: $_"
    Pop-Location
    Read-Host "Press Enter to exit"
    exit 1
}
Pop-Location

# ============================================
# Step 4: Install files
# ============================================
Write-Step "Installing to $installDir..."

# Kill running processes
$killed = $false
Get-Process -Name "sslocal" -ErrorAction SilentlyContinue | Stop-Process -Force
if ($?) { $killed = $true }
Get-Process -Name "outline-proxy-host" -ErrorAction SilentlyContinue | Stop-Process -Force
if ($?) { $killed = $true }
if ($killed) { Write-OK "Stopped running processes" }

# Create install directory
if (-not (Test-Path $installDir)) {
    New-Item -ItemType Directory -Path $installDir -Force | Out-Null
}

# Copy native host
Copy-Item (Join-Path $nativeHostDir $hostExeName) $installDir -Force
Write-OK "Copied $hostExeName"

# Copy sslocal
$ssLocalPath = Join-Path $tempDir $ssLocalExeName
if (Test-Path $ssLocalPath) {
    Copy-Item $ssLocalPath $installDir -Force
    Write-OK "Copied $ssLocalExeName"
} else {
    Write-Err "sslocal.exe not found in archive"
}

# Cleanup temp
Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue

# ============================================
# Step 5: Generate Icons
# ============================================
Write-Step "Generating icons..."

$iconsDir = Join-Path $extensionDir "icons"

Add-Type -AssemblyName System.Drawing

$sizes = @(16, 48, 128)

foreach ($size in $sizes) {
    $bitmap = New-Object System.Drawing.Bitmap($size, $size)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic

    # Background gradient
    $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
        (New-Object System.Drawing.Point(0, 0)),
        (New-Object System.Drawing.Point($size, $size)),
        [System.Drawing.Color]::FromArgb(102, 126, 234),
        [System.Drawing.Color]::FromArgb(118, 75, 162)
    )

    # Rounded rectangle
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $radius = [int]($size * 0.1875)
    $rect = New-Object System.Drawing.Rectangle(0, 0, $size, $size)
    $path.AddArc($rect.X, $rect.Y, $radius * 2, $radius * 2, 180, 90)
    $path.AddArc($rect.Right - $radius * 2, $rect.Y, $radius * 2, $radius * 2, 270, 90)
    $path.AddArc($rect.Right - $radius * 2, $rect.Bottom - $radius * 2, $radius * 2, $radius * 2, 0, 90)
    $path.AddArc($rect.X, $rect.Bottom - $radius * 2, $radius * 2, $radius * 2, 90, 90)
    $path.CloseFigure()
    $graphics.FillPath($brush, $path)

    # Circle
    $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::White, [int][Math]::Max(1, $size * 0.047))
    $circleSize = [int]($size * 0.5)
    $circleOffset = [int](($size - $circleSize) / 2)
    $graphics.DrawEllipse($pen, $circleOffset, $circleOffset, $circleSize, $circleSize)

    # Center dot
    $dotSize = [int]($size * 0.1875)
    $dotOffset = [int](($size - $dotSize) / 2)
    $whiteBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
    $graphics.FillEllipse($whiteBrush, $dotOffset, $dotOffset, $dotSize, $dotSize)

    # Save
    $iconPath = Join-Path $iconsDir "icon$size.png"
    $bitmap.Save($iconPath, [System.Drawing.Imaging.ImageFormat]::Png)

    $graphics.Dispose()
    $bitmap.Dispose()
    $brush.Dispose()
    $pen.Dispose()
    $whiteBrush.Dispose()
}

Write-OK "Icons generated (16, 48, 128 px)"

# ============================================
# Step 6: Register Native Messaging Host
# ============================================
Write-Step "Registering native messaging host..."

$manifest = @{
    name = "com.outline.proxy"
    description = "Outline Proxy Native Host"
    path = (Join-Path $installDir $hostExeName)
    type = "stdio"
    allowed_origins = @("chrome-extension://*/")
}

$manifestPath = Join-Path $installDir $manifestName
$manifest | ConvertTo-Json -Depth 10 | Set-Content $manifestPath -Encoding UTF8

# Register for Chrome
$chromeKey = "HKCU:\Software\Google\Chrome\NativeMessagingHosts\com.outline.proxy"
if (-not (Test-Path (Split-Path $chromeKey))) {
    New-Item -Path (Split-Path $chromeKey) -Force | Out-Null
}
New-Item -Path $chromeKey -Force | Out-Null
Set-ItemProperty -Path $chromeKey -Name "(Default)" -Value $manifestPath
Write-OK "Registered for Chrome"

# Register for Edge
$edgeKey = "HKCU:\Software\Microsoft\Edge\NativeMessagingHosts\com.outline.proxy"
try {
    if (-not (Test-Path (Split-Path $edgeKey))) {
        New-Item -Path (Split-Path $edgeKey) -Force | Out-Null
    }
    New-Item -Path $edgeKey -Force | Out-Null
    Set-ItemProperty -Path $edgeKey -Name "(Default)" -Value $manifestPath
    Write-OK "Registered for Edge"
} catch {
    Write-Info "Edge registration skipped"
}

# ============================================
# Step 7: Install extension and get ID
# ============================================
Write-Host "`n"
Write-Host "  ========================================" -ForegroundColor Green
Write-Host "       Files installed!" -ForegroundColor Green
Write-Host "  ========================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Now install the extension:" -ForegroundColor Yellow
Write-Host ""
Write-Host "  1. Chrome will open chrome://extensions" -ForegroundColor White
Write-Host "  2. Enable 'Developer mode' (top right)" -ForegroundColor White
Write-Host "  3. Click 'Load unpacked' and select:" -ForegroundColor White
Write-Host "     $extensionDir" -ForegroundColor Cyan
Write-Host "  4. Copy the Extension ID (shown below extension name)" -ForegroundColor White
Write-Host ""

Read-Host "Press Enter to open Chrome"
Start-Process "chrome://extensions"

Write-Host ""
$extensionId = Read-Host "Paste Extension ID here"

if ($extensionId -match "^[a-z]{32}$") {
    # Update manifest with correct extension ID
    $manifest = @{
        name = "com.outline.proxy"
        description = "Outline Proxy Native Host"
        path = (Join-Path $installDir $hostExeName)
        type = "stdio"
        allowed_origins = @("chrome-extension://$extensionId/")
    }
    $manifest | ConvertTo-Json -Depth 10 | Set-Content $manifestPath -Encoding UTF8
    Write-OK "Extension ID registered: $extensionId"

    Write-Host "`n"
    Write-Host "  ========================================" -ForegroundColor Green
    Write-Host "       Installation Complete!" -ForegroundColor Green
    Write-Host "  ========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Restart Chrome, then paste your" -ForegroundColor White
    Write-Host "  Outline key (ss://...) and connect!" -ForegroundColor White
} else {
    Write-Err "Invalid Extension ID format"
    Write-Host "  You can add it manually later to:" -ForegroundColor Yellow
    Write-Host "  $manifestPath" -ForegroundColor Cyan
}

Write-Host "`nDone!" -ForegroundColor Magenta
