#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

APP_NAME="Sagasu"
OUT_DIR="$ROOT_DIR/dist"
DMG_PATH="$OUT_DIR/${APP_NAME}.dmg"

# Use git tag (if any) as version; otherwise fall back to 0.0.0
APP_VERSION="${APP_VERSION:-$(git -C "$ROOT_DIR" describe --tags --abbrev=0 2>/dev/null | sed 's/^v//' || echo "0.0.0")}"
export APP_VERSION

"$ROOT_DIR/scripts/build_app_bundle.sh"

APP_DIR="$OUT_DIR/$APP_NAME.app"
if [[ ! -d "$APP_DIR" ]]; then
  echo "Expected app bundle not found: $APP_DIR" >&2
  exit 1
fi

# Stage DMG contents
STAGE_DIR="$(mktemp -d)"
cleanup() { rm -rf "$STAGE_DIR"; }
trap cleanup EXIT

cp -R "$APP_DIR" "$STAGE_DIR/"
ln -s /Applications "$STAGE_DIR/Applications"

rm -f "$DMG_PATH"
/usr/bin/hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGE_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH" >/dev/null

echo "Created DMG: $DMG_PATH"