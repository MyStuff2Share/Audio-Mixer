import SwiftUI
import AppKit

@main
struct AudioMixerApp: App {
    @StateObject private var store = MixerStore()
    @Environment(\.openWindow) private var openWindow

    init() {
        LaunchDiagnostics.recordLaunch()
        NSApplication.shared.setActivationPolicy(.regular)

        DispatchQueue.main.async {
            NotificationCenter.default.addObserver(
                forName: NSWindow.didResignMainNotification,
                object: nil,
                queue: .main
            ) { _ in
                updateDockVisibility()
            }

            NotificationCenter.default.addObserver(
                forName: NSWindow.didBecomeMainNotification,
                object: nil,
                queue: .main
            ) { _ in
                NSApplication.shared.setActivationPolicy(.regular)
            }
        }
    }

    var body: some Scene {
        WindowGroup("Audio Mixer", id: "main") {
            MixerPanel()
                .environmentObject(store)
                .frame(
                    minWidth: 680,
                    idealWidth: 760,
                    maxWidth: .infinity,
                    minHeight: 460,
                    idealHeight: 520,
                    maxHeight: .infinity
                )
                .onAppear {
                    store.start()
                    NSApplication.shared.setActivationPolicy(.regular)
                }
                .onDisappear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        updateDockVisibility()
                    }
                }
        }
        .defaultSize(width: 760, height: 520)

        MenuBarExtra {
            MenuBarWidget()
                .environmentObject(store)
                .frame(width: 320, height: 450)
        } label: {
            Label("Audio Mixer", systemImage: store.isEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(store)
                .frame(width: 600, height: 500)
        }

        Window("Audio Mixer Help", id: "help") {
            HelpView()
                .frame(width: 680, height: 620)
        }
        .defaultSize(width: 680, height: 620)

        .commands {
            CommandMenu("Interface") {
                Button("Sidebar Dashboard") {
                    setInterfaceStyle(.sidebarDashboard)
                }
                .keyboardShortcut("1", modifiers: .command)

                Button("Pro Console") {
                    setInterfaceStyle(.proConsole)
                }
                .keyboardShortcut("2", modifiers: .command)

                Button("Routing Map") {
                    setInterfaceStyle(.routingMap)
                }
                .keyboardShortcut("3", modifiers: .command)

                Button("Card Stack") {
                    setInterfaceStyle(.cardStack)
                }
                .keyboardShortcut("4", modifiers: .command)
            }

            CommandGroup(replacing: .help) {
                Button("Audio Mixer Help") {
                    openWindow(id: "help")
                }
                .keyboardShortcut("?", modifiers: .command)

                Divider()

                Button("Close Window") {
                    NSApplication.shared.keyWindow?.close()
                }
                .keyboardShortcut("w", modifiers: .command)
            }
        }
    }

    private func setInterfaceStyle(_ style: MixerInterfaceStyle) {
        store.settings.interfaceStyle = style
        store.saveSettings()
    }
}

@MainActor
private func updateDockVisibility() {
    let hasVisibleWindows = NSApplication.shared.windows.contains { window in
        !window.isSheet && window.title != "Audio Mixer Help" && window.isVisible
    }

    let newPolicy: NSApplication.ActivationPolicy = hasVisibleWindows ? .regular : .accessory
    NSApplication.shared.setActivationPolicy(newPolicy)
}
