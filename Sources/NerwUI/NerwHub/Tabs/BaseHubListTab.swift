import Cocoa
import NerwCore

public protocol HubSelectableRowView: AnyObject {
    var isRowSelected: Bool { get set }
    func setSelected(_ selected: Bool, animated: Bool)
}

public protocol BaseHubTabProtocol: AnyObject {
    var currentSelectedIndex: Int { get }
    var totalItemCount: Int { get }
    func selectNext()
    func selectPrevious()
    func selectItem(at index: Int)
    func performPrimaryActionOnSelected()
    func performEditActionOnSelected()
    func performDeleteActionOnSelected()
    func refreshData()
}

open class BaseHubListTab<Item>: NSViewController, BaseHubTabProtocol {
    public let scrollView = NSScrollView()
    public let stackView = NSStackView()

    public var selectedIndex: Int = 0

    public var currentSelectedIndex: Int {
        return selectedIndex
    }

    public var totalItemCount: Int {
        return items.count
    }

    public var selectedItem: Item? {
        guard items.indices.contains(selectedIndex) else { return nil }
        return items[selectedIndex]
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
        stackView.edgeInsets = NSEdgeInsets(top: 48, left: 24, bottom: 16, right: 24)

        let documentView = HubListFlippedView()
        documentView.translatesAutoresizingMaskIntoConstraints = false
        documentView.addSubview(stackView)
        scrollView.documentView = documentView

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            documentView.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            documentView.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            documentView.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),

            stackView.topAnchor.constraint(equalTo: documentView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: documentView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: documentView.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: documentView.bottomAnchor),
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

    public func reloadData() {
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        if items.isEmpty {
            selectedIndex = 0
        } else {
            selectedIndex = max(0, min(selectedIndex, items.count - 1))
        }

        for (idx, item) in items.enumerated() {
            let row = createRowView(for: item)
            stackView.addArrangedSubview(row)
            row.widthAnchor.constraint(
                equalTo: stackView.widthAnchor,
                constant: -(stackView.edgeInsets.left + stackView.edgeInsets.right)
            ).isActive = true

            if let selectable = row as? HubSelectableRowView {
                selectable.setSelected(idx == selectedIndex, animated: false)
            }
        }
    }

    public func selectItem(at index: Int) {
        guard !items.isEmpty else {
            selectedIndex = 0
            return
        }
        let clamped = max(0, min(index, items.count - 1))
        selectedIndex = clamped
        updateSelectionStates(animated: true)
        scrollToSelectedRow()
    }

    public func selectNext() {
        guard !items.isEmpty else { return }
        selectItem(at: selectedIndex + 1)
    }

    public func selectPrevious() {
        guard !items.isEmpty else { return }
        selectItem(at: selectedIndex - 1)
    }

    public func updateSelectionStates(animated: Bool) {
        for (idx, subview) in stackView.arrangedSubviews.enumerated() {
            if let row = subview as? HubSelectableRowView {
                row.setSelected(idx == selectedIndex, animated: animated)
            }
        }
    }

    public func scrollToSelectedRow() {
        guard stackView.arrangedSubviews.indices.contains(selectedIndex) else { return }
        let row = stackView.arrangedSubviews[selectedIndex]
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
