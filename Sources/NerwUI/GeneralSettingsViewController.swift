import Cocoa
import NerwSearchBackend

class GeneralSettingsViewController: NSViewController, KeybindRecorderDelegate {

    private let stackView: NSStackView = {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 20
        // Even insets as requested (Right changed from 40 back to 20 to match Left)
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
        let shortcutSection = createSection(title: "Activation Shortcut")

        // Keybind Recorder
        let recorder = KeybindRecorder(keybind: ConfigManager.shared.config.globalKeybind)
        recorder.delegate = self
        // Set fixed height for pill shape (28pt for cornerRadius 14), allow width to auto-size
        recorder.heightAnchor.constraint(equalToConstant: 28).isActive = true

        shortcutSection.addArrangedSubview(recorder)

        stackView.addArrangedSubview(shortcutSection)

        addSeparator()

        // 2. Behavior
        let behaviorSection = createSection(title: "Behavior")

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

        // Spacer to push switch to the far right
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        findFileStack.addArrangedSubview(findFileLabel)
        findFileStack.addArrangedSubview(spacer)
        findFileStack.addArrangedSubview(findFileSwitch)

        // Constrain stack to full content width (Window 450 - Left 20 - Right 20 = 410)
        findFileStack.translatesAutoresizingMaskIntoConstraints = false
        findFileStack.widthAnchor.constraint(equalToConstant: 410).isActive = true

        behaviorSection.addArrangedSubview(findFileStack)

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

        let shortcutsSpacer = NSView()
        shortcutsSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        shortcutsStack.addArrangedSubview(shortcutsLabel)
        shortcutsStack.addArrangedSubview(shortcutsSpacer)
        shortcutsStack.addArrangedSubview(shortcutsSwitch)

        shortcutsStack.translatesAutoresizingMaskIntoConstraints = false
        shortcutsStack.widthAnchor.constraint(equalToConstant: 410).isActive = true

        behaviorSection.addArrangedSubview(shortcutsStack)

        stackView.addArrangedSubview(behaviorSection)

        addSeparator()

        // 3. Search
        let searchSection = createSection(title: "Search")

        let thresholdStack = NSStackView()
        thresholdStack.orientation = .horizontal
        thresholdStack.spacing = 10

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

        searchSection.addArrangedSubview(thresholdStack)
        stackView.addArrangedSubview(searchSection)
    }

    private func setupConstraints() {
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: view.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stackView.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor),
        ])
    }

    private func createSection(title: String) -> NSStackView {
        let sectionStack = NSStackView()
        sectionStack.orientation = .vertical
        sectionStack.alignment = .leading
        sectionStack.spacing = 10

        let label = NSTextField(labelWithString: title)
        label.font = NSFont.boldSystemFont(ofSize: 13)

        sectionStack.addArrangedSubview(label)
        return sectionStack
    }

    private func addSeparator() {
        let separator = NSBox()
        separator.boxType = .separator
        // Match content width (450 - 20 - 20 = 410)
        separator.widthAnchor.constraint(equalToConstant: 410).isActive = true
        stackView.addArrangedSubview(separator)
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
