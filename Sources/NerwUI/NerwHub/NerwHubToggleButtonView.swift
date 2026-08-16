import Cocoa

class NerwHubToggleButtonView: NSButton {
    var isMenuOpen: Bool = false

    private let visualEffectView = NSVisualEffectView()
    private let customIconView = NSImageView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        wantsLayer = true
        isBordered = false
        title = ""

        visualEffectView.frame = bounds
        visualEffectView.autoresizingMask = [.width, .height]
        visualEffectView.state = .active
        visualEffectView.material = .popover
        visualEffectView.blendingMode = .withinWindow
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.cornerRadius = 18  // Fixed for 36x36 size
        visualEffectView.layer?.masksToBounds = true
        visualEffectView.layer?.borderWidth = 1.0
        visualEffectView.layer?.borderColor = NSColor.white.withAlphaComponent(0.15).cgColor
        addSubview(visualEffectView)

        customIconView.image = NSImage(
            systemSymbolName: "sidebar.left", accessibilityDescription: "Menu")
        if #available(macOS 12.0, *) {
            customIconView.symbolConfiguration = NSImage.SymbolConfiguration(
                hierarchicalColor: .secondaryLabelColor)
        } else {
            customIconView.contentTintColor = .secondaryLabelColor
        }
        customIconView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(customIconView)

        NSLayoutConstraint.activate([
            customIconView.centerXAnchor.constraint(equalTo: centerXAnchor),
            customIconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            customIconView.widthAnchor.constraint(equalToConstant: 16),
            customIconView.heightAnchor.constraint(equalToConstant: 16),
        ])
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }

    func animateIcon() {
        isMenuOpen.toggle()
    }

    func resetState() {
        if isMenuOpen {
            animateIcon()
        }
    }
}
