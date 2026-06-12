import Cocoa
import NerwAction
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

    // Context Menu Button (Removed, now managed as a floating button in MainPanelContentViewController)
    // var onContextButtonTapped: (() -> Void)?

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

    static func makeVerticalEllipsisImage() -> NSImage {
        let size = NSSize(width: 6, height: 16)
        let image = NSImage(size: size, flipped: false) { rect in
            NSColor.white.setFill()
            let dotSize: CGFloat = 3.0
            let spacing: CGFloat = 2.5
            let totalHeight = dotSize * 3 + spacing * 2
            let startY = (rect.height - totalHeight) / 2
            for i in 0..<3 {
                let y = startY + CGFloat(i) * (dotSize + spacing)
                let dotRect = NSRect(
                    x: (rect.width - dotSize) / 2, y: y,
                    width: dotSize, height: dotSize)
                NSBezierPath(ovalIn: dotRect).fill()
            }
            return true
        }
        image.isTemplate = true
        return image
    }

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
        tabBadge.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.1).cgColor
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
                equalTo: containerView.trailingAnchor, constant: -8),
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

    // Shared cache for file icons to avoid regenerating thumbnails while navigating.
    private static let iconCache: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = 96
        cache.totalCostLimit = 24 * 1024 * 1024
        return cache
    }()

    static func clearIconCache() {
        iconCache.removeAllObjects()
    }

    func configure(
        with action: NerwAction, isSelected: Bool, isExplicitNavigation: Bool = false,
        modifiers: NSEvent.ModifierFlags = []
    ) {
        let config = ConfigManager.shared.config.uiConfig
        self.currentActionID = action.id

        var displayTitle = action.title
        var displaySubtitle = action.subtitle
        var displayIcon = action.icon

        // Check for modifiers and alternate text
        if isSelected && !action.modifiers.isEmpty {
            let key: NerwAction.ModifierKey?
            if modifiers.contains(.command) {
                key = .command
            } else if modifiers.contains(.shift) {
                key = .shift
            } else if modifiers.contains(.control) {
                key = .control
            } else if modifiers.contains(.option) {
                key = .option
            } else {
                key = nil
            }

            if let key = key, let modAction = action.modifiers[key] {
                if let t = modAction.title { displayTitle = t }
                if let s = modAction.subtitle { displaySubtitle = s }
                if let i = modAction.icon { displayIcon = i }
            }
        }

        let mainTextColor = NSColor(hex: config?.mainForegroundColor ?? "") ?? .labelColor
        let selectedTextColor = NSColor(hex: config?.selectionForegroundColor ?? "") ?? .white

        // Background Logic
        // Active (Moved): System Accent with frosted glass translucency
        let useSystemSelection = config?.useSystemSelectionColor ?? true
        let activeBg: NSColor

        if useSystemSelection {
            activeBg = NSColor.controlAccentColor.withAlphaComponent(0.65)
        } else {
            activeBg =
                NSColor(hex: config?.selectionBackgroundColor ?? "")?.withAlphaComponent(0.60)
                ?? NSColor.controlAccentColor.withAlphaComponent(0.60)
        }

        // Passive (Default): Subtle frosted glass highlight
        let passiveBg = NSColor.white.withAlphaComponent(0.08)

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

        if let iconType = displayIcon {
            switch iconType {
            case .system(let name):
                if let image = NSImage(systemSymbolName: name, accessibilityDescription: nil) {
                    iconView.image = image
                } else if let image = NSImage(named: NSImage.Name(name)) {
                    iconView.image = image
                }
            case .image(let img):
                iconView.image = img
            case .file(let url):
                // 1. Check Cache
                let cacheKey = url.path as NSString
                if let cached = ResultCellView.iconCache.object(forKey: cacheKey) {
                    iconView.image = cached
                } else {
                    // Set default icon first to avoid flickering/empty state
                    iconView.image = NSWorkspace.shared.icon(for: .data)  // Generic placeholder

                    // Async load
                    let loadingActionID = action.id
                    NerwUtils.IconUtils.getIconAsync(for: url, size: CGSize(width: 64, height: 64))
                    {
                        [weak self] image in
                        guard let self = self else { return }

                        // Cache it for next time
                        if let image = image {
                            ResultCellView.iconCache.setObject(
                                image, forKey: cacheKey, cost: Self.cacheCost(for: image))
                        }

                        // Verify cell is still configured for this action
                        if self.currentActionID == loadingActionID {
                            if let image = image {
                                self.iconView.image = image
                            }
                        }
                    }
                }
            }
        } else {
            iconView.image = nil
        }

        let tintColor = isSelected ? selectedTextColor : mainTextColor
        iconView.contentTintColor = tintColor
        if #available(macOS 12.0, *) {
            iconView.symbolConfiguration = NSImage.SymbolConfiguration(hierarchicalColor: tintColor)
        }

        titleLabel.stringValue = displayTitle
        titleLabel.textColor = isSelected ? selectedTextColor : mainTextColor

        subtitleLabel.stringValue = displaySubtitle
        subtitleLabel.textColor =
            isSelected ? selectedTextColor.withAlphaComponent(0.8) : .secondaryLabelColor

        containerView.layer?.backgroundColor =
            isSelected
            ? finalBgColor.cgColor
            : NSColor.clear.cgColor

        // Add subtle border for selected cells (frosted glass edge)
        if isSelected {
            containerView.layer?.borderColor = NSColor.white.withAlphaComponent(0.12).cgColor
            containerView.layer?.borderWidth = 0.5
        } else {
            containerView.layer?.borderColor = NSColor.clear.cgColor
            containerView.layer?.borderWidth = 0
        }

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

    var contextButtonFrameInCell: NSRect {
        let metrics = MainPanelContentViewController.LayoutMetrics.Cell.self
        let containerTrailing = bounds.width - metrics.Margin.horizontal
        let gapGuideCenterX = containerTrailing + metrics.Margin.horizontal / 2.0
        let centerX = gapGuideCenterX + 7.0
        let centerY = bounds.height / 2.0
        return NSRect(x: centerX - 12.0, y: centerY - 12.0, width: 24.0, height: 24.0)
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

    private static func cacheCost(for image: NSImage) -> Int {
        let size = image.size
        let width = max(Int(size.width), 1)
        let height = max(Int(size.height), 1)
        return width * height * 4
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

class ContextHoverButton: NSView {
    let effectView = NSVisualEffectView()
    let imageView = NSImageView()
    let hintLabel = NSTextField(labelWithString: "⌘K")
    var onTapped: (() -> Void)?

    private var isExpanded = false
    private var baseTrackingArea: NSTrackingArea?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        effectView.translatesAutoresizingMaskIntoConstraints = false
        effectView.material = .popover
        effectView.blendingMode = .withinWindow
        effectView.state = .active
        effectView.wantsLayer = true
        effectView.alphaValue = 0  // Hidden initially
        addSubview(effectView)

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.imageScaling = .scaleProportionallyDown
        addSubview(imageView)

        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        hintLabel.font = .systemFont(ofSize: 13, weight: .bold)  // Increased font size from 10 to 13
        hintLabel.textColor = NSColor.labelColor
        hintLabel.alignment = .center
        hintLabel.alphaValue = 0
        hintLabel.drawsBackground = false
        hintLabel.isBordered = false
        hintLabel.isEditable = false
        hintLabel.isSelectable = false
        addSubview(hintLabel)

        NSLayoutConstraint.activate([
            effectView.topAnchor.constraint(equalTo: topAnchor),
            effectView.bottomAnchor.constraint(equalTo: bottomAnchor),
            effectView.leadingAnchor.constraint(equalTo: leadingAnchor),
            effectView.trailingAnchor.constraint(equalTo: trailingAnchor),

            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 24),
            imageView.heightAnchor.constraint(equalToConstant: 24),

            hintLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 2),
            hintLabel.widthAnchor.constraint(equalToConstant: 38),
            hintLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
            hintLabel.heightAnchor.constraint(equalToConstant: 20),
        ])
    }

    private func makeBubblePath() -> CGPath {
        let path = CGMutablePath()

        // 1. Bubble body: rounded rect at the bottom-left (0, 0, 42, 28)
        let bodyRect = CGRect(x: 0, y: 0, width: 42, height: 28)
        let cornerRadius: CGFloat = 8
        path.addRoundedRect(in: bodyRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius)

        // 2. Tail pointing from the top edge of the body (y: 28) to the tip (38, 36)
        path.move(to: CGPoint(x: 24, y: 28))
        // Curve to tip
        path.addQuadCurve(to: CGPoint(x: 38, y: 36), control: CGPoint(x: 32, y: 33))
        // Curve back to body
        path.addQuadCurve(to: CGPoint(x: 36, y: 28), control: CGPoint(x: 38, y: 31))
        path.closeSubpath()

        return path
    }

    override func layout() {
        super.layout()

        // Update mask layer path on layout
        if let maskLayer = effectView.layer?.mask as? CAShapeLayer {
            maskLayer.path = makeBubblePath()
        } else {
            let maskLayer = CAShapeLayer()
            maskLayer.path = makeBubblePath()

            // Add border styling on the mask layer if desired, or let the layer border handle it.
            // But since a mask clips borders too, we apply border directly inside the mask path or use the layer's border.
            // For NSVisualEffectView, masking it clips the background and borders perfectly.
            effectView.layer?.mask = maskLayer
        }
    }

    override func mouseDown(with event: NSEvent) {
        // Prevent event from falling through
    }

    override func mouseUp(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if bounds.contains(point) {
            onTapped?()
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let area = baseTrackingArea {
            removeTrackingArea(area)
        }

        // Track only the top-right 24x24 area when collapsed to avoid invisible overlap blocking the row below
        let rect =
            isExpanded
            ? bounds : NSRect(x: 26, y: 28, width: 24, height: 24)
        baseTrackingArea = NSTrackingArea(
            rect: rect,
            options: [.activeAlways, .mouseEnteredAndExited],
            owner: self,
            userInfo: nil
        )
        if let area = baseTrackingArea {
            addTrackingArea(area)
        }
    }

    override func mouseEntered(with event: NSEvent) {
        if !isExpanded {
            isExpanded = true
            updateTrackingAreas()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                self.effectView.animator().alphaValue = 1.0
                self.hintLabel.animator().alphaValue = 1.0
            }
        }
    }

    override func mouseExited(with event: NSEvent) {
        if let window = window {
            let localPoint = convert(window.mouseLocationOutsideOfEventStream, from: nil)
            if !bounds.contains(localPoint) {
                collapse()
            }
        } else {
            collapse()
        }
    }

    private func collapse() {
        if isExpanded {
            isExpanded = false
            updateTrackingAreas()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                self.effectView.animator().alphaValue = 0.0
                self.hintLabel.animator().alphaValue = 0.0
            }
        }
    }
}
