import Cocoa
import NerwCore
import NerwUI
import NerwSearchBackend
import Carbon.HIToolbox

class AppDelegate: NSObject, NSApplicationDelegate {
    private var popupController: PopupWindowController!
    private var statusItem: NSStatusItem?
    private var eventMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Run as accessory (no dock icon)
        NSApp.setActivationPolicy(.accessory)

        // Initialize popup
        popupController = PopupWindowController()

        // Setup menu bar icon (optional)
        setupStatusItem()

        // Register global hotkey
        registerGlobalHotkey()
        
        // Listen for config changes to update hotkey
        NotificationCenter.default.addObserver(self, selector: #selector(configDidUpdate), name: Notification.Name("NerwConfigDidUpdate"), object: nil)

        // Show popup on launch for demo
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.popupController.toggle()
        }
    }
    
    @objc private func configDidUpdate() {
        registerGlobalHotkey()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
            if let button = statusItem?.button {
                button.image = NSImage(systemSymbolName: "command", accessibilityDescription: nil)
                    button.action = #selector(togglePopup)
            }
    }

    @objc private func togglePopup() {
        popupController.toggle()
    }

    private func registerGlobalHotkey() {
        // Remove existing monitor if re-registering
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        
        let configString = ConfigManager.shared.config.globalKeybind
        let (modifiers, keyCode) = HotkeyParser.parse(configString) ?? (.command.union(.shift), 49) // Default: Cmd+Shift+Space
        
        // Using NSEvent for global monitoring
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.modifierFlags.intersection(.deviceIndependentFlagsMask) == modifiers && event.keyCode == keyCode {
                DispatchQueue.main.async {
                    self?.popupController.toggle()
                }
            }
        }

        // Also monitor local events when app is active
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.modifierFlags.intersection(.deviceIndependentFlagsMask) == modifiers && event.keyCode == keyCode {
                self?.popupController.toggle()
                return nil
            }
            return event
        }
    }
}
