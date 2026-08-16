import Cocoa
import NerwCore

protocol NerwHubTabBarDelegate: AnyObject {
    func didSelect(tab: NerwHubTab)
}

class NerwHubTabItemView: NSView {
    let tab: NerwHubTab
    var isSelected: Bool = false {
        didSet {
            updateState()
        }
    }

    var isExpandedBar: Bool = false {
        didSet {
            updateState()
        }
    }

    var onClick: ((NerwHubTab) -> Void)?

    private let iconImageView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let stackView = NSStackView()

    init(tab: NerwHubTab) {
        self.tab = tab
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false

        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.orientation = .horizontal
        stackView.spacing = 6
        stackView.alignment = .centerY
        addSubview(stackView)

        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.image = NSImage(systemSymbolName: tab.iconName, accessibilityDescription: nil)
        iconImageView.contentTintColor = .white
        stackView.addArrangedSubview(iconImageView)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.stringValue = tab.rawValue
        titleLabel.lineBreakMode = .byTruncatingTail
        stackView.addArrangedSubview(titleLabel)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),

            iconImageView.widthAnchor.constraint(equalToConstant: 14),
            iconImageView.heightAnchor.constraint(equalToConstant: 14),
        ])

        let click = NSClickGestureRecognizer(target: self, action: #selector(handleClick))
        addGestureRecognizer(click)

        updateState()
    }

    private func updateState() {
        let isFullyActive = isSelected && isExpandedBar
        let translucentColor = NSColor.secondaryLabelColor

        if isSelected {
            titleLabel.font = .systemFont(ofSize: 13, weight: .bold)
            titleLabel.textColor = .white
            if #available(macOS 12.0, *) {
                iconImageView.symbolConfiguration = NSImage.SymbolConfiguration(
                    hierarchicalColor: .white)
            } else {
                iconImageView.contentTintColor = .white
            }
        } else {
            titleLabel.font = .systemFont(ofSize: 13, weight: .medium)
            titleLabel.textColor = translucentColor
            if #available(macOS 12.0, *) {
                iconImageView.symbolConfiguration = NSImage.SymbolConfiguration(
                    hierarchicalColor: translucentColor)
            } else {
                iconImageView.contentTintColor = translucentColor
            }
        }
    }

    @objc private func handleClick() {
        onClick?(tab)
    }
}

class NerwHubTabBarView: NSView {
    weak var delegate: NerwHubTabBarDelegate?

    private let height: CGFloat = 36
    private let maxWidthThreshold: CGFloat = 450

    private let containerView = NSView()
    private let visualEffect = NSVisualEffectView()
    private let borderOverlay = NSView()
    private let scrollView = NSScrollView()
    private let stackView = NSStackView()

    private let leftArrow = NSImageView()
    private let rightArrow = NSImageView()

    private var isExpanded: Bool = false {
        didSet {
            for view in tabViews.values {
                view.isExpandedBar = isExpanded
            }
        }
    }
    private var activeTab: NerwHubTab = .memory
    private var tabViews: [NerwHubTab: NerwHubTabItemView] = [:]

    private var widthConstraint: NSLayoutConstraint!
    private var trackingArea: NSTrackingArea?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        wantsLayer = true

        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = height / 2
        if #available(macOS 10.15, *) {
            containerView.layer?.cornerCurve = .circular
        }
        containerView.layer?.masksToBounds = true
        addSubview(containerView)

        visualEffect.translatesAutoresizingMaskIntoConstraints = false
        visualEffect.state = .active
        visualEffect.material = .popover
        visualEffect.blendingMode = .withinWindow

        let mask = NSImage(size: NSSize(width: height, height: height), flipped: false) { rect in
            let path = NSBezierPath(
                roundedRect: rect, xRadius: rect.height / 2, yRadius: rect.height / 2)
            NSColor.black.setFill()
            path.fill()
            return true
        }
        mask.capInsets = NSEdgeInsets(
            top: height / 2, left: height / 2, bottom: height / 2, right: height / 2)
        visualEffect.maskImage = mask

        containerView.addSubview(visualEffect)

        borderOverlay.translatesAutoresizingMaskIntoConstraints = false
        borderOverlay.wantsLayer = true
        borderOverlay.layer?.borderWidth = 1.0
        borderOverlay.layer?.borderColor = NSColor.white.withAlphaComponent(0.2).cgColor
        borderOverlay.layer?.cornerRadius = height / 2
        if #available(macOS 10.15, *) {
            borderOverlay.layer?.cornerCurve = .circular
        }
        borderOverlay.layer?.masksToBounds = true
        containerView.addSubview(borderOverlay)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        containerView.addSubview(scrollView)

        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.orientation = .horizontal
        stackView.spacing = 0
        stackView.alignment = .centerY
        scrollView.documentView = stackView

        setupArrows()

        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),

            visualEffect.topAnchor.constraint(equalTo: containerView.topAnchor),
            visualEffect.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            visualEffect.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            visualEffect.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),

            borderOverlay.topAnchor.constraint(equalTo: containerView.topAnchor),
            borderOverlay.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            borderOverlay.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            borderOverlay.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),

            scrollView.topAnchor.constraint(equalTo: containerView.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 4),
            scrollView.trailingAnchor.constraint(
                equalTo: containerView.trailingAnchor, constant: -4),

            stackView.heightAnchor.constraint(equalTo: scrollView.heightAnchor),
        ])

        for tab in NerwHubTab.allCases {
            let tabView = NerwHubTabItemView(tab: tab)
            tabView.onClick = { [weak self] selectedTab in
                self?.delegate?.didSelect(tab: selectedTab)
            }
            stackView.addArrangedSubview(tabView)
            tabViews[tab] = tabView
        }

        widthConstraint = widthAnchor.constraint(equalToConstant: height)  // Default starting size
        widthConstraint.isActive = true

        scrollView.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            self, selector: #selector(boundsDidChange), name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView)

        select(tab: .memory)
    }

    private func setupArrows() {
        let arrowConfig = NSImage.SymbolConfiguration(pointSize: 12, weight: .bold)

        leftArrow.image = NSImage(systemSymbolName: "chevron.left", accessibilityDescription: nil)?
            .withSymbolConfiguration(arrowConfig)
        leftArrow.contentTintColor = .white
        leftArrow.translatesAutoresizingMaskIntoConstraints = false
        leftArrow.alphaValue = 0
        containerView.addSubview(leftArrow)

        rightArrow.image = NSImage(
            systemSymbolName: "chevron.right", accessibilityDescription: nil)?
            .withSymbolConfiguration(arrowConfig)
        rightArrow.contentTintColor = .white
        rightArrow.translatesAutoresizingMaskIntoConstraints = false
        rightArrow.alphaValue = 0
        containerView.addSubview(rightArrow)

        NSLayoutConstraint.activate([
            leftArrow.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            leftArrow.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),

            rightArrow.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            rightArrow.trailingAnchor.constraint(
                equalTo: containerView.trailingAnchor, constant: -8),
        ])
    }

    override func layout() {
        super.layout()
        layer?.shadowOpacity = 0.0
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea = trackingArea {
            removeTrackingArea(trackingArea)
        }
        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeAlways]
        trackingArea = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(trackingArea!)
    }

    override func mouseEntered(with event: NSEvent) {
        expand()
    }

    override func mouseExited(with event: NSEvent) {
        collapse()
    }

    func select(tab: NerwHubTab) {
        activeTab = tab
        for (t, view) in tabViews {
            view.isSelected = (t == tab)
        }
        if !isExpanded {
            collapse()  // Re-center and resize to the new tab
        } else {
            // Scroll to make sure it's visible if needed when expanded
            centerActiveTab()
        }
    }

    private func expand() {
        isExpanded = true
        layoutSubtreeIfNeeded()
        let totalWidth = stackView.fittingSize.width + 8  // 4 padding on each side
        let targetWidth = min(totalWidth, maxWidthThreshold)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            ctx.allowsImplicitAnimation = true
            widthConstraint.constant = targetWidth
            self.superview?.layoutSubtreeIfNeeded()
        }
        updateScrollIndicators()
    }

    private func collapse() {
        isExpanded = false
        layoutSubtreeIfNeeded()

        guard let activeView = tabViews[activeTab] else { return }
        let targetWidth = activeView.fittingSize.width + 8

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            ctx.allowsImplicitAnimation = true
            widthConstraint.constant = targetWidth
            self.superview?.layoutSubtreeIfNeeded()
            centerActiveTab()
        }

        // Hide scroll indicators when collapsed
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.1
            leftArrow.animator().alphaValue = 0
            rightArrow.animator().alphaValue = 0
        }
    }

    private func centerActiveTab() {
        guard let activeView = tabViews[activeTab] else { return }

        let targetContainerWidth: CGFloat
        if isExpanded {
            targetContainerWidth = min(stackView.fittingSize.width, maxWidthThreshold - 8)
        } else {
            targetContainerWidth = activeView.fittingSize.width
        }

        let activeFrame = activeView.frame
        let targetX = activeFrame.origin.x - (targetContainerWidth - activeFrame.width) / 2

        let maxOffset = max(0, stackView.frame.width - targetContainerWidth)
        let clampedX = max(0, min(targetX, maxOffset))

        scrollView.contentView.animator().setBoundsOrigin(NSPoint(x: clampedX, y: 0))
    }

    @objc private func boundsDidChange(notification: Notification) {
        if isExpanded {
            updateScrollIndicators()
        }
    }

    private func updateScrollIndicators() {
        let maxOffset = stackView.frame.width - scrollView.bounds.width
        if maxOffset <= 0 {
            leftArrow.animator().alphaValue = 0
            rightArrow.animator().alphaValue = 0
            return
        }

        let currentOffset = scrollView.contentView.bounds.origin.x

        let showLeft = currentOffset > 1
        let showRight = currentOffset < maxOffset - 1

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            leftArrow.animator().alphaValue = showLeft ? 1.0 : 0.0
            rightArrow.animator().alphaValue = showRight ? 1.0 : 0.0
        }
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let view = super.hitTest(point)
        // Ensure scrolling and clicks pass through visual effect/border
        if view == visualEffect || view == borderOverlay || view == containerView {
            return self
        }
        return view
    }
}
