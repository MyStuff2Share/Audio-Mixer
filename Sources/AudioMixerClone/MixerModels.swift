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
    var autoRoute: Bool

    static func fresh(for app: RunningAudioApp, remember: Bool) -> AppAudioProfile {
        AppAudioProfile(
            id: app.id,
            displayName: app.name,
            volume: 0.82,
            isMuted: false,
            balance: 0,
            eqEnabled: false,
            routeName: nil,
            remember: remember,
            autoRoute: false
        )
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case displayName
        case volume
        case isMuted
        case balance
        case eqEnabled
        case routeName
        case remember
        case autoRoute
    }

    init(
        id: String,
        displayName: String,
        volume: Double,
        isMuted: Bool,
        balance: Double,
        eqEnabled: Bool,
        routeName: String?,
        remember: Bool,
        autoRoute: Bool
    ) {
        self.id = id
        self.displayName = displayName
        self.volume = volume
        self.isMuted = isMuted
        self.balance = balance
        self.eqEnabled = eqEnabled
        self.routeName = routeName
        self.remember = remember
        self.autoRoute = autoRoute
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        displayName = try container.decode(String.self, forKey: .displayName)
        volume = try container.decode(Double.self, forKey: .volume)
        isMuted = try container.decode(Bool.self, forKey: .isMuted)
        balance = try container.decode(Double.self, forKey: .balance)
        eqEnabled = try container.decode(Bool.self, forKey: .eqEnabled)
        routeName = try container.decodeIfPresent(String.self, forKey: .routeName)
        remember = try container.decodeIfPresent(Bool.self, forKey: .remember) ?? true
        autoRoute = try container.decodeIfPresent(Bool.self, forKey: .autoRoute) ?? false
    }
}

enum MixerInterfaceStyle: String, Codable, CaseIterable, Identifiable {
    case sidebarDashboard
    case proConsole
    case routingMap
    case cardStack

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sidebarDashboard:
            "Sidebar Dashboard"
        case .proConsole:
            "Pro Console"
        case .routingMap:
            "Routing Map"
        case .cardStack:
            "Card Stack"
        }
    }
}

struct MixerSettings: Codable, Equatable {
    var interfaceStyle: MixerInterfaceStyle = .sidebarDashboard
    var dockInMenuBar = false
    var hasConfiguredMenuBarDocking = false
    var rememberAppProfiles = true
    var showInactiveProfiles = false
    var hideAppsWithoutAudioProcesses = true
    var showActiveAudioOnly = false
    var autoRouteWhenAdjusting = true
    var launchAtLogin = false
    var shortcutStep = 5.0

    private enum CodingKeys: String, CodingKey {
        case interfaceStyle
        case dockInMenuBar
        case hasConfiguredMenuBarDocking
        case rememberAppProfiles
        case showInactiveProfiles
        case hideAppsWithoutAudioProcesses
        case showActiveAudioOnly
        case autoRouteWhenAdjusting
        case launchAtLogin
        case shortcutStep
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        interfaceStyle = try container.decodeIfPresent(MixerInterfaceStyle.self, forKey: .interfaceStyle) ?? .sidebarDashboard
        hasConfiguredMenuBarDocking = try container.decodeIfPresent(Bool.self, forKey: .hasConfiguredMenuBarDocking) ?? false
        dockInMenuBar = hasConfiguredMenuBarDocking ? (try container.decodeIfPresent(Bool.self, forKey: .dockInMenuBar) ?? false) : false
        rememberAppProfiles = try container.decodeIfPresent(Bool.self, forKey: .rememberAppProfiles) ?? true
        showInactiveProfiles = try container.decodeIfPresent(Bool.self, forKey: .showInactiveProfiles) ?? false
        hideAppsWithoutAudioProcesses = try container.decodeIfPresent(Bool.self, forKey: .hideAppsWithoutAudioProcesses) ?? true
        showActiveAudioOnly = try container.decodeIfPresent(Bool.self, forKey: .showActiveAudioOnly) ?? false
        autoRouteWhenAdjusting = try container.decodeIfPresent(Bool.self, forKey: .autoRouteWhenAdjusting) ?? true
        launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
        shortcutStep = try container.decodeIfPresent(Double.self, forKey: .shortcutStep) ?? 5.0
    }
}
