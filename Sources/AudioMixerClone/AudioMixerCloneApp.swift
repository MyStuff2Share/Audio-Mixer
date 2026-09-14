import SwiftUI

@main
struct AudioMixerCloneApp: App {
    @StateObject private var store = MixerStore()
    @Environment(\.openWindow) private var openWindow

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

        MenuBarExtra(isInserted: menuBarDockingBinding) {
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
            }
        }
    }

    private func setInterfaceStyle(_ style: MixerInterfaceStyle) {
        store.settings.interfaceStyle = style
        store.saveSettings()
    }

    private var menuBarDockingBinding: Binding<Bool> {
        Binding(
            get: { store.settings.dockInMenuBar },
            set: { isEnabled in
                store.settings.dockInMenuBar = isEnabled
                store.saveSettings()
            }
        )
    }
}
