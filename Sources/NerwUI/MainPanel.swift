// MainPanel.swift
import Cocoa

public class MainPanel: NSPanel {
    var resignHandler: (() -> Void)?

    public override var canBecomeKey: Bool { true }
    public override var canBecomeMain: Bool { true }

    public override func resignKey() {
        super.resignKey()

        // Don't dismiss when focus moves to our own child window.
        // We check asynchronously since key window status update is slightly delayed.
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let nextKey = NSApp.keyWindow, self.childWindows?.contains(nextKey) == true {
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
            if let mainPanel = self.parent as? MainPanel {
                mainPanel.resignHandler?()
            } else if let splitPanel = self.parent as? SplitPanel {
                splitPanel.resignHandler?()
            } else if let hubPanel = self.parent as? NerwHubPanel {
                hubPanel.resignHandler?()
            }
        }
    }

    /// Forwards Cmd+K close shortcut to the parent window.
    override func cancelOperation(_ sender: Any?) {
        parent?.makeKeyAndOrderFront(nil)
    }
}

// MARK: - ActionContextOverlayView

/// A transparent overlay view that captures clicks outside the context panel to dismiss it.
/// Used when the context panel is displayed inline (as an overlay) instead of in a separate window.
final class ActionContextOverlayView: NSView {
    var onBackgroundClick: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        // Faded background to make the context panel pop out more
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.3).cgColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func mouseDown(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)

        // Check if click is inside any child subview (the context panel)
        for subview in subviews {
            let subviewFrame = subview.frame
            if subviewFrame.contains(location) {
                super.mouseDown(with: event)
                return
            }
        }

        // Click was outside the context panel — dismiss
        onBackgroundClick?()
    }

    override var acceptsFirstResponder: Bool { false }
}
