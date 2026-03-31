import Foundation

enum WAVWriterError: LocalizedError {
    case failedToCreateFile
    case failedToOpenFile
    case notStarted

    var errorDescription: String? {
        switch self {
        case .failedToCreateFile: return "Failed to create WAV file."
        case .failedToOpenFile: return "Failed to open WAV file for writing."
        case .notStarted: return "WAVWriter has not been started."
        }
    }
}

/// Writes PCM audio data incrementally to a WAV file.
/// Format: 16kHz, 16-bit, mono (whisper.cpp preferred input).
final class WAVWriter {
    let outputURL: URL
    let sampleRate: UInt32
    let bitsPerSample: UInt16
    let channels: UInt16

    private var fileHandle: FileHandle?
    private var dataSize: UInt32 = 0

    init(outputURL: URL, sampleRate: UInt32 = 16000, bitsPerSample: UInt16 = 16, channels: UInt16 = 1) {
        self.outputURL = outputURL
        self.sampleRate = sampleRate
        self.bitsPerSample = bitsPerSample
        self.channels = channels
    }

    func start() throws {
        let created = FileManager.default.createFile(atPath: outputURL.path, contents: nil)
        guard created else { throw WAVWriterError.failedToCreateFile }

        guard let handle = FileHandle(forWritingAtPath: outputURL.path) else {
            throw WAVWriterError.failedToOpenFile
        }
        fileHandle = handle
        dataSize = 0

        let header = buildHeader(dataSize: 0)
        handle.write(header)
    }

    func appendPCMData(_ data: Data) throws {
        guard let handle = fileHandle else { throw WAVWriterError.notStarted }
        handle.write(data)
        dataSize += UInt32(data.count)
    }

    func finalize() throws {
        guard let handle = fileHandle else { throw WAVWriterError.notStarted }

        // Overwrite RIFF chunk size at byte 4
        handle.seek(toFileOffset: 4)
        var riffSize = dataSize + 36 // total file size minus 8
        handle.write(Data(bytes: &riffSize, count: 4))

        // Overwrite data sub-chunk size at byte 40
        handle.seek(toFileOffset: 40)
        var ds = dataSize
        handle.write(Data(bytes: &ds, count: 4))

        handle.closeFile()
        fileHandle = nil
    }

    // MARK: - WAV Header

    private func buildHeader(dataSize: UInt32) -> Data {
        let byteRate = sampleRate * UInt32(channels) * UInt32(bitsPerSample) / 8
        let blockAlign = channels * bitsPerSample / 8

        var header = Data(capacity: 44)

        // RIFF chunk descriptor
        header.append(contentsOf: [0x52, 0x49, 0x46, 0x46]) // "RIFF"
        var riffSize = dataSize + 36
        header.append(Data(bytes: &riffSize, count: 4))
        header.append(contentsOf: [0x57, 0x41, 0x56, 0x45]) // "WAVE"

        // fmt sub-chunk
        header.append(contentsOf: [0x66, 0x6D, 0x74, 0x20]) // "fmt "
        var fmtSize: UInt32 = 16
        header.append(Data(bytes: &fmtSize, count: 4))
        var audioFormat: UInt16 = 1 // PCM
        header.append(Data(bytes: &audioFormat, count: 2))
        var ch = channels
        header.append(Data(bytes: &ch, count: 2))
        var sr = sampleRate
        header.append(Data(bytes: &sr, count: 4))
        var br = byteRate
        header.append(Data(bytes: &br, count: 4))
        var ba = blockAlign
        header.append(Data(bytes: &ba, count: 2))
        var bps = bitsPerSample
        header.append(Data(bytes: &bps, count: 2))

        // data sub-chunk
        header.append(contentsOf: [0x64, 0x61, 0x74, 0x61]) // "data"
        var ds = dataSize
        header.append(Data(bytes: &ds, count: 4))

        return header
    }
}
