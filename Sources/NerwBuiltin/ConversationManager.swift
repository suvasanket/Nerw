import Cocoa
import NerwAction
import NerwCore

public class ConversationManager {
    public static let shared = ConversationManager()

    public var showWindowCallback: ((String?) -> Void)?

    private init() {}

    public static func builtinActions() -> [NerwAction] {
        return [
            NerwAction(
                id: "builtin.aiquery",
                title: "Ask AI",
                subtitle: "Query NerwAi",
                icon: .system("sparkle.magnifyingglass"),
                category: .webSearch,
                triggers: ["ai", "chat", "ask", "assistant"],
                type: .inlineArg(perform: { _, query in
                    DispatchQueue.main.async {
                        ConversationManager.shared.showWindowCallback?(query)
                    }
                })
            )
        ]
    }
}
