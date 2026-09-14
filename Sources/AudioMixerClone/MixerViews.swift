import AppKit
import SwiftUI

private enum SidebarDashboardSection {
    case mixer
    case devices
    case routes
}

struct MixerPanel: View {
    @EnvironmentObject private var store: MixerStore
    @Environment(\.openSettings) private var openSettings
    @State private var showsAudioProcesses = false
    @State private var showsHotKeys = false
    @State private var sidebarSection: SidebarDashboardSection = .mixer

    var body: some View {
        Group {
            switch store.settings.interfaceStyle {
            case .sidebarDashboard:
                sidebarDashboard
            case .proConsole:
                proConsole
            case .routingMap:
                routingMap
            case .cardStack:
                cardStack
            }
        }
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

    private var sidebarDashboard: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Image(systemName: "dial.high.fill")
                        .foregroundStyle(.orange)
                    Text("Audio Mixer")
                        .font(.headline.weight(.semibold))
                }
                .padding(.bottom, 8)

                sidebarButton("Mixer", "slider.horizontal.3", selected: sidebarSection == .mixer) { sidebarSection = .mixer }
                sidebarButton("Devices", "speaker.wave.2", selected: sidebarSection == .devices) { sidebarSection = .devices }
                sidebarButton("Routes", "arrow.triangle.branch", selected: sidebarSection == .routes) { sidebarSection = .routes }
                sidebarButton("Hot Keys", "keyboard", selected: false) { showsHotKeys = true }
                sidebarButton("Settings", "gearshape", selected: false, action: openSettings.callAsFunction)

                Divider()
                    .padding(.vertical, 8)

                Text("Filters")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                checkboxFilter("Active Only", \.showActiveAudioOnly)
                checkboxFilter("Auto Route", \.autoRouteWhenAdjusting)

                Spacer()

                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Label("Quit", systemImage: "power")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .padding(18)
            .frame(width: 180)
            .background(.thinMaterial)

            Divider()

            sidebarContent
            .padding(18)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    @ViewBuilder
    private var sidebarContent: some View {
        switch sidebarSection {
        case .mixer:
            mixerDashboardContent
        case .devices:
            devicesDashboardContent
        case .routes:
            routesDashboardContent
        }
    }

    private var mixerDashboardContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            dashboardToolbar
            routingStatus

            HStack(spacing: 12) {
                deviceSummaryCard(title: "Output", icon: "speaker.wave.2.fill", device: store.outputDevice)
                deviceSummaryCard(title: "Input", icon: "mic.fill", device: store.inputDevice)
            }

            ScrollView {
                VStack(spacing: 10) {
                    ForEach(store.visibleApps.prefix(10)) { app in
                        DashboardAppRow(
                            app: app,
                            volume: store.volumeBinding(for: app),
                            isMuted: store.mutedBinding(for: app),
                            isRouting: store.isRouting(app),
                            audioProcessCount: store.appAudioProcessCount(app),
                            isRunningOutput: store.appIsRunningOutput(app),
                            toggleRouting: { store.toggleRouting(for: app) }
                        )
                    }
                }
                .padding(.trailing, 4)
            }
        }
    }

    private var devicesDashboardContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Devices")
                        .font(.title2.weight(.semibold))
                    Text("Input and output controls")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                panelIconButton("Refresh", "arrow.clockwise") { store.refresh() }
                panelIconButton("Audio Processes", "waveform.path.ecg") { showsAudioProcesses = true }
            }

            VStack(spacing: 12) {
                DeviceRow(
                    title: store.outputDevice.name,
                    symbol: "speaker.wave.2.fill",
                    volume: Binding(get: { store.outputDevice.volume }, set: { store.setOutputVolume($0) }),
                    isMuted: Binding(get: { store.outputDevice.isMuted }, set: { store.setOutputMuted($0) }),
                    canSetVolume: store.outputDevice.canSetVolume,
                    canSetMute: store.outputDevice.canSetMute,
                    showsDisclosure: false
                )
                .padding(14)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 10))

                DeviceRow(
                    title: store.inputDevice.name,
                    symbol: "mic.fill",
                    volume: Binding(get: { store.inputDevice.volume }, set: { store.setInputVolume($0) }),
                    isMuted: Binding(get: { store.inputDevice.isMuted }, set: { store.setInputMuted($0) }),
                    canSetVolume: store.inputDevice.canSetVolume,
                    canSetMute: store.inputDevice.canSetMute,
                    showsDisclosure: false
                )
                .padding(14)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            SettingsSectionBox(title: "Device Notes") {
                SettingsValueRow(title: "Output device UID") {
                    Text(store.outputDevice.uid ?? "Unavailable")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                SettingsValueRow(title: "Input device UID") {
                    Text(store.inputDevice.uid ?? "Unavailable")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
    }

    private var routesDashboardContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Routes")
                        .font(.title2.weight(.semibold))
                    Text("Apps routed through the Core Audio tap backend")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                panelIconButton("Audio Processes", "waveform.path.ecg") { showsAudioProcesses = true }
            }

            routingStatus

            ScrollView {
                VStack(spacing: 10) {
                    ForEach(store.visibleApps.prefix(12)) { app in
                        RouteDashboardRow(
                            app: app,
                            volume: store.volumeBinding(for: app),
                            isMuted: store.mutedBinding(for: app),
                            isRouting: store.isRouting(app),
                            audioProcessCount: store.appAudioProcessCount(app),
                            isRunningOutput: store.appIsRunningOutput(app),
                            toggleRouting: { store.toggleRouting(for: app) }
                        )
                    }
                }
                .padding(.trailing, 4)
            }
        }
    }

    private var proConsole: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Audio Mixer")
                    .font(.headline.weight(.semibold))
                Spacer()
                styleSegment
                panelIconButton("Audio Processes", "waveform.path.ecg") { showsAudioProcesses = true }
                panelIconButton("Settings", "gearshape") { openSettings() }
            }

            routingStatus

            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 10) {
                    ForEach(store.visibleApps.prefix(7)) { app in
                        ConsoleChannelStrip(
                            app: app,
                            volume: store.volumeBinding(for: app),
                            isMuted: store.mutedBinding(for: app),
                            isRouting: store.isRouting(app),
                            isRunningOutput: store.appIsRunningOutput(app),
                            toggleRouting: { store.toggleRouting(for: app) }
                        )
                    }
                    MasterChannel(title: "Output", icon: "speaker.wave.2.fill", value: store.outputDevice.volume)
                    MasterChannel(title: "Input", icon: "mic.fill", value: store.inputDevice.volume)
                }
                .padding(.bottom, 6)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            LinearGradient(colors: [Color(red: 0.05, green: 0.07, blue: 0.08), Color(red: 0.10, green: 0.13, blue: 0.15)], startPoint: .top, endPoint: .bottom)
        )
        .foregroundStyle(.white)
    }

    private var routingMap: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Routing")
                    .font(.title2.weight(.semibold))
                styleSegment
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(store.visibleApps.prefix(7)) { app in
                            RouteSourceTile(
                                app: app,
                                volume: store.volumeBinding(for: app),
                                isRouting: store.isRouting(app),
                                isRunningOutput: store.appIsRunningOutput(app),
                                toggleRouting: { store.toggleRouting(for: app) }
                            )
                        }
                    }
                }
            }
            .frame(width: 230)

            VStack(spacing: 18) {
                routingStatus

                HStack(spacing: 12) {
                    ForEach(store.visibleApps.prefix(5)) { app in
                        Image(systemName: store.isRouting(app) ? "arrow.right.circle.fill" : "arrow.right.circle")
                            .font(.title2)
                            .foregroundStyle(store.isRouting(app) ? .orange : .secondary)
                    }
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 10) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundStyle(.orange)
                    Text(store.outputDevice.name)
                        .font(.headline)
                    Slider(value: Binding(get: { store.outputDevice.volume }, set: { store.setOutputVolume($0) }), in: 0...1)
                        .tint(.orange)
                }
                .padding(18)
                .frame(maxWidth: .infinity)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                Spacer()

                HStack {
                    panelIconButton("Processes", "waveform.path.ecg") { showsAudioProcesses = true }
                    panelIconButton("Hot Keys", "keyboard") { showsHotKeys = true }
                    panelIconButton("Settings", "gearshape") { openSettings() }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(red: 0.04, green: 0.08, blue: 0.09))
        .foregroundStyle(.white)
    }

    private var cardStack: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Audio Mixer")
                        .font(.title2.weight(.semibold))
                    Spacer()
                    styleSegment
                    panelIconButton("Settings", "gearshape") { openSettings() }
                }

                HStack(spacing: 12) {
                    deviceSummaryCard(title: "Output Device", icon: "speaker.wave.2.fill", device: store.outputDevice)
                    deviceSummaryCard(title: "Input", icon: "mic.fill", device: store.inputDevice)
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Active Apps")
                            .font(.headline)
                        Spacer()
                        Button {
                            store.refresh()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .buttonStyle(.borderless)
                    }

                    ForEach(store.visibleApps.prefix(8)) { app in
                        DashboardAppRow(
                            app: app,
                            volume: store.volumeBinding(for: app),
                            isMuted: store.mutedBinding(for: app),
                            isRouting: store.isRouting(app),
                            audioProcessCount: store.appAudioProcessCount(app),
                            isRunningOutput: store.appIsRunningOutput(app),
                            toggleRouting: { store.toggleRouting(for: app) }
                        )
                    }
                }
                .padding(14)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 10))

                routingStatus
            }
            .padding(18)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var dashboardToolbar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Apps")
                    .font(.title2.weight(.semibold))
                Text(store.settings.showActiveAudioOnly ? "Active audio only" : "Audio-capable apps")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Picker("Output", selection: .constant(store.outputDevice.name)) {
                Text(store.outputDevice.name).tag(store.outputDevice.name)
            }
            .labelsHidden()
            .frame(width: 190)

            panelIconButton("Audio Processes", "waveform.path.ecg") { showsAudioProcesses = true }
            panelIconButton("Settings", "gearshape") { openSettings() }
        }
    }

    private var styleSegment: some View {
        Picker("Interface", selection: Binding(
            get: { store.settings.interfaceStyle },
            set: { newValue in
                store.settings.interfaceStyle = newValue
                store.saveSettings()
            }
        )) {
            ForEach(MixerInterfaceStyle.allCases) { style in
                Text(style.displayName).tag(style)
            }
        }
        .labelsHidden()
        .frame(width: 190)
    }

    private func settingBinding(_ keyPath: WritableKeyPath<MixerSettings, Bool>) -> Binding<Bool> {
        Binding(
            get: { store.settings[keyPath: keyPath] },
            set: { newValue in
                store.settings[keyPath: keyPath] = newValue
                store.saveSettings()
            }
        )
    }

    private func checkboxFilter(_ title: String, _ keyPath: WritableKeyPath<MixerSettings, Bool>) -> some View {
        Toggle(title, isOn: settingBinding(keyPath))
            .toggleStyle(.checkbox)
            .font(.caption)
    }

    private func sidebarButton(_ title: String, _ icon: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(selected ? Color.orange : Color.clear)
                .foregroundStyle(selected ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private func panelIconButton(_ title: String, _ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 30, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(title)
    }

    private func deviceSummaryCard(title: String, icon: String, device: AudioDevice) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.orange)
                    .frame(width: 34, height: 34)
                    .background(Color.orange.opacity(0.12))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(device.name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                }

                Spacer()
            }

            ProgressView(value: device.volume)
                .tint(.orange)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var header: some View {
        HStack {
            Text("Audio Mixer")
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
                Text("Quit Audio Mixer")
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

struct AppIconBadge: View {
    let app: RunningAudioApp
    var size: CGFloat = 28

    var body: some View {
        Group {
            if let icon = app.icon {
                Image(nsImage: icon)
                    .resizable()
            } else {
                Image(systemName: "app.fill")
                    .resizable()
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: max(5, size * 0.2)))
    }
}

struct DashboardAppRow: View {
    let app: RunningAudioApp
    @Binding var volume: Double
    @Binding var isMuted: Bool
    let isRouting: Bool
    let audioProcessCount: Int
    let isRunningOutput: Bool
    let toggleRouting: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            AppIconBadge(app: app, size: 32)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(app.name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)

                    Circle()
                        .fill(isRunningOutput ? Color.green : Color.secondary.opacity(audioProcessCount > 0 ? 0.55 : 0.18))
                        .frame(width: 7, height: 7)
                }

                WaveformMini(isActive: isRunningOutput)
            }
            .frame(width: 150, alignment: .leading)

            Button {
                isMuted.toggle()
            } label: {
                Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 26)
            }
            .buttonStyle(.plain)

            Slider(value: $volume, in: 0...1)
                .tint(.orange)

            Text("\(Int(volume * 100))%")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 42, alignment: .trailing)

            Button(action: toggleRouting) {
                Label(isRouting ? "On" : "Route", systemImage: isRouting ? "record.circle.fill" : "record.circle")
                    .labelStyle(.iconOnly)
                    .foregroundStyle(isRouting ? .orange : .secondary)
                    .font(.system(size: 18, weight: .semibold))
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct RouteDashboardRow: View {
    let app: RunningAudioApp
    @Binding var volume: Double
    @Binding var isMuted: Bool
    let isRouting: Bool
    let audioProcessCount: Int
    let isRunningOutput: Bool
    let toggleRouting: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            AppIconBadge(app: app, size: 32)

            VStack(alignment: .leading, spacing: 3) {
                Text(app.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Label("\(audioProcessCount) process\(audioProcessCount == 1 ? "" : "es")", systemImage: "cpu")
                    Label(isRunningOutput ? "active" : "idle", systemImage: isRunningOutput ? "speaker.wave.2.fill" : "speaker")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                isMuted.toggle()
            } label: {
                Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.1.fill")
                    .frame(width: 28)
            }
            .buttonStyle(.plain)

            Slider(value: $volume, in: 0...1)
                .frame(width: 150)
                .tint(.orange)

            Button(action: toggleRouting) {
                Label(isRouting ? "Routed" : "Route", systemImage: isRouting ? "record.circle.fill" : "record.circle")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(isRouting ? Color.orange.opacity(0.18) : Color.secondary.opacity(0.12))
                    .foregroundStyle(isRouting ? .orange : .secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct ConsoleChannelStrip: View {
    let app: RunningAudioApp
    @Binding var volume: Double
    @Binding var isMuted: Bool
    let isRouting: Bool
    let isRunningOutput: Bool
    let toggleRouting: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text(app.name)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .frame(height: 18)

            AppIconBadge(app: app, size: 34)

            LevelMeter(value: isRunningOutput ? max(0.18, volume) : 0.08)
                .frame(height: 132)

            Slider(value: $volume, in: 0...1)
                .rotationEffect(.degrees(-90))
                .frame(width: 116, height: 30)
                .tint(.orange)
                .padding(.vertical, 28)

            Button {
                isMuted.toggle()
            } label: {
                Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.1.fill")
                    .frame(width: 28, height: 28)
                    .background(isMuted ? Color.orange : Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)

            Button(action: toggleRouting) {
                Text(isRouting ? "Routed" : "Route")
                    .font(.caption2.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(isRouting ? Color.orange : Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 7))
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .frame(width: 88)
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct MasterChannel: View {
    let title: String
    let icon: String
    let value: Double

    var body: some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.caption.weight(.semibold))
            Image(systemName: icon)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.orange)
                .frame(width: 44, height: 44)
                .background(Color.white.opacity(0.08))
                .clipShape(Circle())
            LevelMeter(value: value)
                .frame(height: 180)
            Text("\(Int(value * 100))%")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(width: 92)
        .background(Color.white.opacity(0.09))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct RouteSourceTile: View {
    let app: RunningAudioApp
    @Binding var volume: Double
    let isRouting: Bool
    let isRunningOutput: Bool
    let toggleRouting: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                AppIconBadge(app: app, size: 30)
                Text(app.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Spacer()
                Circle()
                    .fill(isRunningOutput ? Color.green : Color.secondary)
                    .frame(width: 7, height: 7)
            }

            HStack {
                Slider(value: $volume, in: 0...1)
                    .tint(isRouting ? .orange : .secondary)
                Text("\(Int(volume * 100))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 38)
            }
        }
        .padding(12)
        .background(isRouting ? Color.orange.opacity(0.18) : Color.white.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isRouting ? Color.orange : Color.white.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .onTapGesture(perform: toggleRouting)
    }
}

struct WaveformMini: View {
    let isActive: Bool

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<12, id: \.self) { index in
                Capsule()
                    .fill(isActive ? Color.orange.opacity(0.85) : Color.secondary.opacity(0.22))
                    .frame(width: 2, height: CGFloat([7, 12, 18, 10, 15, 8, 20, 11, 16, 9, 13, 6][index]))
            }
        }
        .frame(height: 20, alignment: .center)
    }
}

struct LevelMeter: View {
    let value: Double

    var body: some View {
        VStack(spacing: 3) {
            ForEach((0..<12).reversed(), id: \.self) { index in
                Capsule()
                    .fill(Double(index + 1) / 12 <= value ? meterColor(index) : Color.white.opacity(0.10))
                    .frame(width: 8, height: 8)
            }
        }
    }

    private func meterColor(_ index: Int) -> Color {
        if index > 8 {
            return .orange
        }
        return .green
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
        AppIconBadge(app: app, size: 24)
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
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Settings")
                    .font(.title2.weight(.semibold))

                SettingsSectionBox(title: "Appearance") {
                    SettingsValueRow(title: "Interface") {
                        Picker("Interface", selection: Binding(
                            get: { store.settings.interfaceStyle },
                            set: { newValue in
                                store.settings.interfaceStyle = newValue
                                store.saveSettings()
                            }
                        )) {
                            ForEach(MixerInterfaceStyle.allCases) { style in
                                Text(style.displayName).tag(style)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 220)
                    }

                    SettingsToggleRow(title: "Dock mixer in menu bar", binding: settingsBinding(\.dockInMenuBar))
                }

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
        .onExitCommand {
            dismiss()
        }
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

struct HelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Audio Mixer Guide")
                            .font(.largeTitle.weight(.semibold))
                        Text("Per-app volume, routing, and device control for macOS.")
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help("Close")
                }

                HelpSection(title: "Getting Started", symbol: "play.circle.fill") {
                    HelpStep(number: 1, text: "Start audio in the app you want to control.")
                    HelpStep(number: 2, text: "Find the app in the mixer list. The green dot means Core Audio sees active output.")
                    HelpStep(number: 3, text: "Move the app slider or click the circular route button. Audio Mixer will create a route for that app.")
                    HelpStep(number: 4, text: "Grant system audio capture permission if macOS asks.")
                }

                HelpSection(title: "Per-App Routing", symbol: "arrow.triangle.branch") {
                    HelpParagraph("The circular route button turns app routing on or off. When it is orange, the app is passing through Audio Mixer’s tap and IOProc, so volume, mute, and balance changes affect that app.")
                    HelpParagraph("Browsers and Electron apps may play audio through helper processes. Audio Mixer matches those helper processes automatically when possible.")
                }

                HelpSection(title: "Interface Styles", symbol: "rectangle.3.group") {
                    HelpShortcut(keys: "⌘1", label: "Sidebar Dashboard")
                    HelpShortcut(keys: "⌘2", label: "Pro Console")
                    HelpShortcut(keys: "⌘3", label: "Routing Map")
                    HelpShortcut(keys: "⌘4", label: "Card Stack")
                    HelpParagraph("You can also choose the interface style in Settings > Appearance.")
                }

                HelpSection(title: "Menu Bar Docking", symbol: "menubar.rectangle") {
                    HelpParagraph("Turn on Dock mixer in menu bar in Settings > Appearance to keep Audio Mixer available from the macOS menu bar.")
                    HelpParagraph("Turning it off removes the menu-bar control while keeping the normal app window and Dock behavior.")
                }

                HelpSection(title: "Sidebar Dashboard", symbol: "sidebar.left") {
                    HelpParagraph("Mixer shows app volume rows. Devices shows input and output device controls. Routes shows routing status, audio process counts, and per-app route toggles.")
                    HelpParagraph("Audio Processes is a debug view for inspecting the Core Audio process list.")
                }

                HelpSection(title: "Troubleshooting", symbol: "wrench.and.screwdriver.fill") {
                    HelpBullet("If an app slider does nothing, make sure the route button is orange.")
                    HelpBullet("If an app is missing, turn off Active Only or use Audio Processes to inspect its bundle ID.")
                    HelpBullet("If routing fails after an app restarts, toggle the route off and on again.")
                    HelpBullet("If macOS denied capture permission, enable it in System Settings and relaunch Audio Mixer.")
                }

                HelpSection(title: "Keyboard And Windows", symbol: "keyboard") {
                    HelpShortcut(keys: "Esc", label: "Close Settings or this Help window")
                    HelpShortcut(keys: "⌘Q", label: "Quit Audio Mixer")
                    HelpShortcut(keys: "⌘?", label: "Open this guide")
                }

                HelpSection(title: "Packaging", symbol: "shippingbox.fill") {
                    HelpParagraph("Use Scripts/package.sh to build the local app bundle. In this development environment, DMG creation may fall back to a zip.")
                    HelpParagraph("For public distribution, sign with Developer ID and notarize the app or DMG with Apple.")
                }
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onExitCommand {
            dismiss()
        }
    }
}

struct HelpSection<Content: View>: View {
    let title: String
    let symbol: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: symbol)
                .font(.title3.weight(.semibold))

            VStack(alignment: .leading, spacing: 10) {
                content
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}

struct HelpStep: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(String(number))
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Color.orange)
                .clipShape(Circle())

            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct HelpParagraph: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct HelpBullet: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.orange)
                .font(.caption)
                .padding(.top, 3)
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct HelpShortcut: View {
    let keys: String
    let label: String

    var body: some View {
        HStack(spacing: 12) {
            Text(keys)
                .font(.system(.body, design: .monospaced).weight(.medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(nsColor: .separatorColor).opacity(0.25))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            Text(label)
        }
    }
}
