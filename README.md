# AudioMixerClone

A native SwiftUI macOS menu-bar audio mixer inspired by Sound Control-style workflows.

## What Works

- Menu-bar window UI with input, output, app, hotkey, and settings sections.
- Current default output/input device discovery through CoreAudio.
- Hardware volume and mute control for devices that expose those controls to macOS.
- Running-app list from `NSWorkspace`.
- Per-app volume, mute, balance, and EQ profile persistence by bundle identifier.
- Core Audio process tap creation/destruction for individual running apps on macOS 14.2+.
- Live routing parameter updates from the per-app sliders into the active tap backend.
- Settings window for remembered app profiles, launch behavior preference, and shortcut step size.

## Important Limitation

macOS does not provide a simple public API for applying independent volume directly to arbitrary apps. Production per-app audio control generally requires Core Audio process taps, private aggregate devices, Audio Unit processing, or a virtual audio device.

This project now has the first tap layer: it can resolve a running app's PID to a Core Audio process object and create a private process tap. The next backend step is to attach those tap UIDs to private aggregate devices, start an IOProc, process buffers in real time, and write the mixed output to the selected physical device.

Core Audio taps require macOS 14.2 or later. A bundled app target must include `NSAudioCaptureUsageDescription`; see `Support/Info.plist`.

## Run

```bash
swift run
```

## Package a macOS App and DMG

```bash
Scripts/package.sh
```

The script builds a release binary, creates `dist/AudioMixerClone.app`, ad-hoc signs it for local testing, and creates `dist/AudioMixerClone.dmg`.

For public distribution, replace ad-hoc signing with a Developer ID certificate and notarize the DMG with Apple.

## Build

```bash
swift build
```

## Project Layout

```text
Sources/AudioMixerClone/
  AudioMixerCloneApp.swift
  CoreAudioDeviceController.swift
  MixerModels.swift
  MixerStore.swift
  MixerViews.swift
```
