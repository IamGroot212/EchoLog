import SwiftUI

@main
struct EchoLogApp: App {
    @State private var recordingController = RecordingController()
    @State private var showOnboarding = !AppSettings.shared.hasCompletedOnboarding

    var body: some Scene {
        MenuBarExtra("EchoLog", systemImage: recordingController.isRecording ? "record.circle" : "waveform") {
            MenuBarView()
                .environment(recordingController)
                .task {
                    recordingController.setupHotkey()
                }
                .sheet(isPresented: $showOnboarding) {
                    OnboardingView()
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
