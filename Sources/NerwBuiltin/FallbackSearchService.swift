import Cocoa
import NerwAction
import NerwCore

public class FallbackSearchService {
    public static let shared = FallbackSearchService()

    private init() {}

    public func getFallbackActions(for query: String, allCandidates: [NerwAction]) -> [NerwAction] {
        let fallbackIDs = ConfigManager.shared.config.fallbackActions
        var fallbacks: [NerwAction] = []

        for id in fallbackIDs {
            if id.starts(with: "engine:") {
                let engineName = String(id.dropFirst("engine:".count))
                if let engine = SearchEngine.shared.engines.first(where: {
                    $0.name == engineName && $0.isEnabled
                }) {
                    fallbacks.append(
                        WebSearchService.shared.createWebSearchAction(query: query, engine: engine))
                }
            } else if id.starts(with: "action:") {
                let actionID = String(id.dropFirst("action:".count))
                if let action = allCandidates.first(where: { $0.id == actionID }) {
                    let wrapped = self.createActionFallback(query: query, action: action)
                    fallbacks.append(wrapped)
                }
            }
        }

        // Ensure we always have at least one fallback (Google) if config is empty or invalid
        if fallbacks.isEmpty {
            if let firstEngine = SearchEngine.shared.engines.first(where: {
                $0.name == "Google" && $0.isEnabled
            }) ?? SearchEngine.shared.engines.first {
                fallbacks.append(
                    WebSearchService.shared.createWebSearchAction(query: query, engine: firstEngine)
                )
            }
        }

        return fallbacks
    }

    public func createActionFallback(query: String, action: NerwAction) -> NerwAction {
        return NerwAction(
            id: "nerw.fallback.\(action.id)",
            title: "\(action.title) '\(query)'",
            subtitle: action.subtitle,
            icon: action.icon,
            type: .instant(perform: { _ in
                switch action.type {
                case .inlineArg(let perform, _):
                    perform(action, query)
                case .args(_, _, let perform):
                    perform?(action, query)
                case .arg(_, let perform):
                    perform(action, [query])
                default:
                    // For other types, just open the action if possible or do nothing.
                    break
                }
            })
        )
    }
}
