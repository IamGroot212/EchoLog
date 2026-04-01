import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @Environment(RecordingController.self) private var controller

    private let settings = AppSettings.shared

    // Local state for text fields
    @State private var ollamaURL: String = AppSettings.shared.ollamaBaseURL
    @State private var ollamaModel: String = AppSettings.shared.ollamaModel
    @State private var claudeKey: String = ""
    @State private var openAIKey: String = ""
    @State private var promptTemplate: String = AppSettings.shared.promptTemplate
    @State private var whisperPath: String = AppSettings.shared.whisperBinaryPath
    @State private var modelPath: String = AppSettings.shared.whisperModelPath
    @State private var selectedLanguage: String = AppSettings.shared.defaultLanguage
    @State private var selectedBackend: String = AppSettings.shared.llmBackend
    @State private var autoSummarize: Bool = AppSettings.shared.autoSummarize
    @State private var launchAtLogin: Bool = AppSettings.shared.launchAtLogin

    // Export state
    @State private var autoExport: Bool = AppSettings.shared.autoExport
    @State private var exportNotionEnabled: Bool = AppSettings.shared.exportNotionEnabled
    @State private var notionToken: String = ""
    @State private var notionDatabaseId: String = AppSettings.shared.notionDatabaseId
    @State private var exportICloudEnabled: Bool = AppSettings.shared.exportICloudEnabled
    @State private var iCloudSubfolder: String = AppSettings.shared.iCloudSubfolder
    @State private var iCloudSaveTranscript: Bool = AppSettings.shared.iCloudSaveTranscript
    @State private var exportHermesEnabled: Bool = AppSettings.shared.exportHermesEnabled
    @State private var hermesBaseURL: String = AppSettings.shared.hermesBaseURL
    @State private var hermesAPIKey: String = AppSettings.shared.hermesAPIKey
    @State private var hermesInstruction: String = AppSettings.shared.hermesInstruction

    @State private var ollamaStatus: String?
    @State private var notionTestStatus: String?
    @State private var hermesTestStatus: String?

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
            exportTab
                .tabItem { Label("Export", systemImage: "square.and.arrow.up") }
            aboutTab
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .padding()
        .frame(minWidth: 550, minHeight: 450)
        .onAppear {
            claudeKey = KeychainHelper.claudeAPIKey ?? ""
            openAIKey = KeychainHelper.openAIAPIKey ?? ""
            notionToken = KeychainHelper.notionToken ?? ""
        }
    }

    // MARK: - General

    private var generalTab: some View {
        Form {
            Section("Startup") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, val in
                        settings.launchAtLogin = val
                        toggleLaunchAtLogin(val)
                    }
            }

            Section("Hotkeys") {
                HotkeyRecorderView {
                    controller.reRegisterHotkey()
                }
                HotkeyRecorderView(
                    label: "Mic Mute Hotkey",
                    settingsKeyCode: \.micMuteKeyCode,
                    settingsModifiers: \.micMuteModifiers
                ) {
                    controller.reRegisterHotkey()
                }
            }

            Section("Capture") {
                Picker("Default Mode", selection: Binding(
                    get: { settings.captureModeRaw },
                    set: { settings.captureModeRaw = $0 }
                )) {
                    Text("System Audio").tag("systemAudio")
                    Text("Microphone Only").tag("microphoneOnly")
                }

                Toggle("Include microphone in system/app recordings", isOn: Binding(
                    get: { settings.includeMicrophone },
                    set: { settings.includeMicrophone = $0 }
                ))

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
                        browseFile { whisperPath = $0 }
                    }
                }
                .onChange(of: whisperPath) { _, val in settings.whisperBinaryPath = val }

                HStack {
                    TextField("Model Path", text: $modelPath)
                        .textFieldStyle(.roundedBorder)
                    Button("Browse...") {
                        browseFile { modelPath = $0 }
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
                    Text("OpenAI API").tag("openai")
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

                if selectedBackend == "openai" {
                    SecureField("OpenAI API Key", text: $openAIKey)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: openAIKey) { _, val in
                            KeychainHelper.openAIAPIKey = val.isEmpty ? nil : val
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

    // MARK: - Export

    private var exportTab: some View {
        Form {
            Section("Auto-Export") {
                Toggle("Automatically export after each session", isOn: $autoExport)
                    .onChange(of: autoExport) { _, val in settings.autoExport = val }
            }

            Section("Local Markdown") {
                LabeledContent("Path", value: "~/EchoLog/")
                Text("Local Markdown export is always enabled.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Notion") {
                Toggle("Enable Notion export", isOn: $exportNotionEnabled)
                    .onChange(of: exportNotionEnabled) { _, val in settings.exportNotionEnabled = val }

                if exportNotionEnabled {
                    SecureField("Integration Token", text: $notionToken)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: notionToken) { _, val in
                            KeychainHelper.notionToken = val.isEmpty ? nil : val
                        }
                    TextField("Database ID", text: $notionDatabaseId)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: notionDatabaseId) { _, val in settings.notionDatabaseId = val }

                    HStack {
                        Button("Test Connection") {
                            Task { await testNotionConnection() }
                        }
                        if let status = notionTestStatus {
                            Text(status)
                                .foregroundStyle(status.contains("OK") ? .green : .red)
                                .font(.caption)
                        }
                    }
                }
            }

            Section("iCloud Drive") {
                Toggle("Enable iCloud export", isOn: $exportICloudEnabled)
                    .onChange(of: exportICloudEnabled) { _, val in settings.exportICloudEnabled = val }

                if exportICloudEnabled {
                    TextField("Subfolder name", text: $iCloudSubfolder)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: iCloudSubfolder) { _, val in settings.iCloudSubfolder = val }
                    Toggle("Also save raw transcript", isOn: $iCloudSaveTranscript)
                        .onChange(of: iCloudSaveTranscript) { _, val in settings.iCloudSaveTranscript = val }
                }
            }

            Section("Hermes Agent") {
                Toggle("Enable Hermes Agent export", isOn: $exportHermesEnabled)
                    .onChange(of: exportHermesEnabled) { _, val in settings.exportHermesEnabled = val }

                if exportHermesEnabled {
                    TextField("API URL", text: $hermesBaseURL)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: hermesBaseURL) { _, val in settings.hermesBaseURL = val }
                    SecureField("API Key (optional for localhost)", text: $hermesAPIKey)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: hermesAPIKey) { _, val in settings.hermesAPIKey = val }

                    DisclosureGroup("Agent Instruction") {
                        TextEditor(text: $hermesInstruction)
                            .font(.system(.caption, design: .monospaced))
                            .frame(minHeight: 80)
                            .onChange(of: hermesInstruction) { _, val in settings.hermesInstruction = val }
                        Button("Reset to Default") {
                            hermesInstruction = HermesAgentExporter.defaultInstruction
                            settings.hermesInstruction = hermesInstruction
                        }
                        .font(.caption)
                    }

                    HStack {
                        Button("Test Connection") {
                            Task { await testHermesConnection() }
                        }
                        if let status = hermesTestStatus {
                            Text(status)
                                .foregroundStyle(status.contains("OK") ? .green : .red)
                                .font(.caption)
                        }
                    }

                    Text("Hermes Agent processes summaries using its 40+ built-in tools — Slack, email, task creation, and more.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - About

    private var aboutTab: some View {
        Form {
            Section {
                LabeledContent("Version") {
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0")
                }
                LabeledContent("Sessions Folder", value: "~/EchoLog/")

                HStack {
                    Button("Open in Finder") {
                        NSWorkspace.shared.open(SessionManager.shared.baseDirectory)
                    }
                    Button("GitHub") {
                        if let url = URL(string: "https://github.com/IamGroot212/EchoLog") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Helpers

    private func browseFile(completion: @escaping (String) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            completion(url.path)
        }
    }

    private func toggleLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Silently fail — not critical
        }
    }

    private func testNotionConnection() async {
        guard let token = KeychainHelper.notionToken, !token.isEmpty else {
            notionTestStatus = "No token"
            return
        }
        guard let url = URL(string: "https://api.notion.com/v1/users/me") else { return }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("2022-06-28", forHTTPHeaderField: "Notion-Version")

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            notionTestStatus = code == 200 ? "OK — Connected" : "Error: HTTP \(code)"
        } catch {
            notionTestStatus = "Error: \(error.localizedDescription)"
        }
    }

    private func testHermesConnection() async {
        let available = await HermesAgentExporter.checkHealth(baseURL: hermesBaseURL)
        hermesTestStatus = available ? "OK — Connected" : "Not reachable"
    }
}
