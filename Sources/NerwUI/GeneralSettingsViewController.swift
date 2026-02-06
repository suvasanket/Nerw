import Cocoa
import NerwSearchBackend

class GeneralSettingsViewController: NSViewController, KeybindRecorderDelegate {

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
    }

    private func setupUI() {
        view.addSubview(stackView)

        // 1. Activation Shortcut
        // Keybind Recorder
        let recorder = KeybindRecorder(keybind: ConfigManager.shared.config.globalKeybind)
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

        // 2. Behavior
        let findFileStack = NSStackView()
        findFileStack.orientation = .horizontal
        findFileStack.spacing = 10
        findFileStack.alignment = .centerY

        let findFileLabel = NSTextField(labelWithString: "Find File on Space")
        findFileLabel.font = .systemFont(ofSize: 13)

        let findFileSwitch = NSSwitch()
        findFileSwitch.controlSize = .mini
        findFileSwitch.state = ConfigManager.shared.config.findFileOnSpace ? .on : .off
        findFileSwitch.target = self
        findFileSwitch.action = #selector(findFileToggled(_:))

        findFileStack.addArrangedSubview(findFileLabel)
        findFileStack.addArrangedSubview(NSView())  // Spacer
        findFileStack.addArrangedSubview(findFileSwitch)

        findFileStack.arrangedSubviews[1].setContentHuggingPriority(.defaultLow, for: .horizontal)

        // Shortcuts Toggle
        let shortcutsStack = NSStackView()
        shortcutsStack.orientation = .horizontal
        shortcutsStack.spacing = 10
        shortcutsStack.alignment = .centerY

        let shortcutsLabel = NSTextField(labelWithString: "Show Shortcuts in Main Results")
        shortcutsLabel.font = .systemFont(ofSize: 13)

        let shortcutsSwitch = NSSwitch()
        shortcutsSwitch.controlSize = .mini
        shortcutsSwitch.state = ConfigManager.shared.config.showShortcutsInMain ? .on : .off
        shortcutsSwitch.target = self
        shortcutsSwitch.action = #selector(shortcutsToggled(_:))

        shortcutsStack.addArrangedSubview(shortcutsLabel)
        shortcutsStack.addArrangedSubview(NSView())
        shortcutsStack.addArrangedSubview(shortcutsSwitch)

        shortcutsStack.arrangedSubviews[1].setContentHuggingPriority(.defaultLow, for: .horizontal)

        let behaviorSection = SettingsSection(
            title: "Behavior",
            contentViews: [findFileStack, shortcutsStack]
        )
        stackView.addArrangedSubview(behaviorSection)
        behaviorSection.widthAnchor.constraint(equalTo: stackView.widthAnchor, constant: -40)
            .isActive = true

        // 3. Search
        let thresholdStack = NSStackView()
        thresholdStack.orientation = .horizontal
        thresholdStack.spacing = 10
        thresholdStack.alignment = .centerY

        let thresholdLabel = NSTextField(labelWithString: "Suggestion Threshold:")

        let thresholdStepper = NSStepper()
        thresholdStepper.minValue = 1
        thresholdStepper.maxValue = 10
        thresholdStepper.intValue = Int32(ConfigManager.shared.config.searchEngineSuggestThreshold)
        thresholdStepper.target = self
        thresholdStepper.action = #selector(thresholdChanged(_:))

        let thresholdValueLabel = NSTextField(
            labelWithString: "\(ConfigManager.shared.config.searchEngineSuggestThreshold)")
        thresholdValueLabel.tag = 101  // Tag to find it later

        thresholdStack.addArrangedSubview(thresholdLabel)
        thresholdStack.addArrangedSubview(thresholdValueLabel)
        thresholdStack.addArrangedSubview(thresholdStepper)
        thresholdStack.addArrangedSubview(NSView())  // Spacer

        let searchSection = SettingsSection(
            title: "Search",
            contentViews: [thresholdStack]
        )
        stackView.addArrangedSubview(searchSection)
        searchSection.widthAnchor.constraint(equalTo: stackView.widthAnchor, constant: -40)
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

    @objc private func findFileToggled(_ sender: NSSwitch) {
        ConfigManager.shared.config.findFileOnSpace = (sender.state == .on)
        ConfigManager.shared.save()
    }

    @objc private func shortcutsToggled(_ sender: NSSwitch) {
        ConfigManager.shared.config.showShortcutsInMain = (sender.state == .on)
        ConfigManager.shared.save()
    }

    @objc private func thresholdChanged(_ sender: NSStepper) {
        let value = Int(sender.intValue)
        ConfigManager.shared.config.searchEngineSuggestThreshold = value
        ConfigManager.shared.save()

        // Update label
        if let label = view.viewWithTag(101) as? NSTextField {
            label.stringValue = "\(value)"
        }
    }
}
