import Cocoa
import NerwCore
import NerwSearchBackend
import NerwUtils

class GeneralSettingsViewController: NSViewController, KeybindRecorderDelegate {

    private var recorder: KeybindRecorder!
    private let navStylePopUp = NSPopUpButton()

    private let stackView: NSStackView = {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading  // Leading alignment
        stack.spacing = 24
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        return stack
    }()

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

        refreshUI()
    }

    private func setupUI() {
        view.addSubview(stackView)

        // 1. Activation Shortcut
        // Keybind Recorder
        recorder = KeybindRecorder(keybind: ConfigManager.shared.config.globalKeybind)
        recorder.delegate = self
        recorder.heightAnchor.constraint(equalToConstant: 28).isActive = true

        let recorderRow = NSStackView()
        recorderRow.orientation = .horizontal
        recorderRow.alignment = .centerY
        recorderRow.addArrangedSubview(recorder)
        recorderRow.addArrangedSubview(NSView())  // Spacer

        let shortcutSection = SettingsSection(
            title: "Activation Shortcut",
            contentViews: [recorderRow]
        )
        stackView.addArrangedSubview(shortcutSection)
        // Constrain width to fill stack (minus 40 padding effectively)
        shortcutSection.widthAnchor.constraint(equalTo: stackView.widthAnchor, constant: -40)
            .isActive = true

        // 2. Navigation Style
        navStylePopUp.pullsDown = false
        navStylePopUp.bezelStyle = .rounded
        navStylePopUp.controlSize = .small
        navStylePopUp.translatesAutoresizingMaskIntoConstraints = false

        let styles = [
            ("Unix Style (Ctrl-N / Ctrl-P)", "unix"),
            ("Vim Style (Ctrl-J / Ctrl-K)", "vim"),
        ]
        for (title, val) in styles {
            let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            item.representedObject = val
            navStylePopUp.menu?.addItem(item)
        }
        navStylePopUp.target = self
        navStylePopUp.action = #selector(navStyleChanged(_:))

        let navStyleLabel = NSTextField(labelWithString: "Navigation Binding Style:")
        navStyleLabel.font = .systemFont(ofSize: 13)
        navStyleLabel.textColor = .labelColor

        let navStyleRow = NSStackView()
        navStyleRow.orientation = .horizontal
        navStyleRow.alignment = .centerY
        navStyleRow.spacing = 10
        navStyleRow.edgeInsets = NSEdgeInsets(top: 8, left: 0, bottom: 12, right: 0)
        navStyleRow.addArrangedSubview(navStyleLabel)
        navStyleRow.addArrangedSubview(navStylePopUp)
        navStyleRow.addArrangedSubview(NSView())  // Spacer

        let navStyleSection = SettingsSection(
            title: "Navigation Style",
            contentViews: [navStyleRow]
        )
        stackView.addArrangedSubview(navStyleSection)
        navStyleSection.widthAnchor.constraint(equalTo: stackView.widthAnchor, constant: -40)
            .isActive = true

        // 3. Reset
        let resetBtn = NSButton(
            title: "Reset to Default", target: self, action: #selector(resetClicked(_:)))
        resetBtn.bezelStyle = .rounded
        resetBtn.controlSize = .small
        resetBtn.font = .systemFont(ofSize: 11)

        let deleteLogsBtn = NSButton(
            title: "Delete Logs", target: self, action: #selector(deleteLogsClicked(_:)))
        deleteLogsBtn.bezelStyle = .rounded
        deleteLogsBtn.controlSize = .small
        deleteLogsBtn.font = .systemFont(ofSize: 11)

        let resetStack = NSStackView()
        resetStack.orientation = .horizontal
        resetStack.alignment = .centerY
        resetStack.spacing = 10
        resetStack.addArrangedSubview(resetBtn)
        resetStack.addArrangedSubview(deleteLogsBtn)
        resetStack.addArrangedSubview(NSView())  // Spacer

        let resetSection = SettingsSection(
            title: "Maintenance",
            contentViews: [resetStack]
        )
        stackView.addArrangedSubview(resetSection)
        resetSection.widthAnchor.constraint(equalTo: stackView.widthAnchor, constant: -40)
            .isActive = true
    }

    private func setupConstraints() {
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stackView.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor),
        ])
    }

    // MARK: - Actions

    func keybindRecorder(_ recorder: KeybindRecorder, didChangeKeybind keybind: String) {
        ConfigManager.shared.config.globalKeybind = keybind
        ConfigManager.shared.save()
        ConfigManager.shared.reload()  // Triggers notification
    }

    @objc private func navStyleChanged(_ sender: NSPopUpButton) {
        guard let selectedItem = sender.selectedItem,
            let style = selectedItem.representedObject as? String
        else { return }
        ConfigManager.shared.config.navigationStyle = style
        ConfigManager.shared.save()
        ConfigManager.shared.reload()
    }

    @objc private func resetClicked(_ sender: NSButton) {
        let alert = NSAlert()
        alert.messageText = "Reset Settings"
        alert.informativeText = "Are you sure you want to reset all general settings to default?"
        alert.addButton(withTitle: "Reset")
        alert.addButton(withTitle: "Cancel")

        alert.beginSheetModal(for: self.view.window!) { response in
            if response == .alertFirstButtonReturn {
                ConfigManager.shared.reset()
            }
        }
    }

    @objc private func deleteLogsClicked(_ sender: NSButton) {
        let logDir = Logger.shared.logDirectory

        let alert = NSAlert()
        alert.messageText = "Delete Logs"
        alert.informativeText = "Are you sure you want to delete all log files in ~/.nerw/log/?"
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")

        alert.beginSheetModal(for: self.view.window!) { response in
            if response == .alertFirstButtonReturn {
                do {
                    let fileManager = FileManager.default
                    let logFiles = try fileManager.contentsOfDirectory(
                        at: logDir, includingPropertiesForKeys: nil
                    )

                    var deletedCount = 0
                    for file in logFiles where file.pathExtension == "log" {
                        try fileManager.removeItem(at: file)
                        deletedCount += 1
                    }

                    let resultAlert = NSAlert()
                    resultAlert.messageText = "Logs Deleted"
                    resultAlert.informativeText =
                        "Successfully deleted \(deletedCount) log file(s)."
                    resultAlert.addButton(withTitle: "OK")
                    resultAlert.runModal()
                } catch {
                    let errorAlert = NSAlert()
                    errorAlert.messageText = "Error Deleting Logs"
                    errorAlert.informativeText = error.localizedDescription
                    errorAlert.addButton(withTitle: "OK")
                    errorAlert.runModal()
                }
            }
        }
    }

    @objc private func refreshUI() {
        let config = ConfigManager.shared.config
        recorder.setKeybind(config.globalKeybind)
        if let idx = navStylePopUp.menu?.items.firstIndex(where: {
            ($0.representedObject as? String) == config.navigationStyle
        }) {
            navStylePopUp.selectItem(at: idx)
        }
    }
}
