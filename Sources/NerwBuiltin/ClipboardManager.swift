import Cocoa
import NerwAction
import NerwCore
import NerwSearchBackend

public struct ClipboardEntry: Codable, Equatable {
    public let id: String
    public let timestamp: Date
    public let text: String?
    public let imagePath: String?

    public init(
        id: String = UUID().uuidString, timestamp: Date = Date(), text: String? = nil,
        imagePath: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.text = text
        self.imagePath = imagePath
    }
}

public class ClipboardManager {
    public static let shared = ClipboardManager()

    public private(set) var entries: [ClipboardEntry] = []
    public var showWindowCallback: (() -> Void)?

    private let pasteboard = NSPasteboard.general
    private var lastChangeCount: Int = 0
    private var timer: Timer?

    private let storageURL: URL
    private let imagesDirURL: URL
    private let maxEntries = 200

    private init() {
        let basePath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(
            ".nerw")
        storageURL = basePath.appendingPathComponent("clipboard.json")
        imagesDirURL = basePath.appendingPathComponent("ClipboardImages")
        lastChangeCount = pasteboard.changeCount

        try? FileManager.default.createDirectory(
            at: imagesDirURL, withIntermediateDirectories: true)
        load()
    }

    public func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.poll()
        }
    }

    private func poll() {
        let currentChangeCount = pasteboard.changeCount
        guard currentChangeCount != lastChangeCount else { return }
        lastChangeCount = currentChangeCount

        var text: String?
        var imagePath: String?

        // Priority to images
        if let types = pasteboard.types, types.contains(.png) || types.contains(.tiff) {
            if let imageToSave = pasteboard.readObjects(forClasses: [NSImage.self], options: nil)?
                .first as? NSImage
            {
                let filename = UUID().uuidString + ".png"
                let fileURL = imagesDirURL.appendingPathComponent(filename)
                if let tiff = imageToSave.tiffRepresentation,
                    let bitmap = NSBitmapImageRep(data: tiff),
                    let data = bitmap.representation(using: .png, properties: [:])
                {
                    try? data.write(to: fileURL)
                    imagePath = fileURL.path
                }
            }
        }

        if imagePath == nil {
            text = pasteboard.string(forType: .string)
        }

        if text == nil && imagePath == nil { return }

        // Deduplicate top entry
        if let first = entries.first {
            if first.text == text && text != nil { return }
            if first.imagePath == imagePath && imagePath != nil { return }
        }

        let entry = ClipboardEntry(text: text, imagePath: imagePath)
        entries.insert(entry, at: 0)

        while entries.count > maxEntries {
            let removed = entries.removeLast()
            if let path = removed.imagePath {
                try? FileManager.default.removeItem(atPath: path)
            }
        }

        save()
    }

    public func deleteEntry(id: String) {
        if let index = entries.firstIndex(where: { $0.id == id }) {
            let removed = entries.remove(at: index)
            if let path = removed.imagePath {
                try? FileManager.default.removeItem(atPath: path)
            }
            save()
        }
    }

    public func paste(entry: ClipboardEntry) {
        let options =
            [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let isTrusted = AXIsProcessTrustedWithOptions(options)

        if !isTrusted {
            return
        }

        pasteboard.clearContents()
        if let text = entry.text {
            pasteboard.setString(text, forType: .string)
        } else if let path = entry.imagePath, let image = NSImage(contentsOfFile: path) {
            pasteboard.writeObjects([image])
        }
        lastChangeCount = pasteboard.changeCount

        // Simulate Cmd+V
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            let source = CGEventSource(stateID: .hidSystemState)
            let vDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
            vDown?.flags = .maskCommand
            let vUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
            vUp?.flags = .maskCommand

            vDown?.post(tap: .cghidEventTap)
            vUp?.post(tap: .cghidEventTap)
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(entries) {
            try? data.write(to: storageURL)
        }
    }

    private func load() {
        if let data = try? Data(contentsOf: storageURL),
            let saved = try? JSONDecoder().decode([ClipboardEntry].self, from: data)
        {
            entries = saved
        }
    }
    public static func builtinActions() -> [NerwAction] {
        return [
            NerwAction(
                id: "builtin.clipboard",
                title: "Clipboard Manager",
                subtitle: "View clipboard history",
                icon: .system("doc.on.clipboard"),
                triggers: ["clipboard", "clip", "paste", "history"],
                type: .instant(perform: { _ in
                    ClipboardManager.shared.showWindowCallback?()
                })
            )
        ]
    }
}
