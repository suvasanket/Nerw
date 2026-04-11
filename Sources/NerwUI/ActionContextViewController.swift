import Cocoa
import NerwAction
import NerwCore
import NerwSearchBackend

public enum ActionContextKeyboardCommand: Equatable {
    case moveUp
    case moveDown
    case activate
    case cancel
}

public enum ActionContextKeyboardRouter {
    public static func command(
        keyCode: UInt16,
        charactersIgnoringModifiers: String?,
        modifierFlags: NSEvent.ModifierFlags
    ) -> ActionContextKeyboardCommand? {
        let normalizedCharacters = charactersIgnoringModifiers?.lowercased()

        if modifierFlags.contains(.command), normalizedCharacters == "k" {
            return .cancel
        }

        if modifierFlags.contains(.control) {
            switch normalizedCharacters {
            case "n":
                return .moveDown
            case "p":
                return .moveUp
            default:
                break
            }
        }

        switch keyCode {
        case 125:
            return .moveDown
        case 126:
            return .moveUp
        case 36, 76:
            return .activate
        case 53:
            return .cancel
        default:
            return nil
        }
    }
}

public enum ActionContextSelection {
    public static func movedIndex(current: Int, delta: Int, count: Int) -> Int? {
        guard count > 0 else { return nil }
        return max(0, min(max(current, 0) + delta, count - 1))
    }
}

public enum ActionContextVisualBridge {
    public static func height(
        forSelectionBackgroundHeight selectionBackgroundHeight: CGFloat,
        availableHeight: CGFloat
    ) -> CGFloat {
        max(0, min(selectionBackgroundHeight, availableHeight))
    }
}

public enum ActionContextTypeSelect {
    public struct Item: Equatable {
        public let title: String
        public let keywords: [String]

        public init(title: String, keywords: [String] = []) {
            self.title = title
            self.keywords = keywords
        }
    }

    public static func normalizedQuery(_ value: String) -> String {
        String(
            value.lowercased().unicodeScalars.filter {
                CharacterSet.alphanumerics.contains($0)
            }
        )
    }

    public static func initials(for value: String) -> String {
        String(
            value.lowercased().split(whereSeparator: {
                !$0.isLetter && !$0.isNumber
            }).compactMap(\.first)
        )
    }

    public static func matchingIndex(query: String, currentIndex: Int, items: [Item]) -> Int? {
        let normalized = normalizedQuery(query)
        guard !normalized.isEmpty, !items.isEmpty else { return nil }

        let startIndex = max(currentIndex + 1, 0)

        for offset in 0..<items.count {
            let index = (startIndex + offset) % items.count
            if itemMatches(items[index], query: normalized) {
                return index
            }
        }

        return nil
    }

    static func normalizedCharacter(from characters: String?) -> String? {
        guard let characters, characters.count == 1 else { return nil }

        let normalized = normalizedQuery(characters)
        return normalized.isEmpty ? nil : normalized
    }

    private static func itemMatches(_ item: Item, query: String) -> Bool {
        searchableTokens(for: item).contains { $0.hasPrefix(query) }
    }

    private static func searchableTokens(for item: Item) -> [String] {
        Array(
            Set(
                ([item.title] + item.keywords).flatMap { value -> [String] in
                    let normalized = normalizedQuery(value)
                    let initialsValue = initials(for: value)
                    return [normalized, initialsValue].filter { !$0.isEmpty }
                })
        )
    }
}

protocol ActionContextViewControllerDelegate: AnyObject {
    func actionContext(
        _ controller: ActionContextViewController,
        didInvoke operation: NerwActionContext.Operation,
        in context: NerwActionContext
    )
    func actionContext(
        _ controller: ActionContextViewController,
        didUpdatePreferencesFor actionID: String
    )
    func actionContextDidRequestClose(_ controller: ActionContextViewController)
}

private final class ActionContextRootView: NSView {
    var commandHandler: ((ActionContextKeyboardCommand) -> Bool)?
    var typeSelectHandler: ((String) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        if handle(event) {
            return
        }
        super.keyDown(with: event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if handle(event) {
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    private func handle(_ event: NSEvent) -> Bool {
        if let command = ActionContextKeyboardRouter.command(
            keyCode: event.keyCode,
            charactersIgnoringModifiers: event.charactersIgnoringModifiers,
            modifierFlags: event.modifierFlags
        ), commandHandler?(command) == true {
            return true
        }

        let normalizedFlags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if normalizedFlags.subtracting([.shift]).isEmpty,
            let input = ActionContextTypeSelect.normalizedCharacter(
                from: event.charactersIgnoringModifiers)
        {
            typeSelectHandler?(input)
            return true
        }

        return false
    }
}

private final class ActionContextTableView: NSTableView {
    override var acceptsFirstResponder: Bool { false }
}

private final class ActionContextOperationCellView: NSTableCellView {
    private let separatorView = NSView()
    private let containerView = NSView()
    private let iconPlateView = NSView()
    private let iconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let detailLabel = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }

    private func setupViews() {
        separatorView.wantsLayer = true
        separatorView.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.08).cgColor
        separatorView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(separatorView)

        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = 10
        containerView.layer?.masksToBounds = true
        containerView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(containerView)

        iconPlateView.wantsLayer = true
        iconPlateView.layer?.cornerRadius = 9
        iconPlateView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(iconPlateView)

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.imageScaling = .scaleProportionallyUpOrDown
        containerView.addSubview(iconView)

        titleLabel.font = .systemFont(ofSize: 13, weight: .medium)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(titleLabel)

        detailLabel.font = .systemFont(ofSize: 11, weight: .regular)
        detailLabel.alignment = .right
        detailLabel.lineBreakMode = .byTruncatingMiddle
        detailLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        detailLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(detailLabel)

        NSLayoutConstraint.activate([
            separatorView.topAnchor.constraint(equalTo: topAnchor),
            separatorView.leadingAnchor.constraint(equalTo: leadingAnchor),
            separatorView.trailingAnchor.constraint(equalTo: trailingAnchor),
            separatorView.heightAnchor.constraint(equalToConstant: 1),

            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),

            iconPlateView.leadingAnchor.constraint(
                equalTo: containerView.leadingAnchor, constant: 12),
            iconPlateView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            iconPlateView.widthAnchor.constraint(equalToConstant: 18),
            iconPlateView.heightAnchor.constraint(equalToConstant: 18),

            iconView.centerXAnchor.constraint(equalTo: iconPlateView.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconPlateView.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 12),
            iconView.heightAnchor.constraint(equalToConstant: 12),

            titleLabel.leadingAnchor.constraint(
                equalTo: iconPlateView.trailingAnchor, constant: 8),
            titleLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            titleLabel.trailingAnchor.constraint(
                lessThanOrEqualTo: detailLabel.leadingAnchor, constant: -8),

            detailLabel.trailingAnchor.constraint(
                equalTo: containerView.trailingAnchor, constant: -12),
            detailLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            detailLabel.leadingAnchor.constraint(
                greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: 8),
        ])
    }

    func configure(
        operation: NerwActionContext.Operation,
        detailText: String?,
        isSelected: Bool,
        showsTopSeparator: Bool
    ) {
        titleLabel.stringValue = operation.title
        detailLabel.stringValue = detailText ?? ""
        detailLabel.isHidden = detailText == nil
        iconView.image = image(for: operation.icon)
        separatorView.isHidden = !showsTopSeparator

        let config = ConfigManager.shared.config.uiConfig
        let mainTextColor = NSColor(hex: config?.mainForegroundColor ?? "") ?? .labelColor
        let selectedTextColor =
            NSColor(hex: config?.selectionForegroundColor ?? "") ?? .white.withAlphaComponent(0.96)
        let selectionColor =
            NSColor(hex: config?.selectionBackgroundColor ?? "")?.withAlphaComponent(0.30)
            ?? NSColor.white.withAlphaComponent(0.14)

        titleLabel.textColor = isSelected ? selectedTextColor : mainTextColor
        detailLabel.textColor =
            isSelected
            ? selectedTextColor.withAlphaComponent(detailText == nil ? 0.0 : 0.72)
            : NSColor.secondaryLabelColor
        iconView.contentTintColor = isSelected ? selectedTextColor : mainTextColor

        containerView.layer?.backgroundColor =
            (isSelected ? selectionColor : NSColor.clear).cgColor
        containerView.layer?.borderColor = NSColor.clear.cgColor
        containerView.layer?.borderWidth = 0
        iconPlateView.layer?.backgroundColor =
            (isSelected ? NSColor.white.withAlphaComponent(0.12) : NSColor.clear).cgColor
    }

    private func image(for icon: NerwAction.IconType?) -> NSImage? {
        guard let icon else {
            return NSImage(systemSymbolName: "circle", accessibilityDescription: nil)
        }

        switch icon {
        case .system(let name):
            return NSImage(systemSymbolName: name, accessibilityDescription: nil)
                ?? NSImage(named: NSImage.Name(name))
        case .image(let image):
            return image
        case .file(let url):
            return NSWorkspace.shared.icon(forFile: url.path)
        }
    }
}

extension NerwAction.ModifierKey {
    fileprivate var actionContextSymbol: String {
        switch self {
        case .command:
            return "⌘"
        case .shift:
            return "⇧"
        case .control:
            return "⌃"
        case .option:
            return "⌥"
        }
    }
}

final class ActionContextViewController: NSViewController, NSTableViewDataSource,
    NSTableViewDelegate,
    NSTextFieldDelegate, KeybindRecorderDelegate
{
    private enum LayoutMetrics {
        static let connectorGapWidth: CGFloat = 8
        static let popupVerticalInset: CGFloat = 8
        static let popupHorizontalInset: CGFloat = 0
        static let editorPadding: CGFloat = 12
        static let cornerRadius: CGFloat = 18
        static let connectorLineWidth: CGFloat = 3
        static let rowHeight: CGFloat = 38
    }

    private struct OperationEntry {
        let sectionTitle: String
        let operation: NerwActionContext.Operation
        let detailText: String?
        let searchKeywords: [String]
        let showsTopSeparator: Bool
    }

    weak var delegate: ActionContextViewControllerDelegate?

    private let backgroundView = NSVisualEffectView()
    private let backgroundTintView = NSView()
    private let connectorLineView = NSView()
    private let strokesLayer = CAShapeLayer()
    private let tableView = ActionContextTableView()
    private let scrollView = NSScrollView()
    private let editorContainer = NSView()
    private let editorTitleLabel = NSTextField(labelWithString: "")
    private let editorHintLabel = NSTextField(labelWithString: "")
    private let aliasField = NSTextField()
    private let editorInputHost = NSView()

    private var hotkeyRecorder: KeybindRecorder?
    private var context: NerwActionContext?
    private var operations: [OperationEntry] = []
    private var editingOperation: NerwActionContext.Operation?
    private var selectedIndex: Int = -1
    private var isSynchronizingSelection = false
    private var typeSelectBuffer = ""
    private var lastTypeSelectTimestamp: TimeInterval = 0
    private var connectorSelectionHeight: CGFloat = 0
    private var connectorHeightConstraint: NSLayoutConstraint?

    private let typeSelectResetInterval: TimeInterval = 0.85
    private let genericPrimaryTitles: Set<String> = [
        "Run",
        "Default Action",
        "Start Inline Input",
        "Enter Arguments",
        "Open Form",
    ]

    private var rootView: ActionContextRootView {
        guard let rootView = view as? ActionContextRootView else {
            fatalError("ActionContextViewController root view mismatch")
        }
        return rootView
    }

    override func loadView() {
        view = ActionContextRootView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureKeyboardRouting()
        setupUI()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        focusCurrentMode()
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        updateShapeMask()
        updateConnectorLineHeight()
    }

    func focusForInteraction() {
        focusCurrentMode()
    }

    func render(context: NerwActionContext) {
        _ = view
        self.context = context
        operations = context.sections.enumerated().flatMap { sectionIndex, section in
            section.operations.enumerated().map { operationIndex, operation in
                let detailText = menuDetailText(for: operation, in: context)
                return OperationEntry(
                    sectionTitle: section.title,
                    operation: operation,
                    detailText: detailText,
                    searchKeywords: searchKeywords(
                        for: operation,
                        sectionTitle: section.title,
                        detailText: detailText,
                        context: context
                    ),
                    showsTopSeparator: sectionIndex > 0 && operationIndex == 0
                )
            }
        }

        clearTypeSelectState()
        editingOperation = nil
        editorContainer.isHidden = true
        scrollView.isHidden = false
        selectedIndex = operations.isEmpty ? -1 : 0

        applyBackgroundStyling()
        syncSelection()
        updatePreferredContentSize()
        updateConnectorLineHeight()

        DispatchQueue.main.async { [weak self] in
            self?.focusCurrentMode()
        }
    }

    func setConnectorSelectionHeight(_ height: CGFloat) {
        connectorSelectionHeight = max(0, height)
        updateConnectorLineHeight()
    }

    private func configureKeyboardRouting() {
        rootView.commandHandler = { [weak self] command in
            self?.handleKeyboardCommand(command) ?? false
        }
        rootView.typeSelectHandler = { [weak self] input in
            self?.handleTypeSelect(input)
        }
    }

    private func setupUI() {
        view.translatesAutoresizingMaskIntoConstraints = false
        view.wantsLayer = true

        backgroundView.material = .fullScreenUI
        backgroundView.appearance = NSAppearance(named: .vibrantDark)
        backgroundView.blendingMode = .behindWindow
        backgroundView.state = .active
        backgroundView.wantsLayer = true
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(backgroundView)

        backgroundTintView.wantsLayer = true
        backgroundTintView.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.addSubview(backgroundTintView)

        connectorLineView.wantsLayer = true
        connectorLineView.translatesAutoresizingMaskIntoConstraints = false
        connectorLineView.isHidden = true
        view.addSubview(connectorLineView)

        strokesLayer.fillColor = NSColor.clear.cgColor
        strokesLayer.lineWidth = 1
        backgroundView.layer?.addSublayer(strokesLayer)

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("operation"))
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.backgroundColor = .clear
        tableView.rowHeight = LayoutMetrics.rowHeight
        tableView.intercellSpacing = .zero
        tableView.selectionHighlightStyle = .none
        tableView.focusRingType = .none
        tableView.delegate = self
        tableView.dataSource = self
        tableView.allowsEmptySelection = false
        tableView.doubleAction = #selector(doubleClickSelection)
        tableView.target = self

        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = false
        scrollView.documentView = tableView
        scrollView.borderType = .noBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.addSubview(scrollView)

        editorContainer.wantsLayer = true
        editorContainer.layer?.cornerRadius = 14
        editorContainer.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.04).cgColor
        editorContainer.layer?.borderColor = NSColor.white.withAlphaComponent(0.08).cgColor
        editorContainer.layer?.borderWidth = 1
        editorContainer.isHidden = true
        editorContainer.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.addSubview(editorContainer)

        let editorStack = NSStackView()
        editorStack.orientation = .vertical
        editorStack.spacing = 10
        editorStack.alignment = .leading
        editorStack.translatesAutoresizingMaskIntoConstraints = false
        editorContainer.addSubview(editorStack)

        editorTitleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        editorStack.addArrangedSubview(editorTitleLabel)

        editorHintLabel.font = .systemFont(ofSize: 11)
        editorHintLabel.textColor = .secondaryLabelColor
        editorHintLabel.lineBreakMode = .byWordWrapping
        editorHintLabel.maximumNumberOfLines = 0
        editorStack.addArrangedSubview(editorHintLabel)

        editorInputHost.wantsLayer = true
        editorInputHost.layer?.cornerRadius = 12
        editorInputHost.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.06).cgColor
        editorInputHost.translatesAutoresizingMaskIntoConstraints = false
        editorStack.addArrangedSubview(editorInputHost)

        aliasField.placeholderString = "space-separated aliases"
        aliasField.font = .systemFont(ofSize: 13)
        aliasField.isBordered = false
        aliasField.drawsBackground = false
        aliasField.focusRingType = .none
        aliasField.delegate = self
        aliasField.translatesAutoresizingMaskIntoConstraints = false

        let connectorHeightConstraint = connectorLineView.heightAnchor.constraint(
            equalToConstant: 0)
        self.connectorHeightConstraint = connectorHeightConstraint

        NSLayoutConstraint.activate([
            backgroundView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundView.leadingAnchor.constraint(
                equalTo: view.leadingAnchor, constant: LayoutMetrics.connectorGapWidth),
            backgroundView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            backgroundTintView.topAnchor.constraint(equalTo: backgroundView.topAnchor),
            backgroundTintView.leadingAnchor.constraint(equalTo: backgroundView.leadingAnchor),
            backgroundTintView.trailingAnchor.constraint(equalTo: backgroundView.trailingAnchor),
            backgroundTintView.bottomAnchor.constraint(equalTo: backgroundView.bottomAnchor),

            connectorLineView.centerXAnchor.constraint(
                equalTo: view.leadingAnchor,
                constant: LayoutMetrics.connectorGapWidth / 2
            ),
            connectorLineView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            connectorLineView.widthAnchor.constraint(
                equalToConstant: LayoutMetrics.connectorLineWidth),
            connectorHeightConstraint,

            scrollView.topAnchor.constraint(
                equalTo: backgroundView.topAnchor, constant: LayoutMetrics.popupVerticalInset),
            scrollView.leadingAnchor.constraint(
                equalTo: backgroundView.leadingAnchor, constant: LayoutMetrics.popupHorizontalInset),
            scrollView.trailingAnchor.constraint(
                equalTo: backgroundView.trailingAnchor,
                constant: -LayoutMetrics.popupHorizontalInset),
            scrollView.bottomAnchor.constraint(
                equalTo: backgroundView.bottomAnchor, constant: -LayoutMetrics.popupVerticalInset),

            editorContainer.topAnchor.constraint(
                equalTo: backgroundView.topAnchor, constant: LayoutMetrics.popupVerticalInset),
            editorContainer.leadingAnchor.constraint(
                equalTo: backgroundView.leadingAnchor, constant: LayoutMetrics.popupHorizontalInset),
            editorContainer.trailingAnchor.constraint(
                equalTo: backgroundView.trailingAnchor,
                constant: -LayoutMetrics.popupHorizontalInset),
            editorContainer.bottomAnchor.constraint(
                equalTo: backgroundView.bottomAnchor, constant: -LayoutMetrics.popupVerticalInset),

            editorStack.topAnchor.constraint(
                equalTo: editorContainer.topAnchor, constant: LayoutMetrics.editorPadding),
            editorStack.leadingAnchor.constraint(
                equalTo: editorContainer.leadingAnchor, constant: LayoutMetrics.editorPadding),
            editorStack.trailingAnchor.constraint(
                equalTo: editorContainer.trailingAnchor, constant: -LayoutMetrics.editorPadding),
            editorStack.bottomAnchor.constraint(
                equalTo: editorContainer.bottomAnchor, constant: -LayoutMetrics.editorPadding),

            editorInputHost.widthAnchor.constraint(equalTo: editorStack.widthAnchor),
            editorInputHost.heightAnchor.constraint(equalToConstant: 36),
        ])

        applyBackgroundStyling()
    }

    private func applyBackgroundStyling() {
        let config = ConfigManager.shared.config.uiConfig
        let tintColor =
            NSColor(hex: config?.mainBackgroundColor ?? "")?.withAlphaComponent(0.22)
            ?? NSColor.black.withAlphaComponent(0.18)

        strokesLayer.strokeColor = NSColor.white.withAlphaComponent(0.12).cgColor
        backgroundTintView.layer?.backgroundColor = tintColor.cgColor
        connectorLineView.layer?.cornerRadius = LayoutMetrics.connectorLineWidth / 2
        connectorLineView.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.45).cgColor
    }

    private func updateShapeMask() {
        let bounds = backgroundView.bounds
        guard bounds.width > 0, bounds.height > 0 else { return }

        let path = CGPath(
            roundedRect: bounds,
            cornerWidth: LayoutMetrics.cornerRadius,
            cornerHeight: LayoutMetrics.cornerRadius,
            transform: nil
        )

        let maskLayer = CAShapeLayer()
        maskLayer.path = path
        backgroundView.layer?.mask = maskLayer

        strokesLayer.path = path
        strokesLayer.frame = bounds
    }

    private func updateConnectorLineHeight() {
        guard let connectorHeightConstraint else { return }

        let availableHeight = max(0, max(view.bounds.height, preferredContentSize.height))
        let height = ActionContextVisualBridge.height(
            forSelectionBackgroundHeight: connectorSelectionHeight,
            availableHeight: availableHeight
        )

        connectorHeightConstraint.constant = height
        connectorLineView.isHidden = height <= 0.5
    }

    private func focusCurrentMode() {
        guard let window = view.window else { return }

        if editingOperation != nil {
            if hotkeyRecorder != nil {
                DispatchQueue.main.async { [weak self] in
                    self?.hotkeyRecorder?.beginRecording()
                }
            } else {
                window.makeFirstResponder(aliasField)
                aliasField.currentEditor()?.selectedRange = NSRange(
                    location: aliasField.stringValue.count,
                    length: 0
                )
            }
            return
        }

        window.makeFirstResponder(rootView)
    }

    private func updatePreferredContentSize() {
        let width: CGFloat = 332 + LayoutMetrics.connectorGapWidth

        if editingOperation != nil {
            preferredContentSize = NSSize(width: width, height: 184)
            return
        }

        let visibleRows = CGFloat(min(max(operations.count, 1), 6))
        let height = max(96, 26 + visibleRows * LayoutMetrics.rowHeight)
        preferredContentSize = NSSize(width: width, height: height)
    }

    private func syncSelection() {
        isSynchronizingSelection = true
        defer { isSynchronizingSelection = false }

        tableView.reloadData()

        if selectedIndex >= 0, selectedIndex < operations.count {
            tableView.selectRowIndexes(
                IndexSet(integer: selectedIndex), byExtendingSelection: false)
            tableView.scrollRowToVisible(selectedIndex)
        } else {
            tableView.deselectAll(nil)
        }
    }

    private func moveSelection(by delta: Int) {
        clearTypeSelectState()

        guard
            let nextIndex = ActionContextSelection.movedIndex(
                current: selectedIndex,
                delta: delta,
                count: operations.count
            )
        else { return }

        selectedIndex = nextIndex
        syncSelection()
    }

    private func handleKeyboardCommand(_ command: ActionContextKeyboardCommand) -> Bool {
        guard editingOperation == nil else {
            if command == .cancel {
                delegate?.actionContextDidRequestClose(self)
                return true
            }
            return false
        }

        switch command {
        case .moveUp:
            moveSelection(by: -1)
        case .moveDown:
            moveSelection(by: 1)
        case .activate:
            activateSelectedOperation()
        case .cancel:
            delegate?.actionContextDidRequestClose(self)
        }

        return true
    }

    private func handleTypeSelect(_ input: String) {
        guard editingOperation == nil else { return }

        let currentTimestamp = Date.timeIntervalSinceReferenceDate
        let nextQuery: String

        if currentTimestamp - lastTypeSelectTimestamp > typeSelectResetInterval {
            nextQuery = input
        } else if typeSelectBuffer == input && typeSelectBuffer.count == 1 {
            nextQuery = input
        } else {
            nextQuery = typeSelectBuffer + input
        }

        let items = operations.map {
            ActionContextTypeSelect.Item(title: $0.operation.title, keywords: $0.searchKeywords)
        }

        if let nextIndex = ActionContextTypeSelect.matchingIndex(
            query: nextQuery,
            currentIndex: selectedIndex,
            items: items
        ) {
            typeSelectBuffer = nextQuery
            lastTypeSelectTimestamp = currentTimestamp
            selectedIndex = nextIndex
            syncSelection()
            return
        }

        if nextQuery != input,
            let fallbackIndex = ActionContextTypeSelect.matchingIndex(
                query: input,
                currentIndex: selectedIndex,
                items: items
            )
        {
            typeSelectBuffer = input
            lastTypeSelectTimestamp = currentTimestamp
            selectedIndex = fallbackIndex
            syncSelection()
            return
        }

        typeSelectBuffer = input
        lastTypeSelectTimestamp = currentTimestamp
    }

    private func clearTypeSelectState() {
        typeSelectBuffer = ""
        lastTypeSelectTimestamp = 0
    }

    @objc private func doubleClickSelection() {
        activateSelectedOperation()
    }

    private func activateSelectedOperation() {
        clearTypeSelectState()

        guard let context, selectedIndex >= 0, selectedIndex < operations.count else { return }

        let operation = operations[selectedIndex].operation
        switch operation.interaction {
        case .execute:
            delegate?.actionContext(self, didInvoke: operation, in: context)
        case .textInput(let placeholder, let value):
            showAliasEditor(operation: operation, placeholder: placeholder, value: value)
        case .hotkeyInput(let value):
            showHotkeyEditor(operation: operation, value: value)
        case .toggle:
            commitToggleEnabled()
        }
    }

    private func commitToggleEnabled() {
        guard let context, selectedIndex >= 0, selectedIndex < operations.count else { return }
        let operation = operations[selectedIndex].operation
        guard operation.kind == .toggleEnabled else { return }

        let currentEnabled = NerwActionEnabled.get(for: context.actionID)
        let nextEnabled = !currentEnabled
        NerwActionEnabled.set(nextEnabled, for: context.actionID)

        // Show feedback
        let status = nextEnabled ? "enabled" : "disabled"
        NerwNotificationManager.shared.show(
            content: "Action \(status): \(context.actionTitle)",
            level: .info
        )

        // Refresh the context UI
        delegate?.actionContext(self, didUpdatePreferencesFor: context.actionID)
        delegate?.actionContextDidRequestClose(self)
    }

    private func showAliasEditor(
        operation: NerwActionContext.Operation,
        placeholder: String,
        value: String
    ) {
        editingOperation = operation
        scrollView.isHidden = true
        editorContainer.isHidden = false
        editorTitleLabel.stringValue = operation.title
        editorHintLabel.stringValue = operation.subtitle

        clearEditorInputHost()
        aliasField.placeholderString = placeholder
        aliasField.stringValue = value
        editorInputHost.addSubview(aliasField)
        NSLayoutConstraint.activate([
            aliasField.leadingAnchor.constraint(
                equalTo: editorInputHost.leadingAnchor, constant: 10),
            aliasField.trailingAnchor.constraint(
                equalTo: editorInputHost.trailingAnchor, constant: -10),
            aliasField.topAnchor.constraint(equalTo: editorInputHost.topAnchor),
            aliasField.bottomAnchor.constraint(equalTo: editorInputHost.bottomAnchor),
        ])

        hotkeyRecorder = nil
        updatePreferredContentSize()
        focusCurrentMode()
    }

    private func showHotkeyEditor(operation: NerwActionContext.Operation, value: String) {
        editingOperation = operation
        scrollView.isHidden = true
        editorContainer.isHidden = false
        editorTitleLabel.stringValue = operation.title
        editorHintLabel.stringValue =
            "Record a shortcut now. Press Delete to clear, or Esc to close."

        clearEditorInputHost()
        let recorder = KeybindRecorder(keybind: value)
        recorder.delegate = self
        recorder.translatesAutoresizingMaskIntoConstraints = false
        hotkeyRecorder = recorder
        editorInputHost.addSubview(recorder)
        NSLayoutConstraint.activate([
            recorder.leadingAnchor.constraint(equalTo: editorInputHost.leadingAnchor),
            recorder.trailingAnchor.constraint(equalTo: editorInputHost.trailingAnchor),
            recorder.topAnchor.constraint(equalTo: editorInputHost.topAnchor),
            recorder.bottomAnchor.constraint(equalTo: editorInputHost.bottomAnchor),
        ])

        updatePreferredContentSize()
        focusCurrentMode()
    }

    private func clearEditorInputHost() {
        for subview in editorInputHost.subviews {
            subview.removeFromSuperview()
        }
    }

    private func commitAliasEdit() {
        guard let context else { return }
        NerwActionPreferenceManager.shared.updateAliases(
            rawValue: aliasField.stringValue,
            for: context.actionID
        )
        delegate?.actionContext(self, didUpdatePreferencesFor: context.actionID)
        delegate?.actionContextDidRequestClose(self)
    }

    private func menuDetailText(
        for operation: NerwActionContext.Operation,
        in context: NerwActionContext
    ) -> String? {
        switch operation.kind {
        case .primary:
            if operation.title == "Start Inline Input" || operation.title == "Enter Arguments" {
                return "⇥"
            }
            return "⏎"
        case .secondary:
            return "⇥"
        case .modifier(let key):
            return "\(key.actionContextSymbol) ⏎"
        case .alias:
            if case .textInput(_, let value) = operation.interaction, !value.isEmpty {
                return value
            }
            return nil
        case .hotkey:
            if case .hotkeyInput(let value) = operation.interaction, !value.isEmpty {
                return value
            }
            return nil
        case .toggleEnabled:
            return nil
        }
    }

    private func searchKeywords(
        for operation: NerwActionContext.Operation,
        sectionTitle: String,
        detailText: String?,
        context: NerwActionContext
    ) -> [String] {
        var keywords = [context.actionTitle, sectionTitle]

        if !operation.subtitle.isEmpty {
            keywords.append(operation.subtitle)
        }

        if let detailText, !detailText.isEmpty {
            keywords.append(detailText)
        }

        return keywords
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        operations.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int)
        -> NSView?
    {
        guard row < operations.count else { return nil }

        let identifier = NSUserInterfaceItemIdentifier("ActionContextOperationCell")
        let cell =
            tableView.makeView(withIdentifier: identifier, owner: self)
            as? ActionContextOperationCellView
            ?? {
                let created = ActionContextOperationCellView()
                created.identifier = identifier
                return created
            }()

        let entry = operations[row]
        cell.configure(
            operation: entry.operation,
            detailText: entry.detailText,
            isSelected: row == selectedIndex,
            showsTopSeparator: entry.showsTopSeparator
        )
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard !isSynchronizingSelection else { return }
        guard tableView.selectedRow >= 0, tableView.selectedRow < operations.count else { return }

        clearTypeSelectState()
        selectedIndex = tableView.selectedRow
        tableView.reloadData()
        focusCurrentMode()
    }

    func keybindRecorder(_ recorder: KeybindRecorder, didChangeKeybind keybind: String) {
        guard let context else { return }
        NerwActionPreferenceManager.shared.updateHotkey(keybind, for: context.actionID)
        delegate?.actionContext(self, didUpdatePreferencesFor: context.actionID)
        delegate?.actionContextDidRequestClose(self)
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector)
        -> Bool
    {
        guard control === aliasField else { return false }

        switch commandSelector {
        case #selector(NSResponder.insertNewline(_:)),
            #selector(NSResponder.insertNewlineIgnoringFieldEditor(_:)),
            #selector(NSResponder.insertLineBreak(_:)):
            commitAliasEdit()
            return true
        case #selector(NSResponder.cancelOperation(_:)):
            delegate?.actionContextDidRequestClose(self)
            return true
        default:
            return false
        }
    }
}
