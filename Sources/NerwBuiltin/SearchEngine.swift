import Cocoa
import NerwCore
import NerwSearchBackend

public struct Engine: Codable {
    public let name: String
    public let triggers: [String]
    public let urlTemplate: String
    public let icon: String?  // Optional icon name or URL
    public var isEnabled: Bool

    public init(
        name: String, triggers: [String], urlTemplate: String, icon: String? = nil,
        isEnabled: Bool = true
    ) {
        self.name = name
        self.triggers = triggers
        self.urlTemplate = urlTemplate
        self.icon = icon
        self.isEnabled = isEnabled
    }

    // Custom decoding to handle migration
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        triggers = try container.decode([String].self, forKey: .triggers)
        urlTemplate = try container.decode(String.self, forKey: .urlTemplate)
        icon = try container.decodeIfPresent(String.self, forKey: .icon)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
    }
}

public class SearchEngine {
    public static let shared = SearchEngine()

    public private(set) var engines: [Engine] = []

    private let fileManager = FileManager.default
    private var storageURL: URL? {
        guard
            let appSupport = fileManager.urls(
                for: .applicationSupportDirectory, in: .userDomainMask
            ).first
        else { return nil }
        let dir = appSupport.appendingPathComponent("Nerw")
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("Bangs.json")
    }

    private init() {
        loadEngines()
    }

    private func getDefaults() -> [Engine] {
        return [
            Engine(
                name: "Google", triggers: ["google", "g"],
                urlTemplate: "https://www.google.com/search?q=%@", icon: "se_google"),
            Engine(
                name: "DuckDuckGo", triggers: ["duckduckgo", "ddg"],
                urlTemplate: "https://duckduckgo.com/?q=%@", icon: "se_duckduckgo"),
            Engine(
                name: "Ducky Search", triggers: ["ducky", "dy"],
                urlTemplate: "ducky://%@", icon: "se_ducky"),
        ]
    }

    private func loadEngines() {
        guard let url = storageURL,
            let data = try? Data(contentsOf: url),
            var loaded = try? JSONDecoder().decode([Engine].self, from: data)
        else {
            // First run or error: Load defaults
            engines = getDefaults()
            saveEngines()
            return
        }

        // 1. Remove old defaults that are no longer in our built-in list
        let unwantedDefaults = ["Feeling Lucky", "Bing", "YouTube", "GitHub"]
        loaded.removeAll { engine in
            unwantedDefaults.contains(engine.name)
        }

        // 2. Ensure our core built-ins are always present and icons are updated
        let defaults = getDefaults()
        for defaultEngine in defaults {
            if let existingIdx = loaded.firstIndex(where: { $0.name == defaultEngine.name }) {
                // Update icon if it's one of the new built-in names (migration)
                if loaded[existingIdx].icon != defaultEngine.icon {
                    loaded[existingIdx] = Engine(
                        name: defaultEngine.name,
                        triggers: defaultEngine.triggers,
                        urlTemplate: defaultEngine.urlTemplate,
                        icon: defaultEngine.icon,
                        isEnabled: loaded[existingIdx].isEnabled
                    )
                }
            } else {
                loaded.append(defaultEngine)
            }
        }

        engines = loaded
        saveEngines()
    }

    private func saveEngines() {
        guard let url = storageURL else { return }
        do {
            let data = try JSONEncoder().encode(engines)
            try data.write(to: url)
        } catch {
            print("Failed to save Bangs: \(error)")
        }
    }

    public func getDefaultEngine() -> Engine {
        let configTriggers = ConfigManager.shared.config.defaultSearchEngine
        // Find engine that matches AT LEAST ONE of the config triggers
        if let engine = engines.first(where: { engine in
            engine.isEnabled && !Set(engine.triggers).isDisjoint(with: configTriggers)
        }) {
            return engine
        }

        // Fallback to first enabled if Google missing (unlikely)
        return engines.first(where: { $0.name == "Google" && $0.isEnabled })
            ?? engines.first(where: { $0.isEnabled })
            ?? engines.first!
    }

    public func setDefaultEngine(_ engine: Engine) {
        var config = ConfigManager.shared.config
        config.defaultSearchEngine = engine.triggers
        ConfigManager.shared.config = config
        ConfigManager.shared.save()
    }

    public func addEngine(name: String, url: String, trigger: String, icon: String? = nil) {
        // Convert %s to %@ for format string if needed
        let template = url.replacingOccurrences(of: "%s", with: "%@")
        let newEngine = Engine(name: name, triggers: [trigger], urlTemplate: template, icon: icon)
        engines.append(newEngine)
        saveEngines()
    }

    public func removeEngine(name: String) {
        if isBuiltIn(name: name) { return }
        engines.removeAll { $0.name == name }
        saveEngines()
    }

    public func toggleEngine(name: String, enabled: Bool) {
        guard let idx = engines.firstIndex(where: { $0.name == name }) else { return }
        engines[idx].isEnabled = enabled
        saveEngines()
    }

    public func isBuiltIn(name: String) -> Bool {
        let defaults = ["Google", "DuckDuckGo", "Ducky Search"]
        return defaults.contains(name)
    }

    /// Updates an existing engine by replacing it with new values.
    public func updateEngine(
        originalName: String, name: String, url: String, trigger: String, icon: String? = nil
    ) {
        // Protect built-ins: don't rename or edit them via the normal UI
        if isBuiltIn(name: originalName) { return }

        let template = url.replacingOccurrences(of: "%s", with: "%@")
        guard let idx = engines.firstIndex(where: { $0.name == originalName }) else { return }
        engines[idx] = Engine(
            name: name,
            triggers: [trigger],
            urlTemplate: template,
            icon: icon ?? engines[idx].icon,
            isEnabled: engines[idx].isEnabled
        )
        saveEngines()
    }

    /// Resolves a query to see if it contains a "Bang" trigger (e.g. !g, !yt).
    /// Returns the matched engine info and the CLEANED query (bang removed).
    public func resolveBang(query: String) -> (
        name: String, urlTemplate: String, cleanedQuery: String
    )? {
        let tokens = query.split(separator: " ")

        // Find the first token that looks like a bang (starts with !)
        for (index, token) in tokens.enumerated() {
            if token.starts(with: "!") {
                let bangTrigger = String(token.dropFirst()).lowercased()

                // Check All Enabled Engines
                if let engine = engines.first(where: {
                    $0.isEnabled && $0.triggers.contains(bangTrigger)
                }) {
                    var newTokens = tokens
                    newTokens.remove(at: index)
                    let cleanedQuery = newTokens.joined(separator: " ")
                    return (engine.name, engine.urlTemplate, cleanedQuery)
                }
            }
        }

        return nil
    }
}
