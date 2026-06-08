import Foundation

/// The Nerw API — host commands and extension bootstrap.
/// Extension developers use `Nerw.open()`, `Nerw.copy()`, `Nerw.log()`
/// inside their `perform(action:)` method, then call `Nerw.run()` to start.
public enum Nerw {

    private static func emitCommand(_ cmd: [String: Any]) {
        // In daemon mode, route commands through the socket as ext_command messages
        if let socket = daemonSocket {
            let response: [String: Any] = ["commands": [cmd]]
            if let data = try? JSONSerialization.data(withJSONObject: response) {
                socket.sendMessage(DaemonSocketMessage(type: "ext_command", payload: data))
            }
            return
        }
        // One-shot mode: write each command to stdout immediately
        let response: [String: Any] = ["commands": [cmd]]
        if let data = try? JSONSerialization.data(withJSONObject: response),
            let output = String(data: data, encoding: .utf8)
        {
            print(output)
            fflush(stdout)
        }
    }

    // MARK: - Host Commands

    /// Open a URL in the default browser or a file path in Finder.
    public static func open(_ url: String) {
        emitCommand(["type": "open", "value": url])
    }

    /// Copy text to the system clipboard.
    public static func copy(_ text: String) {
        emitCommand(["type": "copy", "value": text])
    }

    /// Log a debug message (written to stderr, visible in Nerw console).
    public static func log(_ message: String) {
        FileHandle.standardError.write(
            "[Extension] \(message)\n".data(using: .utf8) ?? Data())
    }

    /// Trigger a system notification panel explicitly from the extension.
    /// - Parameters:
    ///   - content: The message content to notify the user.
    ///   - level: The severity tier (e.g. "info", "warn", "error"). Default is "info".
    ///   - progressive: If true, shows a continuous spinner and prevents auto-dismiss.
    ///   - id: An optional known UUID string to identify this notification, facilitating dismissal.
    public static func notify(
        _ content: String, level: String = "info", progressive: Bool = false, id: String? = nil
    ) {
        var cmd: [String: Any] = [
            "type": "notify",
            "value": content,
            "level": level,
            "progressive": progressive,
        ]
        if let id = id { cmd["id"] = id }
        emitCommand(cmd)
    }

    /// Dismisses a previously sent progressive notification using its assigned string ID.
    public static func dismissNotify(id: String) {
        emitCommand([
            "type": "dismiss_notify",
            "id": id,
        ])
    }

    /// Hide the host application panel immediately.
    public static func hideHost() {
        emitCommand(["type": "hide_host"])
    }

    // MARK: - Bootstrap

    /// Run the extension. Call this at the end of your `main.swift`.
    ///
    /// ```swift
    /// import NerwExtensionKit
    ///
    /// struct MyExtension: NerwExtension {
    ///     func query(input: QueryInput) -> [NerwResult] { ... }
    ///     func perform(action: ActionInput) { ... }
    /// }
    ///
    /// Nerw.run(MyExtension())
    /// ```
    public static func run(_ ext: NerwExtension) {
        run(extension: ext, daemon: nil)
    }

    /// Run the extension, optionally with a daemon.
    ///
    /// When the binary is launched with `--daemon`, it enters daemon mode and
    /// calls the daemon's lifecycle hooks. Otherwise it handles one query/action
    /// via stdin/stdout (the existing one-shot model).
    ///
    /// ```swift
    /// Nerw.run(extension: MyExtension(), daemon: MyDaemon())
    /// ```
    public static func run(extension ext: NerwExtension, daemon: NerwDaemon?) {
        // Safety: exit if parent process dies (prevents orphans)
        startParentWatchdog()

        // Check for --daemon flag
        if CommandLine.arguments.contains("--daemon"), let daemon = daemon {
            runDaemonMode(daemon: daemon)
            return
        }

        // ---- One-shot mode ----
        guard let inputLine = readLine(),
            let inputData = inputLine.data(using: .utf8),
            let input = try? JSONSerialization.jsonObject(with: inputData) as? [String: Any]
        else {
            Nerw.log("Failed to read input")
            exit(1)
        }

        let type = input["type"] as? String ?? ""
        let settings = input["settings"] as? [String: Any] ?? [:]

        switch type {
        case "query":
            let queryInput = QueryInput(
                query: input["query"] as? String ?? "",
                triggers: input["triggers"] as? [String] ?? [],
                settings: settings
            )

            let results = ext.query(input: queryInput)
            let serialized = results.map { $0.serialize() }

            if let data = try? JSONSerialization.data(withJSONObject: serialized),
                let output = String(data: data, encoding: .utf8)
            {
                print(output)
                fflush(stdout)
            } else {
                print("[]")
                fflush(stdout)
            }

        case "action":
            let actionInput = ActionInput(
                function: input["function"] as? String ?? "",
                args: input["args"] as? [String] ?? [],
                formValues: input["formValues"] as? [String: String] ?? [:],
                settings: settings
            )
            // Commands emitted inside perform(action:) via Nerw.open/copy/notify/etc.
            // are written to stdout immediately by emitCommand(). No accumulator needed.
            ext.perform(action: actionInput)

        default:
            Nerw.log("Unknown message type: \(type)")
        }
    }

    // MARK: - Daemon Mode

    private static func runDaemonMode(daemon: NerwDaemon) {
        guard let socketPath = argValue(for: "--socket"),
            let dataDir = argValue(for: "--data-dir")
        else {
            Nerw.log("Daemon mode requires --socket and --data-dir arguments")
            exit(1)
        }

        let server = DaemonSocketServer(socketPath: socketPath)
        do {
            try server.start()
        } catch {
            Nerw.log("Failed to start daemon socket: \(error)")
            exit(1)
        }

        // Call onStart with context
        let context = DaemonContext(dataDirectory: dataDir, settings: [:])
        daemon.onStart(context: context)

        // Message loop
        while let msg = server.readMessage() {
            switch msg.type {

            case "query":
                guard let data = msg.payloadData,
                    let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                else { continue }

                let qSettings = raw["settings"] as? [String: Any] ?? [:]
                let queryInput = QueryInput(
                    query: raw["query"] as? String ?? "",
                    triggers: raw["triggers"] as? [String] ?? [],
                    settings: qSettings
                )
                let results = daemon.onQuery(input: queryInput)
                let serialized = results.map { $0.serialize() }
                if let respData = try? JSONSerialization.data(withJSONObject: serialized) {
                    server.sendMessage(
                        DaemonSocketMessage(id: msg.id, type: "response", payload: respData))
                }

            case "action":
                guard let data = msg.payloadData,
                    let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                else { continue }

                let aSettings = raw["settings"] as? [String: Any] ?? [:]
                let actionInput = ActionInput(
                    function: raw["function"] as? String ?? "",
                    args: raw["args"] as? [String] ?? [],
                    formValues: raw["formValues"] as? [String: String] ?? [:],
                    settings: aSettings
                )
                // Set daemonSocket so emitCommand() routes all Nerw.open/copy/notify/etc.
                // calls through the socket instead of stdout.
                daemonSocket = server
                daemon.onAction(input: actionInput)
                daemonSocket = nil

            case "health":
                server.sendMessage(DaemonSocketMessage(id: msg.id, type: "health_response"))

            case "stop":
                daemon.onStop()
                server.stop()
                exit(0)

            default:
                Nerw.log("Unknown daemon message type: \(msg.type)")
            }
        }

        // Connection dropped — daemon.onStop() and exit
        daemon.onStop()
        server.stop()
        exit(0)
    }

    // MARK: - Daemon Socket

    /// Non-nil during daemon action handling; routes emitCommand() calls to the socket.
    static var daemonSocket: DaemonSocketServer?

    // MARK: - Helpers

    private static func argValue(for flag: String) -> String? {
        let args = CommandLine.arguments
        guard let idx = args.firstIndex(of: flag), idx + 1 < args.count else { return nil }
        return args[idx + 1]
    }

    private static func startParentWatchdog() {
        let parentPID = getppid()
        DispatchQueue.global(qos: .utility).async {
            while true {
                sleep(2)
                if getppid() != parentPID {
                    exit(0)
                }
            }
        }
    }
}
