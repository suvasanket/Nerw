import Cocoa

public protocol HubCommandPaletteDelegate: AnyObject {
    func commandPaletteDidSelect(action: String)
    func commandPaletteDidRequestClose()
}

public class HubCommandPaletteViewController: NSViewController, NSTableViewDataSource,
    NSTableViewDelegate, NSSearchFieldDelegate
{
    public weak var delegate: HubCommandPaletteDelegate?

    let searchField: NSSearchField = {
        let field = NSSearchField()
        (field.cell as? NSSearchFieldCell)?.searchButtonCell = nil
        (field.cell as? NSSearchFieldCell)?.cancelButtonCell = nil
        return field
    }()
    private let tableView = NSTableView()
    private let scrollView = NSScrollView()
    private let effectView = NSVisualEffectView()
    private let searchContainer = NSView()

    private let rowHeight: CGFloat = 34

    private var allActions: [String] = ["Open", "Edit", "Delete", "Refresh"]
    private var filteredActions: [String] = []

    public func setActions(_ actions: [String]) {
        self.allActions = actions
        self.filteredActions = actions
        self.searchField.stringValue = ""
        self.tableView.reloadData()
        if !filteredActions.isEmpty {
            self.tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }
    }

    public override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 340, height: 240))
        view.wantsLayer = true

        setupUI()
        filteredActions = allActions
        tableView.reloadData()
        if !filteredActions.isEmpty {
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }
    }

    private func setupUI() {
        effectView.translatesAutoresizingMaskIntoConstraints = false
        effectView.material = .fullScreenUI
        effectView.appearance = NSAppearance(named: .vibrantDark)
        effectView.blendingMode = .withinWindow
        effectView.state = .active
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = 12
        effectView.layer?.masksToBounds = true
        effectView.layer?.borderWidth = 1
        effectView.layer?.borderColor = NSColor.white.withAlphaComponent(0.15).cgColor

        // Floating shadow matching the edit panel
        view.wantsLayer = true
        view.shadow = NSShadow()
        view.layer?.shadowColor = NSColor.black.cgColor
        view.layer?.shadowOpacity = 0.5
        view.layer?.shadowRadius = 20
        view.layer?.shadowOffset = NSSize(width: 0, height: -10)

        view.addSubview(effectView)

        // Rounded pill search container
        searchContainer.translatesAutoresizingMaskIntoConstraints = false
        searchContainer.wantsLayer = true
        searchContainer.layer?.cornerRadius = 14  // Fully rounded pill for 28pt height
        searchContainer.layer?.masksToBounds = true
        searchContainer.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.06).cgColor
        searchContainer.layer?.borderColor = NSColor.white.withAlphaComponent(0.12).cgColor
        searchContainer.layer?.borderWidth = 1.0
        effectView.addSubview(searchContainer)

        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.focusRingType = .none
        searchField.isBordered = false
        searchField.drawsBackground = false
        searchField.font = .systemFont(ofSize: 12, weight: .regular)
        searchField.placeholderString = "Search commands..."
        searchField.delegate = self
        searchContainer.addSubview(searchField)

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("command"))
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.style = .plain
        tableView.backgroundColor = .clear
        tableView.rowHeight = 28
        tableView.intercellSpacing = NSSize(width: 0, height: 2)
        tableView.selectionHighlightStyle = .none
        tableView.focusRingType = .none
        tableView.delegate = self
        tableView.dataSource = self
        tableView.target = self
        tableView.action = #selector(tableViewClicked)

        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.documentView = tableView
        scrollView.borderType = .noBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        effectView.addSubview(scrollView)

        NSLayoutConstraint.activate([
            effectView.topAnchor.constraint(equalTo: view.topAnchor),
            effectView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            effectView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            effectView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            // Search container
            searchContainer.topAnchor.constraint(equalTo: effectView.topAnchor, constant: 12),
            searchContainer.leadingAnchor.constraint(
                equalTo: effectView.leadingAnchor, constant: 14),
            searchContainer.trailingAnchor.constraint(
                equalTo: effectView.trailingAnchor, constant: -14),
            searchContainer.heightAnchor.constraint(equalToConstant: 28),

            // Search text inside container
            searchField.leadingAnchor.constraint(
                equalTo: searchContainer.leadingAnchor, constant: 10),
            searchField.trailingAnchor.constraint(
                equalTo: searchContainer.trailingAnchor, constant: -10),
            searchField.centerYAnchor.constraint(equalTo: searchContainer.centerYAnchor),

            // ScrollView container
            scrollView.topAnchor.constraint(equalTo: searchContainer.bottomAnchor, constant: 6),
            scrollView.leadingAnchor.constraint(equalTo: effectView.leadingAnchor, constant: 10),
            scrollView.trailingAnchor.constraint(equalTo: effectView.trailingAnchor, constant: -10),
            scrollView.bottomAnchor.constraint(equalTo: effectView.bottomAnchor, constant: -10),
        ])
    }

    public override func viewDidLayout() {
        super.viewDidLayout()
        if let column = tableView.tableColumns.first {
            column.width = tableView.bounds.width
        }
    }

    public override func viewWillAppear() {
        super.viewWillAppear()
        view.window?.makeFirstResponder(searchField)
        if !filteredActions.isEmpty {
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }
    }

    public func controlTextDidChange(_ obj: Notification) {
        let query = searchField.stringValue.lowercased()
        if query.isEmpty {
            filteredActions = allActions
        } else {
            filteredActions = allActions.filter { $0.lowercased().contains(query) }
        }
        tableView.reloadData()
        if !filteredActions.isEmpty {
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }
    }

    public func control(
        _ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector
    ) -> Bool {
        if commandSelector == #selector(NSResponder.moveUp(_:)) {
            let row = max(0, tableView.selectedRow - 1)
            tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
            tableView.scrollRowToVisible(row)
            return true
        } else if commandSelector == #selector(NSResponder.moveDown(_:)) {
            let row = min(filteredActions.count - 1, tableView.selectedRow + 1)
            tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
            tableView.scrollRowToVisible(row)
            return true
        } else if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            if tableView.selectedRow >= 0 && tableView.selectedRow < filteredActions.count {
                delegate?.commandPaletteDidSelect(action: filteredActions[tableView.selectedRow])
            }
            return true
        } else if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            delegate?.commandPaletteDidRequestClose()
            return true
        }
        return false
    }

    @objc private func tableViewClicked() {
        let row = tableView.clickedRow
        if row >= 0 && row < filteredActions.count {
            delegate?.commandPaletteDidSelect(action: filteredActions[row])
        }
    }

    public func numberOfRows(in tableView: NSTableView) -> Int {
        return filteredActions.count
    }

    public func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int)
        -> NSView?
    {
        let identifier = NSUserInterfaceItemIdentifier("CommandCell")
        var cell =
            tableView.makeView(withIdentifier: identifier, owner: self) as? CommandPaletteCellView
        if cell == nil {
            cell = CommandPaletteCellView()
            cell?.identifier = identifier
        }

        let action = filteredActions[row]
        cell?.titleLabel.stringValue = action
        cell?.isSelected = (row == tableView.selectedRow)
        return cell
    }

    public func tableViewSelectionDidChange(_ notification: Notification) {
        tableView.enumerateAvailableRowViews { rowView, row in
            if let cell = rowView.view(atColumn: 0) as? CommandPaletteCellView {
                cell.isSelected = (row == tableView.selectedRow)
            }
        }
    }
}

class CommandPaletteCellView: NSTableCellView {
    let titleLabel = NSTextField(labelWithString: "")
    let container = NSView()
    let returnIconView = NSImageView()

    var isSelected: Bool = false {
        didSet {
            updateSelectionState()
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    private func setupUI() {
        container.wantsLayer = true
        container.layer?.cornerRadius = 6
        container.layer?.masksToBounds = true
        container.translatesAutoresizingMaskIntoConstraints = false
        addSubview(container)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 12, weight: .regular)
        titleLabel.lineBreakMode = .byTruncatingTail
        container.addSubview(titleLabel)

        let configSymbol = NSImage.SymbolConfiguration(pointSize: 10, weight: .regular)
        returnIconView.image = NSImage(systemSymbolName: "return", accessibilityDescription: nil)?
            .withSymbolConfiguration(configSymbol)
        returnIconView.translatesAutoresizingMaskIntoConstraints = false
        returnIconView.contentTintColor = NSColor.white.withAlphaComponent(0.6)
        returnIconView.isHidden = true
        container.addSubview(returnIconView)

        NSLayoutConstraint.activate([
            container.leadingAnchor.constraint(equalTo: leadingAnchor),
            container.trailingAnchor.constraint(equalTo: trailingAnchor),
            container.topAnchor.constraint(equalTo: topAnchor),
            container.bottomAnchor.constraint(equalTo: bottomAnchor),

            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 10),
            titleLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),

            returnIconView.trailingAnchor.constraint(
                equalTo: container.trailingAnchor, constant: -10),
            returnIconView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            titleLabel.trailingAnchor.constraint(
                lessThanOrEqualTo: returnIconView.leadingAnchor, constant: -6),
        ])
    }

    private func updateSelectionState() {
        let selectedTextColor = NSColor.white.withAlphaComponent(0.96)
        let mainTextColor = NSColor.labelColor
        let selectionColor = NSColor.white.withAlphaComponent(0.14)

        if isSelected {
            container.layer?.backgroundColor = selectionColor.cgColor
            titleLabel.textColor = selectedTextColor
            returnIconView.isHidden = false
        } else {
            container.layer?.backgroundColor = NSColor.clear.cgColor
            titleLabel.textColor = mainTextColor
            returnIconView.isHidden = true
        }
    }
}
