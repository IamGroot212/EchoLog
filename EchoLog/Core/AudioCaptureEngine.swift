import Foundation
import ScreenCaptureKit
import AVFoundation
import CoreMedia

enum AudioCaptureError: LocalizedError {
    case noDisplayFound
    case appNotFound(bundleIdentifier: String)
    case notCapturing
    case screenCapturePermissionDenied

    var errorDescription: String? {
        switch self {
        case .noDisplayFound:
            return "No display found for audio capture."
        case .appNotFound(let id):
            return "Application \(id) not found in running apps."
        case .notCapturing:
            return "Not currently capturing audio."
        case .screenCapturePermissionDenied:
            return "Screen Recording permission is required. Enable it in System Settings > Privacy & Security > Screen Recording."
        }
    }
}

final class AudioCaptureEngine: NSObject, @unchecked Sendable {
    private(set) var isCapturing = false
    private(set) var captureStartDate: Date?

    private var scStream: SCStream?
    private var audioEngine: AVAudioEngine?
    private var wavWriter: WAVWriter?
    private var mode: AudioCaptureMode = .systemAudio

    private let writeQueue = DispatchQueue(label: "com.echoLog.audioWrite", qos: .userInitiated)

    // Resampler for converting ScreenCaptureKit's 48kHz Float32 → 16kHz Int16
    private var audioConverter: AVAudioConverter?
    private var sourceFormat: AVAudioFormat?

    // MARK: - Public API

    func startCapture(mode: AudioCaptureMode, outputURL: URL) async throws {
        self.mode = mode

        let writer = WAVWriter(outputURL: outputURL)
        try writer.start()
        self.wavWriter = writer

        switch mode {
        case .systemAudio:
            try await startScreenCapture(appFilter: nil)
        case .perApp(let bundleID):
            try await startScreenCapture(appFilter: bundleID)
        case .microphone:
            try startMicrophoneCapture()
        }

        isCapturing = true
        captureStartDate = Date()
    }

    func stopCapture() async throws -> URL {
        guard isCapturing, let writer = wavWriter else {
            throw AudioCaptureError.notCapturing
        }

        if let stream = scStream {
            try await stream.stopCapture()
            scStream = nil
        }

        if let engine = audioEngine {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
            audioEngine = nil
        }

        writeQueue.sync {
            try? writer.finalize()
        }

        isCapturing = false
        captureStartDate = nil
        audioConverter = nil
        sourceFormat = nil

        let url = writer.outputURL
        wavWriter = nil
        return url
    }

    // MARK: - Available Apps

    func availableApps() async throws -> [CapturedApp] {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        return content.applications.compactMap { app -> CapturedApp? in
            let bundleID = app.bundleIdentifier
            guard !bundleID.isEmpty else { return nil }
            return CapturedApp(
                bundleIdentifier: bundleID,
                displayName: app.applicationName
            )
        }.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    // MARK: - ScreenCaptureKit

    private func startScreenCapture(appFilter: String?) async throws {
        let content: SCShareableContent
        do {
            content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        } catch {
            throw AudioCaptureError.screenCapturePermissionDenied
        }

        guard let display = content.displays.first else {
            throw AudioCaptureError.noDisplayFound
        }

        let filter: SCContentFilter
        if let bundleID = appFilter {
            guard let app = content.applications.first(where: { $0.bundleIdentifier == bundleID }) else {
                throw AudioCaptureError.appNotFound(bundleIdentifier: bundleID)
            }
            filter = SCContentFilter(display: display, including: [app], exceptingWindows: [])
        } else {
            let selfBundleID = Bundle.main.bundleIdentifier
            let excludedApps = content.applications.filter { $0.bundleIdentifier == selfBundleID }
            filter = SCContentFilter(display: display, excludingApplications: excludedApps, exceptingWindows: [])
        }

        let config = SCStreamConfiguration()
        config.capturesAudio = true
        config.sampleRate = 48000
        config.channelCount = 1
        config.excludesCurrentProcessAudio = true
        // Minimal video — we only care about audio
        config.width = 2
        config.height = 2

        // Set up the audio converter: 48kHz Float32 mono → 16kHz Int16 mono
        let srcFmt = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 48000, channels: 1, interleaved: false)!
        let dstFmt = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16000, channels: 1, interleaved: true)!
        audioConverter = AVAudioConverter(from: srcFmt, to: dstFmt)
        sourceFormat = srcFmt

        let stream = SCStream(filter: filter, configuration: config, delegate: self)
        try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: writeQueue)
        try await stream.startCapture()
        scStream = stream
    }

    // MARK: - Microphone (AVAudioEngine)

    private func startMicrophoneCapture() throws {
        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        let targetFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16000, channels: 1, interleaved: true)!
        guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            throw AudioCaptureError.noDisplayFound // reuse error; mic format unsupported
        }

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            self?.processMicBuffer(buffer, converter: converter, targetFormat: targetFormat)
        }

        try engine.start()
        audioEngine = engine
    }

    private func processMicBuffer(_ buffer: AVAudioPCMBuffer, converter: AVAudioConverter, targetFormat: AVAudioFormat) {
        let frameCapacity = AVAudioFrameCount(
            Double(buffer.frameLength) * (16000.0 / buffer.format.sampleRate)
        )
        guard frameCapacity > 0,
              let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: frameCapacity) else {
            return
        }

        var error: NSError?
        var isDone = false
        converter.convert(to: outputBuffer, error: &error) { _, outStatus in
            if isDone {
                outStatus.pointee = .noDataNow
                return nil
            }
            isDone = true
            outStatus.pointee = .haveData
            return buffer
        }

        guard error == nil, outputBuffer.frameLength > 0 else { return }

        let byteCount = Int(outputBuffer.frameLength) * Int(targetFormat.streamDescription.pointee.mBytesPerFrame)
        guard let int16Data = outputBuffer.int16ChannelData else { return }
        let data = Data(bytes: int16Data[0], count: byteCount)

        writeQueue.async { [weak self] in
            try? self?.wavWriter?.appendPCMData(data)
        }
    }
}

// MARK: - SCStreamOutput

extension AudioCaptureEngine: SCStreamOutput {
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio else { return }
        processSCKAudioBuffer(sampleBuffer)
    }

    private func processSCKAudioBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard let converter = audioConverter,
              let srcFmt = sourceFormat else { return }

        // Get the number of samples
        let numSamples = CMSampleBufferGetNumSamples(sampleBuffer)
        guard numSamples > 0 else { return }

        // Extract audio buffer list
        var audioBufferList = AudioBufferList()
        var blockBuffer: CMBlockBuffer?
        CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer,
            bufferListSizeNeededOut: nil,
            bufferListOut: &audioBufferList,
            bufferListSize: MemoryLayout<AudioBufferList>.size,
            blockBufferAllocator: nil,
            blockBufferMemoryAllocator: nil,
            flags: kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment,
            blockBufferOut: &blockBuffer
        )

        guard let bufferData = audioBufferList.mBuffers.mData else { return }
        let bufferByteSize = Int(audioBufferList.mBuffers.mDataByteSize)

        // Wrap Float32 samples in an AVAudioPCMBuffer
        guard let inputBuffer = AVAudioPCMBuffer(pcmFormat: srcFmt, frameCapacity: AVAudioFrameCount(numSamples)) else {
            return
        }
        inputBuffer.frameLength = AVAudioFrameCount(numSamples)

        guard let floatChannelData = inputBuffer.floatChannelData else { return }
        memcpy(floatChannelData[0], bufferData, min(bufferByteSize, Int(numSamples) * MemoryLayout<Float>.size))

        // Convert to 16kHz Int16
        let outputFrameCapacity = AVAudioFrameCount(Double(numSamples) * (16000.0 / 48000.0))
        guard outputFrameCapacity > 0 else { return }

        let dstFmt = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16000, channels: 1, interleaved: true)!
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: dstFmt, frameCapacity: outputFrameCapacity) else {
            return
        }

        var error: NSError?
        var isDone = false
        converter.convert(to: outputBuffer, error: &error) { _, outStatus in
            if isDone {
                outStatus.pointee = .noDataNow
                return nil
            }
            isDone = true
            outStatus.pointee = .haveData
            return inputBuffer
        }

        guard error == nil, outputBuffer.frameLength > 0 else { return }

        let byteCount = Int(outputBuffer.frameLength) * MemoryLayout<Int16>.size
        guard let int16Data = outputBuffer.int16ChannelData else { return }
        let data = Data(bytes: int16Data[0], count: byteCount)

        try? wavWriter?.appendPCMData(data)
    }
}

// MARK: - SCStreamDelegate

extension AudioCaptureEngine: SCStreamDelegate {
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        // Stream stopped unexpectedly — could handle reconnection here
        isCapturing = false
    }
}
