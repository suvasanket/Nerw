import Carbon.HIToolbox
import Cocoa
import NerwAction
import NerwBuiltin
import NerwCore
import NerwSearchBackend
import NerwUI
import NerwUtils

class AppDelegate: NSObject, NSApplicationDelegate {
    private var popupController: MainPanelWindowController!
    private var settingsController: SettingsWindowController?
    private var extensionInstallController: ExtensionInstallWindowController?
    private var clipboardController = ClipboardController()
    private var snippetController = SnippetController()
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Logger.shared.info("AppDelegate: applicationDidFinishLaunching")

        NSApp.setActivationPolicy(.accessory)

        popupController = MainPanelWindowController()

        setupStatusItem()

        registerGlobalHotkey()

        ClipboardManager.shared.showWindowCallback = { [weak self] in
            // Show the new window first so the app doesn't lose the key window
            self?.clipboardController.show()
            // Then hide the main panel without aggressively restoring OS focus
            self?.popupController.hide(restoreFocus: false)
        }
        if ConfigManager.shared.config.clipboardEnabled {
            ClipboardManager.shared.start()
        }

        SnippetManager.shared.showWindowCallback = { [weak self] in
            self?.snippetController.show()
            self?.popupController.hide(restoreFocus: false)
        }

        if ConfigManager.shared.config.snippetExpansionEnabled {
            TextExpansionEngine.shared.start()
        }

        NotificationCenter.default.addObserver(
            self, selector: #selector(configDidUpdate),
            name: Notification.Name("NerwConfigDidUpdate"),
            object: nil)

        NotificationCenter.default.addObserver(
            self, selector: #selector(configDidUpdate),
            name: Notification.Name("NerwActionPreferencesDidUpdate"),
            object: nil)

        NotificationCenter.default.addObserver(
            self, selector: #selector(openSettings),
            name: Notification.Name("NerwOpenSettings"),
            object: nil)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.popupController.toggle()
        }

        // Start daemon extensions (approved and enabled)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            DaemonManager.shared.startAllApproved()
        }

        // Listen for daemon approval requests from installer
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleDaemonApprovalRequired(_:)),
            name: .nerwDaemonApprovalRequired, object: nil)

        // Listen for daemon start/stop requests from CLI
        DistributedNotificationCenter.default().addObserver(
            self, selector: #selector(handleDaemonStartRequest(_:)),
            name: NSNotification.Name("com.nerw.daemon.start"), object: nil)
        DistributedNotificationCenter.default().addObserver(
            self, selector: #selector(handleDaemonStopRequest(_:)),
            name: NSNotification.Name("com.nerw.daemon.stop"), object: nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        DaemonManager.shared.stopAll()
        ExtensionEngine.shared.terminateAllLongRunning()
        Logger.shared.info("AppDelegate: applicationWillTerminate")
        Logger.shared.flush()
    }

    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        if filename.hasSuffix(".nerw") {
            let url = URL(fileURLWithPath: filename)
            if let manifest = ExtensionInstaller.shared.inspectPackage(at: url) {
                if extensionInstallController == nil {
                    extensionInstallController = ExtensionInstallWindowController()
                }
                extensionInstallController?.show(for: url, manifest: manifest)
                return true
            }
        }
        return false
    }

    @objc private func configDidUpdate() {
        registerGlobalHotkey()

        if ConfigManager.shared.config.snippetExpansionEnabled {
            TextExpansionEngine.shared.start()
        } else {
            TextExpansionEngine.shared.stop()
        }

        if ConfigManager.shared.config.clipboardEnabled {
            ClipboardManager.shared.start()
        } else {
            ClipboardManager.shared.stop()
        }
    }

    // MARK: - Daemon Handlers

    @objc private func handleDaemonApprovalRequired(_ notification: Notification) {
        guard let info = notification.userInfo,
            let extensionId = info["extensionId"] as? String,
            let description = info["daemonDescription"] as? String
        else { return }

        // Show a system alert asking the user to approve daemon mode
        let alert = NSAlert()
        alert.messageText = "Background Daemon Permission"
        alert.informativeText =
            "The extension '\(extensionId)' wants to run continuously in the background:\n\n\(description)\n\nAllow this extension to run as a background daemon?"
        alert.addButton(withTitle: "Allow")
        alert.addButton(withTitle: "Deny")
        alert.alertStyle = .warning

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            DaemonRegistry.shared.approve(extensionId)
            do {
                try DaemonManager.shared.startDaemon(extensionId: extensionId)
                NerwNotificationManager.shared.show(
                    content: "Daemon started for '\(extensionId)'")
            } catch {
                NerwNotificationManager.shared.show(
                    content: "Failed to start daemon for '\(extensionId)': \(error)",
                    level: .error)
            }
        } else {
            NerwNotificationManager.shared.show(
                content: "Daemon permission denied for '\(extensionId)'.")
        }
    }
    @objc private func handleDaemonStartRequest(_ notification: Notification) {
        guard let extensionId = notification.object as? String else { return }
        DaemonRegistry.shared.load()
        guard DaemonRegistry.shared.isApproved(extensionId) else {
            print("[AppDelegate] Daemon start requested for '\(extensionId)' but not approved.")
            return
        }
        do {
            try DaemonManager.shared.startDaemon(extensionId: extensionId)
        } catch {
            print("[AppDelegate] Failed to start daemon '\(extensionId)': \(error)")
        }
    }

    @objc private func handleDaemonStopRequest(_ notification: Notification) {
        guard let extensionId = notification.object as? String else { return }
        DaemonRegistry.shared.load()
        DaemonManager.shared.stopDaemon(extensionId: extensionId)
    }
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: nil)
            button.action = #selector(statusBarIconClicked(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    @objc private func statusBarIconClicked(_ sender: NSStatusBarButton) {
        let menu = NSMenu()

        menu.addItem(
            NSMenuItem(
                title: "Toggle Search", action: #selector(togglePopup), keyEquivalent: "Space"))
        menu.addItem(NSMenuItem.separator())

        let cliTitle = CLIUtils.shared.isInstalled() ? "Disable CLI" : "Enable CLI"
        menu.addItem(
            NSMenuItem(title: cliTitle, action: #selector(enableCLI), keyEquivalent: "")
        )

        menu.addItem(
            NSMenuItem(title: "Settings", action: #selector(openSettings), keyEquivalent: ",")
        )
        menu.addItem(NSMenuItem.separator())
        menu.addItem(
            NSMenuItem(title: "Quit Nerw", action: #selector(terminateApp), keyEquivalent: "q"))

        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)  // Trigger menu immediately
        statusItem?.menu = nil
    }

    @objc private func enableCLI() {
        if CLIUtils.shared.isInstalled() {
            CLIUtils.shared.uninstallCLI { success, error in
                if success {
                    NerwNotificationManager.shared.show(
                        content: "Nerw CLI has been successfully disabled.")
                } else if let error = error {
                    let alert = NSAlert()
                    alert.messageText = "CLI Disable Failed"
                    alert.informativeText = error
                    alert.runModal()
                }
            }
        } else {
            CLIUtils.shared.setupCLI { success, error in
                if success {
                    NerwNotificationManager.shared.show(
                        content: "Nerw CLI enabled. Restart terminal to apply PATH changes.")
                } else if let error = error {
                    let alert = NSAlert()
                    alert.messageText = "CLI Setup Failed"
                    alert.informativeText = error
                    alert.runModal()
                }
            }
        }
    }

    @objc private func togglePopup() {
        if clipboardController.isVisible {
            clipboardController.didCancel()
            return
        }
        if snippetController.isVisible {
            snippetController.didCancel()
            return
        }
        popupController.toggle()
    }

    @objc private func openSettings() {
        if settingsController == nil {
            settingsController = SettingsWindowController()
        }
        settingsController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        settingsController?.window?.makeKeyAndOrderFront(nil)
    }

    @objc private func terminateApp() {
        NSApp.terminate(nil)
    }

    private func registerGlobalHotkey() {
        // Unregister all existing hotkeys first to avoid duplicates
        HotKeyManager.shared.unregisterAll()

        // 1. Register Main Global Toggle
        let config = ConfigManager.shared.config
        let configString = config.globalKeybind
        let (modifiers, keyCode) =
            HotkeyParser.parse(configString) ?? (.command.union(.shift), 49)
        // Default: Cmd+Shift+Space

        HotKeyManager.shared.register(
            identifier: "nerw.global.toggle", keyCode: keyCode, modifiers: modifiers
        ) { [weak self] in
            DispatchQueue.main.async {
                self?.popupController.toggle()
            }
        }

        // 2. Register Action-Specific Hotkeys
        for (actionID, hotkey) in NerwActionPreferenceManager.shared.preferences.actionHotkeys {
            guard let (mods, code) = HotkeyParser.parse(hotkey) else { continue }

            HotKeyManager.shared.register(
                identifier: "nerw.action.\(actionID)", keyCode: code, modifiers: mods
            ) {
                DispatchQueue.main.async {
                    SearchService.shared.performAction(id: actionID)
                }
            }
        }
    }
}
