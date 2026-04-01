import Foundation

/// Exports session data to Hermes Agent via its OpenAI-compatible API.
///
/// Hermes Agent (by Nous Research) runs locally and exposes:
/// - Chat API: POST http://localhost:8642/v1/chat/completions
/// - Cron API: POST http://localhost:8642/api/jobs (for scheduled follow-ups)
///
/// The exporter sends the session summary as a chat message, instructing the
/// agent to process it (e.g., send to Slack, create tasks, file notes).
/// It can also create a cron job for recurring session digests.
enum HermesAgentExporter {

    /// Send the session summary to Hermes Agent as a chat completion.
    /// The agent processes it using its skills (Slack, email, task creation, etc.)
    static func export(session: Session, summary: String) async throws {
        let settings = AppSettings.shared
        let baseURL = settings.hermesBaseURL
        let apiKey = settings.hermesAPIKey

        guard let url = URL(string: "\(baseURL)/v1/chat/completions") else {
            throw ExportError.invalidURL("Hermes Agent API")
        }

        let apps = session.capturedApps.map(\.displayName).joined(separator: ", ")
        let durationStr = formatDuration(session.duration)
        let dateStr = session.date.formatted(date: .long, time: .shortened)

        // Build the instruction for the agent
        let instruction = settings.hermesInstruction.isEmpty
            ? defaultInstruction
            : settings.hermesInstruction

        let userMessage = """
        New EchoLog session completed.

        **Date:** \(dateStr)
        **Duration:** \(durationStr)
        **Apps:** \(apps.isEmpty ? "System Audio" : apps)

        ---

        \(summary)
        """

        let body: [String: Any] = [
            "model": "hermes-agent",
            "messages": [
                ["role": "system", "content": instruction],
                ["role": "user", "content": userMessage]
            ],
            "stream": false
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        request.timeoutInterval = 120 // Agent may use tools, takes longer
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            let errorBody = String(data: data, encoding: .utf8) ?? ""
            throw ExportError.hermesRequestFailed("HTTP \(code): \(errorBody)")
        }
    }

    /// Create a cron job on Hermes Agent for scheduled session digests.
    static func createCronJob(schedule: String, prompt: String) async throws {
        let settings = AppSettings.shared
        let baseURL = settings.hermesBaseURL
        let apiKey = settings.hermesAPIKey

        guard let url = URL(string: "\(baseURL)/api/jobs") else {
            throw ExportError.invalidURL("Hermes Agent Cron API")
        }

        let body: [String: Any] = [
            "name": "EchoLog Daily Digest",
            "schedule": schedule,
            "prompt": prompt,
            "deliver": "local"
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        request.timeoutInterval = 30
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            let errorBody = String(data: data, encoding: .utf8) ?? ""
            throw ExportError.hermesRequestFailed("HTTP \(code): \(errorBody)")
        }
    }

    /// Check if Hermes Agent API is reachable.
    static func checkHealth(baseURL: String) async -> Bool {
        guard let url = URL(string: "\(baseURL)/health") else { return false }
        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    // MARK: - Helpers

    static let defaultInstruction = """
    You are receiving a meeting/session summary from EchoLog, a macOS audio \
    capture and transcription app. Process this summary using your available \
    skills and tools. Suggested actions:
    - If action items are present, create tasks or send them to the appropriate channel
    - If the summary is from a meeting, send key points to relevant team members
    - File the summary in an organized way
    - Respond with a brief confirmation of what you did
    """

    private static func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
