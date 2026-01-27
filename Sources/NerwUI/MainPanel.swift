// MainPanel.swift
import Cocoa

public class MainPanel: NSPanel {
    var resignHandler: (() -> Void)?

    public override var canBecomeKey: Bool { true }
    public override var canBecomeMain: Bool { true }

    public override func resignKey() {
        super.resignKey()
        // If we are visible but losing key status (e.g. to an accessory window),
        // normally we might resign. But here we force key if we want to stay active,
        // or we let resignHandler handle the dismissal.
        // However, standard Spotlight behavior is to close on resign.
        if isVisible {
            self.makeKey()
        }
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
