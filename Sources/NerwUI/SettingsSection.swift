import Cocoa

/// A reusable component for a settings section.
/// Displays a title label above a rounded, semi-transparent background container
/// that holds the section's content.
class SettingsSection: NSStackView {

    private let containerView: NSView = {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.cornerRadius = 16  // Increased roundedness
        view.layer?.backgroundColor = NSColor.quaternaryLabelColor.cgColor
        return view
    }()

    private let contentStack: NSStackView = {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        // Increased padding
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        return stack
    }()

    init(title: String, contentViews: [NSView]) {
        super.init(frame: .zero)

        self.orientation = .vertical
        self.alignment = .leading
        self.spacing = 0  // No spacing needed outside container

        // Container
        self.addArrangedSubview(containerView)

        // Content Stack inside Container
        containerView.addSubview(contentStack)
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: containerView.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),

            // Force container to match width of the stack view (self)
            containerView.widthAnchor.constraint(equalTo: self.widthAnchor),
        ])

        // Title (Inside container now)
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = .labelColor

        contentStack.addArrangedSubview(titleLabel)

        // Add content
        for view in contentViews {
            contentStack.addArrangedSubview(view)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Adds a view to the section's content area
    func addContent(_ view: NSView) {
        contentStack.addArrangedSubview(view)
    }
}
