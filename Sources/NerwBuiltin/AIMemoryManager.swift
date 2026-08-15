import Foundation
import NaturalLanguage
import NerwAction
import NerwUtils

public struct MemoryEntry: Codable, Identifiable {
    public let id: UUID
    public let title: String
    public let category: String
    public let content: String
    public let importance: Int
    public let timestamp: Date
    public var lastRecalled: Date?
}

public class AIMemoryManager {
    public static let shared = AIMemoryManager()

    public var showWindowCallback: (() -> Void)?

    private let memoryFile: URL
    public private(set) var entries: [MemoryEntry] = []

    private let maxEntries = 50

    private init() {
        self.memoryFile = NerwPaths.aiMemoryFile
        load()
    }

    public func save(title: String, category: String, content: String, importance: Int) {
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)

        // Exact match check
        if let index = entries.firstIndex(where: {
            $0.content.lowercased() == trimmedContent.lowercased()
        }) {
            let existing = entries[index]
            let newImportance = min(existing.importance + 1, 10)
            entries[index] = MemoryEntry(
                id: existing.id,
                title: title,
                category: category,
                content: existing.content,
                importance: max(newImportance, min(max(importance, 1), 10)),
                timestamp: Date(),
                lastRecalled: existing.lastRecalled
            )
            Logger.shared.info(
                "AIMemoryManager: Updated existing memory (exact match) '\(existing.content)' to importance \(entries[index].importance)"
            )
            saveToDisk()
            return
        }

        // TODO: NLP Deduplication removed for now. Plan to implement a better approach in the future.

        let entry = MemoryEntry(
            id: UUID(),
            title: title,
            category: category,
            content: trimmedContent,
            importance: min(max(importance, 1), 10),  // Clamp 1-10
            timestamp: Date(),
            lastRecalled: nil
        )

        entries.append(entry)
        enforceLimit()
        saveToDisk()
    }

    public func getAllCategories() -> [String] {
        let categories = entries.map { $0.category }
        return Array(Set(categories)).sorted()
    }

    public func getMemories(byCategory category: String) -> [MemoryEntry] {
        return entries.filter { $0.category.lowercased() == category.lowercased() }
            .sorted(by: { $0.timestamp > $1.timestamp })
    }

    public func clear() {
        entries.removeAll()
        saveToDisk()
    }

    private func enforceLimit() {
        guard entries.count > maxEntries else { return }

        // Find the lowest importance. If tie, the oldest timestamp.
        if let toRemove = entries.min(by: {
            if $0.importance != $1.importance {
                return $0.importance < $1.importance
            }
            return $0.timestamp < $1.timestamp
        }) {
            if let index = entries.firstIndex(where: { $0.id == toRemove.id }) {
                entries.remove(at: index)

                // Recursively enforce if somehow we are way over the limit
                enforceLimit()
            }
        }
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: memoryFile.path) else { return }

        do {
            let data = try Data(contentsOf: memoryFile)
            entries = try JSONDecoder().decode([MemoryEntry].self, from: data)
        } catch {
            Logger.shared.error(
                "AIMemoryManager: Failed to load memory: \(error.localizedDescription)")
        }
    }

    private func saveToDisk() {
        do {
            let data = try JSONEncoder().encode(entries)
            try data.write(to: memoryFile, options: .atomic)
        } catch {
            Logger.shared.error(
                "AIMemoryManager: Failed to save memory: \(error.localizedDescription)")
        }
    }

    public static func builtinActions() -> [NerwAction] {
        return [
            NerwAction(
                id: "builtin.memory",
                title: "Nerw Hub Memory",
                subtitle: "View and manage AI memories",
                icon: .system("brain.head.profile"),
                triggers: ["memory", "hub", "ai memory"],
                type: .instant(perform: { _ in
                    DispatchQueue.main.async {
                        AIMemoryManager.shared.showWindowCallback?()
                    }
                })
            )
        ]
    }
}
