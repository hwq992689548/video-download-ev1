#!/bin/bash
# Downloads a standalone Node.js binary for bundling into the macOS app.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/macos/ThirdParty/node"
NODE_VERSION="22.14.0"

ARCH="$(uname -m)"
case "$ARCH" in
  arm64) NODE_ARCH="darwin-arm64" ;;
  x86_64) NODE_ARCH="darwin-x64" ;;
  *)
    echo "Unsupported macOS architecture: $ARCH" >&2
    exit 1
    ;;
esac

if [[ -x "$DEST/bin/node" ]]; then
  echo "Bundled Node.js already present: $($DEST/bin/node --version)"
  exit 0
fi

TARBALL="node-v${NODE_VERSION}-${NODE_ARCH}.tar.gz"
URL="https://nodejs.org/dist/v${NODE_VERSION}/${TARBALL}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "Downloading $URL ..."
curl -fsSL "$URL" -o "$TMP/$TARBALL"
tar -xzf "$TMP/$TARBALL" -C "$TMP"

rm -rf "$DEST"
mkdir -p "$DEST"
cp -R "$TMP/node-v${NODE_VERSION}-${NODE_ARCH}/." "$DEST/"
chmod +x "$DEST/bin/node"

echo "Installed bundled Node.js to $DEST"
"$DEST/bin/node" --version
