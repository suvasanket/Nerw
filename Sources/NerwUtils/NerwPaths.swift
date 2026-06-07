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

    // MARK: - Helper

    /// Ensures that an essential directory exists, creating it if necessary.
    public static func ensureDirectoryExists(at url: URL) {
        if !fileManager.fileExists(atPath: url.path) {
            try? fileManager.createDirectory(
                at: url, withIntermediateDirectories: true, attributes: nil)
        }
    }
}
