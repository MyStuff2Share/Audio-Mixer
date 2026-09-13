import SwiftUI

@main
struct AudioMixerCloneApp: App {
    @StateObject private var store = MixerStore()

    init() {
        LaunchDiagnostics.recordLaunch()
    }

    var body: some Scene {
        WindowGroup("AudioMixerClone") {
            MixerPanel()
                .environmentObject(store)
                .frame(width: 760, height: 520)
                .onAppear {
                    store.start()
                }
        }
        .windowResizability(.contentSize)

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
    }
}
