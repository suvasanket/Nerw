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

    public func check(query: String) -> NerwAction? {
        let lowerQuery = query.lowercased()

        if "reload config".starts(with: lowerQuery) {
            return NerwAction(
                id: "nerw.builtin.reload",
                title: "Reload Config",
                subtitle: "Reload configuration from ~/.config/nerw/config.json",
                icon: .system("arrow.triangle.2.circlepath"),
                triggers: ["reload config"],
                type: .instant(perform: { _ in
                    ConfigManager.shared.reload()
                })
            )
        }

        if "open config".starts(with: lowerQuery) {
            return NerwAction(
                id: "nerw.builtin.openconfig",
                title: "Open Config",
                subtitle: "Reveal config.json in Finder",
                icon: .system("gear"),
                triggers: ["open config"],
                type: .instant(perform: { _ in
                    let configPath = FileManager.default.homeDirectoryForCurrentUser
                        .appendingPathComponent(
                            ".config/nerw/config.json"
                        ).path
                    // Select the file
                    NSWorkspace.shared.selectFile(configPath, inFileViewerRootedAtPath: "")
                })
            )
        }

        if "nerw quit".starts(with: lowerQuery) {
            return NerwAction(
                id: "nerw.builtin.quit",
                title: "Quit Nerw",
                subtitle: "Terminate the application",
                icon: .system("power"),
                triggers: ["nerw quit"],
                type: .instant(perform: { _ in
                    NSApp.terminate(nil)
                })
            )
        }

        if "test form".starts(with: lowerQuery) {
            return makeTestAction()
        }

        return nil
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
        if "reload config" == lowerTrigger {
            return NerwAction(
                id: "nerw.builtin.reload",
                title: "Reload Config",
                subtitle: "Reload configuration from ~/.config/nerw/config.json",
                icon: .system("arrow.triangle.2.circlepath"),
                triggers: ["reload config"],
                type: .instant(perform: { _ in ConfigManager.shared.reload() })
            )
        }
        if "open config" == lowerTrigger {
            return NerwAction(
                id: "nerw.builtin.openconfig",
                title: "Open Config",
                subtitle: "Reveal config.json in Finder",
                icon: .system("gear"),
                triggers: ["open config"],
                type: .instant(perform: { _ in
                    let configPath = FileManager.default.homeDirectoryForCurrentUser
                        .appendingPathComponent(
                            ".config/nerw/config.json"
                        ).path
                    NSWorkspace.shared.selectFile(configPath, inFileViewerRootedAtPath: "")
                })
            )
        }
        if "test form" == lowerTrigger {
            return makeTestAction()
        }
        return nil
    }
}
