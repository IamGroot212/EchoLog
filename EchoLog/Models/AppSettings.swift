import Foundation

final class AppSettings {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard

    var whisperBinaryPath: String {
        get { defaults.string(forKey: "whisperBinaryPath") ?? "/opt/homebrew/bin/whisper-cpp" }
        set { defaults.set(newValue, forKey: "whisperBinaryPath") }
    }

    var whisperModelPath: String {
        get { defaults.string(forKey: "whisperModelPath") ?? NSString("~/EchoLog/models/ggml-base.en.bin").expandingTildeInPath }
        set { defaults.set(newValue, forKey: "whisperModelPath") }
    }

    var defaultLanguage: String {
        get { defaults.string(forKey: "defaultLanguage") ?? "en" }
        set { defaults.set(newValue, forKey: "defaultLanguage") }
    }

    var captureModeRaw: String {
        get { defaults.string(forKey: "captureMode") ?? "systemAudio" }
        set { defaults.set(newValue, forKey: "captureMode") }
    }

    // MARK: - LLM Settings

    var llmBackend: String {
        get { defaults.string(forKey: "llmBackend") ?? "ollama" }
        set { defaults.set(newValue, forKey: "llmBackend") }
    }

    var ollamaBaseURL: String {
        get { defaults.string(forKey: "ollamaBaseURL") ?? "http://localhost:11434" }
        set { defaults.set(newValue, forKey: "ollamaBaseURL") }
    }

    var ollamaModel: String {
        get { defaults.string(forKey: "ollamaModel") ?? "qwen2.5:14b" }
        set { defaults.set(newValue, forKey: "ollamaModel") }
    }

    var promptTemplate: String {
        get { defaults.string(forKey: "promptTemplate") ?? LLMSummarizer.defaultPromptTemplate }
        set { defaults.set(newValue, forKey: "promptTemplate") }
    }

    var autoSummarize: Bool {
        get { defaults.object(forKey: "autoSummarize") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "autoSummarize") }
    }

    // MARK: - Hotkey Settings

    /// Key code for the global hotkey (default: 15 = R)
    var hotkeyKeyCode: UInt16 {
        get {
            let val = defaults.object(forKey: "hotkeyKeyCode") as? Int
            return val.map { UInt16($0) } ?? 15
        }
        set { defaults.set(Int(newValue), forKey: "hotkeyKeyCode") }
    }

    /// Modifier flags for the global hotkey (default: ⌘⇧)
    var hotkeyModifiers: UInt {
        get {
            defaults.object(forKey: "hotkeyModifiers") as? UInt ?? 1_179_648 // .command | .shift
        }
        set { defaults.set(newValue, forKey: "hotkeyModifiers") }
    }

    // MARK: - Onboarding

    var hasCompletedOnboarding: Bool {
        get { defaults.bool(forKey: "hasCompletedOnboarding") }
        set { defaults.set(newValue, forKey: "hasCompletedOnboarding") }
    }

    // MARK: - Launch at Login

    var launchAtLogin: Bool {
        get { defaults.bool(forKey: "launchAtLogin") }
        set { defaults.set(newValue, forKey: "launchAtLogin") }
    }

    // MARK: - Export Settings

    var autoExport: Bool {
        get { defaults.object(forKey: "autoExport") as? Bool ?? false }
        set { defaults.set(newValue, forKey: "autoExport") }
    }

    var exportNotionEnabled: Bool {
        get { defaults.bool(forKey: "exportNotionEnabled") }
        set { defaults.set(newValue, forKey: "exportNotionEnabled") }
    }

    var notionDatabaseId: String {
        get { defaults.string(forKey: "notionDatabaseId") ?? "" }
        set { defaults.set(newValue, forKey: "notionDatabaseId") }
    }

    var exportICloudEnabled: Bool {
        get { defaults.bool(forKey: "exportICloudEnabled") }
        set { defaults.set(newValue, forKey: "exportICloudEnabled") }
    }

    var iCloudSubfolder: String {
        get { defaults.string(forKey: "iCloudSubfolder") ?? "EchoLog" }
        set { defaults.set(newValue, forKey: "iCloudSubfolder") }
    }

    var iCloudSaveTranscript: Bool {
        get { defaults.bool(forKey: "iCloudSaveTranscript") }
        set { defaults.set(newValue, forKey: "iCloudSaveTranscript") }
    }

    var exportHermesEnabled: Bool {
        get { defaults.bool(forKey: "exportHermesEnabled") }
        set { defaults.set(newValue, forKey: "exportHermesEnabled") }
    }

    var hermesBaseURL: String {
        get { defaults.string(forKey: "hermesBaseURL") ?? "http://localhost:8642" }
        set { defaults.set(newValue, forKey: "hermesBaseURL") }
    }

    var hermesAPIKey: String {
        get { defaults.string(forKey: "hermesAPIKey") ?? "" }
        set { defaults.set(newValue, forKey: "hermesAPIKey") }
    }

    var hermesInstruction: String {
        get { defaults.string(forKey: "hermesInstruction") ?? HermesAgentExporter.defaultInstruction }
        set { defaults.set(newValue, forKey: "hermesInstruction") }
    }

    private init() {}
}
