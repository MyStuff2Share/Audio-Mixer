# Audio Mixer

A native SwiftUI macOS audio mixer inspired by Sound Control-style workflows.

Audio Mixer provides a visible SwiftUI app window plus a menu-bar extra. It can control hardware input/output volume where macOS exposes those controls, and it can route selected app audio through Core Audio process taps for per-app volume, mute, and balance.

**Main Window - Sidebar Dashboard Interface**

<img width="926" height="599" alt="Audio Mixer main window" src="https://github.com/user-attachments/assets/093d5b9a-9dce-427c-9ffd-1efc6fd4c4c1" />


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
- **Menu bar widget** for quick device volume and mute control without opening main window.
- **Menu bar widget** shows favorite apps with quick volume access.
- **Numeric volume input field**—click percentage to type exact value (0-100).
- **App favorite/pinning** with star button (orange when starred, favorites sort to top).
- **Visual indicators:**
  - Orange star = app is favorited
  - Orange speaker icon = unmuted
  - Red speaker icon = muted
  - Green dot = app actively producing audio
  - Gray dot = app has audio process but not active
- **Smart app-list filtering** that shows only apps actively producing audio by default (Active Only mode).
- **Four selectable interface styles:** Sidebar Dashboard, Pro Console, Routing Map, and Card Stack.
- **Device mute buttons** in all interface styles showing orange (unmuted) or red (muted) status.
- **Colorful controls:** Orange for output, Blue for input, Red for muted states.

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

## Visual Guide

### Color Scheme
- **Orange:** Output device controls, unmuted status, favorite star
- **Blue:** Input device controls
- **Red:** Muted status
- **Green:** Active audio activity indicator
- **Gray:** Inactive or secondary elements

### UI Controls You'll See

| Control | Location | Purpose |
|---------|----------|---------|
| Speaker icon in menu bar | Top-right of screen | Click to open menu bar widget |
| Volume slider | Device cards & app rows | Drag to adjust volume 0-100% |
| Volume percentage | Next to slider | Click to enter numeric value |
| Star button | Right of app name | Click to favorite app |
| Mute button | Speaker icon | Click to toggle mute (orange/red) |
| Activity dot | Left of app name | Green = audio active, Gray = inactive |
| Route button | Right side of row | Circle icon, orange when routed |
| Device dropdown | Right of each app | Select output device for app |
| ↗ button | Top-right of widget | Click to open main window |

### Interface Styles
Choose in Settings or use keyboard shortcuts:
- **Cmd+1:** Sidebar Dashboard (default)
- **Cmd+2:** Pro Console
- **Cmd+3:** Routing Map
- **Cmd+4:** Card Stack

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

## Screenshots

### Menu Bar Widget
Click the speaker icon in your menu bar to access quick controls without opening the main window.

**Features visible in widget:**
- Output device volume slider with real-time percentage display
- Output mute button (orange = unmuted, red = muted)
- Input device volume slider with real-time percentage display
- Input mute button (orange = unmuted, red = muted)
- Favorite apps list showing pinned apps with quick volume sliders
- "Open" button (↗) to launch full application

### Main Application Window
The Sidebar Dashboard interface shows all app audio controls in one view.

**Features visible:**
- Device summary cards at top with volume sliders and mute buttons
- Per-app volume control rows with:
  - App icon and name
  - Activity indicator (green dot for active audio)
  - Mute button
  - Volume slider
  - Volume percentage (clickable to enter custom value)
  - Favorite star button (orange when starred)
  - Output device selector dropdown
  - Route button (orange when routed)
- Scrollable list of apps

### Numeric Volume Input
Click any volume percentage (e.g., "75%") to edit it directly.

**Input interface:**
- Text field appears when clicking percentage
- Type value 0-100
- Press Enter to apply or Escape to cancel
- Real-time validation

### App Favorites
Star button next to each app for quick access.

**Favorites workflow:**
1. Click star icon to favorite an app (becomes orange)
2. Favorited apps automatically sort to top of list
3. Favorite apps also appear in menu bar widget
4. Click star again to remove from favorites

### Device Controls
Output and Input device cards at the top of each interface.

**Device card features:**
- Device name display
- Volume slider (0-100%)
- Mute button with color indicators
- Volume percentage display

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

## Understanding the Interface

### Activity Indicators
- **Green dot** next to app name = Core Audio detects active audio output from that app
- **Gray dot** next to app name = App has audio processes but not currently active
- **No dot** = App is listed but has no active audio processes

### Mute Status
- **Orange speaker icon** = Device/app is unmuted (normal volume state)
- **Red speaker icon** = Device/app is muted (no sound will play)
- **Speaker with slash** = Alternate mute icon (same as red speaker)

### Favorite Status
- **Orange/filled star** = App is favorited (pinned to top, shown in menu bar widget)
- **Gray/outline star** = App is not favorited
- Favorited apps sort to the top of the app list

### Route Status
- **Orange circle** = App is currently being routed through Audio Mixer (per-app control active)
- **Gray circle** = App is not routed (volume control won't affect this app)
- When routed, the app's slider and mute button become active

### Volume Display
- Shows current volume as percentage (0-100%)
- **Click to edit:** Type custom value (0-100) and press Enter
- Updates in real-time as you adjust sliders

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
