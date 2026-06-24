import Cocoa
import NerwAction
import NerwBuiltin
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
            let navStyle = ConfigManager.shared.config.navigationStyle
            if navStyle == "vim" {
                switch normalizedCharacters {
                case "j":
                    return .moveDown
                case "k":
                    return .moveUp
                default:
                    break
                }
            } else {
                switch normalizedCharacters {
                case "n":
                    return .moveDown
                case "p":
                    return .moveUp
                default:
                    break
                }
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
    private let titleStackView = NSStackView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let searchIconView = NSImageView()
    private let visionIconView = NSImageView()
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

        titleStackView.orientation = .horizontal
        titleStackView.spacing = 4
        titleStackView.alignment = .centerY
        titleStackView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(titleStackView)

        titleLabel.font = .systemFont(ofSize: 13, weight: .medium)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        titleStackView.addArrangedSubview(titleLabel)

        let configSymbol = NSImage.SymbolConfiguration(pointSize: 10, weight: .regular)
        searchIconView.image = NSImage(systemSymbolName: "globe", accessibilityDescription: nil)?
            .withSymbolConfiguration(configSymbol)
        searchIconView.translatesAutoresizingMaskIntoConstraints = false
        titleStackView.addArrangedSubview(searchIconView)

        visionIconView.image = NSImage(systemSymbolName: "eye", accessibilityDescription: nil)?
            .withSymbolConfiguration(configSymbol)
        visionIconView.translatesAutoresizingMaskIntoConstraints = false
        titleStackView.addArrangedSubview(visionIconView)

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

            titleStackView.leadingAnchor.constraint(
                equalTo: iconPlateView.trailingAnchor, constant: 8),
            titleStackView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            titleStackView.trailingAnchor.constraint(
                lessThanOrEqualTo: detailLabel.leadingAnchor, constant: -8),

            detailLabel.trailingAnchor.constraint(
                equalTo: containerView.trailingAnchor, constant: -12),
            detailLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            detailLabel.leadingAnchor.constraint(
                greaterThanOrEqualTo: titleStackView.trailingAnchor, constant: 8),
        ])
    }

    func configure(
        operation: NerwActionContext.Operation,
        detailText: String?,
        isSelected: Bool,
        showsTopSeparator: Bool
    ) {
        titleLabel.stringValue = operation.title
        searchIconView.isHidden = true
        visionIconView.isHidden = true

        if case .custom(let customId) = operation.kind, customId.hasPrefix("selectModel_") {
            let providerId = String(customId.dropFirst("selectModel_".count))
            if let provider = ConfigManager.shared.config.aiConfig.providers.first(where: {
                $0.id == providerId
            }) {
                searchIconView.isHidden =
                    (provider.searchToolName == nil || provider.searchToolName!.isEmpty)
                visionIconView.isHidden = !provider.supportsImages
            }
        }
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
        searchIconView.contentTintColor =
            isSelected
            ? selectedTextColor.withAlphaComponent(0.6) : mainTextColor.withAlphaComponent(0.5)
        visionIconView.contentTintColor =
            isSelected
            ? selectedTextColor.withAlphaComponent(0.6) : mainTextColor.withAlphaComponent(0.5)
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
        case .none:
            return nil
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

    private let backgroundContainer = NSView()
    private var isUsingGlassEffect = false
    private let backgroundTintView = NSView()
    private let connectorLineView = NSView()
    private let strokesLayer = CAShapeLayer()
    private let tableView = ActionContextTableView()
    private let scrollView = NSScrollView()
    let searchContainer = NSView()
    let searchField = ThemedTextField()
    private let editorContainer = NSView()
    private let editorTitleLabel = NSTextField(labelWithString: "")
    private let editorHintLabel = NSTextField(labelWithString: "")
    private let aliasField = NSTextField()
    private let editorInputHost = NSView()

    private var hotkeyRecorder: KeybindRecorder?
    private var context: NerwActionContext?
    private var operations: [OperationEntry] = []
    private var allOperations: [OperationEntry] = []
    private var editingOperation: NerwActionContext.Operation?
    private var selectedIndex: Int = -1
    private var isSynchronizingSelection = false
    private var typeSelectBuffer = ""
    private var lastTypeSelectTimestamp: TimeInterval = 0
    private var connectorSelectionHeight: CGFloat = 0
    private var connectorHeightConstraint: NSLayoutConstraint?
    private var backgroundLeadingConstraint: NSLayoutConstraint?
    var isInlineMode: Bool = false

    private let typeSelectResetInterval: TimeInterval = 0.85
    private let genericPrimaryTitles: Set<String> = [
        "Run",
        "Default Action",
        "Start Inline Input",
        "Enter Arguments",
        "Open Form",
    ]

    override var preferredContentSize: NSSize {
        didSet {
            guard let window = view.window else { return }
            var frame = window.frame
            let oldHeight = frame.size.height
            let newHeight = preferredContentSize.height
            let delta = newHeight - oldHeight

            frame.origin.y -= delta
            frame.size.width = preferredContentSize.width
            frame.size.height = preferredContentSize.height
            window.setFrame(frame, display: true, animate: false)
        }
    }

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

        allOperations = context.sections.enumerated().flatMap { sectionIndex, section in
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

        searchField.stringValue = ""
        clearTypeSelectState()
        editingOperation = nil
        editorContainer.isHidden = true
        scrollView.isHidden = false
        searchContainer.isHidden = false

        filterOperations(for: "")

        applyBackgroundStyling()
        applyInlineMode()

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
        view.layer?.backgroundColor = NSColor.clear.cgColor

        backgroundContainer.wantsLayer = true
        backgroundContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(backgroundContainer)

        let activeBackground: NSView
        if #available(macOS 26.0, *), NerwTheme.current().liquidGlassEnabled {
            isUsingGlassEffect = true
            let glass = NSGlassEffectView()
            glass.style = .regular
            glass.appearance = NSAppearance(named: .vibrantDark)
            glass.cornerRadius = LayoutMetrics.cornerRadius
            glass.translatesAutoresizingMaskIntoConstraints = false
            backgroundContainer.addSubview(glass)
            activeBackground = glass
            strokesLayer.isHidden = true
        } else {
            let legacy = NSVisualEffectView()
            legacy.material = .fullScreenUI
            legacy.appearance = NSAppearance(named: .vibrantDark)
            legacy.blendingMode = .behindWindow
            legacy.state = .active
            legacy.wantsLayer = true
            legacy.translatesAutoresizingMaskIntoConstraints = false
            backgroundContainer.addSubview(legacy)
            activeBackground = legacy
        }

        NSLayoutConstraint.activate([
            activeBackground.leadingAnchor.constraint(equalTo: backgroundContainer.leadingAnchor),
            activeBackground.trailingAnchor.constraint(equalTo: backgroundContainer.trailingAnchor),
            activeBackground.topAnchor.constraint(equalTo: backgroundContainer.topAnchor),
            activeBackground.bottomAnchor.constraint(equalTo: backgroundContainer.bottomAnchor),
        ])

        backgroundTintView.wantsLayer = true
        backgroundTintView.translatesAutoresizingMaskIntoConstraints = false
        backgroundContainer.addSubview(backgroundTintView)

        connectorLineView.wantsLayer = true
        connectorLineView.translatesAutoresizingMaskIntoConstraints = false
        connectorLineView.isHidden = true
        view.addSubview(connectorLineView)

        strokesLayer.fillColor = NSColor.clear.cgColor
        strokesLayer.lineWidth = 1
        backgroundContainer.layer?.addSublayer(strokesLayer)

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

        searchContainer.wantsLayer = true
        searchContainer.layer?.cornerRadius = 14
        searchContainer.layer?.masksToBounds = true
        searchContainer.translatesAutoresizingMaskIntoConstraints = false
        backgroundContainer.addSubview(searchContainer)

        searchField.isBordered = false
        searchField.drawsBackground = false
        searchField.focusRingType = .none
        searchField.font = .systemFont(ofSize: 12, weight: .regular)
        searchField.usesSingleLineMode = true
        searchField.delegate = self
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchContainer.addSubview(searchField)

        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = false
        scrollView.documentView = tableView
        scrollView.borderType = .noBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        backgroundContainer.addSubview(scrollView)

        editorContainer.wantsLayer = true
        editorContainer.isHidden = true
        editorContainer.translatesAutoresizingMaskIntoConstraints = false
        backgroundContainer.addSubview(editorContainer)

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
        editorHintLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        editorStack.addArrangedSubview(editorHintLabel)

        editorInputHost.wantsLayer = true
        editorInputHost.layer?.cornerRadius = 12
        editorInputHost.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.06).cgColor
        editorInputHost.translatesAutoresizingMaskIntoConstraints = false
        editorStack.addArrangedSubview(editorInputHost)

        aliasField.placeholderString = "space-separated aliases"
        aliasField.font = .systemFont(ofSize: 13)
        aliasField.alignment = .center
        aliasField.usesSingleLineMode = true
        aliasField.isBordered = false
        aliasField.drawsBackground = false
        aliasField.focusRingType = .none
        aliasField.delegate = self
        aliasField.translatesAutoresizingMaskIntoConstraints = false

        let connectorHeightConstraint = connectorLineView.heightAnchor.constraint(
            equalToConstant: 0)
        self.connectorHeightConstraint = connectorHeightConstraint

        let bgLeading = backgroundContainer.leadingAnchor.constraint(
            equalTo: view.leadingAnchor, constant: LayoutMetrics.connectorGapWidth)
        self.backgroundLeadingConstraint = bgLeading

        NSLayoutConstraint.activate([
            backgroundContainer.topAnchor.constraint(equalTo: view.topAnchor),
            bgLeading,
            backgroundContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            backgroundTintView.topAnchor.constraint(equalTo: backgroundContainer.topAnchor),
            backgroundTintView.leadingAnchor.constraint(equalTo: backgroundContainer.leadingAnchor),
            backgroundTintView.trailingAnchor.constraint(
                equalTo: backgroundContainer.trailingAnchor),
            backgroundTintView.bottomAnchor.constraint(equalTo: backgroundContainer.bottomAnchor),

            connectorLineView.centerXAnchor.constraint(
                equalTo: view.leadingAnchor,
                constant: LayoutMetrics.connectorGapWidth / 2
            ),
            connectorLineView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            connectorLineView.widthAnchor.constraint(
                equalToConstant: LayoutMetrics.connectorLineWidth),
            connectorHeightConstraint,

            searchContainer.topAnchor.constraint(
                equalTo: backgroundContainer.topAnchor, constant: 10),
            searchContainer.leadingAnchor.constraint(
                equalTo: backgroundContainer.leadingAnchor, constant: 12),
            searchContainer.trailingAnchor.constraint(
                equalTo: backgroundContainer.trailingAnchor, constant: -12),
            searchContainer.heightAnchor.constraint(equalToConstant: 28),

            searchField.leadingAnchor.constraint(
                equalTo: searchContainer.leadingAnchor, constant: 10),
            searchField.trailingAnchor.constraint(
                equalTo: searchContainer.trailingAnchor, constant: -10),
            searchField.centerYAnchor.constraint(equalTo: searchContainer.centerYAnchor),

            scrollView.topAnchor.constraint(
                equalTo: searchContainer.bottomAnchor, constant: 4),
            scrollView.leadingAnchor.constraint(
                equalTo: backgroundContainer.leadingAnchor,
                constant: LayoutMetrics.popupHorizontalInset),
            scrollView.trailingAnchor.constraint(
                equalTo: backgroundContainer.trailingAnchor,
                constant: -LayoutMetrics.popupHorizontalInset),
            scrollView.bottomAnchor.constraint(
                equalTo: backgroundContainer.bottomAnchor,
                constant: -LayoutMetrics.popupVerticalInset),

            editorContainer.topAnchor.constraint(
                equalTo: backgroundContainer.topAnchor, constant: LayoutMetrics.popupVerticalInset),
            editorContainer.leadingAnchor.constraint(
                equalTo: backgroundContainer.leadingAnchor,
                constant: LayoutMetrics.popupHorizontalInset),
            editorContainer.trailingAnchor.constraint(
                equalTo: backgroundContainer.trailingAnchor,
                constant: -LayoutMetrics.popupHorizontalInset),
            editorContainer.bottomAnchor.constraint(
                equalTo: backgroundContainer.bottomAnchor,
                constant: -LayoutMetrics.popupVerticalInset),

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

        strokesLayer.strokeColor =
            isUsingGlassEffect
            ? NSColor.clear.cgColor : NSColor.white.withAlphaComponent(0.12).cgColor
        backgroundTintView.layer?.backgroundColor = tintColor.cgColor
        connectorLineView.layer?.cornerRadius = LayoutMetrics.connectorLineWidth / 2
        connectorLineView.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.45).cgColor

        let mainTextColor = NSColor(hex: config?.mainForegroundColor ?? "") ?? .labelColor
        searchField.textColor = mainTextColor

        let secondaryColor =
            NSColor(hex: config?.mainForegroundColor ?? "")?.withAlphaComponent(0.5)
            ?? .secondaryLabelColor
        searchField.placeholderColor = secondaryColor

        searchContainer.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.06).cgColor
        searchContainer.layer?.borderColor = NSColor.white.withAlphaComponent(0.08).cgColor
        searchContainer.layer?.borderWidth = 0.5
    }

    func applyInlineMode() {
        guard isInlineMode else { return }
        backgroundLeadingConstraint?.constant = 0
        connectorLineView.isHidden = true
    }

    private func updateShapeMask() {
        let bounds = backgroundContainer.bounds
        guard bounds.width > 0, bounds.height > 0 else { return }

        let path = CGPath(
            roundedRect: bounds,
            cornerWidth: LayoutMetrics.cornerRadius,
            cornerHeight: LayoutMetrics.cornerRadius,
            transform: nil
        )

        let maskLayer = CAShapeLayer()
        maskLayer.path = path
        backgroundContainer.layer?.mask = maskLayer

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

        window.makeFirstResponder(searchField)
    }

    private func updatePreferredContentSize() {
        let width: CGFloat = 260 + (isInlineMode ? 0 : LayoutMetrics.connectorGapWidth)

        if editingOperation != nil {
            preferredContentSize = NSSize(width: width, height: 140)
            return
        }

        let visibleRows = CGFloat(min(max(operations.count, 1), 6))
        let height = 50 + visibleRows * LayoutMetrics.rowHeight
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
                returnToContextList()
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
            if operation.kind == .toggleEnabled {
                commitToggleEnabled()
            } else if operation.kind == .toggleHidden {
                commitToggleHidden()
            }
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

    private func commitToggleHidden() {
        guard let context, selectedIndex >= 0, selectedIndex < operations.count else { return }
        let operation = operations[selectedIndex].operation
        guard operation.kind == .toggleHidden else { return }

        let hasHotkey = !NerwActionPreferenceManager.shared.hotkey(for: context.actionID).isEmpty
        let currentlyHidden = NerwActionPreferenceManager.shared.isActionHidden(
            for: context.actionID)

        if !currentlyHidden && !hasHotkey {
            NerwNotificationManager.shared.show(
                content: "Cannot hide action without a hotkey",
                level: .info
            )
            return
        }

        let nextHidden = !currentlyHidden
        NerwActionPreferenceManager.shared.updateActionHidden(nextHidden, for: context.actionID)

        // Show feedback
        let status = nextHidden ? "hidden" : "unhidden"
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
        searchContainer.isHidden = true
        editorContainer.isHidden = false
        editorTitleLabel.stringValue = "Set Alias"
        editorHintLabel.stringValue = "Separate multiple aliases with spaces. Press Enter to save."

        clearEditorInputHost()
        aliasField.placeholderString = placeholder
        aliasField.stringValue = value
        editorInputHost.addSubview(aliasField)
        NSLayoutConstraint.activate([
            aliasField.leadingAnchor.constraint(
                equalTo: editorInputHost.leadingAnchor, constant: 12),
            aliasField.trailingAnchor.constraint(
                equalTo: editorInputHost.trailingAnchor, constant: -12),
            aliasField.centerYAnchor.constraint(equalTo: editorInputHost.centerYAnchor),
        ])

        hotkeyRecorder = nil
        updatePreferredContentSize()
        focusCurrentMode()
    }

    private func showHotkeyEditor(operation: NerwActionContext.Operation, value: String) {
        editingOperation = operation
        scrollView.isHidden = true
        searchContainer.isHidden = true
        editorContainer.isHidden = false
        editorTitleLabel.stringValue = "Set Hotkey"
        editorHintLabel.stringValue =
            "Press key combo to record. Esc to cancel. Backspace to remove."

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
        returnToContextList()
    }

    private func returnToContextList() {
        guard let context else { return }
        editingOperation = nil
        editorContainer.isHidden = true
        scrollView.isHidden = false
        searchContainer.isHidden = false
        updatePreferredContentSize()
        focusCurrentMode()
        delegate?.actionContext(self, didUpdatePreferencesFor: context.actionID)
    }

    private func menuDetailText(
        for operation: NerwActionContext.Operation,
        in context: NerwActionContext
    ) -> String? {
        if let detailText = operation.detailText, !detailText.isEmpty {
            return detailText
        }

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
        case .toggleEnabled, .toggleHidden, .custom:
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

        if keybind.isEmpty
            && NerwActionPreferenceManager.shared.isActionHidden(for: context.actionID)
        {
            NerwActionPreferenceManager.shared.updateActionHidden(false, for: context.actionID)
            SearchService.shared.loadCache(asyncUpdate: true)
        }

        returnToContextList()
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector)
        -> Bool
    {
        if control === aliasField {
            switch commandSelector {
            case #selector(NSResponder.insertNewline(_:)),
                #selector(NSResponder.insertNewlineIgnoringFieldEditor(_:)),
                #selector(NSResponder.insertLineBreak(_:)):
                commitAliasEdit()
                return true
            case #selector(NSResponder.cancelOperation(_:)):
                returnToContextList()
                return true
            default:
                return false
            }
        }

        if control === searchField {
            if let event = NSApp.currentEvent, event.modifierFlags.contains(.control) {
                let chars = event.charactersIgnoringModifiers?.lowercased()
                let navStyle = ConfigManager.shared.config.navigationStyle

                if navStyle == "vim" {
                    if chars == "j" {
                        moveSelection(by: 1)
                        return true
                    } else if chars == "k" {
                        moveSelection(by: -1)
                        return true
                    } else if chars == "n" || chars == "p" {
                        return true
                    }
                } else {  // unix
                    if chars == "n" {
                        moveSelection(by: 1)
                        return true
                    } else if chars == "p" {
                        moveSelection(by: -1)
                        return true
                    } else if chars == "j" || chars == "k" {
                        return true
                    }
                }
            }

            switch commandSelector {
            case #selector(NSResponder.moveUp(_:)):
                moveSelection(by: -1)
                return true
            case #selector(NSResponder.moveDown(_:)):
                moveSelection(by: 1)
                return true
            case #selector(NSResponder.insertNewline(_:)),
                #selector(NSResponder.insertNewlineIgnoringFieldEditor(_:)),
                #selector(NSResponder.insertLineBreak(_:)):
                activateSelectedOperation()
                return true
            case #selector(NSResponder.cancelOperation(_:)):
                delegate?.actionContextDidRequestClose(self)
                return true
            default:
                return false
            }
        }

        return false
    }

    private func filterOperations(for query: String) {
        if query.isEmpty {
            operations = allOperations
        } else {
            let searchStrings = allOperations.map { entry in
                let parts =
                    [entry.operation.title, entry.sectionTitle, entry.detailText ?? ""]
                    + entry.searchKeywords
                return parts.joined(separator: " ")
            }
            let fuse = Fuse()
            let results = fuse.searchSync(query, in: searchStrings)
            let sortedResults = results.sorted { $0.score < $1.score }
            let validResults = sortedResults.filter {
                $0.score < 0.6 && $0.index < allOperations.count
            }
            operations = validResults.map { allOperations[$0.index] }
        }

        selectedIndex = operations.isEmpty ? -1 : 0
        syncSelection()
        updatePreferredContentSize()
        updateConnectorLineHeight()
    }

    func controlTextDidChange(_ obj: Notification) {
        guard let textField = obj.object as? NSTextField else { return }
        if textField === searchField {
            filterOperations(for: textField.stringValue)
        }
    }

    func controlTextDidBeginEditing(_ obj: Notification) {
        guard let textField = obj.object as? NSTextField else { return }
        if textField === searchField {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.15
                searchContainer.layer?.borderColor = NSColor.white.withAlphaComponent(0.2).cgColor
            }
        }
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        guard let textField = obj.object as? NSTextField else { return }
        if textField === searchField {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.15
                searchContainer.layer?.borderColor = NSColor.white.withAlphaComponent(0.08).cgColor
            }
        }
    }
}
