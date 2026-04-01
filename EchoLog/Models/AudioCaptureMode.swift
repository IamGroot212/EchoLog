import Foundation

enum AudioCaptureMode: Hashable {
    case systemAudio
    case perApp(bundleIdentifier: String)
    case microphoneOnly
}
