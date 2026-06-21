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
        self.placeholderString = "Ask AI..."
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let keyCode = event.keyCode
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

        // 1. Header Bar
        let headerView = NSStackView()
        headerView.orientation = .horizontal
        headerView.alignment = .centerY
        headerView.edgeInsets = NSEdgeInsets(top: 10, left: 16, bottom: 8, right: 16)
        headerView.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = NSTextField(labelWithString: "AI Assistant")
        titleLabel.font = .systemFont(ofSize: 13, weight: .bold)
        titleLabel.textColor = .labelColor
        headerView.addArrangedSubview(titleLabel)

        headerView.addArrangedSubview(NSView())  // Spacer

        let clearButton = HoverButton(
            title: "Clear Chat", target: self, action: #selector(clearChat))
        headerView.addArrangedSubview(clearButton)

        contentView.addSubview(headerView)

        let separator = NSView()
        separator.wantsLayer = true
        separator.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.08).cgColor
        separator.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(separator)

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
        promptContainer.layer?.borderColor = NSColor.white.withAlphaComponent(0.12).cgColor
        promptContainer.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.06).cgColor
        contentView.addSubview(promptContainer)

        promptTextField.onSubmit = { [weak self] in
            self?.sendCurrentPrompt()
        }
        promptTextField.onCancel = { [weak self] in
            self?.dismissController()
        }
        promptTextField.translatesAutoresizingMaskIntoConstraints = false
        promptContainer.addSubview(promptTextField)

        // 4. Response Card (Main content area)
        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.wantsLayer = true
        cardView.layer?.cornerRadius = 16
        cardView.layer?.borderWidth = 1.0
        contentView.addSubview(cardView)

        // Query capsule label on top right of card
        queryContainer.translatesAutoresizingMaskIntoConstraints = false
        queryContainer.wantsLayer = true
        queryContainer.layer?.cornerRadius = 10
        queryContainer.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.08).cgColor
        queryContainer.layer?.borderColor = NSColor.white.withAlphaComponent(0.12).cgColor
        queryContainer.layer?.borderWidth = 1.0
        cardView.addSubview(queryContainer)

        queryLabel.font = .systemFont(ofSize: 10, weight: .bold)
        queryLabel.textColor = .white.withAlphaComponent(0.8)
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

        // Constraints setup
        NSLayoutConstraint.activate([
            // Header
            headerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 38),

            // Separator
            separator.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            separator.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1),

            // Left Indicator bars
            indicatorContainer.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor, constant: 16),
            indicatorContainer.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            indicatorContainer.widthAnchor.constraint(equalToConstant: 16),
            indicatorContainer.topAnchor.constraint(
                greaterThanOrEqualTo: separator.bottomAnchor, constant: 16),
            indicatorContainer.bottomAnchor.constraint(
                lessThanOrEqualTo: promptContainer.topAnchor, constant: -16),

            // Prompt Container
            promptContainer.leadingAnchor.constraint(
                equalTo: indicatorContainer.trailingAnchor, constant: 16),
            promptContainer.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor, constant: -16),
            promptContainer.bottomAnchor.constraint(
                equalTo: contentView.bottomAnchor, constant: -16),
            promptContainer.heightAnchor.constraint(equalToConstant: 44),

            promptTextField.leadingAnchor.constraint(
                equalTo: promptContainer.leadingAnchor, constant: 16),
            promptTextField.trailingAnchor.constraint(
                equalTo: promptContainer.trailingAnchor, constant: -16),
            promptTextField.centerYAnchor.constraint(equalTo: promptContainer.centerYAnchor),

            // Response Card
            cardView.topAnchor.constraint(equalTo: separator.bottomAnchor, constant: 16),
            cardView.leadingAnchor.constraint(
                equalTo: indicatorContainer.trailingAnchor, constant: 16),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            cardView.bottomAnchor.constraint(equalTo: promptContainer.topAnchor, constant: -16),

            // Query Container in Top Right of Card
            queryContainer.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 12),
            queryContainer.trailingAnchor.constraint(
                equalTo: cardView.trailingAnchor, constant: -12),
            queryContainer.heightAnchor.constraint(equalToConstant: 20),
            queryContainer.leadingAnchor.constraint(
                greaterThanOrEqualTo: cardView.leadingAnchor, constant: 100),

            queryLabel.leadingAnchor.constraint(equalTo: queryContainer.leadingAnchor, constant: 8),
            queryLabel.trailingAnchor.constraint(
                equalTo: queryContainer.trailingAnchor, constant: -8),
            queryLabel.centerYAnchor.constraint(equalTo: queryContainer.centerYAnchor),

            // Response Scroll View in Card
            responseScrollView.topAnchor.constraint(
                equalTo: queryContainer.bottomAnchor, constant: 12),
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

        // Apply theme colors to card
        cardView.layer?.backgroundColor = selectionColor.withAlphaComponent(0.18).cgColor
        cardView.layer?.borderColor = selectionColor.withAlphaComponent(0.35).cgColor

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
            responseTextView.string =
                "Welcome to AI Chat! Type a prompt in the input field below to ask your first question. You can navigate through past questions using the indicators on the left."
            return
        }

        guard activeTurnIndex >= 0 && activeTurnIndex < turns.count else { return }
        let turn = turns[activeTurnIndex]

        queryLabel.stringValue = "Query: \(turn.query)"
        responseTextView.string = turn.response
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

        // Add turn to list
        let newTurn = ChatTurn(query: text, response: "Thinking...")
        turns.append(newTurn)
        activeTurnIndex = turns.count - 1

        updateCard()

        Logger.shared.info(
            "ConversationViewController: Starting async Task for AI response generation...")
        activeTask = Task {
            var fullResponse = ""
            var startedStream = false

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

                    if !startedStream {
                        startedStream = true
                        fullResponse = ""
                        Logger.shared.info(
                            "ConversationViewController: First stream chunk received, clearing 'Thinking...'"
                        )
                    }
                    fullResponse += delta

                    let currentText = fullResponse
                    await MainActor.run { [weak self] in
                        guard let self = self else { return }
                        // Ensure we are still displaying the active turn
                        if self.activeTurnIndex == self.turns.count - 1 {
                            self.turns[self.activeTurnIndex].response = currentText
                            self.responseTextView.string = currentText
                        }
                    }
                }

                if !Task.isCancelled {
                    let finalResponse = fullResponse
                    Logger.shared.info(
                        "ConversationViewController: Stream finished successfully. Response length: \(finalResponse.count)"
                    )
                    await MainActor.run { [weak self] in
                        guard let self = self else { return }
                        self.turns[self.turns.count - 1].response = finalResponse
                        if self.activeTurnIndex == self.turns.count - 1 {
                            self.responseTextView.string = finalResponse
                        }
                    }
                }
            } catch {
                if !Task.isCancelled {
                    let errMsg = "Error: \(error.localizedDescription)"
                    Logger.shared.error(
                        "ConversationViewController: Caught error during stream: \(errMsg)")
                    await MainActor.run { [weak self] in
                        guard let self = self else { return }
                        self.turns[self.turns.count - 1].response = errMsg
                        if self.activeTurnIndex == self.turns.count - 1 {
                            self.responseTextView.string = errMsg
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

        NSLayoutConstraint.activate([
            warning.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            warning.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            warning.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
        ])
    }
}
