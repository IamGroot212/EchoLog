import Foundation

enum LLMSummarizerError: LocalizedError {
    case ollamaNotAvailable
    case ollamaRequestFailed(String)
    case claudeAPIKeyMissing
    case claudeRequestFailed(String)
    case noBackendAvailable

    var errorDescription: String? {
        switch self {
        case .ollamaNotAvailable:
            return "Ollama is not running. Start it with: ollama serve"
        case .ollamaRequestFailed(let msg):
            return "Ollama request failed: \(msg)"
        case .claudeAPIKeyMissing:
            return "Claude API key not configured. Add it in Settings."
        case .claudeRequestFailed(let msg):
            return "Claude API request failed: \(msg)"
        case .noBackendAvailable:
            return "No LLM backend available. Start Ollama or configure a Claude API key."
        }
    }
}

final class LLMSummarizer {
    private let settings = AppSettings.shared

    static let defaultPromptTemplate = """
    You are a meeting and conversation summarizer. Given the following transcript, \
    extract and structure the most important information.

    IMPORTANT: Write the summary in the same language the meeting was conducted in. \
    If the language cannot be determined, default to German.

    Output a clean Markdown document with these sections:
    ## Zusammenfassung / Summary
    (2-4 sentence overview of what was discussed)

    ## Kernpunkte / Key Points
    (bullet list of the most important facts, decisions, or insights)

    ## Aufgaben / Action Items
    (bullet list of tasks, todos, or follow-ups mentioned — leave empty if none)

    ## Kontext / Context
    (app(s) captured: {apps}, duration: {duration}, language: {language})

    ---
    TRANSCRIPT:
    {transcript}
    """

    // MARK: - Public API

    func summarize(
        transcript: String,
        apps: [CapturedApp],
        duration: TimeInterval,
        language: String
    ) async throws -> String {
        let prompt = buildPrompt(transcript: transcript, apps: apps, duration: duration, language: language)

        let backend = settings.llmBackend
        switch backend {
        case "claude":
            return try await summarizeWithClaude(prompt: prompt)
        case "openai":
            return try await summarizeWithClaude(prompt: prompt) // TODO: OpenAI in Phase 4
        default:
            // Ollama primary, Claude fallback
            if await isOllamaAvailable() {
                return try await summarizeWithOllama(prompt: prompt)
            } else if KeychainHelper.claudeAPIKey != nil {
                return try await summarizeWithClaude(prompt: prompt)
            } else {
                throw LLMSummarizerError.noBackendAvailable
            }
        }
    }

    func isOllamaAvailable() async -> Bool {
        let baseURL = settings.ollamaBaseURL
        guard let url = URL(string: "\(baseURL)/api/tags") else { return false }

        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    // MARK: - Ollama

    private func summarizeWithOllama(prompt: String) async throws -> String {
        let baseURL = settings.ollamaBaseURL
        let model = settings.ollamaModel
        guard let url = URL(string: "\(baseURL)/api/generate") else {
            throw LLMSummarizerError.ollamaNotAvailable
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 300 // 5 min — large transcripts take time

        let body: [String: Any] = [
            "model": model,
            "prompt": prompt,
            "stream": false
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw LLMSummarizerError.ollamaRequestFailed("HTTP \(statusCode)")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let responseText = json["response"] as? String else {
            throw LLMSummarizerError.ollamaRequestFailed("Invalid response format")
        }

        return responseText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Claude API

    private func summarizeWithClaude(prompt: String) async throws -> String {
        guard let apiKey = KeychainHelper.claudeAPIKey else {
            throw LLMSummarizerError.claudeAPIKeyMissing
        }

        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            throw LLMSummarizerError.claudeRequestFailed("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = 120

        let body: [String: Any] = [
            "model": "claude-haiku-4-5-20251001",
            "max_tokens": 4096,
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            let errorBody = String(data: data, encoding: .utf8) ?? ""
            throw LLMSummarizerError.claudeRequestFailed("HTTP \(statusCode): \(errorBody)")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let firstBlock = content.first,
              let text = firstBlock["text"] as? String else {
            throw LLMSummarizerError.claudeRequestFailed("Invalid response format")
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Prompt Building

    private func buildPrompt(
        transcript: String,
        apps: [CapturedApp],
        duration: TimeInterval,
        language: String
    ) -> String {
        let template = settings.promptTemplate
        let appNames = apps.map(\.displayName).joined(separator: ", ")
        let durationStr = formatDuration(duration)

        return template
            .replacingOccurrences(of: "{apps}", with: appNames.isEmpty ? "System Audio" : appNames)
            .replacingOccurrences(of: "{duration}", with: durationStr)
            .replacingOccurrences(of: "{language}", with: language)
            .replacingOccurrences(of: "{transcript}", with: transcript)
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
