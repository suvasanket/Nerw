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
    public var fontSizeSearch: Double = 25.0
    public var fontSizeResultTitle: Double = 14.0
    public var fontSizeResultSubtitle: Double = 11.0
    public var fontSizeSplitPaneItem: Double = 15.0
    public var iconSizeMain: Double = 26.0

    public init() {}
}

public struct Config: Codable {
    public var defaultSearchEngine: [String] = ["google", "g"]
    public var globalKeybind: String = "Cmd+Shift+Space"
    public var findFileOnSpace: Bool = true
    public var showShortcutsInMain: Bool = false
    public var uiConfig: UIConfig?
    public var layoutConfig: LayoutConfig = LayoutConfig()
    public var searchEngineModifiers: [String: [String]] = ["shift": ["lucky"]]
    public var snippetExpansionEnabled: Bool = true

    public init() {}

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        defaultSearchEngine =
            try container.decodeIfPresent([String].self, forKey: .defaultSearchEngine) ?? [
                "google", "g",
            ]
        globalKeybind =
            try container.decodeIfPresent(String.self, forKey: .globalKeybind) ?? "Cmd+Shift+Space"
        findFileOnSpace = try container.decodeIfPresent(Bool.self, forKey: .findFileOnSpace) ?? true
        showShortcutsInMain =
            try container.decodeIfPresent(Bool.self, forKey: .showShortcutsInMain) ?? false
        uiConfig = try container.decodeIfPresent(UIConfig.self, forKey: .uiConfig)
        layoutConfig =
            try container.decodeIfPresent(LayoutConfig.self, forKey: .layoutConfig)
            ?? LayoutConfig()
        searchEngineModifiers =
            try container.decodeIfPresent([String: [String]].self, forKey: .searchEngineModifiers)
            ?? ["shift": ["lucky"]]
        snippetExpansionEnabled =
            try container.decodeIfPresent(Bool.self, forKey: .snippetExpansionEnabled) ?? true
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
        print("Nerw: Config loaded. Engines: \(config.defaultSearchEngine)")
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
