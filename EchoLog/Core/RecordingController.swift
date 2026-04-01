import Foundation
import UserNotifications

@Observable @MainActor
final class RecordingController {
    // MARK: - Published State

    private(set) var isRecording = false
    private(set) var isProcessing = false
    private(set) var statusText = "Idle"
    private(set) var elapsedSeconds = 0

    var selectedMode: AudioCaptureMode = .systemAudio
    var availableApps: [CapturedApp] = []

    // MARK: - Pipeline Components

    private let engine = AudioCaptureEngine()
    private let sessionManager = SessionManager.shared
    private let whisperBridge = WhisperBridge()
    private let summarizer = LLMSummarizer()

    private var currentSession: Session?
    private var recordingTimer: Timer?
    private var hotkeyManager: HotkeyManager?

    // MARK: - Init

    init() {
        requestNotificationPermission()
    }

    func setupHotkey() {
        guard hotkeyManager == nil else { return }
        let manager = HotkeyManager(controller: self)
        manager.register()
        hotkeyManager = manager
    }

    func reRegisterHotkey() {
        hotkeyManager?.reRegister()
    }

    // MARK: - Public API

    func toggleRecording() async {
        if isRecording {
            await stopRecording()
        } else if !isProcessing {
            await startRecording()
        }
    }

    func startRecording() async {
        guard !isRecording, !isProcessing else { return }

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

            recordingTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    guard let self else { return }
                    self.elapsedSeconds += 1
                    let mins = self.elapsedSeconds / 60
                    let secs = self.elapsedSeconds % 60
                    self.statusText = String(format: "Recording... %d:%02d", mins, secs)
                }
            }

            sendNotification(title: "Recording Started", body: "EchoLog is capturing audio.")
        } catch {
            statusText = "Error: \(error.localizedDescription)"
        }
    }

    func stopRecording() async {
        guard isRecording else { return }

        recordingTimer?.invalidate()
        recordingTimer = nil

        guard var session = currentSession else { return }

        do {
            let audioURL = try await engine.stopCapture()
            session.duration = TimeInterval(elapsedSeconds)
            isRecording = false
            isProcessing = true

            try sessionManager.save(session)
            sendNotification(title: "Processing", body: "Transcribing audio...")

            // Step 1: Transcribe
            statusText = "Transcribing..."
            let result = try await whisperBridge.transcribe(audioFileURL: audioURL)
            session.transcriptFileName = "transcript.txt"
            try sessionManager.saveTranscript(result.transcript, for: session)
            try sessionManager.save(session)

            // Step 2: Summarize (if enabled)
            var summaryText: String?
            if AppSettings.shared.autoSummarize {
                statusText = "Summarizing..."
                let summary = try await summarizer.summarize(
                    transcript: result.transcript,
                    apps: session.capturedApps,
                    duration: session.duration,
                    language: AppSettings.shared.defaultLanguage
                )
                summaryText = summary
                session.summaryFileName = "summary.md"
                try sessionManager.saveSummary(summary, for: session)
                try sessionManager.save(session)
            }

            // Step 3: Export (if enabled)
            if AppSettings.shared.autoExport {
                statusText = "Exporting..."
                let exportResults = await ExportOrchestrator.exportAll(
                    session: session,
                    summary: summaryText ?? result.transcript,
                    transcript: result.transcript
                )
                let failures = exportResults.filter { !$0.success }
                if !failures.isEmpty {
                    let names = failures.compactMap { $0.error }.joined(separator: "; ")
                    sendNotification(title: "Export Warning", body: names)
                }
            }

            statusText = "Done"
            isProcessing = false
            currentSession = nil
            sessionManager.loadSessions()

            sendNotification(title: "Session Complete", body: "Saved to ~/EchoLog/\(session.folderName)/")
        } catch {
            statusText = "Error: \(error.localizedDescription)"
            isProcessing = false
            isRecording = false
        }
    }

    func loadAvailableApps() async {
        do {
            availableApps = try await engine.availableApps()
        } catch {
            statusText = "Failed to load apps"
        }
    }

    // MARK: - Formatted Duration

    var formattedElapsed: String {
        let mins = elapsedSeconds / 60
        let secs = elapsedSeconds % 60
        return String(format: "%d:%02d", mins, secs)
    }

    // MARK: - Notifications

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func sendNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
