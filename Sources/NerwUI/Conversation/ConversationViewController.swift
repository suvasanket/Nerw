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
            string: "Ask AI...", attributes: attributes)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let keyCode = event.keyCode
        if keyCode == 51 && event.modifierFlags.contains(.command) {
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

// MARK: - ChatTurn Model
struct ChatTurn {
    let query: String
    var response: String
}

// MARK: - ConversationViewController
public class ConversationViewController: NSViewController {
    private var panelView: NerwPanelView!
    private let indicatorContainer = NSStackView()
    private let cardView = NSView()
    private let queryContainer = NSView()
    private let queryLabel = NSTextField()
    private let responseScrollView = NSScrollView()
    private let responseTextView = NSTextView()
    private let promptContainer = NSView()
    private let promptTextField = PromptTextField()
    private var warningView: SettingsActionBubbleView?

    // Upgraded UI components
    private let sparkleImageView = NSImageView()
    private let spinner = RippleAnimationView()
    private var cardHeightConstraint: NSLayoutConstraint?
    private let contentPadding: CGFloat = 32

    private var generatingTimer: Timer?
    private var generatingDotCount = 0

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
        promptContainer.layer?.borderWidth = 1.0
        contentView.addSubview(promptContainer)

        promptTextField.onSubmit = { [weak self] in
            self?.sendCurrentPrompt()
        }
        promptTextField.onCancel = { [weak self] in
            self?.dismissController()
        }
        promptTextField.onClearChat = { [weak self] in
            self?.clearChat()
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

        responseTextView.textContainer?.lineFragmentPadding = 0
        responseTextView.textContainer?.widthTracksTextView = true

        responseTextView.minSize = NSSize(width: 0, height: 0)
        responseTextView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        responseTextView.isVerticallyResizable = true
        responseTextView.isHorizontallyResizable = false
        responseTextView.autoresizingMask = [.width]

        // Set default non-zero frame size to prevent layout and wrapping computation bugs
        responseTextView.frame = NSRect(x: 0, y: 0, width: 100, height: 100)

        responseScrollView.documentView = responseTextView

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
            indicatorContainer.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            indicatorContainer.widthAnchor.constraint(equalToConstant: 16),
            indicatorContainer.topAnchor.constraint(
                greaterThanOrEqualTo: contentView.topAnchor, constant: 24),
            indicatorContainer.bottomAnchor.constraint(
                lessThanOrEqualTo: promptContainer.topAnchor, constant: -16),

            // Prompt Container centered with 32pt padding on each side
            promptContainer.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor, constant: contentPadding),
            promptContainer.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor, constant: -contentPadding),
            promptContainer.bottomAnchor.constraint(
                equalTo: contentView.bottomAnchor, constant: -16),
            promptContainer.heightAnchor.constraint(equalToConstant: 44),

            promptTextField.leadingAnchor.constraint(
                equalTo: promptContainer.leadingAnchor, constant: 16),
            promptTextField.trailingAnchor.constraint(
                equalTo: spinner.leadingAnchor, constant: -8),
            promptTextField.centerYAnchor.constraint(equalTo: promptContainer.centerYAnchor),

            // Generation Spinner inside prompt on the right
            spinner.trailingAnchor.constraint(
                equalTo: promptContainer.trailingAnchor, constant: -16),
            spinner.centerYAnchor.constraint(equalTo: promptContainer.centerYAnchor),
            spinner.widthAnchor.constraint(equalToConstant: 16),
            spinner.heightAnchor.constraint(equalToConstant: 16),

            // User Query (Above Card, Top Right)
            queryContainer.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 24),
            queryContainer.trailingAnchor.constraint(equalTo: cardView.trailingAnchor),
            queryContainer.leadingAnchor.constraint(equalTo: contentView.centerXAnchor),
            queryContainer.heightAnchor.constraint(equalToConstant: 20),

            queryLabel.leadingAnchor.constraint(equalTo: queryContainer.leadingAnchor),
            queryLabel.trailingAnchor.constraint(equalTo: queryContainer.trailingAnchor),
            queryLabel.centerYAnchor.constraint(equalTo: queryContainer.centerYAnchor),

            // Response Card below Query Capsule, centered with 64pt padding
            cardView.topAnchor.constraint(equalTo: queryContainer.bottomAnchor, constant: 12),
            cardView.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor, constant: contentPadding),
            cardView.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor, constant: -contentPadding),
            cardView.bottomAnchor.constraint(
                lessThanOrEqualTo: promptContainer.topAnchor, constant: -16),

            // Response Scroll View in Card
            responseScrollView.topAnchor.constraint(
                equalTo: cardView.topAnchor, constant: 16),
            responseScrollView.leadingAnchor.constraint(
                equalTo: cardView.leadingAnchor, constant: 16),
            responseScrollView.trailingAnchor.constraint(
                equalTo: cardView.trailingAnchor, constant: -16),
            responseScrollView.bottomAnchor.constraint(
                equalTo: cardView.bottomAnchor, constant: -16),
        ])

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

        // Prompt container becomes more glass-like (accent highlight and translucent white glow)
        promptContainer.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.12).cgColor
        promptContainer.layer?.borderColor = selectionColor.withAlphaComponent(0.30).cgColor

        // Sparkle icon colors
        sparkleImageView.contentTintColor = selectionColor.withAlphaComponent(0.15)

        // Apply foreground/text colors
        let textColor: NSColor
        if let hex = theme.foregroundColorHex, let color = NSColor(hexString: hex) {
            textColor = color
        } else {
            textColor = .labelColor
        }

        responseTextView.textColor = textColor
        promptTextField.textColor = textColor

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
            responseTextView.string = ""
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
        }
        responseTextView.string = turn.response

        // Dynamic Height Calculation for Response Card
        if let layoutManager = responseTextView.layoutManager,
            let textContainer = responseTextView.textContainer
        {
            layoutManager.ensureLayout(for: textContainer)
            let usedRect = layoutManager.usedRect(for: textContainer)
            let neededHeight = usedRect.height + 32  // top + bottom padding of card (16 each)
            let maxCardHeight = GlobalLayout.mainHeight - 160  // Leave space for query, prompt and padding
            cardHeightConstraint?.constant = min(neededHeight, maxCardHeight)
        }
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
                        self.responseTextView.string = text
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
        let newTurn = ChatTurn(query: text, response: "Generating...")
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
                        self.responseTextView.string = text
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
                            self.responseTextView.string = fullResponse
                            self.updateCard()
                        }
                    }
                }
            }

            parser.onActionDetected = { type, payload in
                Logger.shared.info(
                    "ConversationViewController: Detected action \(type) with payload: \(payload)")
                DispatchQueue.main.async {
                    Nerw.notify("AI Action: \(type)\n\(payload)", level: .info)
                }
            }

            do {
                let stream = try await AIService.shared.generateResponse(
                    prompt: text, isStreaming: true)

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
                            self.responseTextView.string = errMsg
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
}
