import Cocoa
import Foundation

@testable import NerwUI

func runMainPanelTests() {
    print("[Testing] Starting Main Panel tests...")

    testMainPanelRestoresCaretWithoutSelectingText()

    print("[Testing] All Main Panel tests PASSED.")
}

func testMainPanelRestoresCaretWithoutSelectingText() {
    _ = NSApplication.shared

    let controller = MainPanelContentViewController()
    let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 640, height: 160),
        styleMask: [.titled, .closable],
        backing: .buffered,
        defer: false
    )
    window.contentViewController = controller
    window.makeKeyAndOrderFront(nil)

    let query = "existing query"
    controller.inputField.stringValue = query

    controller.restoreInputFocusPreservingCaret()
    RunLoop.main.run(until: Date().addingTimeInterval(0.05))

    guard let editor = controller.inputField.currentEditor() else {
        fatalError("FAIL: Main panel input field did not become first responder.")
    }

    let expectedRange = MainPanelTextSelection.collapsedRange(for: query)
    if editor.selectedRange != expectedRange {
        fatalError(
            "FAIL: Main panel restored selection unexpectedly. Expected \(expectedRange), got \(editor.selectedRange)"
        )
    }

    window.orderOut(nil)
    print("  ✓ testMainPanelRestoresCaretWithoutSelectingText passed.")
}
