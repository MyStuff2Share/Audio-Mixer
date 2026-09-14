#!/bin/sh
set -e

cd "$(dirname "$0")"

Scripts/package.sh

APP_PATH="/Applications/Audio Mixer.app"
LEGACY_APP_PATH="/Applications/AudioMixerClone.app"

osascript -e 'tell application id "com.example.AudioMixerClone" to quit' >/dev/null 2>&1 || true
sleep 1

if [ -d "$APP_PATH" ]; then
  chmod -R u+w "$APP_PATH" >/dev/null 2>&1 || true
  rm -rf "$APP_PATH"
fi

if [ -d "$LEGACY_APP_PATH" ]; then
  chmod -R u+w "$LEGACY_APP_PATH" >/dev/null 2>&1 || true
  rm -rf "$LEGACY_APP_PATH"
fi

ditto "dist/Audio Mixer.app" "$APP_PATH"
xattr -cr "$APP_PATH" >/dev/null 2>&1 || true

if ! open -n "$APP_PATH"; then
  echo "Built and installed $APP_PATH, but macOS refused the automatic launch."
  echo "Try opening it from Finder, or run: open \"$APP_PATH\""
fi
