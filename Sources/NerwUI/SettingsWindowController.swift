import Cocoa
import NerwBuiltin
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

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command) {
            guard let key = event.charactersIgnoringModifiers?.lowercased() else {
                return super.performKeyEquivalent(with: event)
            }
            switch key {
            case "v":
                if NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: self) {
                    return true
                }
            case "c":
                if NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: self) { return true }
            case "x":
                if NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: self) { return true }
            case "a":
                if NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: self) {
                    return true
                }
            default:
                break
            }
        }
        return super.performKeyEquivalent(with: event)
    }
}

public class SettingsWindowController: NSWindowController, NSWindowDelegate {

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

        window.delegate = self

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

    public func windowWillClose(_ notification: Notification) {
        SearchService.shared.clearCache()
    }

    public func selectTab(named name: String) {
        guard let tabViewController = contentViewController as? SettingsTabViewController else {
            return
        }
        switch name.lowercased() {
        case "general": tabViewController.selectedTabViewItemIndex = 0
        case "appearance": tabViewController.selectedTabViewItemIndex = 1
        case "features": tabViewController.selectedTabViewItemIndex = 2
        case "search": tabViewController.selectedTabViewItemIndex = 3
        case "actions": tabViewController.selectedTabViewItemIndex = 4
        case "extensions": tabViewController.selectedTabViewItemIndex = 5
        case "ai": tabViewController.selectedTabViewItemIndex = 6
        default: break
        }
    }
}

class SettingsTabViewController: NSTabViewController {

    static let windowSize = NSSize(width: 800, height: 600)

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

        // 2.5 Features Tab
        let featuresVC = FeaturesSettingsViewController()
        featuresVC.title = "Features"
        featuresVC.preferredContentSize = Self.windowSize
        let featuresItem = NSTabViewItem(viewController: featuresVC)
        featuresItem.label = "Features"
        featuresItem.image = NSImage(
            systemSymbolName: "sparkles", accessibilityDescription: "Features Settings")
        self.addTabViewItem(featuresItem)

        // 3. Search Tab
        let searchVC = SearchEnginesSettingsViewController()
        searchVC.title = "Search"
        searchVC.preferredContentSize = Self.windowSize
        let searchItem = NSTabViewItem(viewController: searchVC)
        searchItem.label = "Search"
        searchItem.image = NSImage(
            systemSymbolName: "magnifyingglass", accessibilityDescription: "Search Settings")
        self.addTabViewItem(searchItem)

        // 3.5 Actions Tab
        let actionsVC = ActionsSettingsViewController()
        actionsVC.title = "Actions"
        actionsVC.preferredContentSize = Self.windowSize
        let actionsItem = NSTabViewItem(viewController: actionsVC)
        actionsItem.label = "Actions"
        actionsItem.image = NSImage(
            systemSymbolName: "command", accessibilityDescription: "Action Triggers")
        self.addTabViewItem(actionsItem)

        // 4. Extensions Tab
        let extensionsVC = ExtensionSettingsViewController()
        extensionsVC.title = "Extensions"
        extensionsVC.preferredContentSize = Self.windowSize
        let extensionsItem = NSTabViewItem(viewController: extensionsVC)
        extensionsItem.label = "Extensions"
        extensionsItem.image = NSImage(
            systemSymbolName: "puzzlepiece.extension",
            accessibilityDescription: "Extensions Settings")
        self.addTabViewItem(extensionsItem)

        // 5. AI Tab
        let aiVC = AISettingsViewController()
        aiVC.title = "NerwAI"
        aiVC.preferredContentSize = Self.windowSize
        let aiItem = NSTabViewItem(viewController: aiVC)
        aiItem.label = "NerwAI"
        aiItem.image = NSImage(
            systemSymbolName: "00.circle.fill.hi",
            accessibilityDescription: "AI Settings")
        self.addTabViewItem(aiItem)

        // Set initial size
        self.preferredContentSize = Self.windowSize

        // Select Actions tab by default
        self.selectedTabViewItemIndex = 4
    }
}
