import Cocoa
import NerwCore

public protocol HubSelectableRowView: AnyObject {
    var isRowSelected: Bool { get set }
    func setSelected(_ selected: Bool, animated: Bool)
}

public protocol BaseHubTabProtocol: AnyObject {
    var currentSelectedIndex: Int? { get }
    var totalItemCount: Int { get }
    func selectNext()
    func selectPrevious()
    func selectItem(at index: Int)
    func deselectAll()
    func performPrimaryActionOnSelected()
    func performEditActionOnSelected()
    func performDeleteActionOnSelected()
    func refreshData()
    func filter(with query: String)
}

open class BaseHubListTab<Item>: NSViewController, BaseHubTabProtocol {
    public let scrollView = NSScrollView()
    public let stackView = NSStackView()

    open var tabTitle: String { "" }

    public var selectedIndex: Int? = nil
    public var onCountChanged: ((Int) -> Void)?
    public var currentQuery: String = ""

    public var currentSelectedIndex: Int? {
        return selectedIndex
    }

    public var totalItemCount: Int {
        return items.count
    }

    public var selectedItem: Item? {
        guard let idx = selectedIndex, items.indices.contains(idx) else { return nil }
        return items[idx]
    }

    public var items: [Item] = [] {
        didSet {
            reloadData()
        }
    }

    open override func loadView() {
        view = NSView()
        view.wantsLayer = true
        setupUI()
    }

    private func setupUI() {
        // Scroll view for the list
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        view.addSubview(scrollView)

        // Stack view for expandable items
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 8
        stackView.edgeInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)

        let documentView = HubListFlippedView()
        documentView.translatesAutoresizingMaskIntoConstraints = false
        documentView.addSubview(stackView)
        scrollView.documentView = documentView

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor, constant: 14),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -14),

            documentView.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            documentView.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            documentView.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
            documentView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),

            stackView.topAnchor.constraint(equalTo: documentView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: documentView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: documentView.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: documentView.bottomAnchor),
            stackView.widthAnchor.constraint(equalTo: documentView.widthAnchor),
        ])
    }

    open override func viewDidLoad() {
        super.viewDidLoad()
        loadData()

        NotificationCenter.default.addObserver(
            forName: Notification.Name("NerwHubDataDidUpdate"), object: nil, queue: .main
        ) { [weak self] _ in
            self?.loadData()
        }
    }

    open func loadData() {
        // Subclasses should override this to populate `items`
    }

    open func createRowView(for item: Item) -> NSView {
        fatalError("Subclasses must override createRowView(for:)")
    }

    open func filter(with query: String) {
        currentQuery = query
    }

    public func reloadData() {
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        if let current = selectedIndex, !items.isEmpty {
            selectedIndex = max(0, min(current, items.count - 1))
        } else {
            selectedIndex = nil
        }

        for (idx, item) in items.enumerated() {
            let row = createRowView(for: item)
            stackView.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true

            if let selectable = row as? HubSelectableRowView {
                let isSelected = (selectedIndex != nil && idx == selectedIndex)
                selectable.setSelected(isSelected, animated: false)
            }
        }

        onCountChanged?(items.count)
    }

    public func selectItem(at index: Int) {
        guard !items.isEmpty else {
            selectedIndex = nil
            updateSelectionStates(animated: true)
            return
        }
        let clamped = max(0, min(index, items.count - 1))
        selectedIndex = clamped
        updateSelectionStates(animated: true)
        scrollToSelectedRow()
    }

    public func deselectAll() {
        guard selectedIndex != nil else { return }
        selectedIndex = nil
        updateSelectionStates(animated: true)
    }

    public func selectNext() {
        guard !items.isEmpty else { return }
        if let current = selectedIndex {
            selectItem(at: current + 1)
        } else {
            selectItem(at: 0)
        }
    }

    public func selectPrevious() {
        guard !items.isEmpty else { return }
        if let current = selectedIndex {
            selectItem(at: current - 1)
        } else {
            selectItem(at: items.count - 1)
        }
    }

    public func updateSelectionStates(animated: Bool) {
        for (idx, subview) in stackView.arrangedSubviews.enumerated() {
            if let row = subview as? HubSelectableRowView {
                let isSelected = (selectedIndex != nil && idx == selectedIndex)
                row.setSelected(isSelected, animated: animated)
            }
        }
    }

    public func scrollToSelectedRow() {
        guard let idx = selectedIndex, stackView.arrangedSubviews.indices.contains(idx) else {
            return
        }
        let row = stackView.arrangedSubviews[idx]
        row.scrollToVisible(row.bounds)
    }

    open func performPrimaryActionOnSelected() {}
    open func performEditActionOnSelected() {}
    open func performDeleteActionOnSelected() {}

    public func refreshData() {
        loadData()
    }
}

class HubListFlippedView: NSView {
    override var isFlipped: Bool { true }
}
