import Cocoa
import NerwAction
import NerwCore
import NerwSearchBackend

class NoDividerSplitView: NSSplitView {
    override var dividerThickness: CGFloat { return 0 }
}

private enum SplitPaneContextShortcut {
    static let delete = "⌘⌫"
    static let pin = "⌘P"
}

public class SplitPaneViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate,
    NSTextFieldDelegate, ActionContextViewControllerDelegate
{
    private var titleContent: String
    public weak var dataSource: SplitPaneDataSource?
    public weak var delegate: SplitPaneDelegate?

    private let splitView = NoDividerSplitView()
    private let leftContainer = NSView()
    private let rightContainer = NSView()
    private var panelView: NerwPanelView!

    private let tableView = NSTableView()
    private let previewView = SplitPanePreviewView()
    private let searchField = ThemedTextField()
    private let searchIconView = NSImageView()

    private var selectedIndex: Int = 0
    private var iconImage: NSImage?
    private var actionContextWindow: ActionContextPanel?
    private var actionContextViewController: ActionContextViewController?

    public init(
        title: String, icon: NSImage? = nil, dataSource: SplitPaneDataSource,
        delegate: SplitPaneDelegate
    ) {
        self.titleContent = title
        self.iconImage = icon
        self.dataSource = dataSource
        self.delegate = delegate
        super.init(nibName: nil, bundle: nil)
    }

    public func configure(
        title: String, icon: NSImage?, dataSource: SplitPaneDataSource, delegate: SplitPaneDelegate
    ) {
        self.titleContent = title
        self.iconImage = icon
        self.dataSource = dataSource
        self.delegate = delegate

        if isViewLoaded {
            searchField.placeholderString = title
            searchIconView.image =
                icon ?? NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: nil)
            searchField.stringValue = ""
            reloadData()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func loadView() {
        let metricsWidth = GlobalLayout.mainWidth
        let metricsHeight = GlobalLayout.mainHeight
        view = NSView(frame: NSRect(x: 0, y: 0, width: metricsWidth, height: metricsHeight))
        view.wantsLayer = true
        setupViews()
    }

    private func setupViews() {
        panelView = NerwPanelView(style: .splitPane)
        panelView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(panelView)

        let contentView = panelView.contentView

        NSLayoutConstraint.activate([
            panelView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            panelView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            panelView.topAnchor.constraint(equalTo: view.topAnchor),
            panelView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        splitView.isVertical = true
        splitView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(splitView)

        leftContainer.translatesAutoresizingMaskIntoConstraints = false
        leftContainer.widthAnchor.constraint(equalToConstant: 280).isActive = true
        rightContainer.translatesAutoresizingMaskIntoConstraints = false
        rightContainer.widthAnchor.constraint(greaterThanOrEqualToConstant: 300).isActive = true

        splitView.addArrangedSubview(leftContainer)
        splitView.addArrangedSubview(rightContainer)

        // Search Icon
        searchIconView.image =
            iconImage ?? NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: nil)
        searchIconView.contentTintColor = .secondaryLabelColor
        searchIconView.translatesAutoresizingMaskIntoConstraints = false
        searchIconView.imageScaling = .scaleProportionallyUpOrDown
        contentView.addSubview(searchIconView)

        // Search field replacing title label
        searchField.placeholderString = titleContent
        searchField.font = .systemFont(ofSize: GlobalLayout.fontSizeSearch, weight: .light)
        searchField.isBordered = false
        searchField.drawsBackground = false
        searchField.focusRingType = .none
        searchField.textColor = .labelColor
        searchField.delegate = self
        searchField.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(searchField)

        // Config table view
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = false
        scrollView.drawsBackground = false

        tableView.backgroundColor = .clear
        tableView.headerView = nil
        tableView.rowHeight = 44
        tableView.intercellSpacing = NSSize(width: 0, height: 0)
        tableView.selectionHighlightStyle = .none
        tableView.dataSource = self
        tableView.delegate = self

        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("item"))
        col.resizingMask = .autoresizingMask
        tableView.addTableColumn(col)

        scrollView.documentView = tableView
        leftContainer.addSubview(scrollView)

        previewView.translatesAutoresizingMaskIntoConstraints = false
        rightContainer.addSubview(previewView)

        let searchTopMargin: CGFloat = 12
        let searchHeight: CGFloat = 32
        let searchHorizMargin: CGFloat = 20
        let iconSize: CGFloat = 24
        let iconToTextSpacing: CGFloat = 8

        // Custom Separator
        let separatorView = NSBox()
        separatorView.boxType = .separator
        separatorView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(separatorView)

        NSLayoutConstraint.activate([
            searchIconView.leadingAnchor.constraint(
                equalTo: view.leadingAnchor, constant: searchHorizMargin),
            searchIconView.centerYAnchor.constraint(equalTo: searchField.centerYAnchor),
            searchIconView.widthAnchor.constraint(equalToConstant: iconSize),
            searchIconView.heightAnchor.constraint(equalToConstant: iconSize),

            searchField.topAnchor.constraint(equalTo: view.topAnchor, constant: searchTopMargin),
            searchField.leadingAnchor.constraint(
                equalTo: searchIconView.trailingAnchor, constant: iconToTextSpacing),
            searchField.trailingAnchor.constraint(
                equalTo: view.trailingAnchor, constant: -searchHorizMargin),
            searchField.heightAnchor.constraint(equalToConstant: searchHeight),

            separatorView.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 12),
            separatorView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            separatorView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            separatorView.heightAnchor.constraint(equalToConstant: 1),

            splitView.topAnchor.constraint(
                equalTo: separatorView.bottomAnchor, constant: 0),
            splitView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            splitView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            splitView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            scrollView.topAnchor.constraint(equalTo: leftContainer.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leftContainer.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: leftContainer.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: leftContainer.bottomAnchor),

            previewView.topAnchor.constraint(equalTo: rightContainer.topAnchor, constant: 8),
            previewView.leadingAnchor.constraint(
                equalTo: rightContainer.leadingAnchor, constant: 8),
            previewView.trailingAnchor.constraint(
                equalTo: rightContainer.trailingAnchor, constant: -16),
            previewView.bottomAnchor.constraint(
                equalTo: rightContainer.bottomAnchor, constant: -16),
        ])

        NotificationCenter.default.addObserver(
            self, selector: #selector(configDidUpdate),
            name: Notification.Name("NerwConfigDidUpdate"),
            object: nil)
    }

    @objc private func configDidUpdate() {
        DispatchQueue.main.async {
            self.applyLayout()
        }
    }

    private func applyLayout() {
        searchField.font = .systemFont(ofSize: GlobalLayout.fontSizeSearch, weight: .light)
        view.frame.size = NSSize(width: GlobalLayout.mainWidth, height: GlobalLayout.mainHeight)
        view.layoutSubtreeIfNeeded()
    }

    public override func viewWillAppear() {
        super.viewWillAppear()
        selectedIndex = 0
        // Focus the search field initially
        view.window?.makeFirstResponder(searchField)

        searchField.stringValue = ""

        if let fontName = NerwPanelContext.shared.configFontName,
            let font = NSFont(name: fontName, size: GlobalLayout.fontSizeSearch)
        {
            searchField.font = font
        }
        reloadData()
    }

    public override func viewWillDisappear() {
        super.viewWillDisappear()
        dismissActionContext(restoreFocus: false)
    }

    // Required to receive key events directly on view (fallback if searchfield doesn't focus)
    public override var acceptsFirstResponder: Bool {
        return true
    }

    public func reloadData() {
        tableView.reloadData()
        updateSelection(to: min(selectedIndex, max(0, (dataSource?.numberOfItems() ?? 0) - 1)))
        refreshActionContextIfNeeded()
    }

    public func resetSelection() {
        selectedIndex = 0
        if tableView.numberOfRows > 0 {
            tableView.scrollRowToVisible(0)
        }
    }

    private func updateSelection(to index: Int) {
        guard let ds = dataSource, ds.numberOfItems() > 0 else {
            dismissActionContext(restoreFocus: false)
            previewView.configure(with: nil)
            delegate?.didSelect(item: nil)
            return
        }

        let oldIndex = selectedIndex
        selectedIndex = max(0, min(index, ds.numberOfItems() - 1))

        if oldIndex != selectedIndex {
            tableView.reloadData(
                forRowIndexes: IndexSet(integer: oldIndex), columnIndexes: IndexSet(integer: 0))
        }
        tableView.reloadData(
            forRowIndexes: IndexSet(integer: selectedIndex), columnIndexes: IndexSet(integer: 0))
        tableView.scrollRowToVisible(selectedIndex)

        let item = ds.item(at: selectedIndex)
        previewView.configure(with: item)
        delegate?.didSelect(item: item)
        refreshActionContextIfNeeded()
    }

    public override func keyDown(with event: NSEvent) {
        if handleCommandShortcut(from: event) {
            return
        }

        // Esc
        if event.keyCode == 53 {
            if actionContextWindow?.isVisible == true {
                dismissActionContext()
                return
            }
            delegate?.didCancel()
            return
        }

        // Enter
        if event.keyCode == 36 {
            handleActivate()
            return
        }

        // Delete / Backspace
        if event.keyCode == 51 || event.keyCode == 117 {
            handleDelete()
            return
        }

        // Nav
        let isCtrl = event.modifierFlags.contains(.control)
        if event.keyCode == 126 || (isCtrl && event.keyCode == 35) {  // Up or Ctrl-P
            updateSelection(to: selectedIndex - 1)
            return
        }
        if event.keyCode == 125 || (isCtrl && event.keyCode == 45) {  // Down or Ctrl-N
            updateSelection(to: selectedIndex + 1)
            return
        }

        super.keyDown(with: event)
    }

    private func handleCommandShortcut(from event: NSEvent) -> Bool {
        let normalizedFlags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard normalizedFlags.contains(.command) else { return false }

        if event.keyCode == 51 || event.keyCode == 117 {
            return performContextOperation(withDetailText: SplitPaneContextShortcut.delete)
        }

        switch event.charactersIgnoringModifiers?.lowercased() {
        case "k":
            toggleActionContext()
            return true
        case "p":
            return performContextOperation(withDetailText: SplitPaneContextShortcut.pin)
        default:
            return false
        }
    }

    private func handleActivate() {
        dismissActionContext(restoreFocus: false)
        guard let item = selectedItem() else { return }
        delegate?.didActivate(item: item)
    }

    private func handleDelete() {
        dismissActionContext(restoreFocus: false)
        guard let item = selectedItem() else { return }
        delegate?.didDelete(item: item)
    }

    private func selectedItem() -> SplitPaneItem? {
        guard let ds = dataSource, ds.numberOfItems() > 0 else { return nil }
        return ds.item(at: selectedIndex)
    }

    private func toggleActionContext() {
        if actionContextWindow?.isVisible == true {
            dismissActionContext()
            return
        }

        showActionContext()
    }

    private func showActionContext() {
        guard let item = selectedItem(),
            let context = delegate?.actionContext(for: item)
        else { return }

        let anchorRect = actionContextAnchorRect()
        let controller = actionContextViewController ?? ActionContextViewController()
        controller.delegate = self
        controller.setConnectorSelectionHeight(actionContextConnectorHeight(for: anchorRect))
        controller.render(context: context)
        actionContextViewController = controller

        let panel: ActionContextPanel
        if let existing = actionContextWindow {
            panel = existing
        } else {
            panel = ActionContextPanel(
                contentRect: NSRect(x: 0, y: 0, width: 343, height: 200),
                styleMask: [.nonactivatingPanel, .borderless],
                backing: .buffered,
                defer: false
            )
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = true
            panel.level = .floating
            panel.hidesOnDeactivate = false
            panel.contentView = controller.view
            actionContextWindow = panel
        }

        controller.view.layoutSubtreeIfNeeded()
        let contentSize = controller.preferredContentSize
        panel.setFrame(
            NSRect(origin: panel.frame.origin, size: contentSize), display: true)

        if let parentWindow = view.window {
            let screenRect = parentWindow.convertToScreen(anchorRect)
            let windowOrigin = NerwPanelContext.shared.sideOrigin(
                forSize: contentSize,
                anchorRect: screenRect
            )
            panel.setFrameOrigin(windowOrigin)
            parentWindow.addChildWindow(panel, ordered: .above)
            panel.orderFront(nil)
        }

        DispatchQueue.main.async {
            panel.makeKey()
            controller.focusForInteraction()
        }
    }

    private func dismissActionContext(restoreFocus: Bool = true) {
        guard let panel = actionContextWindow else { return }
        if let parent = panel.parent {
            parent.removeChildWindow(panel)
        }
        panel.orderOut(nil)

        if restoreFocus, view.window?.isVisible == true {
            view.window?.makeKeyAndOrderFront(nil)
            view.window?.makeFirstResponder(searchField)
        }
    }

    private func refreshActionContextIfNeeded() {
        guard let panel = actionContextWindow, panel.isVisible else { return }
        guard let item = selectedItem(),
            let context = delegate?.actionContext(for: item)
        else {
            dismissActionContext(restoreFocus: false)
            return
        }

        let controller = actionContextViewController
        controller?.render(context: context)

        if let controller, let parentWindow = view.window {
            controller.view.layoutSubtreeIfNeeded()
            let contentSize = controller.preferredContentSize
            let anchorRect = actionContextAnchorRect()
            controller.setConnectorSelectionHeight(actionContextConnectorHeight(for: anchorRect))
            let screenRect = parentWindow.convertToScreen(anchorRect)
            let windowOrigin = NerwPanelContext.shared.sideOrigin(
                forSize: contentSize,
                anchorRect: screenRect
            )
            panel.setFrame(
                NSRect(origin: windowOrigin, size: contentSize),
                display: true
            )
        }
    }

    private func actionContextConnectorHeight(for anchorRect: NSRect) -> CGFloat {
        max(0, anchorRect.height)
    }

    private func actionContextAnchorRect() -> NSRect {
        guard let ds = dataSource, ds.numberOfItems() > 0,
            selectedIndex >= 0, selectedIndex < ds.numberOfItems()
        else {
            return NSRect(
                x: leftContainer.frame.maxX - 8,
                y: 0,
                width: 8,
                height: view.bounds.height
            )
        }

        let rowRect = tableView.rect(ofRow: selectedIndex)
        let rectInView = view.convert(rowRect, from: tableView)
        return NSRect(
            x: leftContainer.frame.maxX - 8,
            y: rectInView.minY,
            width: 8,
            height: rectInView.height
        )
    }

    private func performContextOperation(withDetailText detailText: String) -> Bool {
        guard let item = selectedItem(),
            let context = delegate?.actionContext(for: item),
            let operation = context.operations.first(where: { $0.detailText == detailText })
        else { return false }

        dismissActionContext(restoreFocus: false)
        delegate?.didInvokeActionContext(operation: operation, for: item)
        return true
    }

    // MARK: - NSTextFieldDelegate
    public func controlTextDidChange(_ obj: Notification) {
        let query = searchField.stringValue
        delegate?.didSearch(query: query)
    }

    public func control(
        _ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector
    ) -> Bool {
        if let event = NSApp.currentEvent, handleCommandShortcut(from: event) {
            return true
        }

        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            if actionContextWindow?.isVisible == true {
                dismissActionContext()
                return true
            }
            if !searchField.stringValue.isEmpty {
                searchField.stringValue = ""
                controlTextDidChange(
                    Notification(name: NSTextField.textDidChangeNotification, object: searchField))
                return true
            }
            delegate?.didCancel()
            return true
        }

        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            handleActivate()
            return true
        }

        if commandSelector == #selector(NSResponder.deleteBackward(_:)) {
            return false  // Let textfield handle its own deletion
        }

        // We also want to capture Up / Down when in text field
        if commandSelector == #selector(NSResponder.moveUp(_:)) {
            updateSelection(to: selectedIndex - 1)
            return true
        }
        if commandSelector == #selector(NSResponder.moveDown(_:)) {
            updateSelection(to: selectedIndex + 1)
            return true
        }

        let isCtrl = NSEvent.modifierFlags.contains(.control)
        if isCtrl {
            if let event = NSApp.currentEvent, event.keyCode == 35 {  // Ctrl-P
                updateSelection(to: selectedIndex - 1)
                return true
            }
            if let event = NSApp.currentEvent, event.keyCode == 45 {  // Ctrl-N
                updateSelection(to: selectedIndex + 1)
                return true
            }
        }

        return false
    }

    // MARK: - NSTableView
    public func numberOfRows(in tableView: NSTableView) -> Int {
        return dataSource?.numberOfItems() ?? 0
    }

    public func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int)
        -> NSView?
    {
        let identifier = NSUserInterfaceItemIdentifier("SplitPaneCellView")
        var cell = tableView.makeView(withIdentifier: identifier, owner: self) as? SplitPaneCellView
        if cell == nil {
            cell = SplitPaneCellView()
            cell?.identifier = identifier
        }
        if let item = dataSource?.item(at: row) {
            cell?.configure(with: item, isSelected: row == selectedIndex)
        }
        return cell
    }

    func actionContext(
        _ controller: ActionContextViewController,
        didInvoke operation: NerwActionContext.Operation,
        in context: NerwActionContext
    ) {
        dismissActionContext(restoreFocus: false)
        guard let item = selectedItem(),
            delegate?.actionContext(for: item)?.actionID == context.actionID
        else { return }
        delegate?.didInvokeActionContext(operation: operation, for: item)
    }

    func actionContext(
        _ controller: ActionContextViewController,
        didUpdatePreferencesFor actionID: String
    ) {}

    func actionContextDidRequestClose(_ controller: ActionContextViewController) {
        dismissActionContext()
    }
}
