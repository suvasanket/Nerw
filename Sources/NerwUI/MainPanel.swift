// MainPanel.swift
import Cocoa

public class MainPanel: NSPanel {
    var resignHandler: (() -> Void)?

    public override var canBecomeKey: Bool { true }
    public override var canBecomeMain: Bool { true }

    public override func resignKey() {
        super.resignKey()
        resignHandler?()
    }

    public override func cancelOperation(_ sender: Any?) {
        resignHandler?()
    }

    public override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command) && event.characters == "," {
            NotificationCenter.default.post(
                name: Notification.Name("NerwOpenSettings"), object: nil)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}
