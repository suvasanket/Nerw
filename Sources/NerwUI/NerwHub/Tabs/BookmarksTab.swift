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

    func didClickRow(_ rowView: BookmarkRowView) {
        if let index = stackView.arrangedSubviews.firstIndex(of: rowView) {
            selectItem(at: index)
        }
    }

    private func findHubViewController() -> NerwHubViewController? {
        var responder: NSResponder? = self.view
        while responder != nil {
            if let vc = responder as? NerwHubViewController {
                return vc
            }
            responder = responder?.nextResponder
        }
        return nil
    }

    func editBookmarkName(_ bookmark: Bookmark) {
        let hubVC = findHubViewController()
        hubVC?.showFloatingInput(
            title: "Edit Bookmark Name",
            subtitle: bookmark.url,
            initialText: bookmark.title
        ) { newTitle in
            let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                BookmarkManager.shared.updateBookmark(
                    id: bookmark.id, url: bookmark.url, title: trimmed)
            }
        }
    }

    func editBookmarkURL(_ bookmark: Bookmark) {
        let hubVC = findHubViewController()
        hubVC?.showFloatingInput(
            title: "Edit Bookmark URL",
            subtitle: bookmark.title,
            initialText: bookmark.url
        ) { newUrl in
            let trimmed = newUrl.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                BookmarkManager.shared.updateBookmark(
                    id: bookmark.id, url: trimmed, title: bookmark.title)
            }
        }
    }

    func editSelectedName() {
        guard let bookmark = selectedItem else { return }
        editBookmarkName(bookmark)
    }

    func editSelectedURL() {
        guard let bookmark = selectedItem else { return }
        editBookmarkURL(bookmark)
    }

    func deleteBookmark(_ bookmark: Bookmark) {
        BookmarkManager.shared.deleteBookmark(id: bookmark.id)
        loadData()
    }

    override func performPrimaryActionOnSelected() {
        guard let bookmark = selectedItem, let url = URL(string: bookmark.url) else { return }
        NSWorkspace.shared.open(url)
    }

    override func performEditActionOnSelected() {
        editSelectedName()
    }

    override func performDeleteActionOnSelected() {
        guard let bookmark = selectedItem else { return }
        deleteBookmark(bookmark)
    }
}

class BookmarkRowView: NSView, HubSelectableRowView {
    let bookmark: Bookmark
    private weak var delegate: BookmarksTab?
    var isRowSelected: Bool = false

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
        layer?.borderWidth = 1.0
        layer?.borderColor = NSColor.white.withAlphaComponent(0.08).cgColor
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

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: height),

            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),

            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),

            urlLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            urlLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            urlLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
        ])

        let clickGesture = NSClickGestureRecognizer(target: self, action: #selector(rowClicked))
        addGestureRecognizer(clickGesture)

        let trackingArea = NSTrackingArea(
            rect: .zero, options: [.inVisibleRect, .activeAlways, .mouseEnteredAndExited],
            owner: self, userInfo: nil)
        addTrackingArea(trackingArea)
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        delegate?.didClickRow(self)

        let menu = NSMenu()
        let openItem = NSMenuItem(
            title: "Open in Browser", action: #selector(openClicked), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)

        let editNameItem = NSMenuItem(
            title: "Edit Name...", action: #selector(editNameClicked), keyEquivalent: "")
        editNameItem.target = self
        menu.addItem(editNameItem)

        let editURLItem = NSMenuItem(
            title: "Edit URL...", action: #selector(editURLClicked), keyEquivalent: "")
        editURLItem.target = self
        menu.addItem(editURLItem)

        menu.addItem(NSMenuItem.separator())

        let deleteItem = NSMenuItem(
            title: "Delete Bookmark", action: #selector(deleteClicked), keyEquivalent: "")
        deleteItem.target = self
        menu.addItem(deleteItem)

        return menu
    }

    func setSelected(_ selected: Bool, animated: Bool) {
        isRowSelected = selected
        let targetBorderColor =
            selected
            ? NSColor(red: 0.38, green: 0.68, blue: 1.0, alpha: 0.9).cgColor
            : NSColor.white.withAlphaComponent(0.08).cgColor
        let targetBorderWidth: CGFloat = selected ? 1.5 : 1.0
        let targetBgColor =
            selected
            ? NSColor.white.withAlphaComponent(0.09).cgColor
            : NSColor.white.withAlphaComponent(0.05).cgColor

        if animated {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.15
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
                ctx.duration = 0.15
                layer?.backgroundColor = NSColor.white.withAlphaComponent(0.1).cgColor
            }
        }
    }

    override func mouseExited(with event: NSEvent) {
        NSCursor.pop()
        if !isRowSelected {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.15
                layer?.backgroundColor = NSColor.white.withAlphaComponent(0.05).cgColor
            }
        }
    }

    @objc private func rowClicked() {
        delegate?.didClickRow(self)
        if let url = URL(string: bookmark.url) {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func openClicked() {
        rowClicked()
    }

    @objc private func editNameClicked() {
        delegate?.didClickRow(self)
        delegate?.editBookmarkName(bookmark)
    }

    @objc private func editURLClicked() {
        delegate?.didClickRow(self)
        delegate?.editBookmarkURL(bookmark)
    }

    @objc private func deleteClicked() {
        delegate?.deleteBookmark(bookmark)
    }
}
