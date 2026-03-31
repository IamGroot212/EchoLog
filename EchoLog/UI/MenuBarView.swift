import SwiftUI

struct MenuBarView: View {
    @State private var engine = AudioCaptureEngine()
    @State private var sessionManager = SessionManager.shared
    @State private var whisperBridge = WhisperBridge()

    @State private var currentSession: Session?
    @State private var statusText = "Idle"
    @State private var isRecording = false
    @State private var isTranscribing = false
    @State private var recordingTimer: Timer?
    @State private var elapsedSeconds: Int = 0

    @State private var selectedMode: AudioCaptureMode = .systemAudio
    @State private var availableApps: [CapturedApp] = []
    @State private var showAppPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Text("EchoLog").font(.headline)
                Spacer()
                if isRecording {
                    Circle()
                        .fill(.red)
                        .frame(width: 8, height: 8)
                }
            }

            Text(statusText)
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            // Capture mode picker
            if !isRecording {
                Menu("Mode: \(modeLabel)") {
                    Button("System Audio") { selectedMode = .systemAudio }
                    Button("Microphone") { selectedMode = .microphone }
                    Divider()
                    if availableApps.isEmpty {
                        Button("Load Apps...") {
                            Task { await loadApps() }
                        }
                    } else {
                        ForEach(availableApps) { app in
                            Button(app.displayName) {
                                selectedMode = .perApp(bundleIdentifier: app.bundleIdentifier)
                            }
                        }
                    }
                }
                .menuStyle(.borderlessButton)
            }

            // Start / Stop
            if isRecording {
                Button("Stop & Transcribe") {
                    Task { await stopRecording() }
                }
                .disabled(isTranscribing)
            } else if isTranscribing {
                Text("Transcribing...")
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else {
                Button("Start Recording") {
                    Task { await startRecording() }
                }
            }

            // Recent sessions
            if !sessionManager.sessions.isEmpty {
                Divider()
                Text("Recent Sessions").font(.caption).foregroundStyle(.secondary)
                ForEach(sessionManager.sessions.prefix(3)) { session in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.folderName)
                            .font(.caption2)
                            .foregroundStyle(.primary)
                        if let transcript = session.transcriptFileName {
                            Text(transcript)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            }

            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding()
        .frame(width: 280)
        .onAppear {
            sessionManager.loadSessions()
        }
    }

    // MARK: - Mode Label

    private var modeLabel: String {
        switch selectedMode {
        case .systemAudio: return "System Audio"
        case .microphone: return "Microphone"
        case .perApp(let id): return availableApps.first { $0.bundleIdentifier == id }?.displayName ?? id
        }
    }

    // MARK: - Actions

    private func loadApps() async {
        do {
            availableApps = try await engine.availableApps()
        } catch {
            statusText = "Failed to load apps"
        }
    }

    private func startRecording() async {
        do {
            let apps: [CapturedApp]
            if case .perApp(let id) = selectedMode {
                apps = availableApps.filter { $0.bundleIdentifier == id }
            } else {
                apps = []
            }

            let (session, audioURL) = try sessionManager.createSession(apps: apps)
            currentSession = session

            try await engine.startCapture(mode: selectedMode, outputURL: audioURL)

            isRecording = true
            elapsedSeconds = 0
            statusText = "Recording... 0:00"

            // Start a timer for elapsed display
            recordingTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                elapsedSeconds += 1
                let mins = elapsedSeconds / 60
                let secs = elapsedSeconds % 60
                statusText = String(format: "Recording... %d:%02d", mins, secs)
            }
        } catch {
            statusText = "Error: \(error.localizedDescription)"
        }
    }

    private func stopRecording() async {
        recordingTimer?.invalidate()
        recordingTimer = nil

        guard var session = currentSession else { return }

        do {
            let audioURL = try await engine.stopCapture()
            session.duration = TimeInterval(elapsedSeconds)
            isRecording = false

            // Save session metadata
            try sessionManager.save(session)

            // Transcribe
            statusText = "Transcribing..."
            isTranscribing = true

            let result = try await whisperBridge.transcribe(audioFileURL: audioURL)
            session.transcriptFileName = "transcript.txt"

            try sessionManager.saveTranscript(result.transcript, for: session)
            try sessionManager.save(session)

            statusText = "Done — transcript saved"
            isTranscribing = false
            currentSession = nil

            // Reload sessions list
            sessionManager.loadSessions()
        } catch {
            statusText = "Error: \(error.localizedDescription)"
            isTranscribing = false
            isRecording = false
        }
    }
}
