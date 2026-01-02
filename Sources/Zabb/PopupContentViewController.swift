// PopupContentViewController.swift
import Cocoa

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
        static let windowWidth: CGFloat = 650 // Total width of the popup window
        static let baseHeight: CGFloat = 10   // Height of the window when no results are shown (Top + Search + Bottom)
        static let cornerRadius: CGFloat = 16 // Corner radius for the main popup window

        struct Icon {
            static let size: CGFloat = 24            // Width and height of search icons
            static let spacing: CGFloat = 8           // Spacing between multiple icons in the stack
            static let containerHeight: CGFloat = 32  // Height of the container holding the icons
            static let leading: CGFloat = 20          // Left padding from window edge to icons
        }

        struct SearchInput {
            static let fontSize: CGFloat = 22  // Text size for the search input field
            static let height: CGFloat = 32    // Height of the search input field
            static let top: CGFloat = 16       // Top padding from window edge to search input
            static let leading: CGFloat = 16   // Spacing between the icon container and search input
            static let trailing: CGFloat = 20  // Right padding from search input to window edge
        }

        struct Separator {
            static let horizontalPadding: CGFloat = 20 // Side padding for the horizontal line
            static let topPadding: CGFloat = 16        // Spacing between search input bottom and separator
            static let height: CGFloat = 2             // Thickness of the separator line
        }

        struct Results {
            static let rowHeight: CGFloat = 50      // Height of each individual result row
            static let bottomPadding: CGFloat = 16  // Padding at the very bottom when results are shown
            static let maxVisibleRows: Int = 5      // Maximum number of rows to show before scrolling
        }

        struct Cell {
            static let cornerRadius: CGFloat = 8     // Corner radius for the selection highlight bubble
            static let verticalMargin: CGFloat = 2   // Vertical spacing between selection highlight and row edge
            static let horizontalMargin: CGFloat = 20 // Horizontal padding for the selection highlight bubble

            static let iconSize: CGFloat = 28    // Size of the icon within a result cell
            static let iconLeading: CGFloat = 10 // Left padding inside the selection highlight to the icon
            static let iconSpacing: CGFloat = 6  // Space between icon and the title/subtitle text

            static let titleTop: CGFloat = 6           // Top padding inside the cell to the title text
            static let subtitleTop: CGFloat = 1        // Spacing between title bottom and subtitle top
            static let titleFontSize: CGFloat = 14     // Font size for the result title
            static let subtitleFontSize: CGFloat = 11  // Font size for the result subtitle
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

    private var isDebugMode = false

    private var results: [SearchResult] = []
    private var selectedIndex: Int = 0

    struct SearchResult {
        let icon: NSImage?
        let title: String
        let subtitle: String
    }

    override func loadView() {
        view = NSView(
            frame: NSRect(
                x: 0, y: 0, width: LayoutMetrics.windowWidth, height: LayoutMetrics.baseHeight))
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
        backgroundView.layer?.cornerRadius = LayoutMetrics.cornerRadius
        backgroundView.layer?.masksToBounds = true
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(backgroundView)

        // Icon Container
        iconContainer = NSStackView()
        iconContainer.orientation = .horizontal
        iconContainer.spacing = LayoutMetrics.Icon.spacing
        iconContainer.alignment = .centerY
        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.addSubview(iconContainer)

        // Default Search Icon
        defaultSearchIcon = NSImageView()
        defaultSearchIcon.image = NSImage(
            systemSymbolName: "magnifyingglass", accessibilityDescription: nil)
        defaultSearchIcon.contentTintColor = .secondaryLabelColor
        defaultSearchIcon.translatesAutoresizingMaskIntoConstraints = false
        defaultSearchIcon.widthAnchor.constraint(equalToConstant: LayoutMetrics.Icon.size)
            .isActive = true
        defaultSearchIcon.heightAnchor.constraint(equalToConstant: LayoutMetrics.Icon.size)
            .isActive = true
        iconContainer.addArrangedSubview(defaultSearchIcon)

        // Input field
        inputField = NSTextField()
        inputField.placeholderString = "Search or type a command..."
        inputField.font = .systemFont(ofSize: LayoutMetrics.SearchInput.fontSize, weight: .light)
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
        // Calculate available width for the column
        let columnWidth =
            LayoutMetrics.windowWidth - (LayoutMetrics.Separator.horizontalPadding * 2)
        column.width = columnWidth
        resultsTableView.addTableColumn(column)

        scrollView = NSScrollView()
        scrollView.documentView = resultsTableView
        scrollView.hasVerticalScroller = false
        scrollView.drawsBackground = false
        scrollView.isHidden = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.addSubview(scrollView)

        // Constraints
        NSLayoutConstraint.activate([
            backgroundView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            iconContainer.leadingAnchor.constraint(
                equalTo: backgroundView.leadingAnchor, constant: LayoutMetrics.Icon.leading),
            iconContainer.centerYAnchor.constraint(equalTo: inputField.centerYAnchor),
            iconContainer.heightAnchor.constraint(
                equalToConstant: LayoutMetrics.Icon.containerHeight),

            inputField.topAnchor.constraint(
                equalTo: backgroundView.topAnchor, constant: LayoutMetrics.SearchInput.top),
            inputField.leadingAnchor.constraint(
                equalTo: iconContainer.trailingAnchor, constant: LayoutMetrics.SearchInput.leading),
            inputField.trailingAnchor.constraint(
                equalTo: backgroundView.trailingAnchor,
                constant: -LayoutMetrics.SearchInput.trailing),
            inputField.heightAnchor.constraint(equalToConstant: LayoutMetrics.SearchInput.height),

            separatorView.topAnchor.constraint(
                equalTo: inputField.bottomAnchor, constant: LayoutMetrics.Separator.topPadding),
            separatorView.leadingAnchor.constraint(
                equalTo: backgroundView.leadingAnchor,
                constant: LayoutMetrics.Separator.horizontalPadding),
            separatorView.trailingAnchor.constraint(
                equalTo: backgroundView.trailingAnchor,
                constant: -LayoutMetrics.Separator.horizontalPadding),

            scrollView.topAnchor.constraint(equalTo: separatorView.bottomAnchor, constant: 0),
            scrollView.leadingAnchor.constraint(equalTo: backgroundView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: backgroundView.trailingAnchor),
            scrollView.bottomAnchor.constraint(
                equalTo: backgroundView.bottomAnchor, constant: -LayoutMetrics.Results.bottomPadding
            ),
        ])
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
                iv.widthAnchor.constraint(equalToConstant: LayoutMetrics.Icon.size).isActive = true
                iv.heightAnchor.constraint(equalToConstant: LayoutMetrics.Icon.size).isActive = true
                iconContainer.addArrangedSubview(iv)
            }
        }
    }

    func reset() {
        inputField.stringValue = ""
        setIcons([])
        results = []
        selectedIndex = 0
        updateResults()
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
            delegate?.didPressEscape()
            return true

        case #selector(NSResponder.insertNewline(_:)):
            if !results.isEmpty {
                delegate?.didSubmit(text: results[selectedIndex].title)
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
        guard !query.isEmpty else {
            results = []
            updateResults()
            return
        }

        // Demo results - replace with actual search
        results = [
            SearchResult(
                icon: NSImage(systemSymbolName: "safari.fill", accessibilityDescription: nil),
                title: "Safari", subtitle: "Application"),
            SearchResult(
                icon: NSImage(systemSymbolName: "terminal.fill", accessibilityDescription: nil),
                title: "Terminal", subtitle: "Application"),
            SearchResult(
                icon: NSImage(systemSymbolName: "gear", accessibilityDescription: nil),
                title: "System Settings", subtitle: "Application"),
            SearchResult(
                icon: NSImage(systemSymbolName: "music.note", accessibilityDescription: nil),
                title: "Music", subtitle: "Application"),
            SearchResult(
                icon: NSImage(systemSymbolName: "envelope.fill", accessibilityDescription: nil),
                title: "Mail", subtitle: "Application"),
            SearchResult(
                icon: NSImage(systemSymbolName: "calendar", accessibilityDescription: nil),
                title: "Calendar", subtitle: "Application"),
            SearchResult(
                icon: NSImage(systemSymbolName: "note.text", accessibilityDescription: nil),
                title: "Notes", subtitle: "Application"),
            SearchResult(
                icon: NSImage(systemSymbolName: "message.fill", accessibilityDescription: nil),
                title: "Messages", subtitle: "Application"),
            SearchResult(
                icon: NSImage(systemSymbolName: "doc.fill", accessibilityDescription: nil),
                title: "Project Proposal.pdf", subtitle: "~/Documents/Work"),
            SearchResult(
                icon: NSImage(systemSymbolName: "photo.fill", accessibilityDescription: nil),
                title: "Vacation.jpg", subtitle: "~/Pictures"),
            SearchResult(
                icon: NSImage(systemSymbolName: "folder.fill", accessibilityDescription: nil),
                title: "Developer", subtitle: "~/Developer"),
            SearchResult(
                icon: NSImage(systemSymbolName: "swift", accessibilityDescription: nil),
                title: "Zabb Source", subtitle: "~/Developer/Zabb"),
        ].filter { $0.title.localizedCaseInsensitiveContains(query) }

        selectedIndex = 0
        updateResults()
    }

    private func updateResults() {
        let hasResults = !results.isEmpty
        separatorView.isHidden = !hasResults
        scrollView.isHidden = !hasResults
        scrollView.hasVerticalScroller = results.count > LayoutMetrics.Results.maxVisibleRows
        resultsTableView.reloadData()

        if hasResults {
            resultsTableView.selectRowIndexes(
                IndexSet(integer: selectedIndex), byExtendingSelection: false)
        }

        delegate?.didUpdateResults(count: results.count)
    }

    private func moveSelection(by delta: Int) {
        guard !results.isEmpty else { return }
        selectedIndex = (selectedIndex + delta + results.count) % results.count
        resultsTableView.selectRowIndexes(
            IndexSet(integer: selectedIndex), byExtendingSelection: false)
        resultsTableView.scrollRowToVisible(selectedIndex)
    }

    // MARK: - NSTableViewDataSource

    func numberOfRows(in tableView: NSTableView) -> Int {
        results.count
    }

    // MARK: - NSTableViewDelegate

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int)
        -> NSView?
    {
        let result = results[row]
        let cell = ResultCellView()
        cell.configure(with: result, isSelected: row == selectedIndex)
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
