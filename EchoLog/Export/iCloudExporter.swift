import Foundation

enum iCloudExporter {
    /// Writes summary (and optionally transcript) to iCloud Drive.
    /// Path: ~/Library/Mobile Documents/com~apple~CloudDocs/{subfolder}/
    static func export(session: Session, summary: String, transcript: String?) async throws {
        let settings = AppSettings.shared
        let subfolder = settings.iCloudSubfolder

        let iCloudBase = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs", isDirectory: true)

        let targetDir = iCloudBase.appendingPathComponent(subfolder, isDirectory: true)

        // Create directory if needed
        if !FileManager.default.fileExists(atPath: targetDir.path) {
            try FileManager.default.createDirectory(at: targetDir, withIntermediateDirectories: true)
        }

        // Format filename: YYYY-MM-DD_HH-mm
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm"
        let dateStr = formatter.string(from: session.date)

        // Write summary
        let summaryURL = targetDir.appendingPathComponent("\(dateStr).md")
        try summary.write(to: summaryURL, atomically: true, encoding: .utf8)

        // Optionally write transcript
        if settings.iCloudSaveTranscript, let transcript {
            let transcriptURL = targetDir.appendingPathComponent("\(dateStr)_transcript.txt")
            try transcript.write(to: transcriptURL, atomically: true, encoding: .utf8)
        }
    }
}
