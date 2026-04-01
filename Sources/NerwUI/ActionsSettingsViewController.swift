import Cocoa
import NerwBuiltin
import NerwCore
import NerwSearchBackend

class ActionsSettingsViewController: NSViewController, NSTextFieldDelegate, KeybindRecorderDelegate
{

    private let scrollView = NSScrollView()
    private let stackView = FlippedStackView()

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
        stackView.spacing = 20
        stackView.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 40, right: 20)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
            stackView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),
        ])
    }

    private func reloadData() {
        // Clear current stack
        for subview in stackView.arrangedSubviews {
            subview.removeFromSuperview()
        }

        // 1. Apps Section — load on background then update UI
        let apps = AppSearch.shared.getAllApps().sorted { $0.name < $1.name }
        // Pre-build rows without icons first (icons loaded async)
        let appRows = apps.map { app in
            let id = "nerw.app." + app.path
            return createActionRow(
                title: app.name,
                triggers: [app.name],
                id: id,
                icon: nil,  // No icon yet — will be loaded async
                iconURL: URL(fileURLWithPath: app.path)
            )
        }
        addSection(title: "Applications", rows: appRows)

        // 2. System Section
        var systemActions = System.shared.getAllActions()
        systemActions.append(contentsOf: Nerw.shared.getAllActions())
        // Ensure unique by ID
        var uniqueSystemActions: [String: NerwAction] = [:]
        for action in systemActions {
            uniqueSystemActions[action.id] = action
        }
        let sortedSystemActions = uniqueSystemActions.values.sorted { $0.title < $1.title }

        let systemRows = sortedSystemActions.map { action in
            createActionRow(
                title: action.title,
                triggers: action.triggers,
                id: action.id,
                icon: action.icon
            )
        }
        addSection(title: "System", rows: systemRows)

        // 3. Shortcuts
        let shortcuts = ShortcutsEngine.shared.getAllActions()
        let shortcutRows = shortcuts.map { action in
            createActionRow(
                title: action.title,
                triggers: action.triggers,
                id: action.id,
                icon: action.icon
            )
        }
        addSection(title: "Shortcuts", rows: shortcutRows)

        // 4. File Search
        let findFileAction = FindFile.shared.getTriggerAction()
        let findFileRows = [
            createActionRow(
                title: findFileAction.title,
                triggers: findFileAction.triggers,
                id: findFileAction.id,
                icon: findFileAction.icon
            )
        ]
        addSection(title: "File Search", rows: findFileRows)

        // 5. Extensions
        let extensions = ExtensionEngine.shared.extensions
        for ext in extensions {
            let entryActions = ExtensionEngine.shared.getAllEntryActions().filter {
                $0.id.contains(ext.id)
            }
            let extRows = entryActions.map { action in
                createActionRow(
                    title: action.title,
                    triggers: action.triggers,
                    id: action.id,
                    icon: action.icon
                )
            }
            addSection(title: ext.name, rows: extRows)
        }
    }

    private func addSection(title: String, rows: [NSView]) {
        guard !rows.isEmpty else { return }

        let sectionStack = NSStackView()
        sectionStack.orientation = .vertical
        sectionStack.spacing = 0
        sectionStack.alignment = .leading

        for (index, row) in rows.enumerated() {
            sectionStack.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: sectionStack.widthAnchor).isActive = true

            if index < rows.count - 1 {
                let line = NSBox()
                line.boxType = .separator
                sectionStack.addArrangedSubview(line)
                line.widthAnchor.constraint(equalTo: sectionStack.widthAnchor).isActive = true
            }
        }

        let section = SettingsSection(
            title: title, contentViews: [sectionStack], isCollapsable: true)
        stackView.addArrangedSubview(section)
        section.widthAnchor.constraint(equalTo: stackView.widthAnchor, constant: -40).isActive =
            true
    }

    private func createActionRow(
        title: String, triggers: [String], id: String, icon: NerwAction.IconType?,
        iconURL: URL? = nil
    ) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 10
        row.alignment = .centerY
        row.edgeInsets = NSEdgeInsets(top: 4, left: 12, bottom: 4, right: 12)
        row.heightAnchor.constraint(equalToConstant: 36).isActive = true

        // Icon
        let iconView = NSImageView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.widthAnchor.constraint(equalToConstant: 20).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 20).isActive = true

        if let icon = icon {
            switch icon {
            case .system(let name):
                iconView.image = NSImage(systemSymbolName: name, accessibilityDescription: nil)
            case .image(let image):
                iconView.image = image
            case .file(let url):
                // Load icon asynchronously to avoid UI freeze
                let capturedView = iconView
                DispatchQueue.global(qos: .userInitiated).async {
                    let loadedIcon = NSWorkspace.shared.icon(forFile: url.path)
                    DispatchQueue.main.async {
                        capturedView.image = loadedIcon
                    }
                }
            }
        } else if let url = iconURL {
            // Async icon loading for apps (no icon type provided)
            let capturedView = iconView
            DispatchQueue.global(qos: .userInitiated).async {
                let loadedIcon = NSWorkspace.shared.icon(forFile: url.path)
                DispatchQueue.main.async {
                    capturedView.image = loadedIcon
                }
            }
        }
        row.addArrangedSubview(iconView)

        // Title
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 13, weight: .medium)
        titleLabel.textColor = .labelColor
        row.addArrangedSubview(titleLabel)

        // Default Triggers in brackets
        let customAliases = ConfigManager.shared.config.actionAliases[id] ?? []
        let defaultTriggers = triggers.filter { !customAliases.contains($0) }

        if !defaultTriggers.isEmpty {
            let triggerString = "[\(defaultTriggers.joined(separator: ", "))]"
            let triggerLabel = NSTextField(labelWithString: triggerString)
            triggerLabel.font = .monospacedSystemFont(ofSize: 10, weight: .regular)
            triggerLabel.textColor = .secondaryLabelColor
            row.addArrangedSubview(triggerLabel)
        }

        row.addArrangedSubview(NSView())  // Spacer

        // Custom Alias TextField Container
        let aliasContainer = NSView()
        aliasContainer.wantsLayer = true
        aliasContainer.layer?.cornerRadius = 12
        aliasContainer.layer?.borderWidth = 1
        aliasContainer.layer?.borderColor = NSColor.separatorColor.cgColor
        aliasContainer.layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.08).cgColor
        aliasContainer.translatesAutoresizingMaskIntoConstraints = false
        aliasContainer.widthAnchor.constraint(equalToConstant: 120).isActive = true
        aliasContainer.heightAnchor.constraint(equalToConstant: 24).isActive = true

        let aliasField = NSTextField()
        aliasField.placeholderString = "Alias"
        aliasField.isBordered = false
        aliasField.drawsBackground = false
        aliasField.font = .systemFont(ofSize: 12)
        aliasField.textColor = .labelColor
        aliasField.alignment = .center
        aliasField.delegate = self
        aliasField.identifier = NSUserInterfaceItemIdentifier(id)
        aliasField.focusRingType = .none
        aliasField.translatesAutoresizingMaskIntoConstraints = false

        aliasContainer.addSubview(aliasField)
        // Slight offset for visual balance
        NSLayoutConstraint.activate([
            aliasField.leadingAnchor.constraint(equalTo: aliasContainer.leadingAnchor, constant: 4),
            aliasField.trailingAnchor.constraint(
                equalTo: aliasContainer.trailingAnchor, constant: -4),
            aliasField.centerYAnchor.constraint(equalTo: aliasContainer.centerYAnchor, constant: 1),
        ])

        // Load existing custom aliases
        aliasField.stringValue = customAliases.joined(separator: " ")

        row.addArrangedSubview(aliasContainer)

        // Hotkey Recorder
        let currentHotkey = ConfigManager.shared.config.actionHotkeys[id] ?? ""
        let recorder = KeybindRecorder(keybind: currentHotkey)
        recorder.identifier = NSUserInterfaceItemIdentifier(id)
        recorder.delegate = self
        recorder.translatesAutoresizingMaskIntoConstraints = false
        recorder.widthAnchor.constraint(equalToConstant: 120).isActive = true
        recorder.heightAnchor.constraint(equalToConstant: 24).isActive = true

        row.addArrangedSubview(recorder)

        return row
    }

    func keybindRecorder(_ recorder: KeybindRecorder, didChangeKeybind keybind: String) {
        guard let id = recorder.identifier?.rawValue else { return }

        if keybind.isEmpty {
            ConfigManager.shared.config.actionHotkeys.removeValue(forKey: id)
        } else {
            ConfigManager.shared.config.actionHotkeys[id] = keybind
        }

        ConfigManager.shared.save()
    }
    func controlTextDidChange(_ obj: Notification) {
        guard let textField = obj.object as? NSTextField,
            let id = textField.identifier?.rawValue
        else { return }

        let aliases = textField.stringValue.components(separatedBy: .whitespaces).filter {
            !$0.isEmpty
        }

        if aliases.isEmpty {
            ConfigManager.shared.config.actionAliases.removeValue(forKey: id)
        } else {
            ConfigManager.shared.config.actionAliases[id] = aliases
        }

        ConfigManager.shared.save()
    }
}
