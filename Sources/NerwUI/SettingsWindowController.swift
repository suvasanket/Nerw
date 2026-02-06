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
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = ""
        window.center()
        window.toolbarStyle = .preference

        // Transparency & Blur
        window.isOpaque = false
        window.backgroundColor = .clear
        window.titlebarAppearsTransparent = true

        super.init(window: window)

        // Set the content view controller to our tab controller
        let tabViewController = SettingsTabViewController()
        self.contentViewController = tabViewController

        // Setup Visual Effect View
        let visualEffectView = NSVisualEffectView()
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.material = .underWindowBackground  // Standard glassy background
        visualEffectView.state = .active
        visualEffectView.translatesAutoresizingMaskIntoConstraints = false

        if let contentView = window.contentView {
            // Add as the first subview so it's behind everything
            contentView.addSubview(visualEffectView, positioned: .below, relativeTo: nil)

            NSLayoutConstraint.activate([
                visualEffectView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                visualEffectView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                visualEffectView.topAnchor.constraint(equalTo: contentView.topAnchor),
                visualEffectView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            ])
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class SettingsTabViewController: NSTabViewController {

    static let windowSize = NSSize(width: 550, height: 450)

    override func viewDidLoad() {
        super.viewDidLoad()

        self.tabStyle = .toolbar
        self.transitionOptions = [.crossfade, .slideDown]  // Standard macOS feel

        // 1. General Tab
        let generalVC = GeneralSettingsViewController()
        generalVC.title = "General"
        generalVC.preferredContentSize = Self.windowSize
        let generalItem = NSTabViewItem(viewController: generalVC)
        generalItem.label = "General"
        generalItem.image = NSImage(
            systemSymbolName: "gear", accessibilityDescription: "General Settings")
        self.addTabViewItem(generalItem)

        // 2. Appearance Tab
        let appearanceVC = AppearanceSettingsViewController()
        appearanceVC.title = "Appearance"
        appearanceVC.preferredContentSize = Self.windowSize
        let appearanceItem = NSTabViewItem(viewController: appearanceVC)
        appearanceItem.label = "Appearance"
        appearanceItem.image = NSImage(
            systemSymbolName: "paintbrush", accessibilityDescription: "Appearance Settings")
        self.addTabViewItem(appearanceItem)

        // 3. Extensions Tab
        let extensionsVC = ExtensionSettingsViewController()
        extensionsVC.title = "Extensions"
        extensionsVC.preferredContentSize = Self.windowSize
        let extensionsItem = NSTabViewItem(viewController: extensionsVC)
        extensionsItem.label = "Extensions"
        extensionsItem.image = NSImage(
            systemSymbolName: "puzzlepiece.extension",
            accessibilityDescription: "Extensions Settings")
        self.addTabViewItem(extensionsItem)

        // Set initial size
        self.preferredContentSize = Self.windowSize
    }
}
