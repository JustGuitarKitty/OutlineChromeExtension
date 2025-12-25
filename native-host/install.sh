#!/bin/bash

set -e

echo "=========================================="
echo "  Outline Proxy Native Host Installer"
echo "=========================================="
echo

# Determine OS
OS="$(uname -s)"
case "${OS}" in
    Linux*)     PLATFORM=linux;;
    Darwin*)    PLATFORM=macos;;
    *)          echo "Unsupported OS: ${OS}"; exit 1;;
esac

echo "Detected platform: $PLATFORM"
echo

# Set paths based on platform
if [ "$PLATFORM" = "linux" ]; then
    INSTALL_DIR="$HOME/.local/share/outline-proxy"
    CHROME_MANIFEST_DIR="$HOME/.config/google-chrome/NativeMessagingHosts"
    CHROMIUM_MANIFEST_DIR="$HOME/.config/chromium/NativeMessagingHosts"
else
    INSTALL_DIR="$HOME/Library/Application Support/OutlineProxy"
    CHROME_MANIFEST_DIR="$HOME/Library/Application Support/Google/Chrome/NativeMessagingHosts"
fi

EXE_NAME="outline-proxy-host"
MANIFEST_NAME="com.outline.proxy.json"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "[1/4] Creating installation directory..."
mkdir -p "$INSTALL_DIR"

echo "[2/4] Copying executable..."
cp "$SCRIPT_DIR/$EXE_NAME" "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/$EXE_NAME"

echo "[3/4] Creating Native Messaging manifest..."

# Ask for extension ID
read -p "Enter Chrome extension ID (leave empty for development): " EXT_ID

if [ -z "$EXT_ID" ]; then
    # For development, we can't use wildcard, so we'll need the actual ID
    echo "Note: You'll need to update the extension ID after installing the extension"
    ALLOWED_ORIGIN="chrome-extension://aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/"
else
    ALLOWED_ORIGIN="chrome-extension://$EXT_ID/"
fi

cat > "$INSTALL_DIR/$MANIFEST_NAME" << EOF
{
  "name": "com.outline.proxy",
  "description": "Outline Proxy Native Host",
  "path": "$INSTALL_DIR/$EXE_NAME",
  "type": "stdio",
  "allowed_origins": [
    "$ALLOWED_ORIGIN"
  ]
}
EOF

echo "[4/4] Installing manifest for browsers..."

# Chrome
mkdir -p "$CHROME_MANIFEST_DIR"
ln -sf "$INSTALL_DIR/$MANIFEST_NAME" "$CHROME_MANIFEST_DIR/$MANIFEST_NAME"
echo "  - Installed for Chrome"

# Chromium (Linux only)
if [ "$PLATFORM" = "linux" ]; then
    mkdir -p "$CHROMIUM_MANIFEST_DIR"
    ln -sf "$INSTALL_DIR/$MANIFEST_NAME" "$CHROMIUM_MANIFEST_DIR/$MANIFEST_NAME"
    echo "  - Installed for Chromium"
fi

echo
echo "=========================================="
echo "  Installation completed successfully!"
echo "=========================================="
echo
echo "Installed to: $INSTALL_DIR"
echo
echo "Please restart Chrome to apply changes."
echo
