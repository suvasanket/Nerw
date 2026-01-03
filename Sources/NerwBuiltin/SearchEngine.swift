import Cocoa

import NerwSearchBackend

public struct Engine {
    public let name: String
    public let triggers: [String]
    public let urlTemplate: String
    public let iconName: String
}

public class SearchEngine {
    public static let shared = SearchEngine()

    public private(set) var engines: [Engine] = [
        Engine(name: "Google Search", triggers: ["google", "goo"], urlTemplate: "https://www.google.com/search?q=%@", iconName: "magnifyingglass"),
        Engine(name: "Bing Search", triggers: ["bing"], urlTemplate: "https://www.bing.com/search?q=%@", iconName: "magnifyingglass"),
        Engine(name: "DuckDuckGo Search", triggers: ["duck", "ddg"], urlTemplate: "https://duckduckgo.com/?q=%@", iconName: "magnifyingglass"),
        Engine(name: "Yahoo Search", triggers: ["yahoo"], urlTemplate: "https://search.yahoo.com/search?p=%@", iconName: "magnifyingglass")
    ]

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
                      let urlTemplate = dict["urlTemplate"] else { return nil }
                return CustomEngine(name: name, trigger: trigger, urlTemplate: urlTemplate, icon: dict["icon"])
            }
        }
    }

    private func saveCustomEngines() {
        let dicts: [[String: String]] = customEngines.map { engine in
            var dict = [
                "name": engine.name,
                "trigger": engine.trigger,
                "urlTemplate": engine.urlTemplate
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
        } else {
            name = trigger.capitalized
        }

        let newEngine = CustomEngine(name: name, trigger: trigger, urlTemplate: template, icon: "magnifyingglass")
        customEngines.append(newEngine)
        saveCustomEngines()
    }

    public func check(query: String) -> BuiltinResult? {
        let lowerQuery = query.lowercased()

        // Check Hardcoded Engines
        for engine in engines {
            if engine.triggers.contains(where: { $0.starts(with: lowerQuery) }) {
                return BuiltinResult(
                    title: engine.name,
                    subtitle: "Search web using \(engine.name)",
                    iconName: engine.iconName,
                    supportsArguments: true
                ) { argument in
                    let encodedQuery = argument.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                    let urlString = String(format: engine.urlTemplate, encodedQuery)
                    if let url = URL(string: urlString) {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }

        // Check Custom Engines
        for engine in customEngines {
             if engine.trigger.starts(with: lowerQuery) {
                 return BuiltinResult(
                     title: engine.name,
                     subtitle: "Search web using \(engine.name) (\(engine.trigger))",
                     iconName: engine.icon,
                     supportsArguments: true
                 ) { argument in
                     let encodedQuery = argument.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                     // Handle both %s (if user entered raw) and %@ (our format) just in case
                     // But we convert on save, so %@ is standard.
                     let urlString = String(format: engine.urlTemplate, encodedQuery)
                     if let url = URL(string: urlString) {
                         NSWorkspace.shared.open(url)
                     }
                 }
             }
        }

        return nil
    }
}
