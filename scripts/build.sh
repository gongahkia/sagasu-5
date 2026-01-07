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
if swift build -c release --product sagasu; then
  BIN_SRC="$ROOT_DIR/.build/release/sagasu"
  if [[ ! -f "$BIN_SRC" ]]; then
    echo "Expected SwiftPM binary not found: $BIN_SRC" >&2
    exit 1
  fi

  cp "$BIN_SRC" "$ROOT_DIR/build/sagasu-menubar"
  chmod +x "$ROOT_DIR/build/sagasu-menubar"
  echo "Built: $ROOT_DIR/build/sagasu-menubar"
  exit 0
fi

echo "swift build failed; falling back to direct swiftc build" >&2

/usr/bin/swiftc \
  -O \
  -o "$ROOT_DIR/build/sagasu-menubar" \
  "$ROOT_DIR"/Sources/*.swift \
  -framework AppKit \
  -framework SwiftUI \
  -framework Combine

echo "Built: $ROOT_DIR/build/sagasu-menubar"