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

public class NerwHubWindow: NSWindow {
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

    public override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command) {
            guard let key = event.charactersIgnoringModifiers?.lowercased() else {
                return super.performKeyEquivalent(with: event)
            }
            switch key {
            case "w", "q":
                if let vc = contentViewController as? NerwHubViewController {
                    vc.onDismiss?()
                } else {
                    self.orderOut(nil)
                }
                return true
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

    public override func cancelOperation(_ sender: Any?) {
        if let vc = contentViewController as? NerwHubViewController {
            if vc.isOverlayOpen {
                super.cancelOperation(sender)
                return
            }
            vc.onDismiss?()
        } else {
            self.orderOut(nil)
        }
    }
}

// Keep NerwHubPanel alias for backward compatibility with older references
public typealias NerwHubPanel = NerwHubWindow

class NerwHubViewController: NSViewController, NerwHubSidebarDelegate, NerwHubTopBarDelegate,
    HubCommandPaletteDelegate
{
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

    private let sidebarView = NerwHubSidebarView()
    private let topBarView = NerwHubTopBarView()
    private let contentContainer = NSView()
    private let statusBarView = NSView()
    private let statusLabel = NSTextField(labelWithString: "")
    private let hintLabel = NSTextField(labelWithString: "")

    private var currentTabViewController: NSViewController?
    private var currentTab: NerwHubTab = .memory

    // Tab controllers cache
    private var memoryTabController: MemoryTab?
    private var bookmarksTabController: BookmarksTab?
    private var conversationsTabController: ConversationsTab?

    private var commandPaletteController: HubCommandPaletteViewController?
    private var floatingInputController: HubFloatingInputViewController?
    private var eventMonitor: Any?

    override func loadView() {
        let defaultWidth: CGFloat = 920
        let defaultHeight: CGFloat = 580
        view = NSView(frame: NSRect(x: 0, y: 0, width: defaultWidth, height: defaultHeight))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        setupViews()
    }

    override func viewDidAppear() {
        super.viewDidAppear()

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
            let char = event.charactersIgnoringModifiers?.lowercased()

            // Cmd + K
            if flags.contains(.command), char == "k" {
                self.toggleCommandPalette()
                return nil
            }

            // Cmd + F
            if flags.contains(.command), char == "f" {
                self.topBarView.focusSearchField()
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

            // Cmd + W or Cmd + Q
            if flags.contains(.command), char == "w" || char == "q" {
                self.onDismiss?()
                return nil
            }

            // Esc
            if event.keyCode == 53 {
                if let searchFirstResponder = self.view.window?.firstResponder as? NSTextView,
                    searchFirstResponder.delegate as? NSSearchField == self.topBarView.searchField,
                    !self.topBarView.searchField.stringValue.isEmpty
                {
                    self.topBarView.clearSearch()
                    return nil
                }
                self.onDismiss?()
                return nil
            }

            // If focus is inside search field, only allow arrow keys/Enter to fall through to list
            let isSearchFocused =
                (self.view.window?.firstResponder as? NSTextView)?.delegate as? NSSearchField
                == self.topBarView.searchField

            let navStyle = ConfigManager.shared.config.navigationStyle

            var isMoveUp = (event.keyCode == 126)  // Up Arrow
            var isMoveDown = (event.keyCode == 125)  // Down Arrow

            if !isSearchFocused {
                if navStyle == "vim" {
                    let noCommandOrControl = !flags.contains(.command) && !flags.contains(.control)
                    if noCommandOrControl && char == "k" {
                        isMoveUp = true
                    } else if noCommandOrControl && char == "j" {
                        isMoveDown = true
                    }
                } else {
                    if flags.contains(.control) && char == "p" {
                        isMoveUp = true
                    } else if flags.contains(.control) && char == "n" {
                        isMoveDown = true
                    }
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
            if event.keyCode == 36 && !isSearchFocused {
                (self.currentTabViewController as? BaseHubTabProtocol)?
                    .performPrimaryActionOnSelected()
                return nil
            }

            // Delete / Backspace (keyCode 51 or forward delete 117)
            if (event.keyCode == 51 || event.keyCode == 117) && !isSearchFocused {
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
        sidebarView.delegate = self
        view.addSubview(sidebarView)

        let verticalDivider = NSView()
        verticalDivider.translatesAutoresizingMaskIntoConstraints = false
        verticalDivider.wantsLayer = true
        verticalDivider.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.08).cgColor
        view.addSubview(verticalDivider)

        let rightContainer = NSView()
        rightContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(rightContainer)

        topBarView.delegate = self
        rightContainer.addSubview(topBarView)

        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        rightContainer.addSubview(contentContainer)

        // Status bar at bottom
        statusBarView.translatesAutoresizingMaskIntoConstraints = false
        statusBarView.wantsLayer = true
        rightContainer.addSubview(statusBarView)

        let statusTopBorder = NSView()
        statusTopBorder.translatesAutoresizingMaskIntoConstraints = false
        statusTopBorder.wantsLayer = true
        statusTopBorder.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.08).cgColor
        statusBarView.addSubview(statusTopBorder)

        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = .systemFont(ofSize: 11, weight: .regular)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.isEditable = false
        statusLabel.isSelectable = false
        statusLabel.drawsBackground = false
        statusLabel.isBezeled = false
        statusBarView.addSubview(statusLabel)

        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        hintLabel.stringValue = "⌘K Command Palette  •  ⌘F Search  •  ⌘1-3 Tabs"
        hintLabel.font = .systemFont(ofSize: 11, weight: .regular)
        hintLabel.textColor = .tertiaryLabelColor
        hintLabel.isEditable = false
        hintLabel.isSelectable = false
        hintLabel.drawsBackground = false
        hintLabel.isBezeled = false
        hintLabel.alignment = .right
        statusBarView.addSubview(hintLabel)

        NSLayoutConstraint.activate([
            // Sidebar on the left (210pt width)
            sidebarView.topAnchor.constraint(equalTo: view.topAnchor),
            sidebarView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            sidebarView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            sidebarView.widthAnchor.constraint(equalToConstant: 210),

            // Vertical divider line
            verticalDivider.topAnchor.constraint(equalTo: view.topAnchor),
            verticalDivider.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            verticalDivider.leadingAnchor.constraint(equalTo: sidebarView.trailingAnchor),
            verticalDivider.widthAnchor.constraint(equalToConstant: 1),

            // Right container fills remaining space
            rightContainer.topAnchor.constraint(equalTo: view.topAnchor),
            rightContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            rightContainer.leadingAnchor.constraint(equalTo: verticalDivider.trailingAnchor),
            rightContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            // Top Bar
            topBarView.topAnchor.constraint(equalTo: rightContainer.topAnchor),
            topBarView.leadingAnchor.constraint(equalTo: rightContainer.leadingAnchor),
            topBarView.trailingAnchor.constraint(equalTo: rightContainer.trailingAnchor),

            // Content container
            contentContainer.topAnchor.constraint(equalTo: topBarView.bottomAnchor),
            contentContainer.leadingAnchor.constraint(equalTo: rightContainer.leadingAnchor),
            contentContainer.trailingAnchor.constraint(equalTo: rightContainer.trailingAnchor),
            contentContainer.bottomAnchor.constraint(equalTo: statusBarView.topAnchor),

            // Status Bar
            statusBarView.leadingAnchor.constraint(equalTo: rightContainer.leadingAnchor),
            statusBarView.trailingAnchor.constraint(equalTo: rightContainer.trailingAnchor),
            statusBarView.bottomAnchor.constraint(equalTo: rightContainer.bottomAnchor),
            statusBarView.heightAnchor.constraint(equalToConstant: 26),

            statusTopBorder.topAnchor.constraint(equalTo: statusBarView.topAnchor),
            statusTopBorder.leadingAnchor.constraint(equalTo: statusBarView.leadingAnchor),
            statusTopBorder.trailingAnchor.constraint(equalTo: statusBarView.trailingAnchor),
            statusTopBorder.heightAnchor.constraint(equalToConstant: 1),

            statusLabel.leadingAnchor.constraint(
                equalTo: statusBarView.leadingAnchor, constant: 18),
            statusLabel.centerYAnchor.constraint(equalTo: statusBarView.centerYAnchor),

            hintLabel.trailingAnchor.constraint(
                equalTo: statusBarView.trailingAnchor, constant: -18),
            hintLabel.centerYAnchor.constraint(equalTo: statusBarView.centerYAnchor),
        ])

        // Setup palette controller
        let palette = HubCommandPaletteViewController()
        palette.delegate = self
        self.commandPaletteController = palette
        addChild(palette)
        palette.view.translatesAutoresizingMaskIntoConstraints = false
        palette.view.alphaValue = 0
        palette.view.isHidden = true
        view.addSubview(palette.view)

        NSLayoutConstraint.activate([
            palette.view.centerXAnchor.constraint(equalTo: rightContainer.centerXAnchor),
            palette.view.centerYAnchor.constraint(equalTo: rightContainer.centerYAnchor),
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
            floatingInput.view.centerXAnchor.constraint(equalTo: rightContainer.centerXAnchor),
            floatingInput.view.centerYAnchor.constraint(equalTo: rightContainer.centerYAnchor),
            floatingInput.view.widthAnchor.constraint(equalToConstant: 440),
        ])
    }

    // MARK: - NerwHubSidebarDelegate

    func sidebarDidSelect(tab: NerwHubTab) {
        selectTab(tab)
    }

    // MARK: - NerwHubTopBarDelegate

    func topBarSearchQueryDidChange(_ query: String) {
        (currentTabViewController as? BaseHubTabProtocol)?.filter(with: query)
    }

    func topBarDidClickCommandPalette() {
        toggleCommandPalette()
    }

    // MARK: - Tab Selection

    func selectTab(_ tab: NerwHubTab) {
        currentTab = tab

        let newController: NSViewController
        switch tab {
        case .memory:
            if memoryTabController == nil {
                let mem = MemoryTab()
                mem.onCountChanged = { [weak self] count in
                    self?.sidebarView.updateCount(for: .memory, count: count)
                    if self?.currentTab == .memory {
                        self?.updateStatusCount(count: count)
                    }
                }
                memoryTabController = mem
            }
            newController = memoryTabController!
        case .bookmarks:
            if bookmarksTabController == nil {
                let bm = BookmarksTab()
                bm.onCountChanged = { [weak self] count in
                    self?.sidebarView.updateCount(for: .bookmarks, count: count)
                    if self?.currentTab == .bookmarks {
                        self?.updateStatusCount(count: count)
                    }
                }
                bookmarksTabController = bm
            }
            newController = bookmarksTabController!
        case .conversations:
            if conversationsTabController == nil {
                let cv = ConversationsTab()
                cv.onCountChanged = { [weak self] count in
                    self?.sidebarView.updateCount(for: .conversations, count: count)
                    if self?.currentTab == .conversations {
                        self?.updateStatusCount(count: count)
                    }
                }
                conversationsTabController = cv
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
        sidebarView.select(tab: tab)
        topBarView.updateTab(tab)

        if let listTab = newController as? BaseHubTabProtocol {
            listTab.filter(with: topBarView.searchField.stringValue)
            updateStatusCount(count: listTab.totalItemCount)
        }
    }

    private func updateStatusCount(count: Int) {
        let isFiltered = !topBarView.searchField.stringValue.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).isEmpty
        if isFiltered {
            statusLabel.stringValue = "Filtered: \(count) \(count == 1 ? "item" : "items")"
        } else {
            statusLabel.stringValue = "\(count) \(count == 1 ? "item" : "items")"
        }
    }

    // MARK: - Overlays & Command Palette

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
}
