// PopupContentViewController.swift
import Cocoa
import NerwCore
import NerwBuiltin
import Ifrit

protocol PopupContentDelegate: AnyObject {
    func didPressEscape()
    func didSubmit(text: String)
    func didUpdateResults(count: Int)
}

class PopupContentViewController: NSViewController, NSTextFieldDelegate, NSTableViewDataSource,
    NSTableViewDelegate
{
    // MARK: - Layout Configuration
    struct LayoutMetrics {
        struct Window {
            static let width: CGFloat = 650
            static let cornerRadius: CGFloat = 16
        }

        struct SearchField {
            static let height: CGFloat = 32
            static let fontSize: CGFloat = 22
            static let top: CGFloat = 16        // Margin from window top
            static let bottom: CGFloat = 16     // Margin from window bottom (in shrink view)
            static let leading: CGFloat = 12    // Margin from icon container
            static let trailing: CGFloat = 20   // Margin from window trailing edge
        }

        struct IconContainer {
            static let height: CGFloat = 40
            static let iconSize: CGFloat = 20
            static let spacing: CGFloat = 12
            static let leading: CGFloat = 20    // Margin from window leading edge
        }

        struct Separator {
            static let height: CGFloat = 1
            static let top: CGFloat = 16        // Margin from SearchField bottom
            static let bottom: CGFloat = 0      // Margin to Results top
            static let leading: CGFloat = 20
            static let trailing: CGFloat = 20
        }

        struct Results {
            static let rowHeight: CGFloat = 50
            static let maxVisibleRows: Int = 5
            static let bottom: CGFloat = 0      // Default margin
            static let expandedBottom: CGFloat = 16 // Margin when expanded
        }

        struct Cell {
            static let cornerRadius: CGFloat = 8

            struct Margin {
                static let vertical: CGFloat = 2
                static let horizontal: CGFloat = 0
            }

            struct Icon {
                static let size: CGFloat = 28
                static let leading: CGFloat = 10
                static let trailing: CGFloat = 6 // Spacing to text
            }

            struct Text {
                static let titleTop: CGFloat = 6
                static let subtitleTop: CGFloat = 1
                static let titleSize: CGFloat = 14
                static let subtitleSize: CGFloat = 11
            }
        }
    }

    weak var delegate: PopupContentDelegate?

    private var iconContainer: NSStackView!
    private var defaultSearchIcon: NSImageView!
    private(set) var inputField: NSTextField!
    private var resultsTableView: NSTableView!
    private var scrollView: NSScrollView!
    private var separatorView: NSBox!
    private var backgroundView: NSVisualEffectView!
    private var scrollViewBottomConstraint: NSLayoutConstraint!

    private var isDebugMode = false

    private var actions: [Action] = []
    private var activeAction: Action?
    private var previousSearchText: String = ""
    private var selectedIndex: Int = 0

    struct Action {
        let icon: NSImage?
        let title: String
        let subtitle: String
        let height: CGFloat? // Dynamic height support if needed
        let supportsArguments: Bool
        let path: String? // For apps
        let handler: ((String) -> Void)?
        
        init(icon: NSImage?, title: String, subtitle: String, supportsArguments: Bool, path: String? = nil, handler: ((String) -> Void)? = nil) {
            self.icon = icon
            self.title = title
            self.subtitle = subtitle
            self.supportsArguments = supportsArguments
            self.path = path
            self.handler = handler
            self.height = nil
        }
    }

    override func loadView() {
        // Initial height calculation for shrink view
        let initialHeight = LayoutMetrics.SearchField.top + LayoutMetrics.SearchField.height + LayoutMetrics.SearchField.bottom
        view = NSView(
            frame: NSRect(
                x: 0, y: 0, width: LayoutMetrics.Window.width, height: initialHeight))
        view.wantsLayer = true
        setupViews()
    }

    private func setupViews() {
        // Background blur
        backgroundView = NSVisualEffectView()
        backgroundView.material = .hudWindow
        backgroundView.state = .active
        backgroundView.blendingMode = .behindWindow
        backgroundView.wantsLayer = true
        backgroundView.layer?.cornerRadius = LayoutMetrics.Window.cornerRadius
        backgroundView.layer?.masksToBounds = true
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(backgroundView)

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
        defaultSearchIcon.widthAnchor.constraint(equalToConstant: LayoutMetrics.IconContainer.iconSize)
            .isActive = true
        defaultSearchIcon.heightAnchor.constraint(equalToConstant: LayoutMetrics.IconContainer.iconSize)
            .isActive = true
        defaultSearchIcon.imageScaling = .scaleProportionallyUpOrDown
        iconContainer.addArrangedSubview(defaultSearchIcon)

        // Input field
        inputField = NSTextField()
        inputField.placeholderString = "nerw"
        inputField.font = .systemFont(ofSize: LayoutMetrics.SearchField.fontSize, weight: .light)
        inputField.isBordered = false
        inputField.drawsBackground = false
        inputField.focusRingType = .none
        inputField.textColor = .labelColor
        inputField.delegate = self
        inputField.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.addSubview(inputField)

        // Separator
        separatorView = NSBox()
        separatorView.boxType = .separator
        separatorView.isHidden = true
        separatorView.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.addSubview(separatorView)

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
        let columnWidth = LayoutMetrics.Window.width - (LayoutMetrics.Separator.leading + LayoutMetrics.Separator.trailing)
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
                equalTo: backgroundView.leadingAnchor, constant: LayoutMetrics.IconContainer.leading),
            iconContainer.centerYAnchor.constraint(equalTo: inputField.centerYAnchor, constant: -1.5),
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

            separatorView.topAnchor.constraint(
                equalTo: inputField.bottomAnchor, constant: LayoutMetrics.Separator.top),
            separatorView.leadingAnchor.constraint(
                equalTo: backgroundView.leadingAnchor,
                constant: LayoutMetrics.Separator.leading),
            separatorView.trailingAnchor.constraint(
                equalTo: backgroundView.trailingAnchor,
                constant: -LayoutMetrics.Separator.trailing),
            separatorView.heightAnchor.constraint(equalToConstant: LayoutMetrics.Separator.height),

            separatorView.heightAnchor.constraint(equalToConstant: LayoutMetrics.Separator.height),

            scrollView.topAnchor.constraint(equalTo: separatorView.bottomAnchor, constant: LayoutMetrics.Separator.bottom),
            scrollView.leadingAnchor.constraint(equalTo: backgroundView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: backgroundView.trailingAnchor),
        ])
        
        scrollViewBottomConstraint = scrollView.bottomAnchor.constraint(
            equalTo: backgroundView.bottomAnchor, constant: -LayoutMetrics.Results.bottom
        )
        scrollViewBottomConstraint.isActive = true
    }

    func toggleDebugMode() {
        isDebugMode.toggle()
        print("Debug mode: \(isDebugMode)")

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
        iconContainer.arrangedSubviews.forEach { $0.removeFromSuperview() }

        if icons.isEmpty {
            iconContainer.addArrangedSubview(defaultSearchIcon)
        } else {
            for image in icons {
                let iv = NSImageView()
                iv.image = image
                iv.contentTintColor = .secondaryLabelColor
                iv.translatesAutoresizingMaskIntoConstraints = false
                iv.widthAnchor.constraint(equalToConstant: LayoutMetrics.IconContainer.iconSize).isActive = true
                iv.heightAnchor.constraint(equalToConstant: LayoutMetrics.IconContainer.iconSize).isActive = true
                iv.imageScaling = .scaleProportionallyUpOrDown
                iconContainer.addArrangedSubview(iv)
            }
        }
    }

    func reset() {
        inputField.stringValue = ""
        setIcons([])
        actions = []
        activeAction = nil
        previousSearchText = ""
        selectedIndex = 0
        updateActions()
    }

    // MARK: - NSTextFieldDelegate

    func controlTextDidChange(_ obj: Notification) {
        let query = inputField.stringValue
        search(query: query)
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector)
        -> Bool
    {
        switch commandSelector {
        case #selector(NSResponder.cancelOperation(_:)):
            if activeAction != nil {
                // Restore previous state
                activeAction = nil
                inputField.stringValue = previousSearchText
                inputField.placeholderString = "nerw"
                setIcons([]) // Reset to default icon
                search(query: previousSearchText) // Re-trigger search
                return true
            }
            delegate?.didPressEscape()
            return true

        case #selector(NSResponder.insertTab(_:)):
            if activeAction == nil && !actions.isEmpty {
                let selectedAction = actions[selectedIndex]
                
                // Only allow argument mode if supported
                guard selectedAction.supportsArguments else { return false }
                
                // Save state
                previousSearchText = inputField.stringValue
                activeAction = selectedAction
                
                // Switch to Argument Mode
                inputField.stringValue = ""
                inputField.placeholderString = selectedAction.title
                if let icon = selectedAction.icon {
                    setIcons([icon])
                }
                
                // Clear list
                actions = []
                updateActions()
                return true
            }
            return false

        case #selector(NSResponder.insertNewline(_:)):
            if let action = activeAction {
                 if let handler = action.handler {
                     handler(inputField.stringValue)
                     // Restore state after submit
                     activeAction = nil
                     inputField.stringValue = previousSearchText
                     inputField.placeholderString = "nerw"
                     setIcons([])
                     search(query: previousSearchText)
                 } else {
                     // Execute Action with Argument (Default legacy behavior)
                     delegate?.didSubmit(text: "\(action.title) \(inputField.stringValue)")
                     
                     // Restore state after submit
                     activeAction = nil
                     inputField.stringValue = previousSearchText
                     inputField.placeholderString = "nerw"
                     setIcons([])
                     search(query: previousSearchText)
                 }
            } else if !actions.isEmpty {
                let selectedAction = actions[selectedIndex]
                if let appPath = selectedAction.path {
                     // Launch Application
                     NSWorkspace.shared.open(URL(fileURLWithPath: appPath))
                     // Hide window
                     delegate?.didPressEscape()
                } else {
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
            return false
        }
    }

    // MARK: - Search

    private func search(query: String) {
        // If in Argument Mode, query is the argument. (For now, we just let the user type)
        if activeAction != nil {
            return
        }

        guard !query.isEmpty else {
            actions = []
            updateActions()
            return
        }
        
        var newActions: [Action] = []
        
        // 0. Built-in Extensions (Google, etc.)
        if let google = GoogleSearch.shared.check(query: query) {
            newActions.append(Action(
                icon: NSImage(systemSymbolName: google.iconName, accessibilityDescription: nil),
                title: google.title,
                subtitle: google.subtitle,
                supportsArguments: google.supportsArguments,
                handler: google.handler
            ))
        }

        // 1. Check for Extension Triggers
        let components = query.split(separator: " ", maxSplits: 1)
        if let firstWord = components.first,
           let extensionManifest = ExtensionEngine.shared.extensions.first(where: { $0.trigger == String(firstWord) }) {
             
             let arg = components.count > 1 ? String(components[1]) : ""
             
             // Run Extension
              ExtensionEngine.shared.runExtension(id: extensionManifest.id, query: arg) { [weak self] extResults in
                  DispatchQueue.main.async {
                      let extActions = extResults.map { res in
                          var image: NSImage?
                          if let iconName = res.icon {
                              image = NSImage(systemSymbolName: iconName, accessibilityDescription: nil)
                          }
                          if image == nil {
                              image = NSImage(systemSymbolName: "puzzlepiece.extension", accessibilityDescription: nil)
                          }
                          
                          return Action(
                             icon: image,
                             title: res.title, 
                             subtitle: res.subtitle ?? extensionManifest.name,
                             supportsArguments: true, // Extensions usually support args
                             path: nil
                          )
                      }
                      
                      // Combine existing actions (Google) with extension results
                      self?.actions = newActions + extActions
                      self?.updateActions()
                  }
              }
             return
        }
        
        // 2. Default App Search (Fallback)
        // If extension matched, we return above. If not, continue here.
        
        let allApps = AppSearch.shared.getAllApps()
        
        // Ifrit (Fuse) Fuzzy Search on App Names
        let fuse = Fuse()
        // Improve performance by only searching names
        let appNames = allApps.map { $0.name }
        
        let searchResults = fuse.searchSync(query, in: appNames)
        
        // Map back to Action
        let appActions = searchResults.map { result in
            let app = allApps[result.index]
            return Action(
                icon: NSWorkspace.shared.icon(forFile: app.path), // Lazy load icon here
                title: app.name,
                subtitle: "Application",
                supportsArguments: false,
                path: app.path
            )
        }
        
        // Combine Built-in (Google) + App Results
        self.actions = newActions + appActions

        selectedIndex = 0
        updateActions()
    }

    private func updateActions() {
        let hasActions = !actions.isEmpty
        separatorView.isHidden = !hasActions
        scrollView.isHidden = !hasActions
        scrollView.hasVerticalScroller = actions.count > LayoutMetrics.Results.maxVisibleRows
        
        // Update bottom constraint dynamically
        scrollViewBottomConstraint.constant = hasActions ? -LayoutMetrics.Results.expandedBottom : -LayoutMetrics.Results.bottom
        
        resultsTableView.reloadData()

        if hasActions {
            resultsTableView.selectRowIndexes(
                IndexSet(integer: selectedIndex), byExtendingSelection: false)
        }

        delegate?.didUpdateResults(count: actions.count)
    }

    private func moveSelection(by delta: Int) {
        guard !actions.isEmpty else { return }
        selectedIndex = (selectedIndex + delta + actions.count) % actions.count
        resultsTableView.selectRowIndexes(
            IndexSet(integer: selectedIndex), byExtendingSelection: false)
        resultsTableView.scrollRowToVisible(selectedIndex)
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
        cell.configure(with: action, isSelected: row == selectedIndex)
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
