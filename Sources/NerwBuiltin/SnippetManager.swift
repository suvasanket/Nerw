import Cocoa
import NerwAction
import NerwCore
import NerwUtils

public struct Snippet: Codable, Equatable {
    public let id: String
    public let name: String
    public let trigger: String
    public let content: String
    public let createdAt: Date

    public init(
        id: String = UUID().uuidString, name: String, trigger: String, content: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.trigger = trigger
        self.content = content
        self.createdAt = createdAt
    }
}

public class SnippetManager {
    public static let shared = SnippetManager()

    public private(set) var snippets: [Snippet] = []
    public private(set) var triggerMap: [String: Snippet] = [:]
    public var showWindowCallback: (() -> Void)?

    private var storageURL: URL

    private init() {
        storageURL = NerwPaths.dataDirectory.appendingPathComponent("snippets.json")
        load()
    }

    public func setStorageURL(_ url: URL) {
        self.storageURL = url
        load()
    }

    public func addSnippet(name: String, trigger: String, content: String) {
        let snippet = Snippet(name: name, trigger: trigger, content: content)
        snippets.append(snippet)
        updateTriggerMap()
        save()
    }

    public func updateSnippet(id: String, name: String, trigger: String, content: String) {
        if let index = snippets.firstIndex(where: { $0.id == id }) {
            let existing = snippets[index]
            snippets[index] = Snippet(
                id: existing.id, name: name, trigger: trigger, content: content,
                createdAt: existing.createdAt)
            updateTriggerMap()
            save()
        }
    }

    public func deleteSnippet(id: String) {
        snippets.removeAll { $0.id == id }
        updateTriggerMap()
        save()
    }

    private func updateTriggerMap() {
        triggerMap.removeAll()
        for snippet in snippets {
            triggerMap[snippet.trigger] = snippet
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(snippets) {
            try? data.write(to: storageURL)
        }
    }

    private func load() {
        if let data = try? Data(contentsOf: storageURL),
            let saved = try? JSONDecoder().decode([Snippet].self, from: data)
        {
            snippets = saved
        } else {
            snippets = []
        }
        updateTriggerMap()
    }

    public func resolve(content: String) -> String {
        var resolved = content

        // Resolve {{clipboard}}
        if resolved.contains("{{clipboard}}") {
            let clipboardText = NSPasteboard.general.string(forType: .string) ?? ""
            resolved = resolved.replacingOccurrences(of: "{{clipboard}}", with: clipboardText)
        }

        // Resolve time/date placeholders like {{time}} or {{yyyy-MM-dd}}
        let regex = try! NSRegularExpression(pattern: "\\{\\{(.*?)\\}\\}", options: [])
        let nsString = resolved as NSString
        let matches = regex.matches(
            in: resolved, options: [], range: NSRange(location: 0, length: nsString.length))

        var replacements: [(NSRange, String)] = []
        for match in matches {
            let fullRange = match.range(at: 0)
            let formatRange = match.range(at: 1)
            let format = nsString.substring(with: formatRange)

            // Skip clipboard since we already handled it
            if format == "clipboard" { continue }

            let dateFormatter = DateFormatter()
            if format == "time" {
                dateFormatter.dateFormat = "HH:mm"
            } else {
                dateFormatter.dateFormat = format
            }

            let dateString = dateFormatter.string(from: Date())
            replacements.append((fullRange, dateString))
        }

        // Apply replacements from back to front to avoid shifting indices
        for (range, replacement) in replacements.reversed() {
            let startIndex = resolved.index(resolved.startIndex, offsetBy: range.location)
            let endIndex = resolved.index(startIndex, offsetBy: range.length)
            resolved.replaceSubrange(startIndex..<endIndex, with: replacement)
        }

        return resolved
    }

    public static func builtinActions() -> [NerwAction] {
        return [
            NerwAction(
                id: "builtin.snippet.manager",
                title: "Snippet Manager",
                subtitle: "View and manage text snippets",
                icon: .system("text.pad.header"),
                triggers: ["snippet"],
                type: .instant(perform: { _ in
                    DispatchQueue.main.async {
                        SnippetManager.shared.showWindowCallback?()
                    }
                })
            ),
            NerwAction(
                id: "builtin.snippet.add",
                title: "Add Snippet",
                subtitle: "Create a new text expansion snippet",
                icon: .system("text.pad.header.badge.plus"),
                triggers: ["addsnippet"],
                type: .form(
                    fields: [
                        .init(id: "name", title: "Name", placeholder: "e.g. Email signature"),
                        .init(id: "trigger", title: "Trigger", placeholder: "e.g. ;sig"),
                        .init(
                            id: "content", title: "Content",
                            subtext:
                                "You can use placeholders like {{date}}, {{time}}, or {{clipboard}}",
                            placeholder: "Your text here",
                            isMultiline: true),
                    ],
                    submitLabel: "Save Snippet",
                    perform: { _, values in
                        let name = values["name"] ?? ""
                        let trigger = values["trigger"] ?? ""
                        let content = values["content"] ?? ""
                        if !name.isEmpty && !trigger.isEmpty && !content.isEmpty {
                            SnippetManager.shared.addSnippet(
                                name: name, trigger: trigger, content: content)
                            if ConfigManager.shared.config.snippetExpansionEnabled {
                                TextExpansionEngine.shared.start(prompt: true)
                            }
                            DispatchQueue.main.async {
                                SnippetManager.shared.showWindowCallback?()
                            }
                        }
                    }
                )
            ),
        ]
    }
}
