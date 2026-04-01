import Foundation

enum OpenClawExporter {
    static func export(session: Session, summary: String) async throws {
        let settings = AppSettings.shared
        let gatewayURL = settings.openClawGatewayURL
        let agentId = settings.openClawAgentId

        guard !gatewayURL.isEmpty, let url = URL(string: gatewayURL) else {
            throw ExportError.invalidURL("OpenClaw gateway")
        }

        let apps = session.capturedApps.map(\.displayName)
        let durationStr = {
            let mins = Int(session.duration) / 60
            let secs = Int(session.duration) % 60
            return String(format: "%d:%02d", mins, secs)
        }()

        let body: [String: Any] = [
            "agent": agentId,
            "message": "New EchoLog session completed. Here is the summary:\n\n\(summary)",
            "metadata": [
                "date": ISO8601DateFormatter().string(from: session.date),
                "duration": durationStr,
                "apps": apps
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            let errorBody = String(data: data, encoding: .utf8) ?? ""
            throw ExportError.openClawRequestFailed("HTTP \(code): \(errorBody)")
        }
    }
}
