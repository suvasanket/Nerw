import Cocoa
import NerwCore

protocol FormViewDelegate: AnyObject {
    func formDidCancel()
    func formDidSubmit(values: [String: String])
}

class FormView: NSView, NSTextFieldDelegate {

    weak var delegate: FormViewDelegate?

    private let fields: [NerwAction.Field]
    private var inputs: [String: NSTextField] = [:]
    private var orderedInputs: [NSTextField] = []

    init(fields: [NerwAction.Field]) {
        self.fields = fields
        super.init(frame: .zero)
        setupView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupView() {
        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 20
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20),
        ])

        for field in fields {
            let fieldContainer = NSStackView()
            fieldContainer.orientation = .vertical
            fieldContainer.alignment = .leading
            fieldContainer.spacing = 8

            // Label
            let label = NSTextField(labelWithString: field.title)
            label.font = .systemFont(ofSize: 13, weight: .medium)
            label.textColor = .secondaryLabelColor
            fieldContainer.addArrangedSubview(label)

            // Input
            let input: NSTextField
            if field.isSecure {
                input = NSSecureTextField()
            } else {
                input = ThemedTextField()
            }

            input.font = .systemFont(ofSize: 15)
            if let ph = field.placeholder {
                input.placeholderString = ph
            }
            input.isBordered = false
            input.drawsBackground = false
            input.focusRingType = .none
            input.textColor = .labelColor

            fieldContainer.addArrangedSubview(input)

            // Separator Line
            let separator = NSBox()
            separator.boxType = .separator
            fieldContainer.addArrangedSubview(separator)

            // Constraints
            input.translatesAutoresizingMaskIntoConstraints = false
            separator.translatesAutoresizingMaskIntoConstraints = false

            input.widthAnchor.constraint(equalTo: fieldContainer.widthAnchor).isActive = true
            separator.widthAnchor.constraint(equalTo: fieldContainer.widthAnchor).isActive = true

            stackView.addArrangedSubview(fieldContainer)
            fieldContainer.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true

            input.delegate = self
            inputs[field.id] = input
            orderedInputs.append(input)
        }

        // Setup Key View Loop
        for i in 0..<orderedInputs.count {
            let current = orderedInputs[i]
            let next = orderedInputs[(i + 1) % orderedInputs.count]
            current.nextKeyView = next
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        // Focus first field
        if let first = orderedInputs.first, window?.firstResponder != first {
            window?.makeFirstResponder(first)
        }
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command) {
            guard let key = event.charactersIgnoringModifiers?.lowercased() else {
                return super.performKeyEquivalent(with: event)
            }

            switch key {
            case "v":
                if NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: self) {
                    return true
                }
            case "c":
                if NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: self) { return true }
            case "x":
                if NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: self) { return true }
            case "a":
                if NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: self) {
                    return true
                }
            default:
                break
            }
        }
        return super.performKeyEquivalent(with: event)
    }

    // MARK: - NSTextFieldDelegate

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector)
        -> Bool
    {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            // If it's the last field, submit. Else move to next.
            if let index = orderedInputs.firstIndex(of: control as! NSTextField) {
                if index == orderedInputs.count - 1 {
                    submit()
                } else {
                    window?.makeFirstResponder(orderedInputs[index + 1])
                }
                return true
            }
        } else if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            delegate?.formDidCancel()
            return true
        }
        return false
    }

    private func submit() {
        var values: [String: String] = [:]
        for (id, input) in inputs {
            values[id] = input.stringValue
        }
        delegate?.formDidSubmit(values: values)
    }
}
