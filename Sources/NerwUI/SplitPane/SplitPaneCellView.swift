import Cocoa
import NerwCore

class SplitPaneCellView: NSTableCellView {
    private let rightIconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let containerView = NSView()

    private var titleTrailingToContainerConstraint: NSLayoutConstraint!
    private var titleTrailingToRightIconConstraint: NSLayoutConstraint!

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }

    private func setupViews() {
        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = GlobalLayout.cornerRadius * 0.75
        containerView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(containerView)

        titleLabel.font = .systemFont(ofSize: GlobalLayout.fontSizeSplitPaneItem, weight: .bold)
        titleLabel.textColor = .labelColor
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.lineBreakMode = .byTruncatingTail
        containerView.addSubview(titleLabel)

        rightIconView.translatesAutoresizingMaskIntoConstraints = false
        rightIconView.imageScaling = .scaleProportionallyUpOrDown
        containerView.addSubview(rightIconView)

        titleTrailingToContainerConstraint = titleLabel.trailingAnchor.constraint(
            lessThanOrEqualTo: containerView.trailingAnchor, constant: -12)
        titleTrailingToRightIconConstraint = titleLabel.trailingAnchor.constraint(
            lessThanOrEqualTo: rightIconView.leadingAnchor, constant: -8)

        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: topAnchor, constant: 2),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -2),

            titleLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            titleTrailingToContainerConstraint,

            rightIconView.trailingAnchor.constraint(
                equalTo: containerView.trailingAnchor, constant: -12),
            rightIconView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            rightIconView.widthAnchor.constraint(equalToConstant: 16),
            rightIconView.heightAnchor.constraint(equalToConstant: 16),
        ])
    }

    func configure(with item: SplitPaneItem, isSelected: Bool, isExplicitNavigation: Bool = false) {
        titleLabel.stringValue = item.title

        let config = ConfigManager.shared.config.uiConfig
        let selectedTextColor = NSColor(hex: config?.selectionForegroundColor ?? "") ?? .white
        let mainTextColor = NSColor(hex: config?.mainForegroundColor ?? "") ?? .labelColor

        // Only the selected item gets the background highlight
        let useSystemSelection = config?.useSystemSelectionColor ?? true
        let activeBg: NSColor

        if useSystemSelection {
            activeBg = NSColor.controlAccentColor.withAlphaComponent(0.65)
        } else {
            activeBg =
                NSColor(hex: config?.selectionBackgroundColor ?? "")?.withAlphaComponent(0.60)
                ?? NSColor.controlAccentColor.withAlphaComponent(0.60)
        }

        // Make unselected text/icon translucent
        titleLabel.textColor =
            isSelected ? selectedTextColor : mainTextColor.withAlphaComponent(0.55)
        rightIconView.contentTintColor =
            isSelected ? selectedTextColor : mainTextColor.withAlphaComponent(0.4)

        // Show image icon to the right if the item is an image, or 3 dots if selected
        if isSelected {
            rightIconView.image = ResultCellView.makeVerticalEllipsisImage()
            rightIconView.isHidden = false
            titleTrailingToContainerConstraint.isActive = false
            titleTrailingToRightIconConstraint.isActive = true
        } else {
            let isImage = item.previewImagePath != nil
            if isImage {
                rightIconView.image = NSImage(
                    systemSymbolName: "photo", accessibilityDescription: nil)
                rightIconView.isHidden = false
                titleTrailingToContainerConstraint.isActive = false
                titleTrailingToRightIconConstraint.isActive = true
            } else {
                rightIconView.image = nil
                rightIconView.isHidden = true
                titleTrailingToRightIconConstraint.isActive = false
                titleTrailingToContainerConstraint.isActive = true
            }
        }

        let passiveBg = NSColor.white.withAlphaComponent(0.08)
        let finalBgColor = isExplicitNavigation ? activeBg : passiveBg

        if isSelected {
            containerView.layer?.backgroundColor = finalBgColor.cgColor
            containerView.layer?.borderColor = NSColor.white.withAlphaComponent(0.12).cgColor
            containerView.layer?.borderWidth = 0.5
        } else {
            containerView.layer?.backgroundColor = NSColor.clear.cgColor
            containerView.layer?.borderColor = NSColor.clear.cgColor
            containerView.layer?.borderWidth = 0
        }
    }
}
