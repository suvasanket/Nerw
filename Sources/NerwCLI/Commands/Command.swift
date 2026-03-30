import Foundation

// MARK: - Help Registration System

/// A flag or option that can be passed to a command
struct Flag {
    let names: [String]
    let description: String

    init(_ names: String..., description: String) {
        self.names = names
        self.description = description
    }
}

/// Metadata for a command or subcommand
struct CommandMetadata {
    let name: String
    let description: String
    let usage: String
    let flags: [Flag]
    let subcommands: [CommandMetadata]?

    init(
        name: String, description: String, usage: String, flags: [Flag] = [],
        subcommands: [CommandMetadata]? = nil
    ) {
        self.name = name
        self.description = description
        self.usage = usage
        self.flags = flags
        self.subcommands = subcommands
    }
}

/// Registry for all commands and their help information
final class CommandRegistry {
    static let shared = CommandRegistry()

    private var commands: [String: CommandMetadata] = [:]

    private init() {}

    func register(_ metadata: CommandMetadata) {
        commands[metadata.name] = metadata
    }

    func get(_ name: String) -> CommandMetadata? {
        commands[name]
    }

    var allCommands: [CommandMetadata] {
        Array(commands.values).sorted { $0.name < $1.name }
    }
}

// MARK: - Command Protocol

/// Protocol for all CLI commands
protocol Command {
    var metadata: CommandMetadata { get }
    func execute(args: [String]) -> Never
}

/// Protocol for subcommands
protocol Subcommand {
    var metadata: CommandMetadata { get }
    func execute(args: [String]) -> Never
}

// MARK: - Shared Utilities

struct CLIUtils {
    static func triggerReload() {
        DistributedNotificationCenter.default().postNotificationName(
            NSNotification.Name("com.nerw.reloadExtensions"),
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )
    }

    static func findExtensionKitPaths() -> (modules: String, lib: String)? {
        let fileManager = FileManager.default
        let currentDir = URL(fileURLWithPath: fileManager.currentDirectoryPath)

        if let bundlePath = Bundle.main.resourcePath {
            let modulesPath = bundlePath + "/Modules"
            let libPath = bundlePath + "/lib"
            if fileManager.fileExists(atPath: modulesPath + "/NerwExtensionKit.swiftmodule") {
                return (modulesPath, libPath)
            }
        }

        var path = currentDir
        for _ in 0..<10 {
            let packageSwift = path.appendingPathComponent("Package.swift")
            if fileManager.fileExists(atPath: packageSwift.path) {
                let arch = "arm64-apple-macosx"
                let modulesPath = path.appendingPathComponent(".build/\(arch)/debug/Modules").path
                let libPath = path.appendingPathComponent(".build/\(arch)/debug").path
                let swiftmodule = modulesPath + "/NerwExtensionKit.swiftmodule"
                if fileManager.fileExists(atPath: swiftmodule) {
                    return (modulesPath, libPath)
                }
            }
            path = path.deletingLastPathComponent()
        }

        let installPath = "/Applications/Nerw.app/Contents/Resources"
        let modulesPath = installPath + "/Modules"
        let libPath = installPath + "/lib"
        if fileManager.fileExists(atPath: modulesPath + "/NerwExtensionKit.swiftmodule") {
            return (modulesPath, libPath)
        }

        return nil
    }

    static func getCurrentExtensionDir() -> URL {
        URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    }

    static func readManifest(from dir: URL) -> [String: Any]? {
        let manifestPath = dir.appendingPathComponent("manifest.json")
        guard let data = try? Data(contentsOf: manifestPath),
            let manifest = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return manifest
    }
}
