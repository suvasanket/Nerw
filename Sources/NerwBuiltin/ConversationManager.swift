import Cocoa
import NerwAction
import NerwCore

public class ConversationManager {
    public static let shared = ConversationManager()

    public var showWindowCallback: (() -> Void)?

    private init() {}

    public static func builtinActions() -> [NerwAction] {
        return [
            NerwAction(
                id: "builtin.aichat",
                title: "AI Chat",
                subtitle: "Start a conversation with AI",
                icon: .system("cpu"),
                triggers: ["ai", "chat", "ask", "assistant"],
                type: .instant(perform: { _ in
                    DispatchQueue.main.async {
                        ConversationManager.shared.showWindowCallback?()
                    }
                })
            )
        ]
    }
}
