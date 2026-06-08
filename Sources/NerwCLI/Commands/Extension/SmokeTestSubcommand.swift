import Foundation

/// Test an extension by compiling and running it
struct SmokeTestSubcommand: Subcommand {
    let metadata = CommandMetadata(
        name: "smoke-test",
        description: "Test extension by compiling and running it",
        usage: "nerw extension smoke-test [--daemon] [query]",
        flags: [
            Flag("--install", "-i", description: "Install extension to test"),
            Flag("--clean", "-c", description: "Remove test extension"),
            Flag("--daemon", "-d", description: "Run extension in daemon mode interactively"),
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

        if args.contains("--daemon") || args.contains("-d") {
            daemonSmokeTest()
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

            var triggers: [String] = ["first"]
            if let manifest = CLIUtils.readManifest(from: currentDir) {
                if let actions = manifest["actions"] as? [[String: Any]] {
                    triggers = actions.flatMap { ($0["triggers"] as? [String]) ?? [] }
                } else if let trigs = manifest["triggers"] as? [String] {
                    triggers = trigs
                } else if let trig = manifest["trigger"] as? String {
                    triggers = [trig]
                }
            }

            let input: [String: Any] = [
                "type": "query",
                "query": query,
                "triggers": triggers,
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

    // MARK: - Daemon Smoke Test

    private func daemonSmokeTest() -> Never {
        let fileManager = FileManager.default
        let currentDir = CLIUtils.getCurrentExtensionDir()
        let mainSwift = currentDir.appendingPathComponent("main.swift")

        guard fileManager.fileExists(atPath: mainSwift.path) else {
            print("Error: No main.swift found in current directory")
            exit(1)
        }

        print("Compiling extension for daemon smoke test...")

        let buildDir = currentDir.appendingPathComponent(".build")
        try? fileManager.createDirectory(at: buildDir, withIntermediateDirectories: true)
        let binaryPath = buildDir.appendingPathComponent("main")

        // Compile
        let compileProcess = Process()
        compileProcess.executableURL = URL(fileURLWithPath: "/usr/bin/swiftc")
        var compileArgs = [String]()
        if let paths = CLIUtils.findExtensionKitPaths() {
            compileArgs += ["-I", paths.modules, "-L", paths.lib, "-lNerwExtensionKit"]
        }
        compileArgs += [mainSwift.path, "-o", binaryPath.path]
        compileProcess.arguments = compileArgs
        let compilePipe = Pipe()
        compileProcess.standardError = compilePipe
        try? compileProcess.run()
        compileProcess.waitUntilExit()
        if compileProcess.terminationStatus != 0 {
            let errStr =
                String(
                    data: compilePipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
                ?? ""
            print("Compilation failed:\n\(errStr)")
            exit(1)
        }
        print("Compilation succeeded.")

        // Read extension ID for socket naming
        let extId = (CLIUtils.readManifest(from: currentDir)?["id"] as? String) ?? "smoke-test"
        let socketPath = "/tmp/nerw-smoke-\(extId).sock"
        let tmpDataDir = "/tmp/nerw-smoke-data-\(extId)"
        try? fileManager.createDirectory(
            atPath: tmpDataDir, withIntermediateDirectories: true, attributes: nil)

        // Launch daemon
        let daemon = Process()
        daemon.executableURL = binaryPath
        daemon.arguments = ["--daemon", "--socket", socketPath, "--data-dir", tmpDataDir]
        let daemonErr = Pipe()
        daemon.standardError = daemonErr
        daemonErr.fileHandleForReading.readabilityHandler = { fh in
            let d = fh.availableData
            if !d.isEmpty, let s = String(data: d, encoding: .utf8) {
                print("[daemon] \(s.trimmingCharacters(in: .newlines))")
            }
        }

        print("Launching daemon (socket: \(socketPath))...")
        try? daemon.run()

        // Wait for socket to appear
        var waited = 0.0
        while !fileManager.fileExists(atPath: socketPath) && waited < 5.0 {
            Thread.sleep(forTimeInterval: 0.1)
            waited += 0.1
        }
        guard fileManager.fileExists(atPath: socketPath) else {
            print("Error: Daemon socket did not appear within 5 seconds.")
            daemon.terminate()
            exit(1)
        }
        print("Daemon running (PID \(daemon.processIdentifier)).")
        print("")
        print("Commands:  q <query>   a <function>   h (health)   s (stop)   Ctrl-C to abort")
        print("")

        // Connect to socket
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let pathBytes = socketPath.utf8CString
        withUnsafeMutableBytes(of: &addr.sun_path) { buf in
            pathBytes.withUnsafeBytes { src in
                let count = min(src.count, buf.count - 1)
                buf.copyMemory(from: UnsafeRawBufferPointer(rebasing: src.prefix(count)))
            }
        }
        _ = withUnsafePointer(to: addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }

        func sendMsg(id: String? = nil, type msgType: String, payload: Data? = nil) {
            var obj: [String: Any] = ["type": msgType]
            if let i = id { obj["id"] = i }
            if let p = payload { obj["payload"] = p.base64EncodedString() }
            if let data = try? JSONSerialization.data(withJSONObject: obj),
                let line = String(data: data, encoding: .utf8)
            {
                let bytes = (line + "\n").data(using: .utf8)!
                _ = bytes.withUnsafeBytes { write(fd, $0.baseAddress!, $0.count) }
            }
        }

        // Background receive loop
        var receiveBuffer = Data()
        DispatchQueue.global(qos: .userInteractive).async {
            while true {
                var chunk = [UInt8](repeating: 0, count: 4096)
                let n = read(fd, &chunk, chunk.count)
                if n <= 0 { break }
                receiveBuffer.append(contentsOf: chunk.prefix(n))
                while let nlIdx = receiveBuffer.firstIndex(of: UInt8(ascii: "\n")) {
                    let lineData = receiveBuffer[receiveBuffer.startIndex..<nlIdx]
                    receiveBuffer.removeSubrange(receiveBuffer.startIndex...nlIdx)
                    if let s = String(data: lineData, encoding: .utf8) {
                        print("← \(s)")
                    }
                }
            }
        }

        // Interactive REPL
        while let line = readLine(strippingNewline: true) {
            let parts = line.split(separator: " ", maxSplits: 1).map(String.init)
            let cmd = parts.first ?? ""
            let arg = parts.count > 1 ? parts[1] : ""

            switch cmd {
            case "q":
                let p: [String: Any] = ["query": arg, "triggers": ["smoke"], "settings": [:]]
                if let data = try? JSONSerialization.data(withJSONObject: p) {
                    sendMsg(id: UUID().uuidString, type: "query", payload: data)
                }
            case "a":
                let p: [String: Any] = ["function": arg, "args": [], "settings": [:]]
                if let data = try? JSONSerialization.data(withJSONObject: p) {
                    sendMsg(id: UUID().uuidString, type: "action", payload: data)
                }
            case "h":
                sendMsg(id: UUID().uuidString, type: "health")
            case "s":
                sendMsg(type: "stop")
                Thread.sleep(forTimeInterval: 0.5)
                close(fd)
                daemon.waitUntilExit()
                print("Daemon stopped.")
                exit(0)
            default:
                print("Unknown command. Use: q <query>  a <function>  h  s")
            }
        }

        // EOF / Ctrl-C
        sendMsg(type: "stop")
        daemon.waitUntilExit()
        exit(0)
    }
}
