import Cocoa
import NerwAction
import NerwBuiltin
import NerwCore
import NerwSearchBackend

class SearchEnginesSettingsViewController: NSViewController {

    private let scrollView = NSScrollView()
    private let stackView = FlippedStackView()
    private var engines: [Engine] = []

    private var enginesListStack: NSStackView!
    private var modifiersListStack: NSStackView!
    private var enginesPopUp: NSPopUpButton!

    override func loadView() {
        self.view = NSView()
        self.view.wantsLayer = true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        reloadData()

        NotificationCenter.default.addObserver(
            self, selector: #selector(refreshUI), name: Notification.Name("NerwConfigDidUpdate"),
            object: nil)
    }

    private func setupUI() {
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
        stackView.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 40, right: 20)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
            stackView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),
        ])

        // --- 1. General Section (Default Engine) ---
        let generalSectionStack = NSStackView()
        generalSectionStack.orientation = .vertical
        generalSectionStack.spacing = 12
        generalSectionStack.alignment = .leading

        // Default Engine Row
        let defaultEngineRow = NSStackView()
        defaultEngineRow.orientation = .horizontal
        defaultEngineRow.spacing = 10
        defaultEngineRow.alignment = .centerY

        let defaultEngineLabel = NSTextField(labelWithString: "Default Engine:")
        enginesPopUp = NSPopUpButton(frame: .zero, pullsDown: false)

        refreshDefaultEnginePopUp()

        enginesPopUp.target = self
        enginesPopUp.action = #selector(defaultEngineChanged(_:))

        defaultEngineRow.addArrangedSubview(defaultEngineLabel)
        defaultEngineRow.addArrangedSubview(enginesPopUp)
        defaultEngineRow.addArrangedSubview(NSView())  // Spacer

        generalSectionStack.addArrangedSubview(defaultEngineRow)

        let generalSection = SettingsSection(
            title: "General",
            contentViews: [generalSectionStack]
        )
        stackView.addArrangedSubview(generalSection)
        generalSection.widthAnchor.constraint(equalTo: stackView.widthAnchor, constant: -40)
            .isActive = true

        // --- 2. Custom Bangs List ---
        enginesListStack = NSStackView()
        enginesListStack.orientation = .vertical
        enginesListStack.spacing = 0
        enginesListStack.alignment = .leading
        enginesListStack.translatesAutoresizingMaskIntoConstraints = false

        let addBtn = NSButton(
            title: "Add New Engine", target: self, action: #selector(addBangClicked))
        addBtn.bezelStyle = .rounded
        addBtn.controlSize = .small
        addBtn.font = .systemFont(ofSize: 11)
        addBtn.translatesAutoresizingMaskIntoConstraints = false

        let bangsStack = NSStackView()
        bangsStack.orientation = .vertical
        bangsStack.spacing = 12
        bangsStack.alignment = .leading
        bangsStack.addArrangedSubview(enginesListStack)
        bangsStack.addArrangedSubview(addBtn)

        enginesListStack.widthAnchor.constraint(equalTo: bangsStack.widthAnchor).isActive = true

        let customBangsSection = SettingsSection(
            title: "Search Engines & Bangs",
            contentViews: [bangsStack]
        )

        stackView.addArrangedSubview(customBangsSection)
        customBangsSection.widthAnchor.constraint(equalTo: stackView.widthAnchor, constant: -40)
            .isActive = true

        // --- 3. Custom Modifiers Section ---
        modifiersListStack = NSStackView()
        modifiersListStack.orientation = .vertical
        modifiersListStack.spacing = 0
        modifiersListStack.alignment = .leading
        modifiersListStack.translatesAutoresizingMaskIntoConstraints = false

        let addModBtn = NSButton(
            title: "Add Modifier", target: self, action: #selector(addModifierClicked))
        addModBtn.bezelStyle = .rounded
        addModBtn.controlSize = .small
        addModBtn.font = .systemFont(ofSize: 11)
        addModBtn.translatesAutoresizingMaskIntoConstraints = false

        let modifiersStack = NSStackView()
        modifiersStack.orientation = .vertical
        modifiersStack.spacing = 12
        modifiersStack.alignment = .leading
        modifiersStack.addArrangedSubview(modifiersListStack)
        modifiersStack.addArrangedSubview(addModBtn)

        modifiersListStack.widthAnchor.constraint(equalTo: modifiersStack.widthAnchor).isActive =
            true

        let customModifiersSection = SettingsSection(
            title: "Custom Modifiers",
            contentViews: [modifiersStack]
        )

        stackView.addArrangedSubview(customModifiersSection)
        customModifiersSection.widthAnchor.constraint(equalTo: stackView.widthAnchor, constant: -40)
            .isActive = true
    }

    private func reloadData() {
        engines = SearchEngine.shared.engines.sorted { a, b in
            let aIsBuiltIn = SearchEngine.shared.isBuiltIn(name: a.name)
            let bIsBuiltIn = SearchEngine.shared.isBuiltIn(name: b.name)
            if aIsBuiltIn && !bIsBuiltIn { return true }
            if !aIsBuiltIn && bIsBuiltIn { return false }
            return a.name < b.name
        }

        refreshDefaultEnginePopUp()

        // Clear current list
        for subview in enginesListStack.arrangedSubviews {
            subview.removeFromSuperview()
        }

        // Rebuild list
        for engine in engines {
            let row = createEngineRow(for: engine)
            enginesListStack.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: enginesListStack.widthAnchor).isActive = true
        }

        // --- Modifiers ---
        for subview in modifiersListStack.arrangedSubviews {
            subview.removeFromSuperview()
        }

        let configModifiers = ConfigManager.shared.config.searchEngineModifiers
        for (mod, triggers) in configModifiers {
            let row = createModifierRow(modStr: mod, triggers: triggers)
            modifiersListStack.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: modifiersListStack.widthAnchor).isActive = true
        }
    }

    private func refreshDefaultEnginePopUp() {
        guard let popUp = enginesPopUp else { return }
        popUp.removeAllItems()
        for engine in SearchEngine.shared.engines {
            popUp.addItem(withTitle: engine.name)
        }
        let defaultEngine = SearchEngine.shared.getDefaultEngine()
        popUp.selectItem(withTitle: defaultEngine.name)
    }

    @objc private func refreshUI() {
        refreshDefaultEnginePopUp()
        reloadData()
    }

    private func createEngineRow(for engine: Engine) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 12
        row.alignment = .centerY
        // Tighter vertical padding
        row.edgeInsets = NSEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)
        row.translatesAutoresizingMaskIntoConstraints = false
        // Tighter row height
        row.heightAnchor.constraint(equalToConstant: 36).isActive = true

        // 1. Icon
        let iconView = NSImageView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.widthAnchor.constraint(equalToConstant: 20).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 20).isActive = true

        let domain =
            URL(string: engine.urlTemplate.replacingOccurrences(of: "%@", with: ""))?.host
            ?? engine.name

        var iconImage: NSImage?
        if let key = engine.icon {
            iconImage = IconManager.shared.icon(forKey: key) ?? NSImage(named: NSImage.Name(key))
        }
        if iconImage == nil {
            iconImage =
                IconManager.shared.icon(for: domain)
                ?? NSImage(systemSymbolName: "globe", accessibilityDescription: nil)
        }
        iconView.image = iconImage
        row.addArrangedSubview(iconView)

        // 2. Name
        let nameLabel = NSTextField(labelWithString: engine.name)
        nameLabel.font = .systemFont(ofSize: 12, weight: .medium)
        nameLabel.textColor = engine.isEnabled ? .labelColor : .secondaryLabelColor
        row.addArrangedSubview(nameLabel)

        // 3. Triggers (Bangs)
        let triggers = engine.triggers.map { "!\($0)" }.joined(separator: " ")
        let triggerLabel = NSTextField(labelWithString: triggers)
        triggerLabel.font = .monospacedSystemFont(ofSize: 10, weight: .regular)
        triggerLabel.textColor = .secondaryLabelColor
        row.addArrangedSubview(triggerLabel)

        // Spacer to push buttons to the right
        row.addArrangedSubview(NSView())

        if SearchEngine.shared.isBuiltIn(name: engine.name) {
            // Built-in: Toggle only
            let toggle = NSSwitch()
            toggle.controlSize = .mini
            toggle.state = engine.isEnabled ? .on : .off
            toggle.target = self
            toggle.action = #selector(toggleEngineClicked(_:))
            toggle.identifier = NSUserInterfaceItemIdentifier(engine.name)
            row.addArrangedSubview(toggle)
        } else {
            // Custom: Edit & Delete
            // 4. Edit Button
            let editBtn = NSButton(
                image: NSImage(systemSymbolName: "pencil", accessibilityDescription: "Edit")!,
                target: self, action: #selector(editEngineRowClicked(_:)))
            editBtn.isBordered = false
            editBtn.bezelStyle = .recessed
            editBtn.controlSize = .small
            editBtn.identifier = NSUserInterfaceItemIdentifier(engine.name)
            row.addArrangedSubview(editBtn)

            // 5. Delete Button
            let deleteBtn = NSButton(
                image: NSImage(systemSymbolName: "trash", accessibilityDescription: "Delete")!,
                target: self, action: #selector(deleteEngineRowClicked(_:)))
            deleteBtn.isBordered = false
            deleteBtn.bezelStyle = .recessed
            deleteBtn.controlSize = .small
            deleteBtn.contentTintColor = .systemRed
            deleteBtn.identifier = NSUserInterfaceItemIdentifier(engine.name)
            row.addArrangedSubview(deleteBtn)
        }

        // Separator line at bottom
        let line = NSBox()
        line.boxType = .separator
        line.translatesAutoresizingMaskIntoConstraints = false

        let container = NSStackView()
        container.orientation = .vertical
        container.spacing = 0
        container.addArrangedSubview(row)
        container.addArrangedSubview(line)

        // Ensure container (and thus row) spans full width
        container.translatesAutoresizingMaskIntoConstraints = false
        row.widthAnchor.constraint(equalTo: container.widthAnchor).isActive = true
        line.widthAnchor.constraint(equalTo: container.widthAnchor).isActive = true

        return container
    }

    private func createModifierRow(modStr: String, triggers: [String]) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 12
        row.alignment = .centerY
        row.edgeInsets = NSEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)
        row.translatesAutoresizingMaskIntoConstraints = false
        row.heightAnchor.constraint(equalToConstant: 36).isActive = true

        // 1. Mod Label
        let modLabel = NSTextField(labelWithString: modStr.uppercased())
        modLabel.font = .systemFont(ofSize: 11, weight: .bold)
        modLabel.textColor = .secondaryLabelColor
        modLabel.backgroundColor = NSColor.labelColor.withAlphaComponent(0.1)
        modLabel.isBezeled = false
        modLabel.isEditable = false
        modLabel.drawsBackground = true
        row.addArrangedSubview(modLabel)

        // 2. Engine Info
        var engineName = "Unknown Engine"
        if let engine = SearchEngine.shared.engines.first(where: { e in
            !Set(e.triggers).isDisjoint(with: triggers)
        }) {
            engineName = engine.name
        }

        let nameLabel = NSTextField(labelWithString: engineName)
        nameLabel.font = .systemFont(ofSize: 12, weight: .medium)
        row.addArrangedSubview(nameLabel)

        // Spacer
        row.addArrangedSubview(NSView())

        // Delete Button
        let deleteBtn = NSButton(
            image: NSImage(systemSymbolName: "trash", accessibilityDescription: "Delete")!,
            target: self, action: #selector(deleteModifierRowClicked(_:)))
        deleteBtn.isBordered = false
        deleteBtn.bezelStyle = .recessed
        deleteBtn.controlSize = .small
        deleteBtn.contentTintColor = .systemRed
        deleteBtn.identifier = NSUserInterfaceItemIdentifier(modStr)
        row.addArrangedSubview(deleteBtn)

        let line = NSBox()
        line.boxType = .separator
        line.translatesAutoresizingMaskIntoConstraints = false

        let container = NSStackView()
        container.orientation = .vertical
        container.spacing = 0
        container.addArrangedSubview(row)
        container.addArrangedSubview(line)

        container.translatesAutoresizingMaskIntoConstraints = false
        row.widthAnchor.constraint(equalTo: container.widthAnchor).isActive = true
        line.widthAnchor.constraint(equalTo: container.widthAnchor).isActive = true

        return container
    }

    private func showModifierSheet() {
        guard let window = self.view.window else { return }

        let alert = NSAlert()
        alert.messageText = "Add Custom Modifier Mapping"
        alert.informativeText = "Map a modifier key to a specific search engine."

        let stack = NSStackView(frame: NSRect(x: 0, y: 0, width: 300, height: 80))
        stack.orientation = .vertical
        stack.spacing = 10
        stack.alignment = .leading

        let modRow = NSStackView()
        modRow.orientation = .horizontal
        modRow.spacing = 10
        let modLabel = NSTextField(labelWithString: "Modifier:")
        let modPopUp = NSPopUpButton(frame: .zero, pullsDown: false)
        for key in NerwAction.ModifierKey.allCases {
            modPopUp.addItem(withTitle: key.rawValue)
        }
        modRow.addArrangedSubview(modLabel)
        modRow.addArrangedSubview(modPopUp)

        let engineRow = NSStackView()
        engineRow.orientation = .horizontal
        engineRow.spacing = 10
        let engineLabel = NSTextField(labelWithString: "Engine:")
        let enginePopUp = NSPopUpButton(frame: .zero, pullsDown: false)
        for engine in SearchEngine.shared.engines {
            enginePopUp.addItem(withTitle: engine.name)
        }
        engineRow.addArrangedSubview(engineLabel)
        engineRow.addArrangedSubview(enginePopUp)

        stack.addArrangedSubview(modRow)
        stack.addArrangedSubview(engineRow)

        alert.accessoryView = stack
        alert.addButton(withTitle: "Add")
        alert.addButton(withTitle: "Cancel")

        alert.beginSheetModal(for: window) { response in
            guard response == .alertFirstButtonReturn else { return }
            let mod = modPopUp.titleOfSelectedItem ?? ""
            let engineName = enginePopUp.titleOfSelectedItem ?? ""

            if let engine = SearchEngine.shared.engines.first(where: { $0.name == engineName }) {
                var config = ConfigManager.shared.config
                config.searchEngineModifiers[mod] = engine.triggers
                ConfigManager.shared.config = config
                ConfigManager.shared.save()
                self.reloadData()
            }
        }
    }

    private func showEngineSheet(editing engine: Engine?) {
        guard let window = self.view.window else { return }

        let isEdit = engine != nil
        let alert = NSAlert()
        alert.messageText = isEdit ? "Edit Engine" : "Add Custom Engine / Bang"
        alert.informativeText = "Use %@ in the URL as the search query placeholder."

        let outer = NSStackView(frame: NSRect(x: 0, y: 0, width: 480, height: 130))
        outer.orientation = .horizontal
        outer.spacing = 14
        outer.alignment = .top

        let dropView = IconDropView(frame: NSRect(x: 0, y: 0, width: 72, height: 72))
        dropView.translatesAutoresizingMaskIntoConstraints = false
        dropView.widthAnchor.constraint(equalToConstant: 72).isActive = true
        dropView.heightAnchor.constraint(equalToConstant: 72).isActive = true

        let existingIconKey: String? = engine?.icon
        if let key = existingIconKey {
            let existing =
                IconManager.shared.icon(forKey: key) ?? NSImage(named: NSImage.Name(key))
                ?? IconManager.shared.icon(for: key)
            dropView.image = existing
        } else if let engine = engine {
            let domain =
                URL(string: engine.urlTemplate.replacingOccurrences(of: "%@", with: ""))?.host
                ?? engine.name
            dropView.image = IconManager.shared.icon(for: domain)
        }

        var userPickedImage: NSImage?
        dropView.onImageChanged = { img in
            userPickedImage = img
        }

        let fields = NSStackView()
        fields.orientation = .vertical
        fields.spacing = 8
        fields.alignment = .leading

        let nameField = NSTextField(string: engine?.name ?? "")
        nameField.placeholderString = "Name (e.g. Wikipedia)"

        let triggerField = NSTextField(string: engine?.triggers.joined(separator: " ") ?? "")
        triggerField.placeholderString = "Bang triggers (e.g. g google)"

        let urlField = NSTextField(string: engine?.urlTemplate ?? "")
        urlField.placeholderString = "URL (e.g. https://en.wikipedia.org/wiki/%@)"

        for field in [nameField, triggerField, urlField] {
            field.translatesAutoresizingMaskIntoConstraints = false
            fields.addArrangedSubview(field)
        }

        outer.addArrangedSubview(dropView)
        outer.addArrangedSubview(fields)

        fields.translatesAutoresizingMaskIntoConstraints = false
        fields.widthAnchor.constraint(equalTo: outer.widthAnchor, constant: -(72 + 14)).isActive =
            true
        for field in [nameField, triggerField, urlField] {
            field.widthAnchor.constraint(equalTo: fields.widthAnchor).isActive = true
        }

        alert.accessoryView = outer
        alert.addButton(withTitle: isEdit ? "Save" : "Add")
        alert.addButton(withTitle: "Cancel")

        alert.beginSheetModal(for: window) { response in
            guard response == .alertFirstButtonReturn else { return }
            let name = nameField.stringValue.trimmingCharacters(in: .whitespaces)
            let triggersStr = triggerField.stringValue.trimmingCharacters(in: .whitespaces)
                .lowercased()
            let triggers = triggersStr.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            let url = urlField.stringValue.trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty, !triggers.isEmpty, !url.isEmpty else { return }

            var iconKey: String? = existingIconKey
            if let img = userPickedImage {
                let rawKey = "custom_\(name.replacingOccurrences(of: " ", with: "_").lowercased())"
                iconKey = IconManager.shared.saveCustomIcon(image: img, key: rawKey)
            }

            if let original = engine {
                SearchEngine.shared.updateEngine(
                    originalName: original.name, name: name, url: url, triggers: triggers,
                    icon: iconKey)
            } else {
                SearchEngine.shared.addEngine(
                    name: name, url: url, triggers: triggers, icon: iconKey)
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

    @objc private func addBangClicked() {
        showEngineSheet(editing: nil)
    }

    @objc private func addModifierClicked() {
        showModifierSheet()
    }

    @objc private func deleteModifierRowClicked(_ sender: NSButton) {
        guard let mod = sender.identifier?.rawValue else { return }

        guard let window = self.view.window else { return }
        let alert = NSAlert()
        alert.messageText = "Remove Modifier Mapping"
        alert.informativeText = "Are you sure you want to remove the \(mod) mapping?"
        alert.addButton(withTitle: "Remove")
        alert.addButton(withTitle: "Cancel")

        alert.beginSheetModal(for: window) { response in
            if response == .alertFirstButtonReturn {
                var config = ConfigManager.shared.config
                config.searchEngineModifiers.removeValue(forKey: mod)
                ConfigManager.shared.config = config
                ConfigManager.shared.save()
                self.reloadData()
            }
        }
    }

    @objc private func toggleEngineClicked(_ sender: NSSwitch) {
        guard let name = sender.identifier?.rawValue else { return }
        SearchEngine.shared.toggleEngine(name: name, enabled: sender.state == .on)
        self.reloadData()
    }

    @objc private func editEngineRowClicked(_ sender: NSButton) {
        guard let name = sender.identifier?.rawValue else { return }
        if let engine = engines.first(where: { $0.name == name }) {
            showEngineSheet(editing: engine)
        }
    }

    @objc private func deleteEngineRowClicked(_ sender: NSButton) {
        guard let name = sender.identifier?.rawValue else { return }

        guard let window = self.view.window else { return }
        let alert = NSAlert()
        alert.messageText = "Remove Engine"
        alert.informativeText = "Are you sure you want to remove \(name)?"
        alert.addButton(withTitle: "Remove")
        alert.addButton(withTitle: "Cancel")

        alert.beginSheetModal(for: window) { response in
            if response == .alertFirstButtonReturn {
                SearchEngine.shared.removeEngine(name: name)
                self.reloadData()
            }
        }
    }
}
