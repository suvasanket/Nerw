// PopupWindowController.swift
import Cocoa

class PopupWindowController: NSObject {
    private var panel: PopupPanel!
    private var contentViewController: PopupContentViewController!

    var isVisible: Bool { panel.isVisible }

    override init() {
        super.init()
        setupPanel()
    }

    private func setupPanel() {
        // Create content view controller
        contentViewController = PopupContentViewController()
        contentViewController.delegate = self

        // Calculate window size
        let width = PopupContentViewController.LayoutMetrics.windowWidth
        let initialHeight = PopupContentViewController.LayoutMetrics.baseHeight

        // Create panel
        panel = PopupPanel(
            contentRect: NSRect(x: 0, y: 0, width: width, height: initialHeight),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        panel.contentViewController = contentViewController
        panel.setContentSize(NSSize(width: width, height: initialHeight))
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // Click outside to dismiss
        panel.resignHandler = { [weak self] in
            self?.hide()
        }

        centerOnScreen()
    }

    private func centerOnScreen() {
        guard let screen = NSScreen.main else { return }
        let screenRect = screen.visibleFrame
        let windowRect = panel.frame

        let x = screenRect.origin.x + (screenRect.width - windowRect.width) / 2
        let y =
            screenRect.origin.y + (screenRect.height - windowRect.height) / 2 + screenRect.height
            * 0.15

        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    func toggle() {
        isVisible ? hide() : show()
    }

    func show() {
        centerOnScreen()
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(contentViewController.inputField)
    }

    func hide() {
        panel.orderOut(nil)
        contentViewController.reset()
        // Return focus to the previous application
        NSApp.hide(nil)
    }

    func updateHeight(_ height: CGFloat) {
        var frame = panel.frame
        let diff = height - frame.height
        frame.origin.y -= diff
        frame.size.height = height
        panel.setFrame(frame, display: true, animate: true)
    }
}

extension PopupWindowController: PopupContentDelegate {
    func didPressEscape() {
        hide()
    }

    func didSubmit(text: String) {
        if text == "/debug" {
            contentViewController.toggleDebugMode()
            return
        }
        print("Submitted: \(text)")
        // Handle submission
        hide()
    }

    func didUpdateResults(count: Int) {
        let metrics = PopupContentViewController.LayoutMetrics.self
        let rowHeight = metrics.Results.rowHeight
        let maxVisible = metrics.Results.maxVisibleRows
        let resultsHeight = CGFloat(min(count, maxVisible)) * rowHeight

        if count > 0 {
            // Calculate total height dynamically based on all components
            let topPart = metrics.SearchInput.top + metrics.SearchInput.height
            let separatorPart = metrics.Separator.topPadding + metrics.Separator.height
            let bottomPart = metrics.Results.bottomPadding
            
            let newHeight = topPart + separatorPart + resultsHeight + bottomPart
            updateHeight(newHeight)
        } else {
            updateHeight(metrics.baseHeight)
        }
    }
}
