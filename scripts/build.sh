#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

mkdir -p "$ROOT_DIR/build"

/usr/bin/swiftc \
  -O \
  -o "$ROOT_DIR/build/sagasu-menubar" \
  "$ROOT_DIR"/Sources/*.swift \
  -framework AppKit \
  -framework SwiftUI \
  -framework Combine

echo "Built: $ROOT_DIR/build/sagasu-menubar"