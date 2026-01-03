import Cocoa

import NerwSearchBackend

public struct Engine {
    public let name: String
    public let triggers: [String]
    public let urlTemplate: String
}

public class SearchEngine {
    public static let shared = SearchEngine()

    public private(set) var engines: [Engine] = [
        Engine(name: "Google", triggers: ["google"], urlTemplate: "https://www.google.com/search?q=%@"),
        Engine(name: "Feeling Lucky", triggers: ["gl", "googlelucky"], urlTemplate: "https://www.google.com/search?btnI=1&q=%@"),
        Engine(name: "DuckDuckGo", triggers: ["duckduckgo"], urlTemplate: "https://duckduckgo.com/?q=%@"),
        Engine(name: "Bing", triggers: ["bing"], urlTemplate: "https://www.bing.com/search?q=%@"),
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
            // Pre-fetch icon
            IconManager.shared.fetchIcon(for: host) { _ in }
        } else {
            name = trigger.capitalized
        }

        let newEngine = CustomEngine(name: name, trigger: trigger, urlTemplate: template, icon: "globe") // Default placeholder
        customEngines.append(newEngine)
        saveCustomEngines()
    }

    public func check(query: String) -> BuiltinResult? {
        let lowerQuery = query.lowercased()

        // Check Hardcoded Engines
        for engine in engines {
            if engine.triggers.contains(where: { $0.starts(with: lowerQuery) }) {
                let domain = URL(string: engine.urlTemplate.replacingOccurrences(of: "%@", with: ""))?.host ?? engine.name
                let icon = IconManager.shared.icon(for: domain)
                if icon == nil { IconManager.shared.fetchIcon(for: domain) { _ in } }
                
                return BuiltinResult(
                    title: engine.name,
                    subtitle: "Search web using \(engine.name)",
                    iconName: icon == nil ? "globe" : nil,
                    icon: icon,
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
                 let domain = URL(string: engine.urlTemplate.replacingOccurrences(of: "%@", with: ""))?.host ?? engine.name
                 let icon = IconManager.shared.icon(for: domain)
                 if icon == nil { IconManager.shared.fetchIcon(for: domain) { _ in } }

                 return BuiltinResult(
                     title: engine.name,
                     subtitle: "Search web using \(engine.name) (\(engine.trigger))",
                     iconName: icon == nil ? "globe" : nil,
                     icon: icon,
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

        return nil
    }

    public func getSuggestions(for query: String) -> [BuiltinResult] {
        var results: [BuiltinResult] = []
        let configDefaults = ConfigManager.shared.config.defaultSearchEngine
        let useSmartRanking = configDefaults.count > 1

        // Helper to create result
        func createResult(name: String, urlTemplate: String) -> BuiltinResult {
             let domain = URL(string: urlTemplate.replacingOccurrences(of: "%@", with: ""))?.host ?? name
             let icon = IconManager.shared.icon(for: domain)
             if icon == nil { IconManager.shared.fetchIcon(for: domain) { _ in } }
             
             return BuiltinResult(
                  title: name,
                  subtitle: "Search for '\(query)'",
                  iconName: icon == nil ? "globe" : nil,
                  icon: icon,
                  supportsArguments: false // Direct execution
              ) { _ in
                  // Record usage if smart ranking is active
                  if useSmartRanking {
                      FrecencyManager.shared.recordUsage(id: "search_pref:\(query):\(name)")
                  }
                  
                  let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                  // Handle standard format
                  let urlString = String(format: urlTemplate, encodedQuery)
                  if let url = URL(string: urlString) {
                      NSWorkspace.shared.open(url)
                  }
              }
        }

        // Collect Candidates
        struct Candidate {
            let name: String
            let urlTemplate: String
            let score: Double
        }
        
        var candidates: [Candidate] = []

        // Standard Engines
        for engine in engines {
            if engine.triggers.contains(where: { configDefaults.contains($0) }) {
                let score = useSmartRanking ? FrecencyManager.shared.score(for: "search_pref:\(query):\(engine.name)") : 0.0
                candidates.append(Candidate(name: engine.name, urlTemplate: engine.urlTemplate, score: score))
            }
        }

        // Custom Engines
        for engine in customEngines {
            if configDefaults.contains(engine.trigger) {
                let score = useSmartRanking ? FrecencyManager.shared.score(for: "search_pref:\(query):\(engine.name)") : 0.0
                candidates.append(Candidate(name: engine.name, urlTemplate: engine.urlTemplate, score: score))
            }
        }
        
        // Sort
        if useSmartRanking {
            candidates.sort { $0.score > $1.score }
        }
        
        // Map to Results
        results = candidates.map { createResult(name: $0.name, urlTemplate: $0.urlTemplate) }
        
        return results
    }
    
    public func findByTrigger(_ trigger: String) -> BuiltinResult? {
        let lowerTrigger = trigger.lowercased()
        
        // Check Hardcoded Engines
        if let engine = engines.first(where: { $0.triggers.contains(lowerTrigger) }) {
            let domain = URL(string: engine.urlTemplate.replacingOccurrences(of: "%@", with: ""))?.host ?? engine.name
            let icon = IconManager.shared.icon(for: domain)
            if icon == nil { IconManager.shared.fetchIcon(for: domain) { _ in } }
            
            return BuiltinResult(
                title: engine.name,
                subtitle: "Search web using \(engine.name)",
                iconName: icon == nil ? "globe" : nil,
                icon: icon,
                supportsArguments: true
            ) { argument in
                let encodedQuery = argument.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                let urlString = String(format: engine.urlTemplate, encodedQuery)
                if let url = URL(string: urlString) {
                    NSWorkspace.shared.open(url)
                }
            }
        }
        
        // Check Custom Engines
        if let engine = customEngines.first(where: { $0.trigger == lowerTrigger }) {
             let domain = URL(string: engine.urlTemplate.replacingOccurrences(of: "%@", with: ""))?.host ?? engine.name
             let icon = IconManager.shared.icon(for: domain)
             if icon == nil { IconManager.shared.fetchIcon(for: domain) { _ in } }
             
             return BuiltinResult(
                 title: engine.name,
                 subtitle: "Search web using \(engine.name) (\(engine.trigger))",
                 iconName: icon == nil ? "globe" : nil,
                 icon: icon,
                 supportsArguments: true
             ) { argument in
                 let encodedQuery = argument.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                 let urlString = String(format: engine.urlTemplate, encodedQuery)
                 if let url = URL(string: urlString) {
                     NSWorkspace.shared.open(url)
                 }
             }
        }
        
        return nil
    }
}
