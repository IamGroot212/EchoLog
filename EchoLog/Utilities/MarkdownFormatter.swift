import Foundation

enum MarkdownFormatter {
    /// Wraps a session's summary with consistent metadata header and formatting.
    static func formatSessionSummary(
        summary: String,
        session: Session,
        transcript: String? = nil
    ) -> String {
        var output = ""

        // Title
        let dateStr = session.date.formatted(date: .long, time: .shortened)
        let apps = session.capturedApps.map(\.displayName).joined(separator: ", ")
        output += "# EchoLog Session — \(dateStr)\n\n"

        // Metadata block
        output += "| | |\n|---|---|\n"
        output += "| **Duration** | \(formatDuration(session.duration)) |\n"
        output += "| **Source** | \(apps.isEmpty ? "System Audio" : apps) |\n"
        output += "| **Session** | \(session.folderName) |\n"
        output += "\n---\n\n"

        // Summary body
        output += summary.trimmingCharacters(in: .whitespacesAndNewlines)
        output += "\n"

        // Optional transcript appendix
        if let transcript, !transcript.isEmpty {
            output += "\n---\n\n"
            output += "## Raw Transcript\n\n"
            output += "```\n"
            output += transcript.trimmingCharacters(in: .whitespacesAndNewlines)
            output += "\n```\n"
        }

        return output
    }

    /// Cleans up common LLM markdown issues.
    static func cleanMarkdown(_ text: String) -> String {
        var result = text

        // Normalize multiple blank lines to double
        result = result.replacingOccurrences(
            of: #"\n{3,}"#,
            with: "\n\n",
            options: .regularExpression
        )

        // Ensure headers have a blank line before them
        result = result.replacingOccurrences(
            of: #"([^\n])\n(##? )"#,
            with: "$1\n\n$2",
            options: .regularExpression
        )

        // Trim trailing whitespace from lines
        let lines = result.components(separatedBy: "\n")
        result = lines.map { $0.replacingOccurrences(of: #"\s+$"#, with: "", options: .regularExpression) }
            .joined(separator: "\n")

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Helpers

    private static func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        if mins >= 60 {
            let hrs = mins / 60
            let remainMins = mins % 60
            return String(format: "%d:%02d:%02d", hrs, remainMins, secs)
        }
        return String(format: "%d:%02d", mins, secs)
    }
}
