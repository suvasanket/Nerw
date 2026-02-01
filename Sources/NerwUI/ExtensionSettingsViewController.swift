import Cocoa
import NerwCore

class ExtensionSettingsViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate,
    NSMenuDelegate
{

    private let scrollView = NSScrollView()
    private let tableView = NSTableView()

    private var extensions: [ExtensionManifest] = []

    override func loadView() {
        self.view = NSView()
        self.view.wantsLayer = true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        reloadData()

        NotificationCenter.default.addObserver(
            self, selector: #selector(extensionsDidUpdate),
            name: Notification.Name("NerwExtensionsDidUpdate"), object: nil)
    }

    @objc private func extensionsDidUpdate() {
        DispatchQueue.main.async {
            self.reloadData()
        }
    }

    private func setupUI() {
        // Scroll View
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        // Make constraints to fill view, but with some padding if desired, or full for list style
        // Raycast usually has full width list or slightly padded. I'll go full width.
        view.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        // Table View
        tableView.dataSource = self
        tableView.delegate = self
        tableView.headerView = nil  // No header
        tableView.rowHeight = 60
        tableView.style = .plain  // or .inset or .sourceList
        tableView.selectionHighlightStyle = .regular  // or .none if just viewing

        // Context Menu
        let menu = NSMenu()
        menu.delegate = self
        tableView.menu = menu

        // Column
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("MainColumn"))
        column.width = 400  // Approx, will autoresize
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)

        scrollView.documentView = tableView

        // Constraint table to scrollview width
        // (Usually handled by autoresizing but explicit helps if needed)
    }

    private func reloadData() {
        extensions = ExtensionEngine.shared.extensions
        tableView.reloadData()
    }

    // MARK: - Menu Delegate
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        guard tableView.clickedRow >= 0 else { return }

        menu.addItem(
            withTitle: "Uninstall", action: #selector(uninstallClicked(_:)), keyEquivalent: "")
    }

    @objc private func uninstallClicked(_ sender: Any) {
        let row = tableView.clickedRow
        guard row >= 0, row < extensions.count else { return }
        let ext = extensions[row]

        let alert = NSAlert()
        alert.messageText = "Uninstall \(ext.name)?"
        alert.informativeText =
            "Are you sure you want to remove this extension? This cannot be undone."
        alert.addButton(withTitle: "Uninstall")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            do {
                try ExtensionInstaller.shared.uninstall(id: ext.id)
                reloadData()
            } catch {
                let errAlert = NSAlert()
                errAlert.messageText = "Error"
                errAlert.informativeText = error.localizedDescription
                errAlert.runModal()
            }
        }
    }

    // MARK: - DataSource

    func numberOfRows(in tableView: NSTableView) -> Int {
        return extensions.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int)
        -> NSView?
    {
        // Recycle or create view
        let identifier = NSUserInterfaceItemIdentifier("ExtCell")
        var cell =
            tableView.makeView(withIdentifier: identifier, owner: self) as? ExtensionListCellView

        if cell == nil {
            cell = ExtensionListCellView()
            cell?.identifier = identifier
        }

        let ext = extensions[row]
        cell?.configure(with: ext)

        return cell
    }

}

class ExtensionListCellView: NSTableCellView {

    private let iconImageView = NSImageView()
    private let nameLabel = NSTextField(labelWithString: "")
    private let descLabel = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        // Icon
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.imageScaling = .scaleProportionallyUpOrDown
        addSubview(iconImageView)

        // Name
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = .systemFont(ofSize: 15, weight: .medium)
        nameLabel.textColor = .labelColor
        addSubview(nameLabel)

        // Description
        descLabel.translatesAutoresizingMaskIntoConstraints = false
        descLabel.font = .systemFont(ofSize: 12)
        descLabel.textColor = .secondaryLabelColor
        descLabel.maximumNumberOfLines = 1
        descLabel.cell?.truncatesLastVisibleLine = true
        addSubview(descLabel)

        NSLayoutConstraint.activate([
            // Icon: 32x32, 20px leading, center vertically
            iconImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            iconImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 32),
            iconImageView.heightAnchor.constraint(equalToConstant: 32),

            // Name: leading 12px from icon
            nameLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 12),
            nameLabel.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            nameLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),

            // Desc: below name
            descLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            descLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
            descLabel.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),
        ])
    }

    func configure(with manifest: ExtensionManifest) {
        nameLabel.stringValue = manifest.name
        descLabel.stringValue = manifest.description

        if let iconName = manifest.icon {
            iconImageView.image = NSImage(systemSymbolName: iconName, accessibilityDescription: nil)
        } else {
            iconImageView.image = NSImage(
                systemSymbolName: "puzzlepiece.extension", accessibilityDescription: nil)
        }
    }
}
