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

    private init() {}
}
