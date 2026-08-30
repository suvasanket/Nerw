import Cocoa
import Foundation
import NerwAction
import NerwCore
import NerwUtils

public struct PCIIconItem: Codable, Hashable {
    public let icon: String
    public let name: String

    public init(icon: String, name: String) {
        self.icon = icon
        self.name = name
    }
}

public struct SavedChatTurn: Codable, Identifiable {
    public var id: UUID
    public let query: String
    public var response: String
    public var rawResponse: String?
    public var actionType: String?
    public var pciIcons: [PCIIconItem]
    public var timestamp: Date

    public init(
        id: UUID = UUID(),
        query: String,
        response: String,
        rawResponse: String? = nil,
        actionType: String? = nil,
        pciIcons: [PCIIconItem] = [],
        timestamp: Date = Date()
    ) {
        self.id = id
        self.query = query
        self.response = response
        self.rawResponse = rawResponse
        self.actionType = actionType
        self.pciIcons = pciIcons
        self.timestamp = timestamp
    }
}

public struct AIConversation: Codable, Identifiable {
    public let id: UUID
    public var title: String
    public var createdAt: Date
    public var updatedAt: Date
    public var turns: [SavedChatTurn]

    public var preview: String {
        if let lastTurn = turns.last {
            return lastTurn.response.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return ""
    }

    public var queryPreview: String {
        if let firstTurn = turns.first {
            return firstTurn.query.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return title
    }

    public init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        turns: [SavedChatTurn] = []
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.turns = turns
    }
}

public class ConversationManager {
    public static let shared = ConversationManager()

    private let conversationsFile: URL
    public private(set) var conversations: [AIConversation] = []

    public var showWindowCallback: ((String?) -> Void)?
    public var showConversationCallback: ((UUID) -> Void)?

    private init() {
        self.conversationsFile = NerwPaths.aiConversationsFile
        NerwPaths.ensureDirectoryExists(at: NerwPaths.configDirectory)
        load()
    }

    public func load() {
        do {
            if FileManager.default.fileExists(atPath: conversationsFile.path) {
                let data = try Data(contentsOf: conversationsFile)
                let decoder = JSONDecoder()
                conversations = try decoder.decode([AIConversation].self, from: data)
                // Keep sorted by updatedAt descending
                conversations.sort(by: { $0.updatedAt > $1.updatedAt })
            }
        } catch {
            Logger.shared.error("ConversationManager: Failed to load conversations: \(error)")
        }
    }

    public func saveToDisk() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(conversations)
            try data.write(to: conversationsFile, options: .atomic)
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: Notification.Name("NerwHubDataDidUpdate"), object: nil)
                NotificationCenter.default.post(
                    name: Notification.Name("NerwConversationsDidUpdate"), object: nil)
            }
        } catch {
            Logger.shared.error("ConversationManager: Failed to save conversations: \(error)")
        }
    }

    public func saveConversation(id: UUID, title: String?, turns: [SavedChatTurn]) {
        guard !turns.isEmpty else { return }

        let resolvedTitle: String
        if let title = title, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            resolvedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        } else if let firstQuery = turns.first?.query,
            !firstQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
            resolvedTitle = firstQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            resolvedTitle = "New Conversation"
        }

        if let index = conversations.firstIndex(where: { $0.id == id }) {
            var existing = conversations[index]
            existing.title = resolvedTitle
            existing.updatedAt = Date()
            existing.turns = turns
            conversations[index] = existing
        } else {
            let newConversation = AIConversation(
                id: id,
                title: resolvedTitle,
                createdAt: Date(),
                updatedAt: Date(),
                turns: turns
            )
            conversations.insert(newConversation, at: 0)
        }

        enforceLimit()
        saveToDisk()
    }

    public func enforceLimit() {
        let maxLimit = max(1, ConfigManager.shared.config.aiConfig.maxSavedConversations)
        conversations.sort(by: { $0.updatedAt > $1.updatedAt })
        if conversations.count > maxLimit {
            conversations = Array(conversations.prefix(maxLimit))
        }
    }

    public func getConversation(id: UUID) -> AIConversation? {
        return conversations.first(where: { $0.id == id })
    }

    public func deleteConversation(id: UUID) {
        conversations.removeAll(where: { $0.id == id })
        saveToDisk()
    }

    public func clearAll() {
        conversations.removeAll()
        saveToDisk()
    }

    public func openConversation(id: UUID) {
        showConversationCallback?(id)
    }

    public static func builtinActions() -> [NerwAction] {
        return []
    }
}
