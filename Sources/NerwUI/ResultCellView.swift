import Cocoa
import NerwCore
import NerwSearchBackend
import NerwUtils

class ResultCellView: NSTableCellView {
    private let iconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "")
    private let containerView = NSView()
    private var currentActionID: String?

    // Tab Hint UI
    private let hintStack = NSStackView()
    private let hintLabel = NSTextField(labelWithString: "")
    private let tabBadge = NSView()
    private let tabBadgeLabel = NSTextField(labelWithString: "tab")

    // Icon Size Constraints
    private var iconWidthConstraint: NSLayoutConstraint!
    private var iconHeightConstraint: NSLayoutConstraint!

    // Peek UI Constraints
    private var normalIconCenterYConstraint: NSLayoutConstraint!
    private var peekIconTopConstraint: NSLayoutConstraint!
    private var normalTitleTopConstraint: NSLayoutConstraint!
    private var peekTitleCenterYConstraint: NSLayoutConstraint!
    private var normalSubtitleTopConstraint: NSLayoutConstraint!
    private var peekSubtitleTopConstraint: NSLayoutConstraint!
    private var normalSubtitleBottomConstraint: NSLayoutConstraint!
    private var peekSubtitleBottomConstraint: NSLayoutConstraint!

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }

    private func setupViews() {
        let metrics = MainPanelContentViewController.LayoutMetrics.Cell.self

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
        titleLabel.lineBreakMode = .byTruncatingTail
        containerView.addSubview(titleLabel)

        subtitleLabel.font = .systemFont(ofSize: metrics.Text.subtitleSize)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.lineBreakMode = .byWordWrapping  // allow multi-line for peek
        subtitleLabel.maximumNumberOfLines = 0
        containerView.addSubview(subtitleLabel)

        // Hint Stack
        hintStack.orientation = .horizontal
        hintStack.spacing = 6
        hintStack.translatesAutoresizingMaskIntoConstraints = false
        hintStack.alignment = .centerY
        containerView.addSubview(hintStack)

        hintLabel.font = .systemFont(ofSize: 11, weight: .regular)
        hintLabel.textColor = .secondaryLabelColor
        hintLabel.alphaValue = 0.7
        hintStack.addArrangedSubview(hintLabel)

        // Tab Badge
        tabBadge.wantsLayer = true
        tabBadge.layer?.cornerRadius = 4
        tabBadge.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.2).cgColor
        tabBadge.translatesAutoresizingMaskIntoConstraints = false

        tabBadgeLabel.font = .systemFont(ofSize: 10, weight: .semibold)
        tabBadgeLabel.textColor = .white.withAlphaComponent(0.9)
        tabBadgeLabel.translatesAutoresizingMaskIntoConstraints = false

        tabBadge.addSubview(tabBadgeLabel)

        NSLayoutConstraint.activate([
            tabBadgeLabel.leadingAnchor.constraint(equalTo: tabBadge.leadingAnchor, constant: 4),
            tabBadgeLabel.trailingAnchor.constraint(equalTo: tabBadge.trailingAnchor, constant: -4),
            tabBadgeLabel.topAnchor.constraint(equalTo: tabBadge.topAnchor, constant: 2),
            tabBadgeLabel.bottomAnchor.constraint(equalTo: tabBadge.bottomAnchor, constant: -2),
        ])

        hintStack.addArrangedSubview(tabBadge)

        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(
                equalTo: topAnchor, constant: metrics.Margin.vertical),
            containerView.leadingAnchor.constraint(
                equalTo: leadingAnchor, constant: metrics.Margin.horizontal),
            containerView.trailingAnchor.constraint(
                equalTo: trailingAnchor, constant: -metrics.Margin.horizontal),
            containerView.bottomAnchor.constraint(
                equalTo: bottomAnchor, constant: -metrics.Margin.vertical),

            iconView.leadingAnchor.constraint(
                equalTo: containerView.leadingAnchor, constant: metrics.Icon.leading),

            titleLabel.leadingAnchor.constraint(
                equalTo: iconView.trailingAnchor, constant: metrics.Icon.trailing),
            titleLabel.trailingAnchor.constraint(
                lessThanOrEqualTo: hintStack.leadingAnchor, constant: -10),

            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),

            hintStack.trailingAnchor.constraint(
                equalTo: containerView.trailingAnchor, constant: -12),
            hintStack.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
        ])

        iconWidthConstraint = iconView.widthAnchor.constraint(equalToConstant: metrics.Icon.size)
        iconHeightConstraint = iconView.heightAnchor.constraint(equalToConstant: metrics.Icon.size)
        iconWidthConstraint.isActive = true
        iconHeightConstraint.isActive = true

        normalIconCenterYConstraint = iconView.centerYAnchor.constraint(
            equalTo: containerView.centerYAnchor)
        peekIconTopConstraint = iconView.topAnchor.constraint(
            equalTo: containerView.topAnchor, constant: 16)

        normalTitleTopConstraint = titleLabel.topAnchor.constraint(
            equalTo: containerView.topAnchor, constant: metrics.Text.titleTop)
        peekTitleCenterYConstraint = titleLabel.centerYAnchor.constraint(
            equalTo: iconView.centerYAnchor)

        normalSubtitleTopConstraint = subtitleLabel.topAnchor.constraint(
            equalTo: titleLabel.bottomAnchor, constant: metrics.Text.subtitleTop)
        // give the peek subtitle some breathing room below the title
        peekSubtitleTopConstraint = subtitleLabel.topAnchor.constraint(
            equalTo: titleLabel.bottomAnchor, constant: 12)

        normalSubtitleBottomConstraint = subtitleLabel.bottomAnchor.constraint(
            lessThanOrEqualTo: containerView.bottomAnchor, constant: -metrics.Text.subtitleTop)
        peekSubtitleBottomConstraint = subtitleLabel.bottomAnchor.constraint(
            lessThanOrEqualTo: containerView.bottomAnchor, constant: -16)

        NSLayoutConstraint.activate([
            normalIconCenterYConstraint,
            normalTitleTopConstraint,
            normalSubtitleTopConstraint,
            normalSubtitleBottomConstraint,
        ])
    }

    func configure(with action: NerwAction, isSelected: Bool, isExplicitNavigation: Bool = false) {
        let config = ConfigManager.shared.config.uiConfig
        self.currentActionID = action.id

        let mainTextColor = NSColor(hex: config?.mainForegroundColor ?? "") ?? .labelColor
        let selectedTextColor = NSColor(hex: config?.selectionForegroundColor ?? "") ?? .white

        // Background Logic
        // Active (Moved): System Accent
        let useSystemSelection = config?.useSystemSelectionColor ?? false
        let activeBg: NSColor

        if useSystemSelection {
            activeBg = NSColor.controlAccentColor.withAlphaComponent(0.9)
        } else {
            activeBg =
                NSColor(hex: config?.selectionBackgroundColor ?? "")?.withAlphaComponent(0.85)
                ?? NSColor.controlAccentColor.withAlphaComponent(0.85)
        }

        // Passive (Default): Grey/White Alpha
        let passiveBg = NSColor.white.withAlphaComponent(0.12)

        let finalBgColor = isExplicitNavigation ? activeBg : passiveBg

        let metrics = MainPanelContentViewController.LayoutMetrics.Cell.self
        let defaultTitleFont = NSFont.systemFont(ofSize: metrics.Text.titleSize, weight: .medium)
        let defaultSubFont = NSFont.systemFont(ofSize: metrics.Text.subtitleSize)

        // Font
        if let fontName = config?.font {
            titleLabel.font =
                NSFont(name: fontName, size: metrics.Text.titleSize) ?? defaultTitleFont
            subtitleLabel.font =
                NSFont(name: fontName, size: metrics.Text.subtitleSize) ?? defaultSubFont
        } else {
            titleLabel.font = defaultTitleFont
            subtitleLabel.font = defaultSubFont
        }

        if let iconType = action.icon {
            switch iconType {
            case .system(let name):
                iconView.image = NSImage(systemSymbolName: name, accessibilityDescription: nil)
            case .image(let img):
                iconView.image = img
            case .file(let url):
                // Set default icon first to avoid flickering/empty state
                iconView.image = NSWorkspace.shared.icon(for: .data)  // Generic placeholder

                // Async load
                let loadingActionID = action.id
                NerwUtils.IconUtils.getIconAsync(for: url, size: CGSize(width: 64, height: 64)) {
                    [weak self] image in
                    guard let self = self else { return }

                    // Verify cell is still configured for this action
                    if self.currentActionID == loadingActionID {
                        if let image = image {
                            self.iconView.image = image
                        }
                    }
                }
            }
        } else {
            iconView.image = nil
        }

        iconView.contentTintColor = isSelected ? selectedTextColor : mainTextColor

        titleLabel.stringValue = action.title
        titleLabel.textColor = isSelected ? selectedTextColor : mainTextColor

        subtitleLabel.stringValue = action.subtitle
        subtitleLabel.textColor =
            isSelected ? selectedTextColor.withAlphaComponent(0.8) : .secondaryLabelColor

        containerView.layer?.backgroundColor =
            isSelected
            ? finalBgColor.cgColor
            : NSColor.clear.cgColor

        // Configure Peek Mode
        if isSelected, let peek = action.peek {
            // Apply Constraints
            normalIconCenterYConstraint.isActive = false
            peekIconTopConstraint.isActive = true
            normalTitleTopConstraint.isActive = false
            peekTitleCenterYConstraint.isActive = true
            normalSubtitleTopConstraint.isActive = false
            peekSubtitleTopConstraint.isActive = true
            normalSubtitleBottomConstraint.isActive = false
            peekSubtitleBottomConstraint.isActive = true

            // Allow multiple lines
            subtitleLabel.lineBreakMode = .byWordWrapping

            // Apply Fonts & Colors for Peek
            titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
            titleLabel.textColor = .white

            // Shrink icon size
            iconWidthConstraint.constant = 22
            iconHeightConstraint.constant = 22

            subtitleLabel.font = .systemFont(ofSize: 12, weight: .regular)
            subtitleLabel.textColor = .secondaryLabelColor

            // Apply Peek Overrides
            titleLabel.stringValue = peek.title
            subtitleLabel.stringValue = peek.text

            // Override Icon
            if let peekIcon = peek.icon {
                switch peekIcon {
                case .system(let name):
                    iconView.image = NSImage(systemSymbolName: name, accessibilityDescription: nil)
                    iconView.contentTintColor = .white
                case .image(let img):
                    iconView.image = img
                case .file(let url):
                    NerwUtils.IconUtils.getIconAsync(for: url, size: CGSize(width: 64, height: 64))
                    { [weak self] image in
                        if let self = self, self.currentActionID == action.id {
                            self.iconView.image = image ?? self.iconView.image
                        }
                    }
                }
            }

            // Reduce icon size for Peek
            // Note: AutoLayout will handle this via existing constraints or scaling,
            // but we can adjust the content scale or the frame if needed.
            // The imageScaling = .scaleProportionallyUpOrDown helps.
            iconView.contentTintColor = .white

            containerView.needsLayout = true

        } else {
            // Normal Mode
            normalIconCenterYConstraint.isActive = true
            peekIconTopConstraint.isActive = false
            normalTitleTopConstraint.isActive = true
            peekTitleCenterYConstraint.isActive = false
            normalSubtitleTopConstraint.isActive = true
            peekSubtitleTopConstraint.isActive = false
            normalSubtitleBottomConstraint.isActive = true
            peekSubtitleBottomConstraint.isActive = false

            // Revert icon size
            iconWidthConstraint.constant = metrics.Icon.size
            iconHeightConstraint.constant = metrics.Icon.size

            subtitleLabel.lineBreakMode = .byTruncatingTail
        }

        updateHint(
            action: action, isSelected: isSelected,
            textColor: isSelected ? selectedTextColor : mainTextColor)
    }

    private func updateHint(action: NerwAction, isSelected: Bool, textColor: NSColor) {
        // Only show if selected
        guard isSelected else {
            hintStack.isHidden = true
            return
        }

        if let hintText = action.modeHintText {
            hintStack.isHidden = false
            hintLabel.stringValue = hintText
            hintLabel.textColor = textColor.withAlphaComponent(0.7)

            // Adjust badge color based on selection text color
            tabBadge.layer?.backgroundColor = textColor.withAlphaComponent(0.15).cgColor
            tabBadgeLabel.textColor = textColor
        } else {
            hintStack.isHidden = true
        }
    }
}

class ResultRowView: NSTableRowView {
    override func drawSelection(in dirtyRect: NSRect) {
        // Custom selection handled in cell
    }
}

class FlatButton: NSButton {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        isBordered = false
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.backgroundColor = NSColor.white.withAlphaComponent(0.1).cgColor
        font = .systemFont(ofSize: 12, weight: .medium)
        contentTintColor = .labelColor
        alignment = .center
    }

    override func mouseEntered(with event: NSEvent) {
        layer?.backgroundColor = NSColor.white.withAlphaComponent(0.2).cgColor
    }

    override func mouseExited(with event: NSEvent) {
        layer?.backgroundColor = NSColor.white.withAlphaComponent(0.1).cgColor
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for trackingArea in trackingAreas {
            removeTrackingArea(trackingArea)
        }
        let trackingArea = NSTrackingArea(
            rect: bounds, options: [.activeAlways, .mouseEnteredAndExited], owner: self,
            userInfo: nil)
        addTrackingArea(trackingArea)
    }
}
