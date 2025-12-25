#!/bin/bash

#
# Outline Proxy - One-click installer for Linux/macOS
# VPN for browser only. Games go direct.
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
MAGENTA='\033[0;35m'
GRAY='\033[0;90m'
NC='\033[0m'

step() { echo -e "\n${GRAY}[$(date +%H:%M:%S)]${NC} ${CYAN}$1${NC}"; }
ok() { echo -e "  ${GREEN}[OK]${NC} $1"; }
err() { echo -e "  ${RED}[ERROR]${NC} $1"; }
info() { echo -e "  ${GRAY}$1${NC}"; }

cat << 'EOF'

   ____        _   _ _              ____
  / __ \      | | | (_)            |  _ \
 | |  | |_   _| |_| |_ _ __   ___  | |_) |_ __ _____  ___   _
 | |  | | | | | __| | | '_ \ / _ \ |  __/| '__/ _ \ \/ / | | |
 | |__| | |_| | |_| | | | | |  __/ | |   | | | (_) >  <| |_| |
  \____/ \__,_|\__|_|_|_| |_|\___| |_|   |_|  \___/_/\_\\__, |
                                                         __/ |
   VPN for browser only. Games go direct.               |___/

EOF

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
EXTENSION_DIR="$SCRIPT_DIR/extension"
NATIVE_HOST_DIR="$SCRIPT_DIR/native-host"
HOST_EXE_NAME="outline-proxy-host"
SS_LOCAL_NAME="sslocal"
MANIFEST_NAME="com.outline.proxy.json"

# Shadowsocks-rust version
SS_RUST_VERSION="1.21.2"

# Detect OS and architecture
OS="$(uname -s)"
ARCH="$(uname -m)"

case "$OS" in
    Linux*)  PLATFORM="linux";;
    Darwin*) PLATFORM="macos";;
    *)       echo -e "${RED}Unsupported OS: $OS${NC}"; exit 1;;
esac

case "$ARCH" in
    x86_64)  ARCH_NAME="x86_64";;
    aarch64) ARCH_NAME="aarch64";;
    arm64)   ARCH_NAME="aarch64";;
    *)       echo -e "${RED}Unsupported architecture: $ARCH${NC}"; exit 1;;
esac

# Build download URL
if [ "$PLATFORM" = "linux" ]; then
    SS_RUST_URL="https://github.com/shadowsocks/shadowsocks-rust/releases/download/v${SS_RUST_VERSION}/shadowsocks-v${SS_RUST_VERSION}.${ARCH_NAME}-unknown-linux-gnu.tar.xz"
else
    SS_RUST_URL="https://github.com/shadowsocks/shadowsocks-rust/releases/download/v${SS_RUST_VERSION}/shadowsocks-v${SS_RUST_VERSION}.${ARCH_NAME}-apple-darwin.zip"
fi

# Set paths based on platform
if [ "$PLATFORM" = "linux" ]; then
    INSTALL_DIR="$HOME/.local/share/outline-proxy"
    CHROME_MANIFEST_DIR="$HOME/.config/google-chrome/NativeMessagingHosts"
    CHROMIUM_MANIFEST_DIR="$HOME/.config/chromium/NativeMessagingHosts"
    BRAVE_MANIFEST_DIR="$HOME/.config/BraveSoftware/Brave-Browser/NativeMessagingHosts"
else
    INSTALL_DIR="$HOME/Library/Application Support/OutlineProxy"
    CHROME_MANIFEST_DIR="$HOME/Library/Application Support/Google/Chrome/NativeMessagingHosts"
    CHROMIUM_MANIFEST_DIR="$HOME/Library/Application Support/Chromium/NativeMessagingHosts"
    BRAVE_MANIFEST_DIR="$HOME/Library/Application Support/BraveSoftware/Brave-Browser/NativeMessagingHosts"
fi

echo -e "Platform: ${CYAN}$PLATFORM ($ARCH_NAME)${NC}"

# ============================================
# Step 1: Check/Install Go
# ============================================
step "Checking Go installation..."

if ! command -v go &> /dev/null; then
    info "Go not found. Installing..."

    if [ "$PLATFORM" = "linux" ]; then
        if command -v apt &> /dev/null; then
            sudo apt update && sudo apt install -y golang-go
        elif command -v dnf &> /dev/null; then
            sudo dnf install -y golang
        elif command -v pacman &> /dev/null; then
            sudo pacman -S --noconfirm go
        elif command -v brew &> /dev/null; then
            brew install go
        else
            err "Could not install Go automatically"
            info "Please install Go manually: https://go.dev/dl/"
            exit 1
        fi
    else
        if command -v brew &> /dev/null; then
            brew install go
        else
            err "Please install Homebrew first: https://brew.sh"
            exit 1
        fi
    fi
    ok "Go installed"
else
    GO_VERSION=$(go version | cut -d' ' -f3)
    ok "Go found: $GO_VERSION"
fi

# ============================================
# Step 2: Download shadowsocks-rust
# ============================================
step "Downloading shadowsocks-rust v$SS_RUST_VERSION..."

TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

info "Downloading from GitHub..."
if [ "$PLATFORM" = "linux" ]; then
    curl -sL "$SS_RUST_URL" -o "$TEMP_DIR/ss.tar.xz"
    info "Extracting..."
    tar -xf "$TEMP_DIR/ss.tar.xz" -C "$TEMP_DIR"
else
    curl -sL "$SS_RUST_URL" -o "$TEMP_DIR/ss.zip"
    info "Extracting..."
    unzip -q "$TEMP_DIR/ss.zip" -d "$TEMP_DIR"
fi

if [ ! -f "$TEMP_DIR/sslocal" ]; then
    err "sslocal not found in archive"
    exit 1
fi

ok "Downloaded sslocal"

# ============================================
# Step 3: Build Native Host
# ============================================
step "Building native host..."

cd "$NATIVE_HOST_DIR"

info "Compiling..."
CGO_ENABLED=0 go build -ldflags="-s -w" -o "$HOST_EXE_NAME" .

if [ ! -f "$HOST_EXE_NAME" ]; then
    err "Build failed - executable not created"
    exit 1
fi

SIZE=$(du -h "$HOST_EXE_NAME" | cut -f1)
ok "Built successfully ($SIZE)"

cd "$SCRIPT_DIR"

# ============================================
# Step 4: Install files
# ============================================
step "Installing to $INSTALL_DIR..."

mkdir -p "$INSTALL_DIR"

cp "$NATIVE_HOST_DIR/$HOST_EXE_NAME" "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/$HOST_EXE_NAME"
ok "Copied $HOST_EXE_NAME"

cp "$TEMP_DIR/sslocal" "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/sslocal"
ok "Copied sslocal"

# ============================================
# Step 5: Generate Icons
# ============================================
step "Generating icons..."

ICONS_DIR="$EXTENSION_DIR/icons"
mkdir -p "$ICONS_DIR"

if command -v convert &> /dev/null; then
    for size in 16 48 128; do
        convert -background none -resize ${size}x${size} "$ICONS_DIR/icon.svg" "$ICONS_DIR/icon${size}.png" 2>/dev/null || true
    done
    ok "Icons generated via ImageMagick"
elif command -v rsvg-convert &> /dev/null; then
    for size in 16 48 128; do
        rsvg-convert -w $size -h $size "$ICONS_DIR/icon.svg" -o "$ICONS_DIR/icon${size}.png" 2>/dev/null || true
    done
    ok "Icons generated via rsvg-convert"
else
    info "Creating placeholder icons..."
    # Minimal purple PNGs
    echo "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAOklEQVQ4y2NgoAH4z8DA8J8YNUxkaFZl+M9AjGZGBgYGRnI1M5GimZGBgYGJFM2MpGhmJEUzMWoAACILBgE5EuyjAAAAAElFTkSuQmCC" | base64 -d > "$ICONS_DIR/icon16.png"
    echo "iVBORw0KGgoAAAANSUhEUgAAADAAAAAwCAYAAABXAvmHAAAASElEQVRo3u3OQQ0AAAgDsOFfNHqABcLMaS+00p4uAQQIECBAgAABAgQIECBAgAABAgQIECBAgAABAgQIECBAgAABAgQI/AosPBcwATOSR+wAAAAASUVORK5CYII=" | base64 -d > "$ICONS_DIR/icon48.png"
    echo "iVBORw0KGgoAAAANSUhEUgAAAIAAAACACAYAAADDPmHLAAAAW0lEQVR42u3OMQEAAAgDoGn/zlMGByQgtpf2agkQIECAAAECBAgQIECAAAECBAgQIECAAAECBAgQIECAAAECBAgQIECAAAECBAgQIECAAAECBAgQIECAgJkDNlYBMz8nJJAAAAAASUVORK5CYII=" | base64 -d > "$ICONS_DIR/icon128.png"
    ok "Placeholder icons created"
fi

# ============================================
# Step 6: Register Native Messaging Host
# ============================================
step "Registering native messaging host..."

cat > "$INSTALL_DIR/$MANIFEST_NAME" << EOF
{
  "name": "com.outline.proxy",
  "description": "Outline Proxy Native Host",
  "path": "$INSTALL_DIR/$HOST_EXE_NAME",
  "type": "stdio",
  "allowed_origins": [
    "chrome-extension://*/"
  ]
}
EOF

# Chrome
mkdir -p "$CHROME_MANIFEST_DIR"
ln -sf "$INSTALL_DIR/$MANIFEST_NAME" "$CHROME_MANIFEST_DIR/$MANIFEST_NAME"
ok "Registered for Chrome"

# Chromium
mkdir -p "$CHROMIUM_MANIFEST_DIR"
ln -sf "$INSTALL_DIR/$MANIFEST_NAME" "$CHROMIUM_MANIFEST_DIR/$MANIFEST_NAME"
ok "Registered for Chromium"

# Brave
mkdir -p "$BRAVE_MANIFEST_DIR" 2>/dev/null || true
ln -sf "$INSTALL_DIR/$MANIFEST_NAME" "$BRAVE_MANIFEST_DIR/$MANIFEST_NAME" 2>/dev/null && ok "Registered for Brave" || true

# ============================================
# Step 7: Summary
# ============================================
echo ""
echo -e "  ${GREEN}========================================${NC}"
echo -e "  ${GREEN}     Installation Complete!${NC}"
echo -e "  ${GREEN}========================================${NC}"
echo ""
echo -e "  ${YELLOW}Installed files:${NC}"
echo -e "    ${GRAY}$INSTALL_DIR/$HOST_EXE_NAME${NC}"
echo -e "    ${GRAY}$INSTALL_DIR/sslocal${NC}"
echo ""
echo -e "  ${YELLOW}Next steps:${NC}"
echo ""
echo -e "  1. Open Chrome/Brave and go to:"
echo -e "     ${CYAN}chrome://extensions${NC}"
echo ""
echo -e "  2. Enable ${YELLOW}'Developer mode'${NC} (top right)"
echo ""
echo -e "  3. Click ${YELLOW}'Load unpacked'${NC} and select:"
echo -e "     ${CYAN}$EXTENSION_DIR${NC}"
echo ""
echo -e "  4. Click the extension icon, paste your"
echo -e "     Outline key (ss://...) and connect!"
echo ""

# Try to open browser
if [ "$PLATFORM" = "linux" ]; then
    if command -v xdg-open &> /dev/null; then
        read -p "Open chrome://extensions now? (Y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            xdg-open "chrome://extensions" 2>/dev/null || true
        fi
    fi
else
    read -p "Open chrome://extensions now? (Y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        open "chrome://extensions" 2>/dev/null || true
    fi
fi

echo -e "\n${MAGENTA}Done! Enjoy YouTube without lags in games :)${NC}\n"
