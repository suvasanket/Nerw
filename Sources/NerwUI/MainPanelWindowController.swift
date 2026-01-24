// MainPanelWindowController.swift
import Cocoa

public class MainPanelWindowController: NSObject {
    private var panel: MainPanel!
    private var contentViewController: MainPanelContentViewController!

    public var isVisible: Bool { panel.isVisible }

    public override init() {
        super.init()
        setupPanel()
    }

    private func setupPanel() {
        // Create content view controller
        contentViewController = MainPanelContentViewController()
        contentViewController.delegate = self

        // Calculate window size
        let metrics = MainPanelContentViewController.LayoutMetrics.self
        let width = metrics.Window.width
        let initialHeight =
            metrics.SearchField.top + metrics.SearchField.height + metrics.SearchField.bottom

        // Create panel
        panel = MainPanel(
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

        // Calculate positioning based on the search bar height logic
        // We want the Search Bar to be roughly at the "Visual Center" + Offset
        // regardless of whether there are results or not.

        let metrics = MainPanelContentViewController.LayoutMetrics.self
        let searchBarHeight =
            metrics.SearchField.top + metrics.SearchField.height + metrics.SearchField.bottom

        // This is where we want the center of the Search Bar to be
        // 0.30 offset moves it higher up the screen (Recalling that screen Y origin is bottom)
        let visualCenterY = screenRect.origin.y + screenRect.height / 2 + screenRect.height * 0.30

        // Calculate where the top of the window should be
        // CenterOfSearchBar = TopOfWindow - SearchBarHeight/2
        // TopOfWindow = CenterOfSearchBar + SearchBarHeight/2
        let targetTopY = visualCenterY + searchBarHeight / 2

        // Actual Origin Y = TopOfWindow - CurrentHeight
        let newOriginY = targetTopY - windowRect.height

        let x = screenRect.origin.x + (screenRect.width - windowRect.width) / 2

        panel.setFrameOrigin(NSPoint(x: x, y: newOriginY))
    }

    public func toggle() {
        isVisible ? hide() : show()
    }

    public func show() {
        centerOnScreen()
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(contentViewController.inputField)
    }

    public func hide() {
        panel.orderOut(nil)
        contentViewController.reset()
        // Return focus to the previous application
        NSApp.hide(nil)
    }

    public func updateHeight(_ height: CGFloat) {
        var frame = panel.frame
        let diff = height - frame.height
        frame.origin.y -= diff
        frame.size.height = height
        panel.setFrame(frame, display: true, animate: true)
    }
}

extension MainPanelWindowController: MainPanelContentDelegate {
    func didPressEscape() {
        hide()
    }

    func didSubmit(text: String) {
        if text == "/debug" {
            contentViewController.toggleDebugMode()
            return
        }
        // print("Submitted: \(text)")
        // Handle submission
        hide()
    }

    func didUpdateResults(count: Int) {
        let metrics = MainPanelContentViewController.LayoutMetrics.self
        let rowHeight = metrics.Results.rowHeight
        let maxVisible = metrics.Results.maxVisibleRows
        let resultsHeight = CGFloat(min(count, maxVisible)) * rowHeight

        if count > 0 {
            // Calculate total height dynamically based on all components
            // Search Field Section
            let searchSection = metrics.SearchField.top + metrics.SearchField.height

            // Separator Section (Top margin + Height + Bottom margin)
            let separatorSection =
                metrics.Separator.top + metrics.Separator.height + metrics.Separator.bottom

            // Results Section (Results height + Bottom margin matching expandedBottom)
            // We use the explicit expandedBottom metric from LayoutMetrics
            let bottomPadding = metrics.Results.expandedBottom
            let resultsSection = resultsHeight + bottomPadding

            // Add a 6pt buffer to ensure no clipping occurs
            let newHeight = searchSection + separatorSection + resultsSection + 10
            updateHeight(newHeight)
        } else {
            // Shrink view height (SearchField.top + SearchField.height + SearchField.bottom)
            // SearchField.bottom acts as the bottom padding in shrink view
            let shrinkHeight =
                metrics.SearchField.top + metrics.SearchField.height + metrics.SearchField.bottom
            updateHeight(shrinkHeight)
        }
    }
}
