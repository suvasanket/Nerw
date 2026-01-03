import Foundation

public struct Config: Codable {
    public var SearchEngineSuggestThreshold: Int = 3
    public var defaultSearchEngine: [String] = ["Google Search"]
    public var globalKeybind: String = "Cmd+Shift+Space"
    
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
        
        do {
            let data = try Data(contentsOf: configFile)
            let decoder = JSONDecoder()
            self.config = try decoder.decode(Config.self, from: data)
        } catch {
            print("Nerw: Failed to load config: \(error). Using defaults.")
            // Maintain defaults
        }
    }
    
    public func save() {
        do {
            if !FileManager.default.fileExists(atPath: configDirectory.path) {
                try FileManager.default.createDirectory(at: configDirectory, withIntermediateDirectories: true)
            }
            
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(config)
            try data.write(to: configFile)
        } catch {
            print("Nerw: Failed to save config: \(error)")
        }
    }
}
