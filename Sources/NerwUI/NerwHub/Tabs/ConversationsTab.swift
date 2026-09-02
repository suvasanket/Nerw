import Cocoa
import NerwBuiltin
import NerwCore

private let sharedTimeDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "h:mm a"
    return formatter
}()

private let sharedDateOnlyFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "MMM d"
    return formatter
}()

class ConversationsTab: BaseHubListTab<AIConversation> {
    override var tabTitle: String { "Conversations" }

    private let emptyStateView = NSView()
    private var allConversations: [AIConversation] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        setupEmptyState()
    }

    override func loadData() {
        allConversations = ConversationManager.shared.conversations.sorted(by: {
            $0.updatedAt > $1.updatedAt
        })
        applyFilter()
    }

    override func filter(with query: String) {
        super.filter(with: query)
        applyFilter()
    }

    private func applyFilter() {
        let q = currentQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if q.isEmpty {
            self.items = allConversations
        } else {
            self.items = allConversations.filter {
                $0.title.lowercased().contains(q) || $0.preview.lowercased().contains(q)
                    || $0.queryPreview.lowercased().contains(q)
            }
        }
        updateEmptyState()
    }

    private func setupEmptyState() {
        emptyStateView.translatesAutoresizingMaskIntoConstraints = false
        emptyStateView.isHidden = true
        view.addSubview(emptyStateView)

        let stack = NSStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 10
        emptyStateView.addSubview(stack)

        let iconView = NSImageView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        let iconConfig = NSImage.SymbolConfiguration(pointSize: 36, weight: .regular)
        iconView.image = NSImage(
            systemSymbolName: "bubble.left.and.bubble.right", accessibilityDescription: nil
        )?.withSymbolConfiguration(iconConfig)
        iconView.contentTintColor = .tertiaryLabelColor
        stack.addArrangedSubview(iconView)

        let titleLabel = NSTextField(labelWithString: "No AI Conversations Found")
        titleLabel.font = .systemFont(ofSize: 15, weight: .medium)
        titleLabel.textColor = .secondaryLabelColor
        stack.addArrangedSubview(titleLabel)

        let subtitleLabel = NSTextField(
            labelWithString: "Start a chat with NerwAI to see conversation history here.")
        subtitleLabel.font = .systemFont(ofSize: 12, weight: .regular)
        subtitleLabel.textColor = .tertiaryLabelColor
        stack.addArrangedSubview(subtitleLabel)

        NSLayoutConstraint.activate([
            emptyStateView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.centerXAnchor.constraint(equalTo: emptyStateView.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: emptyStateView.centerYAnchor),
        ])
    }

    private func updateEmptyState() {
        let isEmpty = items.isEmpty
        emptyStateView.isHidden = !isEmpty
        scrollView.isHidden = isEmpty
    }

    override func createRowView(for item: AIConversation) -> NSView {
        return ConversationRowView(conversation: item, delegate: self)
    }

    func didClickRow(_ rowView: ConversationRowView) {
        if let index = stackView.arrangedSubviews.firstIndex(of: rowView) {
            selectItem(at: index)
        }
    }

    private func findHubViewController() -> NerwHubViewController? {
        var responder: NSResponder? = self.view
        while responder != nil {
            if let vc = responder as? NerwHubViewController {
                return vc
            }
            responder = responder?.nextResponder
        }
        return nil
    }

    func openConversation(_ conversation: AIConversation) {
        let hubVC = findHubViewController()
        hubVC?.onDismiss?()
        ConversationManager.shared.openConversation(id: conversation.id)
    }

    func deleteConversation(_ conversation: AIConversation) {
        ConversationManager.shared.deleteConversation(id: conversation.id)
        loadData()
    }

    func clearAllConversations() {
        ConversationManager.shared.clearAll()
        loadData()
    }

    override func performPrimaryActionOnSelected() {
        guard let conversation = selectedItem else { return }
        openConversation(conversation)
    }

    override func performDeleteActionOnSelected() {
        guard let conversation = selectedItem else { return }
        deleteConversation(conversation)
    }
}

class ConversationRowView: NSView, HubSelectableRowView {
    let conversation: AIConversation
    private weak var delegate: ConversationsTab?
    var isRowSelected: Bool = false
    private var trackingArea: NSTrackingArea?

    init(conversation: AIConversation, delegate: ConversationsTab?) {
        self.conversation = conversation
        self.delegate = delegate
        super.init(frame: .zero)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.borderWidth = 1.0
        layer?.borderColor = NSColor.white.withAlphaComponent(0.08).cgColor
        layer?.backgroundColor = NSColor.white.withAlphaComponent(0.05).cgColor

        let height: CGFloat = 64

        // Icon Container
        let iconContainer = NSView()
        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.wantsLayer = true
        iconContainer.layer?.cornerRadius = 8
        iconContainer.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.08).cgColor
        addSubview(iconContainer)

        let iconView = NSImageView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        let iconConfig = NSImage.SymbolConfiguration(pointSize: 15, weight: .medium)
        iconView.image = NSImage(
            systemSymbolName: "bubble.left.and.bubble.right.fill", accessibilityDescription: nil
        )?.withSymbolConfiguration(iconConfig)
        iconView.contentTintColor = .white
        iconContainer.addSubview(iconView)

        // Text Stack (Title + Preview)
        let textStack = NSStackView()
        textStack.translatesAutoresizingMaskIntoConstraints = false
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 3
        textStack.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        addSubview(textStack)

        let titleLabel = NSTextField(labelWithString: conversation.title)
        titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = .labelColor
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        textStack.addArrangedSubview(titleLabel)

        let previewText =
            conversation.preview.isEmpty ? conversation.queryPreview : conversation.preview
        let cleanPreview = previewText.replacingOccurrences(of: "\n", with: " ")
        let previewLabel = NSTextField(labelWithString: cleanPreview)
        previewLabel.font = .systemFont(ofSize: 12)
        previewLabel.textColor = .secondaryLabelColor
        previewLabel.lineBreakMode = .byTruncatingTail
        previewLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        previewLabel.translatesAutoresizingMaskIntoConstraints = false
        textStack.addArrangedSubview(previewLabel)

        // Right side badges stack (Date/Time + Turn count pill)
        let metaStack = NSStackView()
        metaStack.translatesAutoresizingMaskIntoConstraints = false
        metaStack.orientation = .vertical
        metaStack.alignment = .trailing
        metaStack.spacing = 4
        addSubview(metaStack)

        let timeLabel = NSTextField(labelWithString: formattedDate(conversation.updatedAt))
        timeLabel.font = .systemFont(ofSize: 11, weight: .regular)
        timeLabel.textColor = .tertiaryLabelColor
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        metaStack.addArrangedSubview(timeLabel)

        let pillView = NSView()
        pillView.translatesAutoresizingMaskIntoConstraints = false
        pillView.wantsLayer = true
        pillView.layer?.cornerRadius = 6
        pillView.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.08).cgColor
        metaStack.addArrangedSubview(pillView)

        let turnCount = conversation.turns.count
        let countText = turnCount == 1 ? "1 msg" : "\(turnCount) msgs"
        let countLabel = NSTextField(labelWithString: countText)
        countLabel.font = .systemFont(ofSize: 10, weight: .medium)
        countLabel.textColor = .secondaryLabelColor
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        pillView.addSubview(countLabel)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: height),

            iconContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            iconContainer.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconContainer.widthAnchor.constraint(equalToConstant: 34),
            iconContainer.heightAnchor.constraint(equalToConstant: 34),

            iconView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),

            textStack.leadingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: 12),
            textStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            textStack.trailingAnchor.constraint(
                lessThanOrEqualTo: metaStack.leadingAnchor, constant: -14),

            metaStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            metaStack.centerYAnchor.constraint(equalTo: centerYAnchor),

            countLabel.topAnchor.constraint(equalTo: pillView.topAnchor, constant: 2),
            countLabel.bottomAnchor.constraint(equalTo: pillView.bottomAnchor, constant: -2),
            countLabel.leadingAnchor.constraint(equalTo: pillView.leadingAnchor, constant: 6),
            countLabel.trailingAnchor.constraint(equalTo: pillView.trailingAnchor, constant: -6),
        ])
    }

    private func formattedDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return sharedTimeDateFormatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            return sharedDateOnlyFormatter.string(from: date)
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
        if !isRowSelected {
            layer?.backgroundColor = NSColor.white.withAlphaComponent(0.09).cgColor
        }
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        if !isRowSelected {
            layer?.backgroundColor = NSColor.white.withAlphaComponent(0.05).cgColor
        }
    }

    func setSelected(_ selected: Bool, animated: Bool) {
        self.isRowSelected = selected

        let updateVisuals = {
            if selected {
                let accent = NSColor(hexString: "#61AEFF") ?? .controlAccentColor
                self.layer?.borderColor = accent.cgColor
                self.layer?.borderWidth = 1.5
                self.layer?.backgroundColor = accent.withAlphaComponent(0.12).cgColor
            } else {
                self.layer?.borderColor = NSColor.white.withAlphaComponent(0.08).cgColor
                self.layer?.borderWidth = 1.0
                self.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.05).cgColor
            }
        }

        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.12
                updateVisuals()
            }
        } else {
            updateVisuals()
        }
    }

    override func mouseDown(with event: NSEvent) {
        delegate?.didClickRow(self)
        if event.clickCount == 2 {
            delegate?.openConversation(conversation)
        }
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        delegate?.didClickRow(self)

        let menu = NSMenu()
        let openItem = NSMenuItem(
            title: "Open Conversation", action: #selector(openClicked), keyEquivalent: "\r")
        openItem.target = self
        menu.addItem(openItem)

        let deleteItem = NSMenuItem(
            title: "Delete Conversation", action: #selector(deleteClicked), keyEquivalent: "")
        deleteItem.target = self
        menu.addItem(deleteItem)

        menu.addItem(NSMenuItem.separator())

        let clearAllItem = NSMenuItem(
            title: "Clear All Conversations", action: #selector(clearAllClicked), keyEquivalent: "")
        clearAllItem.target = self
        menu.addItem(clearAllItem)

        return menu
    }

    @objc private func openClicked() {
        delegate?.openConversation(conversation)
    }

    @objc private func deleteClicked() {
        delegate?.deleteConversation(conversation)
    }

    @objc private func clearAllClicked() {
        delegate?.clearAllConversations()
    }
}
