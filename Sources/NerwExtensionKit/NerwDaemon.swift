import Foundation

// MARK: - DaemonContext

/// Context provided to a daemon on startup.
public struct DaemonContext {
    /// Absolute path to the extension's persistent data directory.
    /// Survives daemon restarts; cleaned on extension uninstall.
    public let dataDirectory: String

    /// Extension settings as configured by the user.
    public let settings: [String: Any]

    public init(dataDirectory: String, settings: [String: Any]) {
        self.dataDirectory = dataDirectory
        self.settings = settings
    }
}

// MARK: - NerwDaemon Protocol

/// Implement this protocol to give your extension a background daemon.
///
/// Register your daemon alongside the extension in `main.swift`:
/// ```swift
/// Nerw.run(extension: MyExtension(), daemon: MyDaemon())
/// ```
///
/// The daemon runs continuously while Nerw is open. It handles queries and actions
/// instead of spawning a fresh process each time, enabling instant results from
/// in-memory indexes and persistent connections.
public protocol NerwDaemon: AnyObject {
    /// Called once when the daemon starts. Set up file watchers, indexes, connections, etc.
    /// - Parameter context: Provides the data directory path and extension settings.
    func onStart(context: DaemonContext)

    /// Called for every search query that matches this extension's triggers.
    /// Return results from your in-memory index for instant responses.
    func onQuery(input: QueryInput) -> [NerwResult]

    /// Called when the user executes an action from this extension.
    /// Use `Nerw.open()`, `Nerw.copy()`, `Nerw.notify()` etc. as usual.
    func onAction(input: ActionInput)

    /// Called just before the daemon is terminated gracefully.
    /// Persist any in-memory state here.
    func onStop()
}

// MARK: - Default implementations (all optional)

extension NerwDaemon {
    public func onQuery(input: QueryInput) -> [NerwResult] { [] }
    public func onAction(input: ActionInput) {}
    public func onStop() {}
}
