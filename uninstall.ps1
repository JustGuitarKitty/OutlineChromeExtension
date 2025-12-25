<#
.SYNOPSIS
    Outline Proxy - Uninstaller
#>

# Self-elevation: request admin rights automatically
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe "-NoExit -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

$ErrorActionPreference = "SilentlyContinue"

function Write-Step { param($msg) Write-Host "`n" -NoNewline; Write-Host $msg -ForegroundColor Cyan }
function Write-OK { param($msg) Write-Host "  [OK] $msg" -ForegroundColor Green }
function Write-Skip { param($msg) Write-Host "  [SKIP] $msg" -ForegroundColor Gray }

Write-Host "`n  Outline Proxy - Uninstaller`n" -ForegroundColor Magenta

$installDir = "$env:LOCALAPPDATA\OutlineProxy"

# ============================================
# Stop running processes
# ============================================
Write-Step "Stopping running processes..."

$killed = $false
Get-Process -Name "sslocal" -ErrorAction SilentlyContinue | Stop-Process -Force
if ($?) { $killed = $true; Write-OK "Stopped sslocal" }
Get-Process -Name "outline-proxy-host" -ErrorAction SilentlyContinue | Stop-Process -Force
if ($?) { $killed = $true; Write-OK "Stopped outline-proxy-host" }
if (-not $killed) { Write-Skip "No processes running" }

# ============================================
# Remove installed files
# ============================================
Write-Step "Removing installed files..."

if (Test-Path $installDir) {
    Remove-Item $installDir -Recurse -Force
    Write-OK "Removed $installDir"
} else {
    Write-Skip "Directory not found"
}

# ============================================
# Remove registry entries
# ============================================
Write-Step "Removing registry entries..."

$chromeKey = "HKCU:\Software\Google\Chrome\NativeMessagingHosts\com.outline.proxy"
if (Test-Path $chromeKey) {
    Remove-Item $chromeKey -Force
    Write-OK "Removed Chrome registration"
} else {
    Write-Skip "Chrome key not found"
}

$edgeKey = "HKCU:\Software\Microsoft\Edge\NativeMessagingHosts\com.outline.proxy"
if (Test-Path $edgeKey) {
    Remove-Item $edgeKey -Force
    Write-OK "Removed Edge registration"
} else {
    Write-Skip "Edge key not found"
}

# ============================================
# Done
# ============================================
Write-Host "`n  ========================================" -ForegroundColor Green
Write-Host "       Uninstall Complete!" -ForegroundColor Green
Write-Host "  ========================================`n" -ForegroundColor Green

Write-Host "  Remove the extension manually from the opened page" -ForegroundColor Yellow
Write-Host ""

Start-Process "chrome://extensions"
