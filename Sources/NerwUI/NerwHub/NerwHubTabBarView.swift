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

    var onClick: ((NerwHubTab) -> Void)?

    private let iconImageView = NSImageView()
    private var trackingArea: NSTrackingArea?

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
        wantsLayer = true

        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.imageScaling = .scaleProportionallyDown
        addSubview(iconImageView)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 28),
            heightAnchor.constraint(equalToConstant: 28),

            iconImageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 16),
            iconImageView.heightAnchor.constraint(equalToConstant: 16),
        ])

        let click = NSClickGestureRecognizer(target: self, action: #selector(handleClick))
        addGestureRecognizer(click)

        updateState()
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
        if !isSelected {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.15
                iconImageView.animator().alphaValue = 0.85
            }
        }
    }

    override func mouseExited(with event: NSEvent) {
        if !isSelected {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.15
                iconImageView.animator().alphaValue = 0.4
            }
        }
    }

    private func updateState() {
        let baseImage = NSImage(
            systemSymbolName: tab.iconName, accessibilityDescription: tab.rawValue)

        if isSelected {
            if #available(macOS 12.0, *) {
                let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .bold)
                    .applying(NSImage.SymbolConfiguration(hierarchicalColor: .white))
                iconImageView.image = baseImage?.withSymbolConfiguration(config)
            } else {
                iconImageView.image = baseImage
            }
            iconImageView.contentTintColor = .white
            iconImageView.alphaValue = 1.0
        } else {
            let translucentColor = NSColor.white.withAlphaComponent(0.4)
            if #available(macOS 12.0, *) {
                let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
                    .applying(NSImage.SymbolConfiguration(hierarchicalColor: translucentColor))
                iconImageView.image = baseImage?.withSymbolConfiguration(config)
            } else {
                iconImageView.image = baseImage
            }
            iconImageView.contentTintColor = translucentColor
            iconImageView.alphaValue = 0.4
        }
    }

    @objc private func handleClick() {
        onClick?(tab)
    }
}

class NerwHubTabBarView: NSView {
    weak var delegate: NerwHubTabBarDelegate?

    private let pillWidth: CGFloat = 36
    private let collapsedHeight: CGFloat = 36
    private let expandedHeight: CGFloat = 118

    private let containerView = NSView()
    private let visualEffect = NSVisualEffectView()
    private let borderOverlay = NSView()
    private let collapsedIconView = NSImageView()
    private let stackView = NSStackView()

    private var activeTab: NerwHubTab = .memory
    private var tabViews: [NerwHubTab: NerwHubTabItemView] = [:]

    private var isExpanded: Bool = false
    private var isMouseHovering: Bool = false
    private var introWorkItem: DispatchWorkItem?

    private var heightConstraint: NSLayoutConstraint!
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
        translatesAutoresizingMaskIntoConstraints = false

        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = pillWidth / 2
        if #available(macOS 10.15, *) {
            containerView.layer?.cornerCurve = .circular
        }
        containerView.layer?.masksToBounds = true
        addSubview(containerView)

        visualEffect.translatesAutoresizingMaskIntoConstraints = false
        visualEffect.state = .active
        visualEffect.material = .popover
        visualEffect.blendingMode = .withinWindow
        containerView.addSubview(visualEffect)

        borderOverlay.translatesAutoresizingMaskIntoConstraints = false
        borderOverlay.wantsLayer = true
        borderOverlay.layer?.borderWidth = 1.0
        borderOverlay.layer?.borderColor = NSColor.white.withAlphaComponent(0.2).cgColor
        borderOverlay.layer?.cornerRadius = pillWidth / 2
        if #available(macOS 10.15, *) {
            borderOverlay.layer?.cornerCurve = .circular
        }
        borderOverlay.layer?.masksToBounds = true
        containerView.addSubview(borderOverlay)

        // Collapsed active icon
        collapsedIconView.translatesAutoresizingMaskIntoConstraints = false
        collapsedIconView.imageScaling = .scaleProportionallyDown
        collapsedIconView.contentTintColor = .white
        collapsedIconView.alphaValue = 1.0
        containerView.addSubview(collapsedIconView)

        // Expanded stack view
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.orientation = .vertical
        stackView.spacing = 4
        stackView.alignment = .centerX
        stackView.edgeInsets = NSEdgeInsets(top: 8, left: 4, bottom: 8, right: 4)
        stackView.alphaValue = 0.0
        containerView.addSubview(stackView)

        heightConstraint = heightAnchor.constraint(equalToConstant: collapsedHeight)
        heightConstraint.isActive = true

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: pillWidth),

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

            collapsedIconView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            collapsedIconView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            collapsedIconView.widthAnchor.constraint(equalToConstant: 16),
            collapsedIconView.heightAnchor.constraint(equalToConstant: 16),

            stackView.topAnchor.constraint(equalTo: containerView.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
        ])

        let allTabs = NerwHubTab.allCases
        for (index, tab) in allTabs.enumerated() {
            let tabView = NerwHubTabItemView(tab: tab)
            tabView.toolTip = "\(tab.rawValue) (⌘\(index + 1))"
            tabView.onClick = { [weak self] selectedTab in
                self?.delegate?.didSelect(tab: selectedTab)
            }
            stackView.addArrangedSubview(tabView)
            tabViews[tab] = tabView

            if index < allTabs.count - 1 {
                let dot = createSeparatorDot()
                stackView.addArrangedSubview(dot)
            }
        }

        select(tab: .memory)
        collapse(animated: false)
    }

    private func createSeparatorDot() -> NSView {
        let dotContainer = NSView()
        dotContainer.translatesAutoresizingMaskIntoConstraints = false

        let dot = NSView()
        dot.translatesAutoresizingMaskIntoConstraints = false
        dot.wantsLayer = true
        dot.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.25).cgColor
        dot.layer?.cornerRadius = 1.5
        dotContainer.addSubview(dot)

        NSLayoutConstraint.activate([
            dotContainer.widthAnchor.constraint(equalToConstant: 28),
            dotContainer.heightAnchor.constraint(equalToConstant: 6),

            dot.centerXAnchor.constraint(equalTo: dotContainer.centerXAnchor),
            dot.centerYAnchor.constraint(equalTo: dotContainer.centerYAnchor),
            dot.widthAnchor.constraint(equalToConstant: 3),
            dot.heightAnchor.constraint(equalToConstant: 3),
        ])

        return dotContainer
    }

    func select(tab: NerwHubTab) {
        activeTab = tab
        for (t, view) in tabViews {
            view.isSelected = (t == tab)
        }
        updateCollapsedIcon()
    }

    private func updateCollapsedIcon() {
        let baseImage = NSImage(
            systemSymbolName: activeTab.iconName, accessibilityDescription: activeTab.rawValue)
        if #available(macOS 12.0, *) {
            let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .bold)
                .applying(NSImage.SymbolConfiguration(hierarchicalColor: .white))
            collapsedIconView.image = baseImage?.withSymbolConfiguration(config)
        } else {
            collapsedIconView.image = baseImage
        }
        collapsedIconView.contentTintColor = .white
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
        isMouseHovering = true
        introWorkItem?.cancel()
        expand(animated: true)
    }

    override func mouseExited(with event: NSEvent) {
        isMouseHovering = false
        collapse(animated: true)
    }

    public func playIntroAnimation() {
        introWorkItem?.cancel()
        expand(animated: true)
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            if !self.isMouseHovering {
                self.collapse(animated: true)
            }
        }
        self.introWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9, execute: workItem)
    }

    private func expand(animated: Bool) {
        isExpanded = true
        let targetHeight = expandedHeight

        if animated {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.22
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                ctx.allowsImplicitAnimation = true
                self.heightConstraint.constant = targetHeight
                self.collapsedIconView.animator().alphaValue = 0.0
                self.stackView.animator().alphaValue = 1.0
                self.superview?.layoutSubtreeIfNeeded()
            }
        } else {
            heightConstraint.constant = targetHeight
            collapsedIconView.alphaValue = 0.0
            stackView.alphaValue = 1.0
            superview?.layoutSubtreeIfNeeded()
        }
    }

    private func collapse(animated: Bool) {
        isExpanded = false
        updateCollapsedIcon()
        let targetHeight = collapsedHeight

        if animated {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.22
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                ctx.allowsImplicitAnimation = true
                self.heightConstraint.constant = targetHeight
                self.collapsedIconView.animator().alphaValue = 1.0
                self.stackView.animator().alphaValue = 0.0
                self.superview?.layoutSubtreeIfNeeded()
            }
        } else {
            heightConstraint.constant = targetHeight
            collapsedIconView.alphaValue = 1.0
            stackView.alphaValue = 0.0
            superview?.layoutSubtreeIfNeeded()
        }
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let view = super.hitTest(point)
        if view == visualEffect || view == borderOverlay || view == containerView {
            return self
        }
        return view
    }
}
