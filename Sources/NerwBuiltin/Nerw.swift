import Cocoa
import NerwAction
import NerwCore
import NerwSearchBackend

public class Nerw {
    public static let shared = Nerw()

    private init() {}

    public static func notify(
        _ content: String, level: NerwNotificationLevel = .info, progressive: Bool = false,
        id: UUID? = nil
    ) {
        NerwSystem.shared.ui?.showNotification(
            content: content, level: level, progressive: progressive, id: id)
    }

    public static func dismissNotify(id: UUID) {
        NerwSystem.shared.ui?.dismissNotification(id: id)
    }

    public var showHubCallback: ((String?) -> Void)?

    public func getAllActions() -> [NerwAction] {
        var actions = [
            NerwAction(
                id: "nerw.builtin.quit",
                title: "Quit Nerw",
                subtitle: "Terminate the application",
                icon: .system("xmark.circle.fill"),
                triggers: ["nerw quit"],
                type: .instant(perform: { _ in
                    NSApp.terminate(nil)
                })
            )
        ]

        actions.append(
            NerwAction(
                id: "nerw.builtin.hub",
                title: "NerwHub",
                subtitle: "Open NerwHub",
                icon: .system("square.stack.3d.down.forward.fill"),
                triggers: ["nerwhub", "hub"],
                type: .instant(perform: { _ in
                    DispatchQueue.main.async {
                        Nerw.shared.showHubCallback?(nil)
                    }
                })
            )
        )

        actions.append(
            NerwAction(
                id: "nerw.builtin.hub.memory",
                title: "NerwAI Memory",
                subtitle: "View and manage AI memories",
                icon: .system("brain.head.profile"),
                triggers: ["memory", "hub", "ai memory"],
                type: .instant(perform: { _ in
                    DispatchQueue.main.async {
                        Nerw.shared.showHubCallback?("memory")
                    }
                })
            )
        )

        actions.append(
            NerwAction(
                id: "nerw.builtin.hub.bookmarks",
                title: "Bookmarks",
                subtitle: "View and manage bookmarks",
                icon: .system("bookmark.circle.fill"),
                triggers: ["bookmarks", "hub"],
                type: .instant(perform: { _ in
                    DispatchQueue.main.async {
                        Nerw.shared.showHubCallback?("bookmarks")
                    }
                })
            )
        )

        if ConfigManager.shared.config.aiConfig.isEnabled {
            actions.append(
                NerwAction(
                    id: "nerw.builtin.hub.conversations",
                    title: "NerwAI conversations",
                    subtitle: "View and manage AI conversations",
                    icon: .system("bubble.left.and.bubble.right"),
                    triggers: ["conversations", "hub", "ai conversations"],
                    type: .instant(perform: { _ in
                        DispatchQueue.main.async {
                            Nerw.shared.showHubCallback?("conversations")
                        }
                    })
                )
            )

            actions.append(
                NerwAction(
                    id: "nerw.builtin.ai",
                    title: "NerwAI",
                    subtitle: "Open NerwAI chat panel",
                    icon: .system("00.circle.fill.hi"),
                    triggers: ["nerwai", "ai", "chat"],
                    type: .instant(perform: { _ in
                        DispatchQueue.main.async {
                            ConversationManager.shared.showWindowCallback?(nil)
                        }
                    })
                )
            )
        }

        return actions
    }
}
