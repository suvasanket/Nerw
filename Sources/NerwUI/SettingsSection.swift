import Cocoa

/// A reusable component for a settings section.
/// Displays a title label above a rounded, semi-transparent background container
/// that holds the section's content.
class SettingsSection: NSStackView {

    private let containerView: NSView = {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.cornerRadius = 16
        view.layer?.backgroundColor = NSColor.quaternaryLabelColor.cgColor
        return view
    }()

    private let mainStack: NSStackView = {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 0
        return stack
    }()

    private let headerStack: NSStackView = {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        return stack
    }()

    private let contentStack: NSStackView = {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 0, left: 16, bottom: 16, right: 16)
        stack.isHidden = false
        return stack
    }()

    private let chevronImageView: NSImageView = {
        let imageView = NSImageView()
        imageView.image = NSImage(
            systemSymbolName: "chevron.down", accessibilityDescription: "Toggle Section")
        imageView.contentTintColor = .secondaryLabelColor
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.widthAnchor.constraint(equalToConstant: 12).isActive = true
        imageView.heightAnchor.constraint(equalToConstant: 12).isActive = true
        return imageView
    }()

    private var isExpanded: Bool = true {
        didSet {
            updateState()
        }
    }

    private var onExpand: (() -> Void)?
    private var hasLoadedContent: Bool = false

    init(
        title: String, contentViews: [NSView] = [], isCollapsable: Bool = false,
        isExpanded: Bool = true,
        onExpand: (() -> Void)? = nil
    ) {
        self.isExpanded = isExpanded
        self.onExpand = onExpand
        self.hasLoadedContent = (onExpand == nil) || !contentViews.isEmpty
        super.init(frame: .zero)

        self.orientation = .vertical
        self.alignment = .leading
        self.spacing = 0

        // Container
        self.addArrangedSubview(containerView)
        containerView.addSubview(mainStack)
        mainStack.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: containerView.topAnchor),
            mainStack.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            mainStack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            mainStack.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            containerView.widthAnchor.constraint(equalTo: self.widthAnchor),
        ])

        // Header
        mainStack.addArrangedSubview(headerStack)
        headerStack.widthAnchor.constraint(equalTo: mainStack.widthAnchor).isActive = true

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = .labelColor
        headerStack.addArrangedSubview(titleLabel)

        if isCollapsable {
            headerStack.addArrangedSubview(chevronImageView)

            // Make header clickable
            let clickGesture = NSClickGestureRecognizer(
                target: self, action: #selector(toggleSection))
            headerStack.addGestureRecognizer(clickGesture)
        }

        headerStack.addArrangedSubview(NSView())  // Spacer to push everything to the left

        // Content
        mainStack.addArrangedSubview(contentStack)
        contentStack.widthAnchor.constraint(equalTo: mainStack.widthAnchor).isActive = true

        for view in contentViews {
            contentStack.addArrangedSubview(view)
            view.widthAnchor.constraint(equalTo: contentStack.widthAnchor, constant: -32).isActive =
                true
        }

        if isCollapsable && !isExpanded {
            contentStack.isHidden = true
            chevronImageView.image = NSImage(
                systemSymbolName: "chevron.right",
                accessibilityDescription: "Toggle Section")
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func toggleSection() {
        if !isExpanded && !hasLoadedContent {
            onExpand?()
            hasLoadedContent = true
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            context.allowsImplicitAnimation = true
            self.isExpanded.toggle()
            self.window?.layoutIfNeeded()
        }
    }

    private func updateState() {
        contentStack.isHidden = !isExpanded
        chevronImageView.image = NSImage(
            systemSymbolName: isExpanded ? "chevron.down" : "chevron.right",
            accessibilityDescription: "Toggle Section")
    }

    /// Adds a view to the section's content area
    func addContent(_ view: NSView) {
        contentStack.addArrangedSubview(view)
        view.widthAnchor.constraint(equalTo: contentStack.widthAnchor, constant: -32).isActive =
            true
    }

    /// Triggers the lazy loading of content if not loaded already
    func loadContentIfNeeded() {
        if !hasLoadedContent {
            onExpand?()
            hasLoadedContent = true
        }
    }
}
