import AppKit
import Combine
import CoreAudio
import Foundation
import SwiftUI

@MainActor
final class MixerStore: ObservableObject {
    @Published var isEnabled = true
    @Published var outputDevice: AudioDevice
    @Published var inputDevice: AudioDevice
    @Published var runningApps: [RunningAudioApp] = []
    @Published var profiles: [String: AppAudioProfile] = [:]
    @Published var settings = MixerSettings()
    @Published var selectedControlMode = 0
    @Published var activeRoutes: [String: AppRouteSnapshot] = [:]
    @Published var audioProcesses: [AudioProcessSnapshot] = []
    @Published var routingMessage: String?

    private let deviceController = CoreAudioDeviceController()
    private let routingService: AudioRoutingService = CoreAudioTapRoutingService()
    private let refreshQueue = DispatchQueue(label: "com.example.AudioMixerClone.refresh", qos: .utility)
    private let iconQueue = DispatchQueue(label: "com.example.AudioMixerClone.icons", qos: .utility)
    private var refreshTimer: Timer?
    private var isRefreshInFlight = false
    private var refreshGeneration = 0
    private var iconGeneration = 0

    private var supportDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("AudioMixerClone", isDirectory: true)
    }

    private var profilesURL: URL {
        supportDirectory.appendingPathComponent("profiles.json")
    }

    private var settingsURL: URL {
        supportDirectory.appendingPathComponent("settings.json")
    }

    init() {
        outputDevice = Self.placeholderDevice(name: "Output Device", isInput: false)
        inputDevice = Self.placeholderDevice(name: "Input Device", isInput: true)
        load()
    }

    func start() {
        guard refreshTimer == nil else {
            return
        }

        refresh()

        refreshTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
    }

    func refresh() {
        refresh(includeAudioHardware: false)
    }

    func refreshAudioHardware() {
        refresh(includeAudioHardware: true)
    }

    private func refresh(includeAudioHardware: Bool) {
        guard !isRefreshInFlight else {
            return
        }

        isRefreshInFlight = true
        refreshGeneration += 1
        let generation = refreshGeneration
        LaunchDiagnostics.record(includeAudioHardware ? "Audio refresh started" : "App refresh started")
        scheduleRefreshTimeout(generation: generation)

        refreshQueue.async { [weak self] in
            let runningApplications = Self.readRunningApplications()
            let outputDevice: AudioDevice?
            let inputDevice: AudioDevice?
            let audioProcesses: [AudioProcessSnapshot]?

            if includeAudioHardware {
                LaunchDiagnostics.record("CoreAudio scan started")
                let backgroundDeviceController = CoreAudioDeviceController()
                outputDevice = backgroundDeviceController.defaultDevice(isInput: false)
                inputDevice = backgroundDeviceController.defaultDevice(isInput: true)
                audioProcesses = CoreAudioTapRoutingService().audioProcesses()
                LaunchDiagnostics.record("CoreAudio scan finished")
            } else {
                outputDevice = nil
                inputDevice = nil
                audioProcesses = nil
            }

            Task { @MainActor in
                guard let self else {
                    return
                }
                guard self.refreshGeneration == generation else {
                    return
                }

                if let outputDevice, let inputDevice, let audioProcesses {
                    self.outputDevice = outputDevice
                    self.inputDevice = inputDevice
                    self.audioProcesses = audioProcesses
                }
                self.runningApps = runningApplications

                for app in self.runningApps where self.profiles[app.id] == nil {
                    self.profiles[app.id] = AppAudioProfile.fresh(for: app, remember: self.settings.rememberAppProfiles)
                }

                if includeAudioHardware {
                    self.reconcileActiveRoutes()
                    self.startSavedAutoRoutes()
                }

                self.isRefreshInFlight = false
                LaunchDiagnostics.record(includeAudioHardware ? "Audio refresh finished" : "App refresh finished")
                self.loadIcons(for: runningApplications)
            }
        }
    }

    private func scheduleRefreshTimeout(generation: Int) {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 8_000_000_000)
            guard isRefreshInFlight, refreshGeneration == generation else {
                return
            }

            isRefreshInFlight = false
            routingMessage = "Refresh is taking longer than expected; mixer controls remain available."
            LaunchDiagnostics.record("Refresh timed out")
        }
    }

    nonisolated private static func placeholderDevice(name: String, isInput: Bool) -> AudioDevice {
        AudioDevice(
            id: AudioObjectID(kAudioObjectUnknown),
            uid: nil,
            name: name,
            volume: 0.75,
            isMuted: false,
            canSetVolume: false,
            canSetMute: false,
            isInput: isInput
        )
    }

    nonisolated private static func readRunningApplications() -> [RunningAudioApp] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { application in
                guard let bundleIdentifier = application.bundleIdentifier else {
                    return nil
                }

                return RunningAudioApp(
                    id: bundleIdentifier,
                    bundleIdentifier: bundleIdentifier,
                    name: application.localizedName ?? bundleIdentifier,
                    processIdentifier: application.processIdentifier,
                    bundleURLPath: application.bundleURL?.path,
                    icon: nil
                )
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func loadIcons(for apps: [RunningAudioApp]) {
        iconGeneration += 1
        let generation = iconGeneration
        let iconRequests = apps.compactMap { app -> (id: String, path: String)? in
            guard let path = app.bundleURLPath else {
                return nil
            }

            return (app.id, path)
        }

        guard !iconRequests.isEmpty else {
            return
        }

        iconQueue.async { [weak self] in
            var icons: [String: NSImage] = [:]
            for request in iconRequests {
                let icon = NSWorkspace.shared.icon(forFile: request.path)
                icon.size = NSSize(width: 64, height: 64)
                icons[request.id] = icon
            }

            Task { @MainActor in
                guard let self, self.iconGeneration == generation else {
                    return
                }

                self.runningApps = self.runningApps.map { app in
                    var updated = app
                    updated.icon = icons[app.id]
                    return updated
                }
            }
        }
    }

    func setOutputVolume(_ volume: Double) {
        guard outputDevice.canSetVolume else {
            return
        }

        outputDevice.volume = volume
        deviceController.setVolume(volume, for: outputDevice)
        refresh()
    }

    func setInputVolume(_ volume: Double) {
        guard inputDevice.canSetVolume else {
            return
        }

        inputDevice.volume = volume
        deviceController.setVolume(volume, for: inputDevice)
        refresh()
    }

    func setOutputMuted(_ muted: Bool) {
        guard outputDevice.canSetMute else {
            return
        }

        outputDevice.isMuted = muted
        deviceController.setMuted(muted, for: outputDevice)
        refresh()
    }

    func setInputMuted(_ muted: Bool) {
        guard inputDevice.canSetMute else {
            return
        }

        inputDevice.isMuted = muted
        deviceController.setMuted(muted, for: inputDevice)
        refresh()
    }

    func profile(for app: RunningAudioApp) -> AppAudioProfile {
        profiles[app.id] ?? AppAudioProfile.fresh(for: app, remember: settings.rememberAppProfiles)
    }

    func setProfile(_ profile: AppAudioProfile) {
        profiles[profile.id] = profile
        routingService.updateParameters(
            bundleIdentifier: profile.id,
            parameters: AppRouteParameters(
                volume: profile.volume,
                isMuted: profile.isMuted,
                balance: profile.balance
            )
        )
        refreshRouteSnapshot(bundleIdentifier: profile.id)
        saveProfiles()
    }

    var visibleApps: [RunningAudioApp] {
        runningApps.filter { app in
            if isRouting(app) {
                return true
            }

            let profile = profiles[app.id]
            let hasAudioProcess = appAudioProcesses(app).isEmpty == false
            let isActiveOutput = appIsRunningOutput(app)

            if settings.showActiveAudioOnly {
                return isActiveOutput || (profile?.autoRoute == true && hasAudioProcess)
            }

            if settings.hideAppsWithoutAudioProcesses {
                guard !audioProcesses.isEmpty else {
                    return true
                }

                return hasAudioProcess || profile?.autoRoute == true
            }

            return true
        }
    }

    func isRouting(_ app: RunningAudioApp) -> Bool {
        activeRoutes[app.bundleIdentifier] != nil
    }

    func routeDetail(for app: RunningAudioApp) -> String? {
        activeRoutes[app.bundleIdentifier]?.streamDescription
    }

    func toggleRouting(for app: RunningAudioApp) {
        if isRouting(app) {
            stopRouting(for: app, persistAutoRoute: true)
        } else {
            startRouting(for: app, persistAutoRoute: true, showMessage: true)
        }
    }

    func appAudioProcessCount(_ app: RunningAudioApp) -> Int {
        appAudioProcesses(app).count
    }

    func appIsRunningOutput(_ app: RunningAudioApp) -> Bool {
        appAudioProcesses(app).contains { $0.isRunningOutput }
    }

    func audioProcessRows() -> [AudioProcessSnapshot] {
        audioProcesses.sorted { left, right in
            let leftName = left.bundleIdentifier ?? ""
            let rightName = right.bundleIdentifier ?? ""
            if leftName == rightName {
                return (left.processIdentifier ?? 0) < (right.processIdentifier ?? 0)
            }
            return leftName.localizedCaseInsensitiveCompare(rightName) == .orderedAscending
        }
    }

    private func startRouting(for app: RunningAudioApp, persistAutoRoute: Bool, showMessage: Bool) {
        do {
            let snapshot = try routingService.startRouting(app: app, outputDevice: outputDevice, profile: profile(for: app))
            activeRoutes[app.bundleIdentifier] = snapshot

            if persistAutoRoute {
                var profile = profile(for: app)
                profile.autoRoute = true
                profiles[profile.id] = profile
                saveProfiles()
            }

            if showMessage {
                routingMessage = "Routing \(app.name): \(snapshot.processObjectIDs.count) audio process(es), \(snapshot.streamDescription)."
            }
        } catch {
            if showMessage {
                routingMessage = error.localizedDescription
            }
        }
    }

    private func stopRouting(for app: RunningAudioApp, persistAutoRoute: Bool) {
        do {
            try routingService.stopRouting(bundleIdentifier: app.bundleIdentifier)
            activeRoutes.removeValue(forKey: app.bundleIdentifier)

            if persistAutoRoute {
                var profile = profile(for: app)
                profile.autoRoute = false
                profiles[profile.id] = profile
                saveProfiles()
            }

            routingMessage = "Stopped tap for \(app.name)."
        } catch {
            routingMessage = error.localizedDescription
        }
    }

    private func ensureRoutingIfNeeded(for app: RunningAudioApp) {
        guard settings.autoRouteWhenAdjusting, !isRouting(app) else {
            return
        }

        startRouting(for: app, persistAutoRoute: true, showMessage: true)
    }

    func volumeBinding(for app: RunningAudioApp) -> Binding<Double> {
        Binding(
            get: { self.profile(for: app).volume },
            set: { newValue in
                var profile = self.profile(for: app)
                profile.volume = newValue
                self.setProfile(profile)
                self.ensureRoutingIfNeeded(for: app)
            }
        )
    }

    func mutedBinding(for app: RunningAudioApp) -> Binding<Bool> {
        Binding(
            get: { self.profile(for: app).isMuted },
            set: { newValue in
                var profile = self.profile(for: app)
                profile.isMuted = newValue
                self.setProfile(profile)
                self.ensureRoutingIfNeeded(for: app)
            }
        )
    }

    func balanceBinding(for app: RunningAudioApp) -> Binding<Double> {
        Binding(
            get: { self.profile(for: app).balance },
            set: { newValue in
                var profile = self.profile(for: app)
                profile.balance = newValue
                self.setProfile(profile)
                self.ensureRoutingIfNeeded(for: app)
            }
        )
    }

    private func refreshRouteSnapshot(bundleIdentifier: String) {
        activeRoutes[bundleIdentifier] = routingService.snapshot(bundleIdentifier: bundleIdentifier)
    }

    private func appAudioProcesses(_ app: RunningAudioApp) -> [AudioProcessSnapshot] {
        audioProcesses.filter { process in
            guard let bundleIdentifier = process.bundleIdentifier else {
                return false
            }

            return bundleIdentifier == app.bundleIdentifier ||
                bundleIdentifier.hasPrefix("\(app.bundleIdentifier).")
        }
    }

    private func reconcileActiveRoutes() {
        let appsByBundleID = Dictionary(uniqueKeysWithValues: runningApps.map { ($0.bundleIdentifier, $0) })

        for (bundleIdentifier, snapshot) in Array(activeRoutes) {
            guard let app = appsByBundleID[bundleIdentifier] else {
                do {
                    try routingService.stopRouting(bundleIdentifier: bundleIdentifier)
                    activeRoutes.removeValue(forKey: bundleIdentifier)
                    routingMessage = "Stopped stale route for \(snapshot.displayName)."
                } catch {
                    routingMessage = error.localizedDescription
                }
                continue
            }

            let currentProcessIDs = Set(appAudioProcesses(app).map(\.id))
            if currentProcessIDs.isEmpty {
                stopRouting(for: app, persistAutoRoute: false)
                routingMessage = "\(app.name) stopped producing audio; route cleaned up."
                continue
            }

            let routedProcessIDs = Set(snapshot.processObjectIDs)
            if routedProcessIDs.isDisjoint(with: currentProcessIDs) {
                stopRouting(for: app, persistAutoRoute: false)
                startRouting(for: app, persistAutoRoute: false, showMessage: false)
                routingMessage = "Recovered route for \(app.name)."
            }
        }
    }

    private func startSavedAutoRoutes() {
        for app in runningApps {
            guard profile(for: app).autoRoute, !isRouting(app), appIsRunningOutput(app) else {
                continue
            }

            startRouting(for: app, persistAutoRoute: false, showMessage: false)
        }
    }

    func saveSettings() {
        write(settings, to: settingsURL)
    }

    private func load() {
        try? FileManager.default.createDirectory(at: supportDirectory, withIntermediateDirectories: true)

        if let loadedProfiles: [String: AppAudioProfile] = read([String: AppAudioProfile].self, from: profilesURL) {
            profiles = loadedProfiles
        }

        if let loadedSettings: MixerSettings = read(MixerSettings.self, from: settingsURL) {
            settings = loadedSettings
        }
    }

    private func saveProfiles() {
        guard settings.rememberAppProfiles else {
            return
        }

        write(profiles.filter { $0.value.remember }, to: profilesURL)
    }

    private func read<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }

        return try? JSONDecoder().decode(type, from: data)
    }

    private func write<T: Encodable>(_ value: T, to url: URL) {
        try? FileManager.default.createDirectory(at: supportDirectory, withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(value) else {
            return
        }

        try? data.write(to: url, options: .atomic)
    }
}
