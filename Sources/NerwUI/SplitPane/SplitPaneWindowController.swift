import Cocoa
import NerwSearchBackend

class SplitPanel: NSPanel {
    var resignHandler: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func resignKey() {
        super.resignKey()
        resignHandler?()
    }

    override func cancelOperation(_ sender: Any?) {
        resignHandler?()
    }
}

public class SplitPaneWindowController: NSObject {
    private var panel: SplitPanel!
    private var contentViewController: SplitPaneViewController!

    public var isVisible: Bool {
        return panel != nil && panel.isVisible
    }

    public init(
        title: String,
        icon: NSImage? = nil,
        dataSource: SplitPaneDataSource,
        delegate: SplitPaneDelegate
    ) {
        super.init()
        contentViewController = SplitPaneViewController(
            title: title, icon: icon, dataSource: dataSource, delegate: delegate)
        setupPanel()
    }

    private func setupPanel() {
        let metricsWidth: CGFloat = 800
        let metricsHeight: CGFloat = 450

        panel = SplitPanel(
            contentRect: NSRect(x: 0, y: 0, width: metricsWidth, height: metricsHeight),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        panel.contentViewController = contentViewController
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        panel.resignHandler = { [weak self] in
            if self?.panel.isVisible == true {
                self?.hide()
                self?.contentViewController.delegate?.didCancel()
            }
        }
    }

    public func show() {
        guard let screen = NSScreen.main else { return }

        // Use a wider default size to better fit the side-by-side layout
        let width: CGFloat = 750
        let height: CGFloat = 480
        let size = NSSize(width: width, height: height)
        let exactOrig = NerwPanelContext.shared.exactOrigin(forSize: size, in: screen.visibleFrame)

        panel.setContentSize(size)
        panel.setFrameOrigin(exactOrig)

        panel.makeKeyAndOrderFront(nil)
        contentViewController.reloadData()
    }

    public func hide() {
        if panel.isVisible {
            panel.orderOut(nil)

            let isFocusStayingInApp = NSApp.windows.contains {
                $0.isVisible && $0.isKeyWindow && $0 != panel
            }
            if !isFocusStayingInApp {
                NSApp.hide(nil)
            }
        }
    }

    public func reloadData() {
        contentViewController.reloadData()
    }
}
