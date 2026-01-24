import Cocoa
import NerwCore
import NerwSearchBackend

public struct Engine {
    public let name: String
    public let triggers: [String]
    public let urlTemplate: String
}

public class SearchEngine {
    public static let shared = SearchEngine()

    public private(set) var engines: [Engine] = [
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
            name: "Bing", triggers: ["bing", "b"], urlTemplate: "https://www.bing.com/search?q=%@"),
        Engine(
            name: "YouTube", triggers: ["youtube", "yt"],
            urlTemplate: "https://www.youtube.com/results?search_query=%@"),
        Engine(
            name: "GitHub", triggers: ["github", "gh"],
            urlTemplate: "https://github.com/search?q=%@"),
    ]

    public func getDefaultEngine() -> Engine {
        // Hardcoded return for Google as per requirement
        return engines.first(where: { $0.name == "Google" })!
    }

    private let customEnginesKey = "NerwCustomEngines"

    struct CustomEngine {
        let name: String
        let trigger: String
        let urlTemplate: String
        let icon: String?
    }

    private var customEngines: [CustomEngine] = []

    private init() {
        loadCustomEngines()
    }

    private func loadCustomEngines() {
        if let saved = CacheManager.shared.get(forKey: customEnginesKey) as? [[String: String]] {
            customEngines = saved.compactMap { dict in
                guard let name = dict["name"],
                    let trigger = dict["trigger"],
                    let urlTemplate = dict["urlTemplate"]
                else { return nil }
                return CustomEngine(
                    name: name, trigger: trigger, urlTemplate: urlTemplate, icon: dict["icon"])
            }
        }
    }

    private func saveCustomEngines() {
        let dicts: [[String: String]] = customEngines.map { engine in
            var dict = [
                "name": engine.name,
                "trigger": engine.trigger,
                "urlTemplate": engine.urlTemplate,
            ]
            if let icon = engine.icon {
                dict["icon"] = icon
            }
            return dict
        }
        CacheManager.shared.set(dicts, forKey: customEnginesKey)
    }

    public func addEngine(url: String, trigger: String) {
        // Convert %s to %@ for format string
        let template = url.replacingOccurrences(of: "%s", with: "%@")

        // Simple name generation
        let name: String
        if let host = URL(string: url.replacingOccurrences(of: "%s", with: "test"))?.host {
            name = host
            // Pre-fetch icon
            IconManager.shared.fetchIcon(for: host) { _ in }
        } else {
            name = trigger.capitalized
        }

        let newEngine = CustomEngine(
            name: name, trigger: trigger, urlTemplate: template, icon: "globe")  // Default placeholder
        customEngines.append(newEngine)
        saveCustomEngines()
    }

    /// Resolves a query to see if it contains a "Bang" trigger (e.g. !g, !yt).
    /// Returns the matched engine info and the CLEANED query (bang removed).
    public func resolveBang(query: String) -> (
        name: String, urlTemplate: String, cleanedQuery: String
    )? {
        let tokens = query.split(separator: " ")

        // Find the first token that looks like a bang (starts with !)
        // We iterate through tokens to find the *first* valid bang.
        for (index, token) in tokens.enumerated() {
            if token.starts(with: "!") {
                let bangTrigger = String(token.dropFirst()).lowercased()

                // Check Built-in Engines
                if let engine = engines.first(where: { $0.triggers.contains(bangTrigger) }) {
                    var newTokens = tokens
                    newTokens.remove(at: index)
                    let cleanedQuery = newTokens.joined(separator: " ")
                    return (engine.name, engine.urlTemplate, cleanedQuery)
                }

                // Check Custom Engines
                if let custom = customEngines.first(where: { $0.trigger == bangTrigger }) {
                    var newTokens = tokens
                    newTokens.remove(at: index)
                    let cleanedQuery = newTokens.joined(separator: " ")
                    return (custom.name, custom.urlTemplate, cleanedQuery)
                }
            }
        }

        return nil
    }
}
