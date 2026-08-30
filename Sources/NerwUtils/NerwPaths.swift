import Foundation

public struct NerwPaths {
    private static let fileManager = FileManager.default

    // MARK: - User Config & Extensions (~/.nerw)

    /// Base directory for user editable configs and extensions (`~/.nerw`)
    public static var configDirectory: URL {
        fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".nerw")
    }

    /// Directory for extensions (`~/.nerw/extensions`)
    public static var extensionsDirectory: URL {
        configDirectory.appendingPathComponent("extensions")
    }

    // MARK: - Application Data (~/Library/Application Support/Nerw)

    /// Base directory for application data (`~/Library/Application Support/Nerw`)
    public static var appSupportDirectory: URL {
        if let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first
        {
            return appSupport.appendingPathComponent("Nerw")
        }
        // Fallback if Application Support is somehow not found
        return fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".nerw/data")
    }

    /// Base directory for persistent app data like frecency, cache, clipboard (`~/Library/Application Support/Nerw/Data`)
    public static var dataDirectory: URL {
        appSupportDirectory.appendingPathComponent("Data")
    }

    /// Directory for downloaded icons (`~/Library/Application Support/Nerw/Icons`)
    public static var iconsDirectory: URL {
        appSupportDirectory.appendingPathComponent("Icons")
    }

    /// Directory for application logs (`~/.nerw/log`)
    public static var logsDirectory: URL {
        configDirectory.appendingPathComponent("log")
    }

    /// Directory for clipboard history images (`~/Library/Application Support/Nerw/Data/ClipboardImages`)
    public static var clipboardImagesDirectory: URL {
        dataDirectory.appendingPathComponent("ClipboardImages")
    }

    /// Directory for AI memory images (`~/Library/Application Support/Nerw/Data/MemoryImages`)
    public static var aiMemoriesImagesDirectory: URL {
        dataDirectory.appendingPathComponent("MemoryImages")
    }

    // MARK: - Daemon Paths (~/.nerw/run, ~/.nerw/extensions/<id>/data)

    /// Directory for daemon Unix domain socket files (`~/.nerw/run`).
    /// Cleaned on app launch to remove stale sockets from prior sessions.
    public static var daemonRunDirectory: URL {
        configDirectory.appendingPathComponent("run")
    }

    /// Path for the AI backend socket (`~/.nerw/run/ai.sock`).
    public static var aiSocketPath: URL {
        daemonRunDirectory.appendingPathComponent("ai.sock")
    }

    /// Path for the AI memory file (`~/.nerw/memory.json`).
    public static var aiMemoryFile: URL {
        configDirectory.appendingPathComponent("memory.json")
    }

    /// Path for the AI conversations history file (`~/.nerw/conversations.json`).
    public static var aiConversationsFile: URL {
        configDirectory.appendingPathComponent("conversations.json")
    }

    /// Per-extension persistent data directory (`~/.nerw/extensions/<id>/data`).
    /// Survives restarts; cleaned on extension uninstall.
    public static func daemonDataDir(for extensionId: String) -> URL {
        extensionsDirectory.appendingPathComponent(extensionId).appendingPathComponent("data")
    }

    // MARK: - Helper

    /// Ensures that an essential directory exists, creating it if necessary.
    public static func ensureDirectoryExists(at url: URL) {
        if !fileManager.fileExists(atPath: url.path) {
            try? fileManager.createDirectory(
                at: url, withIntermediateDirectories: true, attributes: nil)
        }
    }
}
