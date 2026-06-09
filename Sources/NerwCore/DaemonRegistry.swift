import Foundation
import NerwUtils

// MARK: - DaemonEntry

/// Persisted state for a single daemon extension.
public struct DaemonEntry: Codable {
    public let extensionId: String
    /// User explicitly granted daemon permission.
    public var approved: Bool
    /// User hasn't disabled it (separate from approval).
    public var enabled: Bool
    /// Crashes since last successful 60-second run.
    public var crashCount: Int
    /// Timestamp of the most recent crash.
    public var lastCrashTime: Date?
    /// Reason daemon was auto-disabled: "crash_limit", "resource_violation", "user".
    public var disabledReason: String?

    public init(extensionId: String) {
        self.extensionId = extensionId
        self.approved = false
        self.enabled = true
        self.crashCount = 0
        self.lastCrashTime = nil
        self.disabledReason = nil
    }
}

// MARK: - DaemonRegistry

/// Persists daemon approval state and crash tracking to `~/.nerw/daemon_registry.json`.
public class DaemonRegistry {
    public static let shared = DaemonRegistry()

    // Max crashes within the budget window before auto-disable.
    private static let crashBudget = 5
    // Sliding window for crash budget (seconds).
    private static let crashWindowSeconds: TimeInterval = 10 * 60  // 10 minutes
    // Successful uptime to reset crash count (seconds).
    private static let resetUptimeSeconds: TimeInterval = 60

    private let lock = NSLock()
    private var entries: [String: DaemonEntry] = [:]

    private var registryPath: URL {
        NerwPaths.configDirectory.appendingPathComponent("daemon_registry.json")
    }

    private init() {
        load()
    }

    // MARK: - Approval

    /// Returns true if the extension has been explicitly approved and not revoked.
    public func isApproved(_ extensionId: String) -> Bool {
        lock.withLock { entries[extensionId]?.approved == true }
    }

    /// Returns true if the daemon is approved, enabled, and not auto-disabled.
    public func isRunnable(_ extensionId: String) -> Bool {
        lock.withLock {
            guard let entry = entries[extensionId] else { return false }
            return entry.approved && entry.enabled && entry.disabledReason == nil
        }
    }

    /// Grants daemon permission for an extension.
    public func approve(_ extensionId: String) {
        lock.withLock {
            var entry = entries[extensionId] ?? DaemonEntry(extensionId: extensionId)
            entry.approved = true
            entry.enabled = true
            entry.disabledReason = nil
            entries[extensionId] = entry
        }
        save()
    }

    /// Revokes daemon permission and stops the daemon if running.
    public func revoke(_ extensionId: String) {
        lock.withLock {
            var entry = entries[extensionId] ?? DaemonEntry(extensionId: extensionId)
            entry.approved = false
            entry.enabled = false
            entry.disabledReason = "user"
            entries[extensionId] = entry
        }
        save()
    }

    // MARK: - Enable / Disable

    public func enable(_ extensionId: String) {
        lock.withLock {
            guard var entry = entries[extensionId] else { return }
            entry.enabled = true
            entry.disabledReason = nil
            entry.crashCount = 0
            entries[extensionId] = entry
        }
        save()
    }

    public func disable(_ extensionId: String, reason: String) {
        lock.withLock {
            guard var entry = entries[extensionId] else { return }
            entry.enabled = false
            entry.disabledReason = reason
            entries[extensionId] = entry
        }
        save()
    }

    // MARK: - Crash Tracking

    /// Records a crash. Returns false if the crash budget is exceeded (auto-disables the daemon).
    @discardableResult
    public func recordCrash(_ extensionId: String) -> Bool {
        var budgetExceeded = false
        lock.withLock {
            guard var entry = entries[extensionId] else { return }

            let now = Date()
            // Reset count if outside the crash window
            if let lastCrash = entry.lastCrashTime,
                now.timeIntervalSince(lastCrash) > Self.crashWindowSeconds
            {
                entry.crashCount = 0
            }

            entry.crashCount += 1
            entry.lastCrashTime = now

            if entry.crashCount >= Self.crashBudget {
                entry.enabled = false
                entry.disabledReason = "crash_limit"
                budgetExceeded = true
                print(
                    "[DaemonRegistry] Extension '\(extensionId)' auto-disabled: crash limit reached (\(entry.crashCount) crashes)."
                )
            }

            entries[extensionId] = entry
        }
        save()
        return !budgetExceeded
    }

    /// Called after a daemon has been running successfully for ≥60 seconds to reset crash count.
    public func resetCrashCount(_ extensionId: String) {
        lock.withLock {
            guard var entry = entries[extensionId] else { return }
            entry.crashCount = 0
            entry.lastCrashTime = nil
            entries[extensionId] = entry
        }
        save()
    }

    // MARK: - Query

    public func allEntries() -> [DaemonEntry] {
        lock.withLock { Array(entries.values).sorted { $0.extensionId < $1.extensionId } }
    }

    public func entry(for extensionId: String) -> DaemonEntry? {
        lock.withLock { entries[extensionId] }
    }
    /// Ensures an entry exists for the extension (call on first discovery).
    public func register(_ extensionId: String) {
        var didRegister = false
        lock.withLock {
            if entries[extensionId] == nil {
                entries[extensionId] = DaemonEntry(extensionId: extensionId)
                didRegister = true
            }
        }
        if didRegister {
            save()
        }
    }
    /// Removes entries for extensions that are no longer installed, and deletes their persistent data.
    public func cleanup(validExtensionIds: [String]) {
        let validSet = Set(validExtensionIds)
        lock.withLock {
            let existingIds = Array(entries.keys)
            for id in existingIds {
                if !validSet.contains(id) {
                    print("[DaemonRegistry] Cleaning up uninstalled extension: \(id)")
                    entries.removeValue(forKey: id)
                    // Delete the persistent data directory for this daemon
                    let dataDir = NerwPaths.daemonDataDir(for: id)
                    try? FileManager.default.removeItem(at: dataDir)
                }
            }
        }
        save()
    }

    // MARK: - Persistence

    public func load() {
        lock.withLock {
            NerwPaths.ensureDirectoryExists(at: NerwPaths.configDirectory)
            guard let data = try? Data(contentsOf: registryPath),
                let decoded = try? JSONDecoder().decode([String: DaemonEntry].self, from: data)
            else {
                return
            }
            entries = decoded
        }
    }

    private func save() {
        NerwPaths.ensureDirectoryExists(at: NerwPaths.configDirectory)
        if let data = try? JSONEncoder().encode(entries) {
            try? data.write(to: registryPath, options: .atomic)
        }
    }
}

// MARK: - NSLock convenience

extension NSLock {
    @discardableResult
    func withLock<T>(_ body: () -> T) -> T {
        lock()
        defer { unlock() }
        return body()
    }
}
