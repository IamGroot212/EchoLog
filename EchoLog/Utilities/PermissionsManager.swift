import Foundation
import AVFoundation
import ScreenCaptureKit

enum PermissionsManager {
    // MARK: - Screen Recording

    static func checkScreenRecording() async -> Bool {
        do {
            _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
            return true
        } catch {
            return false
        }
    }

    static func openScreenRecordingSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Microphone

    static func checkMicrophone() -> Bool {
        AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    static func requestMicrophone() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .audio)
    }

    // MARK: - Tool Checks

    static func checkWhisperInstalled() -> Bool {
        FileManager.default.fileExists(atPath: AppSettings.shared.whisperBinaryPath)
    }

    static func checkOllamaRunning() async -> Bool {
        guard let url = URL(string: "\(AppSettings.shared.ollamaBaseURL)/api/tags") else { return false }
        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
}
