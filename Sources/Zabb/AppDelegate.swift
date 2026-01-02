// AppDelegate.swift
import Cocoa
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

                // Register global hotkey (Cmd+Shift+Space)
                registerGlobalHotkey()

                // Show popup on launch for demo
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.popupController.toggle()
                }
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
        // Using NSEvent for global monitoring
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // Cmd+Shift+Space
            if event.modifierFlags.contains([.command, .shift]) && event.keyCode == 49 {
                DispatchQueue.main.async {
                    self?.popupController.toggle()
                }
            }
        }

        // Also monitor local events when app is active
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.modifierFlags.contains([.command, .shift]) && event.keyCode == 49 {
                self?.popupController.toggle()
                    return nil
            }
            return event
        }
    }
}
