import Cocoa
import NerwBuiltin
import NerwCore
import NerwSearchBackend

class ActionsSettingsViewController: NSViewController, NSTextFieldDelegate, KeybindRecorderDelegate
{
    private struct ActionRowModel {
        let title: String
        let triggers: [String]
        let id: String
        let icon: NerwAction.IconType?
        let iconURL: URL?
    }

    private let scrollView = NSScrollView()
    private let stackView = FlippedStackView()
    private var reloadGeneration = 0

    override func loadView() {
        self.view = NSView()
        self.view.wantsLayer = true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        if stackView.arrangedSubviews.isEmpty {
            reloadData()
        }
    }

    override func viewDidDisappear() {
        super.viewDidDisappear()
        reloadGeneration += 1
        // Aggressively drop all generated views to free memory
        for subview in stackView.arrangedSubviews {
            subview.removeFromSuperview()
        }
        IconManager.shared.clearMemoryCache()
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
        reloadGeneration += 1
        let generation = reloadGeneration

        // Clear current stack
        for subview in stackView.arrangedSubviews {
            subview.removeFromSuperview()
        }

        // Build lightweight row models off the main thread so settings don't
        // keep the entire executable action graph resident.
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let apps = self.makeApplicationRows()
            let systemActions = self.makeRows(
                from: Nerw.shared.getAllActions() + System.shared.getAllActions())
            let shortcuts = self.makeRows(from: ShortcutsEngine.shared.getAllActions())
            let findFileAction = self.makeRows(from: [FindFile.shared.getTriggerAction()])
            let extensions = self.makeExtensionRows()

            DispatchQueue.main.async {
                guard generation == self.reloadGeneration else { return }
                self.addLazySection(title: "Applications", actions: apps)
                self.addLazySection(title: "System", actions: systemActions)
                self.addLazySection(title: "Shortcuts", actions: shortcuts)
                self.addLazySection(title: "File Search", actions: findFileAction)
                for ext in extensions {
                    self.addLazySection(title: ext.0, actions: ext.1)
                }
            }
        }
    }

    private func addLazySection(title: String, actions: [ActionRowModel]) {
        guard !actions.isEmpty else { return }

        // Create the section without content initially
        weak var sectionRef: SettingsSection?

        let section = SettingsSection(
            title: title,
            contentViews: [],
            isCollapsable: true,
            isExpanded: false,
            onExpand: { [weak self] in
                guard let self = self, let actualSection = sectionRef else { return }
                self.populateSection(section: actualSection, actions: actions)
            }
        )

        sectionRef = section
        stackView.addArrangedSubview(section)
        section.widthAnchor.constraint(equalTo: stackView.widthAnchor, constant: -40).isActive =
            true
    }

    private func populateSection(section: SettingsSection, actions: [ActionRowModel]) {
        // We process small batches of rows to avoid main thread locking up
        let batchSize = 100
        var currentIndex = 0

        func processBatch() {
            let endIndex = min(currentIndex + batchSize, actions.count)
            let batch = actions[currentIndex..<endIndex]

            for (i, action) in batch.enumerated() {
                let row = self.createActionRow(
                    title: action.title,
                    triggers: action.triggers,
                    id: action.id,
                    icon: action.icon,
                    iconURL: action.iconURL
                )

                section.addContent(row)

                // Add separator except for the ultimate last item
                let globalIndex = currentIndex + i
                if globalIndex < actions.count - 1 {
                    let line = NSBox()
                    line.boxType = .separator
                    section.addContent(line)
                    line.widthAnchor.constraint(equalTo: row.widthAnchor).isActive = true
                }
            }

            currentIndex = endIndex

            if currentIndex < actions.count {
                // Yield and continue next batch
                DispatchQueue.main.async {
                    processBatch()
                }
            } else {
                // Request layout update to accommodate new rows smoothly
                section.window?.layoutIfNeeded()
            }
        }

        processBatch()
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
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        row.addArrangedSubview(titleLabel)

        // Default Triggers in brackets
        let customAliases = NerwActionPreferenceStore.aliases(for: id)
        let defaultTriggers = triggers.filter { !customAliases.contains($0) }

        if !defaultTriggers.isEmpty {
            let triggerString = "[\(defaultTriggers.joined(separator: ", "))]"
            let triggerLabel = NSTextField(labelWithString: triggerString)
            triggerLabel.font = .monospacedSystemFont(ofSize: 10, weight: .regular)
            triggerLabel.textColor = .secondaryLabelColor
            triggerLabel.lineBreakMode = .byTruncatingTail
            triggerLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
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
        let currentHotkey = NerwActionPreferenceStore.hotkey(for: id)
        let recorder = KeybindRecorder(keybind: currentHotkey)
        recorder.identifier = NSUserInterfaceItemIdentifier(id)
        recorder.delegate = self
        recorder.translatesAutoresizingMaskIntoConstraints = false
        recorder.widthAnchor.constraint(equalToConstant: 120).isActive = true
        recorder.heightAnchor.constraint(equalToConstant: 24).isActive = true

        row.addArrangedSubview(recorder)

        return row
    }

    private func makeRows(from actions: [NerwAction]) -> [ActionRowModel] {
        actions
            .map {
                ActionRowModel(
                    title: $0.title,
                    triggers: $0.triggers,
                    id: $0.id,
                    icon: $0.icon,
                    iconURL: nil
                )
            }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    private func makeApplicationRows() -> [ActionRowModel] {
        let apps = AppSearch.shared.getAllApps()
        var rows: [ActionRowModel] = []

        for app in apps {
            let appURL = URL(fileURLWithPath: app.path)

            rows.append(
                ActionRowModel(
                    title: app.name,
                    triggers: [app.name.lowercased()],
                    id: "nerw.app.\(app.name)",
                    icon: nil,
                    iconURL: appURL
                )
            )

            if let quickAction = quickActionRow(for: app, iconURL: appURL) {
                rows.append(quickAction)
            }
        }

        return rows.sorted {
            $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
    }

    private func quickActionRow(for app: AppSearch.AppInfo, iconURL: URL) -> ActionRowModel? {
        switch app.name.lowercased() {
        case "activity monitor":
            return ActionRowModel(
                title: "Quit Process",
                triggers: [],
                id: "nerw.quick.process",
                icon: nil,
                iconURL: iconURL
            )
        case "finder":
            return ActionRowModel(
                title: "Find File",
                triggers: [],
                id: "nerw.quick.findfile",
                icon: nil,
                iconURL: iconURL
            )
        case "shortcuts":
            return ActionRowModel(
                title: "Run Shortcut",
                triggers: [],
                id: "nerw.quick.shortcuts",
                icon: nil,
                iconURL: iconURL
            )
        case "system settings":
            return ActionRowModel(
                title: "System Settings",
                triggers: [],
                id: "nerw.quick.systemsettings",
                icon: nil,
                iconURL: iconURL
            )
        default:
            return nil
        }
    }

    private func makeExtensionRows() -> [(String, [ActionRowModel])] {
        ExtensionEngine.shared.extensions.map { manifest in
            let rows = manifest.actions.map { actionManifest in
                let resolvedIcon = resolveExtensionIcon(
                    actionIcon: actionManifest.icon, manifestIcon: manifest.icon)

                return ActionRowModel(
                    title: actionManifest.name,
                    triggers: actionManifest.triggers,
                    id: "nerw.ext.\(manifest.id).\(actionManifest.name)",
                    icon: resolvedIcon.icon,
                    iconURL: resolvedIcon.iconURL
                )
            }
            .sorted { (lhs: ActionRowModel, rhs: ActionRowModel) in
                lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }

            return (manifest.name, rows)
        }
    }

    private func resolveExtensionIcon(actionIcon: String?, manifestIcon: String?)
        -> (icon: NerwAction.IconType?, iconURL: URL?)
    {
        let iconName = actionIcon ?? manifestIcon
        guard let iconName, !iconName.isEmpty else {
            return (.system("puzzlepiece.extension"), nil)
        }

        if iconName.hasPrefix("/") {
            return (nil, URL(fileURLWithPath: iconName))
        }

        return (.system(iconName), nil)
    }

    func keybindRecorder(_ recorder: KeybindRecorder, didChangeKeybind keybind: String) {
        guard let id = recorder.identifier?.rawValue else { return }
        NerwActionPreferenceStore.updateHotkey(keybind, for: id)
    }
    func controlTextDidChange(_ obj: Notification) {
        guard let textField = obj.object as? NSTextField,
            let id = textField.identifier?.rawValue
        else { return }
        NerwActionPreferenceStore.updateAliases(rawValue: textField.stringValue, for: id)
    }
}
