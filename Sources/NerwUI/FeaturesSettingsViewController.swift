import Cocoa
import NerwAction
import NerwBuiltin
import NerwCore
import NerwSearchBackend

class CenteredTextFieldCell: NSTextFieldCell {
    override func titleRect(forBounds rect: NSRect) -> NSRect {
        let textHeight: CGFloat = font?.pointSize ?? 13.0
        let editHeight = textHeight + 2
        let deltaY = (rect.height - editHeight) / 2
        return NSRect(
            x: rect.origin.x + 8,
            y: rect.origin.y + deltaY,
            width: rect.width - 16,
            height: editHeight
        )
    }

    override func drawingRect(forBounds rect: NSRect) -> NSRect {
        return titleRect(forBounds: rect)
    }

    override func edit(
        withFrame rect: NSRect, in controlView: NSView, editor textObj: NSText, delegate: Any?,
        event: NSEvent?
    ) {
        let editingRect = titleRect(forBounds: rect)
        super.edit(
            withFrame: editingRect, in: controlView, editor: textObj, delegate: delegate,
            event: event)
    }

    override func select(
        withFrame rect: NSRect, in controlView: NSView, editor textObj: NSText, delegate: Any?,
        start selStart: Int, length selLength: Int
    ) {
        let selectingRect = titleRect(forBounds: rect)
        super.select(
            withFrame: selectingRect, in: controlView, editor: textObj, delegate: delegate,
            start: selStart, length: selLength)
    }
}

class FeaturesSettingsViewController: NSViewController {

    private let scrollView: NSScrollView = {
        let sv = NSScrollView()
        sv.hasVerticalScroller = true
        sv.hasHorizontalScroller = false
        sv.autohidesScrollers = true
        sv.drawsBackground = false
        return sv
    }()

    private let stackView: FlippedStackView = {
        let stack = FlippedStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 24
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        return stack
    }()

    private var bookmarkSwitch: NSSwitch!
    private var clipboardSwitch: NSSwitch!
    private var snippetSwitch: NSSwitch!
    private var clipboardHotkeyRecorder: KeybindRecorder!
    private var onFirstSpaceField: NSTextField!
    private var shortcutsSwitch: NSSwitch!
    private var menubarSearchSwitch: NSSwitch!

    override func loadView() {
        self.view = NSView()
        self.view.wantsLayer = true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()

        NotificationCenter.default.addObserver(
            self, selector: #selector(refreshUI), name: Notification.Name("NerwConfigDidUpdate"),
            object: nil)
    }

    private func setupUI() {
        view.addSubview(scrollView)
        scrollView.documentView = stackView

        // 0. Bookmark Section
        let bookmarkRow = NSStackView()
        bookmarkRow.orientation = .horizontal
        bookmarkRow.spacing = 10
        bookmarkRow.alignment = .centerY

        let bookmarkTextStack = NSStackView()
        bookmarkTextStack.orientation = .vertical
        bookmarkTextStack.spacing = 2
        bookmarkTextStack.alignment = .leading

        let bookmarkLabel = NSTextField(labelWithString: "Enable Bookmarks")
        bookmarkLabel.font = .systemFont(ofSize: 13, weight: .regular)
        let bookmarkSubtitle = NSTextField(
            labelWithString: "Save and search your favorite websites as bookmarks")
        bookmarkSubtitle.font = .systemFont(ofSize: 11)
        bookmarkSubtitle.textColor = .secondaryLabelColor

        bookmarkLabel.lineBreakMode = .byTruncatingTail
        bookmarkLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        bookmarkSubtitle.lineBreakMode = .byTruncatingTail
        bookmarkSubtitle.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        bookmarkTextStack.addArrangedSubview(bookmarkLabel)
        bookmarkTextStack.addArrangedSubview(bookmarkSubtitle)

        bookmarkSwitch = NSSwitch()
        bookmarkSwitch.controlSize = .mini
        bookmarkSwitch.state = ConfigManager.shared.config.bookmarksEnabled ? .on : .off
        bookmarkSwitch.target = self
        bookmarkSwitch.action = #selector(bookmarkToggled(_:))

        let spacer0 = NSView()
        spacer0.setContentHuggingPriority(.defaultLow, for: .horizontal)

        bookmarkRow.addArrangedSubview(bookmarkTextStack)
        bookmarkRow.addArrangedSubview(spacer0)
        bookmarkRow.addArrangedSubview(bookmarkSwitch)

        let bookmarkSection = SettingsSection(
            title: "Bookmarks",
            contentViews: [bookmarkRow]
        )
        stackView.addArrangedSubview(bookmarkSection)
        bookmarkSection.widthAnchor.constraint(equalTo: stackView.widthAnchor, constant: -40)
            .isActive = true

        // 1. Clipboard Section
        let clipboardRow = NSStackView()
        clipboardRow.orientation = .horizontal
        clipboardRow.spacing = 10
        clipboardRow.alignment = .centerY

        let clipboardTextStack = NSStackView()
        clipboardTextStack.orientation = .vertical
        clipboardTextStack.spacing = 2
        clipboardTextStack.alignment = .leading

        let clipboardLabel = NSTextField(labelWithString: "Enable Clipboard History")
        clipboardLabel.font = .systemFont(ofSize: 13, weight: .regular)
        let clipboardSubtitle = NSTextField(
            labelWithString: "Keep track of copied text and images, and enable clipboard actions")
        clipboardSubtitle.font = .systemFont(ofSize: 11)
        clipboardSubtitle.textColor = .secondaryLabelColor

        clipboardLabel.lineBreakMode = .byTruncatingTail
        clipboardLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        clipboardSubtitle.lineBreakMode = .byTruncatingTail
        clipboardSubtitle.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        clipboardTextStack.addArrangedSubview(clipboardLabel)
        clipboardTextStack.addArrangedSubview(clipboardSubtitle)

        clipboardSwitch = NSSwitch()
        clipboardSwitch.controlSize = .mini
        clipboardSwitch.state = ConfigManager.shared.config.clipboardEnabled ? .on : .off
        clipboardSwitch.target = self
        clipboardSwitch.action = #selector(clipboardToggled(_:))

        let spacer1 = NSView()
        spacer1.setContentHuggingPriority(.defaultLow, for: .horizontal)

        clipboardRow.addArrangedSubview(clipboardTextStack)
        clipboardRow.addArrangedSubview(spacer1)
        clipboardRow.addArrangedSubview(clipboardSwitch)

        let clipboardHotkeyRow = NSStackView()
        clipboardHotkeyRow.orientation = .horizontal
        clipboardHotkeyRow.spacing = 10
        clipboardHotkeyRow.alignment = .centerY

        let hotkeyLabel = NSTextField(labelWithString: "Activation Hotkey")
        hotkeyLabel.font = .systemFont(ofSize: 13, weight: .regular)
        let hotkeySubtitle = NSTextField(
            labelWithString: "Global hotkey to open the clipboard manager")
        hotkeySubtitle.font = .systemFont(ofSize: 11)
        hotkeySubtitle.textColor = .secondaryLabelColor

        let hotkeyTextStack = NSStackView()
        hotkeyTextStack.orientation = .vertical
        hotkeyTextStack.spacing = 2
        hotkeyTextStack.alignment = .leading

        hotkeyLabel.lineBreakMode = .byTruncatingTail
        hotkeyLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        hotkeySubtitle.lineBreakMode = .byTruncatingTail
        hotkeySubtitle.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        hotkeyTextStack.addArrangedSubview(hotkeyLabel)
        hotkeyTextStack.addArrangedSubview(hotkeySubtitle)

        let hotkeyString = NerwActionPreferenceManager.shared.hotkey(for: "builtin.clipboard")
        clipboardHotkeyRecorder = KeybindRecorder(keybind: hotkeyString)
        clipboardHotkeyRecorder.delegate = self
        clipboardHotkeyRecorder.translatesAutoresizingMaskIntoConstraints = false
        clipboardHotkeyRecorder.widthAnchor.constraint(equalToConstant: 140).isActive = true
        clipboardHotkeyRecorder.heightAnchor.constraint(equalToConstant: 24).isActive = true

        let spacer2 = NSView()
        spacer2.setContentHuggingPriority(.defaultLow, for: .horizontal)

        clipboardHotkeyRow.addArrangedSubview(hotkeyTextStack)
        clipboardHotkeyRow.addArrangedSubview(spacer2)
        clipboardHotkeyRow.addArrangedSubview(clipboardHotkeyRecorder)

        let clipboardSection = SettingsSection(
            title: "Clipboard",
            contentViews: [clipboardRow, clipboardHotkeyRow]
        )
        stackView.addArrangedSubview(clipboardSection)
        clipboardSection.widthAnchor.constraint(equalTo: stackView.widthAnchor, constant: -40)
            .isActive = true

        // 2. Snippet Section
        let snippetRow = NSStackView()
        snippetRow.orientation = .horizontal
        snippetRow.spacing = 10
        snippetRow.alignment = .centerY

        let snippetTextStack = NSStackView()
        snippetTextStack.orientation = .vertical
        snippetTextStack.spacing = 2
        snippetTextStack.alignment = .leading

        let snippetLabel = NSTextField(labelWithString: "Enable Snippet Expansion")
        snippetLabel.font = .systemFont(ofSize: 13, weight: .regular)
        let snippetSubtitle = NSTextField(
            labelWithString:
                "Expand abbreviation triggers to snippet content, and enable snippet actions")
        snippetSubtitle.font = .systemFont(ofSize: 11)
        snippetSubtitle.textColor = .secondaryLabelColor

        snippetLabel.lineBreakMode = .byTruncatingTail
        snippetLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        snippetSubtitle.lineBreakMode = .byTruncatingTail
        snippetSubtitle.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        snippetTextStack.addArrangedSubview(snippetLabel)
        snippetTextStack.addArrangedSubview(snippetSubtitle)

        snippetSwitch = NSSwitch()
        snippetSwitch.controlSize = .mini
        snippetSwitch.state = ConfigManager.shared.config.snippetExpansionEnabled ? .on : .off
        snippetSwitch.target = self
        snippetSwitch.action = #selector(snippetToggled(_:))

        let spacer3 = NSView()
        spacer3.setContentHuggingPriority(.defaultLow, for: .horizontal)

        snippetRow.addArrangedSubview(snippetTextStack)
        snippetRow.addArrangedSubview(spacer3)
        snippetRow.addArrangedSubview(snippetSwitch)

        let snippetSection = SettingsSection(
            title: "Snippets",
            contentViews: [snippetRow]
        )
        stackView.addArrangedSubview(snippetSection)
        snippetSection.widthAnchor.constraint(equalTo: stackView.widthAnchor, constant: -40)
            .isActive = true

        // 3. Menubar Search Section
        let menubarRow = NSStackView()
        menubarRow.orientation = .horizontal
        menubarRow.spacing = 10
        menubarRow.alignment = .centerY

        let menubarTextStack = NSStackView()
        menubarTextStack.orientation = .vertical
        menubarTextStack.spacing = 2
        menubarTextStack.alignment = .leading

        let menubarLabel = NSTextField(labelWithString: "Enable Menubar Search")
        menubarLabel.font = .systemFont(ofSize: 13, weight: .regular)
        let menubarSubtitle = NSTextField(
            labelWithString:
                "Index and search the menubar items of the active application prior to opening Nerw"
        )
        menubarSubtitle.font = .systemFont(ofSize: 11)
        menubarSubtitle.textColor = .secondaryLabelColor

        menubarLabel.lineBreakMode = .byTruncatingTail
        menubarLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        menubarSubtitle.lineBreakMode = .byTruncatingTail
        menubarSubtitle.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        menubarTextStack.addArrangedSubview(menubarLabel)
        menubarTextStack.addArrangedSubview(menubarSubtitle)

        menubarSearchSwitch = NSSwitch()
        menubarSearchSwitch.controlSize = .mini
        menubarSearchSwitch.state = ConfigManager.shared.config.menubarSearchEnabled ? .on : .off
        menubarSearchSwitch.target = self
        menubarSearchSwitch.action = #selector(menubarSearchToggled(_:))

        let spacerMenubar = NSView()
        spacerMenubar.setContentHuggingPriority(.defaultLow, for: .horizontal)

        menubarRow.addArrangedSubview(menubarTextStack)
        menubarRow.addArrangedSubview(spacerMenubar)
        menubarRow.addArrangedSubview(menubarSearchSwitch)

        let menubarSection = SettingsSection(
            title: "Menubar Search",
            contentViews: [menubarRow]
        )
        stackView.addArrangedSubview(menubarSection)
        menubarSection.widthAnchor.constraint(equalTo: stackView.widthAnchor, constant: -40)
            .isActive = true

        // 4. Misc Section
        let findFileRow = NSStackView()
        findFileRow.orientation = .horizontal
        findFileRow.spacing = 10
        findFileRow.alignment = .centerY

        let findFileTextStack = NSStackView()
        findFileTextStack.orientation = .vertical
        findFileTextStack.spacing = 2
        findFileTextStack.alignment = .leading

        let findFileLabel = NSTextField(labelWithString: "On First space")
        findFileLabel.font = .systemFont(ofSize: 13, weight: .regular)
        let findFileSubtitle = NSTextField(
            labelWithString:
                "Automatically enter this trigger when pressing the spacebar with an empty query (empty to disable)"
        )
        findFileSubtitle.font = .systemFont(ofSize: 11)
        findFileSubtitle.textColor = .secondaryLabelColor

        findFileLabel.lineBreakMode = .byTruncatingTail
        findFileLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        findFileSubtitle.lineBreakMode = .byTruncatingTail
        findFileSubtitle.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        findFileTextStack.addArrangedSubview(findFileLabel)
        findFileTextStack.addArrangedSubview(findFileSubtitle)

        onFirstSpaceField = NSTextField()
        let cell = CenteredTextFieldCell(textCell: "")
        cell.isEditable = true
        cell.isScrollable = true
        cell.isSelectable = true
        onFirstSpaceField.cell = cell
        onFirstSpaceField.wantsLayer = true
        onFirstSpaceField.isBordered = false
        onFirstSpaceField.drawsBackground = false
        onFirstSpaceField.focusRingType = .none
        onFirstSpaceField.layer?.cornerRadius = 12
        onFirstSpaceField.layer?.masksToBounds = true
        onFirstSpaceField.layer?.borderWidth = 1
        onFirstSpaceField.layer?.borderColor = NSColor.separatorColor.cgColor
        onFirstSpaceField.layer?.backgroundColor =
            NSColor.labelColor.withAlphaComponent(0.05).cgColor
        onFirstSpaceField.textColor = .secondaryLabelColor
        onFirstSpaceField.font = .systemFont(ofSize: 13, weight: .medium)
        onFirstSpaceField.alignment = .center
        onFirstSpaceField.stringValue = ConfigManager.shared.config.onFirstSpace
        onFirstSpaceField.delegate = self
        onFirstSpaceField.placeholderString = "e.g. findfile "
        onFirstSpaceField.translatesAutoresizingMaskIntoConstraints = false
        onFirstSpaceField.widthAnchor.constraint(equalToConstant: 100).isActive = true
        onFirstSpaceField.heightAnchor.constraint(equalToConstant: 24).isActive = true

        let spacer4 = NSView()
        spacer4.setContentHuggingPriority(.defaultLow, for: .horizontal)

        findFileRow.addArrangedSubview(findFileTextStack)
        findFileRow.addArrangedSubview(spacer4)
        findFileRow.addArrangedSubview(onFirstSpaceField)

        let shortcutsRow = NSStackView()
        shortcutsRow.orientation = .horizontal
        shortcutsRow.spacing = 10
        shortcutsRow.alignment = .centerY

        let shortcutsTextStack = NSStackView()
        shortcutsTextStack.orientation = .vertical
        shortcutsTextStack.spacing = 2
        shortcutsTextStack.alignment = .leading

        let shortcutsLabel = NSTextField(labelWithString: "Show Shortcuts in Main Results")
        shortcutsLabel.font = .systemFont(ofSize: 13, weight: .regular)
        let shortcutsSubtitle = NSTextField(
            labelWithString:
                "Include your Apple Shortcuts alongside applications and standard actions in the main search view"
        )
        shortcutsSubtitle.font = .systemFont(ofSize: 11)
        shortcutsSubtitle.textColor = .secondaryLabelColor

        shortcutsLabel.lineBreakMode = .byTruncatingTail
        shortcutsLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        shortcutsSubtitle.lineBreakMode = .byTruncatingTail
        shortcutsSubtitle.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        shortcutsTextStack.addArrangedSubview(shortcutsLabel)
        shortcutsTextStack.addArrangedSubview(shortcutsSubtitle)

        shortcutsSwitch = NSSwitch()
        shortcutsSwitch.controlSize = .mini
        shortcutsSwitch.state = ConfigManager.shared.config.showShortcutsInMain ? .on : .off
        shortcutsSwitch.target = self
        shortcutsSwitch.action = #selector(shortcutsToggled(_:))

        let spacer5 = NSView()
        spacer5.setContentHuggingPriority(.defaultLow, for: .horizontal)

        shortcutsRow.addArrangedSubview(shortcutsTextStack)
        shortcutsRow.addArrangedSubview(spacer5)
        shortcutsRow.addArrangedSubview(shortcutsSwitch)

        let miscSection = SettingsSection(
            title: "Misc",
            contentViews: [findFileRow, shortcutsRow]
        )
        stackView.addArrangedSubview(miscSection)
        miscSection.widthAnchor.constraint(equalTo: stackView.widthAnchor, constant: -40).isActive =
            true
    }

    private func setupConstraints() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        stackView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stackView.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
            stackView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),
        ])
    }

    @objc private func bookmarkToggled(_ sender: NSSwitch) {
        let isEnabled = sender.state == .on
        ConfigManager.shared.config.bookmarksEnabled = isEnabled
        ConfigManager.shared.save()

        NerwActionPreferenceManager.shared.updateActionEnabled(
            isEnabled, for: "builtin.bookmark.add")
        SearchService.shared.loadCache(asyncUpdate: true)
    }

    @objc private func clipboardToggled(_ sender: NSSwitch) {
        let isEnabled = sender.state == .on
        ConfigManager.shared.config.clipboardEnabled = isEnabled
        ConfigManager.shared.save()

        NerwActionPreferenceManager.shared.updateActionEnabled(isEnabled, for: "builtin.clipboard")
        NerwActionPreferenceManager.shared.updateActionEnabled(
            isEnabled, for: "builtin.clipboard.clear")
        SearchService.shared.loadCache(asyncUpdate: true)
    }

    @objc private func snippetToggled(_ sender: NSSwitch) {
        let isEnabled = sender.state == .on
        ConfigManager.shared.config.snippetExpansionEnabled = isEnabled
        ConfigManager.shared.save()

        NerwActionPreferenceManager.shared.updateActionEnabled(
            isEnabled, for: "builtin.snippet.manager")
        NerwActionPreferenceManager.shared.updateActionEnabled(
            isEnabled, for: "builtin.snippet.add")
        SearchService.shared.loadCache(asyncUpdate: true)
    }

    @objc private func shortcutsToggled(_ sender: NSSwitch) {
        ConfigManager.shared.config.showShortcutsInMain = (sender.state == .on)
        ConfigManager.shared.save()
    }

    @objc private func menubarSearchToggled(_ sender: NSSwitch) {
        ConfigManager.shared.config.menubarSearchEnabled = (sender.state == .on)
        ConfigManager.shared.save()
        SearchService.shared.loadCache(asyncUpdate: true)
    }

    @objc private func refreshUI() {
        let config = ConfigManager.shared.config
        bookmarkSwitch.state = config.bookmarksEnabled ? .on : .off
        clipboardSwitch.state = config.clipboardEnabled ? .on : .off
        snippetSwitch.state = config.snippetExpansionEnabled ? .on : .off
        menubarSearchSwitch.state = config.menubarSearchEnabled ? .on : .off
        onFirstSpaceField.stringValue = config.onFirstSpace
        shortcutsSwitch.state = config.showShortcutsInMain ? .on : .off

        let hotkeyString = NerwActionPreferenceManager.shared.hotkey(for: "builtin.clipboard")
        clipboardHotkeyRecorder.setKeybind(hotkeyString)
    }
}

extension FeaturesSettingsViewController: KeybindRecorderDelegate {
    func keybindRecorder(_ recorder: KeybindRecorder, didChangeKeybind keybind: String) {
        if recorder === clipboardHotkeyRecorder {
            NerwActionPreferenceManager.shared.updateHotkey(keybind, for: "builtin.clipboard")
        }
    }
}

extension FeaturesSettingsViewController: NSTextFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        if let field = obj.object as? NSTextField, field === onFirstSpaceField {
            ConfigManager.shared.config.onFirstSpace = field.stringValue
            ConfigManager.shared.save()
        }
    }
}
