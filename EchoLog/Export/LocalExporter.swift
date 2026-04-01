import Foundation

enum LocalExporter {
    /// Local export is already handled by SessionManager during the recording pipeline.
    /// This method verifies the session files exist and returns the folder path.
    static func export(session: Session) throws -> URL {
        let folder = SessionManager.shared.sessionFolder(for: session)

        guard FileManager.default.fileExists(atPath: folder.path) else {
            throw ExportError.localFolderMissing(folder.path)
        }

        return folder
    }
}
