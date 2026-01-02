// PopupPanel.swift
import Cocoa

class PopupPanel: NSPanel {
    var resignHandler: (() -> Void)?

        override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func resignKey() {
        super.resignKey()
        if isVisible {
            self.makeKey()
        }
        resignHandler?()
    }

    override func cancelOperation(_ sender: Any?) {
        resignHandler?()
    }
}
