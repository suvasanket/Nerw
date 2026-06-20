// MainPanelContentViewController.swift
import Cocoa
import NerwAction
import NerwBuiltin
import NerwCore
import NerwSearchBackend
import NerwUtils

protocol MainPanelContentDelegate: AnyObject {
    func didPressEscape()
    func didSubmit(text: String)
    func didUpdateResults(count: Int, resultsHeight: CGFloat, isSeparatorExpanded: Bool)
    func requestsResize(to height: CGFloat)
}

enum MainPanelTextSelection {
    static func collapsedRange(for text: String) -> NSRange {
        NSRange(location: text.utf16.count, length: 0)
    }
}

class MainPanelContentViewController: NSViewController, NSTextFieldDelegate, NSTableViewDataSource,
    NSTableViewDelegate
{
    // MARK: - Layout Configuration
    struct LayoutMetrics {
        struct Window {
            static var width: CGFloat { GlobalLayout.mainWidth }
            static var cornerRadius: CGFloat { GlobalLayout.cornerRadius }
            static let heightBuffer: CGFloat = 10
        }

        struct SearchField {
            static let height: CGFloat = 32
            static var fontSize: CGFloat { GlobalLayout.fontSizeSearch }
            static let top: CGFloat = 12  // Margin from window top
            static let bottom: CGFloat = 12  // Margin from window bottom (in shrink view)
            static let leading: CGFloat = 12  // Margin from icon container
            /// Margin from window trailing edge
            static var trailing: CGFloat { GlobalLayout.horizontalMargin }
        }

        struct IconContainer {
            static let height: CGFloat = 40
            static var iconSize: CGFloat { GlobalLayout.iconSizeMain }
            static let spacing: CGFloat = 12
            /// Margin from window leading edge
            static var leading: CGFloat { GlobalLayout.horizontalMargin }
        }

        struct Separator {
            static let height: CGFloat = 1  // Default/Collapsed height
            static let expandedHeight: CGFloat = 14  // Height when icons are present
            static let lineHeight: CGFloat = 1  // Actual separator line height
            static let top: CGFloat = 2  // Reduced margin to keep visuals tight
            static let bottom: CGFloat = 0  // Margin to Results top
            static var leading: CGFloat { GlobalLayout.horizontalMargin }
            static var trailing: CGFloat { GlobalLayout.horizontalMargin }
        }

        struct Results {
            static let rowHeight: CGFloat = 50
            static var maxVisibleRows: Int {
                let overhead =
                    SearchField.top + SearchField.height + Separator.top + Separator.expandedHeight
                    + Separator.bottom + Results.expandedBottom + Window.heightBuffer
                let available = GlobalLayout.mainHeight - overhead
                return max(1, Int(floor(available / rowHeight)))
            }
            static let bottom: CGFloat = 0  // Default margin
            static let expandedBottom: CGFloat = 16  // Margin when expanded
        }

        struct Cell {
            static var cornerRadius: CGFloat { GlobalLayout.cornerRadius / 2 }  // Responsive to global corner radius

            struct Margin {
                static let vertical: CGFloat = 3
                static let horizontal: CGFloat = 0
            }

            struct Icon {
                static let size: CGFloat = 28
                static let leading: CGFloat = 10
                static let trailing: CGFloat = 6  // Spacing to text
            }

            struct Text {
                static let titleTop: CGFloat = 6
                static let subtitleTop: CGFloat = 1
                static var titleSize: CGFloat { GlobalLayout.fontSizeResultTitle }
                static var subtitleSize: CGFloat { GlobalLayout.fontSizeResultSubtitle }
            }
        }
    }

    weak var delegate: MainPanelContentDelegate?

    private var iconContainer: NSStackView!
    private var defaultSearchIcon: NSImageView!
    private(set) var inputField: ThemedTextField!
    private var resultsTableView: NSTableView!
    private var scrollView: NSScrollView!
    private var separatorView: NSBox!
    private var accessoryStackView: NSStackView!
    private var accessoryStackViewHeightConstraint: NSLayoutConstraint!
    private var statusIconContainer: NSStackView!
    private var panelView: NerwPanelView!
    private var scrollViewBottomConstraint: NSLayoutConstraint!

    private var iconContainerLeadingConstraint: NSLayoutConstraint!
    private var iconContainerWidthConstraints: [NSLayoutConstraint] = []
    private var iconContainerHeightConstraints: [NSLayoutConstraint] = []
    private var inputFieldLeadingConstraint: NSLayoutConstraint!
    private var inputFieldTrailingConstraint: NSLayoutConstraint!
    private var accessoryStackViewLeadingConstraint: NSLayoutConstraint!
    private var accessoryStackViewTrailingConstraint: NSLayoutConstraint!
    private var formView: FormView?
    private var actionContextWindow: ActionContextPanel?
    private var actionContextOverlay: ActionContextOverlayView?
    private var actionContextViewController: ActionContextViewController?
    private let floatingContextButton = ContextHoverButton()

    private var isDebugMode = false

    private var actions: [NerwAction] = []
    private var cachedFallbacks: [NerwAction] = []
    private var preModifierActions: [NerwAction]? = nil
    private var activeAction: NerwAction?
    private var previousSearchText: String = ""
    private var selectedIndex: Int = 0
    private var userHasNavigated: Bool = false
    private var currentExecutionId: UUID?

    // State Machine for Input
    enum InputState {
        case search
        case argument(action: NerwAction, step: Int, collectedArgs: [String])
        case form(action: NerwAction)
        case executing(action: NerwAction)
    }
    private var inputState: InputState = .search {
        didSet {
            updateUIForCurrentState()
        }
    }

    private func updateUIForCurrentState() {
        print("[DebugUI] State changed to: \(inputState)")

        // 1. Reset standard visibility (States can override)
        inputField.isHidden = false
        iconContainer.isHidden = false
        separatorView.isHidden = false
        inputField.isEditable = true
        inputField.isSelectable = true
        resultsTableView.alphaValue = 1.0
        scrollView.isHidden = actions.isEmpty

        // Remove spinner and restore icons if not executing
        if case .executing = inputState {
            // Handled below
        } else {
            for view in iconContainer.arrangedSubviews {
                if view is NSProgressIndicator {
                    view.removeFromSuperview()
                } else if view is NSImageView {
                    view.isHidden = false
                }
            }
        }

        switch inputState {
        case .search:
            if let action = activeAction {
                // Hybrid Swap Case: behaves like search but locked to action
                inputField.placeholderString = action.title
                updateIcon(for: action)
            } else {
                inputField.placeholderString = "Nerw"
                // updateSelectionIcon will be called via updateActions or manually
                updateSelectionIcon()
            }

        case .argument(let action, let step, _):
            // Update Placeholder based on argument name
            var placeholder = action.title
            switch action.type {
            case .arg(let placeholders, _):
                if step < placeholders.count { placeholder = placeholders[step] }
            case .args(let ph, _, _):
                placeholder = ph
            default: break
            }
            inputField.placeholderString = placeholder
            updateIcon(for: action)

        case .form:
            inputField.isHidden = true
            iconContainer.isHidden = true
            separatorView.isHidden = true
            scrollView.isHidden = true
            accessoryStackView.isHidden = true

        case .executing(let action):
            inputField.placeholderString = action.title
            inputField.isEditable = false
            inputField.isSelectable = false
            resultsTableView.alphaValue = 0.5

            // Hide existing icons instead of removing them
            for subview in iconContainer.arrangedSubviews {
                if subview is NSImageView {
                    subview.isHidden = true
                }
            }

            // Set spinner icon
            if !iconContainer.arrangedSubviews.contains(where: { $0 is NSProgressIndicator }) {
                let spinner = NSProgressIndicator()
                spinner.style = .spinning
                spinner.controlSize = .small
                spinner.translatesAutoresizingMaskIntoConstraints = false
                spinner.startAnimation(nil)

                // Maintain layout dimensions for the spinner
                let spinnerWidth = spinner.widthAnchor.constraint(equalToConstant: 16)
                spinnerWidth.isActive = true
                let spinnerHeight = spinner.heightAnchor.constraint(equalToConstant: 16)
                spinnerHeight.isActive = true

                iconContainer.addArrangedSubview(spinner)
            } else if let spinner = iconContainer.arrangedSubviews.first(where: {
                $0 is NSProgressIndicator
            }) as? NSProgressIndicator {
                spinner.isHidden = false
                spinner.startAnimation(nil)
            }
        }
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        // Refresh Shortcuts if enabled
        if ConfigManager.shared.config.showShortcutsInMain {
            ShortcutsEngine.shared.refresh()
        }
        SearchService.shared.loadCache()
    }

    override func loadView() {
        // Initial height calculation for shrink view
        let initialHeight =
            LayoutMetrics.SearchField.top + LayoutMetrics.SearchField.height
            + LayoutMetrics.SearchField.bottom
        view = NSView(
            frame: NSRect(
                x: 0, y: 0, width: LayoutMetrics.Window.width, height: initialHeight))
        view.wantsLayer = true
        setupViews()
    }

    private func setupViews() {
        // NerwPanelView
        panelView = NerwPanelView(style: .main)
        panelView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(panelView)

        let backgroundView = panelView.contentView

        // Icon Container
        iconContainer = NSStackView()
        iconContainer.orientation = .horizontal
        iconContainer.spacing = LayoutMetrics.IconContainer.spacing
        iconContainer.alignment = .centerY
        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.addSubview(iconContainer)

        // Default Search Icon
        defaultSearchIcon = NSImageView()
        defaultSearchIcon.image = NSImage(
            systemSymbolName: "magnifyingglass", accessibilityDescription: nil)
        defaultSearchIcon.contentTintColor = .secondaryLabelColor
        defaultSearchIcon.translatesAutoresizingMaskIntoConstraints = false
        let iconWidth = defaultSearchIcon.widthAnchor.constraint(
            equalToConstant: LayoutMetrics.IconContainer.iconSize
        )
        iconWidth.isActive = true
        let iconHeight = defaultSearchIcon.heightAnchor.constraint(
            equalToConstant: LayoutMetrics.IconContainer.iconSize
        )
        iconHeight.isActive = true

        iconContainerWidthConstraints.append(iconWidth)
        iconContainerHeightConstraints.append(iconHeight)

        defaultSearchIcon.imageScaling = .scaleProportionallyUpOrDown
        iconContainer.addArrangedSubview(defaultSearchIcon)

        // Input field
        inputField = ThemedTextField()
        inputField.font = .systemFont(ofSize: LayoutMetrics.SearchField.fontSize, weight: .light)
        inputField.placeholderString = "Nerw"
        inputField.isBordered = false
        inputField.drawsBackground = false
        inputField.focusRingType = .none
        inputField.textColor = .labelColor
        inputField.delegate = self
        inputField.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.addSubview(inputField)

        // Accessory Stack (Separator + Status Icons)
        accessoryStackView = NSStackView()
        accessoryStackView.orientation = .horizontal
        accessoryStackView.spacing = 8
        accessoryStackView.alignment = .centerY
        accessoryStackView.translatesAutoresizingMaskIntoConstraints = false
        accessoryStackView.isHidden = true
        backgroundView.addSubview(accessoryStackView)

        // Separator
        separatorView = NSBox()
        separatorView.boxType = .separator
        separatorView.translatesAutoresizingMaskIntoConstraints = false
        accessoryStackView.addArrangedSubview(separatorView)

        // Ensure separator fills available space
        separatorView.setContentHuggingPriority(.defaultLow, for: .horizontal)

        // Status Icon Container
        statusIconContainer = NSStackView()
        statusIconContainer.orientation = .horizontal
        statusIconContainer.spacing = 6
        statusIconContainer.alignment = .centerY
        statusIconContainer.translatesAutoresizingMaskIntoConstraints = false
        statusIconContainer.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        accessoryStackView.addArrangedSubview(statusIconContainer)

        // Results table
        resultsTableView = NSTableView()
        resultsTableView.backgroundColor = .clear
        resultsTableView.headerView = nil
        resultsTableView.rowHeight = LayoutMetrics.Results.rowHeight
        resultsTableView.intercellSpacing = NSSize(width: 0, height: 0)
        resultsTableView.selectionHighlightStyle = .none
        resultsTableView.dataSource = self
        resultsTableView.delegate = self

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("result"))
        let columnWidth =
            LayoutMetrics.Window.width
            - (LayoutMetrics.Separator.leading + LayoutMetrics.Separator.trailing)
        column.width = columnWidth
        column.resizingMask = .autoresizingMask
        resultsTableView.addTableColumn(column)
        resultsTableView.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        resultsTableView.sizeLastColumnToFit()

        scrollView = NSScrollView()
        scrollView.documentView = resultsTableView
        scrollView.hasVerticalScroller = false
        scrollView.drawsBackground = false
        scrollView.isHidden = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.automaticallyAdjustsContentInsets = false
        backgroundView.addSubview(scrollView)

        // Constraints
        iconContainerLeadingConstraint = iconContainer.leadingAnchor.constraint(
            equalTo: backgroundView.leadingAnchor, constant: LayoutMetrics.IconContainer.leading
        )
        inputFieldLeadingConstraint = inputField.leadingAnchor.constraint(
            equalTo: iconContainer.trailingAnchor, constant: LayoutMetrics.SearchField.leading)
        inputFieldTrailingConstraint = inputField.trailingAnchor.constraint(
            equalTo: backgroundView.trailingAnchor, constant: -LayoutMetrics.SearchField.trailing)
        inputFieldLeadingConstraint.isActive = true
        inputFieldTrailingConstraint.isActive = true

        scrollView.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            self, selector: #selector(scrollViewDidScroll),
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView)
        accessoryStackViewLeadingConstraint = accessoryStackView.leadingAnchor.constraint(
            equalTo: backgroundView.leadingAnchor,
            constant: LayoutMetrics.Separator.leading)
        accessoryStackViewTrailingConstraint = accessoryStackView.trailingAnchor.constraint(
            equalTo: backgroundView.trailingAnchor,
            constant: -LayoutMetrics.Separator.trailing)

        NSLayoutConstraint.activate([
            panelView.topAnchor.constraint(equalTo: view.topAnchor),
            panelView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            panelView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            panelView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            iconContainerLeadingConstraint,
            iconContainer.centerYAnchor.constraint(
                equalTo: inputField.centerYAnchor, constant: 1.0),
            iconContainer.heightAnchor.constraint(
                equalToConstant: LayoutMetrics.IconContainer.height),

            inputField.topAnchor.constraint(
                equalTo: backgroundView.topAnchor, constant: LayoutMetrics.SearchField.top),
            inputFieldLeadingConstraint,
            inputFieldTrailingConstraint,
            inputField.heightAnchor.constraint(equalToConstant: LayoutMetrics.SearchField.height),

            accessoryStackView.topAnchor.constraint(
                equalTo: inputField.bottomAnchor, constant: LayoutMetrics.Separator.top),
            accessoryStackViewLeadingConstraint,
            accessoryStackViewTrailingConstraint,

            // Constrain separator height explicitly to the line height
            separatorView.heightAnchor.constraint(
                equalToConstant: LayoutMetrics.Separator.lineHeight),
            separatorView.widthAnchor.constraint(greaterThanOrEqualToConstant: 10),  // Min width

            scrollView.topAnchor.constraint(
                equalTo: accessoryStackView.bottomAnchor, constant: LayoutMetrics.Separator.bottom),
            scrollView.leadingAnchor.constraint(equalTo: backgroundView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: backgroundView.trailingAnchor),
        ])

        accessoryStackViewHeightConstraint = accessoryStackView.heightAnchor.constraint(
            equalToConstant: LayoutMetrics.Separator.height)
        accessoryStackViewHeightConstraint.isActive = true

        scrollViewBottomConstraint = scrollView.bottomAnchor.constraint(
            equalTo: backgroundView.bottomAnchor, constant: -LayoutMetrics.Results.bottom
        )
        scrollViewBottomConstraint.isActive = true

        applyTheming()

        // Floating Context Button (Add last so it's on top of scrollView)
        floatingContextButton.imageView.image = ResultCellView.makeVerticalEllipsisImage()
        floatingContextButton.isHidden = true
        floatingContextButton.onTapped = { [weak self] in
            self?.toggleActionContext()
        }
        backgroundView.addSubview(floatingContextButton)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(
            self, selector: #selector(configDidUpdate),
            name: Notification.Name("NerwConfigDidUpdate"), object: nil)

        // Monitor modifier flags to update UI (alternate titles/subtitles) and swap fallback results
        NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            guard let self = self else { return event }

            if case .search = self.inputState {
                let modConfig = ConfigManager.shared.config.fallbackModifier
                let isHoldingFallbackMod: Bool
                switch modConfig {
                case "cmd": isHoldingFallbackMod = event.modifierFlags.contains(.command)
                case "opt": isHoldingFallbackMod = event.modifierFlags.contains(.option)
                case "ctrl": isHoldingFallbackMod = event.modifierFlags.contains(.control)
                case "shift": isHoldingFallbackMod = event.modifierFlags.contains(.shift)
                default: isHoldingFallbackMod = event.modifierFlags.contains(.command)
                }

                let isInFallbackMode = self.preModifierActions != nil

                if isHoldingFallbackMod && !isInFallbackMode && !self.cachedFallbacks.isEmpty {
                    // Enter fallback mode
                    self.preModifierActions = self.actions
                    self.actions = self.cachedFallbacks
                    self.selectedIndex = 0
                    self.userHasNavigated = false
                    self.updateActions()
                } else if !isHoldingFallbackMod && isInFallbackMode {
                    // Exit fallback mode
                    self.actions = self.preModifierActions ?? []
                    self.preModifierActions = nil
                    self.selectedIndex = 0
                    self.userHasNavigated = false
                    self.updateActions()
                }
            }

            if !self.actions.isEmpty {
                let row = self.selectedIndex
                if row >= 0 && row < self.actions.count {
                    self.resultsTableView.reloadData(
                        forRowIndexes: IndexSet(integer: row), columnIndexes: IndexSet(integer: 0))
                }
            }
            return event
        }
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        updateFloatingContextButton()
    }

    @objc private func configDidUpdate() {
        DispatchQueue.main.async {
            self.applyLayout()
            self.applyTheming()
            self.resultsTableView.reloadData()
            self.refreshActionContextIfNeeded()
        }
    }

    private func applyLayout() {
        // Update Frame (Width)
        view.frame.size.width = LayoutMetrics.Window.width
        // Notify delegate if window needs update
        delegate?.requestsResize(to: view.frame.height)

        // Update Constraints
        iconContainerLeadingConstraint.constant = LayoutMetrics.IconContainer.leading
        inputFieldTrailingConstraint.constant = -LayoutMetrics.SearchField.trailing
        accessoryStackViewLeadingConstraint.constant = LayoutMetrics.Separator.leading
        accessoryStackViewTrailingConstraint.constant = -LayoutMetrics.Separator.trailing

        for constraint in iconContainerWidthConstraints {
            constraint.constant = LayoutMetrics.IconContainer.iconSize
        }
        for constraint in iconContainerHeightConstraints {
            constraint.constant = LayoutMetrics.IconContainer.iconSize
        }

        // Table View Column Width
        if let column = resultsTableView.tableColumns.first {
            column.width =
                LayoutMetrics.Window.width
                - (LayoutMetrics.Separator.leading + LayoutMetrics.Separator.trailing)
        }

        view.layoutSubtreeIfNeeded()
        updateFloatingContextButton()
    }

    private func applyTheming() {
        let config = ConfigManager.shared.config.uiConfig

        // Font & Text Color
        let fontSize = LayoutMetrics.SearchField.fontSize
        if let fontName = config?.font, let font = NSFont(name: fontName, size: fontSize) {
            inputField.font = font
        }

        if let fgHex = config?.mainForegroundColor, let fgColor = NSColor(hex: fgHex) {
            inputField.textColor = fgColor
            defaultSearchIcon.contentTintColor = fgColor
        } else {
            // Restore default if no override
            defaultSearchIcon.contentTintColor = .secondaryLabelColor
        }

        // Placeholder Color - Match it exactly to the icon tint by default
        let iconColor = defaultSearchIcon.contentTintColor ?? .secondaryLabelColor

        if let hintHex = config?.hintColor, let hintColor = NSColor(hex: hintHex) {
            inputField.placeholderColor = hintColor
        } else {
            inputField.placeholderColor = iconColor
        }
    }

    func toggleDebugMode() {
        isDebugMode.toggle()

        let views: [NSView?] = [
            panelView, iconContainer, inputField, separatorView, scrollView,
        ]

        for view in views.compactMap({ $0 }) {
            view.wantsLayer = true
            if isDebugMode {
                view.layer?.borderColor = NSColor.red.cgColor
                view.layer?.borderWidth = 1.0
            } else {
                view.layer?.borderWidth = 0.0
            }
        }
    }

    private static var symbolIconCache: [String: NSImage] = [:]
    private static func getSymbolImage(for name: String) -> NSImage {
        if let cached = symbolIconCache[name] { return cached }
        let image = NSImage(systemSymbolName: name, accessibilityDescription: nil) ?? NSImage()
        symbolIconCache[name] = image
        return image
    }

    func setIcons(_ icons: [NSImage]) {
        // Remove progress indicator just in case
        for view in iconContainer.arrangedSubviews {
            if view is NSProgressIndicator {
                view.removeFromSuperview()
            }
        }

        let displayIcons =
            icons.isEmpty
            ? [MainPanelContentViewController.getSymbolImage(for: "magnifyingglass")] : icons
        let existingViews = iconContainer.arrangedSubviews.compactMap { $0 as? NSImageView }

        // Remove excess views
        if existingViews.count > displayIcons.count {
            for i in displayIcons.count..<existingViews.count {
                let viewToRemove = existingViews[i]
                viewToRemove.removeFromSuperview()
                iconContainerWidthConstraints.removeAll { $0.firstItem === viewToRemove }
                iconContainerHeightConstraints.removeAll { $0.firstItem === viewToRemove }
            }
        }

        // Update or add views
        for (index, image) in displayIcons.enumerated() {
            let iv: NSImageView
            if index < existingViews.count {
                iv = existingViews[index]
                iv.isHidden = false
            } else {
                iv = NSImageView()
                iv.contentTintColor = .secondaryLabelColor
                if #available(macOS 12.0, *) {
                    iv.symbolConfiguration = NSImage.SymbolConfiguration(
                        hierarchicalColor: .secondaryLabelColor)
                }
                iv.translatesAutoresizingMaskIntoConstraints = false
                iv.imageScaling = .scaleProportionallyUpOrDown
                iconContainer.addArrangedSubview(iv)

                let width = iv.widthAnchor.constraint(
                    equalToConstant: LayoutMetrics.IconContainer.iconSize)
                width.isActive = true
                let height = iv.heightAnchor.constraint(
                    equalToConstant: LayoutMetrics.IconContainer.iconSize)
                height.isActive = true

                iconContainerWidthConstraints.append(width)
                iconContainerHeightConstraints.append(height)
            }

            let changed: Bool
            if let current = iv.image {
                if current === image {
                    changed = false
                } else {
                    changed = true
                }
            } else {
                changed = true
            }

            if changed {
                if #available(macOS 14.0, *) {
                    iv.setSymbolImage(image, contentTransition: .replace)
                } else {
                    iv.image = image
                }
            }
        }
    }

    @objc private func scrollViewDidScroll(_ notification: Notification) {
        updateFloatingContextButton()
        refreshActionContextIfNeeded()
    }

    public func focusSearch() {
        print("[DebugUI] resetToSearch called")
        dismissActionContext()
        activeAction = nil
        inputState = .search

        // Clear text (User Requirement: Do not recomplete previous string)
        inputField.stringValue = ""
        previousSearchText = ""

        // Trigger search to restore default results
        search(query: "")
    }

    func reset(restoreFocus: Bool = true) {
        dismissActionContext(animated: false)
        activeAction = nil
        inputState = .search
        inputField.stringValue = ""
        actions = []
        previousSearchText = ""
        selectedIndex = 0
        userHasNavigated = false
        currentExecutionId = nil

        // Form Cleanup
        formView?.removeFromSuperview()
        formView = nil

        updateActions()
        search(query: "")
    }

    func openAction(_ action: NerwAction) {
        // Reset state first to ensure clean transition
        reset()

        switch action.type {
        case .form:
            enterFormMode(action: action)
        case .arg, .args:
            enterArgumentMode(action: action, step: 0, collectedArgs: [])
        case .instant(let perform), .hybrid(let perform, _):
            perform(action)
        case .inlineArg(let perform, _):
            if let trigger = action.triggers.first {
                inputField.stringValue = trigger + " "
                DispatchQueue.main.async { [weak self] in
                    self?.inputField.currentEditor()?.moveToEndOfLine(nil)
                }
                search(query: inputField.stringValue)
            } else {
                perform(action, "")
            }
        }
    }

    private func toggleActionContext() {
        if actionContextWindow?.isVisible == true {
            dismissActionContext()
            return
        }

        showActionContext()
    }

    private func showActionContext() {
        guard let action = currentContextAction() else { return }

        let context = NerwActionContextBuilder.build(for: action)

        let controller = actionContextViewController ?? ActionContextViewController()
        controller.delegate = self
        controller.isInlineMode = true
        controller.setConnectorSelectionHeight(0)
        controller.render(context: context)
        actionContextViewController = controller

        // Create the full-size overlay (captures clicks outside to dismiss)
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
            ctx.timingFunction = CAMediaTimingFunction(
                controlPoints: 0.34, 1.56, 0.64, 1.0)
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

        let anchorPoint = contextButtonAnchorPoint()
        guard let window = view.window else { return }

        let pointInWindow = panelView.contentView.convert(anchorPoint, to: nil)
        var screenPoint = window.convertPoint(toScreen: pointInWindow)

        // Position to the right of the 3 dots
        screenPoint.x += 8
        // Center vertically
        screenPoint.y -= contentSize.height / 2

        panel.setFrameOrigin(screenPoint)

        window.addChildWindow(panel, ordered: .above)
        panel.makeKeyAndOrderFront(nil)

        // Pop-in animation
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

            if let self = self, !self.inputField.isHidden {
                self.restoreInputFocusPreservingCaret()
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

    func restoreInputFocusPreservingCaret() {
        view.window?.makeKeyAndOrderFront(nil)
        view.window?.makeFirstResponder(inputField)
        collapseInputSelectionToEnd()

        DispatchQueue.main.async { [weak self] in
            self?.collapseInputSelectionToEnd()
        }
    }

    private func collapseInputSelectionToEnd() {
        guard let editor = inputField.currentEditor() else { return }
        editor.selectedRange = MainPanelTextSelection.collapsedRange(for: inputField.stringValue)
    }

    private func refreshActionContextIfNeeded() {
        guard let panel = actionContextWindow else { return }

        guard let action = currentContextAction() else {
            dismissActionContext(animated: false)
            return
        }

        let context = NerwActionContextBuilder.build(for: action)
        let controller = actionContextViewController
        controller?.render(context: context)

        if let controller = controller {
            controller.view.layoutSubtreeIfNeeded()
            let contentSize = controller.preferredContentSize

            let anchorPoint = contextButtonAnchorPoint()
            if let window = view.window {
                let pointInWindow = panelView.contentView.convert(anchorPoint, to: nil)
                var screenPoint = window.convertPoint(toScreen: pointInWindow)
                screenPoint.x += 8
                screenPoint.y -= contentSize.height / 2

                panel.setFrame(
                    NSRect(origin: screenPoint, size: contentSize), display: true, animate: false)
            }
        }
    }

    /// Returns the anchor point (in panelView.contentView coordinates) for positioning the context overlay.
    private func contextButtonAnchorPoint() -> NSPoint {
        if !actions.isEmpty, selectedIndex >= 0, selectedIndex < actions.count,
            !scrollView.isHidden
        {
            let rowRect = resultsTableView.rect(ofRow: selectedIndex)

            let rightMargin = LayoutMetrics.Separator.trailing
            // Anchor it exactly in the middle of the empty margin gap to the right of the cell highlight
            let anchorX = panelView.contentView.bounds.width - (rightMargin / 2.0)

            let centerY = rowRect.height / 2.0
            let buttonCenterInTable = NSPoint(x: 0, y: rowRect.minY + centerY)
            var pointInPanel = panelView.contentView.convert(
                buttonCenterInTable, from: resultsTableView)
            pointInPanel.x = anchorX
            return pointInPanel
        }

        // Fallback: right-center of the panel
        return NSPoint(
            x: panelView.contentView.bounds.maxX - 40,
            y: panelView.contentView.bounds.midY
        )
    }

    private func updateFloatingContextButton() {
        guard !actions.isEmpty, selectedIndex >= 0, selectedIndex < actions.count,
            !scrollView.isHidden
        else {
            print(
                "[DebugUI_Icon] Early return 1: isEmpty=\(actions.isEmpty), selectedIndex=\(selectedIndex), count=\(actions.count), hidden=\(scrollView.isHidden)"
            )
            floatingContextButton.isHidden = true
            return
        }

        let action = actions[selectedIndex]
        if action.peek != nil {
            print("[DebugUI_Icon] Early return 2: peek != nil")
            floatingContextButton.isHidden = true
            return
        }

        let rowRect = resultsTableView.rect(ofRow: selectedIndex)
        guard rowRect.width > 0, rowRect.height > 0 else {
            // Table view hasn't laid out the row yet. Retry asynchronously.
            DispatchQueue.main.async { [weak self] in
                self?.updateFloatingContextButton()
            }
            return
        }

        let visibleRect = scrollView.contentView.documentVisibleRect
        if visibleRect.height > 0, !visibleRect.intersects(rowRect) {
            print(
                "[DebugUI_Icon] Early return 3: outside visibleRect. rowRect=\(rowRect), visibleRect=\(visibleRect)"
            )
            floatingContextButton.isHidden = true
            return
        }

        let config = ConfigManager.shared.config.uiConfig
        let selectedTextColor = NSColor(hex: config?.selectionForegroundColor ?? "") ?? .white

        floatingContextButton.imageView.contentTintColor = selectedTextColor.withAlphaComponent(0.8)

        floatingContextButton.layer?.zPosition = 1000
        floatingContextButton.isHidden = false

        let anchorPoint = contextButtonAnchorPoint()
        let buttonWidth: CGFloat = 50.0  // Expanded width
        let buttonHeight: CGFloat = 52.0  // Expanded height

        let newFrame = NSRect(
            x: anchorPoint.x + 12.0 - buttonWidth,  // Right edge aligned with anchorPoint.x + 12.0
            y: anchorPoint.y + 12.0 - buttonHeight,  // Top edge aligned with anchorPoint.y + 12.0
            width: buttonWidth,
            height: buttonHeight
        )
        floatingContextButton.frame = newFrame

        Logger.shared.info(
            "[DebugUI_Icon] Frame: \(newFrame), Anchor: \(anchorPoint), RowRect: \(rowRect), VisibleRect: \(visibleRect)"
        )
    }

    private func currentContextAction() -> NerwAction? {
        if !actions.isEmpty, selectedIndex >= 0, selectedIndex < actions.count {
            return actions[selectedIndex]
        }
        return activeAction
    }

    private func actionForContext(id: String) -> NerwAction? {
        if let current = currentContextAction(), current.id == id {
            return current
        }
        if let activeAction, activeAction.id == id {
            return activeAction
        }
        return actions.first(where: { $0.id == id })
    }

    private func modifierFlags(for key: NerwAction.ModifierKey) -> NSEvent.ModifierFlags {
        switch key {
        case .command:
            return .command
        case .shift:
            return .shift
        case .control:
            return .control
        case .option:
            return .option
        }
    }

    private func autocompleteInlineTrigger(for action: NerwAction) {
        if let trigger = action.triggers.first {
            inputField.stringValue = trigger + " "
        } else if !inputField.stringValue.hasSuffix(" ") {
            inputField.stringValue += " "
        }
        inputField.currentEditor()?.moveToEndOfLine(nil)
    }

    @discardableResult
    private func performSecondaryAction(for action: NerwAction) -> Bool {
        guard case .hybrid(_, let box) = action.type else { return false }

        let quickAction = box.value
        previousSearchText = inputField.stringValue

        switch quickAction.type {
        case .arg, .args:
            activateArgumentMode(for: quickAction, initialArg: "")
        case .form:
            enterFormMode(action: quickAction)
        case .inlineArg:
            autocompleteInlineTrigger(for: quickAction)
        case .instant, .hybrid:
            FrecencyManager.shared.recordUsage(id: quickAction.id, forQuery: previousSearchText)
            activeAction = quickAction
            updateUIForCurrentState()
            inputField.stringValue = ""
            actions = []
            updateActions()
        }

        return true
    }

    private func performPrimaryAction(for action: NerwAction) -> Bool {
        if !actions.isEmpty, selectedIndex >= 0, selectedIndex < actions.count,
            actions[selectedIndex].id == action.id
        {
            return executeResult(action, query: inputField.stringValue, modifiers: [])
        }

        if case .argument(let currentAction, let step, var args) = inputState,
            currentAction.id == action.id
        {
            args.append(inputField.stringValue)
            return submitArgumentAction(action: currentAction, step: step, args: args)
        }

        if let activeAction, activeAction.id == action.id {
            return submitActiveAction(activeAction)
        }

        return executeResult(action, query: inputField.stringValue, modifiers: [])
    }

    private func submitArgumentAction(action: NerwAction, step: Int, args: [String]) -> Bool {
        var isLastStep = false
        switch action.type {
        case .arg(let placeholders, _):
            isLastStep = step >= placeholders.count - 1
        case .args:
            isLastStep = true
        default:
            break
        }

        if isLastStep {
            switch action.type {
            case .arg(_, let perform):
                perform(action, args)
            case .args(_, _, let perform):
                if let perform {
                    perform(action, args.joined(separator: " "))
                } else {
                    delegate?.didSubmit(text: "\(action.title) \(args.joined(separator: " "))")
                }
            default:
                break
            }
            closeSession(restoreText: false)
            return true
        }

        enterArgumentMode(action: action, step: step + 1, collectedArgs: args)
        return true
    }

    private func submitActiveAction(_ action: NerwAction) -> Bool {
        switch action.type {
        case .instant(let perform):
            dispatchActionExecution(action: action, query: inputField.stringValue) {
                perform(action)
            }
        case .inlineArg(let perform, _):
            dispatchActionExecution(action: action, query: inputField.stringValue) {
                perform(action, self.inputField.stringValue)
            }
        case .args(_, _, let perform):
            if let perform {
                dispatchActionExecution(action: action, query: inputField.stringValue) {
                    perform(action, self.inputField.stringValue)
                }
            } else {
                delegate?.didSubmit(text: "\(action.title) \(inputField.stringValue)")
                closeSession(restoreText: false)
            }
        default:
            delegate?.didSubmit(text: "\(action.title) \(inputField.stringValue)")
            closeSession(restoreText: false)
        }
        return true
    }

    // MARK: - Helpers
    private func closeSession(restoreText: Bool = true, restoreFocus: Bool = true) {
        currentExecutionId = nil
        dismissActionContext(animated: false)
        activeAction = nil
        inputState = .search

        if restoreText {
            inputField.stringValue = previousSearchText
        } else {
            inputField.stringValue = ""
        }

        // Form Cleanup
        formView?.removeFromSuperview()
        formView = nil

        // Drop strong references to all candidates and actions so ARC can immediately reclaim >100MB of icon data
        actions = []
        cachedFallbacks = []
        preModifierActions = nil
        resultsTableView.reloadData()

        SearchService.shared.clearCache()
        ResultCellView.clearIconCache()
        IconManager.shared.clearMemoryCache()
        delegate?.didPressEscape()
    }

    private func dispatchActionExecution(
        action: NerwAction, query: String?, performBlock: @escaping () -> Void
    ) {
        if let q = query, !q.isEmpty {
            FrecencyManager.shared.recordUsage(id: action.id, forQuery: q)
        }

        let executionId = UUID()
        self.currentExecutionId = executionId

        if action.isPersistent {
            self.inputState = .executing(action: action)
        } else {
            // Delay visual feedback for non-persistent actions by 50ms to prevent flicker
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                guard let self = self, self.currentExecutionId == executionId else { return }
                self.inputState = .executing(action: action)
            }
        }

        DispatchQueue.global(qos: .userInitiated).async {
            performBlock()

            DispatchQueue.main.async { [weak self] in
                guard let self = self, self.currentExecutionId == executionId else { return }
                if !action.isPersistent {
                    self.closeSession(restoreText: false)
                }
            }
        }
    }

    private func executeResult(
        _ result: NerwAction, query: String, modifiers: NSEvent.ModifierFlags = []
    ) -> Bool {
        // Check for modifiers first
        if !result.modifiers.isEmpty {
            let key: NerwAction.ModifierKey?
            if modifiers.contains(.command) {
                key = .command
            } else if modifiers.contains(.shift) {
                key = .shift
            } else if modifiers.contains(.control) {
                key = .control
            } else if modifiers.contains(.option) {
                key = .option
            } else {
                key = nil
            }

            if let key = key, let modAction = result.modifiers[key] {
                dispatchActionExecution(action: result, query: query) {
                    modAction.perform(result)
                }
                return true
            }
        }

        switch result.type {
        case .instant(let perform):
            dispatchActionExecution(action: result, query: query) {
                perform(result)
            }
            return true

        case .inlineArg:
            // Append space and let the user continue typing the argument
            if !inputField.stringValue.hasSuffix(" ") {
                inputField.stringValue += " "
                inputField.currentEditor()?.moveToEndOfLine(nil)
            }
            return true

        case .hybrid(let perform, _):
            dispatchActionExecution(action: result, query: query) {
                perform(result)
            }
            return true

        case .arg, .args:
            // Should have entered argument mode via Tab or Auto-trigger
            // But if user presses Enter on it, treat as entering argument mode
            previousSearchText = inputField.stringValue
            enterArgumentMode(action: result, step: 0, collectedArgs: [])
            return true

        case .form:
            previousSearchText = inputField.stringValue
            enterFormMode(action: result)
            return true
        }
    }

    private func updateSelectionIcon() {
        guard case .search = inputState else { return }

        if !actions.isEmpty, selectedIndex >= 0, selectedIndex < actions.count {
            let action = actions[selectedIndex]

            // UI Automation: Use Model-provided Icon
            if let iconName = action.modeIconName {
                let icon = MainPanelContentViewController.getSymbolImage(for: iconName)
                setIcons([icon])
                return
            }
        }
        setIcons([])
    }

    private func resetToSearch() {
        print("[DebugUI] resetToSearch called")
        dismissActionContext()
        activeAction = nil
        inputState = .search

        // Clear text (User Requirement: Do not recomplete previous string)
        inputField.stringValue = ""
        previousSearchText = ""

        // Trigger search to restore default results
        search(query: "")
    }

    private func handleTab() -> Bool {
        switch inputState {
        case .search:
            guard !actions.isEmpty else { return false }
            let selectedAction = actions[selectedIndex]

            switch selectedAction.type {
            case .form:
                previousSearchText = inputField.stringValue
                enterFormMode(action: selectedAction)
                return true

            case .arg, .args:
                previousSearchText = inputField.stringValue
                enterArgumentMode(action: selectedAction, step: 0, collectedArgs: [])
                return true

            case .inlineArg:
                // Universal completion for inline actions: replace field with "trigger "
                autocompleteInlineTrigger(for: selectedAction)
                return true

            case .hybrid:
                return performSecondaryAction(for: selectedAction)

            case .instant:
                return false
            }

        case .argument(let action, let step, var args):
            // 1. Priority: Check if user selected a nested action from suggestions
            if !actions.isEmpty, selectedIndex >= 0, selectedIndex < actions.count {
                let selectedAction = actions[selectedIndex]

                // Allow "drilling down" into the selected action
                switch selectedAction.type {
                case .form:
                    previousSearchText = inputField.stringValue
                    enterFormMode(action: selectedAction)
                    return true

                case .arg, .args:
                    previousSearchText = inputField.stringValue
                    enterArgumentMode(action: selectedAction, step: 0, collectedArgs: [])
                    return true

                case .inlineArg:
                    autocompleteInlineTrigger(for: selectedAction)
                    return true

                case .hybrid:
                    return performSecondaryAction(for: selectedAction)

                case .instant:
                    // Instant actions generally execute on Enter, not Tab.
                    // But if user tabs on an instant action, maybe we do nothing or autocomplete?
                    // Standard Spotlight behavior: Tab usually autocompletes text.
                    // For now, return false to fallback (or maybe update text?)
                    return false
                }
            }

            // 2. Fallback: Advance to next step of CURRENT action (if multi-step)
            // Only .arg supports multiple steps via array
            if case .arg(let placeholders, _) = action.type, step < placeholders.count - 1 {
                args.append(inputField.stringValue)
                enterArgumentMode(action: action, step: step + 1, collectedArgs: args)
                return true
            }
            return false

        case .form, .executing:
            return false  // Form handles its own tab navigation
        }
    }

    private func handleBacktab() -> Bool {
        if case .argument(let action, let step, var args) = inputState {
            if step > 0 {
                // Go back to previous step
                let prevVal = args.popLast() ?? ""
                inputField.stringValue = prevVal
                enterArgumentMode(action: action, step: step - 1, collectedArgs: args)
            } else {
                // Exit argument mode
                resetToSearch()
            }
            return true
        }
        return false
    }

    private func enterArgumentMode(action: NerwAction, step: Int, collectedArgs: [String]) {
        print("[DebugUI] Entering Argument Mode for action: \(action.title)")
        dismissActionContext()
        if step == 0 {
            FrecencyManager.shared.recordUsage(id: action.id, forQuery: previousSearchText)
        }

        // 1. Clear text first (Critical for visual transition)
        inputField.stringValue = ""

        // 2. Update State (didSet will handle UI)
        inputState = .argument(action: action, step: step, collectedArgs: collectedArgs)
        activeAction = action

        // 3. Clear list & trigger search
        actions = []
        updateActions()
        search(query: "")
    }

    private func updateIcon(for action: NerwAction) {
        if let icon = action.icon {
            switch icon {
            case .system(let name):
                setIcons([
                    MainPanelContentViewController.getSymbolImage(for: name)
                ])
            case .image(let img):
                setIcons([img])
            case .file(let url):
                setIcons([NSWorkspace.shared.icon(for: .data)])
                NerwUtils.IconUtils.getIconAsync(for: url, size: CGSize(width: 32, height: 32)) {
                    [weak self] image in
                    if let image = image { self?.setIcons([image]) }
                }
            case .none:
                setIcons([])
            }
        }
    }

    private func enterFormMode(action: NerwAction) {
        guard case .form(let fields, let submitLabel, _) = action.type else { return }

        dismissActionContext()
        inputState = .form(action: action)
        activeAction = action
        FrecencyManager.shared.recordUsage(id: action.id, forQuery: previousSearchText)

        // Setup Form View
        let form = FormView(fields: fields, submitLabel: submitLabel)
        form.delegate = self
        form.translatesAutoresizingMaskIntoConstraints = false
        panelView.contentView.addSubview(form)
        formView = form

        NSLayoutConstraint.activate([
            form.topAnchor.constraint(equalTo: panelView.contentView.topAnchor),
            form.leadingAnchor.constraint(equalTo: panelView.contentView.leadingAnchor),
            form.trailingAnchor.constraint(equalTo: panelView.contentView.trailingAnchor),
            form.bottomAnchor.constraint(equalTo: panelView.contentView.bottomAnchor),
        ])

        // Calculate required height based on fields
        form.layoutSubtreeIfNeeded()
        let fittingSize = form.fittingSize
        let newHeight = max(
            fittingSize.height,
            LayoutMetrics.SearchField.top + LayoutMetrics.SearchField.height
                + LayoutMetrics.SearchField.bottom)

        delegate?.requestsResize(to: newHeight)

        // Focus is handled by FormView inside viewDidMoveToWindow/setup
    }

    // MARK: - NSTextFieldDelegate

    func controlTextDidChange(_ obj: Notification) {
        var query = inputField.stringValue

        // [New Feature] Space to Trigger configured action (Alfred Style)
        let firstSpaceTrigger = ConfigManager.shared.config.onFirstSpace
        if !firstSpaceTrigger.isEmpty && query == " " {
            inputField.stringValue = firstSpaceTrigger
            inputField.currentEditor()?.moveToEndOfLine(nil)
            query = firstSpaceTrigger
        }

        // Unified Smart Trigger Logic (e.g., "eject <arg>", "find <arg>")
        let components = query.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: false)

        if components.count >= 2 {
            let possibleTrigger = String(components[0]).lowercased()
            let arg = String(components[1])

            // Search for an action that matches the trigger
            let candidates = SearchService.shared.getCandidates()
            if let result = candidates.first(where: {
                $0.triggers.contains(where: { $0.lowercased() == possibleTrigger })
            }) {
                // If the action supports arguments but IS NOT an inline action, enter argument mode.
                // Inline actions (like wiki, define) stay in search mode to show live results.
                if result.supportsArguments {
                    if case .inlineArg = result.type {
                        // Let it fall through to normal search.
                    } else {
                        previousSearchText = possibleTrigger
                        activateArgumentMode(for: result, initialArg: arg)
                        return
                    }
                }
            }
        }

        search(query: query)
    }

    private func activateArgumentMode(for action: NerwAction, initialArg: String) {
        // Switch to Argument Mode
        dismissActionContext()
        activeAction = action
        FrecencyManager.shared.recordUsage(id: action.id, forQuery: previousSearchText)

        inputField.stringValue = initialArg

        // Update State (didSet will handle UI)
        inputState = .argument(action: action, step: 0, collectedArgs: [])

        // Clear list & trigger search
        actions = []
        search(query: initialArg)
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector)
        -> Bool
    {
        switch commandSelector {
        case #selector(NSResponder.deleteBackward(_:)):
            if inputField.stringValue.isEmpty {
                if case .argument = inputState {
                    return handleBacktab()
                }
                if activeAction != nil {
                    resetToSearch()
                    return true
                }
            }
            return false

        case #selector(NSResponder.insertTab(_:)):
            // Handle Tab navigation
            return handleTab()

        case #selector(NSResponder.insertBacktab(_:)):
            // Handle Shift+Tab
            return handleBacktab()

        case #selector(NSResponder.cancelOperation(_:)):
            if case .executing = inputState {
                ExtensionEngine.shared.terminateAllLongRunning()
                resetToSearch()
                return true
            }
            if case .argument = inputState {
                resetToSearch()
                return true
            }
            if activeAction != nil {
                // Restore previous state
                resetToSearch()
                return true
            }
            delegate?.didPressEscape()
            return true

        // All Enter variants route to the same handler:
        // - insertNewline:                       → Enter, Shift+Enter
        // - insertNewlineIgnoringFieldEditor:     → Option+Enter
        // - insertLineBreak:                      → Control+Enter
        case #selector(NSResponder.insertNewline(_:)),
            #selector(NSResponder.insertNewlineIgnoringFieldEditor(_:)),
            #selector(NSResponder.insertLineBreak(_:)):
            return handleEnter()

        case #selector(NSResponder.moveUp(_:)):
            moveSelection(by: -1)
            return true

        case #selector(NSResponder.moveDown(_:)):
            moveSelection(by: 1)
            return true

        default:
            // Handle manual keybindings
            if let event = NSApp.currentEvent, event.modifierFlags.contains(.command) {
                guard let chars = event.charactersIgnoringModifiers else { return false }
                switch chars {
                case "a":
                    textView.selectAll(nil)
                    return true
                case "c":
                    textView.copy(nil)
                    return true
                case "v":
                    textView.pasteAsPlainText(nil)
                    return true
                case "x":
                    textView.cut(nil)
                    return true
                case "z":
                    if let undoManager = textView.undoManager {
                        if event.modifierFlags.contains(.shift) {
                            if undoManager.canRedo { undoManager.redo() }
                        } else {
                            if undoManager.canUndo { undoManager.undo() }
                        }
                    }
                    return true
                case "k":
                    toggleActionContext()
                    return true
                // Command+Enter: route to Enter handler (Return key = \r)
                case "\r":
                    return handleEnter()
                default: break
                }
            }
            return false
        }
    }

    private func handleEnter() -> Bool {
        let modifiers = NSApp.currentEvent?.modifierFlags ?? []

        // 1. Priority: Execute Selected Result (if actionable)
        if !actions.isEmpty && selectedIndex >= 0 && selectedIndex < actions.count {
            if executeResult(
                actions[selectedIndex], query: inputField.stringValue, modifiers: modifiers)
            {
                return true
            }
        }

        // 2. Check if we are in argument mode (Multi-Step)
        if case .argument(let action, let step, var args) = inputState {
            args.append(inputField.stringValue)
            return submitArgumentAction(action: action, step: step, args: args)
        }

        // 3. Active Action Submission (No result selected from list)
        if let action = activeAction {
            return submitActiveAction(action)
        }

        // 4. Default Search Action
        if !actions.isEmpty {
            let selectedAction = actions[selectedIndex]

            if selectedAction.supportsArguments {
                // If simple arg and has input, maybe execute directly?
                if case .arg(let placeholders, let perform) = selectedAction.type,
                    placeholders.isEmpty == false,
                    !inputField.stringValue.isEmpty
                {

                    // Treat current input as the argument?
                    perform(selectedAction, [inputField.stringValue])
                    FrecencyManager.shared.recordUsage(
                        id: selectedAction.id, forQuery: inputField.stringValue)
                    closeSession(restoreText: false)
                    return true
                }

                // Enter argument mode
                previousSearchText = inputField.stringValue
                enterArgumentMode(action: selectedAction, step: 0, collectedArgs: [])
                return true
            }

            if !executeResult(
                selectedAction, query: inputField.stringValue, modifiers: modifiers)
            {
                delegate?.didSubmit(text: selectedAction.title)
            }
        } else {
            delegate?.didSubmit(text: inputField.stringValue)
        }
        return true
    }

    // MARK: - Search
    private func search(query: String) {
        // If in Argument Mode with active searcher, delegate it via Service
        if let action = activeAction {
            SearchService.shared.delegateSearch(action: action, query: query) {
                [weak self] results in
                DispatchQueue.main.async {  // Ensure Main Thread
                    guard let self = self, self.inputField.stringValue == query else { return }
                    self.actions = results
                    self.updateActions()
                }
            }
            return
        }

        // Main Search via Service
        SearchService.shared.search(query: query) { [weak self] results, fallbacks in
            DispatchQueue.main.async {  // Ensure Main Thread
                guard let self = self else { return }
                // Verify text hasn't changed (though Service handles cancellation best effort)
                if self.inputField.stringValue == query {
                    self.cachedFallbacks = fallbacks
                    self.preModifierActions = nil

                    let currentFlags = NSApp.currentEvent?.modifierFlags ?? []
                    let modConfig = ConfigManager.shared.config.fallbackModifier
                    let isHoldingFallbackMod: Bool
                    switch modConfig {
                    case "cmd": isHoldingFallbackMod = currentFlags.contains(.command)
                    case "opt": isHoldingFallbackMod = currentFlags.contains(.option)
                    case "ctrl": isHoldingFallbackMod = currentFlags.contains(.control)
                    case "shift": isHoldingFallbackMod = currentFlags.contains(.shift)
                    default: isHoldingFallbackMod = currentFlags.contains(.command)
                    }

                    if isHoldingFallbackMod && !fallbacks.isEmpty {
                        self.preModifierActions = results
                        self.actions = fallbacks
                    } else {
                        self.actions = results
                    }

                    self.selectedIndex = 0
                    self.userHasNavigated = false
                    self.updateActions()
                }
            }
        }
    }

    private func updateActions() {
        let isFormState: Bool
        if case .form = inputState {
            isFormState = true
        } else {
            isFormState = false
        }

        let hasActions = !actions.isEmpty
        accessoryStackView.isHidden = isFormState ? true : !hasActions
        scrollView.isHidden = isFormState ? true : !hasActions
        scrollView.hasVerticalScroller = actions.count > LayoutMetrics.Results.maxVisibleRows

        scrollViewBottomConstraint.constant =
            hasActions ? -LayoutMetrics.Results.expandedBottom : -LayoutMetrics.Results.bottom

        resultsTableView.reloadData()

        if hasActions {
            resultsTableView.selectRowIndexes(
                IndexSet(integer: selectedIndex), byExtendingSelection: false)
        }

        updateStatusIcons()

        let isExpanded = !actions.isEmpty
        accessoryStackViewHeightConstraint.constant =
            isExpanded ? LayoutMetrics.Separator.expandedHeight : LayoutMetrics.Separator.height

        let maxVisible = LayoutMetrics.Results.maxVisibleRows
        let baseHeight = CGFloat(min(actions.count, maxVisible)) * LayoutMetrics.Results.rowHeight
        let hasPeek =
            (selectedIndex >= 0 && selectedIndex < actions.count
                && actions[selectedIndex].peek != nil)
        let peekDiff: CGFloat =
            hasPeek
            ? (calculatePeekHeight(for: actions[selectedIndex])
                - LayoutMetrics.Results.rowHeight) : 0
        let totalResultsHeight = baseHeight + peekDiff

        delegate?.didUpdateResults(
            count: actions.count, resultsHeight: totalResultsHeight, isSeparatorExpanded: isExpanded
        )
        updateSelectionIcon()
        refreshActionContextIfNeeded()
        updateFloatingContextButton()
    }

    @discardableResult
    private func updateStatusIcons() -> Bool {
        // Clear existing
        for subview in statusIconContainer.subviews {
            subview.removeFromSuperview()
        }

        var activeIcon: String? = nil
        var activeColor: NSColor = .secondaryLabelColor

        // 1. Scroll Indicator (Only icon shown now)
        if actions.count > LayoutMetrics.Results.maxVisibleRows {
            activeIcon = "arrow.down"
            activeColor = .secondaryLabelColor
        }

        // Render if we have an active icon
        if let iconName = activeIcon {
            let iv = NSImageView()
            iv.image = MainPanelContentViewController.getSymbolImage(for: iconName)
            iv.contentTintColor = activeColor
            if #available(macOS 12.0, *) {
                iv.symbolConfiguration = NSImage.SymbolConfiguration(hierarchicalColor: activeColor)
            }
            iv.translatesAutoresizingMaskIntoConstraints = false
            iv.heightAnchor.constraint(equalToConstant: 14).isActive = true
            iv.widthAnchor.constraint(equalToConstant: 14).isActive = true
            statusIconContainer.addArrangedSubview(iv)
        }

        let hasIcons = activeIcon != nil
        statusIconContainer.isHidden = !hasIcons

        // Ensure layout updates for the separator
        accessoryStackView.layoutSubtreeIfNeeded()

        return hasIcons
    }

    private func moveSelection(by delta: Int) {
        guard !actions.isEmpty else { return }

        let newIndex = (selectedIndex + delta + actions.count) % actions.count
        userHasNavigated = true

        // Let tableViewSelectionDidChange handle the redraw and animation
        resultsTableView.selectRowIndexes(
            IndexSet(integer: newIndex), byExtendingSelection: false)
        resultsTableView.scrollRowToVisible(newIndex)
        updateSelectionIcon()
    }

    // MARK: - NSTableViewDataSource
    private func calculatePeekHeight(for action: NerwAction) -> CGFloat {
        guard let peek = action.peek else { return 70.0 }

        let textWidth: CGFloat = 550.0  // Safe estimate for subtitle width
        let textFontSize = peek.textFontSize ?? 12
        let titleFontSize = peek.titleFontSize ?? 16

        let isTitleHidden =
            peek.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || titleFontSize <= 0

        var containerHeight: CGFloat = 0

        if !isTitleHidden {
            // Title is visible. Center is 27. Bottom is 27 + (fontHeight/2)
            containerHeight = 27.0 + (CGFloat(titleFontSize) * 1.5 / 2.0)
            containerHeight += 12.0  // Gap below title
        } else {
            // Title is hidden. Subtitle will start near the top.
            containerHeight = 16.0
        }

        if textFontSize > 0 {
            let font = NSFont.systemFont(ofSize: textFontSize, weight: .regular)
            let rect = NSString(string: peek.text).boundingRect(
                with: NSSize(width: textWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: font],
                context: nil
            )
            containerHeight += ceil(rect.height) + 12.0  // Safer buffer for NSTextField intrinsic padding
        }

        // Bottom padding
        if peek.courtesyText != nil && !peek.courtesyText!.isEmpty {
            // Courtesy stack height is ~14, plus 12 bottom margin. Subtitle is 8 above it.
            containerHeight += 8.0 + 14.0 + 12.0
        } else {
            // Just standard bottom margin to container
            containerHeight += 16.0
        }

        // Add vertical margins for the cell container itself
        let totalHeight = containerHeight + (LayoutMetrics.Cell.Margin.vertical * 2)

        return max(70.0, min(totalHeight, 400.0))
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        actions.count
    }

    // MARK: - NSTableViewDelegate

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int)
        -> NSView?
    {
        guard row < actions.count else { return nil }
        let action = actions[row]

        let identifier = NSUserInterfaceItemIdentifier("ResultCell")
        var cell = tableView.makeView(withIdentifier: identifier, owner: self) as? ResultCellView
        if cell == nil {
            cell = ResultCellView()
            cell?.identifier = identifier
        }

        let modifiers = NSApp.currentEvent?.modifierFlags ?? []
        cell?.configure(
            with: action, isSelected: row == selectedIndex, isExplicitNavigation: userHasNavigated,
            modifiers: modifiers)

        return cell
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        guard row < actions.count else { return LayoutMetrics.Results.rowHeight }
        let action = actions[row]
        if row == selectedIndex && action.peek != nil {
            return calculatePeekHeight(for: action)
        }
        return LayoutMetrics.Results.rowHeight
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        return ResultRowView()
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let oldIndex = selectedIndex
        selectedIndex = resultsTableView.selectedRow >= 0 ? resultsTableView.selectedRow : 0

        // Handle animations and partial reloads
        var rowsToUpdate = IndexSet()
        if oldIndex >= 0 && oldIndex < actions.count { rowsToUpdate.insert(oldIndex) }
        if selectedIndex >= 0 && selectedIndex < actions.count {
            rowsToUpdate.insert(selectedIndex)
        }

        NSAnimationContext.beginGrouping()
        NSAnimationContext.current.duration = 0.15
        NSAnimationContext.current.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        let cols = IndexSet(integer: 0)
        resultsTableView.reloadData(forRowIndexes: rowsToUpdate, columnIndexes: cols)

        // Only trigger height change animation if a peek changes
        let oldHasPeek = oldIndex >= 0 && oldIndex < actions.count && actions[oldIndex].peek != nil
        let newHasPeek =
            selectedIndex >= 0 && selectedIndex < actions.count
            && actions[selectedIndex].peek != nil
        if oldHasPeek || newHasPeek {
            resultsTableView.noteHeightOfRows(withIndexesChanged: rowsToUpdate)

            let isExpanded = !actions.isEmpty
            let maxVisible = LayoutMetrics.Results.maxVisibleRows
            let baseHeight =
                CGFloat(min(actions.count, maxVisible)) * LayoutMetrics.Results.rowHeight
            let dynamicPeekHeight =
                newHasPeek ? calculatePeekHeight(for: actions[selectedIndex]) : 110.0
            let peekDiff: CGFloat =
                newHasPeek ? (dynamicPeekHeight - LayoutMetrics.Results.rowHeight) : 0
            let totalResultsHeight = baseHeight + peekDiff

            delegate?.didUpdateResults(
                count: actions.count, resultsHeight: totalResultsHeight,
                isSeparatorExpanded: isExpanded)
        }

        NSAnimationContext.endGrouping()
        refreshActionContextIfNeeded()
        updateFloatingContextButton()
    }
}

extension MainPanelContentViewController: FormViewDelegate {
    func formDidCancel() {
        // 1. cleanup form FIRST to remove constraints that force window height
        formView?.removeFromSuperview()
        formView = nil

        // 2. Close the panel completely instead of returning to search
        delegate?.didPressEscape()
    }

    func formDidSubmit(values: [String: String]) {
        guard case .form(let action) = inputState,
            case .form(_, _, let perform) = action.type
        else { return }

        dispatchActionExecution(action: action, query: nil) {
            perform(action, values)
        }
    }
}

extension MainPanelContentViewController: ActionContextViewControllerDelegate {
    func actionContext(
        _ controller: ActionContextViewController,
        didInvoke operation: NerwActionContext.Operation,
        in context: NerwActionContext
    ) {
        dismissActionContext()

        guard let action = actionForContext(id: context.actionID) else { return }

        switch operation.kind {
        case .primary:
            _ = performPrimaryAction(for: action)
        case .secondary:
            _ = performSecondaryAction(for: action)
        case .modifier(let key):
            _ = executeResult(
                action,
                query: inputField.stringValue,
                modifiers: modifierFlags(for: key)
            )
        case .alias, .hotkey, .toggleEnabled, .toggleHidden, .custom:
            break
        }
    }

    func actionContext(
        _ controller: ActionContextViewController,
        didUpdatePreferencesFor actionID: String
    ) {
        SearchService.shared.clearCache()

        if case .search = inputState {
            search(query: inputField.stringValue)
        }
    }

    func actionContextDidRequestClose(_ controller: ActionContextViewController) {
        dismissActionContext()
    }
}

// MARK: - ThemedTextField
class ThemedTextField: NSTextField {
    var placeholderColor: NSColor = .secondaryLabelColor {
        didSet {
            updatePlaceholder()
        }
    }

    override var font: NSFont? {
        didSet {
            updatePlaceholder()
        }
    }

    private var _rawPlaceholder: String?

    override var placeholderString: String? {
        get { _rawPlaceholder }
        set {
            print("[DebugUI] ThemedTextField.placeholderString set to: \(newValue ?? "nil")")
            _rawPlaceholder = newValue
            updatePlaceholder()
        }
    }

    private func updatePlaceholder() {
        guard let text = _rawPlaceholder else {
            self.placeholderAttributedString = nil
            super.placeholderString = nil
            return
        }

        // Log to confirm underlying attribute string update
        let attr = NSMutableAttributedString(string: text)
        print("[DebugUI] Updating placeholder visual for: \(text) with color \(placeholderColor)")

        let range = NSRange(location: 0, length: attr.length)

        // Use the placeholderColor set during theming
        attr.addAttribute(.foregroundColor, value: placeholderColor, range: range)

        // Font
        if let font = self.font {
            attr.addAttribute(.font, value: font, range: range)
        }

        // Alignment
        let style = NSMutableParagraphStyle()
        style.alignment = self.alignment
        attr.addAttribute(.paragraphStyle, value: style, range: range)

        // Sync both for consistency
        super.placeholderString = text
        self.placeholderAttributedString = attr
        self.needsDisplay = true
    }
}
