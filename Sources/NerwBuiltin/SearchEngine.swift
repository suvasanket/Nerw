import Cocoa
import NerwCore
import NerwSearchBackend

public struct Engine: Codable {
    public let name: String
    public let triggers: [String]
    public let urlTemplate: String
    public let icon: String?  // Optional icon name or URL

    public init(name: String, triggers: [String], urlTemplate: String, icon: String? = nil) {
        self.name = name
        self.triggers = triggers
        self.urlTemplate = urlTemplate
        self.icon = icon
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
                urlTemplate: "https://www.google.com/search?q=%@"),
            Engine(
                name: "Feeling Lucky", triggers: ["gl", "googlelucky"],
                urlTemplate: "https://www.google.com/search?btnI=1&q=%@"),
            Engine(
                name: "DuckDuckGo", triggers: ["duckduckgo", "ddg"],
                urlTemplate: "https://duckduckgo.com/?q=%@"),
            Engine(
                name: "Bing", triggers: ["bing", "b"],
                urlTemplate: "https://www.bing.com/search?q=%@"),
            Engine(
                name: "YouTube", triggers: ["youtube", "yt"],
                urlTemplate: "https://www.youtube.com/results?search_query=%@"),
            Engine(
                name: "GitHub", triggers: ["github", "gh"],
                urlTemplate: "https://github.com/search?q=%@"),
            Engine(
                name: "Ducky Search", triggers: ["ducky", "dy"],
                urlTemplate: "ducky://%@", icon: "ducky"),
        ]
    }

    private func loadEngines() {
        guard let url = storageURL,
            let data = try? Data(contentsOf: url),
            let loaded = try? JSONDecoder().decode([Engine].self, from: data)
        else {
            // First run or error: Load defaults
            engines = getDefaults()
            saveEngines()
            return
        }
        engines = loaded

        // Ensure "Ducky Search" is always present, even if older config loaded
        if !engines.contains(where: { $0.name == "Ducky Search" }) {
            // Also remove the old "Smart" one if it exists from our earlier experiment
            engines.removeAll { $0.name == "Smart" }
            engines.append(
                Engine(
                    name: "Ducky Search", triggers: ["ducky", "dy"],
                    urlTemplate: "ducky://%@", icon: "ducky")
            )
            saveEngines()
        }
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
            !Set(engine.triggers).isDisjoint(with: configTriggers)
        }) {
            return engine
        }

        // Fallback to first if Google missing (unlikely)
        return engines.first(where: { $0.name == "Google" }) ?? engines.first!
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
        if name == "Ducky Search" { return }  // Ducky Search engine cannot be deleted
        engines.removeAll { $0.name == name }
        saveEngines()
    }

    /// Updates an existing engine by replacing it with new values.
    public func updateEngine(
        originalName: String, name: String, url: String, trigger: String, icon: String? = nil
    ) {
        // Protect built-ins: don't rename Ducky Search
        let safeName = (originalName == "Ducky Search") ? originalName : name
        let template = url.replacingOccurrences(of: "%s", with: "%@")
        guard let idx = engines.firstIndex(where: { $0.name == originalName }) else { return }
        engines[idx] = Engine(
            name: safeName,
            triggers: [trigger],
            urlTemplate: template,
            icon: icon ?? engines[idx].icon
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

                // Check All Engines
                if let engine = engines.first(where: { $0.triggers.contains(bangTrigger) }) {
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
