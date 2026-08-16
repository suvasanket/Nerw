import Cocoa
import NerwCore

public enum NerwHubTab: String, CaseIterable {
    case memory = "Memory"
    case bookmarks = "Bookmarks"
    case conversations = "Conversations"

    var iconName: String {
        switch self {
        case .memory: return "brain"
        case .bookmarks: return "bookmark"
        case .conversations: return "bubble.left.and.bubble.right"
        }
    }
}

public class NerwHubPanel: NSPanel {
    public var resignHandler: (() -> Void)?

    public override var canBecomeKey: Bool { return true }
    public override var canBecomeMain: Bool { return true }

    public override func resignKey() {
        super.resignKey()
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.resignHandler?()
        }
    }

    public override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown {
            // Esc key
            if event.keyCode == 53 {
                if let vc = contentViewController as? NerwHubViewController, vc.isSidebarExpanded {
                    vc.dismissSidebar()
                } else {
                    self.resignHandler?()
                }
                return
            }

            // Cmd + 1, 2, 3
            if event.modifierFlags.contains(.command) {
                if let char = event.charactersIgnoringModifiers, let number = Int(char) {
                    if number >= 1 && number <= NerwHubTab.allCases.count {
                        if let vc = contentViewController as? NerwHubViewController {
                            let tab = NerwHubTab.allCases[number - 1]
                            vc.selectTab(tab)
                            return
                        }
                    }
                }
            }
        }
        super.sendEvent(event)
    }
}

class BorderOverlayView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        return nil
    }
}

class NerwHubViewController: NSViewController, NerwHubSidebarDelegate {
    var onDismiss: (() -> Void)?

    var isSidebarExpanded: Bool {
        return sidebarViewController.isExpanded
    }

    private let contentContainer = NSView()

    private var sidebarViewController = NerwHubSidebarViewController()

    private var currentTabViewController: NSViewController?
    private var currentTab: NerwHubTab = .memory

    // Tab controllers cache
    private var memoryTabController: MemoryTab?

    private let panelView = NerwPanelView(style: .main)
    private var sidebarWidthConstraint: NSLayoutConstraint!
    private var sidebarHeightConstraint: NSLayoutConstraint!

    override func loadView() {
        let metricsWidth: CGFloat = 940
        let metricsHeight: CGFloat = 640
        view = NSView(frame: NSRect(x: 0, y: 0, width: metricsWidth, height: metricsHeight))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor

        setupViews()
    }

    private func setupViews() {
        panelView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(panelView)

        let borderOverlay = BorderOverlayView()
        borderOverlay.translatesAutoresizingMaskIntoConstraints = false
        borderOverlay.wantsLayer = true
        borderOverlay.layer?.borderWidth = 1.0
        borderOverlay.layer?.borderColor = NSColor.white.withAlphaComponent(0.15).cgColor
        borderOverlay.layer?.cornerRadius = GlobalLayout.cornerRadius
        borderOverlay.layer?.masksToBounds = true
        // Important: hitTest should ignore this view

        panelView.addSubview(borderOverlay)

        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        panelView.contentView.addSubview(contentContainer)

        sidebarViewController.delegate = self
        sidebarViewController.onToggle = { [weak self] in
            self?.toggleSidebar()
        }
        addChild(sidebarViewController)
        sidebarViewController.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(sidebarViewController.view)

        sidebarWidthConstraint = sidebarViewController.view.widthAnchor.constraint(
            equalToConstant: 44)
        sidebarHeightConstraint = sidebarViewController.view.heightAnchor.constraint(
            equalToConstant: 44)

        NSLayoutConstraint.activate([
            // Center panelView with exactly 900x600
            panelView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            panelView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            panelView.widthAnchor.constraint(equalToConstant: 900),
            panelView.heightAnchor.constraint(equalToConstant: 600),

            borderOverlay.topAnchor.constraint(equalTo: panelView.topAnchor),
            borderOverlay.leadingAnchor.constraint(equalTo: panelView.leadingAnchor),
            borderOverlay.trailingAnchor.constraint(equalTo: panelView.trailingAnchor),
            borderOverlay.bottomAnchor.constraint(equalTo: panelView.bottomAnchor),

            // Content container fills the panelView's contentView
            contentContainer.topAnchor.constraint(equalTo: panelView.contentView.topAnchor),
            contentContainer.bottomAnchor.constraint(equalTo: panelView.contentView.bottomAnchor),
            contentContainer.leadingAnchor.constraint(equalTo: panelView.contentView.leadingAnchor),
            contentContainer.trailingAnchor.constraint(
                equalTo: panelView.contentView.trailingAnchor),

            // Sidebar anchored to panelView's leading/top
            sidebarViewController.view.leadingAnchor.constraint(
                equalTo: panelView.leadingAnchor, constant: -22),
            sidebarViewController.view.topAnchor.constraint(
                equalTo: panelView.topAnchor, constant: 22),
            sidebarWidthConstraint,
            sidebarHeightConstraint,
        ])
    }

    func selectTab(_ tab: NerwHubTab) {
        currentTab = tab

        let newController: NSViewController
        switch tab {
        case .memory:
            if memoryTabController == nil {
                memoryTabController = MemoryTab()
            }
            newController = memoryTabController!
        case .bookmarks, .conversations:
            let placeholder = NSViewController()
            placeholder.view = NSView()
            let label = NSTextField(labelWithString: "\(tab.rawValue) - Coming Soon")
            label.translatesAutoresizingMaskIntoConstraints = false
            label.textColor = .secondaryLabelColor
            label.font = .systemFont(ofSize: 24, weight: .semibold)
            placeholder.view.addSubview(label)
            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: placeholder.view.centerXAnchor),
                label.centerYAnchor.constraint(equalTo: placeholder.view.centerYAnchor),
            ])
            newController = placeholder
        }

        if let current = currentTabViewController {
            current.view.removeFromSuperview()
            current.removeFromParent()
        }

        addChild(newController)
        newController.view.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(newController.view)

        NSLayoutConstraint.activate([
            newController.view.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            newController.view.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor),
            newController.view.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            newController.view.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
        ])

        currentTabViewController = newController
        sidebarViewController.select(tab: tab)
    }

    func toggleSidebar() {
        if sidebarViewController.isExpanded {
            dismissSidebar()
        } else {
            showSidebar()
        }
    }

    private func showSidebar() {
        sidebarViewController.isExpanded = true
        sidebarWidthConstraint.constant = 220
        sidebarHeightConstraint.constant = 600

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            ctx.allowsImplicitAnimation = true
            self.view.layoutSubtreeIfNeeded()
        }

        DispatchQueue.main.async { [weak self] in
            if let window = self?.view.window, let view = self?.sidebarViewController.view {
                window.makeFirstResponder(view)
            }
        }
    }

    func dismissSidebar(animated: Bool = true) {
        let cleanup: () -> Void = { [weak self] in
            if self?.view.window?.isVisible == true {
                self?.view.window?.makeKeyAndOrderFront(nil)
                if let currentTab = self?.currentTabViewController {
                    self?.view.window?.makeFirstResponder(currentTab.view)
                }
            }
        }

        sidebarViewController.isExpanded = false
        sidebarWidthConstraint.constant = 44
        sidebarHeightConstraint.constant = 44

        guard animated else {
            self.view.layoutSubtreeIfNeeded()
            cleanup()
            return
        }

        NSAnimationContext.runAnimationGroup(
            { ctx in
                ctx.duration = 0.20
                ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                ctx.allowsImplicitAnimation = true
                self.view.layoutSubtreeIfNeeded()
            }, completionHandler: cleanup)
    }

    // MARK: - NerwHubSidebarDelegate

    func didSelect(tab: NerwHubTab) {
        selectTab(tab)
    }

    func didRequestDismissSidebar() {
        dismissSidebar()
    }

    // MARK: - Keyboard Handling

    override func keyDown(with event: NSEvent) {
        let normalizedFlags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if normalizedFlags.contains(.command) {
            switch event.charactersIgnoringModifiers {
            case "1":
                if NerwHubTab.allCases.count > 0 {
                    selectTab(NerwHubTab.allCases[0])
                    dismissSidebar()
                }
                return
            case "2":
                if NerwHubTab.allCases.count > 1 {
                    selectTab(NerwHubTab.allCases[1])
                    dismissSidebar()
                }
                return
            case "3":
                if NerwHubTab.allCases.count > 2 {
                    selectTab(NerwHubTab.allCases[2])
                    dismissSidebar()
                }
                return
            default:
                break
            }
        }

        if event.keyCode == 53 {  // Esc
            onDismiss?()
            return
        }

        super.keyDown(with: event)
    }
}
