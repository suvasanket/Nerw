import Cocoa
import NerwSearchBackend

public class Nerw {
    public static let shared = Nerw()

    private init() {}

    public func check(query: String) -> BuiltinResult? {
        let lowerQuery = query.lowercased()

        if "reload config".starts(with: lowerQuery) {
            return BuiltinResult(
                title: "Reload Config",
                subtitle: "Reload configuration from ~/.config/nerw/config.json",
                iconName: "arrow.triangle.2.circlepath",
                supportsArguments: false
            ) { _ in
                ConfigManager.shared.reload()
            }
        }

        if "open config".starts(with: lowerQuery) {
            return BuiltinResult(
                title: "Open Config",
                subtitle: "Reveal config.json in Finder",
                iconName: "gear",
                supportsArguments: false
            ) { _ in
                let configPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config/nerw/config.json").path
                // Select the file
                NSWorkspace.shared.selectFile(configPath, inFileViewerRootedAtPath: "")
            }
        }

        return nil
    }
    public func findByTrigger(_ trigger: String) -> BuiltinResult? {
        let lowerTrigger = trigger.lowercased()
        if "reload config" == lowerTrigger {
            return BuiltinResult(
                title: "Reload Config",
                subtitle: "Reload configuration from ~/.config/nerw/config.json",
                iconName: "arrow.triangle.2.circlepath",
                supportsArguments: false
            ) { _ in ConfigManager.shared.reload() }
        }
        if "open config" == lowerTrigger {
             return BuiltinResult(
                 title: "Open Config",
                 subtitle: "Reveal config.json in Finder",
                 iconName: "gear",
                 supportsArguments: false
             ) { _ in
                 let configPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config/nerw/config.json").path
                 NSWorkspace.shared.selectFile(configPath, inFileViewerRootedAtPath: "")
             }
        }
        return nil
    }
}
