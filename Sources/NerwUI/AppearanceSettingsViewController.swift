import Cocoa
import NerwSearchBackend

class AppearanceSettingsViewController: NSViewController {

    private let stackView: NSStackView = {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 20
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 40)
        return stack
    }()

    private var fontLabel: NSTextField!
    private var selectionBGColorWell: NSColorWell?
    private var useSystemSelectionSwitch: NSSwitch!

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
        view.addSubview(stackView)

        // Font Settings
        let fontSection = createSection(title: "Typography")

        let fontRow = NSStackView()
        fontRow.orientation = .horizontal
        fontRow.spacing = 10

        fontLabel = NSTextField(
            labelWithString: ConfigManager.shared.config.uiConfig?.font ?? "System")

        let selectFontBtn = NSButton(
            title: "Select...", target: self, action: #selector(selectFontClicked))

        fontRow.addArrangedSubview(fontLabel)
        fontRow.addArrangedSubview(selectFontBtn)

        fontSection.addArrangedSubview(fontRow)
        stackView.addArrangedSubview(fontSection)

        addSeparator()

        // Color Settings
        let colorSection = createSection(title: "Colors")

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
        let useSystem = ConfigManager.shared.config.uiConfig?.useSystemSelectionColor ?? false
        useSystemSelectionSwitch.state = useSystem ? .on : .off

        // Spacer
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        systemSelectionRow.addArrangedSubview(systemSelectionTextStack)
        systemSelectionRow.addArrangedSubview(spacer)
        systemSelectionRow.addArrangedSubview(useSystemSelectionSwitch)

        // Constrain width to align with other rows (standardize width if needed, or rely on stack alignment)
        // Ensure the row takes full width available in stackView (minus insets)
        // The stackView width isn't fixed yet, but let's just add it.
        colorSection.addArrangedSubview(systemSelectionRow)
        systemSelectionRow.widthAnchor.constraint(equalTo: colorSection.widthAnchor).isActive = true

        // Background
        addColorRow(
            to: colorSection, title: "Background", subtitle: "Main window background color",
            hex: ConfigManager.shared.config.uiConfig?.mainBackgroundColor,
            action: #selector(mainBGColorChanged(_:)))

        // Selection Background
        selectionBGColorWell = addColorRow(
            to: colorSection, title: "Selection Background",
            subtitle: "Background color of the selected item",
            hex: ConfigManager.shared.config.uiConfig?.selectionBackgroundColor,
            action: #selector(selectionBGColorChanged(_:)))

        // Initial enabled state
        selectionBGColorWell?.isEnabled = !useSystem

        // Main Text
        addColorRow(
            to: colorSection, title: "Text Color", subtitle: "Primary text color",
            hex: ConfigManager.shared.config.uiConfig?.mainForegroundColor,
            action: #selector(textColorChanged(_:)))

        // Selection Text
        addColorRow(
            to: colorSection, title: "Selected Text Color",
            subtitle: "Text color of the selected item",
            hex: ConfigManager.shared.config.uiConfig?.selectionForegroundColor,
            action: #selector(selectedTextColorChanged(_:)))

        stackView.addArrangedSubview(colorSection)
    }

    @discardableResult
    private func addColorRow(
        to stack: NSStackView, title: String, subtitle: String, hex: String?, action: Selector
    ) -> NSColorWell {
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

        stack.addArrangedSubview(row)
        // Ensure row width matches parent
        row.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        return colorWell
    }

    private func setupConstraints() {
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: view.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stackView.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor),
        ])
    }

    private func createSection(title: String) -> NSStackView {
        let sectionStack = NSStackView()
        sectionStack.orientation = .vertical
        sectionStack.alignment = .leading
        sectionStack.spacing = 10

        let label = NSTextField(labelWithString: title)
        label.font = NSFont.boldSystemFont(ofSize: 13)

        sectionStack.addArrangedSubview(label)
        return sectionStack
    }

    private func addSeparator() {
        let separator = NSBox()
        separator.boxType = .separator
        stackView.addArrangedSubview(separator)
        separator.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
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

    private func ensureUIConfig() {
        if ConfigManager.shared.config.uiConfig == nil {
            ConfigManager.shared.config.uiConfig = UIConfig()
        }
    }
}

// Minimal Hex Extensions for this file if not already globally available,
// checking if I need to rely on NerwSearchBackend extensions or define here.
// Assuming NerwSearchBackend has extensions, but usually NSColor extensions are in UI.
// I'll check strictness. If they don't exist, I'll add a helper extension to NerwUI locally or use existing utils.
// Checking `Extension` in backend.
