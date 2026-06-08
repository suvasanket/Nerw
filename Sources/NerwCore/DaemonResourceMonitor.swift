import Foundation

#if canImport(Darwin)
    import Darwin
#endif

// MARK: - DaemonResourceSnapshot

/// A point-in-time resource reading for a running daemon.
public struct DaemonResourceSnapshot {
    public let extensionId: String
    public let pid: pid_t
    /// Resident Set Size in megabytes.
    public let memoryMB: Double
    /// CPU % over the last monitoring interval.
    public let cpuPercent: Double
}

// MARK: - Tracked Entry (internal)

private struct TrackedDaemon {
    let extensionId: String
    let pid: pid_t
    let memoryLimitMB: Int
    /// Rolling CPU time samples (user+sys nanoseconds from rusage).
    var cpuTimeSamples: [UInt64] = []
    /// Consecutive samples where CPU exceeded the threshold.
    var highCPUSampleCount: Int = 0
}

// MARK: - DaemonResourceMonitor

/// Polls running daemons every 5 seconds for memory and CPU usage.
/// Violations trigger a SIGTERM → 5s grace → SIGKILL sequence.
public class DaemonResourceMonitor {
    public static let shared = DaemonResourceMonitor()

    // --- Configuration ---
    /// Polling interval.
    private static let pollIntervalSeconds: Double = 5.0
    /// CPU % threshold for a "high CPU" sample.
    private static let cpuThresholdPercent: Double = 25.0
    /// Consecutive high-CPU samples before SIGTERM (6 × 5s = 30s).
    private static let cpuSustainedSamples: Int = 6
    /// Grace period after SIGTERM before SIGKILL (seconds).
    private static let sigtermGraceSeconds: Double = 5.0

    private var timer: DispatchSourceTimer?
    private var tracked: [String: TrackedDaemon] = [:]  // extensionId → entry
    private let lock = NSLock()

    /// Called on the main queue when a daemon is killed for resource violation.
    /// Parameters: (extensionId, reason) where reason is "memory" or "cpu".
    public var onViolation: ((String, String) -> Void)?

    private init() {}

    // MARK: - Tracking

    public func track(extensionId: String, pid: pid_t, memoryLimitMB: Int) {
        lock.withLock {
            tracked[extensionId] = TrackedDaemon(
                extensionId: extensionId, pid: pid, memoryLimitMB: memoryLimitMB)
        }
    }

    public func untrack(extensionId: String) {
        lock.withLock { tracked.removeValue(forKey: extensionId) }
    }

    // MARK: - Lifecycle

    public func startMonitoring() {
        guard timer == nil else { return }

        let t = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .utility))
        t.schedule(
            deadline: .now() + Self.pollIntervalSeconds,
            repeating: Self.pollIntervalSeconds)
        t.setEventHandler { [weak self] in self?.poll() }
        t.resume()
        timer = t
        print("[DaemonResourceMonitor] Started (interval: \(Self.pollIntervalSeconds)s)")
    }

    public func stopMonitoring() {
        timer?.cancel()
        timer = nil
    }

    // MARK: - Snapshots

    public func snapshot(for extensionId: String) -> DaemonResourceSnapshot? {
        guard let entry = lock.withLock({ tracked[extensionId] }) else { return nil }
        let mem = memoryMB(pid: entry.pid)
        return DaemonResourceSnapshot(
            extensionId: extensionId, pid: entry.pid,
            memoryMB: mem, cpuPercent: 0)  // live cpu% not tracked here
    }

    // MARK: - Poll

    private func poll() {
        let entries = lock.withLock { tracked }

        for var entry in entries.values {
            guard kill(entry.pid, 0) == 0 else {
                // Process already gone — will be handled by DaemonManager termination handler.
                continue
            }

            // --- Memory check ---
            let mem = memoryMB(pid: entry.pid)
            if mem > Double(entry.memoryLimitMB) {
                print(
                    "[DaemonResourceMonitor] '\(entry.extensionId)' exceeded memory limit (\(Int(mem))MB > \(entry.memoryLimitMB)MB). Terminating."
                )
                terminate(pid: entry.pid, extensionId: entry.extensionId, reason: "memory")
                continue
            }

            // --- CPU check ---
            let currentCPUTime = cpuTimeNanos(pid: entry.pid)
            entry.cpuTimeSamples.append(currentCPUTime)
            if entry.cpuTimeSamples.count > 2 {
                entry.cpuTimeSamples.removeFirst()
            }

            if entry.cpuTimeSamples.count == 2 {
                let delta = Double(entry.cpuTimeSamples[1] - entry.cpuTimeSamples[0])
                let intervalNanos = Self.pollIntervalSeconds * 1_000_000_000.0
                let cpuPercent = (delta / intervalNanos) * 100.0

                if cpuPercent > Self.cpuThresholdPercent {
                    entry.highCPUSampleCount += 1
                } else {
                    entry.highCPUSampleCount = 0
                }

                if entry.highCPUSampleCount >= Self.cpuSustainedSamples {
                    print(
                        "[DaemonResourceMonitor] '\(entry.extensionId)' sustained CPU \(Int(cpuPercent))% for \(Self.cpuSustainedSamples) samples. Terminating."
                    )
                    terminate(pid: entry.pid, extensionId: entry.extensionId, reason: "cpu")
                    continue
                }
            }

            // Update entry with new sample counts
            lock.withLock { tracked[entry.extensionId] = entry }
        }
    }

    // MARK: - Termination

    private func terminate(pid: pid_t, extensionId: String, reason: String) {
        lock.withLock { tracked.removeValue(forKey: extensionId) }

        // SIGTERM first
        kill(pid, SIGTERM)

        // After grace period, SIGKILL if still alive
        DispatchQueue.global().asyncAfter(deadline: .now() + Self.sigtermGraceSeconds) {
            if kill(pid, 0) == 0 {
                print(
                    "[DaemonResourceMonitor] '\(extensionId)' still alive after grace. Sending SIGKILL."
                )
                kill(pid, SIGKILL)
            }
        }

        DispatchQueue.main.async { [weak self] in
            self?.onViolation?(extensionId, reason)
        }
    }

    // MARK: - System Metrics

    /// Returns RSS in MB via proc_pid_rusage.
    private func memoryMB(pid: pid_t) -> Double {
        var info = rusage_info_v4()
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
                proc_pid_rusage(pid, RUSAGE_INFO_V4, $0)
            }
        }
        guard result == 0 else { return 0 }
        return Double(info.ri_phys_footprint) / (1024 * 1024)
    }

    /// Returns total CPU time (user + system) in nanoseconds.
    private func cpuTimeNanos(pid: pid_t) -> UInt64 {
        var info = rusage_info_v4()
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
                proc_pid_rusage(pid, RUSAGE_INFO_V4, $0)
            }
        }
        guard result == 0 else { return 0 }
        return info.ri_user_time + info.ri_system_time
    }
}
