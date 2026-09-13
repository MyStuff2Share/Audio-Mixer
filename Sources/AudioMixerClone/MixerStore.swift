import AppKit
import Combine
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
    @Published var routingMessage: String?

    private let deviceController = CoreAudioDeviceController()
    private let routingService: AudioRoutingService = CoreAudioTapRoutingService()
    private var refreshTimer: Timer?

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
        outputDevice = deviceController.defaultDevice(isInput: false)
        inputDevice = deviceController.defaultDevice(isInput: true)
        load()
        refresh()
    }

    func start() {
        guard refreshTimer == nil else {
            return
        }

        refreshTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
    }

    func refresh() {
        outputDevice = deviceController.defaultDevice(isInput: false)
        inputDevice = deviceController.defaultDevice(isInput: true)
        runningApps = NSWorkspace.shared.runningApplications
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
                    icon: application.icon
                )
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        for app in runningApps where profiles[app.id] == nil {
            profiles[app.id] = AppAudioProfile.fresh(for: app, remember: settings.rememberAppProfiles)
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

    func isRouting(_ app: RunningAudioApp) -> Bool {
        activeRoutes[app.bundleIdentifier] != nil
    }

    func routeDetail(for app: RunningAudioApp) -> String? {
        activeRoutes[app.bundleIdentifier]?.streamDescription
    }

    func toggleRouting(for app: RunningAudioApp) {
        do {
            if isRouting(app) {
                try routingService.stopRouting(bundleIdentifier: app.bundleIdentifier)
                activeRoutes.removeValue(forKey: app.bundleIdentifier)
                routingMessage = "Stopped tap for \(app.name)."
            } else {
                let snapshot = try routingService.startRouting(app: app, outputDevice: outputDevice, profile: profile(for: app))
                activeRoutes[app.bundleIdentifier] = snapshot
                routingMessage = "Routing \(app.name): \(snapshot.processObjectIDs.count) audio process(es), \(snapshot.streamDescription)."
            }
        } catch {
            routingMessage = error.localizedDescription
        }
    }

    func volumeBinding(for app: RunningAudioApp) -> Binding<Double> {
        Binding(
            get: { self.profile(for: app).volume },
            set: { newValue in
                var profile = self.profile(for: app)
                profile.volume = newValue
                self.setProfile(profile)
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
            }
        )
    }

    private func refreshRouteSnapshot(bundleIdentifier: String) {
        activeRoutes[bundleIdentifier] = routingService.snapshot(bundleIdentifier: bundleIdentifier)
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
