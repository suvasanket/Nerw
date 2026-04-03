import Cocoa
import NerwCore
import NerwSearchBackend

class HazardTapeView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 16
        layer?.masksToBounds = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        let stripeWidth: CGFloat = 20
        let yellow = NSColor.systemYellow.withAlphaComponent(0.2).cgColor
        let black = NSColor.black.withAlphaComponent(0.3).cgColor

        context.setFillColor(yellow)
        context.fill(bounds)

        context.setFillColor(black)
        let diagonal = bounds.width + bounds.height
        for x in stride(from: -bounds.height, to: diagonal, by: stripeWidth * 2) {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x + stripeWidth, y: 0))
            path.addLine(to: CGPoint(x: x + stripeWidth + bounds.height, y: bounds.height))
            path.addLine(to: CGPoint(x: x + bounds.height, y: bounds.height))
            path.closeSubpath()
            context.addPath(path)
            context.fillPath()
        }
    }
}

class ExtensionCardView: NSView {

    var onUninstall: (() -> Void)?
    private var manifest: ExtensionManifest?

    private let containerView: NSView = {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.cornerRadius = 16
        view.layer?.backgroundColor = NSColor.quaternaryLabelColor.cgColor
        return view
    }()

    private let mainContentStack: NSStackView = {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        return stack
    }()

    private let headerStack: NSStackView = {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 16
        return stack
    }()

    private let settingsStack: NSStackView = {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.isHidden = true
        return stack
    }()

    private var hazardBackground: HazardTapeView?

    private let iconImageView: NSImageView = {
        let iv = NSImageView()
        iv.imageScaling = .scaleProportionallyUpOrDown
        return iv
    }()

    private let nameLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        label.textColor = .labelColor
        return label
    }()

    private let descLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.font = .systemFont(ofSize: 13)
        label.textColor = .secondaryLabelColor
        label.maximumNumberOfLines = 2
        label.cell?.truncatesLastVisibleLine = true
        label.lineBreakMode = .byWordWrapping
        return label
    }()

    // Trash icon button
    private lazy var uninstallButton: NSButton = {
        let button = NSButton()
        button.bezelStyle = .inline
        button.image = NSImage(systemSymbolName: "trash", accessibilityDescription: "Uninstall")
        button.contentTintColor = .secondaryLabelColor
        button.target = self
        button.action = #selector(uninstallClicked)
        button.isBordered = false
        button.toolTip = "Uninstall Extension"
        return button
    }()

    // Settings icon button
    private lazy var settingsButton: NSButton = {
        let button = NSButton()
        button.bezelStyle = .inline
        button.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: "Settings")
        button.contentTintColor = .secondaryLabelColor
        button.target = self
        button.action = #selector(settingsClicked)
        button.isBordered = false
        button.toolTip = "Extension Settings"
        return button
    }()

    init(extensionManifest: ExtensionManifest) {
        super.init(frame: .zero)
        self.manifest = extensionManifest
        setupUI()
        configure(with: extensionManifest)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        addSubview(containerView)
        containerView.translatesAutoresizingMaskIntoConstraints = false

        let hazard = HazardTapeView()
        hazard.isHidden = true
        containerView.addSubview(hazard)
        hazard.translatesAutoresizingMaskIntoConstraints = false
        self.hazardBackground = hazard

        containerView.addSubview(mainContentStack)
        mainContentStack.translatesAutoresizingMaskIntoConstraints = false

        // Header
        let labelStack = NSStackView()
        labelStack.orientation = .vertical
        labelStack.alignment = .leading
        labelStack.spacing = 4
        labelStack.addArrangedSubview(nameLabel)
        labelStack.addArrangedSubview(descLabel)

        headerStack.addArrangedSubview(iconImageView)
        headerStack.addArrangedSubview(labelStack)
        headerStack.addArrangedSubview(NSView())  // Spacer
        headerStack.addArrangedSubview(settingsButton)
        headerStack.addArrangedSubview(uninstallButton)

        mainContentStack.addArrangedSubview(headerStack)
        mainContentStack.addArrangedSubview(settingsStack)

        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),

            hazard.topAnchor.constraint(equalTo: containerView.topAnchor),
            hazard.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            hazard.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            hazard.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),

            mainContentStack.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            mainContentStack.leadingAnchor.constraint(
                equalTo: containerView.leadingAnchor, constant: 16),
            mainContentStack.trailingAnchor.constraint(
                equalTo: containerView.trailingAnchor, constant: -16),
            mainContentStack.bottomAnchor.constraint(
                equalTo: containerView.bottomAnchor, constant: -16),

            iconImageView.widthAnchor.constraint(equalToConstant: 40),
            iconImageView.heightAnchor.constraint(equalToConstant: 40),

            settingsButton.widthAnchor.constraint(equalToConstant: 24),
            settingsButton.heightAnchor.constraint(equalToConstant: 24),

            uninstallButton.widthAnchor.constraint(equalToConstant: 24),
            uninstallButton.heightAnchor.constraint(equalToConstant: 24),

            headerStack.widthAnchor.constraint(equalTo: mainContentStack.widthAnchor),
            settingsStack.widthAnchor.constraint(equalTo: mainContentStack.widthAnchor),
        ])
    }

    private func configure(with manifest: ExtensionManifest) {
        nameLabel.stringValue = manifest.name
        descLabel.stringValue = manifest.description

        if manifest.isSmokeTest {
            hazardBackground?.isHidden = false
            containerView.layer?.backgroundColor = NSColor.clear.cgColor
        } else {
            hazardBackground?.isHidden = true
            containerView.layer?.backgroundColor = NSColor.quaternaryLabelColor.cgColor
        }

        if let iconName = manifest.icon {
            iconImageView.image = NSImage(systemSymbolName: iconName, accessibilityDescription: nil)
        } else {
            iconImageView.image = NSImage(
                systemSymbolName: "puzzlepiece.extension", accessibilityDescription: nil)
        }

        settingsButton.isHidden = (manifest.settings?.isEmpty ?? true)

        if let settings = manifest.settings {
            setupSettingsUI(settings: settings)
        }
    }

    private func setupSettingsUI(settings: [ExtensionSetting]) {
        for subview in settingsStack.arrangedSubviews {
            subview.removeFromSuperview()
        }

        let separator = NSView()
        separator.wantsLayer = true
        separator.layer?.backgroundColor = NSColor.separatorColor.cgColor
        separator.translatesAutoresizingMaskIntoConstraints = false
        settingsStack.addArrangedSubview(separator)
        NSLayoutConstraint.activate([
            separator.heightAnchor.constraint(equalToConstant: 1),
            separator.widthAnchor.constraint(equalTo: settingsStack.widthAnchor),
        ])

        let cacheKey = "ext_settings_\(manifest?.id ?? "")"
        let savedSettings: [String: AnyCodable] =
            CacheManager.shared.get(forKey: cacheKey, as: [String: AnyCodable].self) ?? [:]

        for setting in settings {
            let settingView = createSettingView(
                for: setting, currentValue: savedSettings[setting.id])
            settingsStack.addArrangedSubview(settingView)
        }
    }

    private func createSettingView(for setting: ExtensionSetting, currentValue: Any?) -> NSView {
        let container = NSStackView()
        container.orientation = .horizontal
        container.alignment = .centerY
        container.spacing = 12

        let labelStack = NSStackView()
        labelStack.orientation = .vertical
        labelStack.alignment = .leading
        labelStack.spacing = 2

        let title = NSTextField(labelWithString: setting.title)
        title.font = .systemFont(ofSize: 13, weight: .medium)
        labelStack.addArrangedSubview(title)

        if let desc = setting.description {
            let subtitle = NSTextField(labelWithString: desc)
            subtitle.font = .systemFont(ofSize: 11)
            subtitle.textColor = .secondaryLabelColor
            labelStack.addArrangedSubview(subtitle)
        }

        container.addArrangedSubview(labelStack)
        container.addArrangedSubview(NSView())  // Spacer

        switch setting.type {
        case .string:
            let textField = NSTextField()
            textField.stringValue =
                (currentValue as? String) ?? (setting.defaultValue.value as? String) ?? ""
            textField.isBordered = true
            textField.bezelStyle = .roundedBezel
            textField.translatesAutoresizingMaskIntoConstraints = false
            textField.widthAnchor.constraint(equalToConstant: 150).isActive = true
            textField.target = self
            textField.action = #selector(settingChanged(_:))
            textField.identifier = NSUserInterfaceItemIdentifier(setting.id)
            container.addArrangedSubview(textField)

        case .boolean:
            let toggle = NSButton(
                checkboxWithTitle: "", target: self, action: #selector(settingChanged(_:)))
            toggle.state =
                ((currentValue as? Bool) ?? (setting.defaultValue.value as? Bool) ?? false)
                ? .on : .off
            toggle.identifier = NSUserInterfaceItemIdentifier(setting.id)
            container.addArrangedSubview(toggle)

        case .number:
            let textField = NSTextField()
            if let val = currentValue as? Double {
                textField.doubleValue = val
            } else if let val = currentValue as? Int {
                textField.integerValue = val
            } else {
                textField.doubleValue = (setting.defaultValue.value as? Double) ?? 0.0
            }
            textField.isBordered = true
            textField.bezelStyle = .roundedBezel
            textField.translatesAutoresizingMaskIntoConstraints = false
            textField.widthAnchor.constraint(equalToConstant: 80).isActive = true
            textField.target = self
            textField.action = #selector(settingChanged(_:))
            textField.identifier = NSUserInterfaceItemIdentifier(setting.id)
            container.addArrangedSubview(textField)
        }

        return container
    }

    @objc private func settingChanged(_ sender: NSView) {
        guard let id = sender.identifier?.rawValue, let manifest = manifest else { return }
        let cacheKey = "ext_settings_\(manifest.id)"
        var savedSettings: [String: AnyCodable] =
            CacheManager.shared.get(forKey: cacheKey, as: [String: AnyCodable].self) ?? [:]

        if let textField = sender as? NSTextField {
            // Check if it should be a number
            if let setting = manifest.settings?.first(where: { $0.id == id }),
                setting.type == .number
            {
                savedSettings[id] = AnyCodable(textField.doubleValue)
            } else {
                savedSettings[id] = AnyCodable(textField.stringValue)
            }
        } else if let toggle = sender as? NSButton {
            savedSettings[id] = AnyCodable(toggle.state == .on)
        }

        CacheManager.shared.set(savedSettings, forKey: cacheKey)
    }

    @objc private func settingsClicked() {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.allowsImplicitAnimation = true
            settingsStack.isHidden.toggle()
            self.window?.layoutIfNeeded()
        }
    }

    @objc private func uninstallClicked() {
        onUninstall?()
    }
}
