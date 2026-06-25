import Cocoa
import NerwCore
import NerwSearchBackend
import NerwUtils

class AISettingsViewController: NSViewController {

    private let scrollView: NSScrollView = {
        let sv = NSScrollView()
        sv.hasVerticalScroller = true
        sv.hasHorizontalScroller = false
        sv.autohidesScrollers = true
        sv.drawsBackground = false
        return sv
    }()

    private let stackView: FlippedStackView = {
        let stack = FlippedStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 26
        stack.edgeInsets = NSEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
        return stack
    }()

    // General AI UI elements
    private let enableAISwitch = NSSwitch()
    private let enableMemorySwitch = NSSwitch()
    private let memoryRow = NSStackView()
    private let warningContainer = NSView()
    private let warningLabel = NSTextField()

    // Global Configuration elements
    private let enableClipboardSwitch = NSSwitch()
    private let enableActiveAppSwitch = NSSwitch()
    private let enableWebContextSwitch = NSSwitch()
    private let enableCalendarSwitch = NSSwitch()
    private let enableReminderSwitch = NSSwitch()
    private let enableNotesSwitch = NSSwitch()
    private let notesPathLabel = NSTextField()

    // Providers Section elements
    private let providersListStack = NSStackView()
    private let addProviderBtn = NSButton()

    // Sections
    private var activationSection: SettingsSection!
    private var providersSection: SettingsSection!
    private var contextSection: SettingsSection!

    private var activeAlertTarget: AnyObject?

    override func loadView() {
        self.view = NSView()
        self.view.wantsLayer = true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()

        NotificationCenter.default.addObserver(
            self, selector: #selector(refreshUI), name: Notification.Name("NerwConfigDidUpdate"),
            object: nil)

        refreshUI()
    }

    private func setupUI() {
        view.addSubview(scrollView)
        scrollView.documentView = stackView

        // --- 1. General ---
        let enableTextStack = NSStackView()
        enableTextStack.orientation = .vertical
        enableTextStack.alignment = .leading
        enableTextStack.spacing = 2
        enableTextStack.translatesAutoresizingMaskIntoConstraints = false

        let enableLabel = NSTextField(labelWithString: "Nerw AI")
        enableLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        enableLabel.textColor = .labelColor

        let enableSubtext = NSTextField(
            labelWithString: "Activate the system-wide AI assistant sub-system.")
        enableSubtext.font = .systemFont(ofSize: 11)
        enableSubtext.textColor = .secondaryLabelColor
        enableSubtext.cell?.wraps = true
        enableSubtext.cell?.isScrollable = false

        enableTextStack.addArrangedSubview(enableLabel)
        enableTextStack.addArrangedSubview(enableSubtext)

        enableAISwitch.controlSize = .mini
        enableAISwitch.target = self
        enableAISwitch.action = #selector(enableAICheckboxToggled(_:))
        enableAISwitch.translatesAutoresizingMaskIntoConstraints = false

        let enableRow = NSStackView()
        enableRow.orientation = .horizontal
        enableRow.alignment = .centerY
        enableRow.distribution = .fill
        enableRow.addArrangedSubview(enableTextStack)
        let spacer1 = NSView()
        spacer1.setContentHuggingPriority(.defaultLow, for: .horizontal)
        enableRow.addArrangedSubview(spacer1)
        enableRow.addArrangedSubview(enableAISwitch)

        enableMemorySwitch.controlSize = .mini
        enableMemorySwitch.target = self
        enableMemorySwitch.action = #selector(enableMemoryCheckboxToggled(_:))
        enableMemorySwitch.translatesAutoresizingMaskIntoConstraints = false

        let memoryRow = createToggleRow(
            title: "Memory",
            subtitle: "Enable local long-term memory for persistent context.",
            switchControl: enableMemorySwitch
        )

        // Warning Container
        warningContainer.wantsLayer = true
        warningContainer.layer?.cornerRadius = 8
        warningContainer.layer?.backgroundColor =
            NSColor.systemOrange.withAlphaComponent(0.12).cgColor
        warningContainer.layer?.borderWidth = 1
        warningContainer.layer?.borderColor = NSColor.systemOrange.withAlphaComponent(0.25).cgColor
        warningContainer.translatesAutoresizingMaskIntoConstraints = false

        let warningStack = NSStackView()
        warningStack.orientation = .horizontal
        warningStack.alignment = .centerY
        warningStack.spacing = 8
        warningStack.edgeInsets = NSEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        warningStack.translatesAutoresizingMaskIntoConstraints = false

        let warningIcon = NSImageView()
        warningIcon.image = NSImage(
            systemSymbolName: "exclamationmark.triangle.fill",
            accessibilityDescription: "Warning")
        warningIcon.contentTintColor = .systemOrange
        warningIcon.translatesAutoresizingMaskIntoConstraints = false
        warningIcon.widthAnchor.constraint(equalToConstant: 16).isActive = true
        warningIcon.heightAnchor.constraint(equalToConstant: 16).isActive = true

        warningLabel.stringValue =
            "Foundation model (Apple Intelligence) is currently under construction. Please use the BYOK backend model type."
        warningLabel.font = .systemFont(ofSize: 12, weight: .medium)
        warningLabel.textColor = .labelColor
        warningLabel.isEditable = false
        warningLabel.isSelectable = true
        warningLabel.drawsBackground = false
        warningLabel.isBordered = false
        warningLabel.cell?.wraps = true
        warningLabel.cell?.isScrollable = false
        warningLabel.translatesAutoresizingMaskIntoConstraints = false
        warningLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        warningStack.addArrangedSubview(warningIcon)
        warningStack.addArrangedSubview(warningLabel)
        warningContainer.addSubview(warningStack)

        NSLayoutConstraint.activate([
            warningStack.topAnchor.constraint(equalTo: warningContainer.topAnchor),
            warningStack.leadingAnchor.constraint(equalTo: warningContainer.leadingAnchor),
            warningStack.trailingAnchor.constraint(equalTo: warningContainer.trailingAnchor),
            warningStack.bottomAnchor.constraint(equalTo: warningContainer.bottomAnchor),
        ])

        activationSection = SettingsSection(
            title: "General",
            contentViews: [enableRow, warningContainer]
        )
        stackView.addArrangedSubview(activationSection)
        activationSection.widthAnchor.constraint(equalTo: stackView.widthAnchor, constant: -48)
            .isActive = true

        // --- 2. Providers List & Management ---
        providersListStack.orientation = .vertical
        providersListStack.spacing = 4
        providersListStack.alignment = .leading
        providersListStack.translatesAutoresizingMaskIntoConstraints = false

        addProviderBtn.title = "Add"
        addProviderBtn.bezelStyle = .rounded
        addProviderBtn.controlSize = .small
        addProviderBtn.target = self
        addProviderBtn.action = #selector(addProviderClicked(_:))

        let buttonRow = NSStackView()
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 10
        buttonRow.translatesAutoresizingMaskIntoConstraints = false
        buttonRow.addArrangedSubview(addProviderBtn)
        buttonRow.addArrangedSubview(NSView())  // Spacer

        let providersWrapper = NSStackView()
        providersWrapper.orientation = .vertical
        providersWrapper.spacing = 12
        providersWrapper.alignment = .leading
        providersWrapper.translatesAutoresizingMaskIntoConstraints = false
        providersWrapper.addArrangedSubview(providersListStack)
        providersWrapper.addArrangedSubview(buttonRow)

        providersListStack.widthAnchor.constraint(equalTo: providersWrapper.widthAnchor).isActive =
            true
        buttonRow.widthAnchor.constraint(equalTo: providersWrapper.widthAnchor).isActive = true

        providersSection = SettingsSection(
            title: "Provider",
            contentViews: [providersWrapper]
        )
        stackView.addArrangedSubview(providersSection)
        providersSection.widthAnchor.constraint(equalTo: stackView.widthAnchor, constant: -48)
            .isActive = true

        // --- 3. Context Section ---
        let pciExplanation = NSTextField(
            labelWithString:
                "Precise Context Injection (PCI) uses relvent local data powered by a Natural Language Processer."
        )
        pciExplanation.font = .systemFont(ofSize: 11, weight: .medium)
        pciExplanation.textColor = .secondaryLabelColor
        pciExplanation.cell?.wraps = true
        pciExplanation.cell?.isScrollable = false
        pciExplanation.translatesAutoresizingMaskIntoConstraints = false

        enableClipboardSwitch.controlSize = .mini
        enableClipboardSwitch.target = self
        enableClipboardSwitch.action = #selector(clipboardToggleClicked(_:))
        let clipboardRow = createToggleRow(
            title: "Clipboard", subtitle: "Allow AI to read your recent clipboard history.",
            switchControl: enableClipboardSwitch)

        enableActiveAppSwitch.controlSize = .mini
        enableActiveAppSwitch.target = self
        enableActiveAppSwitch.action = #selector(activeAppToggleClicked(_:))
        let activeAppRow = createToggleRow(
            title: "Active App & Screen",
            subtitle: "Allow AI to see your active application and screen contents.",
            switchControl: enableActiveAppSwitch)

        enableWebContextSwitch.controlSize = .mini
        enableWebContextSwitch.target = self
        enableWebContextSwitch.action = #selector(webContextToggleClicked(_:))
        let webContextRow = createToggleRow(
            title: "Browser Web Access",
            subtitle: "Allow AI to fetch the content of your active browser tab.",
            switchControl: enableWebContextSwitch)

        enableCalendarSwitch.controlSize = .mini
        enableCalendarSwitch.target = self
        enableCalendarSwitch.action = #selector(calendarToggleClicked(_:))
        let calendarRow = createToggleRow(
            title: "Calendar Events", subtitle: "Allow AI to fetch your upcoming calendar events.",
            switchControl: enableCalendarSwitch)

        enableReminderSwitch.controlSize = .mini
        enableReminderSwitch.target = self
        enableReminderSwitch.action = #selector(reminderToggleClicked(_:))
        let reminderRow = createToggleRow(
            title: "Reminders", subtitle: "Allow AI to fetch your tasks and reminders.",
            switchControl: enableReminderSwitch)

        enableNotesSwitch.controlSize = .mini
        enableNotesSwitch.target = self
        enableNotesSwitch.action = #selector(notesToggleClicked(_:))
        let notesRow = createToggleRow(
            title: "Notes & Local Files",
            subtitle: "Allow AI to read filenames and contents from a specified folder.",
            switchControl: enableNotesSwitch)

        notesPathLabel.font = .systemFont(ofSize: 11)
        notesPathLabel.textColor = .secondaryLabelColor
        notesPathLabel.isEditable = false
        notesPathLabel.isSelectable = true
        notesPathLabel.isBordered = false
        notesPathLabel.drawsBackground = false
        notesPathLabel.lineBreakMode = .byTruncatingMiddle

        let chooseNotesBtn = NSButton(
            title: "Choose Folder...", target: self, action: #selector(chooseNotesFolderClicked(_:))
        )
        chooseNotesBtn.controlSize = .small
        chooseNotesBtn.bezelStyle = .rounded

        let notesPathStack = NSStackView()
        notesPathStack.orientation = .horizontal
        notesPathStack.alignment = .centerY
        notesPathStack.spacing = 8
        notesPathStack.addArrangedSubview(chooseNotesBtn)
        notesPathStack.addArrangedSubview(notesPathLabel)

        let indentedNotesStack = NSStackView()
        indentedNotesStack.orientation = .horizontal
        let indentSpacer = NSView()
        indentSpacer.widthAnchor.constraint(equalToConstant: 24).isActive = true
        indentedNotesStack.addArrangedSubview(indentSpacer)
        indentedNotesStack.addArrangedSubview(notesPathStack)

        contextSection = SettingsSection(
            title: "Context",
            contentViews: [
                pciExplanation, memoryRow, clipboardRow, activeAppRow, webContextRow, calendarRow,
                reminderRow, notesRow, indentedNotesStack,
            ]
        )
        stackView.addArrangedSubview(contextSection)
        contextSection.widthAnchor.constraint(equalTo: stackView.widthAnchor, constant: -48)
            .isActive = true
    }

    private func createToggleRow(title: String, subtitle: String, switchControl: NSSwitch)
        -> NSStackView
    {
        let textStack = NSStackView()
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 2
        textStack.translatesAutoresizingMaskIntoConstraints = false

        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.textColor = .labelColor

        let subtext = NSTextField(labelWithString: subtitle)
        subtext.font = .systemFont(ofSize: 11)
        subtext.textColor = .secondaryLabelColor
        subtext.cell?.wraps = true
        subtext.cell?.isScrollable = false

        textStack.addArrangedSubview(label)
        textStack.addArrangedSubview(subtext)

        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.distribution = .fill
        row.addArrangedSubview(textStack)
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        row.addArrangedSubview(spacer)
        row.addArrangedSubview(switchControl)
        return row
    }

    private func setupConstraints() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        stackView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stackView.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
            stackView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),
        ])
    }

    private func createFormRow(
        label: String, control: NSView, width: CGFloat, labelWidth: CGFloat, subtext: String? = nil
    ) -> NSStackView {
        let rowStack = NSStackView()
        rowStack.orientation = .vertical
        rowStack.alignment = .leading
        rowStack.spacing = 6
        rowStack.translatesAutoresizingMaskIntoConstraints = false

        let labelStack = NSStackView()
        labelStack.orientation = .horizontal
        labelStack.alignment = .centerY
        labelStack.spacing = 16
        labelStack.translatesAutoresizingMaskIntoConstraints = false

        let labelField = NSTextField(labelWithString: label)
        labelField.font = .systemFont(ofSize: 13)
        labelField.textColor = .labelColor
        labelField.translatesAutoresizingMaskIntoConstraints = false
        labelField.widthAnchor.constraint(equalToConstant: labelWidth).isActive = true

        control.translatesAutoresizingMaskIntoConstraints = false
        control.widthAnchor.constraint(equalToConstant: width).isActive = true

        labelStack.addArrangedSubview(labelField)
        labelStack.addArrangedSubview(control)

        rowStack.addArrangedSubview(labelStack)

        if let subtext = subtext {
            let subtextField = NSTextField(labelWithString: subtext)
            subtextField.font = .systemFont(ofSize: 10)
            subtextField.textColor = .secondaryLabelColor
            subtextField.cell?.wraps = true
            subtextField.cell?.isScrollable = false

            let indentSpacer = NSView()
            indentSpacer.translatesAutoresizingMaskIntoConstraints = false
            indentSpacer.widthAnchor.constraint(equalToConstant: labelWidth + 16).isActive = true

            let subtextStack = NSStackView()
            subtextStack.orientation = .horizontal
            subtextStack.alignment = .top
            subtextStack.spacing = 0

            subtextStack.addArrangedSubview(indentSpacer)
            subtextStack.addArrangedSubview(subtextField)

            rowStack.addArrangedSubview(subtextStack)

            subtextField.translatesAutoresizingMaskIntoConstraints = false
            // Allow subtext to wrap nicely
            subtextField.widthAnchor.constraint(equalToConstant: width).isActive = true
        }

        return rowStack
    }

    private func createProviderRow(for provider: AIProvider, isActive: Bool) -> NSView {
        let container = NSStackView()
        container.orientation = .vertical
        container.spacing = 0
        container.translatesAutoresizingMaskIntoConstraints = false

        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 12
        row.alignment = .centerY
        row.edgeInsets = NSEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        row.translatesAutoresizingMaskIntoConstraints = false
        row.heightAnchor.constraint(equalToConstant: 40).isActive = true

        let bgView = NSView()
        bgView.wantsLayer = true
        bgView.layer?.cornerRadius = 8
        if isActive {
            bgView.layer?.backgroundColor =
                NSColor.selectedContentBackgroundColor.withAlphaComponent(0.18).cgColor
            bgView.layer?.borderWidth = 1
            bgView.layer?.borderColor =
                NSColor.selectedContentBackgroundColor.withAlphaComponent(0.35).cgColor
        } else {
            bgView.layer?.backgroundColor = NSColor.clear.cgColor
        }
        bgView.translatesAutoresizingMaskIntoConstraints = false

        let radio = NSButton()
        radio.setButtonType(.radio)
        radio.title = ""
        radio.state = isActive ? .on : .off
        radio.target = self
        radio.action = #selector(providerRadioClicked(_:))
        radio.identifier = NSUserInterfaceItemIdentifier(provider.id)
        row.addArrangedSubview(radio)

        let nameLabel = NSTextField(labelWithString: provider.name)
        nameLabel.font = .systemFont(ofSize: 13, weight: .medium)
        nameLabel.textColor = .labelColor
        row.addArrangedSubview(nameLabel)

        let typeString =
            provider.type == "foundation" ? "Foundation" : "BYOK (\(provider.modelName))"
        let typeLabel = NSTextField(labelWithString: typeString)
        typeLabel.font = .systemFont(ofSize: 11)
        typeLabel.textColor = .secondaryLabelColor
        row.addArrangedSubview(typeLabel)

        row.addArrangedSubview(NSView())  // Spacer

        let editBtn = NSButton(
            image: NSImage(systemSymbolName: "pencil", accessibilityDescription: "Edit")!,
            target: self, action: #selector(editProviderRowClicked(_:))
        )
        editBtn.isBordered = false
        editBtn.bezelStyle = .recessed
        editBtn.controlSize = .mini
        editBtn.identifier = NSUserInterfaceItemIdentifier(provider.id)
        row.addArrangedSubview(editBtn)

        if provider.type != "foundation" {
            let copyBtn = NSButton(
                image: NSImage(
                    systemSymbolName: "doc.on.doc", accessibilityDescription: "Duplicate")!,
                target: self, action: #selector(copyProviderRowClicked(_:))
            )
            copyBtn.isBordered = false
            copyBtn.bezelStyle = .recessed
            copyBtn.controlSize = .mini
            copyBtn.identifier = NSUserInterfaceItemIdentifier(provider.id)
            row.addArrangedSubview(copyBtn)

            let deleteBtn = NSButton(
                image: NSImage(systemSymbolName: "trash", accessibilityDescription: "Delete")!,
                target: self, action: #selector(deleteProviderRowClicked(_:))
            )
            deleteBtn.isBordered = false
            deleteBtn.bezelStyle = .recessed
            deleteBtn.controlSize = .mini
            deleteBtn.identifier = NSUserInterfaceItemIdentifier(provider.id)
            if #available(macOS 10.15, *) {
                deleteBtn.contentTintColor = .systemRed
            }
            row.addArrangedSubview(deleteBtn)
        }

        container.addSubview(bgView)
        container.addArrangedSubview(row)

        NSLayoutConstraint.activate([
            bgView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            bgView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            bgView.topAnchor.constraint(equalTo: container.topAnchor),
            bgView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            row.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            row.topAnchor.constraint(equalTo: container.topAnchor),
            row.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        let clickGesture = NSClickGestureRecognizer(
            target: self, action: #selector(providerRowClicked(_:)))
        container.addGestureRecognizer(clickGesture)
        container.identifier = NSUserInterfaceItemIdentifier(provider.id)

        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        container.addArrangedSubview(separator)

        return container
    }

    private func showProviderSheet(editing provider: AIProvider?, copying: Bool = false) {
        guard let window = self.view.window else { return }

        let isEdit = provider != nil && !copying
        let isFoundation = (provider?.type == "foundation") && !copying

        let alert = NSAlert()
        alert.messageText = isEdit ? "Edit AI Provider" : "Add AI Provider"
        alert.informativeText =
            isEdit
            ? "Update configuration for this provider."
            : "Configure a new AI model provider backend."

        let outerHeight: CGFloat = isFoundation ? 40 : 220
        let outer = NSStackView(frame: NSRect(x: 0, y: 0, width: 440, height: outerHeight))
        outer.orientation = .vertical
        outer.spacing = 10
        outer.alignment = .leading

        func createAlertRow(label: String, control: NSView, width: CGFloat = 260) -> NSStackView {
            let row = NSStackView()
            row.orientation = .horizontal
            row.alignment = .centerY
            row.spacing = 10
            let lbl = NSTextField(labelWithString: label)
            lbl.font = .systemFont(ofSize: 12)
            lbl.textColor = .labelColor
            lbl.translatesAutoresizingMaskIntoConstraints = false
            lbl.widthAnchor.constraint(equalToConstant: 120).isActive = true
            control.translatesAutoresizingMaskIntoConstraints = false
            control.widthAnchor.constraint(equalToConstant: width).isActive = true
            row.addArrangedSubview(lbl)
            row.addArrangedSubview(control)
            row.addArrangedSubview(NSView())  // Spacer
            return row
        }

        let dialogNameField = PasteableTextField()
        dialogNameField.placeholderString = "e.g., OpenRouter Gemini"

        let dialogUrlField = PasteableTextField()
        dialogUrlField.placeholderString = "https://openrouter.ai/api/v1/chat/completions"

        let dialogKeyField = PasteableSecureTextField()
        dialogKeyField.placeholderString = "API Key"

        let dialogModelField = PasteableTextField()
        dialogModelField.placeholderString = "google/gemini-2.5-flash"

        let dialogSearchToolField = PasteableTextField()
        dialogSearchToolField.placeholderString = "e.g. googleSearch or web_search"

        let dialogVisionCheckbox = NSButton()
        dialogVisionCheckbox.setButtonType(.switch)
        dialogVisionCheckbox.title = "Supports multimodal image inputs"
        dialogVisionCheckbox.font = .systemFont(ofSize: 12)

        let nameRow = createAlertRow(label: "Provider Name:", control: dialogNameField)
        outer.addArrangedSubview(nameRow)

        if !isFoundation {
            let urlRow = createAlertRow(label: "API Endpoint URL:", control: dialogUrlField)
            let keyRow = createAlertRow(label: "API Key:", control: dialogKeyField)
            let modelRow = createAlertRow(label: "Model Name:", control: dialogModelField)
            let toolRow = createAlertRow(label: "Search Tool Name:", control: dialogSearchToolField)
            let imgRow = createAlertRow(label: "Vision Support:", control: dialogVisionCheckbox)

            outer.addArrangedSubview(urlRow)
            outer.addArrangedSubview(keyRow)
            outer.addArrangedSubview(modelRow)
            outer.addArrangedSubview(toolRow)
            outer.addArrangedSubview(imgRow)
        }

        var targetProvider: AIProvider? = nil
        var initialName = ""
        var initialUrl = ""
        var initialKey = ""
        var initialModel = ""
        var initialSearchTool = ""
        var initialVision = false

        if let p = provider {
            if copying {
                var uniqueName = "\(p.name) copy"
                var suffix = 2
                while ConfigManager.shared.config.aiConfig.providers.contains(where: {
                    $0.name.lowercased() == uniqueName.lowercased()
                }) {
                    uniqueName = "\(p.name) copy \(suffix)"
                    suffix += 1
                }
                initialName = uniqueName
                initialUrl = p.url
                initialKey = p.apiKey
                initialModel = p.modelName
                initialSearchTool = p.searchToolName ?? ""
                initialVision = p.supportsImages
            } else {
                targetProvider = p
                initialName = p.name
                initialUrl = p.url
                initialKey = p.apiKey
                initialModel = p.modelName
                initialSearchTool = p.searchToolName ?? ""
                initialVision = p.supportsImages
            }
        }

        dialogNameField.stringValue = initialName
        if !isFoundation {
            dialogUrlField.stringValue = initialUrl
            dialogKeyField.stringValue = initialKey
            dialogModelField.stringValue = initialModel
            dialogSearchToolField.stringValue = initialSearchTool
            dialogVisionCheckbox.state = initialVision ? .on : .off
        }

        alert.accessoryView = outer
        alert.addButton(withTitle: isEdit ? "Save" : "Add")
        alert.addButton(withTitle: "Cancel")

        alert.beginSheetModal(for: window) { [weak self] response in
            guard response == .alertFirstButtonReturn else { return }
            let name = dialogNameField.stringValue.trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { return }

            // Uniqueness check: no two providers can have same name
            let nameExists = ConfigManager.shared.config.aiConfig.providers.contains(where: {
                $0.name.lowercased() == name.lowercased() && $0.id != (targetProvider?.id ?? "")
            })
            if nameExists {
                let errorAlert = NSAlert()
                errorAlert.messageText = "Duplicate Provider Name"
                errorAlert.informativeText =
                    "A provider with the name '\(name)' already exists. Please choose a unique name."
                errorAlert.runModal()
                return
            }

            let type = targetProvider?.type ?? "byok"
            let url = dialogUrlField.stringValue.trimmingCharacters(in: .whitespaces)
            let apiKey = dialogKeyField.stringValue.trimmingCharacters(in: .whitespaces)
            let modelName = dialogModelField.stringValue.trimmingCharacters(in: .whitespaces)
            let searchTool = dialogSearchToolField.stringValue.trimmingCharacters(in: .whitespaces)
            let supportsImages = dialogVisionCheckbox.state == .on

            if let p = targetProvider {
                if let idx = ConfigManager.shared.config.aiConfig.providers.firstIndex(where: {
                    $0.id == p.id
                }) {
                    ConfigManager.shared.config.aiConfig.providers[idx].name = name
                    ConfigManager.shared.config.aiConfig.providers[idx].type = type
                    ConfigManager.shared.config.aiConfig.providers[idx].url = url
                    ConfigManager.shared.config.aiConfig.providers[idx].apiKey = apiKey
                    ConfigManager.shared.config.aiConfig.providers[idx].modelName = modelName
                    ConfigManager.shared.config.aiConfig.providers[idx].searchToolName =
                        searchTool.isEmpty ? nil : searchTool
                    ConfigManager.shared.config.aiConfig.providers[idx].supportsImages =
                        supportsImages
                }
            } else {
                let newProvider = AIProvider(
                    id: UUID().uuidString,
                    name: name,
                    type: type,
                    url: url,
                    apiKey: apiKey,
                    modelName: modelName,
                    searchToolName: searchTool.isEmpty ? nil : searchTool,
                    supportsImages: supportsImages
                )
                ConfigManager.shared.config.aiConfig.providers.append(newProvider)
                ConfigManager.shared.config.aiConfig.selectedProviderId = newProvider.id
            }

            ConfigManager.shared.save()
            ConfigManager.shared.reload()
            self?.refreshUI()
        }

        if copying {
            DispatchQueue.main.async {
                alert.window.makeFirstResponder(dialogModelField)
            }
        }
    }

    // MARK: - Actions & Bindings

    @objc private func enableAICheckboxToggled(_ sender: NSSwitch) {
        ConfigManager.shared.config.aiConfig.isEnabled = (sender.state == .on)
        ConfigManager.shared.save()
        ConfigManager.shared.reload()  // Dynamic socket start/stop
        updateVisibility()
    }

    @objc private func enableMemoryCheckboxToggled(_ sender: NSSwitch) {
        ConfigManager.shared.config.aiConfig.isMemoryEnabled = (sender.state == .on)
        ConfigManager.shared.save()
    }

    @objc private func clipboardToggleClicked(_ sender: NSSwitch) {
        ConfigManager.shared.config.aiConfig.isClipboardContextEnabled = (sender.state == .on)
        ConfigManager.shared.save()
    }

    @objc private func activeAppToggleClicked(_ sender: NSSwitch) {
        ConfigManager.shared.config.aiConfig.isActiveAppContextEnabled = (sender.state == .on)
        ConfigManager.shared.save()
    }

    @objc private func webContextToggleClicked(_ sender: NSSwitch) {
        ConfigManager.shared.config.aiConfig.isWebContextEnabled = (sender.state == .on)
        ConfigManager.shared.save()
    }

    @objc private func calendarToggleClicked(_ sender: NSSwitch) {
        ConfigManager.shared.config.aiConfig.isCalendarContextEnabled = (sender.state == .on)
        ConfigManager.shared.save()
    }

    @objc private func reminderToggleClicked(_ sender: NSSwitch) {
        ConfigManager.shared.config.aiConfig.isReminderContextEnabled = (sender.state == .on)
        ConfigManager.shared.save()
    }

    @objc private func notesToggleClicked(_ sender: NSSwitch) {
        ConfigManager.shared.config.aiConfig.isNotesContextEnabled = (sender.state == .on)
        ConfigManager.shared.save()
    }

    @objc private func chooseNotesFolderClicked(_ sender: NSButton) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Choose a folder for your Notes"

        if panel.runModal() == .OK, let url = panel.url {
            ConfigManager.shared.config.aiConfig.notesDirectoryPath = url.path
            ConfigManager.shared.save()
            refreshUI()
        }
    }

    @objc private func providerRadioClicked(_ sender: NSButton) {
        guard let providerId = sender.identifier?.rawValue else { return }
        ConfigManager.shared.config.aiConfig.selectedProviderId = providerId
        ConfigManager.shared.save()
        ConfigManager.shared.reload()
        refreshUI()
    }

    @objc private func providerRowClicked(_ sender: NSClickGestureRecognizer) {
        guard let container = sender.view, let providerId = container.identifier?.rawValue else {
            return
        }
        ConfigManager.shared.config.aiConfig.selectedProviderId = providerId
        ConfigManager.shared.save()
        ConfigManager.shared.reload()
        refreshUI()
    }

    @objc private func editProviderRowClicked(_ sender: NSButton) {
        guard let providerId = sender.identifier?.rawValue else { return }
        if let provider = ConfigManager.shared.config.aiConfig.providers.first(where: {
            $0.id == providerId
        }) {
            showProviderSheet(editing: provider)
        }
    }

    @objc private func copyProviderRowClicked(_ sender: NSButton) {
        guard let providerId = sender.identifier?.rawValue else { return }
        if let provider = ConfigManager.shared.config.aiConfig.providers.first(where: {
            $0.id == providerId
        }) {
            showProviderSheet(editing: provider, copying: true)
        }
    }

    @objc private func addProviderClicked(_ sender: NSButton) {
        showProviderSheet(editing: nil)
    }

    @objc private func deleteProviderRowClicked(_ sender: NSButton) {
        guard let providerId = sender.identifier?.rawValue else { return }
        let providers = ConfigManager.shared.config.aiConfig.providers
        guard let index = providers.firstIndex(where: { $0.id == providerId }) else { return }

        let alert = NSAlert()
        alert.messageText = "Remove AI Provider"
        alert.informativeText = "Are you sure you want to remove '\(providers[index].name)'?"
        alert.addButton(withTitle: "Remove")
        alert.addButton(withTitle: "Cancel")

        guard let window = self.view.window else { return }
        alert.beginSheetModal(for: window) { [weak self] response in
            guard response == .alertFirstButtonReturn else { return }

            ConfigManager.shared.config.aiConfig.providers.remove(at: index)

            // If the deleted provider was active, fall back to another one
            if ConfigManager.shared.config.aiConfig.selectedProviderId == providerId {
                let remaining = ConfigManager.shared.config.aiConfig.providers
                ConfigManager.shared.config.aiConfig.selectedProviderId =
                    remaining.first?.id ?? "foundation-default"
            }

            ConfigManager.shared.save()
            ConfigManager.shared.reload()

            self?.refreshUI()
        }
    }

    // MARK: - UI Update

    @objc private func refreshUI() {
        let config = ConfigManager.shared.config.aiConfig

        enableAISwitch.state = config.isEnabled ? .on : .off
        enableMemorySwitch.state = config.isMemoryEnabled ? .on : .off

        // Rebuild provider rows in stack view
        for subview in providersListStack.arrangedSubviews {
            subview.removeFromSuperview()
        }
        for provider in config.providers {
            let row = createProviderRow(
                for: provider, isActive: provider.id == config.selectedProviderId)
            providersListStack.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: providersListStack.widthAnchor).isActive = true
        }

        enableClipboardSwitch.state = config.isClipboardContextEnabled ? .on : .off
        enableActiveAppSwitch.state = config.isActiveAppContextEnabled ? .on : .off
        enableWebContextSwitch.state = config.isWebContextEnabled ? .on : .off
        enableCalendarSwitch.state = config.isCalendarContextEnabled ? .on : .off
        enableReminderSwitch.state = config.isReminderContextEnabled ? .on : .off
        enableNotesSwitch.state = config.isNotesContextEnabled ? .on : .off
        notesPathLabel.stringValue = config.notesDirectoryPath ?? "No folder selected"

        updateVisibility()
    }

    private func updateVisibility() {
        let isEnabled = ConfigManager.shared.config.aiConfig.isEnabled

        memoryRow.isHidden = !isEnabled
        providersSection.isHidden = !isEnabled
        contextSection.isHidden = !isEnabled

        if isEnabled, let active = ConfigManager.shared.config.aiConfig.activeProvider {
            let isByok = (active.type == "byok")
            warningContainer.isHidden = isByok
        }
    }
}

class PasteableTextField: NSTextField {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command) {
            guard let key = event.charactersIgnoringModifiers?.lowercased() else {
                return super.performKeyEquivalent(with: event)
            }
            switch key {
            case "v":
                if self.currentEditor() != nil {
                    NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: self)
                    return true
                }
            case "c":
                if self.currentEditor() != nil {
                    NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: self)
                    return true
                }
            case "x":
                if self.currentEditor() != nil {
                    NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: self)
                    return true
                }
            case "a":
                if self.currentEditor() != nil {
                    NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: self)
                    return true
                }
            default:
                break
            }
        }
        return super.performKeyEquivalent(with: event)
    }
}

class PasteableSecureTextField: NSSecureTextField {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command) {
            guard let key = event.charactersIgnoringModifiers?.lowercased() else {
                return super.performKeyEquivalent(with: event)
            }
            switch key {
            case "v":
                if self.currentEditor() != nil {
                    NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: self)
                    return true
                }
            case "c":
                if self.currentEditor() != nil {
                    NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: self)
                    return true
                }
            case "x":
                if self.currentEditor() != nil {
                    NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: self)
                    return true
                }
            case "a":
                if self.currentEditor() != nil {
                    NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: self)
                    return true
                }
            default:
                break
            }
        }
        return super.performKeyEquivalent(with: event)
    }
}
