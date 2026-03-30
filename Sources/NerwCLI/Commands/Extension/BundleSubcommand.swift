import Foundation

/// Bundle an extension into a .nerw package
struct BundleSubcommand: Subcommand {
    let metadata = CommandMetadata(
        name: "bundle",
        description: "Bundle extension into a .nerw package",
        usage: "nerw extension bundle [path]",
        flags: [
            Flag("<path>", description: "Directory where extension files located")
        ]
    )

    func execute(args: [String]) -> Never {
        let targetPath = args.first ?? "."
        let sourceDir = URL(fileURLWithPath: targetPath).absoluteURL

        // Validate path exists
        if !FileManager.default.fileExists(atPath: sourceDir.path) {
            print("Error: Path does not exist: \(targetPath)")
            exit(1)
        }

        // Validate it's a directory
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: sourceDir.path, isDirectory: &isDirectory),
            isDirectory.boolValue
        else {
            print("Error: Path is not a directory: \(targetPath)")
            exit(1)
        }

        // Validate required files exist
        let manifestPath = sourceDir.appendingPathComponent("manifest.json")
        let mainSwiftPath = sourceDir.appendingPathComponent("main.swift")

        guard FileManager.default.fileExists(atPath: manifestPath.path) else {
            print("Error: manifest.json not found in \(targetPath)")
            print("Expected structure: <extension_dir>/manifest.json, <extension_dir>/main.swift")
            exit(1)
        }

        guard FileManager.default.fileExists(atPath: mainSwiftPath.path) else {
            print("Error: main.swift not found in \(targetPath)")
            print("Expected structure: <extension_dir>/manifest.json, <extension_dir>/main.swift")
            exit(1)
        }

        // Validate and parse manifest
        guard let manifestData = try? Data(contentsOf: manifestPath),
            let manifest = try? JSONSerialization.jsonObject(with: manifestData) as? [String: Any]
        else {
            print("Error: manifest.json is invalid or cannot be parsed")
            exit(1)
        }

        guard let id = manifest["id"] as? String else {
            print("Error: manifest.json is missing required 'id' field")
            exit(1)
        }

        guard let name = manifest["name"] as? String else {
            print("Error: manifest.json is missing required 'name' field")
            exit(1)
        }

        let packageName = "\(id).nerw"
        let outputURL = sourceDir.appendingPathComponent(packageName)

        // Remove existing package if present
        if FileManager.default.fileExists(atPath: outputURL.path) {
            print("Removing existing package: \(packageName)")
            try? FileManager.default.removeItem(at: outputURL)
        }

        // Create temp directory for bundling
        let tempDir = sourceDir.appendingPathComponent(".nerw_bundle_temp")
        try? FileManager.default.removeItem(at: tempDir)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        // Copy extension files to temp directory
        do {
            try FileManager.default.copyItem(
                at: manifestPath, to: tempDir.appendingPathComponent("manifest.json"))
            try FileManager.default.copyItem(
                at: mainSwiftPath, to: tempDir.appendingPathComponent("main.swift"))
        } catch {
            print("Error: Failed to copy extension files: \(error)")
            try? FileManager.default.removeItem(at: tempDir)
            exit(1)
        }

        // Create zip archive
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.arguments = ["-r", outputURL.path, "."]
        process.currentDirectoryURL = tempDir

        do {
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus != 0 {
                print("Error: Failed to create zip archive")
                try? FileManager.default.removeItem(at: tempDir)
                exit(1)
            }
        } catch {
            print("Error: Failed to run zip: \(error)")
            try? FileManager.default.removeItem(at: tempDir)
            exit(1)
        }

        // Cleanup temp directory
        try? FileManager.default.removeItem(at: tempDir)

        print("Successfully created extension package: \(name).nerw")
        print("Package location: \(outputURL.path)")
        exit(0)
    }
}
