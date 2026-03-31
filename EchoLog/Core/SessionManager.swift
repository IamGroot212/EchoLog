import Foundation

enum SessionManagerError: LocalizedError {
    case failedToCreateDirectory
    case sessionNotFound

    var errorDescription: String? {
        switch self {
        case .failedToCreateDirectory: return "Failed to create session directory."
        case .sessionNotFound: return "Session not found on disk."
        }
    }
}

final class SessionManager {
    static let shared = SessionManager()

    let baseDirectory: URL

    private(set) var sessions: [Session] = []

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    init() {
        baseDirectory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("EchoLog", isDirectory: true)
    }

    // MARK: - Session Lifecycle

    func createSession(apps: [CapturedApp] = []) throws -> (Session, URL) {
        let session = Session(capturedApps: apps)
        let folder = baseDirectory.appendingPathComponent(session.folderName, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let audioURL = folder.appendingPathComponent(session.audioFileName)
        return (session, audioURL)
    }

    func save(_ session: Session) throws {
        let folder = baseDirectory.appendingPathComponent(session.folderName, isDirectory: true)
        let metadataURL = folder.appendingPathComponent("session.json")
        let data = try encoder.encode(session)
        try data.write(to: metadataURL)
    }

    func saveTranscript(_ text: String, for session: Session) throws {
        let folder = baseDirectory.appendingPathComponent(session.folderName, isDirectory: true)
        let url = folder.appendingPathComponent("transcript.txt")
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    // MARK: - Loading

    func loadSessions() {
        guard FileManager.default.fileExists(atPath: baseDirectory.path) else {
            sessions = []
            return
        }

        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: baseDirectory,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
            sessions = contents.compactMap { folderURL -> Session? in
                let metadataURL = folderURL.appendingPathComponent("session.json")
                guard let data = try? Data(contentsOf: metadataURL) else { return nil }
                return try? decoder.decode(Session.self, from: data)
            }.sorted { $0.date > $1.date }
        } catch {
            sessions = []
        }
    }

    // MARK: - Deletion

    func deleteSession(_ session: Session) throws {
        let folder = baseDirectory.appendingPathComponent(session.folderName, isDirectory: true)
        guard FileManager.default.fileExists(atPath: folder.path) else {
            throw SessionManagerError.sessionNotFound
        }
        try FileManager.default.removeItem(at: folder)
        sessions.removeAll { $0.id == session.id }
    }

    // MARK: - Helpers

    func sessionFolder(for session: Session) -> URL {
        baseDirectory.appendingPathComponent(session.folderName, isDirectory: true)
    }
}
