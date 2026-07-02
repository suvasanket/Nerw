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
    var onCancelGeneration: (() -> Void)?
    var onRetry: (() -> Void)?

    var onTab: (() -> Void)?
    var onShiftTab: (() -> Void)?
    var onExecuteNode: (() -> Bool)?
    var onCancelSelection: (() -> Bool)?

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
        if keyCode == 48 {  // Tab
            if event.modifierFlags.contains(.shift) {
                onShiftTab?()
            } else {
                onTab?()
            }
            return true
        }
        if keyCode == 36 || keyCode == 76 {  // Enter/Return
            if let onExecuteNode = onExecuteNode, onExecuteNode() {
                return true
            }
            onSubmit?()
            return true
        }
        if keyCode == 53 {  // Esc
            if let onCancelSelection = onCancelSelection, onCancelSelection() {
                return true
            }
            onCancel?()
            return true
        }

        // Navigation bindings
        if event.modifierFlags.contains(.control) {
            guard let chars = event.charactersIgnoringModifiers?.lowercased() else {
                return super.performKeyEquivalent(with: event)
            }
            if chars == "c" {
                onCancelGeneration?()
                return true
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
            if chars == "r" {
                onRetry?()
                return true
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

// MARK: - ReferencesContainerView
class ReferencesContainerView: NSView {
    private var icons: [(icon: String, name: String)] = []

    private let effectView = NSVisualEffectView()
    private let rootStack = NSStackView()

    private var compactConstraints: [NSLayoutConstraint] = []
    private var expandedConstraints: [NSLayoutConstraint] = []

    private var isExpanded = false

    init() {
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        wantsLayer = true

        effectView.material = .hudWindow
        effectView.state = .active
        effectView.blendingMode = .withinWindow
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = 12
        effectView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(effectView)

        NSLayoutConstraint.activate([
            effectView.leadingAnchor.constraint(equalTo: leadingAnchor),
            effectView.trailingAnchor.constraint(equalTo: trailingAnchor),
            effectView.topAnchor.constraint(equalTo: topAnchor),
            effectView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        rootStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(rootStack)

        compactConstraints = [
            rootStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 2),
            rootStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -2),
            rootStack.topAnchor.constraint(equalTo: topAnchor, constant: 2),
            rootStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -2),
        ]

        expandedConstraints = [
            rootStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            rootStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            rootStack.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            rootStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
        ]

        NSLayoutConstraint.activate(compactConstraints)
    }

    override func mouseDown(with event: NSEvent) {
        isExpanded.toggle()
        updateUI()
    }

    func update(with items: [(icon: String, name: String)]) {
        self.icons = items
        isHidden = items.isEmpty
        if items.isEmpty {
            isExpanded = false
        }
        updateUI()
    }

    private func updateUI() {
        rootStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        if isExpanded {
            NSLayoutConstraint.deactivate(compactConstraints)
            NSLayoutConstraint.activate(expandedConstraints)

            rootStack.orientation = .vertical
            rootStack.spacing = 8
            rootStack.alignment = .leading

            effectView.layer?.cornerRadius = 8

            effectView.material = .hudWindow
            effectView.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.06).cgColor
            effectView.layer?.borderWidth = 1.0
            effectView.layer?.borderColor = NSColor.white.withAlphaComponent(0.12).cgColor

            buildExpanded()
        } else {
            NSLayoutConstraint.deactivate(expandedConstraints)
            NSLayoutConstraint.activate(compactConstraints)

            rootStack.orientation = .horizontal
            rootStack.spacing = 6
            rootStack.alignment = .centerY

            effectView.layer?.cornerRadius = 12

            effectView.material = .hudWindow
            effectView.layer?.backgroundColor = NSColor.clear.cgColor
            effectView.layer?.borderWidth = 0

            buildCompact()
        }
    }

    private func buildCompact() {
        if icons.isEmpty { return }

        let iconSize: CGFloat = 20
        let overlap: CGFloat = 8
        let displayCount = min(icons.count, 3)
        let hasMore = icons.count > 3

        let totalWidth =
            CGFloat(displayCount) * iconSize - CGFloat(displayCount - 1) * overlap
            + (hasMore ? iconSize - overlap : 0)

        let overlappingIconsView = NSView()
        overlappingIconsView.translatesAutoresizingMaskIntoConstraints = false
        overlappingIconsView.widthAnchor.constraint(equalToConstant: totalWidth).isActive = true
        overlappingIconsView.heightAnchor.constraint(equalToConstant: iconSize).isActive = true

        for i in 0..<displayCount {
            let iv = makeCircleIcon(imageName: icons[i].icon)
            iv.frame = NSRect(
                x: CGFloat(i) * (iconSize - overlap), y: 0, width: iconSize, height: iconSize)
            overlappingIconsView.addSubview(iv)
        }

        if hasMore {
            let moreView = makeMoreIcon(count: icons.count - 3)
            moreView.frame = NSRect(
                x: CGFloat(displayCount) * (iconSize - overlap), y: 0, width: iconSize,
                height: iconSize)
            overlappingIconsView.addSubview(moreView)
        }

        rootStack.addArrangedSubview(overlappingIconsView)
    }

    private func buildExpanded() {
        let titleLabel = NSTextField(labelWithString: "Context Sources")
        titleLabel.font = .systemFont(ofSize: 11, weight: .bold)
        titleLabel.textColor = .white.withAlphaComponent(0.5)
        titleLabel.isEditable = false
        titleLabel.isBordered = false
        titleLabel.drawsBackground = false
        rootStack.addArrangedSubview(titleLabel)

        for item in icons {
            let row = NSStackView()
            row.orientation = .horizontal
            row.spacing = 8
            row.alignment = .centerY

            let container = NSView()
            container.wantsLayer = true
            container.layer?.cornerRadius = 10
            container.layer?.backgroundColor = NSColor(white: 0.2, alpha: 1.0).cgColor
            container.translatesAutoresizingMaskIntoConstraints = false
            container.widthAnchor.constraint(equalToConstant: 20).isActive = true
            container.heightAnchor.constraint(equalToConstant: 20).isActive = true

            let iv = NSImageView()
            if let image = NSImage(systemSymbolName: item.icon, accessibilityDescription: nil) {
                iv.image = image.withSymbolConfiguration(.init(pointSize: 10, weight: .medium))
            }
            iv.contentTintColor = .white
            iv.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(iv)

            NSLayoutConstraint.activate([
                iv.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                iv.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            ])

            let lbl = NSTextField(labelWithString: item.name)
            lbl.font = .systemFont(ofSize: 12, weight: .medium)
            lbl.textColor = .white
            lbl.isEditable = false
            lbl.isBordered = false
            lbl.drawsBackground = false

            row.addArrangedSubview(container)
            row.addArrangedSubview(lbl)
            rootStack.addArrangedSubview(row)
        }
    }

    private func makeCircleIcon(imageName: String) -> NSView {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.cornerRadius = 10
        container.layer?.backgroundColor = NSColor(white: 0.2, alpha: 1.0).cgColor
        container.layer?.borderWidth = 1
        container.layer?.borderColor = NSColor.white.withAlphaComponent(0.2).cgColor

        let iv = NSImageView()
        if let image = NSImage(systemSymbolName: imageName, accessibilityDescription: nil) {
            iv.image = image.withSymbolConfiguration(.init(pointSize: 10, weight: .medium))
        }
        iv.contentTintColor = .white
        iv.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(iv)

        NSLayoutConstraint.activate([
            iv.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            iv.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])

        return container
    }

    private func makeMoreIcon(count: Int) -> NSView {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.cornerRadius = 10
        container.layer?.backgroundColor = NSColor(white: 0.2, alpha: 1.0).cgColor
        container.layer?.borderWidth = 1
        container.layer?.borderColor = NSColor.white.withAlphaComponent(0.2).cgColor

        let lbl = NSTextField(labelWithString: "+\(count)")
        lbl.font = .systemFont(ofSize: 9, weight: .bold)
        lbl.textColor = .white
        lbl.isEditable = false
        lbl.isBordered = false
        lbl.drawsBackground = false
        lbl.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(lbl)

        NSLayoutConstraint.activate([
            lbl.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            lbl.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])

        return container
    }
}

// MARK: - ChatTurn Model
struct ChatTurn {
    let query: String
    var response: String
    var actionType: String?
    var actionPayload: [String: Any]?
    var pciIcons: [(icon: String, name: String)] = []
}

// MARK: - ConversationViewController
public class ConversationViewController: NSViewController {
    private let responseFontSize: CGFloat = 15.0
    private var panelView: NerwPanelView!
    private let indicatorContainer = NSStackView()
    private let cardView = NSView()
    private let queryContainer = NSView()
    private let queryPlaceholder = NSView()
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

    private let nodeSelectionPill = NSView()
    private var markdownNodes: [(range: NSRange, node: NerwMarkdownNode)] = []
    private var selectedNodeIndex: Int? = nil

    private let currentModelStack = NSStackView()
    private let currentModelLabel = NSTextField(labelWithString: "")
    private let currentModelGlobeIcon = NSImageView()
    private let currentModelEyeIcon = NSImageView()

    private let referencesContainer = ReferencesContainerView()

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
    private var cardHeightConstraint: NSLayoutConstraint?
    private var scrollViewBottomToCardConstraint: NSLayoutConstraint?
    private let contentPadding: CGFloat = 32

    private var generatingTimer: Timer?
    private var generatingDotCount = 0

    // Wave generating label & shimmer
    private let waveGeneratingView = WaveGeneratingView()

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
        promptTextField.onTab = { [weak self] in self?.handleTab(shift: false) }
        promptTextField.onShiftTab = { [weak self] in self?.handleTab(shift: true) }
        promptTextField.onExecuteNode = { [weak self] in self?.handleExecuteNode() ?? false }
        promptTextField.onCancelSelection = { [weak self] in self?.handleCancelSelection() ?? false
        }
        promptTextField.onCancelGeneration = { [weak self] in
            self?.cancelGeneration()
        }
        promptTextField.onRetry = { [weak self] in
            self?.retryGeneration()
        }
        promptTextField.delegate = self
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

        referencesContainer.translatesAutoresizingMaskIntoConstraints = false
        referencesContainer.isHidden = true
        contentView.addSubview(referencesContainer)

        // Wave generating label inside card (added after cardView is in hierarchy)
        waveGeneratingView.translatesAutoresizingMaskIntoConstraints = false
        waveGeneratingView.isHidden = true
        cardView.addSubview(waveGeneratingView)

        // 7. User Query label outside the card above
        queryPlaceholder.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(queryPlaceholder)

        queryContainer.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(queryContainer)

        queryContainer.addSubview(expandArrowButton)

        queryLabel.isEditable = false
        queryLabel.isBordered = false
        queryLabel.drawsBackground = false
        queryLabel.backgroundColor = .clear
        queryLabel.font = .systemFont(ofSize: 13, weight: .regular)
        queryLabel.textColor = .white.withAlphaComponent(0.5)
        queryLabel.alignment = .left
        queryLabel.maximumNumberOfLines = 1
        queryLabel.cell?.lineBreakMode = .byTruncatingTail
        queryLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        queryLabel.translatesAutoresizingMaskIntoConstraints = false
        queryContainer.wantsLayer = true
        queryContainer.layer?.cornerRadius = 8
        queryContainer.addSubview(queryLabel)

        // Setup current model stack
        currentModelStack.orientation = .horizontal
        currentModelStack.spacing = 4
        currentModelStack.alignment = .centerY
        currentModelStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(currentModelStack)

        currentModelLabel.font = .systemFont(ofSize: 11, weight: .bold)
        currentModelLabel.textColor = .white.withAlphaComponent(0.5)
        currentModelLabel.drawsBackground = false
        currentModelLabel.isEditable = false
        currentModelLabel.isBordered = false
        currentModelLabel.maximumNumberOfLines = 1

        let configSymbol = NSImage.SymbolConfiguration(pointSize: 10, weight: .regular)
        currentModelGlobeIcon.image = NSImage(
            systemSymbolName: "globe", accessibilityDescription: nil)?.withSymbolConfiguration(
                configSymbol)
        currentModelGlobeIcon.contentTintColor = .white.withAlphaComponent(0.5)
        currentModelGlobeIcon.translatesAutoresizingMaskIntoConstraints = false

        currentModelEyeIcon.image = NSImage(systemSymbolName: "eye", accessibilityDescription: nil)?
            .withSymbolConfiguration(configSymbol)
        currentModelEyeIcon.contentTintColor = .white.withAlphaComponent(0.5)
        currentModelEyeIcon.translatesAutoresizingMaskIntoConstraints = false

        currentModelStack.addArrangedSubview(currentModelLabel)
        currentModelStack.addArrangedSubview(currentModelGlobeIcon)
        currentModelStack.addArrangedSubview(currentModelEyeIcon)

        // Response text scroll view inside card
        responseScrollView.drawsBackground = false
        responseScrollView.hasVerticalScroller = false
        responseScrollView.hasHorizontalScroller = false
        responseScrollView.autohidesScrollers = true
        responseScrollView.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(responseScrollView)

        // Configure responseTextView
        responseTextView.isEditable = false
        responseTextView.isSelectable = true
        responseTextView.drawsBackground = false
        responseTextView.backgroundColor = .clear
        responseTextView.font = .systemFont(ofSize: responseFontSize)
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

        nodeSelectionPill.wantsLayer = true
        nodeSelectionPill.layer?.cornerRadius = 6
        nodeSelectionPill.isHidden = true
        responseTextView.addSubview(nodeSelectionPill)

        NSLayoutConstraint.activate([
            waveGeneratingView.leadingAnchor.constraint(
                equalTo: cardView.leadingAnchor, constant: 20),
            waveGeneratingView.trailingAnchor.constraint(
                lessThanOrEqualTo: cardView.trailingAnchor, constant: -20),
            waveGeneratingView.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 14),
            waveGeneratingView.heightAnchor.constraint(equalToConstant: 24),
        ])

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

            // Current model indicator
            currentModelStack.bottomAnchor.constraint(
                equalTo: promptContainer.topAnchor, constant: -12),
            currentModelStack.trailingAnchor.constraint(
                equalTo: promptContainer.trailingAnchor, constant: -16),

            // Response Card below window top
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: contentPadding),
            cardView.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor, constant: contentPadding),
            cardView.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor, constant: -contentPadding),
            cardView.bottomAnchor.constraint(
                lessThanOrEqualTo: promptContainer.topAnchor, constant: -48),

            // User Query Placeholder (Fixed height, left-aligned under cardView)
            queryPlaceholder.topAnchor.constraint(equalTo: cardView.bottomAnchor, constant: 8),
            queryPlaceholder.leadingAnchor.constraint(equalTo: cardView.leadingAnchor),
            queryPlaceholder.widthAnchor.constraint(
                lessThanOrEqualTo: contentView.widthAnchor, multiplier: 0.5),
            queryPlaceholder.heightAnchor.constraint(equalToConstant: 24),

            // User Query Container (Overlay, expands downwards without pushing layout)
            queryContainer.topAnchor.constraint(equalTo: queryPlaceholder.topAnchor),
            queryContainer.trailingAnchor.constraint(equalTo: queryPlaceholder.trailingAnchor),
            queryContainer.leadingAnchor.constraint(equalTo: queryPlaceholder.leadingAnchor),

            queryLabel.leadingAnchor.constraint(equalTo: queryContainer.leadingAnchor, constant: 8),
            queryLabel.trailingAnchor.constraint(
                equalTo: expandArrowButton.leadingAnchor, constant: -4),
            queryLabel.topAnchor.constraint(equalTo: queryContainer.topAnchor, constant: 4),
            queryLabel.bottomAnchor.constraint(equalTo: queryContainer.bottomAnchor, constant: -4),

            expandArrowButton.trailingAnchor.constraint(
                equalTo: queryContainer.trailingAnchor, constant: -4),
            expandArrowButton.topAnchor.constraint(equalTo: queryContainer.topAnchor, constant: 4),
            expandArrowButton.widthAnchor.constraint(equalToConstant: 16),
            expandArrowButton.heightAnchor.constraint(equalToConstant: 16),

            // Response Scroll View in Card
            responseScrollView.topAnchor.constraint(
                equalTo: cardView.topAnchor, constant: 8),
            responseScrollView.leadingAnchor.constraint(
                equalTo: cardView.leadingAnchor, constant: 8),
            responseScrollView.trailingAnchor.constraint(
                equalTo: cardView.trailingAnchor, constant: -8),
        ])

        scrollViewBottomToCardConstraint = responseScrollView.bottomAnchor.constraint(
            equalTo: cardView.bottomAnchor, constant: -8)

        scrollViewBottomToCardConstraint?.isActive = true

        NSLayoutConstraint.activate([
            referencesContainer.bottomAnchor.constraint(
                equalTo: cardView.bottomAnchor, constant: 14),
            referencesContainer.leadingAnchor.constraint(
                equalTo: cardView.leadingAnchor, constant: 6),
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

        nodeSelectionPill.layer?.backgroundColor = selectionColor.withAlphaComponent(0.25).cgColor

        Logger.shared.info(
            "ConversationViewController: updateColors applied. SelectionColor: \(selectionColor), TextColor: \(textColor)"
        )
    }

    public override func viewWillAppear() {
        super.viewWillAppear()
        updateColors()
        updateCard()
        updateModelIndicator()
        focusInput()
    }

    private func updateModelIndicator() {
        let aiConfig = ConfigManager.shared.config.aiConfig
        if let provider = aiConfig.providers.first(where: { $0.id == aiConfig.selectedProviderId })
        {
            currentModelLabel.stringValue = provider.name
            currentModelGlobeIcon.isHidden =
                provider.searchToolName == nil || provider.searchToolName!.isEmpty
            currentModelEyeIcon.isHidden = !provider.supportsImages
        } else {
            currentModelLabel.stringValue = "Unknown Model"
            currentModelGlobeIcon.isHidden = true
            currentModelEyeIcon.isHidden = true
        }
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

    public func submitPromptDirectly(_ text: String) {
        promptTextField.stringValue = text
        sendCurrentPrompt()
    }

    @objc private func toggleQueryExpansion() {
        isQueryExpanded.toggle()
        queryLabel.maximumNumberOfLines = isQueryExpanded ? 0 : 1
        queryLabel.cell?.lineBreakMode = isQueryExpanded ? .byWordWrapping : .byTruncatingTail
        let imageName = isQueryExpanded ? "chevron.up" : "chevron.down"
        expandArrowButton.image = NSImage(
            systemSymbolName: imageName, accessibilityDescription: nil)

        if isQueryExpanded {
            queryContainer.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.06).cgColor
            queryContainer.layer?.borderWidth = 1.0
            queryContainer.layer?.borderColor = NSColor.white.withAlphaComponent(0.12).cgColor
        } else {
            queryContainer.layer?.backgroundColor = NSColor.clear.cgColor
            queryContainer.layer?.borderWidth = 0.0
        }

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

    public func cancelGeneration() {
        guard activeTask != nil else { return }
        cancelActiveTask()

        if activeTurnIndex >= 0 && activeTurnIndex < turns.count {
            let response = turns[activeTurnIndex].response
            if response == "Generating..." {
                turns.remove(at: activeTurnIndex)
                activeTurnIndex = turns.count - 1
            }
        }
        updateCard()
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

        let wasCardHidden = cardView.isHidden

        if turns.isEmpty {
            queryContainer.isHidden = true
            cardView.isHidden = true
            sparkleImageView.isHidden = false
            referencesContainer.isHidden = true
            setResponseText("")
            hideWaveGenerating()
            return
        }

        sparkleImageView.isHidden = true
        cardView.isHidden = false

        guard activeTurnIndex >= 0 && activeTurnIndex < turns.count else { return }
        let turn = turns[activeTurnIndex]

        referencesContainer.update(with: turn.pciIcons)

        if turn.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            queryContainer.isHidden = true
            queryPlaceholder.isHidden = true
        } else {
            queryContainer.isHidden = false
            queryPlaceholder.isHidden = false
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

        let isGenerating = turn.response.hasPrefix("Generating")

        if isGenerating {
            // Show wave shimmer, hide text content
            responseScrollView.isHidden = true
            showWaveGenerating()
        } else {
            // Show real content, hide shimmer
            responseScrollView.isHidden = false
            hideWaveGenerating()
            setResponseText(turn.response)
        }

        scrollViewBottomToCardConstraint?.isActive = !isGenerating

        // Dynamic Height Calculation for Response Card
        if isGenerating {
            cardHeightConstraint?.constant = 60
        } else if let layoutManager = responseTextView.layoutManager,
            let textContainer = responseTextView.textContainer
        {
            layoutManager.ensureLayout(for: textContainer)
            let usedRect = layoutManager.usedRect(for: textContainer)
            // Include textContainerInset (top + bottom) in the height so the card is never
            // smaller than the text view's full frame, preventing the first line from clipping.
            let insetHeight = responseTextView.textContainerInset.height * 2
            let neededHeight = usedRect.height + insetHeight + 16  // 16 = card top+bottom padding
            let maxCardHeight = GlobalLayout.mainHeight - 160  // Leave space for query, prompt and padding
            cardHeightConstraint?.constant = min(neededHeight, maxCardHeight)
        }
    }

    // MARK: - Wave Generating
    private func showWaveGenerating() {
        waveGeneratingView.isHidden = false
        waveGeneratingView.startAnimation()
    }

    private func hideWaveGenerating() {
        waveGeneratingView.stopAnimation()
        waveGeneratingView.isHidden = true
    }

    // MARK: - Action Detail Builder
    /// Builds a human-readable detail string from an action payload to embed inside
    /// the `![action:type|detail]` tag so MarkdownParser can render it inline.
    private static func actionDetail(type: String, payload: [String: Any]) -> String {
        switch type.lowercased() {
        case "timer":
            let label = payload["label"] as? String ?? ""
            let duration = payload["duration"] as? Int ?? 0
            let minutes = duration / 60
            let seconds = duration % 60
            let timeStr: String
            if minutes > 0 {
                timeStr = seconds > 0 ? "\(minutes)m \(seconds)s" : "\(minutes)m"
            } else {
                timeStr = "\(seconds)s"
            }
            return label.isEmpty ? timeStr : "\(label) · \(timeStr)"
        case "reminder":
            return payload["title"] as? String ?? ""
        case "calendar":
            let title = payload["title"] as? String ?? ""
            let dateStr =
                (payload["date"] as? String)
                .flatMap { ISO8601DateFormatter().date(from: $0) }
                .map { d -> String in
                    let fmt = DateFormatter()
                    fmt.dateStyle = .medium
                    fmt.timeStyle = .short
                    return fmt.string(from: d)
                } ?? ""
            return dateStr.isEmpty ? title : "\(title) · \(dateStr)"
        case "memory":
            let content = payload["content"] as? String ?? ""
            return content.count > 50 ? String(content.prefix(50)) + "…" : content
        case "menubar":
            return payload["path"] as? String ?? "Menubar"
        case "note":
            let operation = payload["operation"] as? String ?? "edit"
            let filename = payload["filename"] as? String ?? "note"
            return "\(operation.capitalized) \(filename)"
        case "email":
            let subject = payload["subject"] as? String ?? "Email"
            return "Draft: \(subject)"
        default:
            return ""
        }
    }

    private func setResponseText(_ text: String) {
        if text.isEmpty {
            responseTextView.string = ""
            return
        }

        // Add a subtle cross-fade transition so newly streamed words smoothly fade in
        let transition = CATransition()
        transition.type = .fade
        transition.duration = 0.15  // Fast fade for streaming
        responseTextView.layer?.add(transition, forKey: "streamingFade")

        selectedNodeIndex = nil
        updateNodeSelectionPill()

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

        let font = NSFont.systemFont(ofSize: responseFontSize)

        let attrString = MarkdownParser.parse(
            markdown: text,
            baseFont: font,
            textColor: textColor,
            accentColor: accentColor
        )
        let mutableString = NSMutableAttributedString(attributedString: attrString)
        mutableString.removeAttribute(
            .link, range: NSRange(location: 0, length: mutableString.length))  // Remove native link clickability to allow our keyboard handling to take precedence or just rely on pill
        responseTextView.textStorage?.setAttributedString(mutableString)
    }

    private func updateMarkdownNodes() {
        guard let textStorage = responseTextView.textStorage else { return }
        markdownNodes.removeAll()
        textStorage.enumerateAttribute(
            NerwNodeKey, in: NSRange(location: 0, length: textStorage.length), options: []
        ) { value, range, _ in
            if let node = value as? NerwMarkdownNode {
                markdownNodes.append((range: range, node: node))
            }
        }
    }

    private func handleTab(shift: Bool) {
        updateMarkdownNodes()
        guard !markdownNodes.isEmpty else { return }

        if let current = selectedNodeIndex {
            if shift {
                selectedNodeIndex = (current - 1 + markdownNodes.count) % markdownNodes.count
            } else {
                selectedNodeIndex = (current + 1) % markdownNodes.count
            }
        } else {
            selectedNodeIndex = shift ? markdownNodes.count - 1 : 0
        }
        updateNodeSelectionPill()
    }

    private func handleExecuteNode() -> Bool {
        guard let index = selectedNodeIndex, index < markdownNodes.count else { return false }
        let node = markdownNodes[index].node
        executeNode(node)
        return true
    }

    private func handleCancelSelection() -> Bool {
        guard selectedNodeIndex != nil else { return false }
        selectedNodeIndex = nil
        updateNodeSelectionPill()
        return true
    }

    private func updateNodeSelectionPill() {
        guard let index = selectedNodeIndex, index < markdownNodes.count,
            let layoutManager = responseTextView.layoutManager,
            let textContainer = responseTextView.textContainer
        else {
            nodeSelectionPill.isHidden = true
            return
        }

        let range = markdownNodes[index].range
        let glyphRange = layoutManager.glyphRange(
            forCharacterRange: range, actualCharacterRange: nil)
        var rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)

        rect.origin.x -= 4
        rect.origin.y -= 2
        rect.size.width += 8
        rect.size.height += 4
        rect.origin.x += responseTextView.textContainerOrigin.x
        rect.origin.y += responseTextView.textContainerOrigin.y

        if nodeSelectionPill.isHidden {
            nodeSelectionPill.frame = rect
            nodeSelectionPill.isHidden = false
            nodeSelectionPill.alphaValue = 0
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.2
                nodeSelectionPill.animator().alphaValue = 1
            }
        } else {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.2
                ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                nodeSelectionPill.animator().frame = rect
            }
        }
        responseTextView.scrollToVisible(rect)
    }

    private func executeNode(_ node: NerwMarkdownNode) {
        switch node.type {
        case .link:
            if let url = URL(string: node.content) {
                NSWorkspace.shared.open(url)
                dismissController()
            }
        case .bold, .codeBlock:
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(node.content, forType: .string)

            dismissController()
            NSApp.hide(nil)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                let source = CGEventSource(stateID: .hidSystemState)
                let vDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
                vDown?.flags = .maskCommand
                let vUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
                vUp?.flags = .maskCommand

                vDown?.post(tap: .cghidEventTap)
                vUp?.post(tap: .cghidEventTap)
            }
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
        // Wave shimmer is shown directly via updateCard; we just keep the turn in a Generating state
        generatingTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) {
            [weak self] _ in
            guard let self = self else { return }
            self.generatingDotCount = (self.generatingDotCount + 1) % 4
            DispatchQueue.main.async {
                if self.turns.count > 0 && self.activeTurnIndex == self.turns.count - 1 {
                    if self.turns[self.activeTurnIndex].response.hasPrefix("Generating") {
                        // Keep the "Generating" prefix in the model so updateCard detects it.
                        // No need to update text view — waveGeneratingView handles display.
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

        // Extract PCI contexts for reference viewer
        var pciIcons: [(icon: String, name: String)] = []
        let intents = IntentClassifier.shared.classify(text).contextIntents
        for intent in intents {
            switch intent {
            case .clipboard:
                pciIcons.append(("doc.on.doc.fill", "Clipboard"))
            case .activeAppAndScreen:
                pciIcons.append(("eye.circle.fill", "Screen & App"))
            case .calendar:
                pciIcons.append(("calendar", "Calendar"))
            case .reminder:
                pciIcons.append(("checklist", "Reminders"))
            case .notes:
                pciIcons.append(("text.page.fill", "Notes"))
            case .system:
                break
            }
        }

        let categoryResult = QueryCategorizer.shared.classifySync(text)
        if categoryResult.category == .webSearch {
            if let provider = ConfigManager.shared.config.aiConfig.activeProvider,
                let tool = provider.searchToolName, !tool.isEmpty
            {
                pciIcons.append(("safari", "Web Search"))
            }
        }

        // Add turn to list
        let newTurn = ChatTurn(
            query: text, response: "Generating...", actionType: nil, actionPayload: nil,
            pciIcons: pciIcons)
        turns.append(newTurn)
        activeTurnIndex = turns.count - 1
        updateCard()
        startGeneratingAnimation()

        startGenerationTask(for: text)
    }

    private func startGenerationTask(for text: String) {
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
                        self.turns[self.activeTurnIndex].actionPayload = payload
                    }
                }
            }

            parser.onActionFormat = { type, payload in
                return Self.actionDetail(type: type, payload: payload)
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

    public func retryGeneration() {
        guard activeTurnIndex >= 0 && activeTurnIndex < turns.count else { return }

        cancelActiveTask()

        turns[activeTurnIndex].response = "Generating..."
        turns[activeTurnIndex].actionType = nil
        turns[activeTurnIndex].actionPayload = nil

        let text = turns[activeTurnIndex].query

        spinner.startAnimation()
        updateCard()
        startGeneratingAnimation()

        startGenerationTask(for: text)
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

        var modelOps: [NerwActionContext.Operation] = []
        let aiConfig = ConfigManager.shared.config.aiConfig
        for provider in aiConfig.providers {
            let isSelected = provider.id == aiConfig.selectedProviderId
            let detailText = isSelected ? "✓" : nil
            let op = NerwActionContext.Operation(
                id: "selectModel_\(provider.id)",
                kind: .custom("selectModel_\(provider.id)"),
                title: provider.name,
                subtitle: provider.modelName.isEmpty ? provider.type : provider.modelName,
                icon: .system(isSelected ? "checkmark.circle.fill" : "circle"),
                interaction: .execute,
                detailText: detailText
            )
            modelOps.append(op)
        }

        let modelSection = NerwActionContext.Section(
            id: "models",
            title: "Models",
            operations: modelOps
        )

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

        var conversationOps = [clearChatOp, moveUpOp, moveDownOp]
        let cancelGenerationOp = NerwActionContext.Operation(
            id: "cancelGeneration",
            kind: .custom("cancelGeneration"),
            title: "Cancel Generation",
            subtitle: "Stops the AI from generating further response",
            icon: .system("stop.circle"),
            interaction: .execute,
            detailText: "⌃C"
        )
        conversationOps.insert(cancelGenerationOp, at: 0)

        let retryGenerationOp = NerwActionContext.Operation(
            id: "retryGeneration",
            kind: .custom("retryGeneration"),
            title: "Retry",
            subtitle: "Regenerate the response for the current turn",
            icon: .system("arrow.clockwise"),
            interaction: .execute,
            detailText: "⌘R"
        )
        conversationOps.insert(retryGenerationOp, at: 1)

        let section = NerwActionContext.Section(
            id: "conversation",
            title: "Conversation",
            operations: conversationOps
        )

        let context = NerwActionContext(
            actionID: "conversationContext",
            actionTitle: "Conversation",
            actionSubtitle: "Manage current thread",
            sections: [modelSection, section]
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
            if customId.hasPrefix("selectModel_") {
                let providerId = String(customId.dropFirst("selectModel_".count))
                ConfigManager.shared.config.aiConfig.selectedProviderId = providerId
                ConfigManager.shared.save()
                updateModelIndicator()
                return
            }

            switch customId {
            case "cancelGeneration":
                cancelGeneration()
            case "retryGeneration":
                retryGeneration()
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

// MARK: - NSTextFieldDelegate
extension ConversationViewController: NSTextFieldDelegate {
    public func control(
        _ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector
    ) -> Bool {
        if commandSelector == #selector(insertTab(_:)) {
            handleTab(shift: false)
            return true
        }
        if commandSelector == #selector(insertBacktab(_:)) {
            handleTab(shift: true)
            return true
        }
        return false
    }
}
