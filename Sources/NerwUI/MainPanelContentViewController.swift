// MainPanelContentViewController.swift
import Cocoa
import NerwBuiltin
import NerwCore
import NerwSearchBackend
import NerwUtils

protocol MainPanelContentDelegate: AnyObject {
    func didPressEscape()
    func didSubmit(text: String)
    func didUpdateResults(count: Int, isSeparatorExpanded: Bool)
    func requestsResize(to height: CGFloat)
}

class MainPanelContentViewController: NSViewController, NSTextFieldDelegate, NSTableViewDataSource,
    NSTableViewDelegate
{
    // MARK: - Layout Configuration
    struct LayoutMetrics {
        struct Window {
            static let width: CGFloat = 650
            static let cornerRadius: CGFloat = 28
        }

        struct SearchField {
            static let height: CGFloat = 32
            static let fontSize: CGFloat = 22
            static let top: CGFloat = 12  // Margin from window top
            static let bottom: CGFloat = 12  // Margin from window bottom (in shrink view)
            static let leading: CGFloat = 12  // Margin from icon container
            static let trailing: CGFloat = 20  // Margin from window trailing edge
        }

        struct IconContainer {
            static let height: CGFloat = 40
            static let iconSize: CGFloat = 20
            static let spacing: CGFloat = 12
            static let leading: CGFloat = 20  // Margin from window leading edge
        }

        struct Separator {
            static let height: CGFloat = 1  // Default/Collapsed height
            static let expandedHeight: CGFloat = 14  // Height when icons are present
            static let lineHeight: CGFloat = 1  // Actual separator line height
            static let top: CGFloat = 2  // Reduced margin to keep visuals tight
            static let bottom: CGFloat = 0  // Margin to Results top
            static let leading: CGFloat = 20
            static let trailing: CGFloat = 20
        }

        struct Results {
            static let rowHeight: CGFloat = 50
            static let maxVisibleRows: Int = 5
            static let bottom: CGFloat = 0  // Default margin
            static let expandedBottom: CGFloat = 16  // Margin when expanded
        }

        struct Cell {
            static let cornerRadius: CGFloat = 20

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
                static let titleSize: CGFloat = 14
                static let subtitleSize: CGFloat = 11
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
    private var backgroundView: NSVisualEffectView!
    private var tintView: NSView!
    private var scrollViewBottomConstraint: NSLayoutConstraint!
    private var formView: FormView?

    private var isDebugMode = false

    private var actions: [NerwAction] = []
    private var activeAction: NerwAction?
    private var previousSearchText: String = ""
    private var selectedIndex: Int = 0
    private var userHasNavigated: Bool = false

    // State Machine for Input
    enum InputState {
        case search
        case argument(action: NerwAction, step: Int, collectedArgs: [String])
        case form(action: NerwAction)
    }
    private var inputState: InputState = .search

    // Tracks current search task

    // Tracks current search task

    override func viewWillAppear() {
        super.viewWillAppear()
        // Refresh Shortcuts if enabled
        if ConfigManager.shared.config.showShortcutsInMain {
            ShortcutsEngine.shared.refresh()
        }
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
        // Background - NSVisualEffectView for blur
        backgroundView = NSVisualEffectView()
        backgroundView.material = .hudWindow
        backgroundView.appearance = NSAppearance(named: .vibrantDark)
        backgroundView.blendingMode = .behindWindow
        backgroundView.state = .active
        backgroundView.wantsLayer = true
        backgroundView.layer?.cornerRadius = LayoutMetrics.Window.cornerRadius
        backgroundView.layer?.masksToBounds = true
        backgroundView.layer?.borderColor = NSColor.white.withAlphaComponent(0.12).cgColor
        backgroundView.layer?.borderWidth = 0.8

        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(backgroundView)

        // Tint View - Pitch Black Overlay
        tintView = NSView()
        tintView.wantsLayer = true
        tintView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.3).cgColor
        tintView.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.addSubview(tintView)

        // Constraint Tint to Background
        NSLayoutConstraint.activate([
            tintView.topAnchor.constraint(equalTo: backgroundView.topAnchor),
            tintView.leadingAnchor.constraint(equalTo: backgroundView.leadingAnchor),
            tintView.trailingAnchor.constraint(equalTo: backgroundView.trailingAnchor),
            tintView.bottomAnchor.constraint(equalTo: backgroundView.bottomAnchor),
        ])

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
        defaultSearchIcon.widthAnchor.constraint(
            equalToConstant: LayoutMetrics.IconContainer.iconSize
        )
        .isActive = true
        defaultSearchIcon.heightAnchor.constraint(
            equalToConstant: LayoutMetrics.IconContainer.iconSize
        )
        .isActive = true
        defaultSearchIcon.imageScaling = .scaleProportionallyUpOrDown
        iconContainer.addArrangedSubview(defaultSearchIcon)

        // Input field
        inputField = ThemedTextField()
        inputField.font = .systemFont(ofSize: LayoutMetrics.SearchField.fontSize, weight: .light)
        inputField.placeholderString = "nerw"
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
        // Result alignment fix:
        // Left side aligns natively (implicit padding ~20pt).
        // To fix right overflow and match separator width, we subtract margins (20+20=40pt).
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
        NSLayoutConstraint.activate([
            backgroundView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            iconContainer.leadingAnchor.constraint(
                equalTo: backgroundView.leadingAnchor, constant: LayoutMetrics.IconContainer.leading
            ),
            iconContainer.centerYAnchor.constraint(
                equalTo: inputField.centerYAnchor, constant: -1.5),
            iconContainer.heightAnchor.constraint(
                equalToConstant: LayoutMetrics.IconContainer.height),

            inputField.topAnchor.constraint(
                equalTo: backgroundView.topAnchor, constant: LayoutMetrics.SearchField.top),
            inputField.leadingAnchor.constraint(
                equalTo: iconContainer.trailingAnchor, constant: LayoutMetrics.SearchField.leading),
            inputField.trailingAnchor.constraint(
                equalTo: backgroundView.trailingAnchor,
                constant: -LayoutMetrics.SearchField.trailing),
            inputField.heightAnchor.constraint(equalToConstant: LayoutMetrics.SearchField.height),

            accessoryStackView.topAnchor.constraint(
                equalTo: inputField.bottomAnchor, constant: LayoutMetrics.Separator.top),
            accessoryStackView.leadingAnchor.constraint(
                equalTo: backgroundView.leadingAnchor,
                constant: LayoutMetrics.Separator.leading),
            accessoryStackView.trailingAnchor.constraint(
                equalTo: backgroundView.trailingAnchor,
                constant: -LayoutMetrics.Separator.trailing),

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
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(
            self, selector: #selector(configDidUpdate),
            name: Notification.Name("NerwConfigDidUpdate"), object: nil)
    }

    @objc private func configDidUpdate() {
        DispatchQueue.main.async {
            self.applyTheming()
            self.resultsTableView.reloadData()
        }
    }

    private func applyTheming() {
        let config = ConfigManager.shared.config.uiConfig

        // Background
        if let bgHex = config?.mainBackgroundColor, let bgColor = NSColor(hex: bgHex) {
            backgroundView.layer?.backgroundColor = bgColor.cgColor
        }

        // Font & Text Color
        let fontSize = LayoutMetrics.SearchField.fontSize
        if let fontName = config?.font, let font = NSFont(name: fontName, size: fontSize) {
            inputField.font = font
        }

        if let fgHex = config?.mainForegroundColor, let fgColor = NSColor(hex: fgHex) {
            inputField.textColor = fgColor
            defaultSearchIcon.contentTintColor = fgColor
        }

        // Placeholder Color
        var iconColor: NSColor = .secondaryLabelColor
        if let fgHex = config?.mainForegroundColor, let fgColor = NSColor(hex: fgHex) {
            iconColor = fgColor
        }

        if let hintHex = config?.hintColor, let hintColor = NSColor(hex: hintHex) {
            inputField.placeholderColor = hintColor
        } else {
            inputField.placeholderColor = iconColor
        }
    }

    func toggleDebugMode() {
        isDebugMode.toggle()

        let views: [NSView?] = [
            backgroundView, iconContainer, inputField, separatorView, scrollView,
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

    func setIcons(_ icons: [NSImage]) {
        for subview in iconContainer.arrangedSubviews {
            subview.removeFromSuperview()
        }

        if icons.isEmpty {
            iconContainer.addArrangedSubview(defaultSearchIcon)
        } else {
            for image in icons {
                let iv = NSImageView()
                iv.image = image
                iv.contentTintColor = .secondaryLabelColor
                iv.translatesAutoresizingMaskIntoConstraints = false
                iv.widthAnchor.constraint(equalToConstant: LayoutMetrics.IconContainer.iconSize)
                    .isActive =
                    true
                iv.heightAnchor.constraint(equalToConstant: LayoutMetrics.IconContainer.iconSize)
                    .isActive =
                    true
                iv.imageScaling = .scaleProportionallyUpOrDown
                iconContainer.addArrangedSubview(iv)
            }
        }
    }

    func reset() {
        inputState = .search
        activeAction = nil
        inputField.placeholderString = "nerw"
        inputField.stringValue = ""
        setIcons([])
        actions = []
        previousSearchText = ""
        selectedIndex = 0
        userHasNavigated = false

        // Form Cleanup
        formView?.removeFromSuperview()
        formView = nil
        inputField.isHidden = false
        iconContainer.isHidden = false
        separatorView.isHidden = false

        updateActions()
    }

    // MARK: - Helpers
    private func closeSession(restoreText: Bool = true) {
        activeAction = nil
        inputField.placeholderString = "nerw"
        if restoreText {
            inputField.stringValue = previousSearchText
        }
        setIcons([])

        // Form Cleanup
        formView?.removeFromSuperview()
        formView = nil
        inputField.isHidden = false
        iconContainer.isHidden = false
        separatorView.isHidden = false

        delegate?.didPressEscape()
    }

    private func executeResult(_ result: NerwAction, query: String) -> Bool {
        switch result.type {
        case .instant(let perform):
            perform(result)
            FrecencyManager.shared.recordUsage(id: result.id, forQuery: query)
            closeSession()
            return true

        case .hybrid(let perform, _):
            perform(result)
            FrecencyManager.shared.recordUsage(id: result.id, forQuery: query)
            closeSession()
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
                let icon =
                    NSImage(systemSymbolName: iconName, accessibilityDescription: nil) ?? NSImage()
                setIcons([icon])
                return
            }
        }
        setIcons([])
    }

    private func resetToSearch() {
        print("[DebugUI] resetToSearch called")
        inputState = .search
        activeAction = nil

        // GUARD: update the placeholder first
        inputField.placeholderString = "nerw"

        // Clear text (User Requirement: Do not recomplete previous string)
        inputField.stringValue = ""
        previousSearchText = ""

        setIcons([])
        separatorView.isHidden = false
        // Reset results
        actions = []
        updateActions()
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

            case .hybrid(_, let box):
                let quickAction = box.value
                // Check if quick action needs arguments
                previousSearchText = inputField.stringValue
                switch quickAction.type {
                case .arg, .args:
                    activateArgumentMode(for: quickAction, initialArg: "")
                case .form:
                    enterFormMode(action: quickAction)
                case .instant, .hybrid:
                    // Record Usage for Instant/Hybrid swap
                    FrecencyManager.shared.recordUsage(
                        id: quickAction.id, forQuery: previousSearchText)

                    // Direct Swap
                    activeAction = quickAction
                    inputField.placeholderString = quickAction.title
                    inputField.stringValue = ""
                    updateIcon(for: quickAction)
                    actions = []
                    updateActions()
                }
                return true

            case .instant:
                return false
            }

        case .argument(let action, let step, var args):
            // Check if there is a next argument
            // Only .arg supports multiple steps via array
            if case .arg(let placeholders, _) = action.type, step < placeholders.count - 1 {
                args.append(inputField.stringValue)
                enterArgumentMode(action: action, step: step + 1, collectedArgs: args)
                return true
            }
            return false

        case .form:
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
        if step == 0 {
            FrecencyManager.shared.recordUsage(id: action.id, forQuery: previousSearchText)
        }
        // Update State
        inputState = .argument(action: action, step: step, collectedArgs: collectedArgs)
        activeAction = action

        // 1. Clear text first (Critical for placeholder update consistency)
        inputField.stringValue = ""
        inputField.currentEditor()?.moveToEndOfLine(nil)

        // 2. Update Placeholder based on argument name
        var placeholder = action.title
        switch action.type {
        case .arg(let placeholders, _):
            if step < placeholders.count { placeholder = placeholders[step] }
        case .args(let ph, _, _):
            placeholder = ph
        default: break
        }
        inputField.placeholderString = placeholder

        // Update UI
        updateIcon(for: action)

        // Clear list to focus on input
        actions = []
        updateActions()

        // Trigger initial search for suggestions (e.g. list volumes for "eject")
        search(query: "")
    }

    private func updateIcon(for action: NerwAction) {
        if let icon = action.icon {
            switch icon {
            case .system(let name):
                setIcons([
                    NSImage(systemSymbolName: name, accessibilityDescription: nil) ?? NSImage()
                ])
            case .image(let img):
                setIcons([img])
            case .file(let url):
                setIcons([NSWorkspace.shared.icon(for: .data)])
                NerwUtils.IconUtils.getIconAsync(for: url, size: CGSize(width: 32, height: 32)) {
                    [weak self] image in
                    if let image = image { self?.setIcons([image]) }
                }
            }
        }
    }

    private func enterFormMode(action: NerwAction) {
        guard case .form(let fields, _, _) = action.type else { return }

        inputState = .form(action: action)
        activeAction = action
        FrecencyManager.shared.recordUsage(id: action.id, forQuery: previousSearchText)

        // Hide Main Search UI
        inputField.isHidden = true
        iconContainer.isHidden = true
        separatorView.isHidden = true
        scrollView.isHidden = true

        // Setup Form View
        let form = FormView(fields: fields)
        form.delegate = self
        form.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.addSubview(form)
        formView = form

        NSLayoutConstraint.activate([
            form.topAnchor.constraint(equalTo: backgroundView.topAnchor),
            form.leadingAnchor.constraint(equalTo: backgroundView.leadingAnchor),
            form.trailingAnchor.constraint(equalTo: backgroundView.trailingAnchor),
            // Remove bottom anchor constraint to allow form to dictate height?
            // No, we want to constrain form to window, but resize window to form.
            // So we need to calculate height first.
            form.bottomAnchor.constraint(equalTo: backgroundView.bottomAnchor),
        ])

        // Calculate required height based on fields
        // 20 (top) + 20 (bottom) + fields * (45 approx) + spacing
        // Let's use fitting size after layout
        form.layoutSubtreeIfNeeded()
        let fittingSize = form.fittingSize
        // Ensure minimum height (e.g. at least search bar height)
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

        // [New Feature] Space to Trigger Find File (Alfred Style)
        if ConfigManager.shared.config.findFileOnSpace && query == " " {
            inputField.stringValue = "find "
            inputField.currentEditor()?.moveToEndOfLine(nil)
            query = "find "
        }

        // Smart Trigger Logic
        let components = query.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: false)

        if components.count >= 2 {
            let possibleTrigger = String(components[0])
            let arg = String(components[1])

            // Unified check for built-in providers
            if let result = Nerw.shared.findByTrigger(possibleTrigger) ?? FindFile.shared
                .findByTrigger(possibleTrigger)
                ?? System.shared.findByTrigger(possibleTrigger)

            {

                if result.supportsArguments {
                    previousSearchText = possibleTrigger
                    activateArgumentMode(for: result, initialArg: arg)
                    return
                }
            }
        }

        search(query: query)
    }

    private func activateArgumentMode(for action: NerwAction, initialArg: String) {
        // Switch to Argument Mode
        activeAction = action
        FrecencyManager.shared.recordUsage(id: action.id, forQuery: previousSearchText)
        inputState = .argument(action: action, step: 0, collectedArgs: [])
        inputField.stringValue = initialArg
        inputField.currentEditor()?.moveToEndOfLine(nil)

        // Update Placeholder based on argument name
        var placeholder = action.title
        switch action.type {
        case .arg(let placeholders, _):
            if let first = placeholders.first { placeholder = first }
        case .args(let ph, _, _):
            placeholder = ph
        default: break
        }
        inputField.placeholderString = placeholder

        updateIcon(for: action)

        // Clear list & trigger search
        actions = []
        // updateActions()
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

        case #selector(NSResponder.insertNewline(_:)):
            // 1. Priority: Execute Selected Result (if actionable)
            if !actions.isEmpty && selectedIndex >= 0 && selectedIndex < actions.count {
                if executeResult(actions[selectedIndex], query: inputField.stringValue) {
                    return true
                }
            }

            // 2. Check if we are in argument mode (Multi-Step)
            if case .argument(let action, let step, var args) = inputState {
                args.append(inputField.stringValue)

                var isLastStep = false
                switch action.type {
                case .arg(let placeholders, _):
                    isLastStep = step >= placeholders.count - 1
                case .args:
                    isLastStep = true  // Single step for args type
                default: break
                }

                if isLastStep {
                    // Final Submission
                    switch action.type {
                    case .arg(_, let perform):
                        perform(action, args)
                    case .args(_, _, let perform):
                        if let p = perform {
                            // Single string arg for 'args' type
                            p(action, args.joined(separator: " "))
                        } else {
                            // Fallback
                            delegate?.didSubmit(
                                text: "\(action.title) \(args.joined(separator: " "))")
                        }
                    default: break
                    }
                    closeSession()
                    return true
                } else {
                    // Move to next step
                    enterArgumentMode(action: action, step: step + 1, collectedArgs: args)
                    return true
                }
            }

            // 3. Active Action Submission (No result selected from list)
            if let action = activeAction {
                switch action.type {
                case .instant(let perform):
                    perform(action)
                    resetToSearch()
                case .args(_, _, let perform):
                    perform?(action, inputField.stringValue)
                    resetToSearch()
                default:
                    delegate?.didSubmit(text: "\(action.title) \(inputField.stringValue)")
                    resetToSearch()
                }
                return true
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
                        // Legacy code did: selectedAction.handler?(inputField.stringValue)
                        // If user typed "g test" -> input is "test", action is Google.
                        // Execute it.
                        perform(selectedAction, [inputField.stringValue])
                        FrecencyManager.shared.recordUsage(
                            id: selectedAction.id, forQuery: inputField.stringValue)
                        closeSession()
                        return true
                    }

                    // Enter argument mode
                    previousSearchText = inputField.stringValue
                    enterArgumentMode(action: selectedAction, step: 0, collectedArgs: [])
                    return true
                }

                if !executeResult(selectedAction, query: inputField.stringValue) {
                    delegate?.didSubmit(text: selectedAction.title)
                }
            } else {
                delegate?.didSubmit(text: inputField.stringValue)
            }
            return true

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
                default: break
                }
            }
            return false
        }
    }

    // MARK: - Search
    private func search(query: String) {
        // If in Argument Mode with active searcher, delegate it via Service
        if let action = activeAction {
            SearchService.shared.delegateSearch(action: action, query: query) {
                [weak self] results in
                DispatchQueue.main.async {  // Ensure Main Thread
                    self?.actions = results
                    self?.updateActions()
                }
            }
            return
        }

        // Main Search via Service
        SearchService.shared.search(query: query) { [weak self] results in
            DispatchQueue.main.async {  // Ensure Main Thread
                guard let self = self else { return }
                // Verify text hasn't changed (though Service handles cancellation best effort)
                if self.inputField.stringValue == query {
                    self.actions = results
                    self.selectedIndex = 0
                    self.userHasNavigated = false
                    self.updateActions()
                }
            }
        }
    }

    private func updateActions() {
        let hasActions = !actions.isEmpty
        accessoryStackView.isHidden = !hasActions
        scrollView.isHidden = !hasActions
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

        delegate?.didUpdateResults(count: actions.count, isSeparatorExpanded: isExpanded)
        updateSelectionIcon()
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
            activeColor = .tertiaryLabelColor
        }

        // Render if we have an active icon
        if let iconName = activeIcon {
            let iv = NSImageView()
            iv.image = NSImage(systemSymbolName: iconName, accessibilityDescription: nil)
            iv.contentTintColor = activeColor
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
        selectedIndex = (selectedIndex + delta + actions.count) % actions.count
        userHasNavigated = true
        resultsTableView.selectRowIndexes(
            IndexSet(integer: selectedIndex), byExtendingSelection: false)
        resultsTableView.scrollRowToVisible(selectedIndex)
        updateSelectionIcon()
    }

    // MARK: - NSTableViewDataSource

    func numberOfRows(in tableView: NSTableView) -> Int {
        actions.count
    }

    // MARK: - NSTableViewDelegate

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int)
        -> NSView?
    {
        let action = actions[row]
        let cell = ResultCellView()
        cell.configure(
            with: action, isSelected: row == selectedIndex, isExplicitNavigation: userHasNavigated)
        return cell
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        return ResultRowView()
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        selectedIndex = resultsTableView.selectedRow >= 0 ? resultsTableView.selectedRow : 0
        resultsTableView.reloadData()
    }
}

extension MainPanelContentViewController: FormViewDelegate {
    func formDidCancel() {
        // 1. cleanup form FIRST to remove constraints that force window height
        formView?.removeFromSuperview()
        formView = nil
        inputField.isHidden = false
        iconContainer.isHidden = false

        // 2. Then reset to search which triggers resize
        resetToSearch()

        // Restore focus
        view.window?.makeFirstResponder(inputField)
    }

    func formDidSubmit(values: [String: String]) {
        guard case .form(let action) = inputState,
            case .form(_, _, let perform) = action.type
        else { return }

        perform(action, values)
        closeSession()
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
            super.placeholderString = nil
            return
        }

        // Log to confirm underlying attribute string update
        let attr = NSMutableAttributedString(string: text)
        print("[DebugUI] Updating placeholder visual for: \(text)")

        let range = NSRange(location: 0, length: attr.length)

        // Color
        attr.addAttribute(.foregroundColor, value: placeholderColor, range: range)

        // Font
        if let font = self.font {
            attr.addAttribute(.font, value: font, range: range)
        }

        // Alignment
        let style = NSMutableParagraphStyle()
        style.alignment = self.alignment
        attr.addAttribute(.paragraphStyle, value: style, range: range)

        self.placeholderAttributedString = attr
    }
}
