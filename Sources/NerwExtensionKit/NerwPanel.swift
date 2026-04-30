import Cocoa
import Foundation

// MARK: - Color Helpers (internal to NerwPanel)

extension NSColor {
    /// Initialize from a hex string like "#RRGGBB".
    fileprivate convenience init?(nerwHex hex: String) {
        var str = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if str.hasPrefix("#") { str.removeFirst() }
        guard str.count == 6, let value = UInt64(str, radix: 16) else { return nil }
        let r = CGFloat((value >> 16) & 0xFF) / 255.0
        let g = CGFloat((value >> 8) & 0xFF) / 255.0
        let b = CGFloat(value & 0xFF) / 255.0
        self.init(srgbRed: r, green: g, blue: b, alpha: 1.0)
    }
}

// MARK: - NerwPanel

/// A themed, borderless floating panel that matches the Nerw host's glassmorphic
/// aesthetic.  Extensions create this in their own process — no IPC needed.
///
/// Usage:
/// ```swift
/// let theme = NerwThemeConfig(from: input.settings)
/// let panel = NerwPanel(theme: theme)
/// panel.setContent(myView)
/// panel.show()          // Blocks until the panel is dismissed
/// ```
public class NerwPanel: NSPanel {

    /// A plain `NSView` that extensions add their content to.
    public let contentArea: NSView = NSView()

    private let theme: NerwThemeConfig
    private let effectView = NSVisualEffectView()
    private let tintView = NSView()
    private var innerGlowView: NSView?
    private var runLoopActive = false

    // MARK: - Init

    /// Create a themed panel with default size matching the host's main panel.
    /// - Parameters:
    ///   - theme: The `NerwThemeConfig` parsed from `input.settings`.
    ///   - width: Custom width override. Defaults to `theme.mainPanelWidth`.
    ///   - height: Custom height override. Defaults to `theme.mainPanelHeight`.
    public init(theme: NerwThemeConfig, width: Double? = nil, height: Double? = nil) {
        self.theme = theme

        let w = CGFloat(width ?? theme.mainPanelWidth)
        let h = CGFloat(height ?? theme.mainPanelHeight)

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: w, height: h),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        // Panel properties
        self.level = .floating
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.isMovableByWindowBackground = false
        self.hidesOnDeactivate = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        buildViews(width: w, height: h)
        positionPanel(width: w, height: h)
    }

    // MARK: - Key Window

    public override var canBecomeKey: Bool { true }
    public override var canBecomeMain: Bool { true }

    public override func resignKey() {
        super.resignKey()
        DispatchQueue.main.async { [weak self] in
            self?.dismiss()
        }
    }

    public override func cancelOperation(_ sender: Any?) {
        dismiss()
    }

    // MARK: - Public API

    /// Replace the panel's content area with a custom view.
    public func setContent(_ view: NSView) {
        // Remove existing subviews
        for sub in contentArea.subviews { sub.removeFromSuperview() }

        view.translatesAutoresizingMaskIntoConstraints = false
        contentArea.addSubview(view)
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: contentArea.topAnchor),
            view.leadingAnchor.constraint(equalTo: contentArea.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: contentArea.trailingAnchor),
            view.bottomAnchor.constraint(equalTo: contentArea.bottomAnchor),
        ])
    }

    /// Show the panel and block until it is dismissed (via Esc or click-outside).
    /// Runs `NSApplication.shared.run()` internally so the extension process
    /// stays alive while the panel is visible.
    public func show() {
        NSLog("[NerwPanel] show() called. Current frame: \(frame)")
        positionPanel(width: frame.width, height: frame.height)
        NSLog("[NerwPanel] Repositioned to frame: \(frame)")
        makeKeyAndOrderFront(nil)
        runLoopActive = true
        NSApplication.shared.run()
    }

    /// Dismiss the panel and stop the run loop.
    public func dismiss() {
        guard isVisible else { return }
        orderOut(nil)
        if runLoopActive {
            runLoopActive = false
            NSApplication.shared.stop(nil)
            // Post a dummy event to unblock the run loop immediately.
            let event = NSEvent.otherEvent(
                with: .applicationDefined,
                location: .zero,
                modifierFlags: [],
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                subtype: 0,
                data1: 0,
                data2: 0
            )
            if let event = event {
                NSApplication.shared.postEvent(event, atStart: true)
            }
        }
    }

    // MARK: - Helpers

    /// Resolve the body font: uses `theme.fontName` if available, else system font.
    public func bodyFont(size: Double? = nil) -> NSFont {
        let sz = CGFloat(size ?? theme.resultTitleFontSize)
        if let name = theme.fontName, let f = NSFont(name: name, size: sz) { return f }
        return .systemFont(ofSize: sz, weight: .regular)
    }

    /// Resolve the foreground (text) color from theme.
    public var foregroundColor: NSColor {
        if let hex = theme.foregroundColorHex, let c = NSColor(nerwHex: hex) { return c }
        return .labelColor
    }

    /// Resolve the secondary (hint) text color from theme.
    public var secondaryColor: NSColor {
        if let hex = theme.hintColorHex, let c = NSColor(nerwHex: hex) { return c }
        return .secondaryLabelColor
    }

    // MARK: - Private Build

    private func buildViews(width: CGFloat, height: CGFloat) {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        container.wantsLayer = true

        let radius = CGFloat(theme.cornerRadius)

        // Effect View (blur background)
        effectView.translatesAutoresizingMaskIntoConstraints = false
        effectView.material = .fullScreenUI
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = radius
        effectView.layer?.masksToBounds = true
        container.addSubview(effectView)

        // Border
        let borderColor = NSColor(nerwHex: theme.borderColorHex)?
            .withAlphaComponent(CGFloat(theme.borderOpacity))
        effectView.layer?.borderColor = borderColor?.cgColor
        effectView.layer?.borderWidth = CGFloat(theme.borderWidth)

        // Tint overlay
        tintView.translatesAutoresizingMaskIntoConstraints = false
        tintView.wantsLayer = true
        if let hex = theme.tintColorHex, let c = NSColor(nerwHex: hex) {
            tintView.layer?.backgroundColor =
                c.withAlphaComponent(CGFloat(theme.tintOpacity)).cgColor
        } else {
            tintView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.15).cgColor
        }
        effectView.addSubview(tintView)

        // Inner glow
        if theme.innerGlowEnabled {
            let glow = NSView()
            glow.wantsLayer = true
            glow.layer?.masksToBounds = true
            glow.layer?.cornerRadius = max(0, radius - 1)
            glow.translatesAutoresizingMaskIntoConstraints = false
            let glowColor = NSColor(nerwHex: theme.innerGlowColorHex)?
                .withAlphaComponent(CGFloat(theme.innerGlowOpacity))
            glow.layer?.borderColor = glowColor?.cgColor
            glow.layer?.borderWidth = 1.0
            effectView.addSubview(glow)
            innerGlowView = glow
        }

        // Content area
        contentArea.translatesAutoresizingMaskIntoConstraints = false
        effectView.addSubview(contentArea)

        // Constraints
        NSLayoutConstraint.activate([
            effectView.topAnchor.constraint(equalTo: container.topAnchor),
            effectView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            effectView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            effectView.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            tintView.topAnchor.constraint(equalTo: effectView.topAnchor),
            tintView.leadingAnchor.constraint(equalTo: effectView.leadingAnchor),
            tintView.trailingAnchor.constraint(equalTo: effectView.trailingAnchor),
            tintView.bottomAnchor.constraint(equalTo: effectView.bottomAnchor),

            contentArea.topAnchor.constraint(equalTo: effectView.topAnchor),
            contentArea.leadingAnchor.constraint(equalTo: effectView.leadingAnchor),
            contentArea.trailingAnchor.constraint(equalTo: effectView.trailingAnchor),
            contentArea.bottomAnchor.constraint(equalTo: effectView.bottomAnchor),
        ])

        if let glow = innerGlowView {
            NSLayoutConstraint.activate([
                glow.topAnchor.constraint(equalTo: effectView.topAnchor, constant: 1),
                glow.leadingAnchor.constraint(equalTo: effectView.leadingAnchor, constant: 1),
                glow.trailingAnchor.constraint(equalTo: effectView.trailingAnchor, constant: -1),
                glow.bottomAnchor.constraint(equalTo: effectView.bottomAnchor, constant: -1),
            ])
        }

        self.contentView = container
    }

    private func positionPanel(width: CGFloat, height: CGFloat) {
        let screen: NSRect
        if theme.screenVisibleWidth > 0 {
            screen = NSRect(
                x: theme.screenVisibleX, y: theme.screenVisibleY, width: theme.screenVisibleWidth,
                height: theme.screenVisibleHeight)
        } else {
            screen = NSScreen.main?.visibleFrame ?? .zero
        }

        NSLog(
            "[NerwPanel] Positioning. Screen: \(screen), theme.mainPanelFrameHeight: \(theme.mainPanelFrameHeight)"
        )

        let targetTopY: CGFloat
        if theme.mainPanelFrameHeight > 0 {
            // EXACT top edge of the main panel as reported by the host
            targetTopY = CGFloat(theme.mainPanelOriginY + theme.mainPanelFrameHeight)
            NSLog("[NerwPanel] Using host-provided top edge: \(targetTopY)")
        } else {
            // Fallback to visual center calculation
            let visualCenterY = screen.origin.y + screen.height / 2 + screen.height * 0.30
            let searchBarHeight = CGFloat(
                theme.searchFieldTopMargin + theme.searchFieldHeight + theme.searchFieldBottomMargin
            )
            targetTopY = visualCenterY + searchBarHeight / 2
            NSLog("[NerwPanel] Falling back to visual center: \(targetTopY)")
        }

        let targetY = targetTopY - height

        var targetX = screen.origin.x + (screen.width - width) / 2
        if theme.mainPanelFrameWidth > 0 {
            let mainMidX = CGFloat(theme.mainPanelOriginX) + CGFloat(theme.mainPanelFrameWidth) / 2
            targetX = mainMidX - width / 2
            NSLog("[NerwPanel] Using host-provided X: \(targetX)")
        }

        NSLog("[NerwPanel] Setting frame origin: (\(targetX), \(targetY))")
        setFrameOrigin(NSPoint(x: targetX, y: targetY))
    }
}
