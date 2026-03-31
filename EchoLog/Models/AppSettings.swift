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

    private init() {}
}
