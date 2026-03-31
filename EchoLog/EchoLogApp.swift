import SwiftUI

@main
struct EchoLogApp: App {
    @State private var recordingController = RecordingController()

    var body: some Scene {
        MenuBarExtra("EchoLog", systemImage: recordingController.isRecording ? "record.circle" : "waveform") {
            MenuBarView()
                .environment(recordingController)
                .task {
                    recordingController.setupHotkey()
                }
        }

        Window("Settings", id: "settings") {
            SettingsView()
                .environment(recordingController)
        }
        .defaultSize(width: 600, height: 500)

        Window("Session History", id: "history") {
            SessionHistoryView()
        }
        .defaultSize(width: 700, height: 500)
    }
}
