import Carbon
import Cocoa
import NerwSearchBackend

protocol KeybindRecorderDelegate: AnyObject {
    func keybindRecorder(_ recorder: KeybindRecorder, didChangeKeybind keybind: String)
}

class KeybindRecorder: NSView {

    weak var delegate: KeybindRecorderDelegate?

    private var isRecording = false {
        didSet {
            updateDisplay()
            if isRecording {
                window?.makeFirstResponder(self)
                startBlinking()
            } else {
                stopBlinking()
            }
        }
    }

    private var currentKeybind: String = ""
    private var trackingArea: NSTrackingArea?

    // UI Components
    private let stackView: NSStackView = {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 4
        stack.alignment = .centerY
        return stack
    }()

    private let placeholderLabel: NSTextField = {
        let label = NSTextField(labelWithString: "Click to set")
        label.textColor = .tertiaryLabelColor
        label.font = .systemFont(ofSize: 12)
        return label
    }()

    init(keybind: String) {
        self.currentKeybind = keybind
        super.init(frame: NSRect(x: 0, y: 0, width: 200, height: 28))

        wantsLayer = true
        layer?.cornerRadius = 14  // Rounded ends (28/2 = 14)
        layer?.masksToBounds = true
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.cgColor
        layer?.backgroundColor = nil  // No background as requested

        setupUI()
        updateDisplay()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea = self.trackingArea {
            removeTrackingArea(trackingArea)
        }

        let options: NSTrackingArea.Options = [
            .mouseEnteredAndExited, .activeAlways, .inVisibleRect,
        ]
        trackingArea = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(trackingArea!)
    }

    override func mouseUp(with event: NSEvent) {
        isRecording = true
    }

    override var acceptsFirstResponder: Bool {
        return true
    }

    override func resignFirstResponder() -> Bool {
        isRecording = false
        return super.resignFirstResponder()
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }

        let modifierFlags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let keyCode = event.keyCode

        if modifierFlags.isEmpty && (keyCode == 53) {  // Escape
            isRecording = false
            return
        }

        let newKeybind = HotkeyParser.string(for: modifierFlags, keyCode: keyCode)
        self.currentKeybind = newKeybind
        self.delegate?.keybindRecorder(self, didChangeKeybind: newKeybind)

        isRecording = false
    }

    private func updateDisplay() {
        for subview in stackView.arrangedSubviews {
            subview.removeFromSuperview()
        }

        if isRecording {
            layer?.borderColor = NSColor.controlAccentColor.cgColor
            let recordingLabel = NSTextField(labelWithString: "Type shortcut...")
            recordingLabel.textColor = .secondaryLabelColor
            stackView.addArrangedSubview(recordingLabel)
            return
        }

        layer?.borderColor = NSColor.separatorColor.cgColor

        if currentKeybind.isEmpty {
            stackView.addArrangedSubview(placeholderLabel)
            return
        }

        // Logic to replace Cmd+Ctrl+Opt with "⟡"
        var components = currentKeybind.components(separatedBy: "+")
        let superKeySet: Set<String> = ["Cmd", "Ctrl", "Opt"]
        let currentSet = Set(
            components.prefix(while: { superKeySet.contains($0) || $0 == "Shift" }))

        // If we have at least Cmd, Ctrl, Opt
        if superKeySet.isSubset(of: currentSet) {
            // Remove those from components
            components.removeAll { superKeySet.contains($0) }

            var newComponents: [String] = []
            newComponents.append("⟡")  // Super Key
            if currentSet.contains("Shift") {
                newComponents.append("Shift")
            }
            // Add the rest
            if let last = components.last, !superKeySet.contains(last) && last != "Shift" {
                newComponents.append(last)
            } else if !components.isEmpty {
                newComponents.append(contentsOf: components)
            }

            // Build view from new components
            for component in newComponents {
                if component == "⟡" {
                    stackView.addArrangedSubview(createLabelView(text: "⟡"))  // Symbol
                } else if let icon = icon(for: component) {
                    stackView.addArrangedSubview(createIconView(icon: icon))
                } else {
                    stackView.addArrangedSubview(createLabelView(text: component))
                }
            }
        } else {
            // Standard render
            for component in components {
                if let icon = icon(for: component) {
                    stackView.addArrangedSubview(createIconView(icon: icon))
                } else {
                    stackView.addArrangedSubview(createLabelView(text: component))
                }
            }
        }
    }

    private func createIconView(icon: NSImage) -> NSImageView {
        let iv = NSImageView()
        iv.image = icon
        iv.contentTintColor = .secondaryLabelColor  // "Bit translucent"
        iv.widthAnchor.constraint(equalToConstant: 14).isActive = true
        iv.heightAnchor.constraint(equalToConstant: 14).isActive = true
        return iv
    }

    private func createLabelView(text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .secondaryLabelColor  // "Bit translucent"
        return label
    }

    private func icon(for component: String) -> NSImage? {
        switch component.lowercased() {
        case "cmd", "command":
            return NSImage(systemSymbolName: "command", accessibilityDescription: "Command")
        case "shift": return NSImage(systemSymbolName: "shift", accessibilityDescription: "Shift")
        case "opt", "option", "alt":
            return NSImage(systemSymbolName: "option", accessibilityDescription: "Option")
        case "ctrl", "control":
            return NSImage(systemSymbolName: "control", accessibilityDescription: "Control")
        default: return nil
        }
    }

    private func startBlinking() {
        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = 1.0
        animation.toValue = 0.5
        animation.duration = 0.8
        animation.autoreverses = true
        animation.repeatCount = .infinity
        layer?.add(animation, forKey: "blink")
    }

    private func stopBlinking() {
        layer?.removeAnimation(forKey: "blink")
    }
}
