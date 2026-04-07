// MainPanel.swift
import Cocoa

public class MainPanel: NSPanel {
    var resignHandler: (() -> Void)?

    public override var canBecomeKey: Bool { true }
    public override var canBecomeMain: Bool { true }

    public override func resignKey() {
        super.resignKey()

        // Don't dismiss when focus moves to our own child window
        // (e.g. ActionContextPanel). We check asynchronously since key
        // window status update is slightly delayed.
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let nextKey = NSApp.keyWindow, self.childWindows?.contains(nextKey) == true {
                return
            }
            if NSApp.keyWindow is ActionContextPanel {
                return
            }
            self.resignHandler?()
        }
    }

    public override func cancelOperation(_ sender: Any?) {
        resignHandler?()
    }

    public override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command)
            && event.charactersIgnoringModifiers?.lowercased() == ","
        {
            NotificationCenter.default.post(
                name: Notification.Name("NerwOpenSettings"), object: nil)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}

// MARK: - ActionContextPanel

/// A borderless, key-capable panel used for the action context popup.
class ActionContextPanel: NSPanel {
    override var canBecomeKey: Bool { true }

    override func resignKey() {
        super.resignKey()

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            // Don't dismiss if returning to the parent
            if NSApp.keyWindow == self.parent { return }
            (self.parent as? MainPanel)?.resignHandler?()
        }
    }

    /// Forwards Cmd+K close shortcut to the parent window.
    override func cancelOperation(_ sender: Any?) {
        parent?.makeKeyAndOrderFront(nil)
    }
}
