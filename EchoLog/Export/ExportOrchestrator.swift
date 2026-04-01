import Foundation

enum ExportError: LocalizedError {
    case localFolderMissing(String)
    case notionTokenMissing
    case notionDatabaseIdMissing
    case notionRequestFailed(String)
    case invalidURL(String)
    case openClawRequestFailed(String)
    case iCloudWriteFailed(String)

    var errorDescription: String? {
        switch self {
        case .localFolderMissing(let path): return "Session folder not found: \(path)"
        case .notionTokenMissing: return "Notion integration token not configured."
        case .notionDatabaseIdMissing: return "Notion database ID not configured."
        case .notionRequestFailed(let msg): return "Notion export failed: \(msg)"
        case .invalidURL(let name): return "Invalid URL for \(name)."
        case .openClawRequestFailed(let msg): return "OpenClaw export failed: \(msg)"
        case .iCloudWriteFailed(let msg): return "iCloud export failed: \(msg)"
        }
    }
}

struct ExportResult {
    let exporter: String
    let success: Bool
    let error: String?
}

enum ExportOrchestrator {
    /// Run all enabled exporters for the given session.
    /// Returns results for each attempted export.
    static func exportAll(session: Session, summary: String, transcript: String?) async -> [ExportResult] {
        let settings = AppSettings.shared
        var results: [ExportResult] = []

        // Local is always on — just verify
        do {
            _ = try LocalExporter.export(session: session)
            results.append(ExportResult(exporter: "Local", success: true, error: nil))
        } catch {
            results.append(ExportResult(exporter: "Local", success: false, error: error.localizedDescription))
        }

        // Notion
        if settings.exportNotionEnabled {
            do {
                try await NotionExporter.export(session: session, summary: summary)
                results.append(ExportResult(exporter: "Notion", success: true, error: nil))
            } catch {
                results.append(ExportResult(exporter: "Notion", success: false, error: error.localizedDescription))
            }
        }

        // iCloud
        if settings.exportICloudEnabled {
            do {
                try await iCloudExporter.export(session: session, summary: summary, transcript: transcript)
                results.append(ExportResult(exporter: "iCloud", success: true, error: nil))
            } catch {
                results.append(ExportResult(exporter: "iCloud", success: false, error: error.localizedDescription))
            }
        }

        // OpenClaw
        if settings.exportOpenClawEnabled {
            do {
                try await OpenClawExporter.export(session: session, summary: summary)
                results.append(ExportResult(exporter: "OpenClaw", success: true, error: nil))
            } catch {
                results.append(ExportResult(exporter: "OpenClaw", success: false, error: error.localizedDescription))
            }
        }

        return results
    }
}
