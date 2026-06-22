import Cocoa
import NerwAction
import NerwBuiltin
import NerwCore
import NerwSearchBackend
import NerwUtils

// MARK: - HoverButton
class HoverButton: NSButton {
    private var trackingArea: NSTrackingArea?

    init(title: String, target: AnyObject?, action: Selector) {
        super.init(frame: .zero)
        self.title = title
        self.target = target
        self.action = action
        self.isBordered = false
        self.wantsLayer = true
        self.layer?.cornerRadius = 6
        self.font = .systemFont(ofSize: 11, weight: .semibold)
        self.contentTintColor = .secondaryLabelColor
        updateBg(hover: false)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func updateBg(hover: Bool) {
        if hover {
            self.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.08).cgColor
            self.contentTintColor = .labelColor
        } else {
            self.layer?.backgroundColor = NSColor.clear.cgColor
            self.contentTintColor = .secondaryLabelColor
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        updateBg(hover: true)
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        updateBg(hover: false)
    }
}

// MARK: - HoverIconButton
class HoverIconButton: NSButton {
    private var trackingArea: NSTrackingArea?
    private var isCircular: Bool

    init(imageName: String, isCircular: Bool = false, target: AnyObject?, action: Selector) {
        self.isCircular = isCircular
        super.init(frame: .zero)
        self.image = NSImage(systemSymbolName: imageName, accessibilityDescription: nil)
        self.imagePosition = .imageOnly
        self.target = target
        self.action = action
        self.isBordered = false
        self.wantsLayer = true
        if isCircular {
            self.layer?.cornerRadius = 20
        } else {
            self.layer?.cornerRadius = 6
        }
        self.contentTintColor = .secondaryLabelColor
        updateBg(hover: false)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func updateBg(hover: Bool) {
        let theme = NerwTheme.current()
        let selectionColor: NSColor
        if let hex = theme.selectionBackgroundColorHex, let color = NSColor(hexString: hex) {
            selectionColor = color
        } else {
            selectionColor = .controlAccentColor
        }

        if hover {
            self.layer?.backgroundColor = selectionColor.withAlphaComponent(0.2).cgColor
            self.contentTintColor = .labelColor
        } else {
            self.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.06).cgColor
            self.contentTintColor = .secondaryLabelColor
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        updateBg(hover: true)
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        updateBg(hover: false)
    }
}

// MARK: - SegmentBarView
class SegmentBarView: NSView {
    let index: Int
    var isSelected: Bool = false {
        didSet {
            updateStyle()
        }
    }
    var onClicked: ((Int) -> Void)?
    private var trackingArea: NSTrackingArea?

    init(index: Int) {
        self.index = index
        super.init(frame: .zero)
        self.wantsLayer = true
        self.layer?.cornerRadius = 2
        updateStyle()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func updateStyle() {
        let theme = NerwTheme.current()
        let accentColor: NSColor
        if let hex = theme.selectionBackgroundColorHex, let color = NSColor(hexString: hex) {
            accentColor = color
        } else {
            accentColor = .controlAccentColor
        }

        if isSelected {
            self.layer?.backgroundColor = accentColor.cgColor
            self.alphaValue = 1.0
        } else {
            self.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.25).cgColor
            self.alphaValue = 0.5
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        if !isSelected {
            self.alphaValue = 0.8
        }
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        if !isSelected {
            self.alphaValue = 0.5
        }
    }

    override func mouseDown(with event: NSEvent) {
        onClicked?(index)
    }
}

// MARK: - PromptTextField
class PromptTextField: NSTextField {
    var onSubmit: (() -> Void)?
    var onCancel: (() -> Void)?
    var onClearChat: (() -> Void)?
    var onMoveUp: (() -> Void)?
    var onMoveDown: (() -> Void)?
    var onToggleContextPanel: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        self.isBordered = false
        self.drawsBackground = false
        self.backgroundColor = .clear
        self.textColor = .labelColor
        self.font = .systemFont(ofSize: 14)
        self.focusRingType = .none

        let placeholderColor = NSColor.white.withAlphaComponent(0.4)
        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: placeholderColor,
            .font: NSFont.systemFont(ofSize: 14),
        ]
        self.placeholderAttributedString = NSAttributedString(
            string: "Ask anything", attributes: attributes)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let keyCode = event.keyCode
        if keyCode == 51 && event.modifierFlags.contains([.command, .option]) {
            onClearChat?()
            return true
        }
        if keyCode == 36 || keyCode == 76 {  // Enter/Return
            onSubmit?()
            return true
        }
        if keyCode == 53 {  // Esc
            onCancel?()
            return true
        }

        // Navigation bindings
        if event.modifierFlags.contains(.control) {
            guard let chars = event.charactersIgnoringModifiers?.lowercased() else {
                return super.performKeyEquivalent(with: event)
            }
            let navStyle = ConfigManager.shared.config.navigationStyle
            if navStyle == "vim" {
                if chars == "k" {
                    onMoveUp?()
                    return true
                } else if chars == "j" {
                    onMoveDown?()
                    return true
                }
            } else {
                if chars == "p" {
                    onMoveUp?()
                    return true
                } else if chars == "n" {
                    onMoveDown?()
                    return true
                }
            }
        }

        if event.modifierFlags.contains(.command) {
            guard let chars = event.charactersIgnoringModifiers?.lowercased() else {
                return super.performKeyEquivalent(with: event)
            }
            if chars == "k" {
                onToggleContextPanel?()
                return true
            }
        }

        return super.performKeyEquivalent(with: event)
    }
}

// MARK: - RippleAnimationView
class RippleAnimationView: NSView {
    private var rippleLayer: CALayer!
    private var isAnimating = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        wantsLayer = true
        rippleLayer = CALayer()
        rippleLayer.backgroundColor = NSColor.controlAccentColor.cgColor
        rippleLayer.cornerRadius = 8
        rippleLayer.frame = CGRect(x: 0, y: 0, width: 16, height: 16)
        rippleLayer.opacity = 0
        layer?.addSublayer(rippleLayer)
    }

    override func layout() {
        super.layout()
        rippleLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
    }

    func startAnimation() {
        if isAnimating { return }
        isAnimating = true

        let scaleAnimation = CABasicAnimation(keyPath: "transform.scale")
        scaleAnimation.fromValue = 0.5
        scaleAnimation.toValue = 1.5

        let opacityAnimation = CABasicAnimation(keyPath: "opacity")
        opacityAnimation.fromValue = 1.0
        opacityAnimation.toValue = 0.0

        let group = CAAnimationGroup()
        group.animations = [scaleAnimation, opacityAnimation]
        group.duration = 1.2
        group.repeatCount = .infinity
        group.timingFunction = CAMediaTimingFunction(name: .easeOut)

        rippleLayer.add(group, forKey: "ripple")
    }

    func stopAnimation() {
        isAnimating = false
        rippleLayer.removeAllAnimations()
        rippleLayer.opacity = 0
    }
}

// MARK: - SettingsActionBubbleView
class SettingsActionBubbleView: NSView {
    var onSettingsClicked: (() -> Void)?

    init(message: String) {
        super.init(frame: .zero)
        setupViews(message: message)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews(message: String) {
        translatesAutoresizingMaskIntoConstraints = false

        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.wantsLayer = true
        container.layer?.cornerRadius = 12
        container.layer?.backgroundColor = NSColor.systemOrange.withAlphaComponent(0.1).cgColor
        container.layer?.borderColor = NSColor.systemOrange.withAlphaComponent(0.2).cgColor
        container.layer?.borderWidth = 1.0
        addSubview(container)

        let label = NSTextField(labelWithString: message)
        label.font = .systemFont(ofSize: 13)
        label.textColor = .labelColor
        label.cell?.wraps = true
        label.cell?.isScrollable = false
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)

        let button = HoverButton(
            title: "Configure AI...", target: self, action: #selector(btnClicked))
        button.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(button)

        NSLayoutConstraint.activate([
            container.leadingAnchor.constraint(equalTo: leadingAnchor),
            container.trailingAnchor.constraint(equalTo: trailingAnchor),
            container.topAnchor.constraint(equalTo: topAnchor),
            container.bottomAnchor.constraint(equalTo: bottomAnchor),

            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -14),
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),

            button.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14),
            button.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 10),
            button.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12),
            button.heightAnchor.constraint(equalToConstant: 24),
            button.widthAnchor.constraint(equalToConstant: 110),
        ])
    }

    @objc private func btnClicked() {
        onSettingsClicked?()
    }
}

// MARK: - AIActionBubbleView
class AIActionBubbleView: NSView {
    private let iconView = NSImageView()
    private let label = NSTextField()

    init() {
        super.init(frame: .zero)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        wantsLayer = true
        layer?.cornerRadius = 10

        iconView.image = NSImage(
            systemSymbolName: "wand.and.sparkles", accessibilityDescription: "Action")
        iconView.image?.isTemplate = true
        iconView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(iconView)

        label.isEditable = false
        label.isBordered = false
        label.drawsBackground = false
        label.backgroundColor = .clear
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 16),
            iconView.heightAnchor.constraint(equalToConstant: 16),

            label.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    func update(actionType: String) {
        let displayName: String
        switch actionType.lowercased() {
        case "timer":
            displayName = "Timer"
        case "reminder":
            displayName = "Reminder"
        case "calendar":
            displayName = "Calendar"
        case "memory":
            displayName = "Memory"
        default:
            displayName = actionType.capitalized
        }
        label.stringValue = "Performed Action: \(displayName)"
        updateColors()
    }

    func updateColors() {
        let theme = NerwTheme.current()
        let accentColor: NSColor
        if let hex = theme.selectionBackgroundColorHex, let color = NSColor(hexString: hex) {
            accentColor = color
        } else {
            accentColor = .controlAccentColor
        }

        layer?.backgroundColor = accentColor.withAlphaComponent(0.12).cgColor
        layer?.borderColor = accentColor.withAlphaComponent(0.3).cgColor
        layer?.borderWidth = 1.0

        iconView.contentTintColor = accentColor

        let textColor: NSColor
        if let hex = theme.foregroundColorHex, let color = NSColor(hexString: hex) {
            textColor = color
        } else {
            textColor = .labelColor
        }
        label.textColor = textColor
    }
}

// MARK: - ChatTurn Model
struct ChatTurn {
    let query: String
    var response: String
    var actionType: String?
}

// MARK: - ConversationViewController
public class ConversationViewController: NSViewController {
    private var panelView: NerwPanelView!
    private let indicatorContainer = NSStackView()
    private let cardView = NSView()
    private let queryContainer = NSView()
    private let queryLabel = NSTextField()
    private let responseScrollView = NSScrollView()
    private let responseTextView: NSTextView = {
        let storage = NSTextStorage()
        let layoutManager = RoundedBackgroundLayoutManager()
        storage.addLayoutManager(layoutManager)
        let container = NSTextContainer()
        layoutManager.addTextContainer(container)
        let tv = NSTextView(frame: .zero, textContainer: container)
        return tv
    }()
    private let promptContainer = NSView()
    private let promptTextField = PromptTextField()
    private var warningView: SettingsActionBubbleView?

    private lazy var expandArrowButton: HoverIconButton = {
        let btn = HoverIconButton(
            imageName: "chevron.down", isCircular: true, target: self,
            action: #selector(toggleQueryExpansion))
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.isHidden = true
        return btn
    }()
    private var isQueryExpanded = false

    // Upgraded UI components
    private let sparkleImageView = NSImageView()
    private let spinner = RippleAnimationView()
    private let floatingContextButton = ContextHoverButton()
    private let actionBubbleView = AIActionBubbleView()
    private var cardHeightConstraint: NSLayoutConstraint?
    private var scrollViewBottomToCardConstraint: NSLayoutConstraint?
    private var scrollViewBottomToActionConstraint: NSLayoutConstraint?
    private var actionBubbleBottomConstraint: NSLayoutConstraint?
    private let contentPadding: CGFloat = 32

    private var generatingTimer: Timer?
    private var generatingDotCount = 0

    // Context Panel state
    private var actionContextWindow: ActionContextPanel?
    private var actionContextOverlay: ActionContextOverlayView?
    private var actionContextViewController: ActionContextViewController?

    private var turns: [ChatTurn] = []
    private var activeTurnIndex: Int = -1
    private var activeTask: Task<Void, Never>?

    public var onDismiss: (() -> Void)?

    public override func loadView() {
        view = NSView(
            frame: NSRect(
                x: 0, y: 0, width: GlobalLayout.mainWidth, height: GlobalLayout.mainHeight))
        view.wantsLayer = true
        setupViews()
    }

    private func setupViews() {
        // Frosted glass background
        panelView = NerwPanelView(style: .main)
        panelView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(panelView)

        NSLayoutConstraint.activate([
            panelView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            panelView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            panelView.topAnchor.constraint(equalTo: view.topAnchor),
            panelView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        let contentView = panelView.contentView

        // 1. Sparkle Image View (Centered translucent background symbol)
        sparkleImageView.image = NSImage(
            systemSymbolName: "sparkles", accessibilityDescription: "No chat")
        sparkleImageView.image?.isTemplate = true
        sparkleImageView.translatesAutoresizingMaskIntoConstraints = false
        sparkleImageView.imageScaling = .scaleProportionallyUpOrDown
        contentView.addSubview(sparkleImageView)

        // 2. Left indicator stack view (timeline bars)
        indicatorContainer.orientation = .vertical
        indicatorContainer.spacing = 8
        indicatorContainer.alignment = .centerX
        indicatorContainer.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(indicatorContainer)

        // 3. Floating Prompt input field (at bottom)
        promptContainer.translatesAutoresizingMaskIntoConstraints = false
        promptContainer.wantsLayer = true
        promptContainer.layer?.cornerRadius = 22
        promptContainer.layer?.borderWidth = 0.0
        contentView.addSubview(promptContainer)

        floatingContextButton.imageView.image = ResultCellView.makeVerticalEllipsisImage()
        floatingContextButton.translatesAutoresizingMaskIntoConstraints = false
        floatingContextButton.onTapped = { [weak self] in
            self?.toggleActionContext()
        }
        promptContainer.addSubview(floatingContextButton)

        promptTextField.onSubmit = { [weak self] in
            self?.sendCurrentPrompt()
        }
        promptTextField.onCancel = { [weak self] in
            self?.dismissController()
        }
        promptTextField.onClearChat = { [weak self] in
            self?.clearChat()
        }
        promptTextField.onMoveUp = { [weak self] in
            guard let self = self, self.activeTurnIndex > 0 else { return }
            self.selectTurn(at: self.activeTurnIndex - 1)
        }
        promptTextField.onMoveDown = { [weak self] in
            guard let self = self, self.activeTurnIndex < self.turns.count - 1 else { return }
            self.selectTurn(at: self.activeTurnIndex + 1)
        }
        promptTextField.onToggleContextPanel = { [weak self] in
            self?.toggleActionContext()
        }
        promptTextField.translatesAutoresizingMaskIntoConstraints = false
        promptContainer.addSubview(promptTextField)

        // 4. Generation Spinner inside Prompt Container on the right
        spinner.translatesAutoresizingMaskIntoConstraints = false
        promptContainer.addSubview(spinner)

        // 6. Response Card (Main content area)
        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.wantsLayer = true
        cardView.layer?.cornerRadius = 16
        cardView.layer?.borderWidth = 1.0
        contentView.addSubview(cardView)

        // 7. User Query label outside the card above
        queryContainer.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(queryContainer)

        queryContainer.addSubview(expandArrowButton)

        queryLabel.isEditable = false
        queryLabel.isBordered = false
        queryLabel.drawsBackground = false
        queryLabel.backgroundColor = .clear
        queryLabel.font = .systemFont(ofSize: 13, weight: .bold)
        queryLabel.textColor = .white.withAlphaComponent(0.5)
        queryLabel.alignment = .right
        queryLabel.maximumNumberOfLines = 1
        queryLabel.cell?.lineBreakMode = .byTruncatingTail
        queryLabel.translatesAutoresizingMaskIntoConstraints = false
        queryContainer.addSubview(queryLabel)

        // Response text scroll view inside card
        responseScrollView.drawsBackground = false
        responseScrollView.hasVerticalScroller = true
        responseScrollView.hasHorizontalScroller = false
        responseScrollView.autohidesScrollers = true
        responseScrollView.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(responseScrollView)

        // Configure responseTextView
        responseTextView.isEditable = false
        responseTextView.isSelectable = true
        responseTextView.drawsBackground = false
        responseTextView.backgroundColor = .clear
        responseTextView.font = .systemFont(ofSize: 14)
        responseTextView.textColor = .labelColor
        responseTextView.isRichText = false
        responseTextView.importsGraphics = false

        responseTextView.textContainer?.lineFragmentPadding = 12
        responseTextView.textContainer?.widthTracksTextView = true
        responseTextView.textContainerInset = NSSize(width: 0, height: 12)

        responseTextView.minSize = NSSize(width: 0, height: 0)
        responseTextView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        responseTextView.isVerticallyResizable = true
        responseTextView.isHorizontallyResizable = false
        responseTextView.autoresizingMask = [.width]
        responseTextView.textContainer?.containerSize = NSSize(
            width: responseScrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        responseTextView.textContainer?.widthTracksTextView = true
        responseTextView.textContainer?.lineBreakMode = .byCharWrapping

        // Ensure no horizontal scroll
        responseScrollView.documentView = responseTextView

        // Add action bubble view
        actionBubbleView.translatesAutoresizingMaskIntoConstraints = false
        actionBubbleView.isHidden = true
        cardView.addSubview(actionBubbleView)

        // Card Height Constraint for dynamic sizing
        cardHeightConstraint = cardView.heightAnchor.constraint(equalToConstant: 100)
        cardHeightConstraint?.isActive = true

        // Constraints setup
        NSLayoutConstraint.activate([
            // Sparkle Image (Centered)
            sparkleImageView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            sparkleImageView.centerYAnchor.constraint(
                equalTo: contentView.centerYAnchor, constant: -20),
            sparkleImageView.widthAnchor.constraint(equalToConstant: 120),
            sparkleImageView.heightAnchor.constraint(equalToConstant: 120),

            // Right Indicator bars floating horizontally between card and window edge
            indicatorContainer.centerXAnchor.constraint(
                equalTo: contentView.trailingAnchor, constant: -16),
            indicatorContainer.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            indicatorContainer.widthAnchor.constraint(equalToConstant: 16),
            indicatorContainer.topAnchor.constraint(
                greaterThanOrEqualTo: contentView.topAnchor, constant: 24),
            indicatorContainer.bottomAnchor.constraint(
                lessThanOrEqualTo: promptContainer.topAnchor, constant: -16),

            // Prompt Container centered with `contentPadding` padding on each side
            promptContainer.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor, constant: contentPadding),
            promptContainer.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor, constant: -contentPadding),
            promptContainer.bottomAnchor.constraint(
                equalTo: contentView.bottomAnchor, constant: -contentPadding),
            promptContainer.heightAnchor.constraint(equalToConstant: 44),

            floatingContextButton.trailingAnchor.constraint(
                equalTo: promptContainer.trailingAnchor, constant: -12),
            floatingContextButton.centerYAnchor.constraint(equalTo: promptContainer.centerYAnchor),
            floatingContextButton.widthAnchor.constraint(equalToConstant: 24),
            floatingContextButton.heightAnchor.constraint(equalToConstant: 24),

            promptTextField.leadingAnchor.constraint(
                equalTo: promptContainer.leadingAnchor, constant: 16),
            promptTextField.trailingAnchor.constraint(
                equalTo: spinner.leadingAnchor, constant: -8),
            promptTextField.centerYAnchor.constraint(equalTo: promptContainer.centerYAnchor),

            // Generation Spinner inside prompt on the right
            spinner.trailingAnchor.constraint(
                equalTo: floatingContextButton.leadingAnchor, constant: -8),
            spinner.centerYAnchor.constraint(equalTo: promptContainer.centerYAnchor),
            spinner.widthAnchor.constraint(equalToConstant: 16),
            spinner.heightAnchor.constraint(equalToConstant: 16),

            // Response Card below window top
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: contentPadding),
            cardView.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor, constant: contentPadding),
            cardView.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor, constant: -contentPadding),
            cardView.bottomAnchor.constraint(
                lessThanOrEqualTo: queryContainer.topAnchor, constant: -12),

            // User Query (Just above prompt, start from middle)
            queryContainer.bottomAnchor.constraint(
                equalTo: promptContainer.topAnchor, constant: -12),
            queryContainer.trailingAnchor.constraint(equalTo: promptContainer.trailingAnchor),
            queryContainer.leadingAnchor.constraint(equalTo: promptContainer.centerXAnchor),

            queryLabel.leadingAnchor.constraint(equalTo: queryContainer.leadingAnchor),
            queryLabel.trailingAnchor.constraint(
                equalTo: expandArrowButton.leadingAnchor, constant: -4),
            queryLabel.topAnchor.constraint(equalTo: queryContainer.topAnchor),
            queryLabel.bottomAnchor.constraint(equalTo: queryContainer.bottomAnchor),

            expandArrowButton.trailingAnchor.constraint(equalTo: queryContainer.trailingAnchor),
            expandArrowButton.topAnchor.constraint(equalTo: queryContainer.topAnchor, constant: 0),
            expandArrowButton.widthAnchor.constraint(equalToConstant: 16),
            expandArrowButton.heightAnchor.constraint(equalToConstant: 16),

            // Response Scroll View in Card
            responseScrollView.topAnchor.constraint(
                equalTo: cardView.topAnchor, constant: 16),
            responseScrollView.leadingAnchor.constraint(
                equalTo: cardView.leadingAnchor, constant: 16),
            responseScrollView.trailingAnchor.constraint(
                equalTo: cardView.trailingAnchor, constant: -16),

            // Action Bubble View in Card
            actionBubbleView.leadingAnchor.constraint(
                equalTo: cardView.leadingAnchor, constant: 16),
            actionBubbleView.trailingAnchor.constraint(
                equalTo: cardView.trailingAnchor, constant: -16),
            actionBubbleView.heightAnchor.constraint(equalToConstant: 32),
        ])

        scrollViewBottomToCardConstraint = responseScrollView.bottomAnchor.constraint(
            equalTo: cardView.bottomAnchor, constant: -16)
        scrollViewBottomToActionConstraint = responseScrollView.bottomAnchor.constraint(
            equalTo: actionBubbleView.topAnchor, constant: -12)
        actionBubbleBottomConstraint = actionBubbleView.bottomAnchor.constraint(
            equalTo: cardView.bottomAnchor, constant: -16)

        scrollViewBottomToCardConstraint?.isActive = true

        updateColors()
        updateCard()
    }

    private func updateColors() {
        let theme = NerwTheme.current()
        let selectionColor: NSColor
        if let hex = theme.selectionBackgroundColorHex, let color = NSColor(hexString: hex) {
            selectionColor = color
        } else {
            selectionColor = .controlAccentColor
        }

        // Response card has same color as original prompt (translucent white/border)
        cardView.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.06).cgColor
        cardView.layer?.borderColor = NSColor.white.withAlphaComponent(0.12).cgColor

        // Prompt container dark search style
        promptContainer.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.1).cgColor
        promptContainer.layer?.borderColor = NSColor.clear.cgColor

        // Sparkle icon colors
        sparkleImageView.contentTintColor = NSColor.white.withAlphaComponent(0.35)

        // Apply foreground/text colors
        let textColor: NSColor
        if let hex = theme.foregroundColorHex, let color = NSColor(hexString: hex) {
            textColor = color
        } else {
            textColor = .labelColor
        }

        responseTextView.textColor = textColor
        promptTextField.textColor = textColor
        floatingContextButton.imageView.contentTintColor = textColor.withAlphaComponent(0.8)

        actionBubbleView.updateColors()

        Logger.shared.info(
            "ConversationViewController: updateColors applied. SelectionColor: \(selectionColor), TextColor: \(textColor)"
        )
    }

    public override func viewWillAppear() {
        super.viewWillAppear()
        updateColors()
        updateCard()
        focusInput()
    }

    public override func viewDidLayout() {
        super.viewDidLayout()
        Logger.shared.info(
            """
            ConversationViewController viewDidLayout:
              - view: \(view.frame)
              - panelView: \(panelView.frame)
              - contentView: \(panelView.contentView.frame)
              - cardView: \(cardView.frame)
              - responseScrollView: \(responseScrollView.frame)
              - responseTextView: \(responseTextView.frame)
              - promptContainer: \(promptContainer.frame)
              - indicatorContainer: \(indicatorContainer.frame)
            """)
    }

    public func focusInput() {
        view.window?.makeFirstResponder(promptTextField)
    }

    @objc private func toggleQueryExpansion() {
        isQueryExpanded.toggle()
        queryLabel.maximumNumberOfLines = isQueryExpanded ? 0 : 1
        queryLabel.cell?.lineBreakMode = isQueryExpanded ? .byWordWrapping : .byTruncatingTail
        let imageName = isQueryExpanded ? "chevron.up" : "chevron.down"
        expandArrowButton.image = NSImage(
            systemSymbolName: imageName, accessibilityDescription: nil)

        queryLabel.superview?.needsLayout = true
    }

    public func cancelActiveTask() {
        activeTask?.cancel()
        activeTask = nil
        DispatchQueue.main.async { [weak self] in
            self?.stopGeneratingAnimation()
            self?.spinner.stopAnimation()
        }
    }

    @objc private func clearChat() {
        cancelActiveTask()
        turns.removeAll()
        activeTurnIndex = -1
        updateCard()
    }

    private func dismissController() {
        cancelActiveTask()
        onDismiss?()
    }

    private func updateCard() {
        // Clear warning view if any
        warningView?.removeFromSuperview()
        warningView = nil
        responseScrollView.isHidden = false
        queryContainer.isHidden = false

        rebuildIndicatorBars()

        if turns.isEmpty {
            queryContainer.isHidden = true
            cardView.isHidden = true
            sparkleImageView.isHidden = false
            setResponseText("")
            return
        }

        sparkleImageView.isHidden = true
        cardView.isHidden = false

        guard activeTurnIndex >= 0 && activeTurnIndex < turns.count else { return }
        let turn = turns[activeTurnIndex]

        if turn.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            queryContainer.isHidden = true
        } else {
            queryContainer.isHidden = false
            queryLabel.stringValue = turn.query

            let font = queryLabel.font ?? .systemFont(ofSize: 13, weight: .bold)
            let textWidth = turn.query.size(withAttributes: [.font: font]).width
            let maxWidth: CGFloat = (GlobalLayout.mainWidth / 2.0) - contentPadding - 20

            if textWidth > maxWidth {
                expandArrowButton.isHidden = false
            } else {
                expandArrowButton.isHidden = true
                if isQueryExpanded {
                    toggleQueryExpansion()
                }
            }
        }
        setResponseText(turn.response)

        if let actionType = turn.actionType {
            actionBubbleView.isHidden = false
            actionBubbleView.update(actionType: actionType)

            scrollViewBottomToCardConstraint?.isActive = false
            scrollViewBottomToActionConstraint?.isActive = true
            actionBubbleBottomConstraint?.isActive = true
        } else {
            actionBubbleView.isHidden = true

            scrollViewBottomToActionConstraint?.isActive = false
            actionBubbleBottomConstraint?.isActive = false
            scrollViewBottomToCardConstraint?.isActive = true
        }

        // Dynamic Height Calculation for Response Card
        if let layoutManager = responseTextView.layoutManager,
            let textContainer = responseTextView.textContainer
        {
            layoutManager.ensureLayout(for: textContainer)
            let usedRect = layoutManager.usedRect(for: textContainer)
            // Include textContainerInset (top + bottom) in the height so the card is never
            // smaller than the text view's full frame, preventing the first line from clipping.
            let insetHeight = responseTextView.textContainerInset.height * 2
            var neededHeight = usedRect.height + insetHeight + 32  // 32 = card top+bottom padding
            if turn.actionType != nil {
                neededHeight += 32 /* action bubble height */ + 12 /* spacing */
            }
            let maxCardHeight = GlobalLayout.mainHeight - 160  // Leave space for query, prompt and padding
            cardHeightConstraint?.constant = min(neededHeight, maxCardHeight)
        }
    }

    private func setResponseText(_ text: String) {
        if text.isEmpty {
            responseTextView.textStorage?.setAttributedString(NSAttributedString())
            return
        }

        let theme = NerwTheme.current()
        let textColor: NSColor
        if let hex = theme.foregroundColorHex, let color = NSColor(hexString: hex) {
            textColor = color
        } else {
            textColor = .labelColor
        }

        let accentColor: NSColor
        if let hex = theme.selectionBackgroundColorHex, let color = NSColor(hexString: hex) {
            accentColor = color
        } else {
            accentColor = .controlAccentColor
        }

        let font = responseTextView.font ?? .systemFont(ofSize: 14)

        let attrString = MarkdownParser.parse(
            markdown: text,
            baseFont: font,
            textColor: textColor,
            accentColor: accentColor
        )
        responseTextView.textStorage?.setAttributedString(attrString)
    }

    private func rebuildIndicatorBars() {
        for subview in indicatorContainer.arrangedSubviews {
            subview.removeFromSuperview()
        }

        for i in 0..<turns.count {
            let bar = SegmentBarView(index: i)
            bar.isSelected = (i == activeTurnIndex)
            bar.onClicked = { [weak self] index in
                self?.selectTurn(at: index)
            }
            bar.translatesAutoresizingMaskIntoConstraints = false
            bar.widthAnchor.constraint(equalToConstant: 4).isActive = true
            bar.heightAnchor.constraint(equalToConstant: 24).isActive = true

            indicatorContainer.addArrangedSubview(bar)
        }
    }

    private func selectTurn(at index: Int) {
        guard index >= 0 && index < turns.count else { return }
        activeTurnIndex = index
        updateCard()
        focusInput()
    }

    private func startGeneratingAnimation() {
        generatingTimer?.invalidate()
        generatingDotCount = 0
        generatingTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) {
            [weak self] _ in
            guard let self = self else { return }
            self.generatingDotCount = (self.generatingDotCount + 1) % 4
            let dots = String(repeating: ".", count: self.generatingDotCount)
            DispatchQueue.main.async {
                if self.turns.count > 0 && self.activeTurnIndex == self.turns.count - 1 {
                    if self.turns[self.activeTurnIndex].response.hasPrefix("Generating") {
                        let text = "Generating" + dots
                        self.turns[self.activeTurnIndex].response = text
                        self.setResponseText(text)
                        self.updateCard()
                    }
                }
            }
        }
    }

    private func stopGeneratingAnimation() {
        generatingTimer?.invalidate()
        generatingTimer = nil
    }

    private func sendCurrentPrompt() {
        let text = promptTextField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        Logger.shared.info("ConversationViewController: User submitted prompt: '\(text)'")

        // Clear prompt text field
        promptTextField.stringValue = ""

        // Check if AI is enabled
        guard ConfigManager.shared.config.aiConfig.isEnabled else {
            Logger.shared.warning("ConversationViewController: AI is disabled, showing warning.")
            showDisabledWarning()
            return
        }

        cancelActiveTask()

        // Start spinner
        spinner.startAnimation()

        // Add turn to list
        let newTurn = ChatTurn(query: text, response: "Generating...", actionType: nil)
        turns.append(newTurn)
        activeTurnIndex = turns.count - 1

        updateCard()
        startGeneratingAnimation()

        Logger.shared.info(
            "ConversationViewController: Starting async Task for AI response generation...")
        activeTask = Task { [weak self] in
            let parser = AIStreamParser()
            var fullResponse = ""

            parser.onTextReady = { text in
                fullResponse = text
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    self.stopGeneratingAnimation()
                    if self.activeTurnIndex == self.turns.count - 1 {
                        self.turns[self.activeTurnIndex].response = text
                        self.setResponseText(text)
                        self.updateCard()
                    }
                }
            }

            parser.onThinkingStateChanged = { thinking in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    if thinking {
                        // Keep Generating animation going
                    } else {
                        self.stopGeneratingAnimation()
                        if self.activeTurnIndex == self.turns.count - 1 && !fullResponse.isEmpty {
                            self.setResponseText(fullResponse)
                            self.updateCard()
                        }
                    }
                }
            }

            parser.onActionDetected = { type, payload in
                Logger.shared.info(
                    "ConversationViewController: Detected action \(type) with payload: \(payload)")
                AIActionManager.shared.handleAction(type: type, payload: payload)

                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    if self.activeTurnIndex == self.turns.count - 1 {
                        self.turns[self.activeTurnIndex].actionType = type
                        if self.turns[self.activeTurnIndex].response.hasPrefix("Generating") {
                            self.turns[self.activeTurnIndex].response = ""
                        }
                        self.updateCard()
                    }
                }
            }

            do {
                guard let self = self else { return }
                var messages: [AIChatMessage] = []

                // Add history context
                // dropLast() because the last item is the newly appended "Generating..." turn
                for turn in self.turns.dropLast() {
                    messages.append(AIChatMessage(role: .user, content: turn.query))
                    let responseText = turn.response.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !responseText.isEmpty && !responseText.hasPrefix("Generating") {
                        messages.append(AIChatMessage(role: .assistant, content: responseText))
                    }
                }

                // Add the current query
                messages.append(AIChatMessage(role: .user, content: text))

                let stream = try await AIService.shared.generateResponse(
                    messages: messages, isStreaming: true)
                Logger.shared.info(
                    "ConversationViewController: Stream successfully returned from AIService, starting loop."
                )
                for try await delta in stream {
                    if Task.isCancelled {
                        Logger.shared.info("ConversationViewController: Stream task was cancelled.")
                        break
                    }
                    parser.append(text: delta)
                }

                if !Task.isCancelled {
                    parser.flush()
                    Logger.shared.info(
                        "ConversationViewController: Stream finished successfully. Response length: \(fullResponse.count)"
                    )
                    await MainActor.run { [weak self] in
                        guard let self = self else { return }
                        self.stopGeneratingAnimation()
                        self.spinner.stopAnimation()
                        self.updateCard()
                    }
                }
            } catch {
                if !Task.isCancelled {
                    let errMsg = "Error: \(error.localizedDescription)"
                    Logger.shared.error(
                        "ConversationViewController: Caught error during stream: \(errMsg)")
                    await MainActor.run { [weak self] in
                        guard let self = self else { return }
                        self.stopGeneratingAnimation()
                        self.spinner.stopAnimation()
                        self.turns[self.turns.count - 1].response = errMsg
                        if self.activeTurnIndex == self.turns.count - 1 {
                            self.setResponseText(errMsg)
                            self.updateCard()
                        }
                    }
                }
            }
        }
    }

    private func showDisabledWarning() {
        cancelActiveTask()
        turns.removeAll()
        activeTurnIndex = -1
        rebuildIndicatorBars()

        sparkleImageView.isHidden = true
        cardView.isHidden = false
        queryContainer.isHidden = true
        responseScrollView.isHidden = true

        let warning = SettingsActionBubbleView(
            message:
                "The AI Assistant subsystem is currently disabled in your configuration. Enable it in settings to start chatting."
        )
        warning.onSettingsClicked = { [weak self] in
            self?.dismissController()
            NotificationCenter.default.post(
                name: Notification.Name("NerwOpenSettings"),
                object: "ai"
            )
        }
        cardView.addSubview(warning)
        warningView = warning

        cardHeightConstraint?.constant = 110

        NSLayoutConstraint.activate([
            warning.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            warning.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            warning.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
        ])
    }

    // MARK: - Context Menu
    private func toggleActionContext() {
        if actionContextWindow?.isVisible == true {
            dismissActionContext()
            return
        }
        showActionContext()
    }

    private func showActionContext() {
        let navStyle = ConfigManager.shared.config.navigationStyle
        let upKeybind = navStyle == "vim" ? "⌃K" : "⌃P"
        let downKeybind = navStyle == "vim" ? "⌃J" : "⌃N"

        let clearChatOp = NerwActionContext.Operation(
            id: "clearChat",
            kind: .custom("clearChat"),
            title: "Clear Thread",
            subtitle: "Deletes the current conversation thread",
            icon: .system("trash"),
            interaction: .execute,
            detailText: "⌥⌘⌫"
        )

        let moveUpOp = NerwActionContext.Operation(
            id: "moveUp",
            kind: .custom("moveUp"),
            title: "Previous Message",
            subtitle: "Navigate to the older message",
            icon: .system("arrow.up"),
            interaction: .execute,
            detailText: upKeybind
        )

        let moveDownOp = NerwActionContext.Operation(
            id: "moveDown",
            kind: .custom("moveDown"),
            title: "Next Message",
            subtitle: "Navigate to the newer message",
            icon: .system("arrow.down"),
            interaction: .execute,
            detailText: downKeybind
        )

        let section = NerwActionContext.Section(
            id: "conversation",
            title: "Conversation",
            operations: [clearChatOp, moveUpOp, moveDownOp]
        )

        let context = NerwActionContext(
            actionID: "conversationContext",
            actionTitle: "Conversation",
            actionSubtitle: "Manage current thread",
            sections: [section]
        )

        let controller = actionContextViewController ?? ActionContextViewController()
        controller.delegate = self
        controller.isInlineMode = true
        controller.setConnectorSelectionHeight(0)
        controller.render(context: context)
        actionContextViewController = controller

        let overlay = ActionContextOverlayView()
        overlay.translatesAutoresizingMaskIntoConstraints = false
        overlay.onBackgroundClick = { [weak self] in
            self?.dismissActionContext()
        }
        panelView.contentView.addSubview(overlay)

        NSLayoutConstraint.activate([
            overlay.topAnchor.constraint(equalTo: panelView.contentView.topAnchor),
            overlay.leadingAnchor.constraint(equalTo: panelView.contentView.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: panelView.contentView.trailingAnchor),
            overlay.bottomAnchor.constraint(equalTo: panelView.contentView.bottomAnchor),
        ])
        actionContextOverlay = overlay

        overlay.alphaValue = 0
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.22
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.34, 1.56, 0.64, 1.0)
            overlay.animator().alphaValue = 1.0
        }

        controller.view.layoutSubtreeIfNeeded()
        let contentSize = controller.preferredContentSize

        let panel = ActionContextPanel(
            contentRect: NSRect(origin: .zero, size: contentSize),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.contentViewController = controller
        actionContextWindow = panel

        let buttonBounds = floatingContextButton.bounds
        let anchorPoint = NSPoint(x: buttonBounds.maxX, y: buttonBounds.midY)  // Align panel center to button center
        guard let window = view.window else { return }
        let pointInWindow = floatingContextButton.convert(anchorPoint, to: nil)
        var screenPoint = window.convertPoint(toScreen: pointInWindow)

        screenPoint.x += 8
        screenPoint.y -= contentSize.height / 2

        panel.setFrameOrigin(screenPoint)

        window.addChildWindow(panel, ordered: .above)
        panel.makeKeyAndOrderFront(nil)

        let contextView = controller.view
        contextView.wantsLayer = true
        contextView.alphaValue = 1.0
        contextView.layer?.removeAllAnimations()

        let scaleAnim = CASpringAnimation(keyPath: "transform.scale")
        scaleAnim.fromValue = 0.82
        scaleAnim.toValue = 1.0
        scaleAnim.damping = 14
        scaleAnim.stiffness = 280
        scaleAnim.mass = 0.75
        scaleAnim.duration = scaleAnim.settlingDuration
        contextView.layer?.add(scaleAnim, forKey: "popIn")
        contextView.layer?.transform = CATransform3DIdentity

        let opacityAnim = CABasicAnimation(keyPath: "opacity")
        opacityAnim.fromValue = 0.0
        opacityAnim.toValue = 1.0
        opacityAnim.duration = 0.15
        opacityAnim.timingFunction = CAMediaTimingFunction(name: .easeOut)
        contextView.layer?.add(opacityAnim, forKey: "opacity")

        DispatchQueue.main.async {
            controller.focusForInteraction()
        }
    }

    private func dismissActionContext(animated: Bool = true) {
        let cleanup: () -> Void = { [weak self] in
            self?.actionContextOverlay?.removeFromSuperview()
            self?.actionContextOverlay = nil

            if let panel = self?.actionContextWindow {
                panel.parent?.removeChildWindow(panel)
                panel.close()
                self?.actionContextWindow = nil
            }
        }

        guard animated, let overlay = actionContextOverlay,
            let contextView = actionContextWindow?.contentViewController?.view
        else {
            cleanup()
            return
        }

        contextView.wantsLayer = true
        NSAnimationContext.runAnimationGroup(
            { ctx in
                ctx.duration = 0.15
                ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
                overlay.animator().alphaValue = 0
                contextView.animator().alphaValue = 0
            }, completionHandler: cleanup)

        let scaleAnim = CABasicAnimation(keyPath: "transform.scale")
        scaleAnim.fromValue = 1.0
        scaleAnim.toValue = 0.88
        scaleAnim.duration = 0.15
        scaleAnim.timingFunction = CAMediaTimingFunction(name: .easeIn)
        scaleAnim.fillMode = .forwards
        scaleAnim.isRemovedOnCompletion = false
        contextView.layer?.add(scaleAnim, forKey: "popOut")
    }
}

// MARK: - ActionContextViewControllerDelegate
extension ConversationViewController: ActionContextViewControllerDelegate {
    func actionContext(
        _ controller: ActionContextViewController, didInvoke operation: NerwActionContext.Operation,
        in context: NerwActionContext
    ) {
        dismissActionContext()
        if case .custom(let customId) = operation.kind {
            switch customId {
            case "clearChat":
                clearChat()
            case "moveUp":
                if activeTurnIndex > 0 {
                    selectTurn(at: activeTurnIndex - 1)
                }
            case "moveDown":
                if activeTurnIndex < turns.count - 1 {
                    selectTurn(at: activeTurnIndex + 1)
                }
            default:
                break
            }
        }
    }

    func actionContext(
        _ controller: ActionContextViewController, didUpdatePreferencesFor actionID: String
    ) {}
    func actionContextDidRequestClose(_ controller: ActionContextViewController) {
        dismissActionContext()
    }
}
