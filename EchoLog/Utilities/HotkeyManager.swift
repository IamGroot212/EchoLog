import Cocoa

@MainActor
final class HotkeyManager {
    private weak var controller: RecordingController?
    private var globalMonitor: Any?
    private var localMonitor: Any?

    init(controller: RecordingController) {
        self.controller = controller
    }

    func register() {
        let settings = AppSettings.shared
        let targetKeyCode = settings.hotkeyKeyCode
        let targetModifiers = NSEvent.ModifierFlags(rawValue: settings.hotkeyModifiers)

        // Global monitor — fires when EchoLog is NOT the focused app
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.matchesHotkey(event, keyCode: targetKeyCode, modifiers: targetModifiers) == true {
                Task { @MainActor in
                    await self?.controller?.toggleRecording()
                }
            }
        }

        // Local monitor — fires when EchoLog IS the focused app
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.matchesHotkey(event, keyCode: targetKeyCode, modifiers: targetModifiers) == true {
                Task { @MainActor in
                    await self?.controller?.toggleRecording()
                }
                return nil // consume the event
            }
            return event
        }
    }

    func unregister() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }

    private func matchesHotkey(_ event: NSEvent, keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> Bool {
        // Mask to only care about command, shift, option, control
        let relevantFlags: NSEvent.ModifierFlags = [.command, .shift, .option, .control]
        let eventMods = event.modifierFlags.intersection(relevantFlags)
        let targetMods = modifiers.intersection(relevantFlags)
        return event.keyCode == keyCode && eventMods == targetMods
    }

    deinit {
        // Note: deinit runs on whatever thread; monitors must be removed
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
