import Cocoa
import NerwCore

class ExtensionSettingsViewController: NSViewController {

    private let scrollView = NSScrollView()
    private let stackView = FlippedStackView()
    private var extensions: [ExtensionManifest] = []

    override func loadView() {
        self.view = NSView()
        self.view.wantsLayer = true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        reloadData()

        NotificationCenter.default.addObserver(
            self, selector: #selector(extensionsDidUpdate),
            name: Notification.Name("NerwExtensionsDidUpdate"), object: nil)
    }

    @objc private func extensionsDidUpdate() {
        DispatchQueue.main.async {
            self.reloadData()
        }
    }

    private func setupUI() {
        // Scroll View
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false

        // Ensure scroll view allows document to grow
        scrollView.documentView = stackView

        view.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        // Stack View
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.orientation = .vertical
        stackView.alignment = .centerX
        stackView.spacing = 16
        stackView.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)

        // Constrain stack view width to scroll view width
        // We use scrollView.contentView which is the clip view
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
            stackView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),
            // Do NOT constrain bottom or height, let it grow
        ])
    }

    private func reloadData() {
        // clear existing
        // clear existing
        for subview in stackView.arrangedSubviews {
            subview.removeFromSuperview()
        }

        extensions = ExtensionEngine.shared.extensions

        if extensions.isEmpty {
            let emptyLabel = NSTextField(labelWithString: "No extensions installed")
            emptyLabel.textColor = .secondaryLabelColor
            stackView.addArrangedSubview(emptyLabel)
            return
        }

        for ext in extensions {
            let card = ExtensionCardView(extensionManifest: ext)
            card.translatesAutoresizingMaskIntoConstraints = false

            // Handle uninstall
            card.onUninstall = { [weak self] in
                self?.confirmUninstall(for: ext)
            }

            stackView.addArrangedSubview(card)

            // Constrain width to fill stack view minus padding
            NSLayoutConstraint.activate([
                card.widthAnchor.constraint(equalTo: stackView.widthAnchor, constant: -40)
            ])
        }
    }

    private func confirmUninstall(for ext: ExtensionManifest) {
        let alert = NSAlert()
        alert.messageText = "Uninstall \(ext.name)?"
        alert.informativeText =
            "Are you sure you want to remove this extension? This cannot be undone."
        alert.addButton(withTitle: "Uninstall")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            do {
                try ExtensionInstaller.shared.uninstall(id: ext.id)
                // Reload will be triggered by notification, but we can also optimize or wait
                // ReloadData is called by notification observer
            } catch {
                let errAlert = NSAlert()
                errAlert.messageText = "Error"
                errAlert.informativeText = error.localizedDescription
                errAlert.runModal()
            }
        }
    }
}

class FlippedStackView: NSStackView {
    override var isFlipped: Bool {
        return true
    }
}
