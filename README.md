# Audio Mixer

A native SwiftUI macOS audio mixer inspired by Sound Control-style workflows.

Audio Mixer provides a visible SwiftUI app window plus a menu-bar extra. It can control hardware input/output volume where macOS exposes those controls, and it can route selected app audio through Core Audio process taps for per-app volume, mute, and balance.

<img width="926" height="599" alt="image" src="https://github.com/user-attachments/assets/093d5b9a-9dce-427c-9ffd-1efc6fd4c4c1" />


## Current Features

### Core Audio Control
- Default input and output device discovery through Core Audio.
- Hardware input/output volume and mute control with quick-access mute buttons.
- Per-app volume, mute, and balance profiles persisted by bundle identifier.
- Core Audio process tap routing for running apps on macOS 14.2+.
- Private aggregate-device creation for each active app route.
- Real-time IOProc processing that applies gain, mute, and balance to tapped app audio.
- Browser/helper-process matching for apps such as Brave, Chrome, Electron apps, and other multi-process apps.

### App Volume Management
- Per-app volume, mute, and balance sliders with numeric display (0-100%).
- Click volume percentage to enter precise numeric values.
- Favorite/pin apps with star button for quick access—favorites sort to the top.
- Auto-route when an app slider, mute button, or balance control is adjusted.
- Remembered auto-route preferences for apps that should route again when they produce audio.
- Automatic stale-route cleanup when an app quits or stops exposing audio processes.
- Route recovery when an app’s audio helper process changes.

### User Interface
- Menu bar widget for quick device volume and mute control without opening main window.
- Menu bar widget shows favorite apps with quick volume access.
- Numeric volume input field—click percentage to type exact value (0-100).
- Smart app-list filtering that shows only apps actively producing audio by default (Active Only mode).
- Four selectable interface styles: Sidebar Dashboard, Pro Console, Routing Map, and Card Stack.
- Device mute buttons in all interface styles showing orange (unmuted) or red (muted) status.

### System Integration
- Smart dock visibility—hides from dock when window is closed, accessible via menu bar.
- Launch at Login option in Settings → Startup section.
- Built-in Help guide available from the macOS Help menu with setup, routing, shortcuts, and troubleshooting notes.
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

The script builds a release binary, creates `dist/Audio Mixer.app`, ad-hoc signs it for local testing, and tries to create `dist/Audio Mixer.dmg`. If `hdiutil` cannot create a DMG in the current environment, the script creates `dist/Audio Mixer.zip` instead.

For public distribution, replace ad-hoc signing with Developer ID signing and notarize the DMG with Apple.

## Install Locally

```bash
rm -rf "/Applications/Audio Mixer.app"
cp -R "dist/Audio Mixer.app" /Applications/
open "/Applications/Audio Mixer.app"
```

## Quick Start

### Menu Bar Widget
1. Click the speaker icon in your menu bar (top right of screen).
2. Adjust output or input volume with sliders.
3. Toggle mute with the speaker/mic buttons (orange = unmuted, red = muted).
4. Access favorite apps’ volume controls directly from the widget.
5. Click the ↗ button to open the full application window.

### Numeric Volume Input
1. In the app or menu bar widget, click on any volume percentage (e.g., "75%").
2. Type a value from 0-100.
3. Press Enter to apply, or Escape to cancel.

### Favorite Apps
1. In the app’s mixer view, click the star icon next to an app to favorite it.
2. Favorited apps sort to the top of the list.
3. Star appears orange when an app is favorited.
4. Favorite apps also appear in the menu bar widget for quick access.

## How To Test Per-App Volume

1. Start audio in an app, such as YouTube in Brave.
2. Open Audio Mixer.
3. Adjust that app’s slider, or click the circular route button beside the app.
4. Grant system audio capture permission if macOS asks.
5. When the route button is orange, the app’s slider and mute button should affect that app’s audio.

The status line reports how many Core Audio process objects were routed. Browsers may show helper-process routing depending on where the audio is actually produced.

## Menu Bar Widget Features

The menu bar widget provides quick access without opening the main window:

- **Output Device Control:** Volume slider, mute button, and percentage display
- **Input Device Control:** Microphone volume, mute button, and percentage display
- **Favorite Apps List:** Quick volume adjustment for pinned apps
- **Open Button:** Launch the full application window (↗ icon)
- **Compact Size:** 320×280 pixel window stays out of the way

The menu bar widget updates in real-time as you adjust volumes.

## Debugging Audio Processes

Use **Audio Processes** in the app to inspect the Core Audio process list. This is useful when a multi-process app reports audio under helper processes or when an app does not appear in the filtered list.

## Dock & Window Behavior

- App automatically hides from the dock when the main window is closed (menu bar remains accessible).
- Clicking the ↗ button in the menu bar widget or using the menu bar brings the app back to the dock.
- Settings and Help windows open independently and don't affect dock visibility.
- App respects "Launch at Login" setting in Settings → Startup section.

## Limitations

- This is a local-testing app, not a notarized public release.
- Per-app EQ UI is present as profile state, but EQ DSP is not implemented yet.
- Per-app output-device routing UI is present but routing logic is not yet implemented; active routes currently target the current default output route used when routing starts.
- The real-time DSP path is intentionally minimal: gain, mute, and balance only.
- If macOS audio permissions are denied, taps cannot capture audio until permission is granted in System Settings.

## Project Layout

```text
Sources/AudioMixer/
  AudioMixerApp.swift
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
