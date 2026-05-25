#!/usr/bin/env bash
set -euo pipefail

# Installs the latest Aether release binary from GitHub.
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/rafih110610/aether/main/scripts/install.sh | bash
#   or
#   bash scripts/install.sh [owner/repo]

DEFAULT_REPO="rafih110610/aether"

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  echo "Usage: install.sh [owner/repo]"
  echo "Default repo: ${DEFAULT_REPO}"
  exit 0
fi

REPO="${1:-$DEFAULT_REPO}"

# Keep network calls bounded so installs fail fast instead of hanging.
CURL_OPTS=(--fail --silent --show-error --location --connect-timeout 10 --max-time 60 --retry 3 --retry-delay 2)

OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"

case "$OS" in
  linux) OS_PART="unknown-linux-gnu" ;;
  darwin) OS_PART="apple-darwin" ;;
  *)
    echo "Unsupported OS: $OS" >&2
    exit 1
    ;;
esac

case "$ARCH" in
  x86_64|amd64) ARCH_PART="x86_64" ;;
  aarch64|arm64) ARCH_PART="aarch64" ;;
  *)
    echo "Unsupported architecture: $ARCH" >&2
    exit 1
    ;;
esac

TARGET="${ARCH_PART}-${OS_PART}"

API_URL="https://api.github.com/repos/${REPO}/releases/latest"
DOWNLOAD_URL="$(curl "${CURL_OPTS[@]}" "$API_URL" | grep -oE "https://[^\"]*aether-v[^\"]*-${TARGET}\\.tar\\.gz" | head -n1)"

if [[ -z "$DOWNLOAD_URL" ]]; then
  echo "Could not find release asset for target: $TARGET" >&2
  exit 1
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

ARCHIVE_PATH="$TMP_DIR/aether.tar.gz"
curl "${CURL_OPTS[@]}" "$DOWNLOAD_URL" -o "$ARCHIVE_PATH"

tar -xzf "$ARCHIVE_PATH" -C "$TMP_DIR"
BIN_PATH="$(find "$TMP_DIR" -type f -name aether | head -n1)"

if [[ -z "$BIN_PATH" ]]; then
  echo "Extracted archive does not contain aether binary" >&2
  exit 1
fi

AIR_PATH="$(find "$TMP_DIR" -type f -name air | head -n1 || true)"
AETHERPKG_PATH="$(find "$TMP_DIR" -type f -name aetherpkg | head -n1 || true)"

INSTALL_DIR="${HOME}/.local/bin"
mkdir -p "$INSTALL_DIR"
cp "$BIN_PATH" "$INSTALL_DIR/aether"
chmod +x "$INSTALL_DIR/aether"

if [[ -n "$AIR_PATH" ]]; then
  cp "$AIR_PATH" "$INSTALL_DIR/air"
  chmod +x "$INSTALL_DIR/air"
fi

if [[ -n "$AETHERPKG_PATH" ]]; then
  cp "$AETHERPKG_PATH" "$INSTALL_DIR/aetherpkg"
  chmod +x "$INSTALL_DIR/aetherpkg"
fi

echo "Installed Aether to: $INSTALL_DIR/aether"
if [[ -n "$AIR_PATH" ]]; then
  echo "Installed AIR to: $INSTALL_DIR/air"
fi
if [[ -n "$AETHERPKG_PATH" ]]; then
  echo "Installed aetherpkg to: $INSTALL_DIR/aetherpkg"
fi
if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
  echo "Add $INSTALL_DIR to PATH to run 'aether' globally."
fi
