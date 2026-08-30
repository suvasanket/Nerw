import Cocoa
import NerwCore
import NerwSearchBackend

class ConversationPanel: NSPanel {
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

public class ConversationWindowController: NSObject {
    private var panel: ConversationPanel!
    private var contentViewController: ConversationViewController!

    public var isVisible: Bool {
        return panel != nil && panel.isVisible
    }

    public override init() {
        super.init()
        contentViewController = ConversationViewController()
        contentViewController.onDismiss = { [weak self] in
            self?.hide()
        }
        setupPanel()
    }

    private func setupPanel() {
        let metricsWidth = GlobalLayout.mainWidth
        let metricsHeight = GlobalLayout.mainHeight

        panel = NerwPanelFactory.makePanel(
            type: ConversationPanel.self,
            contentRect: NSRect(x: 0, y: 0, width: metricsWidth, height: metricsHeight)
        )

        panel.contentViewController = contentViewController

        panel.resignHandler = { [weak self] in
            if self?.panel.isVisible == true {
                self?.hide()
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

    public func show(prompt: String? = nil, conversationId: UUID? = nil) {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }

        let width = GlobalLayout.mainWidth
        let height = GlobalLayout.mainHeight
        let size = NSSize(width: width, height: height)
        let exactOrig = NerwPanelContext.shared.exactOrigin(forSize: size, in: screen.visibleFrame)

        panel.setContentSize(size)
        panel.setFrameOrigin(exactOrig)

        panel.makeKeyAndOrderFront(nil)
        _ = contentViewController.view
        if let conversationId = conversationId {
            contentViewController.loadConversation(id: conversationId)
        } else if let prompt = prompt {
            if ConfigManager.shared.config.aiConfig.searchStartsNewConversation {
                contentViewController.startNewConversation()
            }
            contentViewController.submitPromptDirectly(prompt)
        } else {
            if ConfigManager.shared.config.aiConfig.openWithNewConversation {
                contentViewController.startNewConversation()
            } else {
                contentViewController.focusInput()
            }
        }
    }

    public func hide() {
        if panel.isVisible {
            panel.orderOut(nil)

            contentViewController.cancelActiveTask()

            let isFocusStayingInApp = NSApp.windows.contains {
                $0.isVisible && $0.isKeyWindow && $0 != panel
            }
            if !isFocusStayingInApp {
                NSApp.hide(nil)
            }
        }
    }
}
