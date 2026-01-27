import Cocoa
import NerwSearchBackend

public class SettingsWindowController: NSWindowController {

    public init() {
        let window = NSWindow(
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

        // Set initial size
        self.preferredContentSize = NSSize(width: 450, height: 300)
    }

    // To implement the "liquid glass" background properly with NSTabViewController:
    // We need to inject the VisualEffectView as the background of this controller's view.
    // However, NSTabViewController's view is often swapped or managed tightly.
    // Best practice: The children VCs should be transparent, and the window's contentView (or a dedicated background view) should be the effect view.
    // But since `contentViewController` takes over `window.contentView`, we wrap the logic or insert it here.

    override func loadView() {
        super.loadView()

        // Add Visual Effect View as the bottom layer of the Tab View Controller's main view
        let visualEffect = NSVisualEffectView()
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.material = .sidebar
        visualEffect.translatesAutoresizingMaskIntoConstraints = false

        self.view.addSubview(visualEffect, positioned: .below, relativeTo: nil)

        NSLayoutConstraint.activate([
            visualEffect.topAnchor.constraint(equalTo: self.view.topAnchor),
            visualEffect.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            visualEffect.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            visualEffect.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
        ])
    }
}
