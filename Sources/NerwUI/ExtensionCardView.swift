import Cocoa
import NerwCore

class ExtensionCardView: NSView {

    var onUninstall: (() -> Void)?

    private let containerView: NSView = {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.cornerRadius = 16
        view.layer?.backgroundColor = NSColor.quaternaryLabelColor.cgColor
        return view
    }()

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

    init(extensionManifest: ExtensionManifest) {
        super.init(frame: .zero)
        setupUI()
        configure(with: extensionManifest)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        addSubview(containerView)
        containerView.translatesAutoresizingMaskIntoConstraints = false

        containerView.addSubview(iconImageView)
        containerView.addSubview(nameLabel)
        containerView.addSubview(descLabel)
        containerView.addSubview(uninstallButton)

        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        descLabel.translatesAutoresizingMaskIntoConstraints = false
        uninstallButton.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            // Container fills the view
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),

            // Icon: 40x40, left padded
            iconImageView.leadingAnchor.constraint(
                equalTo: containerView.leadingAnchor, constant: 16),
            iconImageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 40),
            iconImageView.heightAnchor.constraint(equalToConstant: 40),

            // Uninstall Button: Far right, centered vertically
            uninstallButton.trailingAnchor.constraint(
                equalTo: containerView.trailingAnchor, constant: -16),
            uninstallButton.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            uninstallButton.widthAnchor.constraint(equalToConstant: 32),
            uninstallButton.heightAnchor.constraint(equalToConstant: 32),

            // Labels: Between Icon and Button
            nameLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 16),
            nameLabel.trailingAnchor.constraint(
                equalTo: uninstallButton.leadingAnchor, constant: -16),
            nameLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),

            descLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            descLabel.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),
            descLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
            descLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16),
        ])
    }

    private func configure(with manifest: ExtensionManifest) {
        nameLabel.stringValue = manifest.name
        descLabel.stringValue = manifest.description

        if let iconName = manifest.icon {
            iconImageView.image = NSImage(systemSymbolName: iconName, accessibilityDescription: nil)
        } else {
            iconImageView.image = NSImage(
                systemSymbolName: "puzzlepiece.extension", accessibilityDescription: nil)
        }
    }

    @objc private func uninstallClicked() {
        onUninstall?()
    }
}
