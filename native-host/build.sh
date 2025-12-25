#!/bin/bash

set -e

echo "Building Outline Proxy Native Host..."
echo

cd "$(dirname "$0")"

# Check if Go is installed
if ! command -v go &> /dev/null; then
    echo "[ERROR] Go is not installed. Please install Go from https://go.dev"
    exit 1
fi

echo "Downloading dependencies..."
go mod tidy

echo
echo "Building for current platform..."
go build -ldflags="-s -w" -o outline-proxy-host .

echo
echo "Build successful!"
echo "Output: outline-proxy-host"
echo

# Make executable
chmod +x outline-proxy-host
