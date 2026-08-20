import Cocoa
import NerwCore

open class BaseHubListTab<Item>: NSViewController {
    public let scrollView = NSScrollView()
    public let stackView = NSStackView()

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
    }

    open func loadData() {
        // Subclasses should override this to populate `items`
    }

    open func createRowView(for item: Item) -> NSView {
        fatalError("Subclasses must override createRowView(for:)")
    }

    public func reloadData() {
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        for item in items {
            let row = createRowView(for: item)
            stackView.addArrangedSubview(row)
            row.widthAnchor.constraint(
                equalTo: stackView.widthAnchor,
                constant: -(stackView.edgeInsets.left + stackView.edgeInsets.right)
            ).isActive = true
        }
    }
}

class HubListFlippedView: NSView {
    override var isFlipped: Bool { true }
}
