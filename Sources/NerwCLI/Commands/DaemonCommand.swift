import Foundation

// MARK: - DaemonCommand

/// Top-level CLI command: `nerw daemon <subcommand>`
struct DaemonCommand: Command {
    let metadata: CommandMetadata

    private let subcommands: [Subcommand]

    init() {
        let listCmd = DaemonListSubcommand()
        let startCmd = DaemonStartSubcommand()
        let stopCmd = DaemonStopSubcommand()
        let approveCmd = DaemonApproveSubcommand()
        let revokeCmd = DaemonRevokeSubcommand()

        self.subcommands = [listCmd, startCmd, stopCmd, approveCmd, revokeCmd]

        self.metadata = CommandMetadata(
            name: "daemon",
            description: "Manage background daemon extensions",
            usage: "nerw daemon <subcommand>",
            subcommands: subcommands.map { $0.metadata }
        )
    }

    func execute(args: [String]) -> Never {
        guard let subcommandName = args.first else {
            HelpCommand().execute(args: ["daemon"])
        }
        let remainingArgs = Array(args.dropFirst())
        guard let subcommand = subcommands.first(where: { $0.metadata.name == subcommandName })
        else {
            print("Error: Unknown daemon subcommand '\(subcommandName)'")
            print("Run 'nerw help daemon' for available subcommands.")
            exit(1)
        }
        subcommand.execute(args: remainingArgs)
    }
}

// MARK: - nerw daemon list

struct DaemonListSubcommand: Subcommand {
    let metadata = CommandMetadata(
        name: "list",
        description: "List all daemon-capable extensions with their status",
        usage: "nerw daemon list"
    )

    func execute(args: [String]) -> Never {
        let registry = loadRegistry()
        let runDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".nerw/run")

        if registry.isEmpty {
            print("No daemon extensions registered.")
            exit(0)
        }

        // Header
        let idWidth = max(registry.map { $0.extensionId.count }.max() ?? 10, 30)
        let header = String(
            format: "%-\(idWidth)@  %-12@  %-6@  %@",
            "Extension", "Status", "PID", "Details")
        print(header)
        print(String(repeating: "-", count: header.count))

        for entry in registry.sorted(by: { $0.extensionId < $1.extensionId }) {
            let socketPath = runDir.appendingPathComponent("\(entry.extensionId).sock").path
            let isRunning = FileManager.default.fileExists(atPath: socketPath)
            let pid = isRunning ? pidForSocket(socketPath) : nil

            let status: String
            if !entry.approved {
                status = "unapproved"
            } else if !entry.enabled {
                status = "disabled"
            } else if isRunning {
                status = "running"
            } else {
                status = "stopped"
            }

            let details: String
            if let reason = entry.disabledReason {
                details = "(\(reason))"
            } else if entry.crashCount > 0 {
                details = "crashes: \(entry.crashCount)"
            } else {
                details = ""
            }

            let pidStr = pid.map { "\($0)" } ?? "-"
            print(
                String(
                    format: "%-\(idWidth)@  %-12@  %-6@  %@",
                    entry.extensionId, status, pidStr, details))
        }
        exit(0)
    }
}

// MARK: - nerw daemon start

struct DaemonStartSubcommand: Subcommand {
    let metadata = CommandMetadata(
        name: "start",
        description: "Start a daemon extension (must be approved)",
        usage: "nerw daemon start <extension-id>"
    )

    func execute(args: [String]) -> Never {
        guard let id = args.first else {
            print("Usage: nerw daemon start <extension-id>")
            exit(1)
        }
        // Signal Nerw to start the daemon via distributed notification
        DistributedNotificationCenter.default().postNotificationName(
            NSNotification.Name("com.nerw.daemon.start"),
            object: id, userInfo: nil, deliverImmediately: true)
        print("Requested daemon start for '\(id)'. Check 'nerw daemon list' to confirm.")
        exit(0)
    }
}

// MARK: - nerw daemon stop

struct DaemonStopSubcommand: Subcommand {
    let metadata = CommandMetadata(
        name: "stop",
        description: "Stop a running daemon extension",
        usage: "nerw daemon stop <extension-id>"
    )

    func execute(args: [String]) -> Never {
        guard let id = args.first else {
            print("Usage: nerw daemon stop <extension-id>")
            exit(1)
        }
        DistributedNotificationCenter.default().postNotificationName(
            NSNotification.Name("com.nerw.daemon.stop"),
            object: id, userInfo: nil, deliverImmediately: true)
        print("Requested daemon stop for '\(id)'. Check 'nerw daemon list' to confirm.")
        exit(0)
    }
}

// MARK: - nerw daemon approve

struct DaemonApproveSubcommand: Subcommand {
    let metadata = CommandMetadata(
        name: "approve",
        description: "Grant daemon permission for an extension",
        usage: "nerw daemon approve <extension-id>"
    )

    func execute(args: [String]) -> Never {
        guard let id = args.first else {
            print("Usage: nerw daemon approve <extension-id>")
            exit(1)
        }
        updateRegistry(extensionId: id) { entry in
            var e = entry ?? DaemonRegistryEntry(extensionId: id)
            e.approved = true
            e.enabled = true
            e.disabledReason = nil
            return e
        }
        DistributedNotificationCenter.default().postNotificationName(
            NSNotification.Name("com.nerw.daemon.start"),
            object: id, userInfo: nil, deliverImmediately: true)
        print("Approved daemon for '\(id)'. Nerw will start it shortly.")
        exit(0)
    }
}

// MARK: - nerw daemon revoke

struct DaemonRevokeSubcommand: Subcommand {
    let metadata = CommandMetadata(
        name: "revoke",
        description: "Revoke daemon permission and stop the daemon",
        usage: "nerw daemon revoke <extension-id>"
    )

    func execute(args: [String]) -> Never {
        guard let id = args.first else {
            print("Usage: nerw daemon revoke <extension-id>")
            exit(1)
        }
        updateRegistry(extensionId: id) { entry in
            var e = entry ?? DaemonRegistryEntry(extensionId: id)
            e.approved = false
            e.enabled = false
            e.disabledReason = "user"
            return e
        }
        DistributedNotificationCenter.default().postNotificationName(
            NSNotification.Name("com.nerw.daemon.stop"),
            object: id, userInfo: nil, deliverImmediately: true)
        print("Revoked daemon permission for '\(id)'.")
        exit(0)
    }
}

// MARK: - Registry Helpers (CLI reads/writes JSON directly)

/// Minimal codable mirror of DaemonEntry for CLI (avoids depending on NerwCore).
struct DaemonRegistryEntry: Codable {
    let extensionId: String
    var approved: Bool
    var enabled: Bool
    var crashCount: Int
    var lastCrashTime: Date?
    var disabledReason: String?

    init(extensionId: String) {
        self.extensionId = extensionId
        self.approved = false
        self.enabled = true
        self.crashCount = 0
    }
}

private func registryPath() -> URL {
    FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".nerw/daemon_registry.json")
}

private func loadRegistry() -> [DaemonRegistryEntry] {
    guard let data = try? Data(contentsOf: registryPath()),
        let decoded = try? JSONDecoder().decode([String: DaemonRegistryEntry].self, from: data)
    else { return [] }
    return Array(decoded.values)
}

private func updateRegistry(
    extensionId: String, transform: (DaemonRegistryEntry?) -> DaemonRegistryEntry
) {
    var entries: [String: DaemonRegistryEntry]
    if let data = try? Data(contentsOf: registryPath()),
        let decoded = try? JSONDecoder().decode([String: DaemonRegistryEntry].self, from: data)
    {
        entries = decoded
    } else {
        entries = [:]
    }
    entries[extensionId] = transform(entries[extensionId])
    if let data = try? JSONEncoder().encode(entries) {
        try? data.write(to: registryPath(), options: .atomic)
    }
}

private func pidForSocket(_ socketPath: String) -> Int32? {
    // Try to find a process that has this socket open using lsof
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
    process.arguments = ["-t", socketPath]
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = Pipe()
    try? process.run()
    process.waitUntilExit()
    let output =
        String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    return Int32(output.trimmingCharacters(in: .whitespacesAndNewlines))
}
