import Cocoa
import NerwCore

public class ExtensionInstallWindowController: NSWindowController {
    private var packageURL: URL?
    private var manifest: ExtensionManifest?

    // UI Elements
    private let iconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let idLabel = NSTextField(labelWithString: "")
    private let descriptionLabel = NSTextField(labelWithString: "")
    private let installButton = NSButton(title: "Install Extension", target: nil, action: nil)
    private let cancelButton = NSButton(title: "Cancel", target: nil, action: nil)

    public convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Install Extension"
        window.center()
        self.init(window: window)
        setupUI()
    }

    private func setupUI() {
        guard let window = window else { return }
        let contentView = window.contentView!

        // Icon
        iconView.image = NSImage(
            systemSymbolName: "puzzlepiece.extension", accessibilityDescription: "Extension")
        iconView.symbolConfiguration = .init(pointSize: 48, weight: .regular)
        iconView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(iconView)

        // Title
        titleLabel.font = .systemFont(ofSize: 18, weight: .bold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)

        // ID
        idLabel.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        idLabel.textColor = .secondaryLabelColor
        idLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(idLabel)

        // Description
        descriptionLabel.font = .systemFont(ofSize: 14)
        descriptionLabel.textColor = .labelColor
        descriptionLabel.maximumNumberOfLines = 5
        descriptionLabel.cell?.wraps = true
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(descriptionLabel)

        // Buttons
        installButton.bezelStyle = .rounded
        installButton.target = self
        installButton.action = #selector(installClicked)
        installButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(installButton)

        cancelButton.bezelStyle = .rounded
        cancelButton.title = "Cancel"
        cancelButton.target = self
        cancelButton.action = #selector(cancelClicked)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(cancelButton)

        // Layout
        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            iconView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 30),

            titleLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 16),

            idLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            idLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),

            descriptionLabel.topAnchor.constraint(equalTo: idLabel.bottomAnchor, constant: 16),
            descriptionLabel.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor, constant: 30),
            descriptionLabel.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor, constant: -30),
            descriptionLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),

            installButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
            installButton.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor, constant: -20),

            cancelButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
            cancelButton.trailingAnchor.constraint(
                equalTo: installButton.leadingAnchor, constant: -12),
        ])
    }

    public func show(for url: URL, manifest: ExtensionManifest) {
        self.packageURL = url
        self.manifest = manifest

        titleLabel.stringValue = manifest.name
        idLabel.stringValue = manifest.id
        descriptionLabel.stringValue = manifest.description

        self.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window?.makeKeyAndOrderFront(nil)
    }

    @objc private func installClicked() {
        guard let url = packageURL else { return }

        do {
            try ExtensionInstaller.shared.installPackage(at: url)

            let alert = NSAlert()
            alert.messageText = "Extension Installed"
            alert.informativeText = "\(manifest?.name ?? "Extension") was installed successfully."
            alert.addButton(withTitle: "OK")
            alert.runModal()

            self.close()
        } catch {
            let alert = NSAlert()
            alert.messageText = "Installation Failed"
            alert.informativeText = error.localizedDescription
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    @objc private func cancelClicked() {
        self.close()
    }
}
