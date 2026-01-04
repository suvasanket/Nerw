import Cocoa
import Carbon

class HotKeyManager {
    static let shared = HotKeyManager()
    
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var handler: (() -> Void)?
    private var eventID: UInt32 = 1
    
    private init() {}
    
    func register(keyCode: UInt16, modifiers: NSEvent.ModifierFlags, handler: @escaping () -> Void) {
        unregister()
        
        self.handler = handler
        
        var carbonModifiers: UInt32 = 0
        if modifiers.contains(.command) { carbonModifiers |= UInt32(cmdKey) }
        if modifiers.contains(.option) { carbonModifiers |= UInt32(optionKey) }
        if modifiers.contains(.control) { carbonModifiers |= UInt32(controlKey) }
        if modifiers.contains(.shift) { carbonModifiers |= UInt32(shiftKey) }
        
        let hotKeyID = EventHotKeyID(signature: OSType(0x4E455257), id: eventID) // 'NERW'
        var hotKeyRef: EventHotKeyRef?
        
        let error = RegisterEventHotKey(UInt32(keyCode),
                                        carbonModifiers,
                                        hotKeyID,
                                        GetApplicationEventTarget(),
                                        0,
                                        &hotKeyRef)
        
        if error == noErr {
            self.hotKeyRef = hotKeyRef
            installEventHandler()
        } else {
            print("Nerw: Failed to register hotkey with error \(error)")
        }
    }
    
    func unregister() {
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }
    
    private func installEventHandler() {
        guard eventHandler == nil else { return }
        
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        
        let handler: EventHandlerUPP = { _, _, _ -> OSStatus in
            HotKeyManager.shared.handler?()
            return noErr
        }
        
        InstallEventHandler(GetApplicationEventTarget(),
                            handler,
                            1,
                            &eventType,
                            nil,
                            &eventHandler)
    }
}
