import Foundation

/// The Nerw API — host commands and extension bootstrap.
/// Extension developers use `Nerw.open()`, `Nerw.copy()`, `Nerw.log()`
/// inside their `perform(action:)` method, then call `Nerw.run()` to start.
public enum Nerw {
    // MARK: - Command Accumulator (internal)
    static var pendingCommands: [[String: Any]] = []

    // MARK: - Host Commands

    /// Open a URL in the default browser or a file path in Finder.
    public static func open(_ url: String) {
        pendingCommands.append(["type": "open", "value": url])
    }

    /// Copy text to the system clipboard.
    public static func copy(_ text: String) {
        pendingCommands.append(["type": "copy", "value": text])
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
        pendingCommands.append(cmd)
    }

    /// Dismisses a previously sent progressive notification using its assigned string ID.
    public static func dismissNotify(id: String) {
        pendingCommands.append([
            "type": "dismiss_notify",
            "id": id,
        ])
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
        guard let inputLine = readLine(),
            let inputData = inputLine.data(using: .utf8),
            let input = try? JSONSerialization.jsonObject(with: inputData) as? [String: Any]
        else {
            Nerw.log("Failed to read input")
            exit(1)
        }

        let type = input["type"] as? String ?? ""

        switch type {
        case "query":
            let queryInput = QueryInput(
                query: input["query"] as? String ?? "",
                trigger: input["trigger"] as? String
            )

            let results = ext.query(input: queryInput)
            let serialized = results.map { $0.serialize() }

            if let data = try? JSONSerialization.data(withJSONObject: serialized),
                let output = String(data: data, encoding: .utf8)
            {
                print(output)
            } else {
                print("[]")
            }

        case "action":
            let actionInput = ActionInput(
                function: input["function"] as? String ?? "",
                args: input["args"] as? [String] ?? [],
                formValues: input["formValues"] as? [String: String] ?? [:]
            )

            pendingCommands = []
            ext.perform(action: actionInput)

            let response: [String: Any] = ["commands": pendingCommands]
            if let data = try? JSONSerialization.data(withJSONObject: response),
                let output = String(data: data, encoding: .utf8)
            {
                print(output)
            } else {
                print("{}")
            }

        default:
            Nerw.log("Unknown message type: \(type)")
        }
    }
}
