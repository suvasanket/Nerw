import Carbon.HIToolbox
import Cocoa
import NerwCore
import NerwSearchBackend
import NerwUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var popupController: MainPanelWindowController!
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Run as accessory (no dock icon)
        NSApp.setActivationPolicy(.accessory)

        // Initialize popup
        popupController = MainPanelWindowController()

        // Setup menu bar icon (optional)
        setupStatusItem()

        // Register global hotkey
        registerGlobalHotkey()

        // Listen for config changes to update hotkey
        NotificationCenter.default.addObserver(
            self, selector: #selector(configDidUpdate),
            name: Notification.Name("NerwConfigDidUpdate"),
            object: nil)

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
        let configString = ConfigManager.shared.config.globalKeybind
        let (modifiers, keyCode) =
            HotkeyParser.parse(configString) ?? (.command.union(.shift), 49)
        // Default: Cmd+Shift+Space

        HotKeyManager.shared.register(keyCode: keyCode, modifiers: modifiers) { [weak self] in
            DispatchQueue.main.async {
                self?.popupController.toggle()
            }
        }
    }
}
