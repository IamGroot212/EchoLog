import Foundation

enum NotionExporter {
    static func export(session: Session, summary: String) async throws {
        let settings = AppSettings.shared
        guard let token = KeychainHelper.notionToken, !token.isEmpty else {
            throw ExportError.notionTokenMissing
        }
        let databaseId = settings.notionDatabaseId
        guard !databaseId.isEmpty else {
            throw ExportError.notionDatabaseIdMissing
        }

        guard let url = URL(string: "https://api.notion.com/v1/pages") else {
            throw ExportError.invalidURL("Notion API")
        }

        let title = formatTitle(session: session)
        let blocks = markdownToNotionBlocks(summary)

        let body: [String: Any] = [
            "parent": ["database_id": databaseId],
            "properties": [
                "Name": [
                    "title": [
                        ["text": ["content": title]]
                    ]
                ],
                "Date": [
                    "date": ["start": ISO8601DateFormatter().string(from: session.date)]
                ],
                "Duration": [
                    "rich_text": [
                        ["text": ["content": formatDuration(session.duration)]]
                    ]
                ],
                "Apps": [
                    "rich_text": [
                        ["text": ["content": session.capturedApps.map(\.displayName).joined(separator: ", ")]]
                    ]
                ]
            ],
            "children": blocks
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("2022-06-28", forHTTPHeaderField: "Notion-Version")
        request.timeoutInterval = 30
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            let errorBody = String(data: data, encoding: .utf8) ?? ""
            throw ExportError.notionRequestFailed("HTTP \(code): \(errorBody)")
        }
    }

    // MARK: - Helpers

    private static func formatTitle(session: Session) -> String {
        let dateStr = session.date.formatted(date: .numeric, time: .omitted)
        let apps = session.capturedApps.map(\.displayName).joined(separator: ", ")
        if apps.isEmpty {
            return "\(dateStr) · System Audio"
        }
        return "\(dateStr) · \(apps)"
    }

    private static func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    /// Convert Markdown text into an array of Notion block objects.
    private static func markdownToNotionBlocks(_ markdown: String) -> [[String: Any]] {
        var blocks: [[String: Any]] = []
        let lines = markdown.components(separatedBy: "\n")

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }

            if trimmed.hasPrefix("## ") {
                let text = String(trimmed.dropFirst(3))
                blocks.append([
                    "object": "block",
                    "type": "heading_2",
                    "heading_2": [
                        "rich_text": [["type": "text", "text": ["content": text]]]
                    ]
                ])
            } else if trimmed.hasPrefix("- ") {
                let text = String(trimmed.dropFirst(2))
                blocks.append([
                    "object": "block",
                    "type": "bulleted_list_item",
                    "bulleted_list_item": [
                        "rich_text": [["type": "text", "text": ["content": text]]]
                    ]
                ])
            } else if trimmed == "---" {
                blocks.append([
                    "object": "block",
                    "type": "divider",
                    "divider": [String: Any]()
                ])
            } else {
                blocks.append([
                    "object": "block",
                    "type": "paragraph",
                    "paragraph": [
                        "rich_text": [["type": "text", "text": ["content": trimmed]]]
                    ]
                ])
            }
        }

        return blocks
    }
}
