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
    private var installButton: CustomActionButton!
    private var cancelButton: CustomActionButton!

    public convenience init() {
        let window = InstallWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 320),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.title = "Install Extension"
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.level = .floating
        window.isMovableByWindowBackground = true
        window.center()
        self.init(window: window)
        setupUI()
    }

    private func setupUI() {
        guard let window = window else { return }
        let contentView = window.contentView!

        // Background - NSVisualEffectView for frosted glass (Glassmorphic)
        let backgroundView = NSVisualEffectView()
        backgroundView.material = .fullScreenUI
        backgroundView.appearance = NSAppearance(named: .vibrantDark)
        backgroundView.blendingMode = .behindWindow
        backgroundView.state = .active
        backgroundView.wantsLayer = true
        backgroundView.layer?.cornerRadius = 24
        backgroundView.layer?.masksToBounds = true
        backgroundView.layer?.borderColor = NSColor.white.withAlphaComponent(0.18).cgColor
        backgroundView.layer?.borderWidth = 1.0
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(backgroundView)

        // Tint View - Light overlay for frosted glass depth
        let tintView = NSView()
        tintView.wantsLayer = true
        tintView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.15).cgColor
        tintView.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.addSubview(tintView)

        // Inner highlight edge - subtle white glow for liquid glass feel
        let innerGlow = NSView()
        innerGlow.wantsLayer = true
        innerGlow.layer?.cornerRadius = 23
        innerGlow.layer?.borderColor = NSColor.white.withAlphaComponent(0.06).cgColor
        innerGlow.layer?.borderWidth = 1.0
        innerGlow.layer?.masksToBounds = true
        innerGlow.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.addSubview(innerGlow)

        // Constraints for Background layers
        NSLayoutConstraint.activate([
            backgroundView.topAnchor.constraint(equalTo: contentView.topAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            tintView.topAnchor.constraint(equalTo: backgroundView.topAnchor),
            tintView.leadingAnchor.constraint(equalTo: backgroundView.leadingAnchor),
            tintView.trailingAnchor.constraint(equalTo: backgroundView.trailingAnchor),
            tintView.bottomAnchor.constraint(equalTo: backgroundView.bottomAnchor),

            innerGlow.topAnchor.constraint(equalTo: backgroundView.topAnchor, constant: 1),
            innerGlow.leadingAnchor.constraint(equalTo: backgroundView.leadingAnchor, constant: 1),
            innerGlow.trailingAnchor.constraint(
                equalTo: backgroundView.trailingAnchor, constant: -1),
            innerGlow.bottomAnchor.constraint(equalTo: backgroundView.bottomAnchor, constant: -1),
        ])

        // Icon
        iconView.image = NSImage(
            systemSymbolName: "puzzlepiece.extension", accessibilityDescription: "Extension")
        iconView.symbolConfiguration = .init(pointSize: 48, weight: .regular)
        iconView.contentTintColor = .white
        iconView.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.addSubview(iconView)

        // Title
        titleLabel.font = .systemFont(ofSize: 22, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.addSubview(titleLabel)

        // ID
        idLabel.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        idLabel.textColor = NSColor.white.withAlphaComponent(0.6)
        idLabel.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.addSubview(idLabel)

        // Description
        descriptionLabel.font = .systemFont(ofSize: 14)
        descriptionLabel.textColor = NSColor.white.withAlphaComponent(0.8)
        descriptionLabel.maximumNumberOfLines = 5
        descriptionLabel.cell?.wraps = true
        descriptionLabel.alignment = .center
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.addSubview(descriptionLabel)

        // Buttons
        installButton = CustomActionButton(
            title: "Install",
            shortcutText: nil,
            shortcutIcon: "return",
            isPrimary: true,
            target: self,
            action: #selector(installClicked)
        )
        backgroundView.addSubview(installButton)

        cancelButton = CustomActionButton(
            title: "Cancel",
            shortcutText: nil,
            shortcutIcon: "escape",
            isPrimary: false,
            target: self,
            action: #selector(cancelClicked)
        )
        backgroundView.addSubview(cancelButton)

        // Layout
        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: backgroundView.centerXAnchor),
            iconView.topAnchor.constraint(equalTo: backgroundView.topAnchor, constant: 36),

            titleLabel.centerXAnchor.constraint(equalTo: backgroundView.centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 16),

            idLabel.centerXAnchor.constraint(equalTo: backgroundView.centerXAnchor),
            idLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),

            descriptionLabel.topAnchor.constraint(equalTo: idLabel.bottomAnchor, constant: 16),
            descriptionLabel.leadingAnchor.constraint(
                equalTo: backgroundView.leadingAnchor, constant: 30),
            descriptionLabel.trailingAnchor.constraint(
                equalTo: backgroundView.trailingAnchor, constant: -30),
            descriptionLabel.centerXAnchor.constraint(equalTo: backgroundView.centerXAnchor),

            installButton.bottomAnchor.constraint(
                equalTo: backgroundView.bottomAnchor, constant: -24),
            installButton.trailingAnchor.constraint(
                equalTo: backgroundView.trailingAnchor, constant: -24),

            cancelButton.bottomAnchor.constraint(
                equalTo: backgroundView.bottomAnchor, constant: -24),
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

        if let win = self.window as? InstallWindow {
            win.installAction = { [weak self] in self?.installClicked() }
            win.cancelAction = { [weak self] in self?.cancelClicked() }
        }

        self.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window?.makeKeyAndOrderFront(nil)
    }

    @objc private func installClicked() {
        guard let url = packageURL else { return }

        let manifestName = manifest?.name ?? "Extension"

        // 1. Close Window immediately
        self.close()

        // 2. Show progressive notification
        let notifId = NerwNotificationManager.shared.show(
            content: "Installing \(manifestName)...", level: .info, progressive: true)

        // 3. Compile and Install asynchronously
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try ExtensionInstaller.shared.installPackage(at: url)

                DispatchQueue.main.async {
                    NerwNotificationManager.shared.dismiss(id: notifId)
                    NerwNotificationManager.shared.show(
                        content: "\(manifestName) Installed", level: .info)
                }
            } catch {
                DispatchQueue.main.async {
                    NerwNotificationManager.shared.dismiss(id: notifId)
                    NerwNotificationManager.shared.show(
                        content: "Failed to install \(manifestName): \(error.localizedDescription)",
                        level: .error)
                }
            }
        }
    }

    @objc private func cancelClicked() {
        self.close()
    }
}

private class InstallWindow: NSWindow {
    override var canBecomeKey: Bool { return true }
    override var canBecomeMain: Bool { return true }

    var installAction: (() -> Void)?
    var cancelAction: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 36 {  // Enter
            installAction?()
        } else if event.keyCode == 53 {  // Esc
            cancelAction?()
        } else {
            super.keyDown(with: event)
        }
    }
}

private class CustomActionButton: NSControl {
    var isPrimary: Bool
    private var baseColor: NSColor
    private var hoverColor: NSColor
    private var clickColor: NSColor
    private var trackingArea: NSTrackingArea?
    private var backgroundLayer: CALayer?

    init(
        title: String, shortcutText: String?, shortcutIcon: String?, isPrimary: Bool,
        target: AnyObject?, action: Selector?
    ) {
        self.isPrimary = isPrimary
        if isPrimary {
            self.baseColor = NSColor.systemBlue.withAlphaComponent(0.4)
            self.hoverColor = NSColor.systemBlue.withAlphaComponent(0.6)
            self.clickColor = NSColor.systemBlue.withAlphaComponent(0.8)
        } else {
            self.baseColor = .clear
            self.hoverColor = NSColor.white.withAlphaComponent(0.1)
            self.clickColor = NSColor.white.withAlphaComponent(0.2)
        }

        super.init(frame: .zero)
        self.target = target
        self.action = action

        setup(title: title, shortcutText: shortcutText, shortcutIcon: shortcutIcon)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setup(title: String, shortcutText: String?, shortcutIcon: String?) {
        self.translatesAutoresizingMaskIntoConstraints = false
        self.wantsLayer = true
        self.layer?.cornerRadius = 8

        if isPrimary {
            let effect = NSVisualEffectView()
            effect.material = .popover
            effect.state = .active
            effect.blendingMode = .withinWindow
            effect.wantsLayer = true
            effect.layer?.cornerRadius = 8
            effect.layer?.masksToBounds = true
            effect.translatesAutoresizingMaskIntoConstraints = false
            self.addSubview(effect)

            let tint = NSView()
            tint.wantsLayer = true
            tint.layer?.backgroundColor = baseColor.cgColor
            tint.translatesAutoresizingMaskIntoConstraints = false
            effect.addSubview(tint)
            self.backgroundLayer = tint.layer

            let border = NSView()
            border.wantsLayer = true
            border.layer?.cornerRadius = 8
            border.layer?.borderWidth = 1.0
            border.layer?.borderColor = NSColor.white.withAlphaComponent(0.15).cgColor
            border.translatesAutoresizingMaskIntoConstraints = false
            effect.addSubview(border)

            NSLayoutConstraint.activate([
                effect.topAnchor.constraint(equalTo: self.topAnchor),
                effect.leadingAnchor.constraint(equalTo: self.leadingAnchor),
                effect.trailingAnchor.constraint(equalTo: self.trailingAnchor),
                effect.bottomAnchor.constraint(equalTo: self.bottomAnchor),

                tint.topAnchor.constraint(equalTo: effect.topAnchor),
                tint.leadingAnchor.constraint(equalTo: effect.leadingAnchor),
                tint.trailingAnchor.constraint(equalTo: effect.trailingAnchor),
                tint.bottomAnchor.constraint(equalTo: effect.bottomAnchor),

                border.topAnchor.constraint(equalTo: effect.topAnchor),
                border.leadingAnchor.constraint(equalTo: effect.leadingAnchor),
                border.trailingAnchor.constraint(equalTo: effect.trailingAnchor),
                border.bottomAnchor.constraint(equalTo: effect.bottomAnchor),
            ])
        } else {
            self.layer?.backgroundColor = baseColor.cgColor
            self.layer?.borderColor = NSColor.white.withAlphaComponent(0.2).cgColor
            self.layer?.borderWidth = 1.0
            self.backgroundLayer = self.layer
        }

        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 0, left: 14, bottom: 0, right: 10)
        stack.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(stack)

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 13, weight: .medium)
        titleLabel.textColor = .white
        titleLabel.isEditable = false
        titleLabel.isBordered = false
        titleLabel.drawsBackground = false
        stack.addArrangedSubview(titleLabel)

        let shortcutContainer = NSView()
        shortcutContainer.wantsLayer = true
        shortcutContainer.layer?.backgroundColor =
            isPrimary
            ? NSColor.white.withAlphaComponent(0.2).cgColor
            : NSColor.white.withAlphaComponent(0.1).cgColor
        shortcutContainer.layer?.cornerRadius = 4
        shortcutContainer.layer?.borderColor =
            isPrimary ? .clear : NSColor.white.withAlphaComponent(0.1).cgColor
        shortcutContainer.layer?.borderWidth = isPrimary ? 0 : 1.0
        shortcutContainer.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(shortcutContainer)

        let shortcutFg = NSColor.white.withAlphaComponent(0.7)

        if let text = shortcutText {
            let lbl = NSTextField(labelWithString: text)
            lbl.font = .systemFont(ofSize: 10, weight: .bold)
            lbl.textColor = shortcutFg
            lbl.isEditable = false
            lbl.isBordered = false
            lbl.drawsBackground = false
            lbl.translatesAutoresizingMaskIntoConstraints = false
            shortcutContainer.addSubview(lbl)
            NSLayoutConstraint.activate([
                lbl.centerXAnchor.constraint(equalTo: shortcutContainer.centerXAnchor),
                lbl.centerYAnchor.constraint(equalTo: shortcutContainer.centerYAnchor),
                shortcutContainer.widthAnchor.constraint(equalTo: lbl.widthAnchor, constant: 10),
                shortcutContainer.heightAnchor.constraint(equalTo: lbl.heightAnchor, constant: 4),
            ])
        } else if let iconName = shortcutIcon {
            let iv = NSImageView()
            iv.image = NSImage(systemSymbolName: iconName, accessibilityDescription: nil)
            iv.contentTintColor = shortcutFg
            iv.symbolConfiguration = .init(pointSize: 10, weight: .bold)
            iv.translatesAutoresizingMaskIntoConstraints = false
            shortcutContainer.addSubview(iv)
            NSLayoutConstraint.activate([
                iv.centerXAnchor.constraint(equalTo: shortcutContainer.centerXAnchor),
                iv.centerYAnchor.constraint(equalTo: shortcutContainer.centerYAnchor),
                shortcutContainer.widthAnchor.constraint(equalToConstant: 22),
                shortcutContainer.heightAnchor.constraint(equalToConstant: 18),
            ])
        }

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: self.topAnchor),
            stack.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: self.bottomAnchor),
            self.heightAnchor.constraint(equalToConstant: 34),
        ])
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea = trackingArea { removeTrackingArea(trackingArea) }
        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeAlways]
        trackingArea = NSTrackingArea(
            rect: self.bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(trackingArea!)
    }

    override func mouseEntered(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.1
            self.backgroundLayer?.backgroundColor = hoverColor.cgColor
        }
    }

    override func mouseExited(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            self.backgroundLayer?.backgroundColor = baseColor.cgColor
        }
    }

    override func mouseDown(with event: NSEvent) {
        self.backgroundLayer?.backgroundColor = clickColor.cgColor
    }

    override func mouseUp(with event: NSEvent) {
        let isInside = self.bounds.contains(self.convert(event.locationInWindow, from: nil))
        self.backgroundLayer?.backgroundColor = isInside ? hoverColor.cgColor : baseColor.cgColor
        if isInside {
            sendAction(action, to: target)
        }
    }
}
