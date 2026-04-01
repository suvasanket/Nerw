import Carbon
import Cocoa

class HotKeyManager {
    static let shared = HotKeyManager()

    private var hotKeyRefs: [String: EventHotKeyRef] = [:]
    private var handlers: [UInt32: () -> Void] = [:]
    private var eventHandler: EventHandlerRef?
    private var nextEventID: UInt32 = 1

    private init() {}

    func register(
        identifier: String, keyCode: UInt16, modifiers: NSEvent.ModifierFlags,
        handler: @escaping () -> Void
    ) {
        unregister(identifier: identifier)

        let eventID = nextEventID
        nextEventID += 1
        handlers[eventID] = handler

        var carbonModifiers: UInt32 = 0
        if modifiers.contains(.command) { carbonModifiers |= UInt32(cmdKey) }
        if modifiers.contains(.option) { carbonModifiers |= UInt32(optionKey) }
        if modifiers.contains(.control) { carbonModifiers |= UInt32(controlKey) }
        if modifiers.contains(.shift) { carbonModifiers |= UInt32(shiftKey) }

        let hotKeyID = EventHotKeyID(signature: OSType(0x4E45_5257), id: eventID)  // 'NERW'
        var hotKeyRef: EventHotKeyRef?

        let error = RegisterEventHotKey(
            UInt32(keyCode),
            carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef)

        if error == noErr, let ref = hotKeyRef {
            self.hotKeyRefs[identifier] = ref
            installEventHandler()
        } else {
            print("Nerw: Failed to register hotkey '\(identifier)' with error \(error)")
        }
    }

    func unregister(identifier: String) {
        if let hotKeyRef = hotKeyRefs[identifier] {
            UnregisterEventHotKey(hotKeyRef)
            hotKeyRefs.removeValue(forKey: identifier)
            // We don't easily know the eventID here without storing it back-mapping
            // But handlers are small, so it's okay for now or we can store ID in hotKeyRefs
        }
    }

    func unregisterAll() {
        for ref in hotKeyRefs.values {
            UnregisterEventHotKey(ref)
        }
        hotKeyRefs.removeAll()
        handlers.removeAll()
        nextEventID = 1
    }

    private func installEventHandler() {
        guard eventHandler == nil else { return }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        let handler: EventHandlerUPP = { _, event, _ -> OSStatus in
            var hotKeyID = EventHotKeyID()
            let error = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID)

            if error == noErr {
                HotKeyManager.shared.handlers[hotKeyID.id]?()
            }
            return noErr
        }

        InstallEventHandler(
            GetApplicationEventTarget(),
            handler,
            1,
            &eventType,
            nil,
            &eventHandler)
    }
}
