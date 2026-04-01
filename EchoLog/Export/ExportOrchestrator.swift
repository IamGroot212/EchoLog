import Foundation

enum ExportError: LocalizedError {
    case localFolderMissing(String)
    case notionTokenMissing
    case notionDatabaseIdMissing
    case notionRequestFailed(String)
    case invalidURL(String)
    case hermesRequestFailed(String)
    case iCloudWriteFailed(String)

    var errorDescription: String? {
        switch self {
        case .localFolderMissing(let path): return "Session folder not found: \(path)"
        case .notionTokenMissing: return "Notion integration token not configured."
        case .notionDatabaseIdMissing: return "Notion database ID not configured."
        case .notionRequestFailed(let msg): return "Notion export failed: \(msg)"
        case .invalidURL(let name): return "Invalid URL for \(name)."
        case .hermesRequestFailed(let msg): return "Hermes Agent export failed: \(msg)"
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
    static func exportAll(session: Session, summary: String, transcript: String?) async -> [ExportResult] {
        let settings = AppSettings.shared
        var results: [ExportResult] = []

        // Local is always on
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

        // Hermes Agent
        if settings.exportHermesEnabled {
            do {
                try await HermesAgentExporter.export(session: session, summary: summary)
                results.append(ExportResult(exporter: "Hermes Agent", success: true, error: nil))
            } catch {
                results.append(ExportResult(exporter: "Hermes Agent", success: false, error: error.localizedDescription))
            }
        }

        return results
    }
}
