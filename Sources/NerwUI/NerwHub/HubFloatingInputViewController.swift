import Cocoa

public class HubFloatingInputViewController: NSViewController, NSTextViewDelegate {
    public var onSave: ((String) -> Void)?
    public var onCancel: (() -> Void)?

    private let titleLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "")
    private let scrollView = NSScrollView()
    public let textView = NSTextView()
    private let effectView = NSVisualEffectView()

    public init() {
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 440, height: 260))
        setupViews()
    }

    private func setupViews() {
        effectView.translatesAutoresizingMaskIntoConstraints = false
        effectView.material = .fullScreenUI
        effectView.appearance = NSAppearance(named: .vibrantDark)
        effectView.blendingMode = .withinWindow
        effectView.state = .active
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = 16
        effectView.layer?.masksToBounds = true

        effectView.layer?.borderWidth = 1
        effectView.layer?.borderColor = NSColor.white.withAlphaComponent(0.15).cgColor

        // Add shadow
        view.wantsLayer = true
        view.shadow = NSShadow()
        view.layer?.shadowColor = NSColor.black.cgColor
        view.layer?.shadowOpacity = 0.5
        view.layer?.shadowRadius = 20
        view.layer?.shadowOffset = NSSize(width: 0, height: -10)

        view.addSubview(effectView)

        let containerStack = NSStackView()
        containerStack.translatesAutoresizingMaskIntoConstraints = false
        containerStack.orientation = .vertical
        containerStack.alignment = .leading
        containerStack.spacing = 16
        effectView.addSubview(containerStack)

        let headerStack = NSStackView()
        headerStack.orientation = .vertical
        headerStack.alignment = .leading
        headerStack.spacing = 4

        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        titleLabel.textColor = .labelColor
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        headerStack.addArrangedSubview(titleLabel)

        subtitleLabel.font = .systemFont(ofSize: 12, weight: .regular)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.cell?.wraps = true
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        headerStack.addArrangedSubview(subtitleLabel)

        containerStack.addArrangedSubview(headerStack)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false

        // Draw a light border around textview
        scrollView.wantsLayer = true
        scrollView.layer?.cornerRadius = 8
        scrollView.layer?.borderWidth = 1
        scrollView.layer?.borderColor = NSColor.white.withAlphaComponent(0.1).cgColor
        scrollView.contentInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)

        textView.delegate = self
        textView.font = .systemFont(ofSize: 14)
        textView.textColor = .labelColor
        textView.drawsBackground = false
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false

        textView.autoresizingMask = [.width]
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        if let container = textView.textContainer {
            container.widthTracksTextView = true
            container.containerSize = NSSize(
                width: scrollView.contentSize.width, height: .greatestFiniteMagnitude)
        }

        scrollView.documentView = textView
        containerStack.addArrangedSubview(scrollView)

        let footerLabel = NSTextField(
            labelWithString: "Press Enter to save, Esc to cancel. Shift+Enter for new line.")
        footerLabel.font = .systemFont(ofSize: 11)
        footerLabel.textColor = .tertiaryLabelColor
        footerLabel.translatesAutoresizingMaskIntoConstraints = false
        containerStack.addArrangedSubview(footerLabel)

        NSLayoutConstraint.activate([
            effectView.topAnchor.constraint(equalTo: view.topAnchor),
            effectView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            effectView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            effectView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            containerStack.topAnchor.constraint(equalTo: effectView.topAnchor, constant: 20),
            containerStack.bottomAnchor.constraint(equalTo: effectView.bottomAnchor, constant: -16),
            containerStack.leadingAnchor.constraint(
                equalTo: effectView.leadingAnchor, constant: 20),
            containerStack.trailingAnchor.constraint(
                equalTo: effectView.trailingAnchor, constant: -20),

            scrollView.widthAnchor.constraint(equalTo: containerStack.widthAnchor),
            scrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 120),
        ])
    }

    public func configure(title: String, subtitle: String, text: String) {
        titleLabel.stringValue = title
        subtitleLabel.stringValue = subtitle
        textView.string = text
    }

    public func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            let event = NSApp.currentEvent
            let isShiftPressed = event?.modifierFlags.contains(.shift) ?? false

            if isShiftPressed {
                // Let it insert a newline
                return false
            } else {
                // Submit
                onSave?(textView.string)
                return true
            }
        } else if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            onCancel?()
            return true
        }
        return false
    }
}
