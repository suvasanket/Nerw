import Cocoa
import NerwAction
import NerwBuiltin
import NerwCore
import NerwSearchBackend

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

    private var clipboardSwitch: NSSwitch!
    private var snippetSwitch: NSSwitch!
    private var clipboardHotkeyRecorder: KeybindRecorder!
    private var findFileSwitch: NSSwitch!
    private var shortcutsSwitch: NSSwitch!

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

        // 3. Misc Section
        let findFileRow = NSStackView()
        findFileRow.orientation = .horizontal
        findFileRow.spacing = 10
        findFileRow.alignment = .centerY

        let findFileTextStack = NSStackView()
        findFileTextStack.orientation = .vertical
        findFileTextStack.spacing = 2
        findFileTextStack.alignment = .leading

        let findFileLabel = NSTextField(labelWithString: "Find File on Space")
        findFileLabel.font = .systemFont(ofSize: 13, weight: .regular)
        let findFileSubtitle = NSTextField(
            labelWithString:
                "Automatically enter find file mode when pressing the spacebar with an empty query")
        findFileSubtitle.font = .systemFont(ofSize: 11)
        findFileSubtitle.textColor = .secondaryLabelColor

        findFileTextStack.addArrangedSubview(findFileLabel)
        findFileTextStack.addArrangedSubview(findFileSubtitle)

        findFileSwitch = NSSwitch()
        findFileSwitch.controlSize = .mini
        findFileSwitch.state = ConfigManager.shared.config.findFileOnSpace ? .on : .off
        findFileSwitch.target = self
        findFileSwitch.action = #selector(findFileToggled(_:))

        let spacer4 = NSView()
        spacer4.setContentHuggingPriority(.defaultLow, for: .horizontal)

        findFileRow.addArrangedSubview(findFileTextStack)
        findFileRow.addArrangedSubview(spacer4)
        findFileRow.addArrangedSubview(findFileSwitch)

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

    @objc private func findFileToggled(_ sender: NSSwitch) {
        ConfigManager.shared.config.findFileOnSpace = (sender.state == .on)
        ConfigManager.shared.save()
    }

    @objc private func shortcutsToggled(_ sender: NSSwitch) {
        ConfigManager.shared.config.showShortcutsInMain = (sender.state == .on)
        ConfigManager.shared.save()
    }

    @objc private func refreshUI() {
        let config = ConfigManager.shared.config
        clipboardSwitch.state = config.clipboardEnabled ? .on : .off
        snippetSwitch.state = config.snippetExpansionEnabled ? .on : .off
        findFileSwitch.state = config.findFileOnSpace ? .on : .off
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
