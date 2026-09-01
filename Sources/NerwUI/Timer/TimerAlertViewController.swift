import Cocoa
import NerwBuiltin
import NerwCore

public class TimerAlertPanel: NSPanel {
    public var onDismiss: (() -> Void)?
    public var onComplete: (() -> Void)?
    public var onSnooze: (() -> Void)?

    public override var canBecomeKey: Bool { return true }
    public override var canBecomeMain: Bool { return true }

    public override func keyDown(with event: NSEvent) {
        // Enter (36) or Space (49) -> Complete
        if event.keyCode == 36 || event.keyCode == 49 {
            onComplete?()
            return
        }
        // Esc (53) -> Dismiss / Complete
        if event.keyCode == 53 {
            onComplete?()
            return
        }
        // Cmd+S or 's' (1) -> Snooze
        if event.keyCode == 1 {
            onSnooze?()
            return
        }
        // Tab (48) -> Snooze
        if event.keyCode == 48 {
            onSnooze?()
            return
        }

        super.keyDown(with: event)
    }
}

public class TimerAlertViewController: NSViewController {
    public var currentTimer: NerwTimer?
    public var onComplete: (() -> Void)?
    public var onSnooze: (() -> Void)?

    private var panelView: NerwPanelView!
    private let iconContainer = NSView()
    private let iconImageView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "")
    private var completeButton: TimerGlassButton!
    private var snoozeButton: TimerGlassButton!

    public override func loadView() {
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 420, height: 260))
        root.wantsLayer = true
        root.layer?.masksToBounds = false

        // Outer Glow & Shadow
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.4)
        shadow.shadowOffset = NSSize(width: 0, height: -4)
        shadow.shadowBlurRadius = 24
        root.shadow = shadow

        self.view = root
        setupUI()
    }

    private func setupUI() {
        // 1. Frosted Glass Panel Container
        panelView = NerwPanelView(style: .notification)
        panelView.cornerRadiusOverride = 24
        panelView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(panelView)

        NSLayoutConstraint.activate([
            panelView.topAnchor.constraint(equalTo: view.topAnchor),
            panelView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            panelView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            panelView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        let content = panelView.contentView

        // 2. Glowing Icon Container
        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.wantsLayer = true
        iconContainer.layer?.cornerRadius = 28
        iconContainer.layer?.backgroundColor = NSColor.systemOrange.withAlphaComponent(0.18).cgColor
        iconContainer.layer?.borderColor = NSColor.systemOrange.withAlphaComponent(0.35).cgColor
        iconContainer.layer?.borderWidth = 1.0
        content.addSubview(iconContainer)

        iconImageView.image = NSImage(
            systemSymbolName: "timer", accessibilityDescription: "Timer Finished")
        iconImageView.symbolConfiguration = .init(pointSize: 28, weight: .semibold)
        iconImageView.contentTintColor = NSColor.systemOrange
        iconImageView.imageScaling = .scaleProportionallyUpOrDown
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.addSubview(iconImageView)

        // 3. Title Label
        titleLabel.font = .systemFont(ofSize: 20, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.alignment = .center
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.maximumNumberOfLines = 1
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(titleLabel)

        // 4. Subtitle Label
        subtitleLabel.font = .systemFont(ofSize: 13, weight: .medium)
        subtitleLabel.textColor = NSColor.white.withAlphaComponent(0.7)
        subtitleLabel.alignment = .center
        subtitleLabel.lineBreakMode = .byTruncatingTail
        subtitleLabel.maximumNumberOfLines = 2
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(subtitleLabel)

        // 5. Buttons
        completeButton = TimerGlassButton(
            title: "Complete",
            shortcut: "↵",
            isPrimary: true,
            target: self,
            action: #selector(handleCompleteClicked)
        )

        snoozeButton = TimerGlassButton(
            title: "Snooze 5m",
            shortcut: "⌘S",
            isPrimary: false,
            target: self,
            action: #selector(handleSnoozeClicked)
        )

        content.addSubview(completeButton)
        content.addSubview(snoozeButton)

        // Layout Constraints
        NSLayoutConstraint.activate([
            // Icon
            iconContainer.topAnchor.constraint(equalTo: content.topAnchor, constant: 24),
            iconContainer.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            iconContainer.widthAnchor.constraint(equalToConstant: 56),
            iconContainer.heightAnchor.constraint(equalToConstant: 56),

            iconImageView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),

            // Title
            titleLabel.topAnchor.constraint(equalTo: iconContainer.bottomAnchor, constant: 14),
            titleLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),

            // Subtitle
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            subtitleLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            subtitleLabel.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),

            // Buttons at bottom
            completeButton.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -20),
            completeButton.trailingAnchor.constraint(equalTo: content.centerXAnchor, constant: -6),
            completeButton.widthAnchor.constraint(equalToConstant: 160),
            completeButton.heightAnchor.constraint(equalToConstant: 38),

            snoozeButton.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -20),
            snoozeButton.leadingAnchor.constraint(equalTo: content.centerXAnchor, constant: 6),
            snoozeButton.widthAnchor.constraint(equalToConstant: 160),
            snoozeButton.heightAnchor.constraint(equalToConstant: 38),
        ])
    }

    public func configure(with timer: NerwTimer) {
        self.currentTimer = timer

        let displayLabel =
            timer.label.isEmpty || timer.label.lowercased() == "timer"
            ? "Timer Finished"
            : timer.label

        titleLabel.stringValue = displayLabel

        let durStr = TimerParser.shared.formatDuration(timer.totalDuration)
        let endStr = TimerParser.shared.formatTargetTime(timer.targetDate)
        subtitleLabel.stringValue = "\(durStr) completed at \(endStr)"
    }

    public func animateIconPulse() {
        let animation = CAKeyframeAnimation(keyPath: "transform.scale")
        animation.values = [1.0, 1.15, 0.95, 1.05, 1.0]
        animation.keyTimes = [0.0, 0.25, 0.5, 0.75, 1.0]
        animation.duration = 0.6
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        iconContainer.layer?.add(animation, forKey: "pulse")
    }

    @objc private func handleCompleteClicked() {
        onComplete?()
    }

    @objc private func handleSnoozeClicked() {
        onSnooze?()
    }
}

private class TimerGlassButton: NSControl {
    private let isPrimary: Bool
    private var baseColor: NSColor
    private var hoverColor: NSColor
    private var clickColor: NSColor
    private var backgroundLayer: CALayer?
    private var trackingArea: NSTrackingArea?

    init(
        title: String,
        shortcut: String,
        isPrimary: Bool,
        target: AnyObject?,
        action: Selector?
    ) {
        self.isPrimary = isPrimary
        if isPrimary {
            self.baseColor = NSColor.systemOrange.withAlphaComponent(0.85)
            self.hoverColor = NSColor.systemOrange
            self.clickColor = NSColor.systemOrange.withAlphaComponent(0.7)
        } else {
            self.baseColor = NSColor.white.withAlphaComponent(0.12)
            self.hoverColor = NSColor.white.withAlphaComponent(0.22)
            self.clickColor = NSColor.white.withAlphaComponent(0.32)
        }

        super.init(frame: .zero)
        self.target = target
        self.action = action

        setup(title: title, shortcut: shortcut)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setup(title: String, shortcut: String) {
        self.translatesAutoresizingMaskIntoConstraints = false
        self.wantsLayer = true
        self.layer?.cornerRadius = 10
        self.layer?.masksToBounds = true

        let bg = NSView()
        bg.translatesAutoresizingMaskIntoConstraints = false
        bg.wantsLayer = true
        bg.layer?.backgroundColor = baseColor.cgColor
        bg.layer?.cornerRadius = 10
        self.addSubview(bg)
        self.backgroundLayer = bg.layer

        let stack = NSStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 6
        self.addSubview(stack)

        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 14, weight: isPrimary ? .semibold : .medium)
        label.textColor = isPrimary ? .black : .white
        label.alignment = .center
        stack.addArrangedSubview(label)

        let badge = NSTextField(labelWithString: shortcut)
        badge.font = .systemFont(ofSize: 11, weight: .bold)
        badge.textColor =
            isPrimary
            ? NSColor.black.withAlphaComponent(0.6) : NSColor.white.withAlphaComponent(0.6)
        stack.addArrangedSubview(badge)

        NSLayoutConstraint.activate([
            bg.topAnchor.constraint(equalTo: self.topAnchor),
            bg.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            bg.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            bg.bottomAnchor.constraint(equalTo: self.bottomAnchor),

            stack.centerXAnchor.constraint(equalTo: self.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: self.centerYAnchor),
        ])
    }

    public override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea { removeTrackingArea(existing) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        self.trackingArea = area
    }

    public override func mouseEntered(with event: NSEvent) {
        backgroundLayer?.backgroundColor = hoverColor.cgColor
    }

    public override func mouseExited(with event: NSEvent) {
        backgroundLayer?.backgroundColor = baseColor.cgColor
    }

    public override func mouseDown(with event: NSEvent) {
        backgroundLayer?.backgroundColor = clickColor.cgColor
    }

    public override func mouseUp(with event: NSEvent) {
        backgroundLayer?.backgroundColor = hoverColor.cgColor
        if bounds.contains(convert(event.locationInWindow, from: nil)) {
            sendAction(action, to: target)
        }
    }
}
