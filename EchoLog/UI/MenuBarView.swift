import SwiftUI

struct MenuBarView: View {
    @Environment(RecordingController.self) private var controller
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Text("EchoLog").font(.headline)
                Spacer()
                if controller.isRecording {
                    Circle()
                        .fill(.red)
                        .frame(width: 8, height: 8)
                }
            }

            Text(controller.statusText)
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            // Capture mode picker
            if !controller.isRecording && !controller.isProcessing {
                @Bindable var ctrl = controller
                Menu("Mode: \(modeLabel)") {
                    Button("System Audio") { ctrl.selectedMode = .systemAudio }
                    Button("Microphone") { ctrl.selectedMode = .microphone }
                    Divider()
                    if controller.availableApps.isEmpty {
                        Button("Load Apps...") {
                            Task { await controller.loadAvailableApps() }
                        }
                    } else {
                        ForEach(controller.availableApps) { app in
                            Button(app.displayName) {
                                ctrl.selectedMode = .perApp(bundleIdentifier: app.bundleIdentifier)
                            }
                        }
                    }
                }
                .menuStyle(.borderlessButton)
            }

            // Start / Stop
            if controller.isRecording {
                Button("Stop & Process") {
                    Task { await controller.stopRecording() }
                }
            } else if controller.isProcessing {
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Button("Start Recording") {
                    Task { await controller.startRecording() }
                }
            }

            // Hotkey hint
            Text("⌘⇧R to toggle")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            // Recent sessions
            let sessions = SessionManager.shared.sessions
            if !sessions.isEmpty {
                Divider()
                Text("Recent").font(.caption).foregroundStyle(.secondary)
                ForEach(sessions.prefix(3)) { session in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.folderName)
                            .font(.caption2)
                            .foregroundStyle(.primary)
                        HStack(spacing: 4) {
                            if session.transcriptFileName != nil {
                                Image(systemName: "doc.text.fill").foregroundStyle(.green)
                            }
                            if session.summaryFileName != nil {
                                Image(systemName: "text.badge.star").foregroundStyle(.blue)
                            }
                        }
                        .font(.caption2)
                    }
                }
            }

            Divider()

            Button("Session History...") {
                openWindow(id: "history")
            }
            Button("Settings...") {
                openWindow(id: "settings")
            }

            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding()
        .frame(width: 280)
        .onAppear {
            SessionManager.shared.loadSessions()
        }
    }

    // MARK: - Mode Label

    private var modeLabel: String {
        switch controller.selectedMode {
        case .systemAudio: return "System Audio"
        case .microphone: return "Microphone"
        case .perApp(let id):
            return controller.availableApps.first { $0.bundleIdentifier == id }?.displayName ?? id
        }
    }
}
