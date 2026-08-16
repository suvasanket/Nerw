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
            if event.keyCode == 53 {
                self.resignHandler?()
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

extension NerwHubViewController: NerwHubTabBarDelegate {
    func didSelect(tab: NerwHubTab) {
        selectTab(tab)
    }
}

class NerwHubViewController: NSViewController {
    var onDismiss: (() -> Void)?

    private let contentContainer = NSView()

    private var tabBarView = NerwHubTabBarView()

    private var currentTabViewController: NSViewController?
    private var currentTab: NerwHubTab = .memory

    // Tab controllers cache
    private var memoryTabController: MemoryTab?

    private let panelView = NerwPanelView(style: .main)

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
        ])

        tabBarView.translatesAutoresizingMaskIntoConstraints = false
        tabBarView.delegate = self
        view.addSubview(tabBarView)  // Added to the main view, not inside panelView

        NSLayoutConstraint.activate([
            tabBarView.centerYAnchor.constraint(equalTo: panelView.topAnchor),  // Straddles the top border
            tabBarView.leadingAnchor.constraint(equalTo: panelView.leadingAnchor, constant: 32),
            tabBarView.heightAnchor.constraint(equalToConstant: 36),
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
        tabBarView.select(tab: tab)
    }

    // MARK: - Keyboard Handling

    override func keyDown(with event: NSEvent) {
        let normalizedFlags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if normalizedFlags.contains(.command) {
            switch event.charactersIgnoringModifiers {
            case "1":
                if NerwHubTab.allCases.count > 0 {
                    selectTab(NerwHubTab.allCases[0])
                }
                return
            case "2":
                if NerwHubTab.allCases.count > 1 {
                    selectTab(NerwHubTab.allCases[1])
                }
                return
            case "3":
                if NerwHubTab.allCases.count > 2 {
                    selectTab(NerwHubTab.allCases[2])
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
