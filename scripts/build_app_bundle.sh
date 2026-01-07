#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

APP_NAME="Sagasu"
BUNDLE_ID="com.gongahkia.sagasu"
APP_VERSION="${APP_VERSION:-0.0.0}"

# Build the binary (existing script)
"$ROOT_DIR/scripts/build.sh"

BIN_SRC="$ROOT_DIR/build/sagasu-menubar"
if [[ ! -f "$BIN_SRC" ]]; then
  echo "Expected binary not found: $BIN_SRC" >&2
  exit 1
fi

OUT_DIR="$ROOT_DIR/dist"
APP_DIR="$OUT_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
INFO_PLIST="$CONTENTS_DIR/Info.plist"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

# Copy executable into the bundle
cp "$BIN_SRC" "$MACOS_DIR/sagasu-menubar"
chmod +x "$MACOS_DIR/sagasu-menubar"

# Optional icon: place an icns at asset/AppIcon.icns
ICON_SRC="$ROOT_DIR/asset/AppIcon.icns"
ICON_BUNDLE_NAME=""
if [[ -f "$ICON_SRC" ]]; then
  cp "$ICON_SRC" "$RESOURCES_DIR/AppIcon.icns"
  ICON_BUNDLE_NAME="AppIcon"
fi

# Minimal Info.plist for a menu bar app.
# LSUIElement=1 hides the Dock icon.
cat >"$INFO_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>sagasu-menubar</string>
  <key>CFBundleIdentifier</key>
  <string>${BUNDLE_ID}</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>${APP_NAME}</string>
  <key>CFBundleDisplayName</key>
  <string>${APP_NAME}</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>${APP_VERSION}</string>
  <key>CFBundleVersion</key>
  <string>${APP_VERSION}</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>LSUIElement</key>
  <true/>
EOF

if [[ -n "$ICON_BUNDLE_NAME" ]]; then
  cat >>"$INFO_PLIST" <<EOF
  <key>CFBundleIconFile</key>
  <string>${ICON_BUNDLE_NAME}</string>
EOF
fi

cat >>"$INFO_PLIST" <<'EOF'
</dict>
</plist>
EOF

echo "Built app bundle: $APP_DIR"