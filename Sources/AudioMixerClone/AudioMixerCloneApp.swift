import SwiftUI

@main
struct AudioMixerCloneApp: App {
    @StateObject private var store = MixerStore()

    init() {
        LaunchDiagnostics.recordLaunch()
    }

    var body: some Scene {
        WindowGroup("Audio Mixer") {
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
                }
        }
        .defaultSize(width: 760, height: 520)

        MenuBarExtra {
            MixerPanel()
                .environmentObject(store)
                .frame(width: 760, height: 520)
                .onAppear {
                    store.start()
                }
        } label: {
            Label("Audio Mixer", systemImage: store.isEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(store)
                .frame(width: 600, height: 500)
        }
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
        }
    }

    private func setInterfaceStyle(_ style: MixerInterfaceStyle) {
        store.settings.interfaceStyle = style
        store.saveSettings()
    }
}
