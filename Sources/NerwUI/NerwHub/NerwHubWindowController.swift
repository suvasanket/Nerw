import Cocoa
import NerwCore

public class NerwHubWindowController: NSWindowController {

    public static let shared = NerwHubWindowController()

    private var nerwViewController: NerwHubViewController!
    private var panel: NerwHubPanel!

    public init() {
        super.init(window: nil)
        setupPanel()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupPanel() {
        panel = NerwHubPanel(
            contentRect: NSRect(x: 0, y: 0, width: 960, height: 640),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false

        nerwViewController = NerwHubViewController()
        nerwViewController.onDismiss = { [weak self] in
            self?.hide()
        }
        panel.contentViewController = nerwViewController

        panel.resignHandler = { [weak self] in
            self?.hide()
        }

        self.window = panel

        NotificationCenter.default.addObserver(
            self, selector: #selector(configDidUpdate),
            name: Notification.Name("NerwConfigDidUpdate"),
            object: nil)
    }

    @objc private func configDidUpdate() {
        DispatchQueue.main.async {
            self.applyLayout()
            self.panel.contentView?.needsLayout = true
        }
    }

    private func applyLayout() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }

        let visualSize = NSSize(width: 900, height: 600)
        let exactOrig = NerwPanelContext.shared.exactOrigin(
            forSize: visualSize, in: screen.visibleFrame)

        // Window allows 30px overlap horizontally and 20px vertically
        let windowOrig = NSPoint(x: exactOrig.x - 30, y: exactOrig.y - 20)
        let windowSize = NSSize(width: 960, height: 640)

        panel.setContentSize(windowSize)
        panel.setFrameOrigin(windowOrig)
    }

    public func show(tab: NerwHubTab = .memory) {
        applyLayout()
        panel.makeKeyAndOrderFront(nil)
        _ = nerwViewController.view

        nerwViewController.selectTab(tab)
        nerwViewController.playIntroAnimation()
    }

    public func hide() {
        panel.close()
    }
}
