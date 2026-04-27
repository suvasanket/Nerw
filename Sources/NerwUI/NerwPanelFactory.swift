import Cocoa
import NerwCore

public enum NerwPanelFactory {
    /// Creates a borderless, floating, non-activating panel
    public static func makePanel<T: NSPanel>(
        type: T.Type = NSPanel.self as! T.Type,
        contentRect: NSRect,
        level: NSWindow.Level = .floating,
        canBecomeKey: Bool = true,
        styleMask: NSWindow.StyleMask = [.borderless, .nonactivatingPanel, .fullSizeContentView]
    ) -> T {
        let panel = T(
            contentRect: contentRect,
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )

        panel.level = level
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        return panel
    }
}
