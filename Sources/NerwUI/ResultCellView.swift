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

        titleLabel.font = .systemFont(ofSize: metrics.Text.titleSize, weight: .medium)
        titleLabel.textColor = .labelColor
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(titleLabel)

        subtitleLabel.font = .systemFont(ofSize: metrics.Text.subtitleSize)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(subtitleLabel)

        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: topAnchor, constant: metrics.Margin.vertical),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: metrics.Margin.horizontal),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -metrics.Margin.horizontal),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -metrics.Margin.vertical),

            iconView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: metrics.Icon.leading),
            iconView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: metrics.Icon.size),
            iconView.heightAnchor.constraint(equalToConstant: metrics.Icon.size),

            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: metrics.Icon.trailing),
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: metrics.Text.titleTop),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -10),

            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: metrics.Text.subtitleTop),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
        ])
    }

    func configure(with action: PopupContentViewController.Action, isSelected: Bool) {
        iconView.image = action.icon
        iconView.contentTintColor = isSelected ? .white : .labelColor
        titleLabel.stringValue = action.title
        titleLabel.textColor = isSelected ? .white : .labelColor
        subtitleLabel.stringValue = action.subtitle
        subtitleLabel.textColor = isSelected ? .white.withAlphaComponent(0.8) : .secondaryLabelColor

        containerView.layer?.backgroundColor = isSelected 
            ? NSColor.black.withAlphaComponent(0.2).cgColor 
            : NSColor.clear.cgColor
    }
}

class ResultRowView: NSTableRowView {
    override func drawSelection(in dirtyRect: NSRect) {
        // Custom selection handled in cell
    }
}