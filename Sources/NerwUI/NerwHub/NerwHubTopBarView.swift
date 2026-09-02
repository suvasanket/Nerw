import Cocoa
import NerwCore
import QuartzCore

protocol NerwHubTopBarDelegate: AnyObject {
    func topBarSearchQueryDidChange(_ query: String)
    func topBarDidClickCommandPalette()
    func topBarDidToggleSidebar()
}

class LiquidDropletButton: NSControl {
    var onClick: (() -> Void)?

    private let iconImageView = NSImageView()
    private var isHovered = false
    private var isPressed = false
    private var trackingArea: NSTrackingArea?

    init(
        symbolName: String = "command.circle",
        pointSize: CGFloat = 15,
        tooltip: String? = nil,
        cornerRadius: CGFloat = 14
    ) {
        super.init(frame: .zero)
        setup(
            symbolName: symbolName, pointSize: pointSize, tooltip: tooltip,
            cornerRadius: cornerRadius)
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup(symbolName: "command.circle", pointSize: 15, tooltip: nil, cornerRadius: 14)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup(
        symbolName: String, pointSize: CGFloat, tooltip: String?, cornerRadius: CGFloat
    ) {
        wantsLayer = true
        translatesAutoresizingMaskIntoConstraints = false

        layer?.cornerRadius = cornerRadius
        layer?.masksToBounds = false
        layer?.backgroundColor = NSColor.white.withAlphaComponent(0.06).cgColor
        layer?.borderColor = NSColor.white.withAlphaComponent(0.12).cgColor
        layer?.borderWidth = 1.0

        // Liquid glass shadow / inner glow
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.2
        layer?.shadowOffset = CGSize(width: 0, height: -1)
        layer?.shadowRadius = 3

        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.imageScaling = .scaleProportionallyDown
        let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .regular)
        iconImageView.image = NSImage(
            systemSymbolName: symbolName, accessibilityDescription: tooltip
        )?.withSymbolConfiguration(config)
        iconImageView.contentTintColor = NSColor.white.withAlphaComponent(0.8)
        addSubview(iconImageView)

        if let tooltip = tooltip {
            toolTip = tooltip
        }

        NSLayoutConstraint.activate([
            iconImageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: pointSize + 5),
            iconImageView.heightAnchor.constraint(equalToConstant: pointSize + 5),
        ])
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking = trackingArea {
            removeTrackingArea(tracking)
        }
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea!)
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        animateDroplet(bgAlpha: 0.12, borderAlpha: 0.22, iconAlpha: 1.0)
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        isPressed = false
        animateDroplet(bgAlpha: 0.06, borderAlpha: 0.12, iconAlpha: 0.8)
    }

    override func mouseDown(with event: NSEvent) {
        isPressed = true
        animateDroplet(bgAlpha: 0.20, borderAlpha: 0.32, iconAlpha: 1.0, duration: 0.06)
    }

    override func mouseUp(with event: NSEvent) {
        if isPressed {
            isPressed = false
            let mouseInView = bounds.contains(convert(event.locationInWindow, from: nil))
            if mouseInView {
                animateDroplet(bgAlpha: 0.12, borderAlpha: 0.22, iconAlpha: 1.0, duration: 0.1)
                onClick?()
            } else {
                animateDroplet(bgAlpha: 0.06, borderAlpha: 0.12, iconAlpha: 0.8, duration: 0.1)
            }
        }
    }

    private func animateDroplet(
        bgAlpha: CGFloat, borderAlpha: CGFloat, iconAlpha: CGFloat,
        duration: TimeInterval = 0.15
    ) {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = duration
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.layer?.backgroundColor = NSColor.white.withAlphaComponent(bgAlpha).cgColor
            self.layer?.borderColor = NSColor.white.withAlphaComponent(borderAlpha).cgColor
            self.iconImageView.contentTintColor = NSColor.white.withAlphaComponent(iconAlpha)
        }
    }
}

class NerwHubTopBarView: NSView, NSSearchFieldDelegate {
    weak var delegate: NerwHubTopBarDelegate?

    private let toggleSidebarButton = LiquidDropletButton(
        symbolName: "sidebar.leading", pointSize: 13, tooltip: "Toggle Sidebar (⌘S)",
        cornerRadius: 14
    )
    private let titleLabel = NSTextField(labelWithString: "")
    let searchField: NSSearchField = {
        let field = NSSearchField()
        (field.cell as? NSSearchFieldCell)?.searchButtonCell = nil
        (field.cell as? NSSearchFieldCell)?.cancelButtonCell = nil
        return field
    }()
    private let searchContainer = NSView()
    private let commandPaletteButton = LiquidDropletButton(
        symbolName: "command.circle", pointSize: 15, tooltip: "Command Palette (⌘K)",
        cornerRadius: 15
    )

    private var titleLeadingWithSidebarConstraint: NSLayoutConstraint!
    private var titleLeadingWithoutSidebarConstraint: NSLayoutConstraint!

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

        // Toggle sidebar button (visible only when sidebar is collapsed)
        toggleSidebarButton.isHidden = true
        toggleSidebarButton.onClick = { [weak self] in
            self?.delegate?.topBarDidToggleSidebar()
        }
        addSubview(toggleSidebarButton)

        // Tab Title (Bigger font and Bold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 22, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        titleLabel.isEditable = false
        titleLabel.isSelectable = false
        titleLabel.drawsBackground = false
        titleLabel.isBezeled = false
        addSubview(titleLabel)

        // Command palette liquid droplet button (positioned to the left of the search bar)
        commandPaletteButton.onClick = { [weak self] in
            self?.delegate?.topBarDidClickCommandPalette()
        }
        addSubview(commandPaletteButton)

        // Search container pill
        searchContainer.translatesAutoresizingMaskIntoConstraints = false
        searchContainer.wantsLayer = true
        searchContainer.layer?.cornerRadius = 14
        searchContainer.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.06).cgColor
        searchContainer.layer?.borderColor = NSColor.white.withAlphaComponent(0.12).cgColor
        searchContainer.layer?.borderWidth = 1.0
        addSubview(searchContainer)

        let searchIcon = NSImageView()
        searchIcon.translatesAutoresizingMaskIntoConstraints = false
        let iconConfig = NSImage.SymbolConfiguration(pointSize: 11, weight: .regular)
        searchIcon.image = NSImage(
            systemSymbolName: "magnifyingglass", accessibilityDescription: nil
        )?.withSymbolConfiguration(iconConfig)
        searchIcon.contentTintColor = .tertiaryLabelColor
        searchContainer.addSubview(searchIcon)

        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.focusRingType = .none
        searchField.isBordered = false
        searchField.drawsBackground = false
        searchField.font = .systemFont(ofSize: 12)
        searchField.placeholderString = "Search..."
        searchField.delegate = self
        searchContainer.addSubview(searchField)

        let searchWidthConstraint = searchContainer.widthAnchor.constraint(equalToConstant: 210)
        searchWidthConstraint.priority = .defaultHigh

        titleLeadingWithSidebarConstraint = titleLabel.leadingAnchor.constraint(
            equalTo: leadingAnchor, constant: 20)
        titleLeadingWithoutSidebarConstraint = titleLabel.leadingAnchor.constraint(
            equalTo: toggleSidebarButton.trailingAnchor, constant: 12)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 52),

            // Toggle sidebar button (at x=84, right after traffic lights when collapsed)
            toggleSidebarButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 84),
            toggleSidebarButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            toggleSidebarButton.widthAnchor.constraint(equalToConstant: 28),
            toggleSidebarButton.heightAnchor.constraint(equalToConstant: 28),

            // Tab title on the left
            titleLeadingWithSidebarConstraint,
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleLabel.trailingAnchor.constraint(
                lessThanOrEqualTo: commandPaletteButton.leadingAnchor, constant: -12),

            // Search pill on the far right
            searchContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -18),
            searchContainer.centerYAnchor.constraint(equalTo: centerYAnchor),
            searchWidthConstraint,
            searchContainer.widthAnchor.constraint(greaterThanOrEqualToConstant: 120),
            searchContainer.heightAnchor.constraint(equalToConstant: 28),

            // Command palette button to the left of the search bar
            commandPaletteButton.trailingAnchor.constraint(
                equalTo: searchContainer.leadingAnchor, constant: -10),
            commandPaletteButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            commandPaletteButton.widthAnchor.constraint(equalToConstant: 30),
            commandPaletteButton.heightAnchor.constraint(equalToConstant: 30),

            searchIcon.leadingAnchor.constraint(
                equalTo: searchContainer.leadingAnchor, constant: 9),
            searchIcon.centerYAnchor.constraint(equalTo: searchContainer.centerYAnchor),
            searchIcon.widthAnchor.constraint(equalToConstant: 12),
            searchIcon.heightAnchor.constraint(equalToConstant: 12),

            searchField.leadingAnchor.constraint(equalTo: searchIcon.trailingAnchor, constant: 6),
            searchField.trailingAnchor.constraint(
                equalTo: searchContainer.trailingAnchor, constant: -8),
            searchField.centerYAnchor.constraint(equalTo: searchContainer.centerYAnchor),
        ])
    }

    func setSidebarCollapsed(_ collapsed: Bool) {
        toggleSidebarButton.isHidden = !collapsed
        titleLeadingWithSidebarConstraint.isActive = !collapsed
        titleLeadingWithoutSidebarConstraint.isActive = collapsed
    }

    func updateTab(_ tab: NerwHubTab) {
        titleLabel.stringValue = tab.rawValue
        searchField.placeholderString = "Search \(tab.rawValue)..."
    }

    func clearSearch() {
        searchField.stringValue = ""
        delegate?.topBarSearchQueryDidChange("")
    }

    func focusSearchField() {
        window?.makeFirstResponder(searchField)
    }

    func unfocusSearchField() {
        window?.makeFirstResponder(window?.contentView)
    }

    // MARK: - NSSearchFieldDelegate

    func controlTextDidChange(_ obj: Notification) {
        let query = searchField.stringValue
        delegate?.topBarSearchQueryDidChange(query)
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector)
        -> Bool
    {
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            unfocusSearchField()
            return true
        }
        return false
    }
}
