# AudioMixerClone

A native SwiftUI macOS audio mixer inspired by Sound Control-style workflows.

AudioMixerClone provides a visible SwiftUI app window plus a menu-bar extra. It can control hardware input/output volume where macOS exposes those controls, and it can route selected app audio through Core Audio process taps for per-app volume, mute, and balance.

## Current Features

- Default input and output device discovery through Core Audio.
- Hardware input/output volume and mute control when supported by the device.
- Per-app volume, mute, and balance profiles persisted by bundle identifier.
- Core Audio process tap routing for running apps on macOS 14.2+.
- Private aggregate-device creation for each active app route.
- Real-time IOProc processing that applies gain, mute, and balance to tapped app audio.
- Browser/helper-process matching for apps such as Brave, Chrome, Electron apps, and other multi-process apps.
- Auto-route when an app slider, mute button, or balance control is adjusted.
- Remembered auto-route preferences for apps that should route again when they produce audio.
- Automatic stale-route cleanup when an app quits or stops exposing audio processes.
- Route recovery when an app’s audio helper process changes.
- App-list filtering for likely audio-capable apps and an Active Only mode.
- Audio Processes debug view showing Core Audio object ID, PID, bundle ID, and output activity.
- Local packaging script for `.app`, `.dmg` when available, and `.zip` fallback.

## Requirements

- macOS 14.2 or later for Core Audio process taps.
- Xcode installed at `/Applications/Xcode.app`.
- System audio capture permission when macOS prompts for it.

The app bundle includes `NSAudioCaptureUsageDescription` in `Support/Info.plist`.

## Build

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
CLANG_MODULE_CACHE_PATH=$PWD/.build/cache/clang \
swift build --disable-sandbox --cache-path .build/cache/swiftpm --manifest-cache local
```

## Run From Source

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
CLANG_MODULE_CACHE_PATH=$PWD/.build/cache/clang \
swift run --disable-sandbox --cache-path .build/cache/swiftpm --manifest-cache local
```

## Package

```bash
Scripts/package.sh
```

The script builds a release binary, creates `dist/AudioMixerClone.app`, ad-hoc signs it for local testing, and tries to create `dist/AudioMixerClone.dmg`. If `hdiutil` cannot create a DMG in the current environment, the script creates `dist/AudioMixerClone.zip` instead.

For public distribution, replace ad-hoc signing with Developer ID signing and notarize the DMG with Apple.

## Install Locally

```bash
rm -rf /Applications/AudioMixerClone.app
cp -R dist/AudioMixerClone.app /Applications/
open /Applications/AudioMixerClone.app
```

## How To Test Per-App Volume

1. Start audio in an app, such as YouTube in Brave.
2. Open AudioMixerClone.
3. Adjust that app’s slider, or click the circular route button beside the app.
4. Grant system audio capture permission if macOS asks.
5. When the route button is orange, the app’s slider and mute button should affect that app’s audio.

The status line reports how many Core Audio process objects were routed. Browsers may show helper-process routing depending on where the audio is actually produced.

## Debugging Audio Processes

Use **Audio Processes** in the app to inspect the Core Audio process list. This is useful when a multi-process app reports audio under helper processes or when an app does not appear in the filtered list.

## Limitations

- This is a local-testing app, not a notarized public release.
- Per-app EQ UI is present as profile state, but EQ DSP is not implemented yet.
- Per-app output-device routing is not implemented yet; active routes currently target the current default output route used when routing starts.
- The real-time DSP path is intentionally minimal: gain, mute, and balance only.
- If macOS audio permissions are denied, taps cannot capture audio until permission is granted in System Settings.

## Project Layout

```text
Sources/AudioMixerClone/
  AudioMixerCloneApp.swift
  AudioRoutingService.swift
  CoreAudioDeviceController.swift
  LaunchDiagnostics.swift
  MixerModels.swift
  MixerStore.swift
  MixerViews.swift
Support/
  Info.plist
Scripts/
  package.sh
```
