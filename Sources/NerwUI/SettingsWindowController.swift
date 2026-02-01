import Cocoa
import NerwSearchBackend

private class SettingsWindow: NSWindow {
    override func keyDown(with event: NSEvent) {
        // Handle Cmd+W to close
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "w" {
            self.close()
            return
        }
        super.keyDown(with: event)
    }
}

public class SettingsWindowController: NSWindowController {

    public init() {
        let window = SettingsWindow(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.center()
        window.toolbarStyle = .preference

        super.init(window: window)

        // Set the content view controller to our tab controller
        let tabViewController = SettingsTabViewController()
        self.contentViewController = tabViewController
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class SettingsTabViewController: NSTabViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        self.tabStyle = .toolbar
        self.transitionOptions = [.crossfade, .slideDown]  // Standard macOS feel

        // 1. General Tab
        let generalVC = GeneralSettingsViewController()
        generalVC.title = "General"
        let generalItem = NSTabViewItem(viewController: generalVC)
        generalItem.label = "General"
        generalItem.image = NSImage(
            systemSymbolName: "gear", accessibilityDescription: "General Settings")
        self.addTabViewItem(generalItem)

        // 2. Appearance Tab
        let appearanceVC = AppearanceSettingsViewController()
        appearanceVC.title = "Appearance"
        let appearanceItem = NSTabViewItem(viewController: appearanceVC)
        appearanceItem.label = "Appearance"
        appearanceItem.image = NSImage(
            systemSymbolName: "paintbrush", accessibilityDescription: "Appearance Settings")
        self.addTabViewItem(appearanceItem)

        // 3. Extensions Tab
        let extensionsVC = ExtensionSettingsViewController()
        extensionsVC.title = "Extensions"
        let extensionsItem = NSTabViewItem(viewController: extensionsVC)
        extensionsItem.label = "Extensions"
        extensionsItem.image = NSImage(
            systemSymbolName: "puzzlepiece.extension",
            accessibilityDescription: "Extensions Settings")
        self.addTabViewItem(extensionsItem)

        // Set initial size
        self.preferredContentSize = NSSize(width: 450, height: 300)
    }
}
