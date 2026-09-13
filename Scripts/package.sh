#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Audio Mixer"
EXECUTABLE_NAME="AudioMixerClone"
CONFIGURATION="${CONFIGURATION:-release}"
DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

export DEVELOPER_DIR
export CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-$ROOT_DIR/.build/cache/clang}"

BUILD_DIR="$ROOT_DIR/.build"
DIST_DIR="$ROOT_DIR/dist"
APP_PATH="$DIST_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_PATH/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
DMG_PATH="$DIST_DIR/$APP_NAME.dmg"
ZIP_PATH="$DIST_DIR/$APP_NAME.zip"
LEGACY_APP_PATH="$DIST_DIR/AudioMixerClone.app"
LEGACY_DMG_PATH="$DIST_DIR/AudioMixerClone.dmg"
LEGACY_ZIP_PATH="$DIST_DIR/AudioMixerClone.zip"

mkdir -p "$CLANG_MODULE_CACHE_PATH" "$DIST_DIR"

swift build \
  -c "$CONFIGURATION" \
  --disable-sandbox \
  --cache-path "$BUILD_DIR/cache/swiftpm" \
  --manifest-cache local

rm -rf "$APP_PATH" "$DMG_PATH" "$ZIP_PATH" "$LEGACY_APP_PATH" "$LEGACY_DMG_PATH" "$LEGACY_ZIP_PATH"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$BUILD_DIR/$CONFIGURATION/$EXECUTABLE_NAME" "$MACOS_DIR/$EXECUTABLE_NAME"
cp "$ROOT_DIR/Support/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$ROOT_DIR/Support/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
printf "APPL????" > "$CONTENTS_DIR/PkgInfo"
chmod +x "$MACOS_DIR/$EXECUTABLE_NAME"

codesign --force --sign - "$APP_PATH"

if hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$APP_PATH" \
    -ov \
    -format UDZO \
    "$DMG_PATH"; then
  echo "Built dmg: $DMG_PATH"
else
  echo "DMG creation failed in this environment; creating a zip instead."
  ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"
  echo "Built zip: $ZIP_PATH"
fi

echo "Built app: $APP_PATH"
