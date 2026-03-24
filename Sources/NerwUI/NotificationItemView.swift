import Cocoa
import NerwCore

public class NotificationItemView: NSView {
    public let id: UUID
    private var progressIndicator: NSProgressIndicator?
    private var effectView: NSVisualEffectView!
    private var tintView: NSView!
    private var textField: NSTextField!

    public init(id: UUID, content: String, level: NerwNotificationLevel, progressive: Bool) {
        self.id = id
        // Initial frame; Auto Layout will resize it based on intrinsic content.
        super.init(frame: NSRect(x: 0, y: 0, width: 320, height: 50))
        setupView(content: content, level: level, progressive: progressive)
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupView(content: String, level: NerwNotificationLevel, progressive: Bool) {
        self.wantsLayer = true
        self.layer?.cornerRadius = 12
        self.layer?.cornerCurve = .continuous
        self.layer?.masksToBounds = true
        self.layer?.borderWidth = 1
        self.layer?.borderColor = NSColor.white.withAlphaComponent(0.2).cgColor

        // Add subtle shadow for the "liquid glass" floating feel
        self.shadow = NSShadow()
        self.shadow?.shadowColor = NSColor.black.withAlphaComponent(0.2)
        self.shadow?.shadowOffset = NSSize(width: 0, height: -4)
        self.shadow?.shadowBlurRadius = 8

        // 1. Frosted Glass Background
        effectView = NSVisualEffectView()
        effectView.translatesAutoresizingMaskIntoConstraints = false
        effectView.material = .popover
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        self.addSubview(effectView)

        // 2. Tint View based on level
        tintView = NSView()
        tintView.translatesAutoresizingMaskIntoConstraints = false
        tintView.wantsLayer = true

        switch level {
        case .warn:
            tintView.layer?.backgroundColor = NSColor.systemYellow.withAlphaComponent(0.2).cgColor
        case .error:
            tintView.layer?.backgroundColor = NSColor.systemRed.withAlphaComponent(0.2).cgColor
        case .info:
            tintView.layer?.backgroundColor = NSColor.clear.cgColor
        }
        effectView.addSubview(tintView)

        // 3. Content Stack
        let stackView = NSStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.orientation = .horizontal
        stackView.alignment = .centerY
        stackView.spacing = 10
        stackView.edgeInsets = NSEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
        effectView.addSubview(stackView)

        NSLayoutConstraint.activate([
            effectView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            effectView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            effectView.topAnchor.constraint(equalTo: self.topAnchor),
            effectView.bottomAnchor.constraint(equalTo: self.bottomAnchor),

            tintView.leadingAnchor.constraint(equalTo: effectView.leadingAnchor),
            tintView.trailingAnchor.constraint(equalTo: effectView.trailingAnchor),
            tintView.topAnchor.constraint(equalTo: effectView.topAnchor),
            tintView.bottomAnchor.constraint(equalTo: effectView.bottomAnchor),

            stackView.leadingAnchor.constraint(equalTo: effectView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: effectView.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: effectView.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: effectView.bottomAnchor),
        ])

        if progressive {
            let indicator = NSProgressIndicator()
            indicator.style = .spinning
            indicator.controlSize = .small
            indicator.translatesAutoresizingMaskIntoConstraints = false
            indicator.startAnimation(nil)
            stackView.addArrangedSubview(indicator)
            self.progressIndicator = indicator
        }

        textField = NSTextField(labelWithString: content)
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.font = .systemFont(ofSize: 14, weight: .medium)
        textField.textColor = .labelColor
        textField.lineBreakMode = .byTruncatingTail
        textField.maximumNumberOfLines = 1  // Enforce single line for perfect pill shape
        stackView.addArrangedSubview(textField)
    }

    public override func layout() {
        super.layout()
        let radius = self.bounds.height / 2
        self.layer?.cornerRadius = radius
        effectView.layer?.cornerRadius = radius
        tintView.layer?.cornerRadius = radius
    }
}
