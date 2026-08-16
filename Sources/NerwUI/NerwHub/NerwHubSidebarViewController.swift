import Cocoa
import NerwCore

protocol NerwHubSidebarDelegate: AnyObject {
    func didSelect(tab: NerwHubTab)
    func didRequestDismissSidebar()
}

class SidebarBorderOverlayView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        return nil
    }
}

class NerwHubSidebarViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    weak var delegate: NerwHubSidebarDelegate?
    private var selectedTab: NerwHubTab = .memory

    var onToggle: (() -> Void)?
    var isExpanded: Bool = false {
        didSet {
            updateState()
        }
    }

    private let tableView = NSTableView()
    private let scrollView = NSScrollView()
    private let visualEffect = NSVisualEffectView()
    private let borderOverlay = SidebarBorderOverlayView()
    private let toggleButton = NSImageView()

    override func loadView() {
        let size: CGFloat = 44
        view = NSView(frame: NSRect(x: 0, y: 0, width: size, height: size))
        view.wantsLayer = true
        view.layer?.cornerRadius = size / 2

        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
        shadow.shadowOffset = NSSize(width: 4, height: -2)
        shadow.shadowBlurRadius = 12
        view.shadow = shadow

        setupVisualEffect()
        setupToggleButton()
        setupTableView()

        updateState()
    }

    private func setupVisualEffect() {
        visualEffect.frame = view.bounds
        visualEffect.autoresizingMask = [.width, .height]
        visualEffect.state = .active
        visualEffect.material = .popover
        visualEffect.blendingMode = .withinWindow
        visualEffect.layer?.cornerRadius = view.layer!.cornerRadius
        visualEffect.layer?.masksToBounds = true
        view.addSubview(visualEffect)

        borderOverlay.frame = view.bounds
        borderOverlay.autoresizingMask = [.width, .height]
        borderOverlay.wantsLayer = true
        borderOverlay.layer?.borderWidth = 1.0
        borderOverlay.layer?.borderColor = NSColor.white.withAlphaComponent(0.2).cgColor
        borderOverlay.layer?.cornerRadius = view.layer!.cornerRadius
        borderOverlay.layer?.masksToBounds = true
        view.addSubview(borderOverlay)
    }

    private func setupToggleButton() {
        toggleButton.image = NSImage(
            systemSymbolName: "sidebar.left", accessibilityDescription: "Menu")
        if #available(macOS 12.0, *) {
            toggleButton.symbolConfiguration = NSImage.SymbolConfiguration(
                hierarchicalColor: .secondaryLabelColor)
        } else {
            toggleButton.contentTintColor = .secondaryLabelColor
        }
        toggleButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(toggleButton)

        NSLayoutConstraint.activate([
            toggleButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            toggleButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 10),
            toggleButton.widthAnchor.constraint(equalToConstant: 24),
            toggleButton.heightAnchor.constraint(equalToConstant: 24),
        ])

        let clickGesture = NSClickGestureRecognizer(
            target: self, action: #selector(handleToggleClick))
        view.addGestureRecognizer(clickGesture)
    }

    @objc private func handleToggleClick() {
        onToggle?()
    }

    private func updateState() {
        scrollView.isHidden = !isExpanded
        let radius: CGFloat = isExpanded ? GlobalLayout.cornerRadius : 22
        view.layer?.cornerRadius = radius
        visualEffect.layer?.cornerRadius = radius
        borderOverlay.layer?.cornerRadius = radius

        if isExpanded {
            tableView.tableColumns.first?.width = 212
        }
    }

    private func setupTableView() {
        // Positioned below the 44px top bar
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = false
        scrollView.drawsBackground = false

        tableView.backgroundColor = .clear
        tableView.headerView = nil
        tableView.rowHeight = 36
        tableView.intercellSpacing = NSSize(width: 0, height: 4)
        tableView.selectionHighlightStyle = .regular
        tableView.dataSource = self
        tableView.delegate = self

        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("item"))
        col.resizingMask = .autoresizingMask
        tableView.addTableColumn(col)
        tableView.columnAutoresizingStyle = .firstColumnOnlyAutoresizingStyle

        scrollView.documentView = tableView
        view.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor, constant: 48),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 4),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -4),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -6),
        ])
    }

    func select(tab: NerwHubTab) {
        selectedTab = tab
        if let index = NerwHubTab.allCases.firstIndex(of: tab) {
            tableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
        }
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        if let index = NerwHubTab.allCases.firstIndex(of: selectedTab) {
            tableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
        }
    }

    // MARK: - NSTableViewDataSource & Delegate

    func numberOfRows(in tableView: NSTableView) -> Int {
        return NerwHubTab.allCases.count
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        let identifier = NSUserInterfaceItemIdentifier("SidebarRow")
        var rowView =
            tableView.makeView(withIdentifier: identifier, owner: self) as? SidebarTableRowView
        if rowView == nil {
            rowView = SidebarTableRowView()
            rowView?.identifier = identifier
        }
        return rowView
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int)
        -> NSView?
    {
        let identifier = NSUserInterfaceItemIdentifier("SidebarItemCell")
        var cell =
            tableView.makeView(withIdentifier: identifier, owner: self) as? SidebarItemCellView

        if cell == nil {
            cell = SidebarItemCellView()
            cell?.identifier = identifier
        }

        let tab = NerwHubTab.allCases[row]
        cell?.titleLabel.stringValue = tab.rawValue
        cell?.iconImageView.image = NSImage(
            systemSymbolName: tab.iconName, accessibilityDescription: nil)
        cell?.hintLabel.stringValue = "⌘\(row + 1)"

        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let row = tableView.selectedRow
        guard row >= 0, row < NerwHubTab.allCases.count else { return }
        let tab = NerwHubTab.allCases[row]
        if tab != selectedTab {
            selectedTab = tab
            delegate?.didSelect(tab: tab)
            delegate?.didRequestDismissSidebar()
        }
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {  // Esc
            delegate?.didRequestDismissSidebar()
            return
        }
        if event.keyCode == 36 {  // Enter
            let row = tableView.selectedRow
            guard row >= 0, row < NerwHubTab.allCases.count else { return }
            delegate?.didSelect(tab: NerwHubTab.allCases[row])
            delegate?.didRequestDismissSidebar()
            return
        }
        super.keyDown(with: event)
    }
}

class SidebarTableRowView: NSTableRowView {
    override func drawSelection(in dirtyRect: NSRect) {
        let selectionRect = bounds.insetBy(dx: 2, dy: 0)
        let radius: CGFloat = 4.0
        let path = NSBezierPath(roundedRect: selectionRect, xRadius: radius, yRadius: radius)
        NSColor.white.withAlphaComponent(0.12).setFill()
        path.fill()
    }
}

class SidebarItemCellView: NSTableCellView {
    let iconImageView = NSImageView()
    let titleLabel = NSTextField(labelWithString: "")
    let badgeContainer = NSView()
    let hintLabel = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.contentTintColor = .secondaryLabelColor
        if #available(macOS 12.0, *) {
            iconImageView.symbolConfiguration = NSImage.SymbolConfiguration(
                hierarchicalColor: .secondaryLabelColor)
        }
        addSubview(iconImageView)
        imageView = iconImageView

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 13, weight: .medium)
        titleLabel.lineBreakMode = .byTruncatingTail
        addSubview(titleLabel)
        textField = titleLabel

        badgeContainer.translatesAutoresizingMaskIntoConstraints = false
        badgeContainer.wantsLayer = true
        badgeContainer.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.08).cgColor
        badgeContainer.layer?.cornerRadius = 4
        badgeContainer.layer?.borderWidth = 0.5
        badgeContainer.layer?.borderColor = NSColor.white.withAlphaComponent(0.12).cgColor
        badgeContainer.setContentCompressionResistancePriority(.required, for: .horizontal)
        badgeContainer.setContentHuggingPriority(.required, for: .horizontal)
        addSubview(badgeContainer)

        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        hintLabel.font = .systemFont(ofSize: 10, weight: .semibold)
        hintLabel.textColor = .secondaryLabelColor
        hintLabel.alignment = .center
        badgeContainer.addSubview(hintLabel)

        NSLayoutConstraint.activate([
            iconImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            iconImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 16),
            iconImageView.heightAnchor.constraint(equalToConstant: 16),

            titleLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 8),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleLabel.trailingAnchor.constraint(
                lessThanOrEqualTo: badgeContainer.leadingAnchor, constant: -4),

            badgeContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            badgeContainer.centerYAnchor.constraint(equalTo: centerYAnchor),
            badgeContainer.heightAnchor.constraint(equalToConstant: 18),

            hintLabel.leadingAnchor.constraint(
                equalTo: badgeContainer.leadingAnchor, constant: 5),
            hintLabel.trailingAnchor.constraint(
                equalTo: badgeContainer.trailingAnchor, constant: -5),
            hintLabel.centerYAnchor.constraint(equalTo: badgeContainer.centerYAnchor),
        ])
    }
}
