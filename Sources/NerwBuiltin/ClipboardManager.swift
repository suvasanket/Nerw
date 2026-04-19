import Cocoa
import NerwAction
import NerwCore
import NerwSearchBackend
import NerwUtils

public enum ClipboardContextOperationID: String {
    case paste = "clipboard.paste"
    case delete = "clipboard.delete"
    case pin = "clipboard.pin"
}

public struct ClipboardEntry: Codable, Equatable {
    public let id: String
    public let timestamp: Date
    public let text: String?
    public let imagePath: String?
    public let isPinned: Bool

    public init(
        id: String = UUID().uuidString, timestamp: Date = Date(), text: String? = nil,
        imagePath: String? = nil, isPinned: Bool = false
    ) {
        self.id = id
        self.timestamp = timestamp
        self.text = text
        self.imagePath = imagePath
        self.isPinned = isPinned
    }

    enum CodingKeys: String, CodingKey {
        case id
        case timestamp
        case text
        case imagePath
        case isPinned
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        text = try container.decodeIfPresent(String.self, forKey: .text)
        imagePath = try container.decodeIfPresent(String.self, forKey: .imagePath)
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encodeIfPresent(text, forKey: .text)
        try container.encodeIfPresent(imagePath, forKey: .imagePath)
        try container.encode(isPinned, forKey: .isPinned)
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
        storageURL = NerwPaths.dataDirectory.appendingPathComponent("clipboard.json")
        imagesDirURL = NerwPaths.clipboardImagesDirectory
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

        let insertionIndex = Self.insertionIndexForNewEntry(in: entries)

        // Deduplicate the most recent non-pinned entry.
        if insertionIndex < entries.count {
            let latestUnpinned = entries[insertionIndex]
            if latestUnpinned.text == text && text != nil { return }
            if latestUnpinned.imagePath == imagePath && imagePath != nil { return }
        }

        let entry = ClipboardEntry(text: text, imagePath: imagePath)
        entries.insert(entry, at: insertionIndex)

        while entries.count > maxEntries {
            let removalIndex =
                entries.lastIndex(where: { !$0.isPinned })
                ?? (entries.isEmpty ? nil : entries.count - 1)
            guard let removalIndex else { break }
            let removed = entries.remove(at: removalIndex)
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

    @discardableResult
    public func togglePinned(id: String) -> Bool {
        let updatedEntries = Self.entriesByTogglingPin(for: id, in: entries)
        guard updatedEntries != entries,
            let updatedEntry = updatedEntries.first(where: { $0.id == id })
        else { return false }

        entries = updatedEntries
        save()
        return updatedEntry.isPinned
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

    public static func insertionIndexForNewEntry(in entries: [ClipboardEntry]) -> Int {
        entries.prefix(while: { $0.isPinned }).count
    }

    public static func entriesByTogglingPin(for id: String, in entries: [ClipboardEntry])
        -> [ClipboardEntry]
    {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return entries }

        var reorderedEntries = entries
        let existingEntry = reorderedEntries.remove(at: index)
        let updatedEntry = ClipboardEntry(
            id: existingEntry.id,
            timestamp: existingEntry.timestamp,
            text: existingEntry.text,
            imagePath: existingEntry.imagePath,
            isPinned: !existingEntry.isPinned
        )

        if updatedEntry.isPinned {
            reorderedEntries.insert(updatedEntry, at: 0)
        } else {
            let insertionIndex = insertionIndexForNewEntry(in: reorderedEntries)
            reorderedEntries.insert(updatedEntry, at: insertionIndex)
        }

        return reorderedEntries
    }

    public static func title(for entry: ClipboardEntry) -> String {
        if let text = entry.text {
            let firstLine =
                text.trimmingCharacters(in: .whitespacesAndNewlines).components(
                    separatedBy: .newlines
                ).first ?? text
            return firstLine.isEmpty ? "Empty Text" : String(firstLine.prefix(50))
        }

        if entry.imagePath != nil {
            return "Image"
        }

        return "Unknown"
    }

    public static func subtitle(for entry: ClipboardEntry) -> String? {
        let baseSubtitle: String?
        if let text = entry.text {
            baseSubtitle = "Text • \(text.count) chars"
        } else if entry.imagePath != nil {
            baseSubtitle = "Image"
        } else {
            baseSubtitle = nil
        }

        if entry.isPinned {
            if let baseSubtitle {
                return "Pinned • \(baseSubtitle)"
            }
            return "Pinned"
        }

        return baseSubtitle
    }

    public static func context(for entry: ClipboardEntry) -> NerwActionContext {
        let pinTitle = entry.isPinned ? "Unpin" : "Pin"
        let pinSubtitle =
            entry.isPinned
            ? "Return this item to the normal clipboard history order"
            : "Keep this item at the top of clipboard history"

        return NerwActionContext(
            actionID: entry.id,
            actionTitle: title(for: entry),
            actionSubtitle: subtitle(for: entry) ?? "Clipboard Entry",
            sections: [
                .init(
                    id: "clipboard",
                    title: "Clipboard",
                    operations: [
                        .init(
                            id: ClipboardContextOperationID.paste.rawValue,
                            kind: .custom(ClipboardContextOperationID.paste.rawValue),
                            title: "Paste",
                            subtitle: "Paste this entry into the frontmost app",
                            icon: .system("doc.on.clipboard"),
                            interaction: .execute,
                            detailText: "⏎"
                        ),
                        .init(
                            id: ClipboardContextOperationID.delete.rawValue,
                            kind: .custom(ClipboardContextOperationID.delete.rawValue),
                            title: "Delete",
                            subtitle: "Remove this entry from clipboard history",
                            icon: .system("trash"),
                            interaction: .execute,
                            detailText: "⌘⌫"
                        ),
                        .init(
                            id: ClipboardContextOperationID.pin.rawValue,
                            kind: .custom(ClipboardContextOperationID.pin.rawValue),
                            title: pinTitle,
                            subtitle: pinSubtitle,
                            icon: .system(entry.isPinned ? "pin.slash" : "pin"),
                            interaction: .execute,
                            detailText: "⌘P"
                        ),
                    ]
                )
            ]
        )
    }

    public static func builtinActions() -> [NerwAction] {
        return [
            NerwAction(
                id: "builtin.clipboard",
                title: "Clipboard Manager",
                subtitle: "View clipboard history",
                icon: .image(
                    NSImage(named: "clipboard") ?? NSImage(
                        systemSymbolName: "clipboard", accessibilityDescription: nil)
                        ?? NSImage(
                            systemSymbolName: "doc.on.clipboard", accessibilityDescription: nil)
                        ?? NSImage()),
                triggers: ["clipboard", "clip", "paste", "history"],
                type: .instant(perform: { _ in
                    ClipboardManager.shared.showWindowCallback?()
                })
            )
        ]
    }
}
