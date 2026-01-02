import Cocoa

public class GoogleSearch {
    public static let shared = GoogleSearch()

    private init() {}

    public func check(query: String) -> BuiltinResult? {
        // Simple trigger matching
        let trigger = "google"

        // Check if query starts with "g" or "goo" or is "google"
        if trigger.starts(with: query.lowercased()) {
            return BuiltinResult(
                title: "Google Search",
                subtitle: "Search Google",
                iconName: "magnifyingglass", // SF Symbol
                supportsArguments: true
            ) { argument in
                // Handler
                let encodedQuery = argument.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                let urlString = "https://www.google.com/search?q=\(encodedQuery)"
                if let url = URL(string: urlString) {
                    NSWorkspace.shared.open(url)
                }
            }
        }

        return nil
    }
}
