import AppKit
import Foundation
import NerwAction
import NerwCore
import NerwUtils

public struct NerwTimer: Codable, Equatable, Identifiable {
    public let id: UUID
    public var label: String
    public var targetDate: Date
    public var totalDuration: TimeInterval
    public let createdAt: Date
    public var isCompleted: Bool
    public var isSnoozed: Bool

    public var remainingDuration: TimeInterval {
        return max(0, targetDate.timeIntervalSinceNow)
    }

    public init(
        id: UUID = UUID(),
        label: String,
        targetDate: Date,
        totalDuration: TimeInterval,
        createdAt: Date = Date(),
        isCompleted: Bool = false,
        isSnoozed: Bool = false
    ) {
        self.id = id
        self.label = label
        self.targetDate = targetDate
        self.totalDuration = totalDuration
        self.createdAt = createdAt
        self.isCompleted = isCompleted
        self.isSnoozed = isSnoozed
    }
}

public final class TimerSoundPlayer {
    public static let shared = TimerSoundPlayer()

    private var currentSound: NSSound?
    private var loopTimer: Timer?

    private init() {}

    public func playAlert() {
        stop()

        // Choose a crisp alert sound available on macOS
        let soundNames = ["Glass", "Ping", "Hero", "Submarine", "Pop"]
        var soundToPlay: NSSound? = nil
        for name in soundNames {
            if let s = NSSound(named: NSSound.Name(name)) {
                soundToPlay = s
                break
            }
        }

        if let sound = soundToPlay {
            self.currentSound = sound
            sound.play()

            // Play alert chimes periodically until dismissed
            DispatchQueue.main.async { [weak self] in
                self?.loopTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { _ in
                    sound.stop()
                    sound.play()
                }
            }
        } else {
            NSSound.beep()
        }
    }

    public func stop() {
        loopTimer?.invalidate()
        loopTimer = nil
        currentSound?.stop()
        currentSound = nil
    }
}

public final class TimerManager {
    public static let shared = TimerManager()

    private let lock = NSLock()
    private var timers: [NerwTimer] = []
    private var checkTimer: Timer?
    private var triggeredTimerIds: Set<UUID> = []

    public var showTimerAlertCallback: ((NerwTimer) -> Void)?

    private init() {
        loadTimers()
    }

    public func setup() {
        startMonitoring()
    }

    // MARK: - Active Timers Access

    public var activeTimers: [NerwTimer] {
        lock.lock()
        defer { lock.unlock() }
        let now = Date()
        return timers.filter { !$0.isCompleted && $0.targetDate > now }
    }

    public var allTimers: [NerwTimer] {
        lock.lock()
        defer { lock.unlock() }
        return timers
    }

    // MARK: - Timer Actions

    @discardableResult
    public func startTimer(duration: TimeInterval, label: String = "Timer") -> NerwTimer {
        let now = Date()
        let target = now.addingTimeInterval(duration)
        let timer = NerwTimer(
            label: label.isEmpty ? "Timer" : label,
            targetDate: target,
            totalDuration: duration,
            createdAt: now
        )

        lock.lock()
        timers.append(timer)
        triggeredTimerIds.remove(timer.id)
        lock.unlock()

        saveTimers()
        startMonitoring()

        Logger.shared.info(
            "TimerManager: Started timer '\(timer.label)' for \(duration)s (target: \(target))")
        return timer
    }

    @discardableResult
    public func startTimer(targetDate: Date, label: String = "Timer") -> NerwTimer {
        let now = Date()
        let duration = max(1, targetDate.timeIntervalSince(now))
        return startTimer(duration: duration, label: label)
    }

    public func cancelTimer(id: UUID) {
        lock.lock()
        if let idx = timers.firstIndex(where: { $0.id == id }) {
            timers.remove(at: idx)
        }
        triggeredTimerIds.remove(id)
        lock.unlock()

        TimerSoundPlayer.shared.stop()
        saveTimers()
        Logger.shared.info("TimerManager: Cancelled timer \(id)")
    }

    public func completeTimer(id: UUID) {
        lock.lock()
        if let idx = timers.firstIndex(where: { $0.id == id }) {
            timers.remove(at: idx)
        }
        triggeredTimerIds.remove(id)
        lock.unlock()

        TimerSoundPlayer.shared.stop()
        saveTimers()
        Logger.shared.info("TimerManager: Completed timer \(id)")
    }

    public func reset() {
        lock.lock()
        timers.removeAll()
        triggeredTimerIds.removeAll()
        lock.unlock()

        checkTimer?.invalidate()
        checkTimer = nil
        TimerSoundPlayer.shared.stop()
        saveTimers()
    }

    @discardableResult
    public func snoozeTimer(id: UUID, duration: TimeInterval = 300) -> NerwTimer? {
        TimerSoundPlayer.shared.stop()

        lock.lock()
        guard let idx = timers.firstIndex(where: { $0.id == id }) else {
            lock.unlock()
            return nil
        }

        let now = Date()
        let newTarget = now.addingTimeInterval(duration)
        timers[idx].targetDate = newTarget
        timers[idx].totalDuration = duration
        timers[idx].isCompleted = false
        timers[idx].isSnoozed = true
        let updated = timers[idx]
        triggeredTimerIds.remove(id)
        lock.unlock()

        saveTimers()
        startMonitoring()

        let durStr = TimerParser.shared.formatDuration(duration)
        Nerw.notify(
            "Timer '\(updated.label)' snoozed for \(durStr)", level: .info)
        Logger.shared.info("TimerManager: Snoozed timer \(id) for \(duration)s")
        return updated
    }

    // MARK: - Background Monitoring

    private func startMonitoring() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.checkTimer == nil {
                self.checkTimer = Timer.scheduledTimer(
                    withTimeInterval: 1.0, repeats: true
                ) { [weak self] _ in
                    self?.checkExpiringTimers()
                }
                if let timer = self.checkTimer {
                    RunLoop.main.add(timer, forMode: .common)
                }
            }
        }
    }

    private func checkExpiringTimers() {
        let now = Date()
        var dueTimers: [NerwTimer] = []

        lock.lock()
        for idx in 0..<timers.count {
            let timer = timers[idx]
            if !timer.isCompleted && timer.targetDate <= now
                && !triggeredTimerIds.contains(timer.id)
            {
                triggeredTimerIds.insert(timer.id)
                dueTimers.append(timer)
            }
        }
        lock.unlock()

        for timer in dueTimers {
            handleTimerFired(timer)
        }
    }

    private func handleTimerFired(_ timer: NerwTimer) {
        Logger.shared.info("TimerManager: Timer '\(timer.label)' fired!")

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // 1. Play alert sound
            TimerSoundPlayer.shared.playAlert()

            // 2. Trigger centered pop-up
            if let callback = self.showTimerAlertCallback {
                callback(timer)
            } else {
                // Fallback notification if UI callback not yet hooked
                Nerw.notify("⏰ Timer Finished: \(timer.label)", level: .info)
            }
        }
    }

    // MARK: - Persistence

    private func saveTimers() {
        lock.lock()
        let toSave = timers.filter { !$0.isCompleted }
        lock.unlock()

        NerwPaths.ensureDirectoryExists(at: NerwPaths.dataDirectory)
        do {
            let data = try JSONEncoder().encode(toSave)
            try data.write(to: NerwPaths.timersFile, options: .atomic)
        } catch {
            Logger.shared.error("TimerManager: Failed to save timers: \(error)")
        }
    }

    private func loadTimers() {
        let file = NerwPaths.timersFile
        guard FileManager.default.fileExists(atPath: file.path) else { return }
        do {
            let data = try Data(contentsOf: file)
            let loaded = try JSONDecoder().decode([NerwTimer].self, from: data)
            lock.lock()
            self.timers = loaded
            lock.unlock()
            Logger.shared.info("TimerManager: Loaded \(loaded.count) timers from disk.")
        } catch {
            Logger.shared.error("TimerManager: Failed to load timers: \(error)")
        }
    }

    // MARK: - Builtin Search Actions

    public static func builtinActions() -> [NerwAction] {
        let manager = TimerManager.shared

        return [
            NerwAction(
                id: "nerw.builtin.timer",
                title: "Start Timer",
                subtitle: "Set a timer with natural language (e.g. 2m, until next 7, 7pm)",
                icon: .system("timer"),
                triggers: ["starttimer", "settimer", "timer", "countdown"],
                type: .inlineArg(
                    perform: { _, arg in
                        let query = arg.trimmingCharacters(in: .whitespacesAndNewlines)
                        if let result = TimerParser.shared.parse(query: query) {
                            manager.startTimer(duration: result.duration, label: result.label)
                            Nerw.notify(
                                "Timer set for \(result.displayDuration): \(result.label) (Ends at \(result.displayTarget))",
                                level: .info)
                        } else if !query.isEmpty {
                            // Fallback default duration (e.g. 5 minutes if unrecognized)
                            let timer = manager.startTimer(duration: 300, label: query)
                            let targetStr = TimerParser.shared.formatTargetTime(timer.targetDate)
                            Nerw.notify(
                                "Timer set for 5m: \(timer.label) (Ends at \(targetStr))",
                                level: .info)
                        }
                    },
                    searcher: { action, arg, completion in
                        let query = arg.trimmingCharacters(in: .whitespacesAndNewlines)
                        var results: [NerwAction] = []

                        if query.isEmpty {
                            // Default action prompt
                            results.append(
                                NerwAction(
                                    id: "nerw.builtin.timer.prompt",
                                    title: "Start Timer",
                                    subtitle:
                                        "Type a duration or time (e.g. '2min Tea', 'settimer for 2min', 'until next 7', '7pm Focus')",
                                    icon: .system("timer"),
                                    triggers: [],
                                    type: .instant(perform: { _ in
                                        // Default quick 5m timer if immediately selected
                                        let timer = manager.startTimer(
                                            duration: 300, label: "Timer")
                                        let targetStr = TimerParser.shared.formatTargetTime(
                                            timer.targetDate)
                                        Nerw.notify(
                                            "Timer set for 5m (Ends at \(targetStr))",
                                            level: .info)
                                    })
                                )
                            )
                        } else if let parseResult = TimerParser.shared.parse(query: query) {
                            let durationText = parseResult.displayDuration
                            let targetText = parseResult.displayTarget
                            let labelText = parseResult.label

                            results.append(
                                NerwAction(
                                    id: "nerw.builtin.timer.dynamic",
                                    title: "Start Timer: \(labelText)",
                                    subtitle:
                                        "Duration: \(durationText) • Ends at \(targetText)",
                                    icon: .system("timer"),
                                    triggers: [],
                                    type: .instant(perform: { _ in
                                        manager.startTimer(
                                            duration: parseResult.duration,
                                            label: parseResult.label)
                                        Nerw.notify(
                                            "Timer set for \(durationText): \(labelText) (Ends at \(targetText))",
                                            level: .info)
                                    })
                                )
                            )
                        } else {
                            // Helpful suggestion when typing partial input
                            results.append(
                                NerwAction(
                                    id: "nerw.builtin.timer.suggestion",
                                    title: "Start Timer: \(query)",
                                    subtitle:
                                        "Set 5-minute timer for '\(query)' (or type '2m', 'until next 7', '7pm')",
                                    icon: .system("timer"),
                                    triggers: [],
                                    type: .instant(perform: { _ in
                                        let timer = manager.startTimer(duration: 300, label: query)
                                        let targetStr = TimerParser.shared.formatTargetTime(
                                            timer.targetDate)
                                        Nerw.notify(
                                            "Timer set for 5m: \(timer.label) (Ends at \(targetStr))",
                                            level: .info)
                                    })
                                )
                            )
                        }

                        // Append active running timers with one-click cancel action
                        let running = manager.activeTimers
                        for active in running {
                            let remaining = TimerParser.shared.formatDuration(
                                active.remainingDuration)
                            let target = TimerParser.shared.formatTargetTime(active.targetDate)
                            results.append(
                                NerwAction(
                                    id: "nerw.builtin.timer.active.\(active.id.uuidString)",
                                    title: "Running: \(active.label) (\(remaining) left)",
                                    subtitle:
                                        "Ends at \(target) • Press Enter to Cancel",
                                    icon: .system("stopwatch.fill"),
                                    triggers: [],
                                    type: .instant(perform: { _ in
                                        manager.cancelTimer(id: active.id)
                                        Nerw.notify(
                                            "Cancelled timer: \(active.label)", level: .info)
                                    })
                                )
                            )
                        }

                        completion(results)
                    }
                )
            )
        ]
    }
}
