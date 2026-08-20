import Cocoa
import NerwUI

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
    private let visualEffectView = NSVisualEffectView()

    // Placeholder actions
    private var allActions = ["Open", "Edit", "Delete", "Refresh", "Navigate"]
    private var filteredActions: [String] = []

    public func setActions(_ actions: [String]) {
        self.allActions = actions
        self.filteredActions = actions
        self.tableView.reloadData()
        if !filteredActions.isEmpty {
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }
    }

    public override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 350))
        view.wantsLayer = true

        setupUI()
        filteredActions = allActions
        tableView.reloadData()
    }

    private let backgroundContainer = NSView()
    private let searchContainer = NSView()
    private let backgroundTintView = NSView()
    private let strokesLayer = CAShapeLayer()

    private func setupUI() {
        backgroundContainer.translatesAutoresizingMaskIntoConstraints = false
        backgroundContainer.wantsLayer = true
        view.addSubview(backgroundContainer)

        let activeBackground: NSView
        let legacy = NSVisualEffectView()
        legacy.material = .fullScreenUI
        legacy.appearance = NSAppearance(named: .vibrantDark)
        legacy.blendingMode = .withinWindow
        legacy.state = .active
        legacy.wantsLayer = true
        legacy.layer?.cornerRadius = 18
        legacy.layer?.masksToBounds = true
        legacy.translatesAutoresizingMaskIntoConstraints = false
        backgroundContainer.addSubview(legacy)
        activeBackground = legacy

        backgroundTintView.wantsLayer = true
        backgroundTintView.layer?.cornerRadius = 18
        backgroundTintView.layer?.masksToBounds = true
        backgroundTintView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.18).cgColor
        backgroundTintView.translatesAutoresizingMaskIntoConstraints = false
        backgroundContainer.addSubview(backgroundTintView)

        strokesLayer.fillColor = NSColor.clear.cgColor
        strokesLayer.strokeColor = NSColor.white.withAlphaComponent(0.12).cgColor
        strokesLayer.lineWidth = 1
        backgroundContainer.layer?.addSublayer(strokesLayer)

        searchContainer.translatesAutoresizingMaskIntoConstraints = false
        searchContainer.wantsLayer = true
        searchContainer.layer?.cornerRadius = 14
        searchContainer.layer?.masksToBounds = true
        searchContainer.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.06).cgColor
        searchContainer.layer?.borderColor = NSColor.white.withAlphaComponent(0.08).cgColor
        searchContainer.layer?.borderWidth = 0.5
        backgroundContainer.addSubview(searchContainer)

        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.focusRingType = .none
        searchField.isBordered = false
        searchField.drawsBackground = false
        searchField.font = .systemFont(ofSize: 13, weight: .regular)
        searchField.placeholderString = "Search commands..."
        searchField.delegate = self
        searchContainer.addSubview(searchField)

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("command"))
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.backgroundColor = .clear
        tableView.rowHeight = 38
        tableView.intercellSpacing = .zero
        tableView.selectionHighlightStyle = .none
        tableView.focusRingType = .none
        tableView.delegate = self
        tableView.dataSource = self

        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = false
        scrollView.documentView = tableView
        scrollView.borderType = .noBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        backgroundContainer.addSubview(scrollView)

        NSLayoutConstraint.activate([
            backgroundContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundContainer.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            activeBackground.leadingAnchor.constraint(equalTo: backgroundContainer.leadingAnchor),
            activeBackground.trailingAnchor.constraint(equalTo: backgroundContainer.trailingAnchor),
            activeBackground.topAnchor.constraint(equalTo: backgroundContainer.topAnchor),
            activeBackground.bottomAnchor.constraint(equalTo: backgroundContainer.bottomAnchor),

            backgroundTintView.leadingAnchor.constraint(equalTo: backgroundContainer.leadingAnchor),
            backgroundTintView.trailingAnchor.constraint(
                equalTo: backgroundContainer.trailingAnchor),
            backgroundTintView.topAnchor.constraint(equalTo: backgroundContainer.topAnchor),
            backgroundTintView.bottomAnchor.constraint(equalTo: backgroundContainer.bottomAnchor),

            searchContainer.topAnchor.constraint(
                equalTo: backgroundContainer.topAnchor, constant: 10),
            searchContainer.leadingAnchor.constraint(
                equalTo: backgroundContainer.leadingAnchor, constant: 12),
            searchContainer.trailingAnchor.constraint(
                equalTo: backgroundContainer.trailingAnchor, constant: -12),
            searchContainer.heightAnchor.constraint(equalToConstant: 28),

            searchField.leadingAnchor.constraint(
                equalTo: searchContainer.leadingAnchor, constant: 10),
            searchField.trailingAnchor.constraint(
                equalTo: searchContainer.trailingAnchor, constant: -10),
            searchField.centerYAnchor.constraint(equalTo: searchContainer.centerYAnchor),

            scrollView.topAnchor.constraint(equalTo: searchContainer.bottomAnchor, constant: 4),
            scrollView.leadingAnchor.constraint(equalTo: backgroundContainer.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: backgroundContainer.trailingAnchor),
            scrollView.bottomAnchor.constraint(
                equalTo: backgroundContainer.bottomAnchor, constant: -8),
        ])
    }

    public override func viewDidLayout() {
        super.viewDidLayout()
        let bounds = backgroundContainer.bounds
        guard bounds.width > 0, bounds.height > 0 else { return }

        let path = CGPath(roundedRect: bounds, cornerWidth: 18, cornerHeight: 18, transform: nil)
        let maskLayer = CAShapeLayer()
        maskLayer.path = path
        backgroundContainer.layer?.mask = maskLayer

        strokesLayer.path = path
        strokesLayer.frame = bounds
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
            if tableView.selectedRow >= 0 {
                delegate?.commandPaletteDidSelect(action: filteredActions[tableView.selectedRow])
            }
            return true
        } else if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            delegate?.commandPaletteDidRequestClose()
            return true
        }
        return false
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
        // Update selection highlighting
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
        container.layer?.cornerRadius = 10
        container.layer?.masksToBounds = true
        container.translatesAutoresizingMaskIntoConstraints = false
        addSubview(container)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 13, weight: .medium)
        titleLabel.lineBreakMode = .byTruncatingTail
        container.addSubview(titleLabel)

        let configSymbol = NSImage.SymbolConfiguration(pointSize: 11, weight: .regular)
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

            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            titleLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),

            returnIconView.trailingAnchor.constraint(
                equalTo: container.trailingAnchor, constant: -16),
            returnIconView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            titleLabel.trailingAnchor.constraint(
                lessThanOrEqualTo: returnIconView.leadingAnchor, constant: -8),
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
