import Foundation

struct NerwCLI {
    static func main() {
        let arguments = Array(CommandLine.arguments.dropFirst())

        guard let command = arguments.first else {
            printUsage()
            return
        }

        switch command {
        case "help":
            printUsage()
        case "extension":
            handleExtension(Array(arguments.dropFirst()))
        default:
            print("Error: Unknown command '\(command)'")
            printUsage()
            exit(1)
        }
    }

    static func printUsage() {
        print(
            """
            Nerw CLI - macOS Popup Utility Controller

            Usage: nerw <command> [options]

            Commands:
              help                   Show this help message
              extension <subcommand> Manage Nerw extensions

            Extension Subcommands:
              init                   Initialize a new extension template
              smoke-test [query]     Test extension. Optional flags:
                                     --install, -i  Symlink to Nerw extensions dir
                                     --clean, -c    Remove symlink from Nerw extensions dir
            """)
    }

    static func handleExtension(_ args: [String]) {
        guard let sub = args.first else {
            print(
                """
                Extension management commands:
                  init                   Initialize a new extension template
                  smoke-test [query]     Test extension
                """)
            return
        }

        switch sub {
        case "init":
            initExtension()
        case "smoke-test":
            let subArgs = Array(args.dropFirst())
            handleSmokeTest(args: subArgs)
        default:
            print("Error: Unknown extension subcommand '\(sub)'")
        }
    }

    // ... (initExtension remains same)

    static func handleSmokeTest(args: [String]) {
        if args.contains("--install") || args.contains("-i") {
            installForSmokeTest()
            return
        }
        if args.contains("--clean") || args.contains("-c") {
            cleanSmokeTest()
            return
        }

        smokeTest(query: args.first ?? "")
    }

    static func installForSmokeTest() {
        let fileManager = FileManager.default
        let currentDir = URL(fileURLWithPath: fileManager.currentDirectoryPath)
        let manifestPath = currentDir.appendingPathComponent("manifest.json")

        guard fileManager.fileExists(atPath: manifestPath.path) else {
            print("Error: No manifest.json found in current directory")
            return
        }

        // Get extension ID from manifest
        guard let data = try? Data(contentsOf: manifestPath),
            let manifest = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let id = manifest["id"] as? String
        else {
            print("Error: Could not read extension ID from manifest.json")
            return
        }

        let extensionsDir = fileManager.homeDirectoryForCurrentUser.appendingPathComponent(
            ".nerw/extensions")
        try? fileManager.createDirectory(at: extensionsDir, withIntermediateDirectories: true)

        let symlinkURL = extensionsDir.appendingPathComponent(id)

        if fileManager.fileExists(atPath: symlinkURL.path) {
            try? fileManager.removeItem(at: symlinkURL)
        }

        do {
            try fileManager.createSymbolicLink(at: symlinkURL, withDestinationURL: currentDir)
            print("Successfully symlinked extension for smoke testing: \(symlinkURL.path)")
            print("Open Nerw Settings -> Extensions to see it with hazard background.")
        } catch {
            print("Error: Failed to create symlink: \(error)")
        }
    }

    static func cleanSmokeTest() {
        let fileManager = FileManager.default
        let currentDir = URL(fileURLWithPath: fileManager.currentDirectoryPath)
        let manifestPath = currentDir.appendingPathComponent("manifest.json")

        guard fileManager.fileExists(atPath: manifestPath.path) else {
            print("Error: No manifest.json found in current directory")
            return
        }

        guard let data = try? Data(contentsOf: manifestPath),
            let manifest = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let id = manifest["id"] as? String
        else {
            print("Error: Could not read extension ID from manifest.json")
            return
        }

        let extensionsDir = fileManager.homeDirectoryForCurrentUser.appendingPathComponent(
            ".nerw/extensions")
        let symlinkURL = extensionsDir.appendingPathComponent(id)

        if fileManager.fileExists(atPath: symlinkURL.path) {
            do {
                try fileManager.removeItem(at: symlinkURL)
                print("Successfully removed smoke test symlink: \(symlinkURL.path)")
            } catch {
                print("Error: Failed to remove symlink: \(error)")
            }
        } else {
            print("No smoke test symlink found for extension '\(id)'")
        }
    }

    static func initExtension() {
        print("Creating a new Nerw Extension...")

        print("Extension Name (e.g., My Search): ", terminator: "")
        guard let name = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty
        else {
            print("Error: Name is required")
            return
        }

        print("Extension ID (e.g., com.example.search): ", terminator: "")
        guard let id = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines), !id.isEmpty
        else {
            print("Error: ID is required")
            return
        }

        print("Trigger (e.g., g): ", terminator: "")
        guard let trigger = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines),
            !trigger.isEmpty
        else {
            print("Error: Trigger is required")
            return
        }

        let fileManager = FileManager.default
        let currentDir = URL(fileURLWithPath: fileManager.currentDirectoryPath)
        let extDir = currentDir.appendingPathComponent(
            name.lowercased().replacingOccurrences(of: " ", with: "-"))

        if fileManager.fileExists(atPath: extDir.path) {
            print("Error: Directory '\(extDir.lastPathComponent)' already exists")
            return
        }

        do {
            try fileManager.createDirectory(at: extDir, withIntermediateDirectories: true)

            // 1. manifest.json
            let manifest: [String: Any] = [
                "id": id,
                "name": name,
                "description": "A new Nerw extension",
                "trigger": trigger,
                "icon": "puzzlepiece.extension",
            ]
            let manifestData = try JSONSerialization.data(
                withJSONObject: manifest, options: .prettyPrinted)
            try manifestData.write(to: extDir.appendingPathComponent("manifest.json"))

            // 2. main.swift
            let template =
                """
                import Foundation
                import NerwExtensionKit

                struct \(name.replacingOccurrences(of: " ", with: "")): NerwExtension {
                    func query(input: QueryInput) -> [NerwResult] {
                        let query = input.query
                        
                        return [
                            NerwResult("Example: \\(query)")
                                .subtitle("Custom result for trigger: \\(input.trigger ?? "none")")
                                .icon(.system("star"))
                                .instant(action: "https://google.com/search?q=\\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")
                        ]
                    }

                    func perform(action: ActionInput) {
                        // Handle function-based actions here
                    }
                }

                Nerw.run(\(name.replacingOccurrences(of: " ", with: ""))())
                """
            try template.write(
                to: extDir.appendingPathComponent("main.swift"), atomically: true, encoding: .utf8)

            print("Successfully created extension at: \(extDir.path)")
            print(
                "To test it, run: cd \(extDir.lastPathComponent) && nerw extension smoke-test 'hello'"
            )

        } catch {
            print("Error: Failed to create extension: \(error)")
        }
    }

    // MARK: - Smoke Test

    static func smokeTest(query: String) {
        let fileManager = FileManager.default
        let currentDir = URL(fileURLWithPath: fileManager.currentDirectoryPath)
        let mainSwift = currentDir.appendingPathComponent("main.swift")

        guard fileManager.fileExists(atPath: mainSwift.path) else {
            print("Error: No main.swift found in current directory")
            return
        }

        print("Compiling extension...")

        let buildDir = currentDir.appendingPathComponent(".build")
        try? fileManager.createDirectory(at: buildDir, withIntermediateDirectories: true)
        let binaryPath = buildDir.appendingPathComponent("main")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/swiftc")

        var args = [String]()
        // Find NerwExtensionKit. Use a simple search for development
        if let paths = findExtensionKitPaths() {
            args += ["-I", paths.modules, "-L", paths.lib, "-lNerwExtensionKit"]
        }

        args += [mainSwift.path, "-o", binaryPath.path]
        process.arguments = args

        let errorPipe = Pipe()
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus != 0 {
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorStr = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                print("Error: Compilation failed:\n\(errorStr)")
                return
            }
        } catch {
            print("Error: Failed to run swiftc: \(error)")
            return
        }

        print("Running extension with query: '\(query)'")

        let runProcess = Process()
        runProcess.executableURL = binaryPath

        let inputPipe = Pipe()
        let outputPipe = Pipe()
        let runErrorPipe = Pipe()
        runProcess.standardInput = inputPipe
        runProcess.standardOutput = outputPipe
        runProcess.standardError = runErrorPipe

        do {
            try runProcess.run()

            let input: [String: Any] = [
                "type": "query",
                "query": query,
                "trigger": "test",
            ]
            let inputData = try JSONSerialization.data(withJSONObject: input)
            inputPipe.fileHandleForWriting.write(inputData)
            inputPipe.fileHandleForWriting.write("\n".data(using: .utf8)!)
            inputPipe.fileHandleForWriting.closeFile()

            runProcess.waitUntilExit()

            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            if let outputStr = String(data: outputData, encoding: .utf8), !outputStr.isEmpty {
                print("\n--- RESULTS ---")
                print(outputStr)
                print("---------------")
            } else {
                let errData = runErrorPipe.fileHandleForReading.readDataToEndOfFile()
                let errStr = String(data: errData, encoding: .utf8) ?? ""
                print("Extension returned no results. \(errStr)")
            }

        } catch {
            print("Error: Failed to run extension: \(error)")
        }
    }

    private static func findExtensionKitPaths() -> (modules: String, lib: String)? {
        let fileManager = FileManager.default
        let currentDir = URL(fileURLWithPath: fileManager.currentDirectoryPath)

        // 1. Check if we are running from within the app bundle
        if let bundlePath = Bundle.main.resourcePath {
            let modulesPath = bundlePath + "/Modules"
            let libPath = bundlePath + "/lib"
            if fileManager.fileExists(atPath: modulesPath + "/NerwExtensionKit.swiftmodule") {
                return (modulesPath, libPath)
            }
        }

        // 2. Try to find project root by looking for Package.swift (Development)
        var path = currentDir
        for _ in 0..<10 {
            let packageSwift = path.appendingPathComponent("Package.swift")
            if fileManager.fileExists(atPath: packageSwift.path) {
                // Found project root
                let arch = "arm64-apple-macosx"
                let modulesPath = path.appendingPathComponent(".build/\(arch)/debug/Modules").path
                let libPath = path.appendingPathComponent(".build/\(arch)/debug").path
                let swiftmodule =
                    modulesPath + "/NerwExtensionKit.swiftmodule"
                if fileManager.fileExists(atPath: swiftmodule) {
                    return (modulesPath, libPath)
                }
            }
            path = path.deletingLastPathComponent()
        }

        // 3. Check common installation path
        let installPath = "/Applications/Nerw.app/Contents/Resources"
        let modulesPath = installPath + "/Modules"
        let libPath = installPath + "/lib"
        if fileManager.fileExists(atPath: modulesPath + "/NerwExtensionKit.swiftmodule") {
            return (modulesPath, libPath)
        }

        return nil
    }
}

NerwCLI.main()
