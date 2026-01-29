import Foundation

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

public struct Config: Codable {
    public var searchEngineSuggestThreshold: Int = 3
    public var defaultSearchEngine: [String] = ["google", "gl"]
    public var globalKeybind: String = "Cmd+Shift+Space"
    public var findFileOnSpace: Bool = true
    public var uiConfig: UIConfig?

    public init() {}
}

public class ConfigManager {
    public static let shared = ConfigManager()

    public var config: Config

    private let configDirectory: URL
    private let configFile: URL

    private init() {
        // Default paths
        let home = FileManager.default.homeDirectoryForCurrentUser
        self.configDirectory = home.appendingPathComponent(".config/nerw")
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
