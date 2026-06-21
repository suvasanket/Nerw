import Foundation
import NerwUtils

// MARK: - RunningDaemon

struct RunningDaemon {
    let extensionId: String
    let process: Process
    let connection: DaemonConnection
    let startTime: Date
    let memoryLimitMB: Int
    /// Exponential backoff level (0 = first crash, increases per successive crash).
    var backoffLevel: Int = 0
    /// Timer token for the 60-second "successful run" reset.
    var crashResetTimer: DispatchWorkItem?
}

// MARK: - DaemonManager

/// Central lifecycle orchestrator for all daemon extensions.
/// - Starts all approved daemons on app launch.
/// - Routes extension queries/actions through the daemon when running.
/// - Restarts crashed daemons with exponential backoff.
/// - Stops all daemons on app quit.
public class DaemonManager {
    public static let shared = DaemonManager()

    private var runningDaemons: [String: RunningDaemon] = [:]
    private let lock = NSLock()

    // Max memory in MB when extension doesn't specify (capped at 256).
    private static let defaultMemoryLimitMB = 128
    private static let maxMemoryLimitMB = 256
    // Backoff delays: 2, 4, 8, 16, 32 seconds (capped at 32).
    private static let backoffDelays: [TimeInterval] = [2, 4, 8, 16, 32]

    private init() {
        // Handle resource violations from the monitor
        DaemonResourceMonitor.shared.onViolation = { [weak self] extensionId, reason in
            print(
                "[DaemonManager] Daemon '\(extensionId)' killed for resource violation: \(reason)")
            self?.lock.withLock { self?.runningDaemons.removeValue(forKey: extensionId) }
            DaemonRegistry.shared.disable(extensionId, reason: "resource_violation")
        }
    }

    // MARK: - App Lifecycle

    /// Called on app launch: cleans stale socket files, starts all approved daemons.
    public func startAllApproved() {
        cleanStaleSockets()
        DaemonResourceMonitor.shared.startMonitoring()

        // Find all extensions that have daemon config and are approved+runnable
        let extensions = ExtensionEngine.shared.loadedExtensions
        for ext in extensions {
            guard let daemonCfg = ext.manifest.daemon, daemonCfg.enabled else { continue }
            let id = ext.manifest.id
            DaemonRegistry.shared.register(id)
            guard DaemonRegistry.shared.isRunnable(id) else { continue }
            do {
                try startDaemon(extensionId: id)
            } catch {
                print("[DaemonManager] Failed to start daemon '\(id)': \(error)")
            }
        }
    }

    /// Called on app quit: gracefully stops all running daemons.
    public func stopAll() {
        DaemonResourceMonitor.shared.stopMonitoring()
        let ids = lock.withLock { Array(runningDaemons.keys) }
        for id in ids {
            stopDaemon(extensionId: id)
        }
    }

    /// Removes stale Unix socket files left from a previous session crash.
    public func cleanStaleSockets() {
        let runDir = NerwPaths.daemonRunDirectory
        NerwPaths.ensureDirectoryExists(at: runDir)
        let fm = FileManager.default
        guard
            let items = try? fm.contentsOfDirectory(
                at: runDir, includingPropertiesForKeys: nil
            )
        else { return }
        for item in items where item.pathExtension == "sock" && item.lastPathComponent != "ai.sock"
        {
            try? fm.removeItem(at: item)
        }
    }

    /// Synchronizes daemon state with the current loaded extensions.
    /// Stops any running daemons that were uninstalled, and cleans up the registry.
    func syncWithLoadedExtensions(_ extensions: [LoadedExtension]) {
        let validIds = Set(extensions.map { $0.manifest.id })

        let runningIds = lock.withLock { Array(runningDaemons.keys) }
        for id in runningIds {
            if !validIds.contains(id) {
                print("[DaemonManager] Stopping daemon '\(id)' because extension was uninstalled.")
                stopDaemon(extensionId: id)
            }
        }

        DaemonRegistry.shared.cleanup(validExtensionIds: Array(validIds))
    }

    // MARK: - Start / Stop

    /// Launches a daemon process and connects to it. Throws on hard failure.
    public func startDaemon(extensionId: String) throws {
        guard
            let ext = ExtensionEngine.shared.loadedExtensions.first(where: {
                $0.manifest.id == extensionId
            }), let binaryPath = ext.binaryPath
        else {
            throw DaemonManagerError.extensionNotFound(extensionId)
        }

        // Already running?
        if lock.withLock({ runningDaemons[extensionId] != nil }) {
            print("[DaemonManager] Daemon '\(extensionId)' already running.")
            return
        }

        let daemonCfg = ext.manifest.daemon
        let rawLimit = daemonCfg?.memoryLimit ?? Self.defaultMemoryLimitMB
        let memLimit = min(rawLimit, Self.maxMemoryLimitMB)

        let socketPath = NerwPaths.daemonRunDirectory
            .appendingPathComponent("\(extensionId).sock").path
        let dataDir = NerwPaths.daemonDataDir(for: extensionId).path

        // Ensure directories exist
        NerwPaths.ensureDirectoryExists(at: NerwPaths.daemonRunDirectory)
        NerwPaths.ensureDirectoryExists(at: NerwPaths.daemonDataDir(for: extensionId))

        // Remove stale socket if present
        try? FileManager.default.removeItem(atPath: socketPath)

        // Build process
        let process = Process()
        var execURL = binaryPath

        // Create a descriptive hardlink for Activity Monitor visibility
        let linkName = "nerw_daemon_\(extensionId.replacingOccurrences(of: ".", with: "_"))"
        let linkURL = binaryPath.deletingLastPathComponent().appendingPathComponent(linkName)
        try? FileManager.default.removeItem(at: linkURL)
        if (try? FileManager.default.linkItem(at: binaryPath, to: linkURL)) != nil {
            execURL = linkURL
        }

        process.executableURL = execURL
        process.arguments = ["--daemon", "--socket", socketPath, "--data-dir", dataDir]

        let stderrPipe = Pipe()
        process.standardError = stderrPipe

        // Forward stderr to console
        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty, let str = String(data: data, encoding: .utf8) {
                print("[Daemon:\(extensionId)] \(str.trimmingCharacters(in: .newlines))")
            }
        }

        do {
            try process.run()
        } catch {
            try? FileManager.default.removeItem(at: execURL)
            throw DaemonManagerError.launchFailed(extensionId, error)
        }

        print("[DaemonManager] Launched daemon '\(extensionId)' (PID \(process.processIdentifier))")

        // Wait for socket file to appear (max 5 seconds)
        guard waitForSocket(path: socketPath, timeoutSeconds: 5) else {
            process.terminate()
            try? FileManager.default.removeItem(at: execURL)
            throw DaemonManagerError.socketTimeout(extensionId)
        }

        // Connect to daemon's socket
        let connection = DaemonConnection(extensionId: extensionId, socketPath: socketPath)
        connection.onExtCommand = { [weak self] commands in
            ExtensionEngine.shared.executeCommands(commands)
        }
        try connection.connect()

        // Health check
        let healthy = withCheckedResult { done in
            connection.healthCheck { ok in done(ok) }
        }
        guard healthy else {
            connection.disconnect()
            process.terminate()
            try? FileManager.default.removeItem(at: execURL)
            throw DaemonManagerError.healthCheckFailed(extensionId)
        }

        // Register for resource monitoring
        DaemonResourceMonitor.shared.track(
            extensionId: extensionId, pid: process.processIdentifier,
            memoryLimitMB: memLimit)

        // Schedule 60-second crash-count reset
        let resetItem = DispatchWorkItem { [weak self] in
            DaemonRegistry.shared.resetCrashCount(extensionId)
            self?.lock.withLock {
                self?.runningDaemons[extensionId]?.crashResetTimer = nil
            }
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + 60, execute: resetItem)

        let daemon = RunningDaemon(
            extensionId: extensionId,
            process: process,
            connection: connection,
            startTime: Date(),
            memoryLimitMB: memLimit,
            crashResetTimer: resetItem
        )
        lock.withLock { runningDaemons[extensionId] = daemon }

        // Termination handler — fires on crash or normal exit
        process.terminationHandler = { [weak self] proc in
            guard let self = self else { return }
            print(
                "[DaemonManager] Daemon '\(extensionId)' exited (status: \(proc.terminationStatus))"
            )
            // Cleanup hardlink
            try? FileManager.default.removeItem(at: execURL)
            stderrPipe.fileHandleForReading.readabilityHandler = nil
            self.handleExit(extensionId: extensionId, exitCode: proc.terminationStatus)
        }
    }

    /// Gracefully stops a daemon: sends stop message, waits 2s, then terminates.
    public func stopDaemon(extensionId: String) {
        let daemon = lock.withLock { runningDaemons.removeValue(forKey: extensionId) }
        guard let daemon = daemon else { return }

        daemon.crashResetTimer?.cancel()
        DaemonResourceMonitor.shared.untrack(extensionId: extensionId)
        daemon.connection.sendStop()

        DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
            if daemon.process.isRunning {
                daemon.process.terminate()
            }
            daemon.connection.disconnect()
        }
    }

    // MARK: - Routing (called by ExtensionEngine)

    public func isRunning(_ extensionId: String) -> Bool {
        lock.withLock { runningDaemons[extensionId] != nil }
    }

    /// Send a query through the daemon; calls completion with raw JSON data or nil.
    public func sendQuery(
        extensionId: String,
        input: ExtensionInput,
        completion: @escaping (Data?) -> Void
    ) {
        guard let conn = lock.withLock({ runningDaemons[extensionId]?.connection }) else {
            completion(nil)
            return
        }
        conn.sendQuery(input, completion: completion)
    }

    /// Send an action through the daemon.
    public func sendAction(extensionId: String, input: ExtensionInput) {
        guard let conn = lock.withLock({ runningDaemons[extensionId]?.connection }) else { return }
        conn.sendAction(input)
    }

    /// Returns a status snapshot for all running daemons.
    public func status() -> [(id: String, pid: pid_t, memoryMB: Double, uptime: TimeInterval)] {
        lock.withLock {
            runningDaemons.values.map { d in
                let snap = DaemonResourceMonitor.shared.snapshot(for: d.extensionId)
                return (
                    id: d.extensionId,
                    pid: d.process.processIdentifier,
                    memoryMB: snap?.memoryMB ?? 0,
                    uptime: Date().timeIntervalSince(d.startTime)
                )
            }
        }
    }

    // MARK: - Crash Recovery

    private func handleExit(extensionId: String, exitCode: Int32) {
        let daemon = lock.withLock { runningDaemons.removeValue(forKey: extensionId) }
        daemon?.crashResetTimer?.cancel()
        DaemonResourceMonitor.shared.untrack(extensionId: extensionId)
        daemon?.connection.disconnect()

        // exitCode 0 = graceful stop (e.g., from sendStop()). Don't restart.
        guard exitCode != 0 else { return }

        let shouldRestart = DaemonRegistry.shared.recordCrash(extensionId)
        guard shouldRestart else {
            print("[DaemonManager] Daemon '\(extensionId)' disabled after crash budget exceeded.")
            return
        }

        let backoffLevel = daemon?.backoffLevel ?? 0
        let delays = Self.backoffDelays
        let delay = backoffLevel < delays.count ? delays[backoffLevel] : delays.last!
        print(
            "[DaemonManager] Restarting '\(extensionId)' in \(delay)s (backoff level \(backoffLevel))..."
        )

        DispatchQueue.global().asyncAfter(deadline: .now() + delay) { [weak self] in
            guard DaemonRegistry.shared.isRunnable(extensionId) else { return }
            do {
                try self?.startDaemon(extensionId: extensionId)
                // Update backoff level on the newly started daemon
                self?.lock.withLock {
                    self?.runningDaemons[extensionId]?.backoffLevel = backoffLevel + 1
                }
            } catch {
                print("[DaemonManager] Restart failed for '\(extensionId)': \(error)")
            }
        }
    }

    // MARK: - Helpers

    private func waitForSocket(path: String, timeoutSeconds: Double) -> Bool {
        let start = Date()
        while Date().timeIntervalSince(start) < timeoutSeconds {
            if FileManager.default.fileExists(atPath: path) { return true }
            Thread.sleep(forTimeInterval: 0.1)
        }
        return false
    }

    /// Synchronously waits for a callback to fire (used for health check on startup).
    private func withCheckedResult(_ block: @escaping (@escaping (Bool) -> Void) -> Void) -> Bool {
        let semaphore = DispatchSemaphore(value: 0)
        var result = false
        block { ok in
            result = ok
            semaphore.signal()
        }
        semaphore.wait()
        return result
    }
}

// MARK: - Errors

public enum DaemonManagerError: Error {
    case extensionNotFound(String)
    case launchFailed(String, Error)
    case socketTimeout(String)
    case healthCheckFailed(String)
}
