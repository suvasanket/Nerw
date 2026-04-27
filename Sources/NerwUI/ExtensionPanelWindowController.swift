import Cocoa
import NerwCore

/// A lightweight panel created by an extension to display content using the host's UI framework.
/// Uses the same dimensions and positioning as the main panel.
class ExtensionContentPanel: NSPanel {
    var resignHandler: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func resignKey() {
        super.resignKey()

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.resignHandler?()
        }
    }

    override func cancelOperation(_ sender: Any?) {
        resignHandler?()
    }
}

public class ExtensionPanelWindowController: NSObject {
    private var panel: ExtensionContentPanel!
    private var panelView: NerwPanelView!
    private var titleLabel: NSTextField!
    private var contentLabel: NSTextField!

    public override init() {
        super.init()
        setupPanel()
    }

    private func setupPanel() {
        let width = GlobalLayout.mainWidth
        let height = GlobalLayout.mainHeight

        panel = NerwPanelFactory.makePanel(
            type: ExtensionContentPanel.self,
            contentRect: NSRect(x: 0, y: 0, width: width, height: height)
        )

        // Setup content
        panelView = NerwPanelView(style: .main)
        panelView.translatesAutoresizingMaskIntoConstraints = false

        let container = NSView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        container.wantsLayer = true
        container.addSubview(panelView)

        NSLayoutConstraint.activate([
            panelView.topAnchor.constraint(equalTo: container.topAnchor),
            panelView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            panelView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            panelView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        let contentView = panelView.contentView

        // Title Label
        titleLabel = NSTextField(labelWithString: "")
        titleLabel.font = .systemFont(ofSize: GlobalLayout.fontSizeSearch, weight: .semibold)
        titleLabel.textColor = .labelColor
        titleLabel.alignment = .center
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.maximumNumberOfLines = 1
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)

        // Content Label
        contentLabel = NSTextField(labelWithString: "")
        contentLabel.font = .systemFont(ofSize: GlobalLayout.fontSizeResultTitle, weight: .regular)
        contentLabel.textColor = .secondaryLabelColor
        contentLabel.alignment = .center
        contentLabel.lineBreakMode = .byWordWrapping
        contentLabel.maximumNumberOfLines = 0
        contentLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(contentLabel)

        let margin = GlobalLayout.horizontalMargin

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 28),
            titleLabel.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor, constant: margin),
            titleLabel.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor, constant: -margin),

            contentLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            contentLabel.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor, constant: margin),
            contentLabel.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor, constant: -margin),
        ])

        // Apply theming to labels
        applyTheming()

        panel.contentView = container

        panel.resignHandler = { [weak self] in
            self?.hide()
        }

        NotificationCenter.default.addObserver(
            self, selector: #selector(configDidUpdate),
            name: Notification.Name("NerwConfigDidUpdate"),
            object: nil)
    }

    @objc private func configDidUpdate() {
        DispatchQueue.main.async {
            self.applyTheming()
            self.applyLayout()
        }
    }

    private func applyTheming() {
        let config = ConfigManager.shared.config.uiConfig

        if let fontName = config?.font {
            if let titleFont = NSFont(name: fontName, size: GlobalLayout.fontSizeSearch) {
                titleLabel.font = titleFont
            }
            if let bodyFont = NSFont(name: fontName, size: GlobalLayout.fontSizeResultTitle) {
                contentLabel.font = bodyFont
            }
        }

        if let fgHex = config?.mainForegroundColor, let fgColor = NSColor(hex: fgHex) {
            titleLabel.textColor = fgColor
            contentLabel.textColor = fgColor.withAlphaComponent(0.7)
        } else {
            titleLabel.textColor = .labelColor
            contentLabel.textColor = .secondaryLabelColor
        }
    }

    private func applyLayout() {
        guard panel.isVisible else { return }
        let size = NSSize(width: GlobalLayout.mainWidth, height: GlobalLayout.mainHeight)
        panel.setContentSize(size)

        if let screen = NSScreen.main {
            let origin = NerwPanelContext.shared.exactOrigin(
                forSize: size, in: screen.visibleFrame)
            panel.setFrameOrigin(origin)
        }
    }

    public func show(title: String, content: String) {
        titleLabel.stringValue = title
        contentLabel.stringValue = content

        guard let screen = NSScreen.main else { return }

        let width = GlobalLayout.mainWidth
        let height = GlobalLayout.mainHeight
        let size = NSSize(width: width, height: height)
        let origin = NerwPanelContext.shared.exactOrigin(forSize: size, in: screen.visibleFrame)

        panel.setContentSize(size)
        panel.setFrameOrigin(origin)
        panel.makeKeyAndOrderFront(nil)
    }

    public func hide() {
        guard panel.isVisible else { return }
        panel.orderOut(nil)

        let isFocusStayingInApp = NSApp.windows.contains {
            $0.isVisible && $0.isKeyWindow && $0 != panel
        }
        if !isFocusStayingInApp {
            NSApp.hide(nil)
        }
    }
}
