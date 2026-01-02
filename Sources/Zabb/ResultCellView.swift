// ResultCellView.swift
import Cocoa

class ResultCellView: NSTableCellView {
    private let iconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "")
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
        let metrics = PopupContentViewController.LayoutMetrics.Cell.self
        
        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = metrics.cornerRadius
        containerView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(containerView)

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.imageScaling = .scaleProportionallyUpOrDown
        containerView.addSubview(iconView)

        titleLabel.font = .systemFont(ofSize: metrics.titleFontSize, weight: .medium)
        titleLabel.textColor = .labelColor
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(titleLabel)

        subtitleLabel.font = .systemFont(ofSize: metrics.subtitleFontSize)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(subtitleLabel)

        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: topAnchor, constant: metrics.verticalMargin),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: metrics.horizontalMargin),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -metrics.horizontalMargin),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -metrics.verticalMargin),

            iconView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: metrics.iconLeading),
            iconView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: metrics.iconSize),
            iconView.heightAnchor.constraint(equalToConstant: metrics.iconSize),

            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: metrics.iconSpacing),
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: metrics.titleTop),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -10),

            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: metrics.subtitleTop),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
        ])
    }

    func configure(with result: PopupContentViewController.SearchResult, isSelected: Bool) {
        iconView.image = result.icon
        iconView.contentTintColor = isSelected ? .white : .labelColor
        titleLabel.stringValue = result.title
        titleLabel.textColor = isSelected ? .white : .labelColor
        subtitleLabel.stringValue = result.subtitle
        subtitleLabel.textColor = isSelected ? .white.withAlphaComponent(0.8) : .secondaryLabelColor

        containerView.layer?.backgroundColor = isSelected 
            ? NSColor.controlAccentColor.cgColor 
            : NSColor.clear.cgColor
    }
}

class ResultRowView: NSTableRowView {
    override func drawSelection(in dirtyRect: NSRect) {
        // Custom selection handled in cell
    }
}