import Foundation
import NerwUtils

public struct UIConfig: Codable {
    public var font: String?
    public var mainBackgroundColor: String?
    public var selectionBackgroundColor: String?
    public var mainForegroundColor: String?
    public var selectionForegroundColor: String?
    public var hintColor: String?
    public var useSystemSelectionColor: Bool?

    public init() {}
}

public struct LayoutConfig: Codable {
    public var mainWidth: Double = 700
    public var mainHeight: Double = 500
    public var cornerRadius: Double = 28
    public var horizontalMargin: Double = 20
    public var fontSizeSearch: Double = 28.0
    public var fontSizeResultTitle: Double = 16.0
    public var fontSizeResultSubtitle: Double = 12.0
    public var fontSizeSplitPaneItem: Double = 15.0
    public var iconSizeMain: Double = 32.0

    public init() {}
}

public struct AIProvider: Codable, Equatable {
    public var id: String
    public var name: String
    public var type: String  // "foundation" or "byok"
    public var url: String
    public var apiKey: String
    public var modelName: String
    public var searchToolName: String?
    public var supportsImages: Bool

    public init(
        id: String = UUID().uuidString,
        name: String = "",
        type: String = "byok",
        url: String = "",
        apiKey: String = "",
        modelName: String = "",
        searchToolName: String? = nil,
        supportsImages: Bool = false
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.url = url
        self.apiKey = apiKey
        self.modelName = modelName
        self.searchToolName = searchToolName
        self.supportsImages = supportsImages
    }
}

public struct AIConfig: Codable {
    public var isEnabled: Bool = false
    public var isConversationLogEnabled: Bool = false
    public var isMemoryEnabled: Bool = true
    public var isClipboardContextEnabled: Bool = true
    public var isActiveAppContextEnabled: Bool = true
    public var isCalendarContextEnabled: Bool = true
    public var isReminderContextEnabled: Bool = true
    public var isWebContextEnabled: Bool = true
    public var isNotesContextEnabled: Bool = true
    public var notesDirectoryPath: String? = nil
    public var selectedProviderId: String = "foundation-default"
    public var providers: [AIProvider] = []

    // Kept for backward compatibility or migration
    public var selectedModelType: String = "byok"  // "foundation" or "byok"
    public var byokApiKey: String = ""
    public var byokApiUrl: String = "https://api.openai.com/v1/chat/completions"
    public var byokModelName: String = "gpt-4o"
    public var supportsImages: Bool = true
    public var systemPrompt: String = "You are a helpful macOS assistant."
    public var temperature: Double = 0.7
    public var maxTokens: Int = 1024
    public var maxSavedConversations: Int = 50

    private enum CodingKeys: String, CodingKey {
        case isEnabled
        case isConversationLogEnabled
        case isMemoryEnabled
        case isClipboardContextEnabled
        case isActiveAppContextEnabled
        case isCalendarContextEnabled
        case isReminderContextEnabled
        case isWebContextEnabled
        case isNotesContextEnabled
        case notesDirectoryPath
        case selectedProviderId
        case providers
        case selectedModelType
        case byokApiKey
        case byokApiUrl
        case byokModelName
        case supportsImages
        case systemPrompt
        case temperature
        case maxTokens
        case maxSavedConversations
    }

    public init() {
        self.providers = [
            AIProvider(id: "foundation-default", name: "Apple Intelligence", type: "foundation"),
            AIProvider(
                id: "byok-default", name: "Custom BYOK", type: "byok", url: byokApiUrl,
                apiKey: byokApiKey, modelName: byokModelName, supportsImages: supportsImages),
        ]
        self.selectedProviderId =
            selectedModelType == "foundation" ? "foundation-default" : "byok-default"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? false
        isConversationLogEnabled =
            try container.decodeIfPresent(Bool.self, forKey: .isConversationLogEnabled) ?? false
        isMemoryEnabled = try container.decodeIfPresent(Bool.self, forKey: .isMemoryEnabled) ?? true
        isClipboardContextEnabled =
            try container.decodeIfPresent(Bool.self, forKey: .isClipboardContextEnabled) ?? true
        isActiveAppContextEnabled =
            try container.decodeIfPresent(Bool.self, forKey: .isActiveAppContextEnabled) ?? true
        isCalendarContextEnabled =
            try container.decodeIfPresent(Bool.self, forKey: .isCalendarContextEnabled) ?? true
        isReminderContextEnabled =
            try container.decodeIfPresent(Bool.self, forKey: .isReminderContextEnabled) ?? true
        isWebContextEnabled =
            try container.decodeIfPresent(Bool.self, forKey: .isWebContextEnabled) ?? true
        isNotesContextEnabled =
            try container.decodeIfPresent(Bool.self, forKey: .isNotesContextEnabled) ?? true
        notesDirectoryPath = try container.decodeIfPresent(String.self, forKey: .notesDirectoryPath)

        selectedModelType =
            try container.decodeIfPresent(String.self, forKey: .selectedModelType) ?? "byok"
        byokApiKey = try container.decodeIfPresent(String.self, forKey: .byokApiKey) ?? ""
        byokApiUrl =
            try container.decodeIfPresent(String.self, forKey: .byokApiUrl)
            ?? "https://api.openai.com/v1/chat/completions"
        byokModelName =
            try container.decodeIfPresent(String.self, forKey: .byokModelName) ?? "gpt-4o"
        supportsImages = try container.decodeIfPresent(Bool.self, forKey: .supportsImages) ?? true
        systemPrompt =
            try container.decodeIfPresent(String.self, forKey: .systemPrompt)
            ?? "You are a helpful macOS assistant."
        temperature = try container.decodeIfPresent(Double.self, forKey: .temperature) ?? 0.7
        maxTokens = try container.decodeIfPresent(Int.self, forKey: .maxTokens) ?? 1024
        maxSavedConversations =
            try container.decodeIfPresent(Int.self, forKey: .maxSavedConversations) ?? 50

        providers = try container.decodeIfPresent([AIProvider].self, forKey: .providers) ?? []
        selectedProviderId =
            try container.decodeIfPresent(String.self, forKey: .selectedProviderId) ?? ""

        if providers.isEmpty {
            providers = [
                AIProvider(
                    id: "foundation-default", name: "Apple Intelligence", type: "foundation"),
                AIProvider(
                    id: "byok-default", name: "Custom BYOK", type: "byok", url: byokApiUrl,
                    apiKey: byokApiKey, modelName: byokModelName, supportsImages: supportsImages),
            ]
            selectedProviderId =
                selectedModelType == "foundation" ? "foundation-default" : "byok-default"
        }
    }
}

extension AIConfig {
    public var activeProvider: AIProvider? {
        return providers.first(where: { $0.id == selectedProviderId })
    }
}

public struct Config: Codable {
    public var fallbackActions: [String] = ["engine:Google", "engine:NerwAI"]
    public var searchModMapper: [String: String] = [:]
    public var globalKeybind: String = "Cmd+Shift+Space"
    public var onFirstSpace: String = "findfile "
    public var showShortcutsInMain: Bool = false
    public var uiConfig: UIConfig?
    public var layoutConfig: LayoutConfig = LayoutConfig()
    public var snippetExpansionEnabled: Bool = true
    public var clipboardEnabled: Bool = true
    public var bookmarksEnabled: Bool = true
    public var navigationStyle: String = "unix"
    public var aiConfig: AIConfig = AIConfig()

    private enum CodingKeys: String, CodingKey {
        case fallbackActions
        case searchModMapper
        case globalKeybind
        case onFirstSpace
        case showShortcutsInMain
        case uiConfig
        case layoutConfig
        case snippetExpansionEnabled
        case clipboardEnabled
        case bookmarksEnabled
        case navigationStyle
        case aiConfig
    }

    private enum OldCodingKeys: String, CodingKey {
        case defaultSearchEngine
        case fallbackModifier
    }

    public init() {}

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        fallbackActions =
            try container.decodeIfPresent([String].self, forKey: .fallbackActions) ?? []

        // Migration from old defaultSearchEngine
        if fallbackActions.isEmpty {
            let oldContainer = try? decoder.container(keyedBy: OldCodingKeys.self)
            if let oldDefault = try? oldContainer?.decodeIfPresent(
                [String].self, forKey: .defaultSearchEngine)
            {
                if oldDefault.contains("g") || oldDefault.contains("google") {
                    fallbackActions.append("engine:Google")
                } else if oldDefault.contains("ddg") || oldDefault.contains("duckduckgo") {
                    fallbackActions.append("engine:DuckDuckGo")
                } else {
                    fallbackActions.append("engine:Google")
                }
            } else {
                fallbackActions.append("engine:Google")
            }
            fallbackActions.append("engine:NerwAI")
        }

        searchModMapper =
            try container.decodeIfPresent([String: String].self, forKey: .searchModMapper) ?? [:]

        globalKeybind =
            try container.decodeIfPresent(String.self, forKey: .globalKeybind) ?? "Cmd+Shift+Space"

        onFirstSpace =
            try container.decodeIfPresent(String.self, forKey: .onFirstSpace) ?? "findfile "

        showShortcutsInMain =
            try container.decodeIfPresent(Bool.self, forKey: .showShortcutsInMain) ?? false
        uiConfig = try container.decodeIfPresent(UIConfig.self, forKey: .uiConfig)
        layoutConfig =
            try container.decodeIfPresent(LayoutConfig.self, forKey: .layoutConfig)
            ?? LayoutConfig()
        snippetExpansionEnabled =
            try container.decodeIfPresent(Bool.self, forKey: .snippetExpansionEnabled) ?? true
        clipboardEnabled =
            try container.decodeIfPresent(Bool.self, forKey: .clipboardEnabled) ?? true
        bookmarksEnabled =
            try container.decodeIfPresent(Bool.self, forKey: .bookmarksEnabled) ?? true
        navigationStyle =
            try container.decodeIfPresent(String.self, forKey: .navigationStyle) ?? "unix"
        aiConfig =
            try container.decodeIfPresent(AIConfig.self, forKey: .aiConfig) ?? AIConfig()
    }
}

public class ConfigManager {
    public static let shared = ConfigManager()

    public var config: Config

    private let configDirectory: URL
    private let configFile: URL

    private init() {
        self.configDirectory = NerwPaths.configDirectory
        self.configFile = configDirectory.appendingPathComponent("config.json")

        // Initialize with default
        self.config = Config()

        // Load or create
        load()
    }

    public func reload() {
        load()
        NotificationCenter.default.post(name: Notification.Name("NerwConfigDidUpdate"), object: nil)
    }

    public func reset() {
        self.config = Config()
        save()
        reload()
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: configFile.path) else {
            // Create default if not exists
            save()
            return
        }

        print("Nerw: Loading config from: \(configFile.path)")

        do {
            let data = try Data(contentsOf: configFile)
            let decoder = JSONDecoder()
            self.config = try decoder.decode(Config.self, from: data)
        } catch {
            print("Nerw: Failed to load config: \(error). Using defaults.")
            // Maintain defaults
        }
        print("Nerw: Config loaded. Fallbacks: \(config.fallbackActions)")
    }

    public func save() {
        do {
            if !FileManager.default.fileExists(atPath: configDirectory.path) {
                try FileManager.default.createDirectory(
                    at: configDirectory, withIntermediateDirectories: true)
            }

            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(config)
            try data.write(to: configFile)
        } catch {
            print("Nerw: Failed to save config: \(error)")
        }

        // Notify listeners
        NotificationCenter.default.post(name: Notification.Name("NerwConfigDidUpdate"), object: nil)
    }
}
