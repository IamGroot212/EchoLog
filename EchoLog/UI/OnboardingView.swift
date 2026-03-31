import SwiftUI

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentStep = 0

    @State private var micGranted = false
    @State private var screenGranted = false
    @State private var whisperInstalled = false
    @State private var ollamaRunning = false

    private let totalSteps = 5

    var body: some View {
        VStack(spacing: 0) {
            // Progress
            ProgressView(value: Double(currentStep), total: Double(totalSteps - 1))
                .padding(.horizontal)
                .padding(.top)

            // Content
            TabView(selection: $currentStep) {
                welcomeStep.tag(0)
                screenRecordingStep.tag(1)
                microphoneStep.tag(2)
                whisperStep.tag(3)
                ollamaStep.tag(4)
            }
            .tabViewStyle(.automatic)

            // Navigation
            HStack {
                if currentStep > 0 {
                    Button("Back") { withAnimation { currentStep -= 1 } }
                }
                Spacer()
                if currentStep < totalSteps - 1 {
                    Button("Next") {
                        withAnimation { currentStep += 1 }
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Get Started") {
                        AppSettings.shared.hasCompletedOnboarding = true
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
        }
        .frame(width: 520, height: 400)
        .task { await refreshStatus() }
    }

    // MARK: - Steps

    private var welcomeStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
            Text("Welcome to EchoLog")
                .font(.title)
            Text("EchoLog captures audio, transcribes it locally, and summarizes the content with a local LLM. All processing happens on your Mac — no data leaves your device unless you configure cloud export.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)
        }
        .padding()
    }

    private var screenRecordingStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "rectangle.inset.filled.and.person.filled")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
            Text("Screen Recording Permission")
                .font(.title2)
            Text("EchoLog uses ScreenCaptureKit to capture system audio and per-app audio streams. This requires Screen Recording permission.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)

            statusBadge(granted: screenGranted, label: "Screen Recording")

            if !screenGranted {
                Button("Open System Settings") {
                    PermissionsManager.openScreenRecordingSettings()
                }
                Text("After granting access, restart EchoLog.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button("Refresh Status") { Task { await refreshStatus() } }
                .font(.caption)
        }
        .padding()
    }

    private var microphoneStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "mic.fill")
                .font(.system(size: 48))
                .foregroundStyle(.blue)
            Text("Microphone Permission")
                .font(.title2)
            Text("Required for microphone capture mode. System audio capture does not need this.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)

            statusBadge(granted: micGranted, label: "Microphone")

            if !micGranted {
                Button("Grant Microphone Access") {
                    Task {
                        micGranted = await PermissionsManager.requestMicrophone()
                    }
                }
            }
        }
        .padding()
    }

    private var whisperStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "text.word.spacing")
                .font(.system(size: 48))
                .foregroundStyle(.green)
            Text("whisper.cpp")
                .font(.title2)
            Text("EchoLog uses whisper.cpp for local transcription. Install it via Homebrew.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)

            statusBadge(granted: whisperInstalled, label: "whisper-cpp")

            if !whisperInstalled {
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Install whisper.cpp:")
                            .font(.caption.bold())
                        Text("brew install whisper-cpp")
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                        Text("Download a model:")
                            .font(.caption.bold())
                        Text("mkdir -p ~/EchoLog/models && curl -L -o ~/EchoLog/models/ggml-base.en.bin https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin")
                            .font(.system(.caption2, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }
                .padding(.horizontal)
            }

            Button("Refresh Status") { Task { await refreshStatus() } }
                .font(.caption)
        }
        .padding()
    }

    private var ollamaStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "brain")
                .font(.system(size: 48))
                .foregroundStyle(.purple)
            Text("Ollama (Local LLM)")
                .font(.title2)
            Text("EchoLog uses Ollama to summarize transcripts locally. This is optional — you can use Claude API instead.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)

            statusBadge(granted: ollamaRunning, label: "Ollama")

            if !ollamaRunning {
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Install and start Ollama:")
                            .font(.caption.bold())
                        Text("brew install ollama && ollama serve")
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                        Text("Pull a model:")
                            .font(.caption.bold())
                        Text("ollama pull qwen2.5:14b")
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }
                .padding(.horizontal)
            }

            Button("Refresh Status") { Task { await refreshStatus() } }
                .font(.caption)
        }
        .padding()
    }

    // MARK: - Helpers

    private func statusBadge(granted: Bool, label: String) -> some View {
        HStack {
            Image(systemName: granted ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(granted ? .green : .red)
            Text(label)
            Text(granted ? "Ready" : "Not configured")
                .foregroundStyle(.secondary)
        }
        .font(.callout)
    }

    private func refreshStatus() async {
        micGranted = PermissionsManager.checkMicrophone()
        screenGranted = await PermissionsManager.checkScreenRecording()
        whisperInstalled = PermissionsManager.checkWhisperInstalled()
        ollamaRunning = await PermissionsManager.checkOllamaRunning()
    }
}
