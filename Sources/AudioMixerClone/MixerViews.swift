import AppKit
import SwiftUI

struct MixerPanel: View {
    @EnvironmentObject private var store: MixerStore
    @Environment(\.openSettings) private var openSettings
    @State private var showsAudioProcesses = false
    @State private var showsHotKeys = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            inputSection
            Divider()
            outputSection
            Divider()
            commandRow(title: "Audio Processes", icon: "waveform.path.ecg", action: { showsAudioProcesses = true })
            commandRow(title: "Hot Keys", icon: "keyboard", action: { showsHotKeys = true })
            commandRow(title: "Settings", icon: "gearshape", action: openSettings.callAsFunction)
            Divider()
            quitRow
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial)
        .sheet(isPresented: $showsAudioProcesses) {
            AudioProcessDebugView()
                .environmentObject(store)
                .frame(width: 660, height: 440)
        }
        .sheet(isPresented: $showsHotKeys) {
            HotKeysView()
                .environmentObject(store)
                .frame(width: 460, height: 320)
        }
    }

    private var header: some View {
        HStack {
            Text("Sound Control")
                .font(.system(size: 22, weight: .semibold))

            Spacer()

            Toggle("", isOn: $store.isEnabled)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(.orange)
        }
        .padding(.bottom, 12)
    }

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Input")
                .font(.headline)
                .foregroundStyle(.secondary)

            DeviceRow(
                title: store.inputDevice.name,
                symbol: "mic",
                volume: Binding(
                    get: { store.inputDevice.volume },
                    set: { store.setInputVolume($0) }
                ),
                isMuted: Binding(
                    get: { store.inputDevice.isMuted },
                    set: { store.setInputMuted($0) }
                ),
                canSetVolume: store.inputDevice.canSetVolume,
                canSetMute: store.inputDevice.canSetMute,
                showsDisclosure: true
            )
        }
        .padding(.vertical, 12)
    }

    private var outputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Output Volume")
                .font(.system(size: 18, weight: .semibold))

            controlModePicker
            filterControls
            routingStatus

            DeviceRow(
                title: store.outputDevice.name,
                symbol: "headphones",
                volume: Binding(
                    get: { store.outputDevice.volume },
                    set: { store.setOutputVolume($0) }
                ),
                isMuted: Binding(
                    get: { store.outputDevice.isMuted },
                    set: { store.setOutputMuted($0) }
                ),
                canSetVolume: store.outputDevice.canSetVolume,
                canSetMute: store.outputDevice.canSetMute,
                showsDisclosure: false
            )

            appRows

            HStack {
                Spacer()
                Button {
                    store.refresh()
                } label: {
                    Label("Add App", systemImage: "plus")
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                Image(systemName: "chevron.right")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 12)
    }

    private var controlModePicker: some View {
        Picker("", selection: $store.selectedControlMode) {
            Image(systemName: "speaker.wave.2.fill").tag(0)
            Image(systemName: "slider.horizontal.3").tag(1)
            Image(systemName: "headphones").tag(2)
            Image(systemName: "shuffle").tag(3)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }

    private var appRows: some View {
        VStack(spacing: 8) {
            ForEach(store.visibleApps.prefix(8)) { app in
                AppVolumeRow(
                    app: app,
                    volume: store.volumeBinding(for: app),
                    isMuted: store.mutedBinding(for: app),
                    balance: store.balanceBinding(for: app),
                    isRouting: store.isRouting(app),
                    routeDetail: store.routeDetail(for: app),
                    audioProcessCount: store.appAudioProcessCount(app),
                    isRunningOutput: store.appIsRunningOutput(app),
                    toggleRouting: {
                        store.toggleRouting(for: app)
                    }
                )
            }
        }
    }

    private var filterControls: some View {
        HStack(spacing: 14) {
            Toggle("Active Only", isOn: Binding(
                get: { store.settings.showActiveAudioOnly },
                set: { newValue in
                    store.settings.showActiveAudioOnly = newValue
                    store.saveSettings()
                }
            ))
            .toggleStyle(.checkbox)

            Toggle("Auto Route", isOn: Binding(
                get: { store.settings.autoRouteWhenAdjusting },
                set: { newValue in
                    store.settings.autoRouteWhenAdjusting = newValue
                    store.saveSettings()
                }
            ))
            .toggleStyle(.checkbox)

            Spacer()
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private var routingStatus: some View {
        Group {
            if let message = store.routingMessage {
                Label(message, systemImage: "waveform.path")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 2)
            }
        }
    }

    private func commandRow(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .frame(width: 20)
                Text(title)
                    .font(.system(size: 17, weight: .medium))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 17, weight: .semibold))
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var quitRow: some View {
        Button {
            NSApplication.shared.terminate(nil)
        } label: {
            HStack {
                Text("Quit Sound Control")
                    .font(.system(size: 17, weight: .medium))
                Spacer()
                Text("⌘Q")
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .keyboardShortcut("q")
    }
}

struct DeviceRow: View {
    let title: String
    let symbol: String
    @Binding var volume: Double
    @Binding var isMuted: Bool
    let canSetVolume: Bool
    let canSetMute: Bool
    let showsDisclosure: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 27, weight: .medium))
                .frame(width: 30)

            Text(title)
                .font(.system(size: 19, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Spacer()

            Button {
                isMuted.toggle()
            } label: {
                Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 19, weight: .semibold))
            }
            .buttonStyle(.plain)
            .disabled(!canSetMute)
            .foregroundStyle(canSetMute ? .primary : .secondary)

            Slider(value: $volume, in: 0...1)
                .frame(width: 135)
                .tint(.orange)
                .disabled(!canSetVolume)

            if showsDisclosure {
                Image(systemName: "chevron.right")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct AppVolumeRow: View {
    let app: RunningAudioApp
    @Binding var volume: Double
    @Binding var isMuted: Bool
    @Binding var balance: Double
    let isRouting: Bool
    let routeDetail: String?
    let audioProcessCount: Int
    let isRunningOutput: Bool
    let toggleRouting: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            appIcon

            Text(app.name)
                .font(.system(size: 17, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            if audioProcessCount > 0 {
                Circle()
                    .fill(isRunningOutput ? Color.green : Color.secondary.opacity(0.55))
                    .frame(width: 7, height: 7)
                    .help(isRunningOutput ? "Audio output active" : "\(audioProcessCount) audio process(es)")
            }

            Spacer(minLength: 8)

            Button {
                isMuted.toggle()
            } label: {
                Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.1.fill")
                    .font(.system(size: 19, weight: .semibold))
            }
            .buttonStyle(.plain)

            Slider(value: $volume, in: 0...1)
                .frame(width: 130)
                .tint(isMuted ? .secondary : .orange)
                .disabled(isMuted)

            Button(action: toggleRouting) {
                Image(systemName: isRouting ? "record.circle.fill" : "record.circle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isRouting ? .orange : .secondary)
            }
            .buttonStyle(.plain)
            .help(isRouting ? "Stop Core Audio tap: \(routeDetail ?? "active")" : "Start Core Audio process tap")

            Menu {
                Slider(value: $balance, in: -1...1) {
                    Text("Balance")
                }
                Button("Route to \(app.name)") {}
                Button(isMuted ? "Unmute" : "Mute") {
                    isMuted.toggle()
                }
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(.orange)
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
        }
    }

    private var appIcon: some View {
        Group {
            if let icon = app.icon {
                Image(nsImage: icon)
                    .resizable()
            } else {
                Image(systemName: "app.fill")
                    .resizable()
            }
        }
        .frame(width: 24, height: 24)
        .clipShape(RoundedRectangle(cornerRadius: 5))
    }
}

struct AudioProcessDebugView: View {
    @EnvironmentObject private var store: MixerStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Audio Processes")
                    .font(.title2.weight(.semibold))
                Spacer()
                Button {
                    store.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Refresh")

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .help("Close")
            }
            .padding(16)

            Divider()

            Table(store.audioProcessRows()) {
                TableColumn("Output") { process in
                    Image(systemName: process.isRunningOutput ? "speaker.wave.2.fill" : "speaker")
                        .foregroundStyle(process.isRunningOutput ? .orange : .secondary)
                }
                .width(60)

                TableColumn("PID") { process in
                    Text(process.processIdentifier.map(String.init) ?? "—")
                        .font(.system(.body, design: .monospaced))
                }
                .width(90)

                TableColumn("Object") { process in
                    Text(String(process.id))
                        .font(.system(.body, design: .monospaced))
                }
                .width(90)

                TableColumn("Bundle ID") { process in
                    Text(process.bundleIdentifier ?? "Unknown")
                        .lineLimit(1)
                }
            }
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var store: MixerStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Settings")
                    .font(.title2.weight(.semibold))

                SettingsSectionBox(title: "Profiles") {
                    SettingsToggleRow(title: "Remember app profiles", binding: settingsBinding(\.rememberAppProfiles))
                    SettingsToggleRow(title: "Show inactive saved apps", binding: settingsBinding(\.showInactiveProfiles))
                    SettingsToggleRow(title: "Hide apps without audio processes", binding: settingsBinding(\.hideAppsWithoutAudioProcesses))
                    SettingsToggleRow(title: "Show active audio only", binding: settingsBinding(\.showActiveAudioOnly))
                    SettingsToggleRow(title: "Auto-route when adjusting app controls", binding: settingsBinding(\.autoRouteWhenAdjusting))
                }

                SettingsSectionBox(title: "Startup") {
                    SettingsToggleRow(title: "Launch at login", binding: settingsBinding(\.launchAtLogin))
                }

                SettingsSectionBox(title: "Audio") {
                    SettingsValueRow(title: "Shortcut volume step") {
                        Stepper(value: settingsBinding(\.shortcutStep), in: 1...25, step: 1) {
                            Text("\(Int(store.settings.shortcutStep))%")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                                .frame(width: 44, alignment: .trailing)
                        }
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func settingsBinding<Value>(_ keyPath: WritableKeyPath<MixerSettings, Value>) -> Binding<Value> {
        Binding(
            get: { store.settings[keyPath: keyPath] },
            set: { newValue in
                store.settings[keyPath: keyPath] = newValue
                store.saveSettings()
            }
        )
    }
}

struct HotKeysView: View {
    @EnvironmentObject private var store: MixerStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Hot Keys")
                    .font(.title2.weight(.semibold))
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
            }

            SettingsSectionBox(title: "Volume") {
                SettingsValueRow(title: "Step size") {
                    Stepper(value: settingsBinding(\.shortcutStep), in: 1...25, step: 1) {
                        Text("\(Int(store.settings.shortcutStep))%")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 44, alignment: .trailing)
                    }
                }
                HotKeyRow(title: "Volume down", keys: "⌥⌘↓")
                HotKeyRow(title: "Volume up", keys: "⌥⌘↑")
                HotKeyRow(title: "Mute current app", keys: "⌥⌘M")
            }

            Text("Global hotkey registration is not implemented yet; these rows define the intended shortcuts and shared step size.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(24)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func settingsBinding<Value>(_ keyPath: WritableKeyPath<MixerSettings, Value>) -> Binding<Value> {
        Binding(
            get: { store.settings[keyPath: keyPath] },
            set: { newValue in
                store.settings[keyPath: keyPath] = newValue
                store.saveSettings()
            }
        )
    }
}

struct SettingsSectionBox<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)

            VStack(spacing: 0) {
                content
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

struct SettingsToggleRow: View {
    let title: String
    @Binding var binding: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .lineLimit(1)
            Spacer()
            Toggle("", isOn: $binding)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .frame(minHeight: 34)
    }
}

struct SettingsValueRow<Accessory: View>: View {
    let title: String
    @ViewBuilder var accessory: Accessory

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            accessory
        }
        .frame(minHeight: 34)
    }
}

struct HotKeyRow: View {
    let title: String
    let keys: String

    var body: some View {
        SettingsValueRow(title: title) {
            Text(keys)
                .font(.system(.body, design: .monospaced).weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(nsColor: .separatorColor).opacity(0.25))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }
}
