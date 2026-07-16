import Cocoa
import NerwAction
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

            let systemActions = System.shared.getAllActions()

            let featureSystemActions = systemActions.filter {
                $0.id == "nerw.system.define" || $0.id == "nerw.system.wiki"
            }
            let featureRawActions =
                ClipboardManager.builtinActions() + SnippetManager.builtinActions()
                + BookmarkManager.builtinActions().filter { $0.id == "builtin.bookmark.add" }
                + featureSystemActions
            let featureActions = self.makeRows(from: featureRawActions)

            let finderSystemActions = systemActions.filter {
                $0.id == "nerw.system.eject" || $0.id == "nerw.system.ejectall"
                    || $0.id == "nerw.system.emptydownloads"
            }
            let finderRawActions: [NerwAction] =
                [FindFile.shared.getTriggerAction()] + finderSystemActions
            let finderActions = self.makeRows(from: finderRawActions)

            let allNerwActions = Nerw.shared.getAllActions()
            let nerwAIActions = allNerwActions.filter { $0.id == "nerw.builtin.ai" }
            let otherNerwActions = allNerwActions.filter { $0.id != "nerw.builtin.ai" }

            let miscRawActions =
                otherNerwActions
                + systemActions.filter {
                    $0.id != "nerw.system.eject" && $0.id != "nerw.system.ejectall"
                        && $0.id != "nerw.system.emptydownloads"
                        && $0.id != "nerw.system.define" && $0.id != "nerw.system.wiki"
                }
            let miscActions = self.makeRows(from: miscRawActions)
            let aiActions = self.makeRows(from: nerwAIActions)

            let shortcuts = self.makeRows(from: ShortcutsEngine.shared.getAllActions())
            let extensions = self.makeExtensionRows()

            DispatchQueue.main.async {
                guard generation == self.reloadGeneration else { return }
                self.addLazySection(title: "Applications", actions: apps, isExpanded: false)
                self.addLazySection(title: "Features", actions: featureActions)
                self.addLazySection(title: "NerwAI", actions: aiActions)
                self.addLazySection(title: "Finder", actions: finderActions)
                self.addLazySection(title: "Misc", actions: miscActions)
                self.addLazySection(title: "Shortcuts", actions: shortcuts)
                for ext in extensions {
                    self.addLazySection(title: ext.0, actions: ext.1)
                }
            }
        }
    }

    private func addLazySection(title: String, actions: [ActionRowModel], isExpanded: Bool = false)
    {
        guard !actions.isEmpty else { return }

        // Create the section without content initially
        weak var sectionRef: SettingsSection?

        let section = SettingsSection(
            title: title,
            contentViews: [],
            isCollapsable: true,
            isExpanded: isExpanded,
            onExpand: { [weak self] in
                guard let self = self, let actualSection = sectionRef else { return }
                self.populateSection(section: actualSection, actions: actions)
            }
        )

        sectionRef = section
        stackView.addArrangedSubview(section)
        section.widthAnchor.constraint(equalTo: stackView.widthAnchor, constant: -40).isActive =
            true

        if isExpanded {
            section.loadContentIfNeeded()
        }
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
                    line.widthAnchor.constraint(equalTo: row.widthAnchor, constant: -24).isActive =
                        true
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

    private static let iconCache: NSCache<NSURL, NSImage> = {
        let cache = NSCache<NSURL, NSImage>()
        cache.countLimit = 300
        return cache
    }()

    private func createActionRow(
        title: String, triggers: [String], id: String, icon: NerwAction.IconType?,
        iconURL: URL? = nil
    ) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 10
        row.alignment = .centerY
        row.edgeInsets = NSEdgeInsets(top: 2, left: 12, bottom: 2, right: 12)
        row.heightAnchor.constraint(equalToConstant: 28).isActive = true

        // Enable Toggle
        let toggle = NSButton(
            checkboxWithTitle: "", target: self, action: #selector(handleToggleEnabled(_:)))
        toggle.state = NerwActionEnabled.get(for: id) ? .on : .off
        toggle.identifier = NSUserInterfaceItemIdentifier(id)
        row.addArrangedSubview(toggle)

        // Hide Toggle
        let isHidden = NerwActionPreferenceManager.shared.isActionHidden(for: id)
        let hideToggle = NSButton(
            image: NSImage(
                systemSymbolName: isHidden ? "eye.slash" : "eye", accessibilityDescription: nil)!,
            target: self, action: #selector(handleToggleHidden(_:)))
        hideToggle.isBordered = false
        hideToggle.identifier = NSUserInterfaceItemIdentifier(id + "_hide")
        hideToggle.toolTip = "Hide from search (requires hotkey)"
        row.addArrangedSubview(hideToggle)

        // Icon
        let iconView = NSImageView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.widthAnchor.constraint(equalToConstant: 20).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 20).isActive = true

        func loadIconAsync(_ url: URL) {
            if let cached = Self.iconCache.object(forKey: url as NSURL) {
                iconView.image = cached
                return
            }
            let capturedView = iconView
            DispatchQueue.global(qos: .userInitiated).async {
                let loadedIcon = NSWorkspace.shared.icon(forFile: url.path)
                Self.iconCache.setObject(loadedIcon, forKey: url as NSURL)
                DispatchQueue.main.async {
                    capturedView.image = loadedIcon
                }
            }
        }

        if let icon = icon {
            switch icon {
            case .system(let name):
                iconView.image = NSImage(systemSymbolName: name, accessibilityDescription: nil)
            case .image(let image):
                iconView.image = image
            case .file(let url):
                loadIconAsync(url)
            case .none:
                iconView.image = nil
            }
        } else if let url = iconURL {
            loadIconAsync(url)
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
        let customAliases = NerwActionPreferenceManager.shared.aliases(for: id)
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
        let currentHotkey = NerwActionPreferenceManager.shared.hotkey(for: id)
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
            let appId = "nerw.app.\(app.name)"

            let isAppConfigured =
                !NerwActionPreferenceManager.shared.hotkey(for: appId).isEmpty
                || !NerwActionPreferenceManager.shared.aliases(for: appId).isEmpty
                || NerwActionPreferenceManager.shared.isActionHidden(for: appId)
                || !NerwActionPreferenceManager.shared.isActionEnabled(for: appId)

            if isAppConfigured {
                rows.append(
                    ActionRowModel(
                        title: app.name,
                        triggers: [app.name.lowercased()],
                        id: appId,
                        icon: nil,
                        iconURL: appURL
                    )
                )
            }

            if let quickAction = quickActionRow(for: app, iconURL: appURL) {
                let isQuickConfigured =
                    !NerwActionPreferenceManager.shared.hotkey(for: quickAction.id).isEmpty
                    || !NerwActionPreferenceManager.shared.aliases(for: quickAction.id).isEmpty
                    || NerwActionPreferenceManager.shared.isActionHidden(for: quickAction.id)
                    || !NerwActionPreferenceManager.shared.isActionEnabled(for: quickAction.id)

                if isQuickConfigured {
                    rows.append(quickAction)
                }
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
        NerwActionPreferenceManager.shared.updateHotkey(keybind, for: id)

        if keybind.isEmpty && NerwActionPreferenceManager.shared.isActionHidden(for: id) {
            NerwActionPreferenceManager.shared.updateActionHidden(false, for: id)
            SearchService.shared.loadCache(asyncUpdate: true)
            // The UI will update on next reload
        }
    }
    func controlTextDidChange(_ obj: Notification) {
        guard let textField = obj.object as? NSTextField,
            let id = textField.identifier?.rawValue
        else { return }
        NerwActionPreferenceManager.shared.updateAliases(rawValue: textField.stringValue, for: id)
    }

    @objc private func handleToggleEnabled(_ sender: NSButton) {
        guard let id = sender.identifier?.rawValue else { return }
        let enabled = sender.state == .on
        NerwActionEnabled.set(enabled, for: id)

        // Reload search cache if needed
        SearchService.shared.loadCache(asyncUpdate: true)

        let status = enabled ? "enabled" : "disabled"
        NerwNotificationManager.shared.show(
            content: "Action \(status): \(id)",
            level: .info
        )
    }

    @objc private func handleToggleHidden(_ sender: NSButton) {
        guard let idWithSuffix = sender.identifier?.rawValue,
            idWithSuffix.hasSuffix("_hide")
        else { return }
        let id = String(idWithSuffix.dropLast(5))

        let hasHotkey = !NerwActionPreferenceManager.shared.hotkey(for: id).isEmpty
        let currentlyHidden = NerwActionPreferenceManager.shared.isActionHidden(for: id)

        if !currentlyHidden && !hasHotkey {
            NerwNotificationManager.shared.show(
                content: "Cannot hide action without a hotkey",
                level: .info
            )
            return
        }

        let nextHidden = !currentlyHidden
        NerwActionPreferenceManager.shared.updateActionHidden(nextHidden, for: id)
        sender.image = NSImage(
            systemSymbolName: nextHidden ? "eye.slash" : "eye", accessibilityDescription: nil)

        SearchService.shared.loadCache(asyncUpdate: true)

        let status = nextHidden ? "hidden" : "unhidden"
        NerwNotificationManager.shared.show(
            content: "Action \(status): \(id)",
            level: .info
        )
    }
}
