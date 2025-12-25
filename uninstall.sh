#!/bin/bash

#
# Outline Proxy - Uninstaller for Linux/macOS
#

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
MAGENTA='\033[0;35m'
GRAY='\033[0;90m'
NC='\033[0m'

step() { echo -e "\n${CYAN}$1${NC}"; }
ok() { echo -e "  ${GREEN}[OK]${NC} $1"; }
skip() { echo -e "  ${GRAY}[SKIP]${NC} $1"; }

echo -e "\n  ${MAGENTA}Outline Proxy - Uninstaller${NC}\n"

# Detect OS
OS="$(uname -s)"
case "$OS" in
    Linux*)  PLATFORM="linux";;
    Darwin*) PLATFORM="macos";;
    *)       echo -e "${RED}Unsupported OS${NC}"; exit 1;;
esac

# Set paths
if [ "$PLATFORM" = "linux" ]; then
    INSTALL_DIR="$HOME/.local/share/outline-proxy"
    CHROME_MANIFEST="$HOME/.config/google-chrome/NativeMessagingHosts/com.outline.proxy.json"
    CHROMIUM_MANIFEST="$HOME/.config/chromium/NativeMessagingHosts/com.outline.proxy.json"
    BRAVE_MANIFEST="$HOME/.config/BraveSoftware/Brave-Browser/NativeMessagingHosts/com.outline.proxy.json"
else
    INSTALL_DIR="$HOME/Library/Application Support/OutlineProxy"
    CHROME_MANIFEST="$HOME/Library/Application Support/Google/Chrome/NativeMessagingHosts/com.outline.proxy.json"
    CHROMIUM_MANIFEST="$HOME/Library/Application Support/Chromium/NativeMessagingHosts/com.outline.proxy.json"
    BRAVE_MANIFEST="$HOME/Library/Application Support/BraveSoftware/Brave-Browser/NativeMessagingHosts/com.outline.proxy.json"
fi

# ============================================
# Remove installed files
# ============================================
step "Removing installed files..."

if [ -d "$INSTALL_DIR" ]; then
    rm -rf "$INSTALL_DIR"
    ok "Removed $INSTALL_DIR"
else
    skip "Directory not found"
fi

# ============================================
# Remove manifest symlinks
# ============================================
step "Removing browser registrations..."

if [ -f "$CHROME_MANIFEST" ] || [ -L "$CHROME_MANIFEST" ]; then
    rm -f "$CHROME_MANIFEST"
    ok "Removed Chrome registration"
else
    skip "Chrome manifest not found"
fi

if [ -f "$CHROMIUM_MANIFEST" ] || [ -L "$CHROMIUM_MANIFEST" ]; then
    rm -f "$CHROMIUM_MANIFEST"
    ok "Removed Chromium registration"
else
    skip "Chromium manifest not found"
fi

if [ -f "$BRAVE_MANIFEST" ] || [ -L "$BRAVE_MANIFEST" ]; then
    rm -f "$BRAVE_MANIFEST"
    ok "Removed Brave registration"
else
    skip "Brave manifest not found"
fi

# ============================================
# Done
# ============================================
echo ""
echo -e "  ${GREEN}========================================${NC}"
echo -e "  ${GREEN}     Uninstall Complete!${NC}"
echo -e "  ${GREEN}========================================${NC}"
echo ""
echo -e "  ${YELLOW}Don't forget to remove the extension from:${NC}"
echo -e "  ${CYAN}chrome://extensions${NC}"
echo ""
