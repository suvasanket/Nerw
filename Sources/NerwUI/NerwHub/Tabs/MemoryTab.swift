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
    private var isExpanded = true

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

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short
        let dateString = dateFormatter.string(from: entry.timestamp)

        let mainHStack = NSStackView()
        mainHStack.translatesAutoresizingMaskIntoConstraints = false
        mainHStack.orientation = .horizontal
        mainHStack.alignment = .centerY
        mainHStack.spacing = 16
        addSubview(mainHStack)

        let leftVStack = NSStackView()
        leftVStack.translatesAutoresizingMaskIntoConstraints = false
        leftVStack.orientation = .vertical
        leftVStack.alignment = .leading
        leftVStack.spacing = 0
        leftVStack.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        mainHStack.addArrangedSubview(leftVStack)

        // Header View
        headerView.translatesAutoresizingMaskIntoConstraints = false
        leftVStack.addArrangedSubview(headerView)

        let titleLabel = NSTextField(labelWithString: entry.title)
        titleLabel.font = .systemFont(ofSize: 15, weight: .medium)
        titleLabel.textColor = .labelColor
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(titleLabel)

        // Detail Stack
        detailStack.translatesAutoresizingMaskIntoConstraints = false
        detailStack.orientation = .vertical
        detailStack.alignment = .leading
        detailStack.spacing = 8
        detailStack.alphaValue = 1.0
        detailStack.isHidden = false
        leftVStack.addArrangedSubview(detailStack)

        let metaLabel = NSTextField(
            labelWithString:
                "[\(entry.type.rawValue.capitalized)] [\(entry.category)] Importance: \(entry.importance)/10 - \(dateString)"
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
        contentLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        detailStack.addArrangedSubview(contentLabel)

        // Ensure leftVStack and detailStack stretch
        leftVStack.widthAnchor.constraint(equalTo: detailStack.widthAnchor).isActive = true
        contentLabel.widthAnchor.constraint(equalTo: detailStack.widthAnchor).isActive = true

        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        mainHStack.addArrangedSubview(spacer)

        if let imagePath = entry.imagePath, let image = NSImage(contentsOfFile: imagePath) {
            let imageView = NSImageView(image: image)
            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageView.imageScaling = .scaleProportionallyUpOrDown

            imageView.widthAnchor.constraint(equalToConstant: 96).isActive = true
            imageView.heightAnchor.constraint(equalToConstant: 60).isActive = true

            let imageBox = NSView()
            imageBox.translatesAutoresizingMaskIntoConstraints = false
            imageBox.wantsLayer = true
            imageBox.layer?.cornerRadius = 6
            imageBox.layer?.masksToBounds = true
            imageBox.layer?.borderWidth = 1
            imageBox.layer?.borderColor = NSColor.white.withAlphaComponent(0.1).cgColor

            imageBox.addSubview(imageView)
            NSLayoutConstraint.activate([
                imageView.topAnchor.constraint(equalTo: imageBox.topAnchor),
                imageView.bottomAnchor.constraint(equalTo: imageBox.bottomAnchor),
                imageView.leadingAnchor.constraint(equalTo: imageBox.leadingAnchor),
                imageView.trailingAnchor.constraint(equalTo: imageBox.trailingAnchor),
            ])

            mainHStack.addArrangedSubview(imageBox)
        }

        NSLayoutConstraint.activate([
            mainHStack.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            mainHStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),
            mainHStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            mainHStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),

            headerView.heightAnchor.constraint(equalToConstant: 32),
            headerView.widthAnchor.constraint(equalTo: leftVStack.widthAnchor),

            titleLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
        ])

        // Setup initial expanded state
        heightConstraint = heightAnchor.constraint(equalToConstant: 44)
        heightConstraint.isActive = false  // Make it expanded by default

        // Initial expanded state property
        isExpanded = true

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

    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = NSMenu()
        let editItem = NSMenuItem(title: "Edit", action: #selector(editMemory), keyEquivalent: "")
        editItem.target = self
        menu.addItem(editItem)
        return menu
    }

    @objc private func editMemory() {
        var responder: NSResponder? = self
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
        ) { [weak self] newText in
            guard let self = self else { return }
            AIMemoryManager.shared.updateMemory(id: self.entry.id, newContent: newText)
        }
    }
}
