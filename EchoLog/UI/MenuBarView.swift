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
                    PulsingDot()
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
                    Button("Microphone Only") { ctrl.selectedMode = .microphoneOnly }
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

            // Start / Stop + Mic Mute
            if controller.isRecording {
                HStack {
                    Button("Stop & Process") {
                        Task { await controller.stopRecording() }
                    }
                    Spacer()
                    // Mic mute toggle (only for modes that include mic)
                    if controller.selectedMode != .microphoneOnly {
                        Button {
                            controller.toggleMic()
                        } label: {
                            Image(systemName: controller.isMicMuted ? "mic.slash.fill" : "mic.fill")
                                .foregroundStyle(controller.isMicMuted ? .red : .green)
                        }
                        .buttonStyle(.borderless)
                        .help(controller.isMicMuted ? "Unmute microphone" : "Mute microphone")
                    }
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

            // Hotkey hints
            HStack(spacing: 8) {
                Text("⌘⇧R record")
                if controller.isRecording && controller.selectedMode != .microphoneOnly {
                    Text("⌘⇧M mute mic")
                }
            }
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
        case .microphoneOnly: return "Microphone Only"
        case .perApp(let id):
            return controller.availableApps.first { $0.bundleIdentifier == id }?.displayName ?? id
        }
    }
}

// MARK: - Pulsing Recording Indicator

struct PulsingDot: View {
    @State private var isPulsing = false

    var body: some View {
        Circle()
            .fill(.red)
            .frame(width: 8, height: 8)
            .scaleEffect(isPulsing ? 1.4 : 1.0)
            .opacity(isPulsing ? 0.5 : 1.0)
            .animation(
                .easeInOut(duration: 0.7).repeatForever(autoreverses: true),
                value: isPulsing
            )
            .onAppear { isPulsing = true }
    }
}
