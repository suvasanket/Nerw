import Foundation

/// Test an extension by compiling and running it
struct SmokeTestSubcommand: Subcommand {
    let metadata = CommandMetadata(
        name: "smoke-test",
        description: "Test extension by compiling and running it",
        usage: "nerw extension smoke-test [query]",
        flags: [
            Flag("--install", "-i", description: "Install extension to test"),
            Flag("--clean", "-c", description: "Remove test extension"),
        ]
    )

    func execute(args: [String]) -> Never {
        if args.contains("--install") || args.contains("-i") {
            installForSmokeTest()
            CLIUtils.triggerReload()
            exit(0)
        }

        if args.contains("--clean") || args.contains("-c") {
            cleanSmokeTest()
            CLIUtils.triggerReload()
            exit(0)
        }

        smokeTest(query: args.first ?? "")
    }

    private func installForSmokeTest() {
        let fileManager = FileManager.default
        let currentDir = CLIUtils.getCurrentExtensionDir()

        guard let manifest = CLIUtils.readManifest(from: currentDir),
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
        } catch {
            print("Error: Failed to create symlink: \(error)")
        }
    }

    private func cleanSmokeTest() {
        let fileManager = FileManager.default
        let currentDir = CLIUtils.getCurrentExtensionDir()

        guard let manifest = CLIUtils.readManifest(from: currentDir),
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

    private func smokeTest(query: String) -> Never {
        let fileManager = FileManager.default
        let currentDir = CLIUtils.getCurrentExtensionDir()
        let mainSwift = currentDir.appendingPathComponent("main.swift")

        guard fileManager.fileExists(atPath: mainSwift.path) else {
            print("Error: No main.swift found in current directory")
            exit(1)
        }

        print("Compiling extension...")

        let buildDir = currentDir.appendingPathComponent(".build")
        try? fileManager.createDirectory(at: buildDir, withIntermediateDirectories: true)
        let binaryPath = buildDir.appendingPathComponent("main")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/swiftc")

        var args = [String]()
        if let paths = CLIUtils.findExtensionKitPaths() {
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
                exit(1)
            }
        } catch {
            print("Error: Failed to run swiftc: \(error)")
            exit(1)
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
                exit(0)
            } else {
                let errData = runErrorPipe.fileHandleForReading.readDataToEndOfFile()
                let errStr = String(data: errData, encoding: .utf8) ?? ""
                print("Extension returned no results. \(errStr)")
                exit(0)
            }
        } catch {
            print("Error: Failed to run extension: \(error)")
            exit(1)
        }
    }
}
