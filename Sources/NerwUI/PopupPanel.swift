// PopupPanel.swift
import Cocoa

public class PopupPanel: NSPanel {
    var resignHandler: (() -> Void)?

    public override var canBecomeKey: Bool { true }
    public override var canBecomeMain: Bool { true }

    public override func resignKey() {
        super.resignKey()
        if isVisible {
            self.makeKey()
        }
        resignHandler?()
    }

    public override func cancelOperation(_ sender: Any?) {
        resignHandler?()
    }
}
