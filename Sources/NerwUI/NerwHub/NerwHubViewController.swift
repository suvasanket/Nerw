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
                if let vc = contentViewController as? NerwHubViewController, vc.isOverlayOpen {
                    super.sendEvent(event)
                    return
                }
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

class NerwHubViewController: NSViewController, HubCommandPaletteDelegate {
    var onDismiss: (() -> Void)?

    var isOverlayOpen: Bool {
        if let palette = commandPaletteController,
            !palette.view.isHidden && palette.view.alphaValue > 0
        {
            return true
        }
        if let floating = floatingInputController,
            !floating.view.isHidden && floating.view.alphaValue > 0
        {
            return true
        }
        return false
    }

    private let contentContainer = NSView()

    private var tabBarView = NerwHubTabBarView()

    private var currentTabViewController: NSViewController?
    private var currentTab: NerwHubTab = .memory

    // Tab controllers cache
    private var memoryTabController: MemoryTab?
    private var bookmarksTabController: BookmarksTab?
    private var conversationsTabController: ConversationsTab?

    private let panelView = NerwPanelView(style: .main)

    private var commandPaletteController: HubCommandPaletteViewController?
    private var floatingInputController: HubFloatingInputViewController?

    override func loadView() {
        let metricsWidth: CGFloat = 960
        let metricsHeight: CGFloat = 640
        view = NSView(frame: NSRect(x: 0, y: 0, width: metricsWidth, height: metricsHeight))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor

        setupViews()
    }

    private var eventMonitor: Any?

    override func viewDidAppear() {
        super.viewDidAppear()
        tabBarView.playIntroAnimation()
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, self.view.window == event.window else { return event }

            // If command palette is open, let palette handle its own inputs
            if let palette = self.commandPaletteController,
                !palette.view.isHidden && palette.view.alphaValue > 0
            {
                return event
            }

            // If floating input is open, let floating input handle its own inputs
            if let floating = self.floatingInputController,
                !floating.view.isHidden && floating.view.alphaValue > 0
            {
                return event
            }

            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

            // Cmd + K
            if flags.contains(.command), event.charactersIgnoringModifiers?.lowercased() == "k" {
                self.toggleCommandPalette()
                return nil
            }

            // Cmd + 1, 2, 3
            if flags.contains(.command), let char = event.charactersIgnoringModifiers,
                let number = Int(char)
            {
                if number >= 1 && number <= NerwHubTab.allCases.count {
                    let tab = NerwHubTab.allCases[number - 1]
                    self.selectTab(tab)
                    return nil
                }
            }

            // Esc
            if event.keyCode == 53 {
                self.onDismiss?()
                return nil
            }

            let navStyle = ConfigManager.shared.config.navigationStyle
            let char = event.charactersIgnoringModifiers?.lowercased()

            var isMoveUp = (event.keyCode == 126)  // Up Arrow
            var isMoveDown = (event.keyCode == 125)  // Down Arrow

            if navStyle == "vim" {
                // In vim mode, plain 'j' and 'k' move down/up (without Cmd/Ctrl)
                let noCommandOrControl = !flags.contains(.command) && !flags.contains(.control)
                if noCommandOrControl && char == "k" {
                    isMoveUp = true
                } else if noCommandOrControl && char == "j" {
                    isMoveDown = true
                }
            } else {
                // In unix/default mode, Ctrl-P and Ctrl-N move up/down
                if flags.contains(.control) && char == "p" {
                    isMoveUp = true
                } else if flags.contains(.control) && char == "n" {
                    isMoveDown = true
                }
            }

            if isMoveUp {
                (self.currentTabViewController as? BaseHubTabProtocol)?.selectPrevious()
                return nil
            }

            if isMoveDown {
                (self.currentTabViewController as? BaseHubTabProtocol)?.selectNext()
                return nil
            }

            // Return / Enter
            if event.keyCode == 36 {
                (self.currentTabViewController as? BaseHubTabProtocol)?
                    .performPrimaryActionOnSelected()
                return nil
            }

            // Delete / Backspace (keyCode 51 or forward delete 117)
            if event.keyCode == 51 || event.keyCode == 117 {
                (self.currentTabViewController as? BaseHubTabProtocol)?
                    .performDeleteActionOnSelected()
                return nil
            }

            return event
        }
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }

        if let palette = commandPaletteController {
            palette.view.alphaValue = 0
            palette.view.isHidden = true
        }

        if let floating = floatingInputController {
            floating.view.alphaValue = 0
            floating.view.isHidden = true
        }
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
            tabBarView.centerXAnchor.constraint(equalTo: panelView.leadingAnchor),  // Straddles the left border
            tabBarView.centerYAnchor.constraint(equalTo: panelView.centerYAnchor),
        ])

        // Setup palette controller
        let palette = HubCommandPaletteViewController()
        palette.delegate = self
        self.commandPaletteController = palette
        addChild(palette)
        palette.view.translatesAutoresizingMaskIntoConstraints = false
        palette.view.alphaValue = 0  // hidden initially
        palette.view.isHidden = true  // Prevent catching clicks while hidden
        view.addSubview(palette.view)

        NSLayoutConstraint.activate([
            palette.view.centerXAnchor.constraint(equalTo: panelView.centerXAnchor),
            palette.view.centerYAnchor.constraint(equalTo: panelView.centerYAnchor),
            palette.view.widthAnchor.constraint(equalToConstant: 440),
            palette.view.heightAnchor.constraint(equalToConstant: 300),
        ])

        // Setup floating input
        let floatingInput = HubFloatingInputViewController()
        self.floatingInputController = floatingInput
        addChild(floatingInput)
        floatingInput.view.translatesAutoresizingMaskIntoConstraints = false
        floatingInput.view.alphaValue = 0
        floatingInput.view.isHidden = true
        view.addSubview(floatingInput.view)

        NSLayoutConstraint.activate([
            floatingInput.view.centerXAnchor.constraint(equalTo: panelView.centerXAnchor),
            floatingInput.view.centerYAnchor.constraint(equalTo: panelView.centerYAnchor),
            floatingInput.view.widthAnchor.constraint(equalToConstant: 440),
        ])
    }

    @objc private func toggleCommandPalette() {
        guard let palette = commandPaletteController else { return }

        let isOpening = palette.view.alphaValue == 0 || palette.view.isHidden

        if isOpening {
            var actions: [String] = []

            if currentTab == .memory {
                if let memTab = memoryTabController, memTab.selectedItem != nil {
                    actions.append("Edit")
                    actions.append("Delete")
                }
            } else if currentTab == .bookmarks {
                if let bTab = bookmarksTabController, bTab.selectedItem != nil {
                    actions.append("Open")
                    actions.append("Edit Name")
                    actions.append("Edit URL")
                    actions.append("Delete")
                }
            } else if currentTab == .conversations {
                if let cTab = conversationsTabController, cTab.selectedItem != nil {
                    actions.append("Open")
                    actions.append("Delete")
                }
                if let cTab = conversationsTabController, !cTab.items.isEmpty {
                    actions.append("Clear All Conversations")
                }
            }

            for tab in NerwHubTab.allCases {
                if tab != currentTab {
                    actions.append("Open \(tab.rawValue)")
                }
            }

            actions.append("Refresh")

            palette.setActions(actions)

            palette.view.isHidden = false
            palette.view.alphaValue = 1.0

            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.15
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                palette.view.alphaValue = 1.0
            }) {
                palette.view.window?.makeFirstResponder(palette.searchField)
            }
        } else {
            closeCommandPalette()
        }
    }

    public func showFloatingInput(
        title: String, subtitle: String, initialText: String, onSave: @escaping (String) -> Void
    ) {
        guard let floatingInput = floatingInputController else { return }

        floatingInput.configure(title: title, subtitle: subtitle, text: initialText)

        floatingInput.onSave = { [weak self] text in
            onSave(text)
            self?.closeFloatingInput()
        }

        floatingInput.onCancel = { [weak self] in
            self?.closeFloatingInput()
        }

        floatingInput.view.isHidden = false

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            floatingInput.view.alphaValue = 1.0
        }) {
            floatingInput.focusInputField()
        }
    }

    private func closeFloatingInput() {
        guard let floatingInput = floatingInputController else { return }

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            floatingInput.view.alphaValue = 0
        }) {
            floatingInput.view.isHidden = true
        }
    }

    private func closeCommandPalette() {
        guard let palette = commandPaletteController else { return }

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            palette.view.alphaValue = 0
        }) {
            palette.view.isHidden = true
        }
    }

    public func commandPaletteDidSelect(action: String) {
        closeCommandPalette()

        switch action {
        case "Edit Name", "Edit Bookmark Name":
            bookmarksTabController?.editSelectedName()
        case "Edit URL", "Edit Bookmark URL":
            bookmarksTabController?.editSelectedURL()
        case "Edit", "Edit Memory":
            (currentTabViewController as? BaseHubTabProtocol)?.performEditActionOnSelected()
        case "Delete", "Delete Memory", "Delete Bookmark", "Delete Conversation":
            (currentTabViewController as? BaseHubTabProtocol)?.performDeleteActionOnSelected()
        case "Open", "Open Bookmark", "Open Conversation":
            (currentTabViewController as? BaseHubTabProtocol)?.performPrimaryActionOnSelected()
        case "Clear All Conversations":
            conversationsTabController?.clearAllConversations()
        case "Open Memory", "Switch to Memory":
            selectTab(.memory)
        case "Open Bookmarks", "Switch to Bookmarks":
            selectTab(.bookmarks)
        case "Open Conversations", "Switch to Conversations":
            selectTab(.conversations)
        case "Refresh":
            (currentTabViewController as? BaseHubTabProtocol)?.refreshData()
        default:
            break
        }
    }

    public func commandPaletteDidRequestClose() {
        closeCommandPalette()
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
        case .bookmarks:
            if bookmarksTabController == nil {
                bookmarksTabController = BookmarksTab()
            }
            newController = bookmarksTabController!
        case .conversations:
            if conversationsTabController == nil {
                conversationsTabController = ConversationsTab()
            }
            newController = conversationsTabController!
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

    public func playIntroAnimation() {
        tabBarView.playIntroAnimation()
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
