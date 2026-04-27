import Cocoa
import NerwCore

public class NerwPanelView: NSView {
    public let contentView: NSView

    private let effectView: NSVisualEffectView
    private let tintView: NSView
    private let innerGlowView: NSView?
    private let containerView: NSView?  // Only used if clipToBounds is true

    public struct Style {
        public var innerGlowEnabled: Bool = false
        public var cornerRadiusOverride: CGFloat? = nil
        public var clipToBounds: Bool = false
        public var backgroundMaterial: NSVisualEffectView.Material = .fullScreenUI
        public var shadowOffset: NSSize? = nil
        public var shadowRadius: CGFloat? = nil
        public var shadowOpacity: Float? = nil

        public static let main = Style(innerGlowEnabled: true)
        public static let splitPane = Style()
        public static let actionContext = Style()
        public static let notification = Style(
            clipToBounds: true,
            backgroundMaterial: .popover,
            shadowOffset: NSSize(width: 0, height: -4),
            shadowRadius: 8,
            shadowOpacity: 0.2
        )
        public static let `default` = Style()
    }

    private let style: Style

    public init(style: Style = .default) {
        self.style = style
        self.contentView = NSView()
        self.effectView = NSVisualEffectView()
        self.tintView = NSView()
        self.innerGlowView = style.innerGlowEnabled ? NSView() : nil
        self.containerView = style.clipToBounds ? NSView() : nil

        super.init(frame: .zero)
        setupViews()
        applyTheme()

        NotificationCenter.default.addObserver(
            self, selector: #selector(configDidUpdate),
            name: Notification.Name("NerwConfigDidUpdate"), object: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        self.wantsLayer = true

        if style.shadowRadius != nil {
            self.layer?.masksToBounds = false
            let shadow = NSShadow()
            shadow.shadowColor = NSColor.black.withAlphaComponent(
                CGFloat(style.shadowOpacity ?? 0.2))
            shadow.shadowOffset = style.shadowOffset ?? .zero
            shadow.shadowBlurRadius = style.shadowRadius ?? 0
            self.shadow = shadow
        }

        // Base view to add things to
        let baseView: NSView

        if let container = containerView {
            container.translatesAutoresizingMaskIntoConstraints = false
            container.wantsLayer = true
            container.layer?.masksToBounds = true
            container.layer?.cornerCurve = .continuous
            self.addSubview(container)

            NSLayoutConstraint.activate([
                container.leadingAnchor.constraint(equalTo: self.leadingAnchor),
                container.trailingAnchor.constraint(equalTo: self.trailingAnchor),
                container.topAnchor.constraint(equalTo: self.topAnchor),
                container.bottomAnchor.constraint(equalTo: self.bottomAnchor),
            ])

            baseView = container
        } else {
            baseView = self
        }

        // Effect View
        effectView.translatesAutoresizingMaskIntoConstraints = false
        effectView.material = style.backgroundMaterial
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        effectView.wantsLayer = true
        baseView.addSubview(effectView)

        NSLayoutConstraint.activate([
            effectView.leadingAnchor.constraint(equalTo: baseView.leadingAnchor),
            effectView.trailingAnchor.constraint(equalTo: baseView.trailingAnchor),
            effectView.topAnchor.constraint(equalTo: baseView.topAnchor),
            effectView.bottomAnchor.constraint(equalTo: baseView.bottomAnchor),
        ])

        // Tint View
        tintView.translatesAutoresizingMaskIntoConstraints = false
        tintView.wantsLayer = true
        effectView.addSubview(tintView)

        NSLayoutConstraint.activate([
            tintView.leadingAnchor.constraint(equalTo: effectView.leadingAnchor),
            tintView.trailingAnchor.constraint(equalTo: effectView.trailingAnchor),
            tintView.topAnchor.constraint(equalTo: effectView.topAnchor),
            tintView.bottomAnchor.constraint(equalTo: effectView.bottomAnchor),
        ])

        // Inner Glow
        if let glow = innerGlowView {
            glow.wantsLayer = true
            glow.layer?.masksToBounds = true
            glow.translatesAutoresizingMaskIntoConstraints = false
            effectView.addSubview(glow)

            NSLayoutConstraint.activate([
                glow.topAnchor.constraint(equalTo: effectView.topAnchor, constant: 1),
                glow.leadingAnchor.constraint(equalTo: effectView.leadingAnchor, constant: 1),
                glow.trailingAnchor.constraint(equalTo: effectView.trailingAnchor, constant: -1),
                glow.bottomAnchor.constraint(equalTo: effectView.bottomAnchor, constant: -1),
            ])
        }

        // Content View
        contentView.translatesAutoresizingMaskIntoConstraints = false
        baseView.addSubview(contentView)

        NSLayoutConstraint.activate([
            contentView.leadingAnchor.constraint(equalTo: baseView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: baseView.trailingAnchor),
            contentView.topAnchor.constraint(equalTo: baseView.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: baseView.bottomAnchor),
        ])
    }

    @objc private func configDidUpdate() {
        DispatchQueue.main.async {
            self.applyTheme()
        }
    }

    public func applyTheme() {
        let theme = NerwTheme.current()

        let radius = style.cornerRadiusOverride ?? CGFloat(theme.cornerRadius)

        let targetView = containerView ?? effectView
        targetView.layer?.cornerRadius = radius
        targetView.layer?.masksToBounds = true
        targetView.layer?.borderColor =
            NSColor(hex: theme.borderColorHex)?.withAlphaComponent(CGFloat(theme.borderOpacity))
            .cgColor
        targetView.layer?.borderWidth = CGFloat(theme.borderWidth)

        if let container = containerView {
            effectView.layer?.cornerRadius = radius
            tintView.layer?.cornerRadius = radius
        }

        let tintColor: NSColor
        if let hex = theme.tintColorHex, let customColor = NSColor(hex: hex) {
            tintColor = customColor.withAlphaComponent(CGFloat(theme.tintOpacity))
        } else {
            tintColor = NSColor.black.withAlphaComponent(0.15)
        }
        tintView.layer?.backgroundColor = tintColor.cgColor

        if let glow = innerGlowView {
            glow.layer?.cornerRadius = max(0, radius - 1)
            let glowColor = NSColor(hex: theme.innerGlowColorHex)?.withAlphaComponent(
                CGFloat(theme.innerGlowOpacity))
            glow.layer?.borderColor = glowColor?.cgColor
            glow.layer?.borderWidth = 1.0
        }
    }

    public override func layout() {
        super.layout()
        if style.cornerRadiusOverride != nil {
            applyTheme()
        }
    }
}
