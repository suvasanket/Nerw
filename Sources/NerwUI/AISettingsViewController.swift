import Cocoa
import NerwCore
import NerwSearchBackend
import NerwUtils

class AISettingsViewController: NSViewController, NSTextFieldDelegate {

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
    private let enableAICheckbox = NSButton()
    private let modelTypePopUp = NSPopUpButton()
    private let modelTypeRow = NSStackView()
    private let warningContainer = NSView()
    private let warningLabel = NSTextField()

    // BYOK configuration UI elements
    private let apiUrlField = NSTextField()
    private let apiKeyField = NSSecureTextField()
    private let modelNameField = NSTextField()
    private let supportsImagesCheckbox = NSButton()
    private let systemPromptField = NSTextField()
    private let temperatureField = NSTextField()
    private let maxTokensField = NSTextField()

    // Sections for dynamic show/hide
    private var activationSection: SettingsSection!
    private var byokSection: SettingsSection!

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

        // --- 1. AI Activation & Backend ---
        enableAICheckbox.setButtonType(.switch)
        enableAICheckbox.title = "Enable AI Assistant Subsystem"
        enableAICheckbox.font = .systemFont(ofSize: 13, weight: .medium)
        enableAICheckbox.target = self
        enableAICheckbox.action = #selector(enableAICheckboxToggled(_:))
        enableAICheckbox.translatesAutoresizingMaskIntoConstraints = false

        let enableRow = NSStackView()
        enableRow.orientation = .horizontal
        enableRow.alignment = .centerY
        enableRow.addArrangedSubview(enableAICheckbox)
        enableRow.addArrangedSubview(NSView())  // Spacer

        // Model Type Selector
        modelTypePopUp.pullsDown = false
        modelTypePopUp.bezelStyle = .rounded
        modelTypePopUp.controlSize = .regular
        modelTypePopUp.translatesAutoresizingMaskIntoConstraints = false

        let types = [
            ("Foundation (Apple Intelligence On-Device)", "foundation"),
            ("BYOK (Bring Your Own Key / Custom API)", "byok"),
        ]
        for (title, val) in types {
            let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            item.representedObject = val
            modelTypePopUp.menu?.addItem(item)
        }
        modelTypePopUp.target = self
        modelTypePopUp.action = #selector(modelTypeChanged(_:))

        let modelTypeLabel = NSTextField(labelWithString: "Model Backend:")
        modelTypeLabel.font = .systemFont(ofSize: 13)
        modelTypeLabel.textColor = .labelColor
        modelTypeLabel.translatesAutoresizingMaskIntoConstraints = false
        modelTypeLabel.widthAnchor.constraint(equalToConstant: 120).isActive = true

        modelTypeRow.orientation = .horizontal
        modelTypeRow.alignment = .centerY
        modelTypeRow.spacing = 10
        modelTypeRow.translatesAutoresizingMaskIntoConstraints = false
        modelTypeRow.addArrangedSubview(modelTypeLabel)
        modelTypeRow.addArrangedSubview(modelTypePopUp)
        modelTypeRow.addArrangedSubview(NSView())  // Spacer

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
            title: "AI Activation & Backend",
            contentViews: [enableRow, modelTypeRow, warningContainer]
        )
        stackView.addArrangedSubview(activationSection)
        activationSection.widthAnchor.constraint(equalTo: stackView.widthAnchor, constant: -48)
            .isActive = true

        // --- 2. BYOK Config Form ---
        setupBYOKFormFields()

        let byokLabelWidth: CGFloat = 120
        let byokControlWidth: CGFloat = 320

        let urlRow = createFormRow(
            label: "API Endpoint URL:", control: apiUrlField, width: byokControlWidth,
            labelWidth: byokLabelWidth,
            subtext:
                "e.g., https://openrouter.ai/api/v1/chat/completions or http://localhost:11434/v1/chat/completions"
        )
        let keyRow = createFormRow(
            label: "API Key:", control: apiKeyField, width: byokControlWidth,
            labelWidth: byokLabelWidth,
            subtext:
                "Required for commercial APIs (OpenRouter, OpenAI). Keep empty for local Ollama.")
        let modelRow = createFormRow(
            label: "Model Name:", control: modelNameField, width: byokControlWidth,
            labelWidth: byokLabelWidth,
            subtext: "e.g., google/gemini-2.5-flash (OpenRouter) or llama3.1 (Ollama)")

        supportsImagesCheckbox.setButtonType(.switch)
        supportsImagesCheckbox.title = "Model supports multimodal image inputs"
        supportsImagesCheckbox.font = .systemFont(ofSize: 12)
        supportsImagesCheckbox.target = self
        supportsImagesCheckbox.action = #selector(supportsImagesToggled(_:))
        let imgRow = createFormRow(
            label: "Vision Support:", control: supportsImagesCheckbox, width: byokControlWidth,
            labelWidth: byokLabelWidth)

        let promptRow = createFormRow(
            label: "System Prompt:", control: systemPromptField, width: byokControlWidth,
            labelWidth: byokLabelWidth, subtext: "Global instructions injected into chat context.")
        let tempRow = createFormRow(
            label: "Temperature:", control: temperatureField, width: 80, labelWidth: byokLabelWidth,
            subtext: "Controls creativity (0.0 = deterministic, 1.0 = highly creative)")
        let tokensRow = createFormRow(
            label: "Max Output Tokens:", control: maxTokensField, width: 80,
            labelWidth: byokLabelWidth, subtext: "Upper limit of generated tokens (0 = no limit)")

        byokSection = SettingsSection(
            title: "Custom BYOK / API Provider Configuration",
            contentViews: [urlRow, keyRow, modelRow, imgRow, promptRow, tempRow, tokensRow]
        )
        stackView.addArrangedSubview(byokSection)
        byokSection.widthAnchor.constraint(equalTo: stackView.widthAnchor, constant: -48).isActive =
            true
    }

    private func setupBYOKFormFields() {
        apiUrlField.delegate = self
        apiKeyField.delegate = self
        modelNameField.delegate = self
        systemPromptField.delegate = self
        temperatureField.delegate = self
        maxTokensField.delegate = self

        apiUrlField.bezelStyle = .roundedBezel
        apiKeyField.bezelStyle = .roundedBezel
        modelNameField.bezelStyle = .roundedBezel
        systemPromptField.bezelStyle = .roundedBezel
        temperatureField.bezelStyle = .roundedBezel
        maxTokensField.bezelStyle = .roundedBezel

        apiUrlField.controlSize = .regular
        apiKeyField.controlSize = .regular
        modelNameField.controlSize = .regular
        systemPromptField.controlSize = .regular
        temperatureField.controlSize = .regular
        maxTokensField.controlSize = .regular
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

    // MARK: - Actions & Bindings

    @objc private func enableAICheckboxToggled(_ sender: NSButton) {
        ConfigManager.shared.config.aiConfig.isEnabled = (sender.state == .on)
        ConfigManager.shared.save()
        ConfigManager.shared.reload()  // Dynamic socket start/stop
        updateVisibility()
    }

    @objc private func modelTypeChanged(_ sender: NSPopUpButton) {
        guard let selectedItem = sender.selectedItem,
            let type = selectedItem.representedObject as? String
        else { return }

        ConfigManager.shared.config.aiConfig.selectedModelType = type
        ConfigManager.shared.save()
        updateVisibility()
    }

    @objc private func supportsImagesToggled(_ sender: NSButton) {
        ConfigManager.shared.config.aiConfig.supportsImages = (sender.state == .on)
        ConfigManager.shared.save()
    }

    // MARK: - NSTextFieldDelegate

    func controlTextDidChange(_ obj: Notification) {
        guard let textField = obj.object as? NSTextField else { return }

        var config = ConfigManager.shared.config.aiConfig
        if textField == apiUrlField {
            config.byokApiUrl = textField.stringValue.trimmingCharacters(in: .whitespaces)
        } else if textField == apiKeyField {
            config.byokApiKey = textField.stringValue.trimmingCharacters(in: .whitespaces)
        } else if textField == modelNameField {
            config.byokModelName = textField.stringValue.trimmingCharacters(in: .whitespaces)
        } else if textField == systemPromptField {
            config.systemPrompt = textField.stringValue
        } else if textField == temperatureField {
            if let val = Double(textField.stringValue) {
                config.temperature = val
            }
        } else if textField == maxTokensField {
            if let val = Int(textField.stringValue) {
                config.maxTokens = val
            }
        }

        ConfigManager.shared.config.aiConfig = config
        ConfigManager.shared.save()
    }

    // MARK: - UI Update

    @objc private func refreshUI() {
        let config = ConfigManager.shared.config.aiConfig

        enableAICheckbox.state = config.isEnabled ? .on : .off

        if let idx = modelTypePopUp.menu?.items.firstIndex(where: {
            ($0.representedObject as? String) == config.selectedModelType
        }) {
            modelTypePopUp.selectItem(at: idx)
        }

        // BYOK fields
        apiUrlField.stringValue = config.byokApiUrl
        apiKeyField.stringValue = config.byokApiKey
        modelNameField.stringValue = config.byokModelName
        supportsImagesCheckbox.state = config.supportsImages ? .on : .off
        systemPromptField.stringValue = config.systemPrompt
        temperatureField.stringValue = String(config.temperature)
        maxTokensField.stringValue = String(config.maxTokens)

        updateVisibility()
    }

    private func updateVisibility() {
        let isEnabled = ConfigManager.shared.config.aiConfig.isEnabled
        let modelType = ConfigManager.shared.config.aiConfig.selectedModelType

        modelTypeRow.isHidden = !isEnabled
        warningContainer.isHidden = !isEnabled || (modelType != "foundation")
        byokSection.isHidden = !isEnabled || (modelType != "byok")
    }
}
