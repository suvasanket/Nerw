import Cocoa
import NerwCore

public class NotificationItemView: NSView {
    public let id: UUID
    private var progressIndicator: NSProgressIndicator?
    private var panelView: NerwPanelView!
    private var textField: NSTextField!

    public init(id: UUID, content: String, level: NerwNotificationLevel, progressive: Bool) {
        self.id = id
        super.init(frame: NSRect(x: 0, y: 0, width: 320, height: 50))
        setupView(content: content, level: level, progressive: progressive)
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupView(content: String, level: NerwNotificationLevel, progressive: Bool) {
        self.wantsLayer = true
        // Shadow on the root view
        self.layer?.masksToBounds = false
        self.shadow = NSShadow()
        self.shadow?.shadowColor = NSColor.black.withAlphaComponent(0.2)
        self.shadow?.shadowOffset = NSSize(width: 0, height: -4)
        self.shadow?.shadowBlurRadius = 8

        // Container View handles the perfect pill masking
        // 1. NerwPanelView (Frosted Glass Background)
        panelView = NerwPanelView(style: .notification)
        panelView.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(panelView)

        // Let it handle tint view from theme
        if level == .warn || level == .error {
            // Apply a slight colored tint on top if warn or error
            let colorView = NSView()
            colorView.translatesAutoresizingMaskIntoConstraints = false
            colorView.wantsLayer = true
            if level == .warn {
                colorView.layer?.backgroundColor =
                    NSColor.systemYellow.withAlphaComponent(0.15).cgColor
            } else {
                colorView.layer?.backgroundColor =
                    NSColor.systemRed.withAlphaComponent(0.15).cgColor
            }
            panelView.contentView.addSubview(colorView)

            NSLayoutConstraint.activate([
                colorView.leadingAnchor.constraint(equalTo: panelView.contentView.leadingAnchor),
                colorView.trailingAnchor.constraint(equalTo: panelView.contentView.trailingAnchor),
                colorView.topAnchor.constraint(equalTo: panelView.contentView.topAnchor),
                colorView.bottomAnchor.constraint(equalTo: panelView.contentView.bottomAnchor),
            ])
        }

        // 2. Content Stack
        let stackView = NSStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.orientation = .horizontal
        stackView.alignment = .centerY
        stackView.spacing = 10
        stackView.edgeInsets = NSEdgeInsets(top: 12, left: 18, bottom: 12, right: 18)
        panelView.contentView.addSubview(stackView)

        NSLayoutConstraint.activate([
            panelView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            panelView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            panelView.topAnchor.constraint(equalTo: self.topAnchor),
            panelView.bottomAnchor.constraint(equalTo: self.bottomAnchor),

            stackView.leadingAnchor.constraint(equalTo: panelView.contentView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: panelView.contentView.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: panelView.contentView.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: panelView.contentView.bottomAnchor),
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
        // Perfect pill shape calculation
        let radius = self.bounds.height / 2

        var style = NerwPanelView.Style.notification
        style.cornerRadiusOverride = radius

        // This is a bit of a hack but we want to re-init or apply corner radius
        // For our simple case, directly setting corner radius is sufficient as the applyTheme() respects it
        panelView.layer?.cornerRadius = radius

        // Removed self.shadow?.shadowPath = path.cgPath completely,
        // relying on Mac OS default NSShadow rendering over subviews
    }
}
