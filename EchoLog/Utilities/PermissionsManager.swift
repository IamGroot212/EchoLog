import Foundation
import AppKit
import AVFoundation
import CoreGraphics

enum PermissionsManager {
    // MARK: - Screen Recording

    /// Check if Screen Recording permission is granted WITHOUT triggering a system prompt.
    static func checkScreenRecording() -> Bool {
        CGPreflightScreenCaptureAccess()
    }

    /// Request Screen Recording access — shows the system dialog directing to System Settings.
    /// Call this only once (e.g., during onboarding), not before every recording.
    static func requestScreenRecording() {
        CGRequestScreenCaptureAccess()
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
