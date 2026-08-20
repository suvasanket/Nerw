import Cocoa
import NerwAction
import NerwBuiltin
import NerwCore

class MemoryTab: BaseHubListTab<MemoryEntry> {
    private var allEntries: [MemoryEntry] = []

    override func loadData() {
        allEntries = AIMemoryManager.shared.entries.sorted(by: { $0.timestamp > $1.timestamp })
        self.items = allEntries
    }

    override func createRowView(for item: MemoryEntry) -> NSView {
        return MemoryExpandableRowView(entry: item)
    }

    // Removed setupUI and filterAndDisplay as they are handled by BaseHubListTab
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
        layer?.cornerRadius = 12
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
