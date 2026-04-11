import Cocoa
import NerwCore
import NerwSearchBackend

class AppearanceSettingsViewController: NSViewController {

    private let stackView: FlippedStackView = {
        let stack = FlippedStackView()
        stack.orientation = .vertical
        stack.alignment = .leading  // Leading alignment
        stack.spacing = 24
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        return stack
    }()

    private var fontLabel: NSTextField!
    private var selectionBGColorWell: NSColorWell?
    private var useSystemSelectionSwitch: NSSwitch!

    private let scrollView: NSScrollView = {
        let sv = NSScrollView()
        sv.hasVerticalScroller = true
        sv.hasHorizontalScroller = false
        sv.autohidesScrollers = true
        sv.drawsBackground = false
        return sv
    }()

    override func loadView() {
        self.view = NSView()
        self.view.wantsLayer = true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
    }

    private func setupUI() {
        view.addSubview(scrollView)
        scrollView.documentView = stackView

        // Font Settings
        let fontRow = NSStackView()
        fontRow.orientation = .horizontal
        fontRow.spacing = 10
        fontRow.alignment = .centerY

        fontLabel = NSTextField(
            labelWithString: ConfigManager.shared.config.uiConfig?.font ?? "System")

        let selectFontBtn = NSButton(
            title: "Select...", target: self, action: #selector(selectFontClicked))

        fontRow.addArrangedSubview(fontLabel)
        fontRow.addArrangedSubview(selectFontBtn)
        fontRow.addArrangedSubview(NSView())  // Spacer

        let fontSection = SettingsSection(
            title: "Typography",
            contentViews: [fontRow]
        )
        stackView.addArrangedSubview(fontSection)
        fontSection.widthAnchor.constraint(equalTo: stackView.widthAnchor, constant: -40).isActive =
            true

        // Color Settings
        // We will collect color settings rows
        var colorRows: [NSView] = []

        // System Selection Color Option
        let systemSelectionRow = NSStackView()
        systemSelectionRow.orientation = .horizontal
        systemSelectionRow.spacing = 10
        systemSelectionRow.alignment = .centerY

        let systemSelectionTextStack = NSStackView()
        systemSelectionTextStack.orientation = .vertical
        systemSelectionTextStack.spacing = 2
        systemSelectionTextStack.alignment = .leading

        let systemSelectionLabel = NSTextField(labelWithString: "Use System Selection Color")
        let systemSelectionSubtitle = NSTextField(
            labelWithString: "Overrides custom selection background with system accent")
        systemSelectionSubtitle.font = .systemFont(ofSize: 11)
        systemSelectionSubtitle.textColor = .secondaryLabelColor

        systemSelectionTextStack.addArrangedSubview(systemSelectionLabel)
        systemSelectionTextStack.addArrangedSubview(systemSelectionSubtitle)

        useSystemSelectionSwitch = NSSwitch()
        useSystemSelectionSwitch.controlSize = .mini
        useSystemSelectionSwitch.target = self
        useSystemSelectionSwitch.action = #selector(useSystemSelectionColorChanged(_:))

        // Set initial state
        let useSystem = ConfigManager.shared.config.uiConfig?.useSystemSelectionColor ?? true
        useSystemSelectionSwitch.state = useSystem ? .on : .off

        // Spacer
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        systemSelectionRow.addArrangedSubview(systemSelectionTextStack)
        systemSelectionRow.addArrangedSubview(spacer)
        systemSelectionRow.addArrangedSubview(useSystemSelectionSwitch)

        colorRows.append(systemSelectionRow)

        // Background
        colorRows.append(
            createColorRow(
                title: "Background", subtitle: "Main window background color",
                hex: ConfigManager.shared.config.uiConfig?.mainBackgroundColor,
                action: #selector(mainBGColorChanged(_:))))

        // Selection Background
        let selectionRow = createColorRow(
            title: "Selection Background",
            subtitle: "Background color of the selected item",
            hex: ConfigManager.shared.config.uiConfig?.selectionBackgroundColor,
            action: #selector(selectionBGColorChanged(_:)))

        // Find the color well in the returned row to keep reference
        // Structure: [TextStack, Spacer, ColorWell]
        if let colorWell = (selectionRow as? NSStackView)?.arrangedSubviews.last as? NSColorWell {
            selectionBGColorWell = colorWell
        }
        selectionBGColorWell?.isEnabled = !useSystem

        colorRows.append(selectionRow)

        // Main Text
        colorRows.append(
            createColorRow(
                title: "Text Color", subtitle: "Primary text color",
                hex: ConfigManager.shared.config.uiConfig?.mainForegroundColor,
                action: #selector(textColorChanged(_:))))

        // Selection Text
        colorRows.append(
            createColorRow(
                title: "Selected Text Color",
                subtitle: "Text color of the selected item",
                hex: ConfigManager.shared.config.uiConfig?.selectionForegroundColor,
                action: #selector(selectedTextColorChanged(_:))))

        let colorSection = SettingsSection(
            title: "Colors",
            contentViews: colorRows
        )
        stackView.addArrangedSubview(colorSection)
        colorSection.widthAnchor.constraint(equalTo: stackView.widthAnchor, constant: -40)
            .isActive = true

        // Layout Settings
        var layoutRows: [NSView] = []

        layoutRows.append(
            createNumberRow(
                title: "Window Width", subtitle: "Main panel and split pane width",
                value: ConfigManager.shared.config.layoutConfig.mainWidth,
                action: #selector(mainWidthChanged(_:))))

        layoutRows.append(
            createNumberRow(
                title: "Window Height", subtitle: "Standard height for split panes",
                value: ConfigManager.shared.config.layoutConfig.mainHeight,
                action: #selector(mainHeightChanged(_:))))

        layoutRows.append(
            createNumberRow(
                title: "Corner Radius", subtitle: "Radius for all primary UI panels",
                value: ConfigManager.shared.config.layoutConfig.cornerRadius,
                action: #selector(cornerRadiusChanged(_:))))

        layoutRows.append(
            createNumberRow(
                title: "Horizontal Margin", subtitle: "Margins for UI elements",
                value: ConfigManager.shared.config.layoutConfig.horizontalMargin,
                action: #selector(horizontalMarginChanged(_:))))

        layoutRows.append(
            createNumberRow(
                title: "Search Font Size", subtitle: "Font size for primary input",
                value: ConfigManager.shared.config.layoutConfig.fontSizeSearch,
                action: #selector(fontSizeSearchChanged(_:))))

        layoutRows.append(
            createNumberRow(
                title: "Result Title Size", subtitle: "Font size for result titles",
                value: ConfigManager.shared.config.layoutConfig.fontSizeResultTitle,
                action: #selector(fontSizeResultTitleChanged(_:))))

        layoutRows.append(
            createNumberRow(
                title: "Icon Size", subtitle: "Primary search icon size",
                value: ConfigManager.shared.config.layoutConfig.iconSizeMain,
                action: #selector(iconSizeMainChanged(_:))))

        let layoutSection = SettingsSection(
            title: "Layout",
            contentViews: layoutRows
        )
        stackView.addArrangedSubview(layoutSection)
        layoutSection.widthAnchor.constraint(equalTo: stackView.widthAnchor, constant: -40)
            .isActive = true
    }

    /// Creates and returns a row view for color settings
    private func createColorRow(
        title: String, subtitle: String, hex: String?, action: Selector
    ) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 10
        row.alignment = .top  // Top alignment for multiline text

        // Text Stack (Title + Subtitle)
        let textStack = NSStackView()
        textStack.orientation = .vertical
        textStack.spacing = 2
        textStack.alignment = .leading

        let label = NSTextField(labelWithString: title)
        let subLabel = NSTextField(labelWithString: subtitle)
        subLabel.font = .systemFont(ofSize: 11)
        subLabel.textColor = .secondaryLabelColor

        textStack.addArrangedSubview(label)
        textStack.addArrangedSubview(subLabel)

        let colorWell = NSColorWell()
        colorWell.translatesAutoresizingMaskIntoConstraints = false
        colorWell.widthAnchor.constraint(equalToConstant: 44).isActive = true
        colorWell.heightAnchor.constraint(equalToConstant: 24).isActive = true
        colorWell.color = NSColor(hexString: hex ?? "#FFFFFF") ?? .white
        colorWell.target = self
        colorWell.action = action

        // Spacer to push color well to right
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        row.addArrangedSubview(textStack)
        row.addArrangedSubview(spacer)
        row.addArrangedSubview(colorWell)

        return row
    }

    /// Creates and returns a row view for numeric settings
    private func createNumberRow(
        title: String, subtitle: String, value: Double, action: Selector
    ) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 10
        row.alignment = .centerY

        // Text Stack (Title + Subtitle)
        let textStack = NSStackView()
        textStack.orientation = .vertical
        textStack.spacing = 2
        textStack.alignment = .leading

        let label = NSTextField(labelWithString: title)
        let subLabel = NSTextField(labelWithString: subtitle)
        subLabel.font = .systemFont(ofSize: 11)
        subLabel.textColor = .secondaryLabelColor

        textStack.addArrangedSubview(label)
        textStack.addArrangedSubview(subLabel)

        let textField = NSTextField()
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.widthAnchor.constraint(equalToConstant: 60).isActive = true
        textField.stringValue = String(format: "%.0f", value)
        textField.target = self
        textField.action = action

        let stepper = NSStepper()
        stepper.minValue = 0
        stepper.maxValue = 2000
        stepper.doubleValue = value
        stepper.valueWraps = false
        stepper.target = self
        stepper.action = action

        // Connect stepper to textfield via tag or similar if needed,
        // but here we just use the same action and sender check

        let controlStack = NSStackView()
        controlStack.orientation = .horizontal
        controlStack.spacing = 4
        controlStack.addArrangedSubview(textField)
        controlStack.addArrangedSubview(stepper)

        // Spacer
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        row.addArrangedSubview(textStack)
        row.addArrangedSubview(spacer)
        row.addArrangedSubview(controlStack)

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

    // MARK: - Actions

    @objc private func selectFontClicked() {
        let fontManager = NSFontManager.shared
        if let currentFontName = ConfigManager.shared.config.uiConfig?.font,
            let font = NSFont(name: currentFontName, size: 13)
        {
            fontManager.setSelectedFont(font, isMultiple: false)
        }
        fontManager.target = self
        fontManager.orderFrontFontPanel(self)
    }

    @objc func changeFont(_ sender: NSFontManager?) {
        guard let validSender = sender else { return }
        // Create a dummy font with current name to convert from
        let oldFontName = ConfigManager.shared.config.uiConfig?.font ?? "System"
        let oldFont = NSFont(name: oldFontName, size: 13) ?? NSFont.systemFont(ofSize: 13)

        let newFont = validSender.convert(oldFont)

        ensureUIConfig()
        ConfigManager.shared.config.uiConfig?.font = newFont.fontName
        ConfigManager.shared.save()

        fontLabel.stringValue = newFont.fontName
    }

    @objc private func mainBGColorChanged(_ sender: NSColorWell) {
        ensureUIConfig()
        ConfigManager.shared.config.uiConfig?.mainBackgroundColor = sender.color.toHexString()
        ConfigManager.shared.save()
    }

    @objc private func selectionBGColorChanged(_ sender: NSColorWell) {
        ensureUIConfig()
        ConfigManager.shared.config.uiConfig?.selectionBackgroundColor = sender.color.toHexString()
        ConfigManager.shared.save()
    }

    @objc private func textColorChanged(_ sender: NSColorWell) {
        ensureUIConfig()
        ConfigManager.shared.config.uiConfig?.mainForegroundColor = sender.color.toHexString()
        ConfigManager.shared.save()
    }

    @objc private func selectedTextColorChanged(_ sender: NSColorWell) {
        ensureUIConfig()
        ConfigManager.shared.config.uiConfig?.selectionForegroundColor = sender.color.toHexString()
        ConfigManager.shared.save()
    }

    @objc private func useSystemSelectionColorChanged(_ sender: NSSwitch) {
        ensureUIConfig()
        let useSystem = sender.state == .on
        ConfigManager.shared.config.uiConfig?.useSystemSelectionColor = useSystem
        ConfigManager.shared.save()

        selectionBGColorWell?.isEnabled = !useSystem
    }

    // MARK: - Layout Actions

    @objc private func mainWidthChanged(_ sender: NSControl) {
        ConfigManager.shared.config.layoutConfig.mainWidth = sender.doubleValue
        syncLayoutControls(sender)
        ConfigManager.shared.save()
    }

    @objc private func mainHeightChanged(_ sender: NSControl) {
        ConfigManager.shared.config.layoutConfig.mainHeight = sender.doubleValue
        syncLayoutControls(sender)
        ConfigManager.shared.save()
    }

    @objc private func cornerRadiusChanged(_ sender: NSControl) {
        ConfigManager.shared.config.layoutConfig.cornerRadius = sender.doubleValue
        syncLayoutControls(sender)
        ConfigManager.shared.save()
    }

    @objc private func horizontalMarginChanged(_ sender: NSControl) {
        ConfigManager.shared.config.layoutConfig.horizontalMargin = sender.doubleValue
        syncLayoutControls(sender)
        ConfigManager.shared.save()
    }

    @objc private func fontSizeSearchChanged(_ sender: NSControl) {
        ConfigManager.shared.config.layoutConfig.fontSizeSearch = sender.doubleValue
        syncLayoutControls(sender)
        ConfigManager.shared.save()
    }

    @objc private func fontSizeResultTitleChanged(_ sender: NSControl) {
        ConfigManager.shared.config.layoutConfig.fontSizeResultTitle = sender.doubleValue
        syncLayoutControls(sender)
        ConfigManager.shared.save()
    }

    @objc private func iconSizeMainChanged(_ sender: NSControl) {
        ConfigManager.shared.config.layoutConfig.iconSizeMain = sender.doubleValue
        syncLayoutControls(sender)
        ConfigManager.shared.save()
    }

    private func syncLayoutControls(_ sender: NSControl) {
        // Sync TextField and Stepper if they are in the same stack
        guard let stack = sender.superview as? NSStackView else { return }
        for view in stack.arrangedSubviews {
            if let control = view as? NSControl, control != sender {
                control.doubleValue = sender.doubleValue
            }
        }
    }

    private func ensureUIConfig() {
        if ConfigManager.shared.config.uiConfig == nil {
            ConfigManager.shared.config.uiConfig = UIConfig()
        }
    }
}
