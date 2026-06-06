import Cocoa
import NerwAction
import NerwCore

protocol FormViewDelegate: AnyObject {
    func formDidCancel()
    func formDidSubmit(values: [String: String])
}

class FormView: NSView, NSTextFieldDelegate, NSTextViewDelegate {

    weak var delegate: FormViewDelegate?

    private let fields: [NerwAction.Field]
    private var inputs: [String: NSView] = [:]
    private var orderedInputs: [NSView] = []

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
            label.font = .systemFont(ofSize: 14, weight: .medium)
            label.textColor = .white
            fieldContainer.addArrangedSubview(label)

            // Input
            let inputView: NSView
            if field.isMultiline {
                let scrollView = NSTextView.scrollableTextView()
                scrollView.hasVerticalScroller = true
                let textView = scrollView.documentView as! NSTextView
                textView.font = .systemFont(ofSize: 15)
                textView.textColor = .labelColor
                textView.backgroundColor = .controlBackgroundColor
                textView.isRichText = false
                textView.allowsUndo = true
                textView.delegate = self

                if let dv = field.defaultValue {
                    textView.string = dv
                }

                scrollView.translatesAutoresizingMaskIntoConstraints = false
                scrollView.heightAnchor.constraint(equalToConstant: 80).isActive = true
                inputView = scrollView

                inputs[field.id] = textView
                orderedInputs.append(textView)
            } else {
                let textField: NSTextField
                if field.isSecure {
                    textField = NSSecureTextField()
                } else {
                    textField = ThemedTextField()
                }

                textField.font = .systemFont(ofSize: 15)
                if let ph = field.placeholder {
                    textField.placeholderString = ph
                }

                textField.bezelStyle = .roundedBezel
                textField.textColor = .labelColor
                textField.delegate = self

                if let dv = field.defaultValue {
                    textField.stringValue = dv
                }

                inputView = textField
                inputs[field.id] = textField
                orderedInputs.append(textField)
            }

            fieldContainer.addArrangedSubview(inputView)

            // Constraints
            inputView.translatesAutoresizingMaskIntoConstraints = false
            inputView.widthAnchor.constraint(equalTo: fieldContainer.widthAnchor).isActive = true

            stackView.addArrangedSubview(fieldContainer)
            fieldContainer.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
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
            if let index = orderedInputs.firstIndex(of: control) {
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

    // MARK: - NSTextViewDelegate

    func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            if let event = NSApp.currentEvent, event.modifierFlags.contains(.shift) {
                // Shift+Enter inserts newline in multiline text
                return false
            } else {
                // Enter submits if last field, else moves focus
                if let index = orderedInputs.firstIndex(of: textView) {
                    if index == orderedInputs.count - 1 {
                        submit()
                    } else {
                        window?.makeFirstResponder(orderedInputs[index + 1])
                    }
                    return true
                }
            }
        } else if commandSelector == #selector(NSResponder.insertTab(_:)) {
            // Tab moves to next field
            if let index = orderedInputs.firstIndex(of: textView) {
                window?.makeFirstResponder(orderedInputs[(index + 1) % orderedInputs.count])
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
            if let textField = input as? NSTextField {
                values[id] = textField.stringValue
            } else if let textView = input as? NSTextView {
                values[id] = textView.string
            }
        }
        delegate?.formDidSubmit(values: values)
    }
}
