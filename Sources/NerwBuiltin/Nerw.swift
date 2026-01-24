import Cocoa
import NerwCore
import NerwSearchBackend

public class Nerw {
    public static let shared = Nerw()

    private init() {}

    public func check(query: String) -> NerwAction? {
        let lowerQuery = query.lowercased()

        if "reload config".starts(with: lowerQuery) {
            return NerwAction(
                id: "nerw.builtin.reload",
                title: "Reload Config",
                subtitle: "Reload configuration from ~/.config/nerw/config.json",
                icon: .system("arrow.triangle.2.circlepath"),
                triggers: ["reload config"],
                arguments: nil,
                handler: { _ in
                    ConfigManager.shared.reload()
                }
            )
        }

        if "open config".starts(with: lowerQuery) {
            return NerwAction(
                id: "nerw.builtin.openconfig",
                title: "Open Config",
                subtitle: "Reveal config.json in Finder",
                icon: .system("gear"),
                triggers: ["open config"],
                arguments: nil,
                handler: { _ in
                    let configPath = FileManager.default.homeDirectoryForCurrentUser
                        .appendingPathComponent(
                            ".config/nerw/config.json"
                        ).path
                    // Select the file
                    NSWorkspace.shared.selectFile(configPath, inFileViewerRootedAtPath: "")
                }
            )
        }

        if "nerw quit".starts(with: lowerQuery) {
            return NerwAction(
                id: "nerw.builtin.quit",
                title: "Quit Nerw",
                subtitle: "Terminate the application",
                icon: .system("power"),
                triggers: ["nerw quit"],
                arguments: nil,
                handler: { _ in
                    NSApp.terminate(nil)
                }
            )
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
                arguments: nil,
                handler: { _ in NSApp.terminate(nil) }
            )
        }
        if "reload config" == lowerTrigger {
            return NerwAction(
                id: "nerw.builtin.reload",
                title: "Reload Config",
                subtitle: "Reload configuration from ~/.config/nerw/config.json",
                icon: .system("arrow.triangle.2.circlepath"),
                triggers: ["reload config"],
                arguments: nil,
                handler: { _ in ConfigManager.shared.reload() }
            )
        }
        if "open config" == lowerTrigger {
            return NerwAction(
                id: "nerw.builtin.openconfig",
                title: "Open Config",
                subtitle: "Reveal config.json in Finder",
                icon: .system("gear"),
                triggers: ["open config"],
                arguments: nil,
                handler: { _ in
                    let configPath = FileManager.default.homeDirectoryForCurrentUser
                        .appendingPathComponent(
                            ".config/nerw/config.json"
                        ).path
                    NSWorkspace.shared.selectFile(configPath, inFileViewerRootedAtPath: "")
                }
            )
        }
        return nil
    }
}
