import Cocoa
import NerwBuiltin
import NerwCore

class BookmarksTab: BaseHubListTab<Bookmark> {
    override func loadData() {
        self.items = BookmarkManager.shared.bookmarks.sorted(by: { $0.createdAt > $1.createdAt })
    }

    override func createRowView(for item: Bookmark) -> NSView {
        return BookmarkRowView(bookmark: item, delegate: self)
    }

    func deleteBookmark(_ bookmark: Bookmark) {
        BookmarkManager.shared.deleteBookmark(id: bookmark.id)
        loadData()
    }
}

class BookmarkRowView: NSView {
    private let bookmark: Bookmark
    private weak var delegate: BookmarksTab?

    init(bookmark: Bookmark, delegate: BookmarksTab?) {
        self.bookmark = bookmark
        self.delegate = delegate
        super.init(frame: .zero)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        wantsLayer = true
        layer?.cornerRadius = 12
        layer?.backgroundColor = NSColor.white.withAlphaComponent(0.05).cgColor

        let height: CGFloat = 50

        let iconView = NSImageView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        if let path = bookmark.faviconPath, FileManager.default.fileExists(atPath: path),
            let image = NSImage(contentsOfFile: path)
        {
            iconView.image = image
        } else {
            var symbol = "bookmark.circle.fill"
            if let firstChar = bookmark.title.first(where: { $0.isLetter || $0.isNumber }) {
                symbol = "\(firstChar.lowercased()).circle.fill"
            }
            iconView.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
            iconView.contentTintColor = .white
        }
        addSubview(iconView)

        let titleLabel = NSTextField(labelWithString: bookmark.title)
        titleLabel.font = .systemFont(ofSize: 15, weight: .medium)
        titleLabel.textColor = .labelColor
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        let urlLabel = NSTextField(labelWithString: bookmark.url)
        urlLabel.font = .systemFont(ofSize: 12)
        urlLabel.textColor = .secondaryLabelColor
        urlLabel.lineBreakMode = .byTruncatingTail
        urlLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(urlLabel)

        let deleteButton = NSButton(title: "", target: self, action: #selector(deleteClicked))
        deleteButton.image = NSImage(systemSymbolName: "trash", accessibilityDescription: "Delete")
        deleteButton.isBordered = false
        deleteButton.translatesAutoresizingMaskIntoConstraints = false
        deleteButton.contentTintColor = .systemRed
        addSubview(deleteButton)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: height),

            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),

            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(
                equalTo: deleteButton.leadingAnchor, constant: -12),

            urlLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            urlLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            urlLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),

            deleteButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            deleteButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            deleteButton.widthAnchor.constraint(equalToConstant: 24),
            deleteButton.heightAnchor.constraint(equalToConstant: 24),
        ])

        let clickGesture = NSClickGestureRecognizer(target: self, action: #selector(rowClicked))
        addGestureRecognizer(clickGesture)

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

    @objc private func rowClicked() {
        if let url = URL(string: bookmark.url) {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func deleteClicked() {
        delegate?.deleteBookmark(bookmark)
    }
}
