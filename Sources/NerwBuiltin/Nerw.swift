import Cocoa
import NerwAction
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
                icon: .image(
                    NSImage(named: "quit") ?? NSImage(
                        systemSymbolName: "quit", accessibilityDescription: nil)
                        ?? NSImage(systemSymbolName: "power", accessibilityDescription: nil)
                        ?? NSImage()),
                triggers: ["nerw quit"],
                type: .instant(perform: { _ in
                    NSApp.terminate(nil)
                })
            )
        ]
    }
}
