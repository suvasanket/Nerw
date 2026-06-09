import Cocoa
import NerwCore

public class NerwPanelView: NSView {
    public let contentView: NSView

    private var legacyEffectView: NSVisualEffectView?
    private var glassEffectView: NSView?
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
        public var useGlassEffect: Bool = true

        public static let main = Style(innerGlowEnabled: true)
        public static let splitPane = Style()
        public static let actionContext = Style()
        public static let notification = Style(
            innerGlowEnabled: true,
            clipToBounds: true,
            backgroundMaterial: .popover,
            shadowOffset: NSSize(width: 0, height: 0),
            shadowRadius: 12,
            shadowOpacity: 0.25
        )
        public static let `default` = Style()
    }

    private let style: Style
    public var cornerRadiusOverride: CGFloat? {
        didSet {
            applyTheme()
        }
    }

    public init(style: Style = .default) {
        self.style = style
        self.contentView = NSView()
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
        let activeEffectView: NSView

        if #available(macOS 26.0, *), style.useGlassEffect, NerwTheme.current().liquidGlassEnabled {
            let glass = NSGlassEffectView()
            glass.style = .regular
            glass.appearance = NSAppearance(named: .vibrantDark)
            glass.translatesAutoresizingMaskIntoConstraints = false
            baseView.addSubview(glass)
            self.glassEffectView = glass
            activeEffectView = glass
        } else {
            let legacy = NSVisualEffectView()
            legacy.material = style.backgroundMaterial
            legacy.appearance = NSAppearance(named: .vibrantDark)
            legacy.blendingMode = .behindWindow
            legacy.state = .active
            legacy.wantsLayer = true
            legacy.translatesAutoresizingMaskIntoConstraints = false
            baseView.addSubview(legacy)
            self.legacyEffectView = legacy
            activeEffectView = legacy
        }

        NSLayoutConstraint.activate([
            activeEffectView.leadingAnchor.constraint(equalTo: baseView.leadingAnchor),
            activeEffectView.trailingAnchor.constraint(equalTo: baseView.trailingAnchor),
            activeEffectView.topAnchor.constraint(equalTo: baseView.topAnchor),
            activeEffectView.bottomAnchor.constraint(equalTo: baseView.bottomAnchor),
        ])

        // Tint View
        tintView.translatesAutoresizingMaskIntoConstraints = false
        tintView.wantsLayer = true
        activeEffectView.addSubview(tintView)

        NSLayoutConstraint.activate([
            tintView.leadingAnchor.constraint(equalTo: activeEffectView.leadingAnchor),
            tintView.trailingAnchor.constraint(equalTo: activeEffectView.trailingAnchor),
            tintView.topAnchor.constraint(equalTo: activeEffectView.topAnchor),
            tintView.bottomAnchor.constraint(equalTo: activeEffectView.bottomAnchor),
        ])

        // Inner Glow
        if let glow = innerGlowView {
            glow.wantsLayer = true
            glow.layer?.masksToBounds = true
            glow.translatesAutoresizingMaskIntoConstraints = false
            activeEffectView.addSubview(glow)

            NSLayoutConstraint.activate([
                glow.topAnchor.constraint(equalTo: activeEffectView.topAnchor, constant: 1),
                glow.leadingAnchor.constraint(equalTo: activeEffectView.leadingAnchor, constant: 1),
                glow.trailingAnchor.constraint(
                    equalTo: activeEffectView.trailingAnchor, constant: -1),
                glow.bottomAnchor.constraint(equalTo: activeEffectView.bottomAnchor, constant: -1),
            ])
        }

        // Content View
        contentView.translatesAutoresizingMaskIntoConstraints = false
        activeEffectView.addSubview(contentView)

        NSLayoutConstraint.activate([
            contentView.leadingAnchor.constraint(equalTo: activeEffectView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: activeEffectView.trailingAnchor),
            contentView.topAnchor.constraint(equalTo: activeEffectView.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: activeEffectView.bottomAnchor),
        ])
    }

    @objc private func configDidUpdate() {
        DispatchQueue.main.async {
            self.applyTheme()
        }
    }

    public func applyTheme() {
        let theme = NerwTheme.current()

        let radius =
            cornerRadiusOverride ?? style.cornerRadiusOverride ?? CGFloat(theme.cornerRadius)

        let targetView = containerView ?? legacyEffectView ?? self

        let isGlass = glassEffectView != nil

        if isGlass {
            if #available(macOS 26.0, *) {
                if let glass = glassEffectView as? NSGlassEffectView {
                    glass.cornerRadius = radius
                }
            }
            targetView.layer?.cornerRadius = radius
            targetView.layer?.masksToBounds = true
            targetView.layer?.borderColor = NSColor.clear.cgColor
            targetView.layer?.borderWidth = 0

            if containerView != nil {
                tintView.layer?.cornerRadius = radius
            }
        } else {
            targetView.layer?.cornerRadius = radius
            targetView.layer?.masksToBounds = true
            targetView.layer?.borderColor =
                NSColor(hex: theme.borderColorHex)?.withAlphaComponent(CGFloat(theme.borderOpacity))
                .cgColor
            targetView.layer?.borderWidth = CGFloat(theme.borderWidth)

            if containerView != nil {
                legacyEffectView?.layer?.cornerRadius = radius
                tintView.layer?.cornerRadius = radius
            }
        }

        let tintColor: NSColor
        if let hex = theme.tintColorHex, let customColor = NSColor(hex: hex) {
            tintColor = customColor.withAlphaComponent(CGFloat(theme.tintOpacity))
        } else {
            tintColor = NSColor.black.withAlphaComponent(0.15)
        }
        tintView.layer?.backgroundColor = tintColor.cgColor

        if let glow = innerGlowView {
            glow.isHidden = isGlass
            if !isGlass {
                glow.layer?.cornerRadius = max(0, radius - 1)
                let glowColor = NSColor(hex: theme.innerGlowColorHex)?.withAlphaComponent(
                    CGFloat(theme.innerGlowOpacity))
                glow.layer?.borderColor = glowColor?.cgColor
                glow.layer?.borderWidth = 1.0
            }
        }
    }

    public override func layout() {
        super.layout()
        if style.cornerRadiusOverride != nil {
            applyTheme()
        }
    }
}
