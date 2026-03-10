import Cocoa
import NerwCore
import NerwSearchBackend

public class Nerw {
    public static let shared = Nerw()

    private init() {}

    public func getAllActions() -> [NerwAction] {
        return [
            NerwAction(
                id: "nerw.builtin.quit",
                title: "Quit Nerw",
                subtitle: "Terminate the application",
                icon: .system("power"),
                triggers: ["nerw quit"],
                type: .instant(perform: { _ in
                    NSApp.terminate(nil)
                })
            )
        ]
    }

    public func findByTrigger(_ trigger: String) -> NerwAction? {
        let lowerTrigger = trigger.lowercased()
        if "nerw quit" == lowerTrigger {
            return NerwAction(
                id: "nerw.builtin.quit",
                title: "Quit Nerw",
                subtitle: "Terminate the application",
                icon: .system("power"),
                triggers: ["nerw quit"],
                type: .instant(perform: { _ in NSApp.terminate(nil) })
            )
        }

        return nil
    }
}
