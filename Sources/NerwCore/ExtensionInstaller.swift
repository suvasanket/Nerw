import Foundation

public enum ExtensionInstallError: Error {
    case invalidPackage
    case manifestMissing
    case unzipFailed
    case installationFailed
}

public class ExtensionInstaller {
    public static let shared = ExtensionInstaller()

    private let fileManager = FileManager.default

    private var extensionsDir: URL {
        fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".nerw/extensions")
    }

    private init() {
        try? fileManager.createDirectory(at: extensionsDir, withIntermediateDirectories: true)
    }

    /// Unzips manifest.json from the package to a temp location and returns it
    public func inspectPackage(at url: URL) -> ExtensionManifest? {
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? fileManager.removeItem(at: tempDir)
        }

        // Unzip only manifest.json
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-j", url.path, "manifest.json", "-d", tempDir.path]

        try? process.run()
        process.waitUntilExit()

        let manifestPath = tempDir.appendingPathComponent("manifest.json")
        guard let data = try? Data(contentsOf: manifestPath),
            let manifest = try? JSONDecoder().decode(ExtensionManifest.self, from: data)
        else {
            return nil
        }

        return manifest
    }

    public func installPackage(at url: URL) throws {
        // 1. Inspect first to get ID
        guard let manifest = inspectPackage(at: url) else {
            throw ExtensionInstallError.invalidPackage
        }

        let installPath = extensionsDir.appendingPathComponent(manifest.id)

        // 2. Remove existing if any
        if fileManager.fileExists(atPath: installPath.path) {
            try? fileManager.removeItem(at: installPath)
        }
        try? fileManager.createDirectory(at: installPath, withIntermediateDirectories: true)

        // 3. Unzip all
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-o", url.path, "-d", installPath.path]  // -o overwrite

        try? process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw ExtensionInstallError.unzipFailed
        }

        // 4. Reload Engine
        ExtensionEngine.shared.reload()
        NotificationCenter.default.post(
            name: Notification.Name("NerwExtensionsDidUpdate"), object: nil)
    }

    public func uninstall(id: String) throws {
        let installPath = extensionsDir.appendingPathComponent(id)
        if fileManager.fileExists(atPath: installPath.path) {
            try fileManager.removeItem(at: installPath)
        }
        ExtensionEngine.shared.reload()
        NotificationCenter.default.post(
            name: Notification.Name("NerwExtensionsDidUpdate"), object: nil)
    }
}
