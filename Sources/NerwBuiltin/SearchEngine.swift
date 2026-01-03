import Cocoa

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

    private init() {}

    public func check(query: String) -> BuiltinResult? {
        let lowerQuery = query.lowercased()

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

        return nil
    }
}
