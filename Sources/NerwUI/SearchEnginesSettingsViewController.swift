import Cocoa
import NerwBuiltin
import NerwSearchBackend

class SearchEnginesSettingsViewController: NSViewController, NSTableViewDataSource,
    NSTableViewDelegate
{

    private let scrollView = NSScrollView()
    private let stackView = FlippedStackView()
    private var engines: [Engine] = []

    private var enginesTableView: NSTableView!
    private var tableHeightConstraint: NSLayoutConstraint!

    override func loadView() {
        self.view = NSView()
        self.view.wantsLayer = true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        reloadData()
    }

    private func setupUI() {
        // ... (rest of setupUI stays same until bangs section)
        // Note: I'm keeping the rest of the code for context in the replace call
        // but focusing on the table section.

        // Scroll View Setup
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.documentView = stackView

        view.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        // Stack View Setup
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.orientation = .vertical
        stackView.alignment = .centerX
        stackView.spacing = 16
        // Increased bottom padding to make space for table view editing cleanly
        stackView.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 40, right: 20)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
            stackView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),
        ])

        // --- 1. Default Search Engine ---
        let defaultEngineRow = NSStackView()
        defaultEngineRow.orientation = .horizontal
        defaultEngineRow.spacing = 10
        defaultEngineRow.alignment = .centerY

        let defaultEngineLabel = NSTextField(labelWithString: "Default Engine:")

        let enginesPopUp = NSPopUpButton(frame: .zero, pullsDown: false)
        let defaultEngine = SearchEngine.shared.getDefaultEngine()

        for engine in SearchEngine.shared.engines {
            enginesPopUp.addItem(withTitle: engine.name)
        }
        enginesPopUp.selectItem(withTitle: defaultEngine.name)
        enginesPopUp.target = self
        enginesPopUp.action = #selector(defaultEngineChanged(_:))

        defaultEngineRow.addArrangedSubview(defaultEngineLabel)
        defaultEngineRow.addArrangedSubview(enginesPopUp)
        defaultEngineRow.addArrangedSubview(NSView())  // Spacer

        let defaultEngineSection = SettingsSection(
            title: "Default Search Engine",
            contentViews: [defaultEngineRow]
        )
        stackView.addArrangedSubview(defaultEngineSection)
        defaultEngineSection.widthAnchor.constraint(equalTo: stackView.widthAnchor, constant: -40)
            .isActive = true

        // --- 2. Smart Search (Threshold) ---
        let thresholdStack = NSStackView()
        thresholdStack.orientation = .horizontal
        thresholdStack.spacing = 10
        thresholdStack.alignment = .centerY

        let thresholdLabel = NSTextField(labelWithString: "Suggestion Threshold:")

        let thresholdStepper = NSStepper()
        thresholdStepper.minValue = 1
        thresholdStepper.maxValue = 10
        thresholdStepper.intValue = Int32(ConfigManager.shared.config.searchEngineSuggestThreshold)
        thresholdStepper.target = self
        thresholdStepper.action = #selector(thresholdChanged(_:))

        let thresholdValueLabel = NSTextField(
            labelWithString: "\(ConfigManager.shared.config.searchEngineSuggestThreshold)")
        thresholdValueLabel.tag = 101  // Tag to find it later

        thresholdStack.addArrangedSubview(thresholdLabel)
        thresholdStack.addArrangedSubview(thresholdValueLabel)
        thresholdStack.addArrangedSubview(thresholdStepper)
        thresholdStack.addArrangedSubview(NSView())  // Spacer

        let smartSearchSection = SettingsSection(
            title: "Smart Search",
            contentViews: [thresholdStack]
        )
        stackView.addArrangedSubview(smartSearchSection)
        smartSearchSection.widthAnchor.constraint(equalTo: stackView.widthAnchor, constant: -40)
            .isActive = true

        // --- 3. Custom Bangs List ---
        let bangsStack = NSStackView()
        bangsStack.orientation = .vertical
        bangsStack.spacing = 8
        bangsStack.alignment = .leading

        // Add TableView
        let tableScroll = NSScrollView()
        tableScroll.hasVerticalScroller = false
        tableScroll.hasHorizontalScroller = false
        tableScroll.verticalScrollElasticity = .none
        tableScroll.horizontalScrollElasticity = .none
        tableScroll.drawsBackground = false  // Transparency
        tableScroll.borderType = .noBorder  // Remove border for cleaner look
        tableScroll.translatesAutoresizingMaskIntoConstraints = false

        tableHeightConstraint = tableScroll.heightAnchor.constraint(equalToConstant: 180)
        tableHeightConstraint.isActive = true

        enginesTableView = NSTableView()
        enginesTableView.backgroundColor = .clear  // Transparency
        enginesTableView.dataSource = self
        enginesTableView.delegate = self
        enginesTableView.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        enginesTableView.allowsMultipleSelection = false
        enginesTableView.headerView = NSTableHeaderView()

        let col1 = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("Name"))
        col1.title = "Name"
        col1.width = 100
        enginesTableView.addTableColumn(col1)

        let col2 = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("Trigger"))
        col2.title = "Trigger"
        col2.width = 60
        enginesTableView.addTableColumn(col2)

        let col3 = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("URL"))
        col3.title = "URL Template"
        col3.width = 200
        enginesTableView.addTableColumn(col3)

        tableScroll.documentView = enginesTableView
        enginesTableView.doubleAction = #selector(editBangClicked)
        enginesTableView.target = self
        bangsStack.addArrangedSubview(tableScroll)
        tableScroll.widthAnchor.constraint(equalTo: bangsStack.widthAnchor).isActive = true

        // Add/Remove buttons
        let controlsStack = NSStackView()
        controlsStack.orientation = .horizontal
        controlsStack.spacing = 8

        let addBtn = NSButton(title: "Add Engine", target: self, action: #selector(addBangClicked))
        addBtn.bezelStyle = .rounded
        let editBtn = NSButton(title: "Edit", target: self, action: #selector(editBangClicked))
        editBtn.bezelStyle = .rounded
        let removeBtn = NSButton(
            title: "Remove", target: self, action: #selector(removeBangClicked))
        removeBtn.bezelStyle = .rounded

        controlsStack.addArrangedSubview(addBtn)
        controlsStack.addArrangedSubview(editBtn)
        controlsStack.addArrangedSubview(removeBtn)
        controlsStack.addArrangedSubview(NSView())  // spacer

        bangsStack.addArrangedSubview(controlsStack)

        let customBangsSection = SettingsSection(
            title: "Search Engines & Bangs",
            contentViews: [bangsStack]
        )

        stackView.addArrangedSubview(customBangsSection)
        customBangsSection.widthAnchor.constraint(equalTo: stackView.widthAnchor, constant: -40)
            .isActive = true
    }

    private func reloadData() {
        engines = SearchEngine.shared.engines
        enginesTableView.reloadData()
        updateTableHeight()
    }

    private func updateTableHeight() {
        enginesTableView.layout()
        let headerHeight = enginesTableView.headerView?.frame.height ?? 0
        let rowHeight = enginesTableView.rowHeight
        let spacing = enginesTableView.intercellSpacing.height
        let count = CGFloat(engines.count)

        // Height = header + (rows + spacing)
        let totalHeight = headerHeight + (rowHeight + spacing) * count
        tableHeightConstraint.constant = max(totalHeight, 40)
    }

    /// Shows a sheet for adding or editing an engine.
    /// When `editing` is non-nil, the form is pre-filled and the save action calls `updateEngine`.
    private func showEngineSheet(editing engine: Engine?) {
        guard let window = self.view.window else { return }

        let isEdit = engine != nil
        let alert = NSAlert()
        alert.messageText = isEdit ? "Edit Engine" : "Add Custom Engine / Bang"
        alert.informativeText = "Use %@ in the URL as the search query placeholder."

        // ── Outer horizontal stack: [icon drop zone] | [fields] ──
        let outer = NSStackView(frame: NSRect(x: 0, y: 0, width: 480, height: 130))
        outer.orientation = .horizontal
        outer.spacing = 14
        outer.alignment = .top

        // Icon drop zone (72×72)
        let dropView = IconDropView(frame: NSRect(x: 0, y: 0, width: 72, height: 72))
        dropView.translatesAutoresizingMaskIntoConstraints = false
        dropView.widthAnchor.constraint(equalToConstant: 72).isActive = true
        dropView.heightAnchor.constraint(equalToConstant: 72).isActive = true

        // Pre-fill drop zone with existing icon (display only — does NOT mark icon as changed)
        let existingIconKey: String? = engine?.icon
        if let key = existingIconKey {
            let existing =
                IconManager.shared.icon(forKey: key)
                ?? NSImage(named: NSImage.Name(key))
                ?? IconManager.shared.icon(for: key)
            dropView.image = existing
        } else if let engine = engine {
            let domain =
                URL(string: engine.urlTemplate.replacingOccurrences(of: "%@", with: ""))?.host
                ?? engine.name
            dropView.image = IconManager.shared.icon(for: domain)
        }

        // Only set when user actively drops/picks a NEW image
        var userPickedImage: NSImage?
        dropView.onImageChanged = { img in
            userPickedImage = img
        }

        // Fields stack (vertical)
        let fields = NSStackView()
        fields.orientation = .vertical
        fields.spacing = 8
        fields.alignment = .leading

        let nameField = NSTextField(string: engine?.name ?? "")
        nameField.placeholderString = "Name (e.g. Wikipedia)"

        let triggerField = NSTextField(string: engine?.triggers.first ?? "")
        triggerField.placeholderString = "Bang trigger (e.g. w)"

        let urlField = NSTextField(string: engine?.urlTemplate ?? "")
        urlField.placeholderString = "URL (e.g. https://en.wikipedia.org/wiki/%@)"

        for field in [nameField, triggerField, urlField] {
            field.translatesAutoresizingMaskIntoConstraints = false
            fields.addArrangedSubview(field)
        }

        outer.addArrangedSubview(dropView)
        outer.addArrangedSubview(fields)

        // Make fields fill remaining width
        fields.translatesAutoresizingMaskIntoConstraints = false
        fields.widthAnchor.constraint(
            equalTo: outer.widthAnchor, constant: -(72 + 14)
        ).isActive = true

        for field in [nameField, triggerField, urlField] {
            field.widthAnchor.constraint(equalTo: fields.widthAnchor).isActive = true
        }

        alert.accessoryView = outer
        alert.addButton(withTitle: isEdit ? "Save" : "Add")
        alert.addButton(withTitle: "Cancel")

        alert.beginSheetModal(for: window) { response in
            guard response == .alertFirstButtonReturn else { return }
            let name = nameField.stringValue.trimmingCharacters(in: .whitespaces)
            let trigger = triggerField.stringValue.trimmingCharacters(in: .whitespaces).lowercased()
            let url = urlField.stringValue.trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty, !trigger.isEmpty, !url.isEmpty else { return }

            // Icon key: only re-save if user actually picked a NEW image
            var iconKey: String? = existingIconKey
            if let img = userPickedImage {
                let rawKey = "custom_\(name.replacingOccurrences(of: " ", with: "_").lowercased())"
                iconKey = IconManager.shared.saveCustomIcon(image: img, key: rawKey)
            }

            if let original = engine {
                SearchEngine.shared.updateEngine(
                    originalName: original.name,
                    name: name,
                    url: url,
                    trigger: trigger,
                    icon: iconKey
                )
            } else {
                SearchEngine.shared.addEngine(name: name, url: url, trigger: trigger, icon: iconKey)
            }
            self.reloadData()
        }
    }

    // MARK: - Actions

    @objc private func defaultEngineChanged(_ sender: NSPopUpButton) {
        let name = sender.titleOfSelectedItem
        if let engine = SearchEngine.shared.engines.first(where: { $0.name == name }) {
            SearchEngine.shared.setDefaultEngine(engine)
        }
    }

    @objc private func thresholdChanged(_ sender: NSStepper) {
        let value = Int(sender.intValue)
        ConfigManager.shared.config.searchEngineSuggestThreshold = value
        ConfigManager.shared.save()

        if let label = view.viewWithTag(101) as? NSTextField {
            label.stringValue = "\(value)"
        }
    }

    @objc private func addBangClicked() {
        showEngineSheet(editing: nil)
    }

    @objc private func editBangClicked() {
        let row = enginesTableView.selectedRow
        guard row >= 0 && row < engines.count else { return }
        showEngineSheet(editing: engines[row])
    }

    @objc private func removeBangClicked() {
        let row = enginesTableView.selectedRow
        guard row >= 0 && row < engines.count else { return }
        let engine = engines[row]

        guard let window = self.view.window else { return }

        let alert = NSAlert()
        alert.messageText = "Remove Engine"
        alert.informativeText = "Are you sure you want to remove \(engine.name)?"
        alert.addButton(withTitle: "Remove")
        alert.addButton(withTitle: "Cancel")

        alert.beginSheetModal(for: window) { response in
            if response == .alertFirstButtonReturn {
                SearchEngine.shared.removeEngine(name: engine.name)
                self.reloadData()
            }
        }
    }

    // MARK: - NSTableViewDataSource & Delegate

    func numberOfRows(in tableView: NSTableView) -> Int {
        return engines.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int)
        -> NSView?
    {
        let engine = engines[row]
        let identifier = tableColumn?.identifier.rawValue ?? ""

        var text = ""
        switch identifier {
        case "Name":
            text = engine.name
        case "Trigger":
            text = engine.triggers.joined(separator: ", ")
        case "URL":
            text = engine.urlTemplate
        default:
            break
        }

        if let cell = tableView.makeView(
            withIdentifier: NSUserInterfaceItemIdentifier(identifier), owner: nil)
            as? NSTableCellView
        {
            cell.textField?.stringValue = text
            return cell
        } else {
            let cell = NSTableCellView()
            let textField = NSTextField(labelWithString: text)
            textField.translatesAutoresizingMaskIntoConstraints = false
            textField.lineBreakMode = .byTruncatingTail
            cell.addSubview(textField)
            cell.textField = textField
            cell.identifier = NSUserInterfaceItemIdentifier(identifier)
            NSLayoutConstraint.activate([
                textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                textField.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
                textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
            ])
            return cell
        }
    }
}
