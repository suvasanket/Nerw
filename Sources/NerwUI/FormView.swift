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
    private let submitLabelText: String?
    private var inputs: [String: NSView] = [:]
    private var orderedInputs: [NSView] = []
    private var submitButton: FormButton?

    init(fields: [NerwAction.Field], submitLabel: String? = nil) {
        self.fields = fields
        self.submitLabelText = submitLabel
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
            label.font = .systemFont(ofSize: 16, weight: .semibold)
            label.textColor = .white
            fieldContainer.addArrangedSubview(label)

            // Subtext (if present)
            if let subtext = field.subtext, !subtext.isEmpty {
                let subtextLabel = NSTextField(labelWithString: subtext)
                subtextLabel.font = .systemFont(ofSize: 12.5, weight: .regular)
                subtextLabel.textColor = .secondaryLabelColor
                subtextLabel.lineBreakMode = .byWordWrapping
                subtextLabel.cell?.wraps = true
                fieldContainer.addArrangedSubview(subtextLabel)
                subtextLabel.translatesAutoresizingMaskIntoConstraints = false
                subtextLabel.widthAnchor.constraint(equalTo: fieldContainer.widthAnchor).isActive =
                    true
            }

            // Input
            let inputView: NSView
            if field.isMultiline {
                let container: NSView
                container = NSView()
                container.wantsLayer = true
                container.layer?.cornerRadius = 10
                container.layer?.borderWidth = 1.0
                container.layer?.borderColor = NSColor.white.withAlphaComponent(0.12).cgColor
                container.layer?.backgroundColor =
                    NSColor.white.withAlphaComponent(0.06).cgColor
                container.translatesAutoresizingMaskIntoConstraints = false
                container.heightAnchor.constraint(equalToConstant: 120).isActive = true

                let scrollView = NSScrollView()
                scrollView.hasVerticalScroller = true
                scrollView.drawsBackground = false
                scrollView.translatesAutoresizingMaskIntoConstraints = false
                container.addSubview(scrollView)

                NSLayoutConstraint.activate([
                    scrollView.topAnchor.constraint(equalTo: container.topAnchor, constant: 4),
                    scrollView.leadingAnchor.constraint(
                        equalTo: container.leadingAnchor, constant: 4),
                    scrollView.trailingAnchor.constraint(
                        equalTo: container.trailingAnchor, constant: -4),
                    scrollView.bottomAnchor.constraint(
                        equalTo: container.bottomAnchor, constant: -4),
                ])

                let textView = NSTextView()
                textView.drawsBackground = false
                textView.backgroundColor = .clear
                textView.font = .systemFont(ofSize: 16.5)
                textView.textColor = .labelColor
                textView.isRichText = false
                textView.allowsUndo = true
                textView.delegate = self
                textView.textContainerInset = NSSize(width: 8, height: 8)

                textView.minSize = NSSize(width: 0, height: 0)
                textView.maxSize = NSSize(
                    width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
                textView.isVerticallyResizable = true
                textView.isHorizontallyResizable = false
                textView.autoresizingMask = [.width]

                if let textContainer = textView.textContainer {
                    textContainer.widthTracksTextView = true
                }

                if let dv = field.defaultValue {
                    textView.string = dv
                }

                scrollView.documentView = textView
                inputView = container

                inputs[field.id] = textView
                orderedInputs.append(textView)
            } else {
                let textField: NSTextField
                if field.isSecure {
                    textField = FormSecureTextField()
                } else {
                    textField = FormTextField()
                }

                textField.font = .systemFont(ofSize: 16.5)
                if let ph = field.placeholder {
                    textField.placeholderString = ph
                }

                textField.textColor = .labelColor
                textField.delegate = self

                if let dv = field.defaultValue {
                    textField.stringValue = dv
                }

                inputs[field.id] = textField
                orderedInputs.append(textField)

                let container = NSView()
                container.wantsLayer = true
                container.layer?.cornerRadius = 10
                container.layer?.borderWidth = 1.0
                container.layer?.borderColor = NSColor.white.withAlphaComponent(0.12).cgColor
                container.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.06).cgColor
                container.translatesAutoresizingMaskIntoConstraints = false
                container.heightAnchor.constraint(equalToConstant: 44).isActive = true

                textField.wantsLayer = false
                textField.drawsBackground = false
                textField.backgroundColor = .clear
                textField.isBezeled = false
                textField.isBordered = false
                textField.translatesAutoresizingMaskIntoConstraints = false
                container.addSubview(textField)

                NSLayoutConstraint.activate([
                    textField.leadingAnchor.constraint(
                        equalTo: container.leadingAnchor, constant: 8),
                    textField.trailingAnchor.constraint(
                        equalTo: container.trailingAnchor, constant: -8),
                    textField.topAnchor.constraint(equalTo: container.topAnchor),
                    textField.bottomAnchor.constraint(equalTo: container.bottomAnchor),
                ])

                inputView = container
            }

            fieldContainer.addArrangedSubview(inputView)

            // Constraints
            inputView.translatesAutoresizingMaskIntoConstraints = false
            inputView.widthAnchor.constraint(equalTo: fieldContainer.widthAnchor).isActive = true

            stackView.addArrangedSubview(fieldContainer)
            fieldContainer.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
        }

        // Button Row at the bottom
        let buttonRow = NSStackView()
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 12
        buttonRow.alignment = .centerY

        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        buttonRow.addArrangedSubview(spacer)

        let cancelButton = FormButton(
            title: "Cancel", iconName: "escape", target: self,
            action: #selector(cancelPressed))
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.heightAnchor.constraint(equalToConstant: 32).isActive = true
        buttonRow.addArrangedSubview(cancelButton)

        let submitLabel = submitLabelText ?? "Submit"
        let submitButtonInstance = FormButton(
            title: submitLabel, iconName: "command,return", target: self,
            action: #selector(submitPressed))
        submitButtonInstance.isAccent = true
        submitButtonInstance.translatesAutoresizingMaskIntoConstraints = false
        submitButtonInstance.heightAnchor.constraint(equalToConstant: 32).isActive = true
        buttonRow.addArrangedSubview(submitButtonInstance)
        self.submitButton = submitButtonInstance

        stackView.addArrangedSubview(buttonRow)
        buttonRow.translatesAutoresizingMaskIntoConstraints = false
        buttonRow.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true

        // Setup Key View Loop
        for i in 0..<orderedInputs.count {
            let current = orderedInputs[i]
            let next = orderedInputs[(i + 1) % orderedInputs.count]
            current.nextKeyView = next
        }

        validateForm()
    }

    @objc private func cancelPressed() {
        delegate?.formDidCancel()
    }

    @objc private func submitPressed() {
        submit()
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
            case "\r", "\n":
                submit()
                return true
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
            if let event = NSApp.currentEvent, event.modifierFlags.contains(.command) {
                submit()
                return true
            }
            // If it's the last field, submit. Else move to next.
            if let index = orderedInputs.firstIndex(of: control) {
                if index == orderedInputs.count - 1 {
                    submit()
                } else {
                    window?.makeFirstResponder(orderedInputs[index + 1])
                }
                return true
            }
        } else if commandSelector == #selector(NSResponder.insertTab(_:)) {
            if let index = orderedInputs.firstIndex(of: control) {
                window?.makeFirstResponder(orderedInputs[(index + 1) % orderedInputs.count])
                return true
            }
        } else if commandSelector == #selector(NSResponder.insertBacktab(_:)) {
            if let index = orderedInputs.firstIndex(of: control) {
                let prevIndex = (index - 1 + orderedInputs.count) % orderedInputs.count
                window?.makeFirstResponder(orderedInputs[prevIndex])
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
        if commandSelector == #selector(NSResponder.insertNewline(_:))
            || commandSelector == #selector(NSResponder.insertNewlineIgnoringFieldEditor(_:))
        {
            if let event = NSApp.currentEvent {
                if event.modifierFlags.contains(.command) {
                    submit()
                    return true
                }
            }
            // Regular Enter or other modifiers inserts a newline in the multiline field.
            return false
        } else if commandSelector == #selector(NSResponder.insertTab(_:)) {
            // Tab moves to next field
            if let index = orderedInputs.firstIndex(of: textView) {
                window?.makeFirstResponder(orderedInputs[(index + 1) % orderedInputs.count])
                return true
            }
        } else if commandSelector == #selector(NSResponder.insertBacktab(_:)) {
            // Shift+Tab moves to previous field
            if let index = orderedInputs.firstIndex(of: textView) {
                let prevIndex = (index - 1 + orderedInputs.count) % orderedInputs.count
                window?.makeFirstResponder(orderedInputs[prevIndex])
                return true
            }
        } else if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            delegate?.formDidCancel()
            return true
        }
        return false
    }

    func controlTextDidChange(_ obj: Notification) {
        validateForm()
    }

    func textDidChange(_ notification: Notification) {
        validateForm()
    }

    private func validateForm() {
        var allFilled = true
        for (_, input) in inputs {
            if let textField = input as? NSTextField {
                let trimmed = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    allFilled = false
                    break
                }
            } else if let textView = input as? NSTextView {
                let trimmed = textView.string.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    allFilled = false
                    break
                }
            }
        }
        submitButton?.isEnabled = allFilled
    }

    private func submit() {
        guard submitButton?.isEnabled == true else { return }
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

// MARK: - Custom Rounded Form Elements

class FormTextFieldCell: NSTextFieldCell {
    private let xOffset: CGFloat = 14

    override func titleRect(forBounds rect: NSRect) -> NSRect {
        let textHeight: CGFloat = font?.pointSize ?? 16.5
        let editHeight = textHeight + 3
        let deltaY = (rect.height - editHeight) / 2
        return NSRect(
            x: rect.origin.x + xOffset,
            y: rect.origin.y + deltaY,
            width: rect.width - xOffset * 2,
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

class FormSecureTextFieldCell: NSSecureTextFieldCell {
    private let xOffset: CGFloat = 14

    override func titleRect(forBounds rect: NSRect) -> NSRect {
        let textHeight: CGFloat = font?.pointSize ?? 16.5
        let editHeight = textHeight + 3
        let deltaY = (rect.height - editHeight) / 2
        return NSRect(
            x: rect.origin.x + xOffset,
            y: rect.origin.y + deltaY,
            width: rect.width - xOffset * 2,
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

class FormTextField: ThemedTextField {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.stringValue = ""
        setupCell()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.stringValue = ""
        setupCell()
    }

    private func setupCell() {
        let customCell = FormTextFieldCell()
        customCell.stringValue = ""
        customCell.drawsBackground = false
        customCell.isScrollable = true
        customCell.isSelectable = true
        customCell.isEditable = true
        self.cell = customCell

        self.isBezeled = false
        self.isBordered = false
        self.drawsBackground = false
        self.backgroundColor = .clear
        self.focusRingType = .none
        self.wantsLayer = false
    }
}

class FormSecureTextField: NSSecureTextField {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.stringValue = ""
        setupCell()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.stringValue = ""
        setupCell()
    }

    private func setupCell() {
        let customCell = FormSecureTextFieldCell()
        customCell.stringValue = ""
        customCell.drawsBackground = false
        customCell.isScrollable = true
        customCell.isSelectable = true
        customCell.isEditable = true
        self.cell = customCell

        self.isBezeled = false
        self.isBordered = false
        self.drawsBackground = false
        self.backgroundColor = .clear
        self.focusRingType = .none
        self.wantsLayer = false
    }
}

class FormButton: NSButton {
    private var trackingArea: NSTrackingArea?
    var normalBackgroundColor: NSColor = .white.withAlphaComponent(0.06)
    var hoverBackgroundColor: NSColor = .white.withAlphaComponent(0.15)
    var normalBorderColor: NSColor = .white.withAlphaComponent(0.12)
    var hoverBorderColor: NSColor = .white.withAlphaComponent(0.25)

    override var isEnabled: Bool {
        didSet {
            updateColors()
            self.alphaValue = isEnabled ? 1.0 : 0.4
        }
    }

    var isAccent = false {
        didSet {
            updateColors()
        }
    }

    init(title: String, iconName: String, target: AnyObject?, action: Selector) {
        super.init(frame: .zero)
        self.title = ""
        self.image = nil
        self.target = target
        self.action = action
        self.isBordered = false
        self.wantsLayer = true
        self.layer?.cornerRadius = 16
        self.layer?.borderWidth = 1.0

        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 6
        stack.alignment = .centerY
        stack.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: self.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: self.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -12),
        ])

        let tf = NSTextField(labelWithString: title)
        tf.font = .systemFont(ofSize: 13, weight: .medium)
        tf.textColor = .white
        stack.addArrangedSubview(tf)

        let iconNames = iconName.components(separatedBy: ",")
        for name in iconNames {
            let iv = NSImageView()
            iv.image = NSImage(
                systemSymbolName: name.trimmingCharacters(in: .whitespaces),
                accessibilityDescription: nil)
            iv.contentTintColor = .white.withAlphaComponent(0.6)
            iv.translatesAutoresizingMaskIntoConstraints = false
            iv.heightAnchor.constraint(equalToConstant: 12).isActive = true
            iv.widthAnchor.constraint(equalToConstant: 12).isActive = true
            stack.addArrangedSubview(iv)
        }

        updateColors()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: NSSize {
        let stackWidth = self.subviews.first?.fittingSize.width ?? 0
        return NSSize(width: stackWidth + 24, height: 32)
    }

    private func updateColors() {
        if isAccent {
            normalBackgroundColor = NSColor.white.withAlphaComponent(0.15)
            hoverBackgroundColor = NSColor.white.withAlphaComponent(0.25)
            normalBorderColor = NSColor.white.withAlphaComponent(0.3)
            hoverBorderColor = NSColor.white.withAlphaComponent(0.5)
        }
        self.layer?.backgroundColor = normalBackgroundColor.cgColor
        self.layer?.borderColor = normalBorderColor.cgColor
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea = trackingArea {
            self.removeTrackingArea(trackingArea)
        }
        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeAlways]
        let area = NSTrackingArea(rect: self.bounds, options: options, owner: self, userInfo: nil)
        self.addTrackingArea(area)
        self.trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        guard isEnabled else { return }
        super.mouseEntered(with: event)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            self.layer?.backgroundColor = hoverBackgroundColor.cgColor
            self.layer?.borderColor = hoverBorderColor.cgColor
        }
    }

    override func mouseExited(with event: NSEvent) {
        guard isEnabled else { return }
        super.mouseExited(with: event)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            self.layer?.backgroundColor = normalBackgroundColor.cgColor
            self.layer?.borderColor = normalBorderColor.cgColor
        }
    }
}
