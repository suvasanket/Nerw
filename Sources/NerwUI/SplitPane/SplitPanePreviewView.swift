import Cocoa

class SplitPanePreviewView: NSView {
    private let scrollView = NSScrollView()
    private let textView = NSTextView()
    private let imageView = NSImageView()
    private let emptyLabel = NSTextField(labelWithString: "No preview available")

    private let bottomActionStack = NSStackView()
    private let subtitleLabel = NSTextField(labelWithString: "")
    private let timeAgoLabel = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }

    private func setupViews() {
        wantsLayer = true
        // Match the slight bright background of Peek
        layer?.backgroundColor = NSColor.white.withAlphaComponent(0.12).cgColor
        layer?.cornerRadius = 16
        layer?.masksToBounds = true
        layer?.borderColor = NSColor.white.withAlphaComponent(0.12).cgColor
        layer?.borderWidth = 0.5

        // Setup empty label
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyLabel.textColor = .tertiaryLabelColor
        emptyLabel.font = .systemFont(ofSize: 14)
        addSubview(emptyLabel)

        // Setup text view
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        scrollView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)

        textView.backgroundColor = .clear
        textView.isEditable = false
        textView.isSelectable = false
        textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.textColor = .labelColor
        textView.textContainerInset = NSSize(width: 16, height: 16)

        textView.autoresizingMask = [.width]
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true

        scrollView.documentView = textView
        addSubview(scrollView)

        // Setup image view
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        addSubview(imageView)

        // Setup bottom action stack
        bottomActionStack.orientation = .horizontal
        bottomActionStack.translatesAutoresizingMaskIntoConstraints = false
        bottomActionStack.edgeInsets = NSEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)

        // Blur background for bottom stack
        let blur = NSVisualEffectView()
        blur.material = .hudWindow
        blur.state = .active
        blur.translatesAutoresizingMaskIntoConstraints = false
        addSubview(blur)

        subtitleLabel.font = .systemFont(ofSize: 12, weight: .medium)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.lineBreakMode = .byTruncatingTail
        bottomActionStack.addArrangedSubview(subtitleLabel)

        // Spacer
        bottomActionStack.addArrangedSubview(NSView())

        timeAgoLabel.font = .systemFont(ofSize: 12, weight: .regular)
        timeAgoLabel.textColor = .tertiaryLabelColor
        bottomActionStack.addArrangedSubview(timeAgoLabel)

        addSubview(bottomActionStack)

        NSLayoutConstraint.activate([
            emptyLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: blur.topAnchor),

            imageView.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            imageView.bottomAnchor.constraint(equalTo: blur.topAnchor, constant: -16),

            blur.leadingAnchor.constraint(equalTo: leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: trailingAnchor),
            blur.bottomAnchor.constraint(equalTo: bottomAnchor),
            blur.heightAnchor.constraint(equalToConstant: 40),

            bottomActionStack.leadingAnchor.constraint(equalTo: blur.leadingAnchor),
            bottomActionStack.trailingAnchor.constraint(equalTo: blur.trailingAnchor),
            bottomActionStack.topAnchor.constraint(equalTo: blur.topAnchor),
            bottomActionStack.bottomAnchor.constraint(equalTo: blur.bottomAnchor),
        ])
    }

    func configure(with item: SplitPaneItem?) {
        guard let item = item else {
            scrollView.isHidden = true
            imageView.isHidden = true
            emptyLabel.isHidden = false
            imageView.image = nil
            subtitleLabel.stringValue = ""
            timeAgoLabel.stringValue = ""
            return
        }

        emptyLabel.isHidden = true
        subtitleLabel.stringValue = item.subtitle ?? ""

        if let ts = item.timestamp {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .full
            timeAgoLabel.stringValue = formatter.localizedString(for: ts, relativeTo: Date())
        } else {
            timeAgoLabel.stringValue = ""
        }

        if let path = item.previewImagePath, let img = NSImage(contentsOfFile: path) {
            scrollView.isHidden = true
            imageView.isHidden = false
            imageView.image = img
        } else if let text = item.previewText {
            imageView.isHidden = true
            scrollView.isHidden = false
            textView.string = text
        } else {
            scrollView.isHidden = true
            imageView.isHidden = true
            emptyLabel.isHidden = false
            imageView.image = nil
        }
    }
}
