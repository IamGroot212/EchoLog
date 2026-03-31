import Foundation

struct WhisperResult {
    let transcript: String
}

enum WhisperError: LocalizedError {
    case binaryNotFound(path: String)
    case modelNotFound(path: String)
    case transcriptionFailed(exitCode: Int32, stderr: String)
    case outputFileNotFound

    var errorDescription: String? {
        switch self {
        case .binaryNotFound(let path):
            return "whisper-cpp binary not found at \(path). Install with: brew install whisper-cpp"
        case .modelNotFound(let path):
            return "Whisper model not found at \(path)."
        case .transcriptionFailed(let code, let stderr):
            return "Transcription failed (exit \(code)): \(stderr)"
        case .outputFileNotFound:
            return "whisper-cpp did not produce an output file."
        }
    }
}

final class WhisperBridge {
    private let binaryPath: String
    private let modelPath: String

    init(binaryPath: String? = nil, modelPath: String? = nil) {
        let settings = AppSettings.shared
        self.binaryPath = binaryPath ?? settings.whisperBinaryPath
        self.modelPath = modelPath ?? settings.whisperModelPath
    }

    func transcribe(audioFileURL: URL, language: String? = nil) async throws -> WhisperResult {
        let lang = language ?? AppSettings.shared.defaultLanguage

        guard FileManager.default.fileExists(atPath: binaryPath) else {
            throw WhisperError.binaryNotFound(path: binaryPath)
        }
        guard FileManager.default.fileExists(atPath: modelPath) else {
            throw WhisperError.modelNotFound(path: modelPath)
        }

        let outputBase = audioFileURL.deletingPathExtension().path

        let process = Process()
        process.executableURL = URL(fileURLWithPath: binaryPath)
        process.arguments = [
            "-m", modelPath,
            "-f", audioFileURL.path,
            "-otxt",
            "-of", outputBase,
            "-l", lang
        ]

        let stderrPipe = Pipe()
        process.standardOutput = Pipe() // discard stdout
        process.standardError = stderrPipe

        return try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { proc in
                if proc.terminationStatus != 0 {
                    let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                    let stderrString = String(data: stderrData, encoding: .utf8) ?? ""
                    continuation.resume(throwing: WhisperError.transcriptionFailed(
                        exitCode: proc.terminationStatus, stderr: stderrString
                    ))
                    return
                }

                let outputFilePath = outputBase + ".txt"
                guard let text = try? String(contentsOfFile: outputFilePath, encoding: .utf8) else {
                    continuation.resume(throwing: WhisperError.outputFileNotFound)
                    return
                }

                continuation.resume(returning: WhisperResult(
                    transcript: text.trimmingCharacters(in: .whitespacesAndNewlines)
                ))
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
