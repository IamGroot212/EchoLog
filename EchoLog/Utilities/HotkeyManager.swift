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
        let recordKeyCode = settings.hotkeyKeyCode
        let recordModifiers = NSEvent.ModifierFlags(rawValue: settings.hotkeyModifiers)
        let micKeyCode = settings.micMuteKeyCode
        let micModifiers = NSEvent.ModifierFlags(rawValue: settings.micMuteModifiers)

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.matchesHotkey(event, keyCode: recordKeyCode, modifiers: recordModifiers) == true {
                Task { @MainActor in await self?.controller?.toggleRecording() }
            } else if self?.matchesHotkey(event, keyCode: micKeyCode, modifiers: micModifiers) == true {
                Task { @MainActor in self?.controller?.toggleMic() }
            }
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.matchesHotkey(event, keyCode: recordKeyCode, modifiers: recordModifiers) == true {
                Task { @MainActor in await self?.controller?.toggleRecording() }
                return nil
            } else if self?.matchesHotkey(event, keyCode: micKeyCode, modifiers: micModifiers) == true {
                Task { @MainActor in self?.controller?.toggleMic() }
                return nil
            }
            return event
        }
    }

    func reRegister() {
        unregister()
        register()
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
        let relevantFlags: NSEvent.ModifierFlags = [.command, .shift, .option, .control]
        let eventMods = event.modifierFlags.intersection(relevantFlags)
        let targetMods = modifiers.intersection(relevantFlags)
        return event.keyCode == keyCode && eventMods == targetMods
    }

    deinit {
        if let monitor = globalMonitor { NSEvent.removeMonitor(monitor) }
        if let monitor = localMonitor { NSEvent.removeMonitor(monitor) }
    }
}
