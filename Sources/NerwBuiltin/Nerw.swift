import Cocoa
import NerwCore
import NerwSearchBackend

public class Nerw {
    public static let shared = Nerw()

    private init() {}

    private func makeTestAction() -> NerwAction {
        return NerwAction(
            id: "nerw.builtin.testform",
            title: "Test Form",
            subtitle: "Test multi-field input",
            icon: .system("pencil.and.outline"),
            triggers: ["test form"],
            type: .form(
                fields: [
                    NerwAction.Field(id: "name", title: "Name", placeholder: "John Doe"),
                    NerwAction.Field(id: "email", title: "Email", placeholder: "john@example.com"),
                    NerwAction.Field(id: "password", title: "Password", isSecure: true),
                ],
                submitLabel: "Send Data",
                perform: { _, values in
                    let alert = NSAlert()
                    alert.messageText = "Form Submitted"
                    alert.informativeText = values.map { "\($0.key): \($0.value)" }.joined(
                        separator: "\n")
                    alert.runModal()
                }
            )
        )
    }

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
            ),
            makeTestAction(),
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

        if "test form" == lowerTrigger {
            return makeTestAction()
        }
        return nil
    }
}
