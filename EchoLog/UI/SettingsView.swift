import SwiftUI

struct SettingsView: View {
    @State private var settings = AppSettings.shared

    // Local state for text fields
    @State private var ollamaURL: String = AppSettings.shared.ollamaBaseURL
    @State private var ollamaModel: String = AppSettings.shared.ollamaModel
    @State private var claudeKey: String = ""
    @State private var promptTemplate: String = AppSettings.shared.promptTemplate
    @State private var whisperPath: String = AppSettings.shared.whisperBinaryPath
    @State private var modelPath: String = AppSettings.shared.whisperModelPath
    @State private var selectedLanguage: String = AppSettings.shared.defaultLanguage
    @State private var selectedBackend: String = AppSettings.shared.llmBackend
    @State private var autoSummarize: Bool = AppSettings.shared.autoSummarize

    @State private var ollamaStatus: String?

    private let languages = [
        ("en", "English"), ("de", "German"), ("fr", "French"),
        ("es", "Spanish"), ("auto", "Auto-detect")
    ]

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("General", systemImage: "gear") }
            transcriptionTab
                .tabItem { Label("Transcription", systemImage: "waveform") }
            summarizationTab
                .tabItem { Label("Summarization", systemImage: "text.badge.star") }
            aboutTab
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .padding()
        .frame(minWidth: 500, minHeight: 400)
        .onAppear {
            claudeKey = KeychainHelper.claudeAPIKey ?? ""
        }
    }

    // MARK: - General

    private var generalTab: some View {
        Form {
            Section("Capture") {
                Picker("Default Mode", selection: $settings.captureModeRaw) {
                    Text("System Audio").tag("systemAudio")
                    Text("Microphone").tag("microphone")
                }
                Toggle("Auto-summarize after recording", isOn: $autoSummarize)
                    .onChange(of: autoSummarize) { _, val in settings.autoSummarize = val }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Transcription

    private var transcriptionTab: some View {
        Form {
            Section("whisper.cpp") {
                HStack {
                    TextField("Binary Path", text: $whisperPath)
                        .textFieldStyle(.roundedBorder)
                    Button("Browse...") {
                        let panel = NSOpenPanel()
                        panel.canChooseFiles = true
                        panel.canChooseDirectories = false
                        if panel.runModal() == .OK, let url = panel.url {
                            whisperPath = url.path
                        }
                    }
                }
                .onChange(of: whisperPath) { _, val in settings.whisperBinaryPath = val }

                HStack {
                    TextField("Model Path", text: $modelPath)
                        .textFieldStyle(.roundedBorder)
                    Button("Browse...") {
                        let panel = NSOpenPanel()
                        panel.canChooseFiles = true
                        panel.canChooseDirectories = false
                        if panel.runModal() == .OK, let url = panel.url {
                            modelPath = url.path
                        }
                    }
                }
                .onChange(of: modelPath) { _, val in settings.whisperModelPath = val }
            }

            Section("Language") {
                Picker("Language", selection: $selectedLanguage) {
                    ForEach(languages, id: \.0) { code, name in
                        Text(name).tag(code)
                    }
                }
                .onChange(of: selectedLanguage) { _, val in settings.defaultLanguage = val }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Summarization

    private var summarizationTab: some View {
        Form {
            Section("LLM Backend") {
                Picker("Backend", selection: $selectedBackend) {
                    Text("Ollama (Local)").tag("ollama")
                    Text("Claude API").tag("claude")
                }
                .onChange(of: selectedBackend) { _, val in settings.llmBackend = val }

                if selectedBackend == "ollama" {
                    TextField("Ollama URL", text: $ollamaURL)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: ollamaURL) { _, val in settings.ollamaBaseURL = val }
                    TextField("Model", text: $ollamaModel)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: ollamaModel) { _, val in settings.ollamaModel = val }

                    HStack {
                        Button("Check Ollama") {
                            Task {
                                let available = await LLMSummarizer().isOllamaAvailable()
                                ollamaStatus = available ? "Connected" : "Not reachable"
                            }
                        }
                        if let status = ollamaStatus {
                            Text(status)
                                .foregroundStyle(status == "Connected" ? .green : .red)
                                .font(.caption)
                        }
                    }
                }

                if selectedBackend == "claude" {
                    SecureField("Claude API Key", text: $claudeKey)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: claudeKey) { _, val in
                            KeychainHelper.claudeAPIKey = val.isEmpty ? nil : val
                        }
                }
            }

            Section("Prompt Template") {
                TextEditor(text: $promptTemplate)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 120)
                    .onChange(of: promptTemplate) { _, val in settings.promptTemplate = val }

                Button("Reset to Default") {
                    promptTemplate = LLMSummarizer.defaultPromptTemplate
                    settings.promptTemplate = promptTemplate
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - About

    private var aboutTab: some View {
        Form {
            Section {
                LabeledContent("Version", value: "0.1.0")
                LabeledContent("Sessions Folder", value: "~/EchoLog/")
                Button("Open in Finder") {
                    let url = SessionManager.shared.baseDirectory
                    NSWorkspace.shared.open(url)
                }
            }
        }
        .formStyle(.grouped)
    }
}
