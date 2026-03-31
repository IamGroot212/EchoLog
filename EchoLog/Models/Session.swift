import Foundation

struct Session: Codable, Identifiable {
    let id: UUID
    let date: Date
    var duration: TimeInterval
    var capturedApps: [CapturedApp]
    var audioFileName: String
    var transcriptFileName: String?
    var summaryFileName: String?

    var folderName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter.string(from: date)
    }

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        duration: TimeInterval = 0,
        capturedApps: [CapturedApp] = [],
        audioFileName: String = "raw_audio.wav",
        transcriptFileName: String? = nil,
        summaryFileName: String? = nil
    ) {
        self.id = id
        self.date = date
        self.duration = duration
        self.capturedApps = capturedApps
        self.audioFileName = audioFileName
        self.transcriptFileName = transcriptFileName
        self.summaryFileName = summaryFileName
    }
}
