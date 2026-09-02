import Cocoa
import NerwCore

public class NerwHubWindowController: NSWindowController, NSWindowDelegate {

    public static let shared = NerwHubWindowController()

    private var nerwViewController: NerwHubViewController!
    private var hubWindow: NerwHubWindow!

    public init() {
        super.init(window: nil)
        setupWindow()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupWindow() {
        let initialSize = NSSize(width: 920, height: 580)
        hubWindow = NerwHubWindow(
            contentRect: NSRect(origin: .zero, size: initialSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        hubWindow.titlebarAppearsTransparent = true
        hubWindow.titleVisibility = .hidden
        hubWindow.isMovableByWindowBackground = true
        hubWindow.minSize = NSSize(width: 740, height: 440)
        hubWindow.maxSize = NSSize(width: 1040, height: 740)
        hubWindow.isReleasedWhenClosed = false
        hubWindow.center()

        nerwViewController = NerwHubViewController()
        nerwViewController.onDismiss = { [weak self] in
            self?.hide()
        }
        hubWindow.contentViewController = nerwViewController

        hubWindow.resignHandler = {
            // Keep window open when switching apps unless user explicitly closes with Cmd+W / Esc / close button
        }

        self.window = hubWindow
        hubWindow.delegate = self
    }

    public func show(tab: NerwHubTab = .memory) {
        if window == nil {
            setupWindow()
        }

        NSApp.activate(ignoringOtherApps: true)
        hubWindow.makeKeyAndOrderFront(nil)
        _ = nerwViewController.view

        nerwViewController.selectTab(tab)
    }

    public func hide() {
        hubWindow.orderOut(nil)
    }

    public func windowWillClose(_ notification: Notification) {
        // Window closed
    }
}
