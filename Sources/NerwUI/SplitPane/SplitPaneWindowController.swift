import Cocoa
import NerwCore
import NerwSearchBackend

class SplitPanel: NSPanel {
    var resignHandler: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func resignKey() {
        super.resignKey()

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let nextKey = NSApp.keyWindow, self.childWindows?.contains(nextKey) == true {
                return
            }
            self.resignHandler?()
        }
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
        let metricsWidth = GlobalLayout.mainWidth
        let metricsHeight = GlobalLayout.mainHeight

        panel = NerwPanelFactory.makePanel(
            type: SplitPanel.self,
            contentRect: NSRect(x: 0, y: 0, width: metricsWidth, height: metricsHeight)
        )

        panel.contentViewController = contentViewController

        panel.resignHandler = { [weak self] in
            if self?.panel.isVisible == true {
                self?.hide()
                self?.contentViewController.delegate?.didCancel()
            }
        }

        NotificationCenter.default.addObserver(
            self, selector: #selector(configDidUpdate),
            name: Notification.Name("NerwConfigDidUpdate"),
            object: nil)
    }

    @objc private func configDidUpdate() {
        DispatchQueue.main.async {
            self.applyLayout()
        }
    }

    private func applyLayout() {
        guard let panel = panel, panel.isVisible else { return }
        let size = NSSize(width: GlobalLayout.mainWidth, height: GlobalLayout.mainHeight)
        panel.setContentSize(size)

        if let screen = NSScreen.main {
            let exactOrig = NerwPanelContext.shared.exactOrigin(
                forSize: size, in: screen.visibleFrame)
            panel.setFrameOrigin(exactOrig)
        }
    }

    public func update(
        title: String, icon: NSImage?, dataSource: SplitPaneDataSource, delegate: SplitPaneDelegate
    ) {
        contentViewController.configure(
            title: title, icon: icon, dataSource: dataSource, delegate: delegate)
    }

    public func show() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }

        // Use a wider default size to better fit the side-by-side layout
        let width = GlobalLayout.mainWidth
        let height = GlobalLayout.mainHeight
        let size = NSSize(width: width, height: height)
        let exactOrig = NerwPanelContext.shared.exactOrigin(forSize: size, in: screen.visibleFrame)

        panel.setContentSize(size)
        panel.setFrameOrigin(exactOrig)

        panel.makeKeyAndOrderFront(nil)
        contentViewController.resetSelection()
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

public class SplitPaneManager {
    public static let shared = SplitPaneManager()

    private var windowController: SplitPaneWindowController?

    public var isVisible: Bool {
        return windowController?.isVisible == true
    }

    public func show(
        title: String, icon: NSImage?, dataSource: SplitPaneDataSource, delegate: SplitPaneDelegate
    ) {
        if windowController == nil {
            windowController = SplitPaneWindowController(
                title: title, icon: icon, dataSource: dataSource, delegate: delegate)
        } else {
            windowController?.update(
                title: title, icon: icon, dataSource: dataSource, delegate: delegate)
        }
        windowController?.show()
    }

    public func hide() {
        windowController?.hide()
    }

    public func reloadData() {
        windowController?.reloadData()
    }
}
