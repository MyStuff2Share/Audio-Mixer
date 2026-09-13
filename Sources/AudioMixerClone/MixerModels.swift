import AppKit
import CoreAudio

struct AudioDevice: Identifiable, Equatable {
    let id: AudioObjectID
    var uid: String?
    var name: String
    var volume: Double
    var isMuted: Bool
    var canSetVolume: Bool
    var canSetMute: Bool
    var isInput: Bool
}

struct RunningAudioApp: Identifiable, Equatable {
    let id: String
    var bundleIdentifier: String
    var name: String
    var processIdentifier: pid_t
    var icon: NSImage?

    static func == (lhs: RunningAudioApp, rhs: RunningAudioApp) -> Bool {
        lhs.id == rhs.id &&
        lhs.name == rhs.name &&
        lhs.processIdentifier == rhs.processIdentifier
    }
}

struct AppAudioProfile: Codable, Equatable, Identifiable {
    let id: String
    var displayName: String
    var volume: Double
    var isMuted: Bool
    var balance: Double
    var eqEnabled: Bool
    var routeName: String?
    var remember: Bool

    static func fresh(for app: RunningAudioApp, remember: Bool) -> AppAudioProfile {
        AppAudioProfile(
            id: app.id,
            displayName: app.name,
            volume: 0.82,
            isMuted: false,
            balance: 0,
            eqEnabled: false,
            routeName: nil,
            remember: remember
        )
    }
}

struct MixerSettings: Codable, Equatable {
    var rememberAppProfiles = true
    var showInactiveProfiles = false
    var launchAtLogin = false
    var shortcutStep = 5.0
}
