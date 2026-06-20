import Cocoa
import NerwAction
import NerwCore

public class WebSearchService {
    public static let shared = WebSearchService()

    private init() {}

    public func resolveIcon(for engine: Engine, domain: String) -> NerwAction.IconType? {
        if let iconStr = engine.icon {
            if let url = URL(string: iconStr), url.isFileURL {
                return .file(url)
            }
            if let icon = NSImage(named: NSImage.Name(iconStr)) {
                return .image(icon)
            }
            if let icon = IconManager.shared.icon(forKey: iconStr) {
                return .image(icon)
            }
        }

        if domain.contains("google.com") {
            if let icon = NSImage(named: "se_google") {
                return .image(icon)
            }
        }
        if domain.contains("duckduckgo.com") {
            if let icon = NSImage(named: "se_duckduckgo") {
                return .image(icon)
            }
        }
        if domain.contains("duck.ai") {
            if let icon = NSImage(named: "se_duckduckgo") {
                return .image(icon)
            }
        }

        if let icon = IconManager.shared.icon(for: domain) {
            return .image(icon)
        }

        return .system("globe")
    }

    public func createWebSearchAction(query: String, engine: Engine) -> NerwAction {
        let domain =
            URL(string: engine.urlTemplate.replacingOccurrences(of: "%@", with: ""))?.host
            ?? engine.name
        let iconType = self.resolveIcon(for: engine, domain: domain)

        return NerwAction(
            id: "nerw.web.search.\(engine.name)",
            title: "Search \(engine.name)",
            subtitle: "Search for '\(query)' on \(engine.name)",
            icon: iconType ?? .system("globe"),
            category: .webSearch,
            triggers: [],
            type: .instant(perform: { _ in
                let encodedQuery =
                    query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                let urlString = String(format: engine.urlTemplate, encodedQuery)
                if let url = URL(string: urlString) {
                    NSWorkspace.shared.open(url)
                }
            })
        )
    }
}
