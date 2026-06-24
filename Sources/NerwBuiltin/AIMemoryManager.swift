import Foundation
import NaturalLanguage
import NerwUtils

public struct MemoryEntry: Codable, Identifiable {
    public let id: UUID
    public let content: String
    public let importance: Int
    public let timestamp: Date
}

public class AIMemoryManager {
    public static let shared = AIMemoryManager()

    private let memoryFile: URL
    public private(set) var entries: [MemoryEntry] = []

    private let maxEntries = 50

    private init() {
        self.memoryFile = NerwPaths.aiMemoryFile
        load()
    }

    public func save(content: String, importance: Int) {
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)

        // Exact match check
        if let index = entries.firstIndex(where: {
            $0.content.lowercased() == trimmedContent.lowercased()
        }) {
            let existing = entries[index]
            let newImportance = min(existing.importance + 1, 10)
            entries[index] = MemoryEntry(
                id: existing.id,
                content: existing.content,
                importance: max(newImportance, min(max(importance, 1), 10)),
                timestamp: Date()
            )
            Logger.shared.info(
                "AIMemoryManager: Updated existing memory (exact match) '\(existing.content)' to importance \(entries[index].importance)"
            )
            saveToDisk()
            return
        }

        // Semantic similarity check using NLP
        if #available(macOS 10.15, *) {
            if let embedding = NLEmbedding.sentenceEmbedding(for: .english) {
                for (index, existing) in entries.enumerated() {
                    let distance = embedding.distance(
                        between: trimmedContent, and: existing.content)
                    // NLEmbedding distance < 0.3 generally means highly similar sentences
                    if distance < 0.3 {
                        let newImportance = min(existing.importance + 1, 10)
                        let bestContent =
                            existing.content.count >= trimmedContent.count
                            ? existing.content : trimmedContent
                        entries[index] = MemoryEntry(
                            id: existing.id,
                            content: bestContent,
                            importance: max(newImportance, min(max(importance, 1), 10)),
                            timestamp: Date()
                        )
                        Logger.shared.info(
                            "AIMemoryManager: Updated existing memory (semantic dist: \(distance)) '\(entries[index].content)' to importance \(entries[index].importance)"
                        )
                        saveToDisk()
                        return
                    }
                }
            }
        }

        let entry = MemoryEntry(
            id: UUID(),
            content: trimmedContent,
            importance: min(max(importance, 1), 10),  // Clamp 1-10
            timestamp: Date()
        )

        entries.append(entry)
        enforceLimit()
        saveToDisk()
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
}
