import Cocoa

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
        containerView.layer?.cornerRadius = 8
        containerView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(containerView)

        titleLabel.font = .systemFont(ofSize: GlobalLayout.fontSizeSplitPaneItem, weight: .medium)
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

    func configure(with item: SplitPaneItem, isSelected: Bool) {
        titleLabel.stringValue = item.title

        let selectedTextColor = NSColor.white
        let mainTextColor = NSColor.labelColor

        // Only the selected item gets the background highlight
        let activeBg = NSColor.controlAccentColor.withAlphaComponent(0.8)

        // Make unselected text/icon translucent
        titleLabel.textColor =
            isSelected ? selectedTextColor : mainTextColor.withAlphaComponent(0.55)
        rightIconView.contentTintColor =
            isSelected ? selectedTextColor : mainTextColor.withAlphaComponent(0.4)

        // Show image icon to the right if the item is an image
        let isImage = item.previewImagePath != nil
        if isImage {
            rightIconView.image = NSImage(systemSymbolName: "photo", accessibilityDescription: nil)
            rightIconView.isHidden = false
            titleTrailingToContainerConstraint.isActive = false
            titleTrailingToRightIconConstraint.isActive = true
        } else {
            rightIconView.image = nil
            rightIconView.isHidden = true
            titleTrailingToRightIconConstraint.isActive = false
            titleTrailingToContainerConstraint.isActive = true
        }

        if isSelected {
            containerView.layer?.backgroundColor = activeBg.cgColor
            containerView.layer?.borderColor = NSColor.white.withAlphaComponent(0.2).cgColor
            containerView.layer?.borderWidth = 0.5
        } else {
            containerView.layer?.backgroundColor = NSColor.clear.cgColor
            containerView.layer?.borderColor = NSColor.clear.cgColor
            containerView.layer?.borderWidth = 0
        }
    }
}
