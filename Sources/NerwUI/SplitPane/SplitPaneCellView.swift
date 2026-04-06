import Cocoa

class SplitPaneCellView: NSTableCellView {
    private let iconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let containerView = NSView()

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

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.imageScaling = .scaleProportionallyUpOrDown
        containerView.addSubview(iconView)

        titleLabel.font = .systemFont(ofSize: 13, weight: .medium)
        titleLabel.textColor = .labelColor
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.lineBreakMode = .byTruncatingTail
        containerView.addSubview(titleLabel)

        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: topAnchor, constant: 2),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -2),

            iconView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
            iconView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),

            titleLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(
                lessThanOrEqualTo: containerView.trailingAnchor, constant: -8),
        ])
    }

    func configure(with item: SplitPaneItem, isSelected: Bool) {
        titleLabel.stringValue = item.title

        iconView.image = item.iconImage

        let selectedTextColor = NSColor.white
        let mainTextColor = NSColor.labelColor

        // System accent or subtle grey
        let activeBg = NSColor.controlAccentColor.withAlphaComponent(0.8)

        titleLabel.textColor = isSelected ? selectedTextColor : mainTextColor
        iconView.contentTintColor = isSelected ? selectedTextColor : mainTextColor

        if isSelected {
            containerView.layer?.backgroundColor = activeBg.cgColor
            containerView.layer?.borderColor = NSColor.white.withAlphaComponent(0.2).cgColor
            containerView.layer?.borderWidth = 0.5
        } else {
            containerView.layer?.backgroundColor = NSColor.clear.cgColor
            containerView.layer?.borderWidth = 0
        }
    }
}
