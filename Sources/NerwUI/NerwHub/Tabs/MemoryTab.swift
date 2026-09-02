import Cocoa
import NerwAction
import NerwBuiltin
import NerwCore

private let sharedMemoryDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .short
    return formatter
}()

class MemoryTab: BaseHubListTab<MemoryEntry> {
    override var tabTitle: String { "Memory" }

    private var allEntries: [MemoryEntry] = []

    override func loadData() {
        allEntries = AIMemoryManager.shared.entries.sorted(by: { $0.timestamp > $1.timestamp })
        applyFilter()
    }

    override func filter(with query: String) {
        super.filter(with: query)
        applyFilter()
    }

    private func applyFilter() {
        let q = currentQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if q.isEmpty {
            self.items = allEntries
        } else {
            self.items = allEntries.filter {
                $0.title.lowercased().contains(q) || $0.content.lowercased().contains(q)
                    || $0.category.lowercased().contains(q)
                    || $0.type.rawValue.lowercased().contains(q)
            }
        }
    }

    override func createRowView(for item: MemoryEntry) -> NSView {
        return MemoryExpandableRowView(entry: item, delegate: self)
    }

    func didClickRow(_ rowView: MemoryExpandableRowView) {
        if let index = stackView.arrangedSubviews.firstIndex(of: rowView) {
            selectItem(at: index)
        }
    }

    func editMemory(_ entry: MemoryEntry) {
        var responder: NSResponder? = self.view
        var hubVC: NerwHubViewController?
        while responder != nil {
            if let vc = responder as? NerwHubViewController {
                hubVC = vc
                break
            }
            responder = responder?.nextResponder
        }

        hubVC?.showFloatingInput(
            title: "Edit Memory", subtitle: entry.title, initialText: entry.content
        ) { newText in
            AIMemoryManager.shared.updateMemory(id: entry.id, newContent: newText)
        }
    }

    func deleteMemory(_ entry: MemoryEntry) {
        AIMemoryManager.shared.deleteMemory(id: entry.id)
    }

    override func performPrimaryActionOnSelected() {
        guard let idx = selectedIndex,
            stackView.arrangedSubviews.indices.contains(idx),
            let rowView = stackView.arrangedSubviews[idx] as? MemoryExpandableRowView
        else { return }
        rowView.toggleExpansion()
    }

    override func performEditActionOnSelected() {
        guard let entry = selectedItem else { return }
        editMemory(entry)
    }

    override func performDeleteActionOnSelected() {
        guard let entry = selectedItem else { return }
        deleteMemory(entry)
    }
}

class MemoryExpandableRowView: NSView, HubSelectableRowView {
    let entry: MemoryEntry
    private weak var delegate: MemoryTab?
    var isRowSelected: Bool = false
    private var isExpanded = true

    private let headerView = NSView()
    private let detailStack = NSStackView()
    private var heightConstraint: NSLayoutConstraint!

    init(entry: MemoryEntry, delegate: MemoryTab?) {
        self.entry = entry
        self.delegate = delegate
        super.init(frame: .zero)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.borderWidth = 1.0
        layer?.borderColor = NSColor.white.withAlphaComponent(0.08).cgColor
        layer?.backgroundColor = NSColor.white.withAlphaComponent(0.05).cgColor

        let dateString = sharedMemoryDateFormatter.string(from: entry.timestamp)

        let leftVStack = NSStackView()
        leftVStack.translatesAutoresizingMaskIntoConstraints = false
        leftVStack.orientation = .vertical
        leftVStack.alignment = .leading
        leftVStack.spacing = 0
        addSubview(leftVStack)

        // Header View
        headerView.translatesAutoresizingMaskIntoConstraints = false
        leftVStack.addArrangedSubview(headerView)

        let titleLabel = NSTextField(labelWithString: entry.title)
        titleLabel.font = .systemFont(ofSize: 14, weight: .medium)
        titleLabel.textColor = .labelColor
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(titleLabel)

        // Detail Stack
        detailStack.translatesAutoresizingMaskIntoConstraints = false
        detailStack.orientation = .vertical
        detailStack.alignment = .leading
        detailStack.spacing = 6
        detailStack.alphaValue = 1.0
        detailStack.isHidden = false
        leftVStack.addArrangedSubview(detailStack)

        let metaLabel = NSTextField(
            labelWithString:
                "[\(entry.type.rawValue.capitalized)] [\(entry.category)] Importance: \(entry.importance)/10 - \(dateString)"
        )
        metaLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        metaLabel.textColor = .secondaryLabelColor
        metaLabel.lineBreakMode = .byTruncatingTail
        detailStack.addArrangedSubview(metaLabel)

        let contentLabel = NSTextField(labelWithString: entry.content)
        contentLabel.font = .systemFont(ofSize: 13)
        contentLabel.textColor = .labelColor
        contentLabel.cell?.isScrollable = false
        contentLabel.cell?.wraps = true
        contentLabel.lineBreakMode = .byWordWrapping
        contentLabel.translatesAutoresizingMaskIntoConstraints = false
        detailStack.addArrangedSubview(contentLabel)

        var trailingConstraint: NSLayoutConstraint?

        if let imagePath = entry.imagePath, let image = NSImage(contentsOfFile: imagePath) {
            let imageView = NSImageView(image: image)
            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageView.imageScaling = .scaleProportionallyUpOrDown

            let imageBox = NSView()
            imageBox.translatesAutoresizingMaskIntoConstraints = false
            imageBox.wantsLayer = true
            imageBox.layer?.cornerRadius = 6
            imageBox.layer?.masksToBounds = true
            imageBox.layer?.borderWidth = 1
            imageBox.layer?.borderColor = NSColor.white.withAlphaComponent(0.1).cgColor

            imageBox.addSubview(imageView)
            addSubview(imageBox)

            NSLayoutConstraint.activate([
                imageBox.widthAnchor.constraint(equalToConstant: 80),
                imageBox.heightAnchor.constraint(equalToConstant: 50),
                imageBox.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
                imageBox.centerYAnchor.constraint(equalTo: centerYAnchor),

                imageView.topAnchor.constraint(equalTo: imageBox.topAnchor),
                imageView.bottomAnchor.constraint(equalTo: imageBox.bottomAnchor),
                imageView.leadingAnchor.constraint(equalTo: imageBox.leadingAnchor),
                imageView.trailingAnchor.constraint(equalTo: imageBox.trailingAnchor),
            ])

            trailingConstraint = leftVStack.trailingAnchor.constraint(
                equalTo: imageBox.leadingAnchor, constant: -16)
        } else {
            trailingConstraint = leftVStack.trailingAnchor.constraint(
                equalTo: trailingAnchor, constant: -14)
        }

        NSLayoutConstraint.activate([
            leftVStack.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            leftVStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            leftVStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            trailingConstraint!,

            headerView.heightAnchor.constraint(equalToConstant: 26),
            headerView.widthAnchor.constraint(equalTo: leftVStack.widthAnchor),

            titleLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),

            detailStack.widthAnchor.constraint(equalTo: leftVStack.widthAnchor),
            metaLabel.widthAnchor.constraint(equalTo: detailStack.widthAnchor),
            contentLabel.widthAnchor.constraint(equalTo: detailStack.widthAnchor),
        ])

        // Setup initial expanded state
        heightConstraint = heightAnchor.constraint(equalToConstant: 38)
        heightConstraint.isActive = false
        isExpanded = true

        // Setup tracking for hover and click
        let trackingArea = NSTrackingArea(
            rect: .zero, options: [.inVisibleRect, .activeAlways, .mouseEnteredAndExited],
            owner: self, userInfo: nil)
        addTrackingArea(trackingArea)
    }

    func setSelected(_ selected: Bool, animated: Bool) {
        isRowSelected = selected
        let accent = NSColor(hexString: "#61AEFF") ?? .controlAccentColor
        let targetBorderColor =
            selected
            ? accent.cgColor
            : NSColor.white.withAlphaComponent(0.08).cgColor
        let targetBorderWidth: CGFloat = selected ? 1.5 : 1.0
        let targetBgColor =
            selected
            ? accent.withAlphaComponent(0.12).cgColor
            : NSColor.white.withAlphaComponent(0.05).cgColor

        if animated {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.12
                self.layer?.borderColor = targetBorderColor
                self.layer?.borderWidth = targetBorderWidth
                self.layer?.backgroundColor = targetBgColor
            }
        } else {
            layer?.borderColor = targetBorderColor
            layer?.borderWidth = targetBorderWidth
            layer?.backgroundColor = targetBgColor
        }
    }

    override func mouseEntered(with event: NSEvent) {
        NSCursor.pointingHand.push()
        if !isRowSelected {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.1
                layer?.backgroundColor = NSColor.white.withAlphaComponent(0.09).cgColor
            }
        }
    }

    override func mouseExited(with event: NSEvent) {
        NSCursor.pop()
        if !isRowSelected {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.1
                layer?.backgroundColor = NSColor.white.withAlphaComponent(0.05).cgColor
            }
        }
    }

    override func mouseDown(with event: NSEvent) {
        delegate?.didClickRow(self)
        toggleExpansion()
    }

    func toggleExpansion() {
        isExpanded.toggle()

        if isExpanded {
            heightConstraint.isActive = false
            detailStack.isHidden = false
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.15
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                detailStack.animator().alphaValue = 1.0
            }
        } else {
            NSAnimationContext.runAnimationGroup(
                { ctx in
                    ctx.duration = 0.12
                    ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
                    detailStack.animator().alphaValue = 0.0
                },
                completionHandler: {
                    self.detailStack.isHidden = true
                    self.heightConstraint.isActive = true
                })
        }
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        delegate?.didClickRow(self)
        let menu = NSMenu()
        let editItem = NSMenuItem(title: "Edit", action: #selector(editMemory), keyEquivalent: "")
        editItem.target = self
        menu.addItem(editItem)

        let deleteItem = NSMenuItem(
            title: "Delete", action: #selector(deleteMemory), keyEquivalent: "")
        deleteItem.target = self
        menu.addItem(deleteItem)

        return menu
    }

    @objc private func editMemory() {
        delegate?.editMemory(entry)
    }

    @objc private func deleteMemory() {
        delegate?.deleteMemory(entry)
    }
}
