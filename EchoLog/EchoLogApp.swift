import SwiftUI

@main
struct EchoLogApp: App {
    var body: some Scene {
        MenuBarExtra("EchoLog", systemImage: "waveform") {
            MenuBarView()
        }

        Window("Settings", id: "settings") {
            SettingsView()
        }
        .defaultSize(width: 600, height: 500)

        Window("Session History", id: "history") {
            SessionHistoryView()
        }
        .defaultSize(width: 700, height: 500)
    }
}
