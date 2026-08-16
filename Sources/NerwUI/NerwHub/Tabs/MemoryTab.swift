import Cocoa
import NerwAction
import NerwBuiltin
import NerwCore

class MemoryTab: NSViewController, NSTextFieldDelegate {
    private let searchField = ThemedTextField()
    private let searchIconView = NSImageView()
    private let separator = NSBox()

    private let scrollView = NSScrollView()
    private let stackView = NSStackView()

    private var allEntries: [MemoryEntry] = []

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
        setupUI()
        loadData()
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        // Focus search field
        view.window?.makeFirstResponder(searchField)
    }

    private func setupUI() {
        // Search icon
        searchIconView.image = NSImage(
            systemSymbolName: "magnifyingglass", accessibilityDescription: "Search")
        if #available(macOS 12.0, *) {
            searchIconView.symbolConfiguration = NSImage.SymbolConfiguration(
                hierarchicalColor: .secondaryLabelColor)
        } else {
            searchIconView.contentTintColor = .secondaryLabelColor
        }
        searchIconView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(searchIconView)

        // Search field
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.placeholderString = "Search AI Memories..."
        searchField.isBordered = false
        searchField.drawsBackground = false
        searchField.focusRingType = .none
        searchField.font = .systemFont(ofSize: 24, weight: .light)
        searchField.delegate = self
        view.addSubview(searchField)

        // Separator
        separator.boxType = .custom
        separator.borderType = .noBorder
        separator.fillColor = NSColor.white.withAlphaComponent(0.1)
        separator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(separator)

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
        stackView.edgeInsets = NSEdgeInsets(top: 16, left: 24, bottom: 16, right: 24)

        let documentView = FlippedView()
        documentView.translatesAutoresizingMaskIntoConstraints = false
        documentView.addSubview(stackView)
        scrollView.documentView = documentView

        // Layout
        let topMargin: CGFloat = 20
        let horizMargin: CGFloat = 24

        NSLayoutConstraint.activate([
            searchIconView.leadingAnchor.constraint(
                equalTo: view.leadingAnchor, constant: horizMargin),
            searchIconView.centerYAnchor.constraint(equalTo: searchField.centerYAnchor),
            searchIconView.widthAnchor.constraint(equalToConstant: 22),
            searchIconView.heightAnchor.constraint(equalToConstant: 22),

            searchField.topAnchor.constraint(equalTo: view.topAnchor, constant: topMargin),
            searchField.leadingAnchor.constraint(
                equalTo: searchIconView.trailingAnchor, constant: 12),
            searchField.trailingAnchor.constraint(
                equalTo: view.trailingAnchor, constant: -horizMargin),
            searchField.heightAnchor.constraint(equalToConstant: 32),

            separator.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 16),
            separator.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: horizMargin),
            separator.trailingAnchor.constraint(
                equalTo: view.trailingAnchor, constant: -horizMargin),
            separator.heightAnchor.constraint(equalToConstant: 1),

            scrollView.topAnchor.constraint(equalTo: separator.bottomAnchor),
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

    private func loadData() {
        allEntries = AIMemoryManager.shared.entries.sorted(by: { $0.timestamp > $1.timestamp })
        filterAndDisplay(query: "")
    }

    private func filterAndDisplay(query: String) {
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let lowerQuery = query.lowercased()
        let filtered =
            query.isEmpty
            ? allEntries
            : allEntries.filter {
                $0.title.lowercased().contains(lowerQuery)
                    || $0.content.lowercased().contains(lowerQuery)
                    || $0.category.lowercased().contains(lowerQuery)
            }

        for entry in filtered {
            let row = MemoryExpandableRowView(entry: entry)
            stackView.addArrangedSubview(row)
            row.widthAnchor.constraint(
                equalTo: stackView.widthAnchor,
                constant: -(stackView.edgeInsets.left + stackView.edgeInsets.right)
            ).isActive = true
        }
    }

    func controlTextDidChange(_ obj: Notification) {
        if let textField = obj.object as? NSTextField {
            filterAndDisplay(query: textField.stringValue)
        }
    }
}

class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

class MemoryExpandableRowView: NSView {
    private let entry: MemoryEntry
    private var isExpanded = false

    private let headerView = NSView()
    private let detailStack = NSStackView()
    private var heightConstraint: NSLayoutConstraint!

    init(entry: MemoryEntry) {
        self.entry = entry
        super.init(frame: .zero)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.backgroundColor = NSColor.white.withAlphaComponent(0.05).cgColor

        // Header
        headerView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(headerView)

        let titleLabel = NSTextField(labelWithString: entry.title)
        titleLabel.font = .systemFont(ofSize: 15, weight: .medium)
        titleLabel.textColor = .labelColor
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(titleLabel)

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short

        let dateLabel = NSTextField(labelWithString: dateFormatter.string(from: entry.timestamp))
        dateLabel.font = .systemFont(ofSize: 12)
        dateLabel.textColor = .tertiaryLabelColor
        dateLabel.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(dateLabel)

        // Detail Stack
        detailStack.translatesAutoresizingMaskIntoConstraints = false
        detailStack.orientation = .vertical
        detailStack.alignment = .leading
        detailStack.spacing = 8
        detailStack.alphaValue = 0
        detailStack.isHidden = true
        addSubview(detailStack)

        let metaLabel = NSTextField(
            labelWithString:
                "[\(entry.type.rawValue.capitalized)] [\(entry.category)] Importance: \(entry.importance)/10"
        )
        metaLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        metaLabel.textColor = .secondaryLabelColor
        detailStack.addArrangedSubview(metaLabel)

        let contentLabel = NSTextField(labelWithString: entry.content)
        contentLabel.font = .systemFont(ofSize: 14)
        contentLabel.textColor = .labelColor
        contentLabel.cell?.isScrollable = false
        contentLabel.cell?.wraps = true
        contentLabel.translatesAutoresizingMaskIntoConstraints = false
        detailStack.addArrangedSubview(contentLabel)

        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: topAnchor),
            headerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 44),

            titleLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(
                lessThanOrEqualTo: dateLabel.leadingAnchor, constant: -8),

            dateLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            dateLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),

            detailStack.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            detailStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            detailStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            detailStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),
        ])

        // Setup initial collapsed state
        heightConstraint = heightAnchor.constraint(equalToConstant: 44)
        heightConstraint.isActive = true

        // Allow content label to wrap properly
        contentLabel.widthAnchor.constraint(equalTo: detailStack.widthAnchor).isActive = true

        // Setup tracking for hover and click
        let trackingArea = NSTrackingArea(
            rect: .zero, options: [.inVisibleRect, .activeAlways, .mouseEnteredAndExited],
            owner: self, userInfo: nil)
        addTrackingArea(trackingArea)
    }

    override func mouseEntered(with event: NSEvent) {
        NSCursor.pointingHand.push()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            layer?.backgroundColor = NSColor.white.withAlphaComponent(0.1).cgColor
        }
    }

    override func mouseExited(with event: NSEvent) {
        NSCursor.pop()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            layer?.backgroundColor = NSColor.white.withAlphaComponent(0.05).cgColor
        }
    }

    override func mouseDown(with event: NSEvent) {
        isExpanded.toggle()

        if isExpanded {
            heightConstraint.isActive = false
            detailStack.isHidden = false
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.2
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                detailStack.animator().alphaValue = 1.0
            }
        } else {
            NSAnimationContext.runAnimationGroup(
                { ctx in
                    ctx.duration = 0.15
                    ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
                    detailStack.animator().alphaValue = 0.0
                },
                completionHandler: {
                    self.detailStack.isHidden = true
                    self.heightConstraint.isActive = true
                })
        }
    }
}
