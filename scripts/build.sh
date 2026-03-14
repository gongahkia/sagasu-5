#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

mkdir -p "$ROOT_DIR/build"

# Prefer building via SwiftPM (more correct for dependencies), but SwiftPM
# requires a compatible toolchain. If full Xcode is installed, force using it.
XCODE_DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
if [[ -d "$XCODE_DEVELOPER_DIR" ]]; then
  export DEVELOPER_DIR="$XCODE_DEVELOPER_DIR"
fi

cd "$ROOT_DIR"
swift build -c release --product sagasu
swift build -c release --product sagasu-helper

APP_BIN="$ROOT_DIR/.build/release/sagasu"
HELPER_BIN="$ROOT_DIR/.build/release/sagasu-helper"

if [[ ! -f "$APP_BIN" ]]; then
  echo "Expected app binary not found: $APP_BIN" >&2
  exit 1
fi

if [[ ! -f "$HELPER_BIN" ]]; then
  echo "Expected helper binary not found: $HELPER_BIN" >&2
  exit 1
fi

cp "$APP_BIN" "$ROOT_DIR/build/sagasu-menubar"
cp "$HELPER_BIN" "$ROOT_DIR/build/sagasu-helper"
chmod +x "$ROOT_DIR/build/sagasu-menubar" "$ROOT_DIR/build/sagasu-helper"

echo "Built: $ROOT_DIR/build/sagasu-menubar"
echo "Built: $ROOT_DIR/build/sagasu-helper"
