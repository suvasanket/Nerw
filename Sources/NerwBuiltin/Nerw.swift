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

    public func getAllActions() -> [NerwAction] {
        return [
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
    }
}
