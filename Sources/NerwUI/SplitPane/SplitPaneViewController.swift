import Cocoa
import NerwCore
import NerwSearchBackend

class NoDividerSplitView: NSSplitView {
    override var dividerThickness: CGFloat { return 0 }
}

public class SplitPaneViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate,
    NSTextFieldDelegate
{
    private let titleContent: String
    public weak var dataSource: SplitPaneDataSource?
    public weak var delegate: SplitPaneDelegate?

    private let splitView = NoDividerSplitView()
    private let leftContainer = NSView()
    private let rightContainer = NSView()

    private let tableView = NSTableView()
    private let previewView = SplitPanePreviewView()
    private let searchField = NSTextField()
    private let searchIconView = NSImageView()

    private var selectedIndex: Int = 0
    private let iconImage: NSImage?

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
        // Blur background
        let visualEffect = NSVisualEffectView(frame: view.bounds)
        visualEffect.autoresizingMask = [.width, .height]
        visualEffect.material = .fullScreenUI
        visualEffect.state = .active
        visualEffect.blendingMode = .behindWindow
        view.addSubview(visualEffect)

        // Window styling
        view.layer?.cornerRadius = GlobalLayout.cornerRadius  // Matched to main panel's
        view.layer?.masksToBounds = true
        view.layer?.borderColor = NSColor.white.withAlphaComponent(0.18).cgColor
        view.layer?.borderWidth = 1.0

        let tint = NSView(frame: view.bounds)
        tint.autoresizingMask = [.width, .height]
        tint.wantsLayer = true
        tint.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.15).cgColor
        visualEffect.addSubview(tint)

        // Split View
        splitView.isVertical = true
        splitView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(splitView)

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
        view.addSubview(searchIconView)

        // Search field replacing title label
        searchField.placeholderString = titleContent
        searchField.font = .systemFont(ofSize: 22, weight: .light)
        searchField.isBordered = false
        searchField.drawsBackground = false
        searchField.focusRingType = .none
        searchField.textColor = .labelColor
        searchField.delegate = self
        searchField.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(searchField)

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
        view.addSubview(separatorView)

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
            splitView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            splitView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            splitView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

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
    }

    public override func viewWillAppear() {
        super.viewWillAppear()
        // Focus the search field initially
        view.window?.makeFirstResponder(searchField)

        searchField.stringValue = ""

        if let fontName = NerwPanelContext.shared.configFontName,
            let font = NSFont(name: fontName, size: 22)
        {
            searchField.font = font
        }
        reloadData()
    }

    // Required to receive key events directly on view (fallback if searchfield doesn't focus)
    public override var acceptsFirstResponder: Bool {
        return true
    }

    public func reloadData() {
        tableView.reloadData()
        updateSelection(to: min(selectedIndex, max(0, (dataSource?.numberOfItems() ?? 0) - 1)))
    }

    private func updateSelection(to index: Int) {
        guard let ds = dataSource, ds.numberOfItems() > 0 else {
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
    }

    public override func keyDown(with event: NSEvent) {
        // Esc
        if event.keyCode == 53 {
            delegate?.didCancel()
            return
        }

        // Enter
        if event.keyCode == 36 {
            if let ds = dataSource, ds.numberOfItems() > 0 {
                delegate?.didActivate(item: ds.item(at: selectedIndex))
            }
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

    private func handleDelete() {
        if let ds = dataSource, ds.numberOfItems() > 0 {
            delegate?.didDelete(item: ds.item(at: selectedIndex))
        }
    }

    // MARK: - NSTextFieldDelegate
    public func controlTextDidChange(_ obj: Notification) {
        let query = searchField.stringValue
        delegate?.didSearch(query: query)
    }

    public func control(
        _ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector
    ) -> Bool {
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
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
            if let ds = dataSource, ds.numberOfItems() > 0 {
                delegate?.didActivate(item: ds.item(at: selectedIndex))
            }
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
}
