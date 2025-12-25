#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Outline Proxy - Uninstaller
#>

$ErrorActionPreference = "SilentlyContinue"

function Write-Step { param($msg) Write-Host "`n" -NoNewline; Write-Host $msg -ForegroundColor Cyan }
function Write-OK { param($msg) Write-Host "  [OK] $msg" -ForegroundColor Green }
function Write-Skip { param($msg) Write-Host "  [SKIP] $msg" -ForegroundColor Gray }

Write-Host "`n  Outline Proxy - Uninstaller`n" -ForegroundColor Magenta

$installDir = "$env:LOCALAPPDATA\OutlineProxy"

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

Write-Host "  Don't forget to remove the extension from:" -ForegroundColor Yellow
Write-Host "  chrome://extensions`n" -ForegroundColor Cyan
