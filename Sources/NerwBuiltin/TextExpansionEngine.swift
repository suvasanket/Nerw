import ApplicationServices
import Cocoa
import CoreGraphics
import NerwCore

public class TextExpansionEngine {
    public static let shared = TextExpansionEngine()

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isRunning = false

    private var buffer = ""
    private let maxBufferLength = 50  // Keep small to avoid memory/performance overhead

    private init() {}

    public func start(prompt: Bool = false) {
        guard !isRunning else { return }

        let options =
            [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
        let isTrusted = AXIsProcessTrustedWithOptions(options)

        if !isTrusted {
            print("TextExpansionEngine: Accessibility permissions not granted.")
            return
        }

        let eventMask = (1 << CGEventType.keyDown.rawValue)

        // Use a block wrapper to handle the C-callback pattern
        let observer = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        guard
            let tap = CGEvent.tapCreate(
                tap: .cghidEventTap,
                place: .headInsertEventTap,
                options: .defaultTap,
                eventsOfInterest: CGEventMask(eventMask),
                callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                    if let refcon = refcon {
                        let engine = Unmanaged<TextExpansionEngine>.fromOpaque(refcon)
                            .takeUnretainedValue()
                        return engine.handleEvent(proxy: proxy, type: type, event: event)
                    }
                    return Unmanaged.passRetained(event)
                },
                userInfo: observer
            )
        else {
            print("TextExpansionEngine: Failed to create event tap")
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        isRunning = true
        print("TextExpansionEngine: Started")
    }

    public func stop() {
        guard isRunning else { return }

        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
            }
        }

        eventTap = nil
        runLoopSource = nil
        isRunning = false
        buffer = ""
        print("TextExpansionEngine: Stopped")
    }

    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent)
        -> Unmanaged<CGEvent>?
    {
        // If config is disabled, clear buffer and pass event through
        if !ConfigManager.shared.config.snippetExpansionEnabled {
            buffer = ""
            return Unmanaged.passRetained(event)
        }

        if type == .keyDown {
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

            // Check modifier flags (ignore Ctrl/Cmd/Option combinations as they are shortcuts, not typing)
            if event.flags.contains(.maskCommand) || event.flags.contains(.maskControl)
                || event.flags.contains(.maskAlternate)
            {
                buffer = ""
                return Unmanaged.passRetained(event)
            }

            // Handle Backspace (keyCode 51)
            if keyCode == 51 {
                if !buffer.isEmpty {
                    buffer.removeLast()
                }
                return Unmanaged.passRetained(event)
            }

            // Get character
            var chars = [UniChar](repeating: 0, count: 4)
            var actualStringLength = 0
            event.keyboardGetUnicodeString(
                maxStringLength: 4, actualStringLength: &actualStringLength, unicodeString: &chars)

            if actualStringLength > 0,
                let char = String(utf16CodeUnits: chars, count: actualStringLength).first
            {
                // If it's a newline, space, or tab, it can act as a word boundary. But some triggers might contain punctuation.
                // We just append. If it exceeds max length, we drop the prefix.

                // Exclude some non-printable characters or structural keys (Escape, etc.)
                // Note: Arrows, Home/End, PageUp/Down don't produce printable characters generally
                // But just in case:
                if char.isASCII && (char.asciiValue ?? 0) < 32 {
                    // Control characters
                    buffer = ""
                    return Unmanaged.passRetained(event)
                }

                buffer.append(char)
                if buffer.count > maxBufferLength {
                    buffer.removeFirst(buffer.count - maxBufferLength)
                }

                // Check if the current buffer suffix matches any trigger
                for (trigger, snippet) in SnippetManager.shared.triggerMap {
                    if buffer.hasSuffix(trigger) {
                        // Match found!
                        buffer = ""  // Reset buffer

                        // We need to execute the expansion asynchronously to not block the event tap
                        let resolvedContent = SnippetManager.shared.resolve(
                            content: snippet.content)
                        let triggerLength = trigger.count

                        DispatchQueue.main.async {
                            self.expand(content: resolvedContent, triggerLength: triggerLength - 1)
                        }

                        // Swallow the current keystroke so we only have to backspace triggerLength - 1 characters
                        return nil
                    }
                }
            }
        }

        return Unmanaged.passRetained(event)
    }

    private func expand(content: String, triggerLength: Int) {
        let source = CGEventSource(stateID: .hidSystemState)

        // 1. Send Backspaces to delete the trigger word
        for _ in 0..<triggerLength {
            if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 51, keyDown: true),
                let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 51, keyDown: false)
            {
                keyDown.post(tap: .cghidEventTap)
                keyUp.post(tap: .cghidEventTap)
            }
        }

        // 2. Type the expansion content using keyboardSetUnicodeString
        for char in content {
            if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
                let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
            {

                let chars = Array(char.utf16)
                keyDown.keyboardSetUnicodeString(stringLength: chars.count, unicodeString: chars)
                keyUp.keyboardSetUnicodeString(stringLength: chars.count, unicodeString: chars)

                keyDown.post(tap: .cghidEventTap)
                keyUp.post(tap: .cghidEventTap)
            }
        }
    }
}
