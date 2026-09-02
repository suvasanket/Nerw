import Cocoa
import NerwCore

protocol NerwHubTopBarDelegate: AnyObject {
    func topBarSearchQueryDidChange(_ query: String)
    func topBarDidClickCommandPalette()
}

class NerwHubTopBarView: NSView, NSSearchFieldDelegate {
    weak var delegate: NerwHubTopBarDelegate?

    private let pathIconView = NSImageView()
    private let pathLabel = NSTextField(labelWithString: "")
    let searchField: NSSearchField = {
        let field = NSSearchField()
        (field.cell as? NSSearchFieldCell)?.searchButtonCell = nil
        (field.cell as? NSSearchFieldCell)?.cancelButtonCell = nil
        return field
    }()
    private let searchContainer = NSView()
    private let commandPaletteButton = NSButton()
    private let bottomBorder = NSView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        wantsLayer = true
        translatesAutoresizingMaskIntoConstraints = false

        // Breadcrumb Icon & Label
        pathIconView.translatesAutoresizingMaskIntoConstraints = false
        pathIconView.imageScaling = .scaleProportionallyDown
        pathIconView.contentTintColor = NSColor.controlAccentColor
        addSubview(pathIconView)

        pathLabel.translatesAutoresizingMaskIntoConstraints = false
        pathLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        pathLabel.textColor = .labelColor
        pathLabel.isEditable = false
        pathLabel.isSelectable = false
        pathLabel.drawsBackground = false
        pathLabel.isBezeled = false
        addSubview(pathLabel)

        // Command palette button on the far right
        commandPaletteButton.translatesAutoresizingMaskIntoConstraints = false
        commandPaletteButton.bezelStyle = .regularSquare
        commandPaletteButton.isBordered = false
        commandPaletteButton.wantsLayer = true
        commandPaletteButton.layer?.cornerRadius = 6
        commandPaletteButton.toolTip = "Command Palette (⌘K)"
        commandPaletteButton.target = self
        commandPaletteButton.action = #selector(commandPaletteClicked)

        let cmdConfig = NSImage.SymbolConfiguration(pointSize: 13, weight: .medium)
        commandPaletteButton.image = NSImage(
            systemSymbolName: "command", accessibilityDescription: "Command Palette"
        )?.withSymbolConfiguration(cmdConfig)
        commandPaletteButton.contentTintColor = .secondaryLabelColor
        addSubview(commandPaletteButton)

        // Search container pill
        searchContainer.translatesAutoresizingMaskIntoConstraints = false
        searchContainer.wantsLayer = true
        searchContainer.layer?.cornerRadius = 14
        searchContainer.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.06).cgColor
        searchContainer.layer?.borderColor = NSColor.white.withAlphaComponent(0.12).cgColor
        searchContainer.layer?.borderWidth = 1.0
        addSubview(searchContainer)

        let searchIcon = NSImageView()
        searchIcon.translatesAutoresizingMaskIntoConstraints = false
        let iconConfig = NSImage.SymbolConfiguration(pointSize: 11, weight: .regular)
        searchIcon.image = NSImage(
            systemSymbolName: "magnifyingglass", accessibilityDescription: nil
        )?.withSymbolConfiguration(iconConfig)
        searchIcon.contentTintColor = .tertiaryLabelColor
        searchContainer.addSubview(searchIcon)

        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.focusRingType = .none
        searchField.isBordered = false
        searchField.drawsBackground = false
        searchField.font = .systemFont(ofSize: 12)
        searchField.placeholderString = "Search..."
        searchField.delegate = self
        searchContainer.addSubview(searchField)

        // Bottom separator
        bottomBorder.translatesAutoresizingMaskIntoConstraints = false
        bottomBorder.wantsLayer = true
        bottomBorder.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.08).cgColor
        addSubview(bottomBorder)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 48),

            pathIconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            pathIconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            pathIconView.widthAnchor.constraint(equalToConstant: 16),
            pathIconView.heightAnchor.constraint(equalToConstant: 16),

            pathLabel.leadingAnchor.constraint(equalTo: pathIconView.trailingAnchor, constant: 8),
            pathLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            commandPaletteButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            commandPaletteButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            commandPaletteButton.widthAnchor.constraint(equalToConstant: 28),
            commandPaletteButton.heightAnchor.constraint(equalToConstant: 28),

            searchContainer.trailingAnchor.constraint(
                equalTo: commandPaletteButton.leadingAnchor, constant: -10),
            searchContainer.centerYAnchor.constraint(equalTo: centerYAnchor),
            searchContainer.widthAnchor.constraint(equalToConstant: 210),
            searchContainer.heightAnchor.constraint(equalToConstant: 28),

            searchIcon.leadingAnchor.constraint(
                equalTo: searchContainer.leadingAnchor, constant: 9),
            searchIcon.centerYAnchor.constraint(equalTo: searchContainer.centerYAnchor),
            searchIcon.widthAnchor.constraint(equalToConstant: 12),
            searchIcon.heightAnchor.constraint(equalToConstant: 12),

            searchField.leadingAnchor.constraint(equalTo: searchIcon.trailingAnchor, constant: 6),
            searchField.trailingAnchor.constraint(
                equalTo: searchContainer.trailingAnchor, constant: -8),
            searchField.centerYAnchor.constraint(equalTo: searchContainer.centerYAnchor),

            bottomBorder.leadingAnchor.constraint(equalTo: leadingAnchor),
            bottomBorder.trailingAnchor.constraint(equalTo: trailingAnchor),
            bottomBorder.bottomAnchor.constraint(equalTo: bottomAnchor),
            bottomBorder.heightAnchor.constraint(equalToConstant: 1),
        ])
    }

    func updateTab(_ tab: NerwHubTab) {
        let baseImage = NSImage(
            systemSymbolName: tab.iconName, accessibilityDescription: tab.rawValue)
        if #available(macOS 12.0, *) {
            let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
            pathIconView.image = baseImage?.withSymbolConfiguration(config)
        } else {
            pathIconView.image = baseImage
        }
        pathLabel.stringValue = "NerwHub  ›  \(tab.rawValue)"
        searchField.placeholderString = "Search \(tab.rawValue)..."
    }

    func clearSearch() {
        searchField.stringValue = ""
        delegate?.topBarSearchQueryDidChange("")
    }

    func focusSearchField() {
        window?.makeFirstResponder(searchField)
    }

    @objc private func commandPaletteClicked() {
        delegate?.topBarDidClickCommandPalette()
    }

    // MARK: - NSSearchFieldDelegate

    func controlTextDidChange(_ obj: Notification) {
        let query = searchField.stringValue
        delegate?.topBarSearchQueryDidChange(query)
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector)
        -> Bool
    {
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            if !searchField.stringValue.isEmpty {
                clearSearch()
                return true
            }
        }
        return false
    }
}
