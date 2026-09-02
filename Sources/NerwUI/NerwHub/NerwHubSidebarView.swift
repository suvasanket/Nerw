import Cocoa
import NerwCore

protocol NerwHubSidebarDelegate: AnyObject {
    func sidebarDidSelect(tab: NerwHubTab)
    func sidebarDidToggle()
}

class NerwHubSidebarItemView: NSView {
    let tab: NerwHubTab
    private let shortcutText: String

    var isSelected: Bool = false {
        didSet {
            updateState()
        }
    }

    var badgeCount: Int = 0 {
        didSet {
            updateBadge()
        }
    }

    var onClick: ((NerwHubTab) -> Void)?

    private let pillView = NSView()
    private let iconImageView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let badgeLabel = NSTextField(labelWithString: "")
    private let shortcutLabel = NSTextField(labelWithString: "")
    private var trackingArea: NSTrackingArea?

    init(tab: NerwHubTab, shortcutText: String) {
        self.tab = tab
        self.shortcutText = shortcutText
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false

        pillView.translatesAutoresizingMaskIntoConstraints = false
        pillView.wantsLayer = true
        pillView.layer?.cornerRadius = 6
        if #available(macOS 10.15, *) {
            pillView.layer?.cornerCurve = .continuous
        }
        addSubview(pillView)

        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.imageScaling = .scaleProportionallyDown
        pillView.addSubview(iconImageView)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.stringValue = tab.rawValue
        titleLabel.isEditable = false
        titleLabel.isSelectable = false
        titleLabel.drawsBackground = false
        titleLabel.isBezeled = false
        pillView.addSubview(titleLabel)

        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        badgeLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        badgeLabel.isEditable = false
        badgeLabel.isSelectable = false
        badgeLabel.drawsBackground = false
        badgeLabel.isBezeled = false
        badgeLabel.alignment = .right
        pillView.addSubview(badgeLabel)

        shortcutLabel.translatesAutoresizingMaskIntoConstraints = false
        shortcutLabel.stringValue = shortcutText
        shortcutLabel.font = .systemFont(ofSize: 10, weight: .medium)
        shortcutLabel.isEditable = false
        shortcutLabel.isSelectable = false
        shortcutLabel.drawsBackground = false
        shortcutLabel.isBezeled = false
        shortcutLabel.alignment = .right
        shortcutLabel.isHidden = true
        pillView.addSubview(shortcutLabel)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 32),

            pillView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            pillView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            pillView.topAnchor.constraint(equalTo: topAnchor, constant: 1),
            pillView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -1),

            iconImageView.leadingAnchor.constraint(equalTo: pillView.leadingAnchor, constant: 8),
            iconImageView.centerYAnchor.constraint(equalTo: pillView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 16),
            iconImageView.heightAnchor.constraint(equalToConstant: 16),

            titleLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 8),
            titleLabel.centerYAnchor.constraint(equalTo: pillView.centerYAnchor),

            badgeLabel.trailingAnchor.constraint(equalTo: pillView.trailingAnchor, constant: -8),
            badgeLabel.centerYAnchor.constraint(equalTo: pillView.centerYAnchor),
            badgeLabel.leadingAnchor.constraint(
                greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: 4),

            shortcutLabel.trailingAnchor.constraint(equalTo: pillView.trailingAnchor, constant: -8),
            shortcutLabel.centerYAnchor.constraint(equalTo: pillView.centerYAnchor),
        ])

        updateState()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea = trackingArea {
            removeTrackingArea(trackingArea)
        }
        let options: NSTrackingArea.Options = [
            .mouseEnteredAndExited, .activeAlways, .inVisibleRect,
        ]
        trackingArea = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(trackingArea!)
    }

    override func mouseEntered(with event: NSEvent) {
        if !isSelected {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.1
                pillView.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.06).cgColor
            }
            shortcutLabel.isHidden = false
            badgeLabel.isHidden = true
        }
    }

    override func mouseExited(with event: NSEvent) {
        if !isSelected {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.1
                pillView.layer?.backgroundColor = NSColor.clear.cgColor
            }
            shortcutLabel.isHidden = true
            badgeLabel.isHidden = (badgeCount == 0)
        }
    }

    override func mouseDown(with event: NSEvent) {
        onClick?(tab)
    }

    private func updateBadge() {
        if badgeCount > 0 {
            badgeLabel.stringValue = "\(badgeCount)"
            if !shortcutLabel.isHidden {
                badgeLabel.isHidden = true
            } else {
                badgeLabel.isHidden = false
            }
        } else {
            badgeLabel.stringValue = ""
            badgeLabel.isHidden = true
        }
    }

    private func updateState() {
        let baseImage = NSImage(
            systemSymbolName: tab.iconName, accessibilityDescription: tab.rawValue)

        if isSelected {
            pillView.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.12).cgColor
            titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
            titleLabel.textColor = .white
            badgeLabel.textColor = NSColor.white.withAlphaComponent(0.85)
            shortcutLabel.textColor = NSColor.white.withAlphaComponent(0.85)

            if #available(macOS 12.0, *) {
                let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
                    .applying(NSImage.SymbolConfiguration(hierarchicalColor: .white))
                iconImageView.image = baseImage?.withSymbolConfiguration(config)
            } else {
                iconImageView.image = baseImage
            }
            iconImageView.contentTintColor = .white
        } else {
            pillView.layer?.backgroundColor = NSColor.clear.cgColor
            titleLabel.font = .systemFont(ofSize: 13, weight: .regular)
            titleLabel.textColor = NSColor.white.withAlphaComponent(0.7)
            badgeLabel.textColor = .secondaryLabelColor
            shortcutLabel.textColor = .tertiaryLabelColor

            if #available(macOS 12.0, *) {
                let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
                    .applying(
                        NSImage.SymbolConfiguration(
                            hierarchicalColor: NSColor.white.withAlphaComponent(0.7)))
                iconImageView.image = baseImage?.withSymbolConfiguration(config)
            } else {
                iconImageView.image = baseImage
            }
            iconImageView.contentTintColor = NSColor.white.withAlphaComponent(0.7)
        }
        updateBadge()
    }
}

class NerwHubSidebarView: NSView {
    weak var delegate: NerwHubSidebarDelegate?

    private let visualEffect = NSVisualEffectView()
    private let stackView = NSStackView()
    private var tabViews: [NerwHubTab: NerwHubSidebarItemView] = [:]
    private var activeTab: NerwHubTab = .memory
    private let toggleButton = LiquidDropletButton(
        symbolName: "sidebar.leading", pointSize: 13, tooltip: "Toggle Sidebar (⌘S)",
        cornerRadius: 14
    )

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

        visualEffect.translatesAutoresizingMaskIntoConstraints = false
        visualEffect.material = .sidebar
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        addSubview(visualEffect)

        toggleButton.onClick = { [weak self] in
            self?.delegate?.sidebarDidToggle()
        }
        addSubview(toggleButton)

        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 2
        stackView.edgeInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        addSubview(stackView)

        // Top padding to sit naturally below macOS traffic lights
        NSLayoutConstraint.activate([
            visualEffect.topAnchor.constraint(equalTo: topAnchor),
            visualEffect.bottomAnchor.constraint(equalTo: bottomAnchor),
            visualEffect.leadingAnchor.constraint(equalTo: leadingAnchor),
            visualEffect.trailingAnchor.constraint(equalTo: trailingAnchor),

            // Sidebar toggle button on top right of the sidebar
            toggleButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            toggleButton.centerYAnchor.constraint(equalTo: topAnchor, constant: 25),
            toggleButton.widthAnchor.constraint(equalToConstant: 28),
            toggleButton.heightAnchor.constraint(equalToConstant: 28),

            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 58),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])

        let tabs = NerwHubTab.allCases
        for (index, tab) in tabs.enumerated() {
            let shortcut = "⌘\(index + 1)"
            let itemView = NerwHubSidebarItemView(tab: tab, shortcutText: shortcut)
            itemView.onClick = { [weak self] selectedTab in
                self?.select(tab: selectedTab)
                self?.delegate?.sidebarDidSelect(tab: selectedTab)
            }
            stackView.addArrangedSubview(itemView)
            itemView.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
            tabViews[tab] = itemView
        }

        select(tab: .memory)
    }

    func select(tab: NerwHubTab) {
        activeTab = tab
        for (t, view) in tabViews {
            view.isSelected = (t == tab)
        }
    }

    func updateCount(for tab: NerwHubTab, count: Int) {
        tabViews[tab]?.badgeCount = count
    }
}
