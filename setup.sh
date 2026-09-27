#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DIST_DIR="$SCRIPT_DIR/dist"
ZIP_URL="https://bafybeid5iwqp3uyc4q3dqajjzbsqggqatuttqk4dnkksluqqcxaizbhjpi.ipfs.dweb.link/?filename=u53_web.zip"
ZIP_PATH="$DIST_DIR/eaglercraft.zip"
EXTRACT_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$EXTRACT_DIR"
}
trap cleanup EXIT

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

require_cmd npm
require_cmd curl
require_cmd unzip
require_cmd python3

cd "$SCRIPT_DIR"
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

echo "Building wispcraft..."
npm run build

echo "Downloading Eaglercraft bundle..."
curl -fsSL "$ZIP_URL" -o "$ZIP_PATH"

unzip -q "$ZIP_PATH" -d "$EXTRACT_DIR/eaglercraft"
rm -f "$ZIP_PATH"

if [[ ! -d "$EXTRACT_DIR/eaglercraft/web_wasm" ]]; then
  echo "Downloaded bundle is missing the expected web_wasm directory." >&2
  exit 1
fi

mv -f "$EXTRACT_DIR/eaglercraft/web_wasm/index.html" "$DIST_DIR/index.html"
mv -f "$EXTRACT_DIR/eaglercraft/web_wasm/assets.epw" "$DIST_DIR/assets.epw"
mv -f "$EXTRACT_DIR/eaglercraft/web_wasm/bootstrap.js" "$DIST_DIR/bootstrap.js"

python3 - "$DIST_DIR/index.html" <<'PY'
from pathlib import Path
import sys

html_path = Path(sys.argv[1])
needle = "<head>"
replacement = '<head><script src="index.js"></script>'

text = html_path.read_text(encoding="utf-8")
if needle in text and replacement not in text:
    html_path.write_text(text.replace(needle, replacement, 1), encoding="utf-8")
PY

echo "Setup complete. Files are in $DIST_DIR"
