import Foundation
import NerwUtils

/// Sensitivity level for frecency scoring (0-10 scale)
/// - 0: Disabled (frecency has no effect)
/// - 5: Moderate (balanced influence)
/// - 10: Maximum (frecency dominates ranking)
public enum FrecencySensitivity: Int {
    case disabled = 0
    case minimal = 1
    case low = 3
    case moderate = 5
    case high = 7
    case maximum = 10

    /// Multiplier applied to frecency scores
    public var multiplier: Double {
        Double(rawValue) / 10.0
    }
}

public class FrecencyManager {
    public static let shared = FrecencyManager()

    private let fileManager = FileManager.default
    private let queue = DispatchQueue(label: "com.nerw.frecency", attributes: .concurrent)

    // Key: Item ID, Value: Score Data
    private var scores: [String: FrecencyData] = [:]
    // Key: "query:itemId", Value: usage count for query-aware tracking
    private var queryScores: [String: QueryFrecencyData] = [:]

    // Debounce timers for efficient batch saves
    private var saveScoresWorkItem: DispatchWorkItem?
    private var saveQueryScoresWorkItem: DispatchWorkItem?
    private let saveDebounceInterval: TimeInterval = 0.5

    // Pruning Constants
    private let maxDaysHistory: TimeInterval = 90
    private let maxGlobalItems: Int = 1000
    private let maxQueryItems: Int = 2000

    private var storeFileURL: URL? {
        let dataDir = NerwPaths.dataDirectory
        NerwPaths.ensureDirectoryExists(at: dataDir)
        return dataDir.appendingPathComponent("frecency.json")
    }

    private var queryStoreFileURL: URL? {
        let dataDir = NerwPaths.dataDirectory
        NerwPaths.ensureDirectoryExists(at: dataDir)
        return dataDir.appendingPathComponent("frecency_query.json")
    }

    private init() {
        loadScores()
        loadQueryScores()

        // Schedule cleanup shortly after startup to avoid blocking critical path
        queue.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            self?.pruneData()
        }
    }

    // MARK: - Public API

    /// Record usage of an item (Global Frecency)
    public func recordUsage(id: String) {
        queue.async(flags: .barrier) {
            var data =
                self.scores[id] ?? FrecencyData(count: 0, lastUsed: Date().timeIntervalSince1970)
            data.count += 1
            data.lastUsed = Date().timeIntervalSince1970
            self.scores[id] = data
            self.scheduleSaveScores()
        }
    }

    /// Record usage with query context (query-aware)
    public func recordUsage(id: String, forQuery query: String) {
        let normalizedQuery = query.lowercased().trimmingCharacters(in: .whitespaces)
        guard !normalizedQuery.isEmpty else {
            recordUsage(id: id)
            return
        }

        let compositeKey = "\(normalizedQuery):\(id)"
        queue.async(flags: .barrier) {
            var data =
                self.queryScores[compositeKey]
                ?? QueryFrecencyData(
                    count: 0, lastUsed: Date().timeIntervalSince1970, query: normalizedQuery)
            data.count += 1
            data.lastUsed = Date().timeIntervalSince1970
            self.queryScores[compositeKey] = data
            self.scheduleQuerySaveScores()
        }
    }

    /// Calculate score based on frequency and recency decay (Global Frecency).
    public func score(for id: String) -> Double {
        return queue.sync {
            guard let data = scores[id] else { return 0.0 }
            return calculateScore(count: data.count, lastUsed: data.lastUsed)
        }
    }

    /// Calculate query-aware score with sensitivity control.
    /// Returns scores ONLY for exact query matches - no prefix matching.
    public func score(for id: String, query: String, sensitivity: FrecencySensitivity) -> Double {
        guard sensitivity != .disabled else { return 0.0 }

        let normalizedQuery = query.lowercased().trimmingCharacters(in: .whitespaces)
        guard !normalizedQuery.isEmpty else { return 0.0 }

        return queue.sync {
            // ONLY exact query match - no prefix matching
            let exactKey = "\(normalizedQuery):\(id)"
            guard let exactData = queryScores[exactKey] else { return 0.0 }

            return calculateScore(count: exactData.count, lastUsed: exactData.lastUsed)
                * sensitivity.multiplier
        }
    }

    /// Calculate a combined score for an item, prioritizing Smart Suggestions (Query-Specific)
    /// but falling back to General Frecency (Global) if no query match exists.
    ///
    /// - Parameters:
    ///   - id: unique identifier of the action
    ///   - query: current search query
    ///   - matchText: text to match against the query (e.g. item title). Required for Global Frecency to apply.
    ///   - querySensitivity: sensitivity for exact query matches (Smart Suggestions)
    ///   - globalSensitivity: sensitivity for global usage (Global Frecency)
    /// - Returns: A unified score. If a Smart Suggestion match exists, it returns a very high score (> 1,000,000).
    public func combinedScore(
        for id: String, query: String, matchText: String?, querySensitivity: FrecencySensitivity,
        globalSensitivity: FrecencySensitivity
    ) -> Double {
        let normalizedQuery = query.lowercased().trimmingCharacters(in: .whitespaces)
        guard !normalizedQuery.isEmpty else { return 0.0 }

        return queue.sync {
            var finalScore: Double = 0.0

            // 1. Smart Suggestion (Query Specific) - HIGHEST PRIORITY
            // Check EXACT query match first
            if querySensitivity != .disabled {
                let exactKey = "\(normalizedQuery):\(id)"
                if let exactData = queryScores[exactKey] {
                    let queryScore =
                        calculateScore(count: exactData.count, lastUsed: exactData.lastUsed)
                        * querySensitivity.multiplier
                    if queryScore > 0 {
                        // Apply massive boost to ensure these always float to top
                        finalScore += 1_000_000.0 + queryScore
                    }
                }
                // TODO: Potential Future Improvement: Check for *contained/prefix* stored queries?
                // User requirement "starts with in stored frecency entry" could apply here too,
                // but checking `exactKey` is the standard "Smart Suggestion" definition.
            }

            // 2. Global Frecency (General Usage) - LOW PRIORITY
            // Applied ONLY if the item title starts with the query.
            if globalSensitivity != .disabled {
                // Check Condition: "if the query is contained and starts with, in the stored frecency entry"
                // Interpreted as: The item (represented by matchText) must start with the query.
                if let text = matchText?.lowercased(), text.hasPrefix(normalizedQuery) {
                    if let globalData = scores[id] {
                        let globalScore =
                            calculateScore(count: globalData.count, lastUsed: globalData.lastUsed)
                            * globalSensitivity.multiplier
                        finalScore += globalScore
                    }
                }
            }

            return finalScore
        }
    }

    /// Returns the ID of the highest scoring iterm for a specific query.
    /// This is used to "suggest previously used bang search".
    public func getTopScoringID(for query: String) -> (id: String, score: Double)? {
        let normalizedQuery = query.lowercased().trimmingCharacters(in: .whitespaces)
        guard !normalizedQuery.isEmpty else { return nil }

        return queue.sync {
            var bestID: String? = nil
            var bestScore: Double = -1.0

            let prefix = "\(normalizedQuery):"

            for (key, data) in queryScores {
                if key.hasPrefix(prefix) {
                    let id = String(key.dropFirst(prefix.count))
                    // Safety: skip empty IDs
                    guard !id.isEmpty else { continue }
                    let score = calculateScore(count: data.count, lastUsed: data.lastUsed)
                    if score > bestScore {
                        bestScore = score
                        bestID = id
                    }
                }
            }

            if let id = bestID, bestScore > 0 {
                return (id, bestScore)
            }
            return nil
        }
    }

    /// Returns the ID of the MOST RECENTLY USED item for a specific query.
    /// This ignores frequency count and only looks at `lastUsed`.
    public func getMostRecentID(for query: String) -> (id: String, timestamp: TimeInterval)? {
        let normalizedQuery = query.lowercased().trimmingCharacters(in: .whitespaces)
        guard !normalizedQuery.isEmpty else { return nil }

        return queue.sync {
            var bestID: String? = nil
            var bestTime: TimeInterval = 0

            let prefix = "\(normalizedQuery):"

            for (key, data) in queryScores {
                if key.hasPrefix(prefix) {
                    let id = String(key.dropFirst(prefix.count))
                    if data.lastUsed > bestTime {
                        bestTime = data.lastUsed
                        bestID = id
                    }
                }
            }

            if let id = bestID, bestTime > 0 {
                return (id, bestTime)
            }
            return nil
        }
    }

    // MARK: - Maintenance

    private func pruneData() {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }

            let now = Date().timeIntervalSince1970
            let expirationTime = now - (self.maxDaysHistory * 24 * 60 * 60)
            var statsChanged = false

            // 1. Prune Global Scores
            let initialScoreCount = self.scores.count

            // Remove old entries
            self.scores = self.scores.filter { $0.value.lastUsed >= expirationTime }

            // Enforce capacity limit (remove least recently used if over limit)
            if self.scores.count > self.maxGlobalItems {
                let sortedKeys = self.scores.keys.sorted {
                    // Sort descending by lastUsed (keep newest)
                    let t1 = self.scores[$0]?.lastUsed ?? 0
                    let t2 = self.scores[$1]?.lastUsed ?? 0
                    return t1 > t2
                }

                // Keep only top N keys
                let keysToKeep = sortedKeys.prefix(self.maxGlobalItems)
                self.scores = self.scores.filter { keysToKeep.contains($0.key) }
            }

            if self.scores.count != initialScoreCount {
                print(
                    "[FrecencyManager] Pruned global scores: \(initialScoreCount) -> \(self.scores.count)"
                )
                self.scheduleSaveScores()
                statsChanged = true
            }

            // 2. Prune Query Scores
            let initialQueryCount = self.queryScores.count

            // Remove old entries
            self.queryScores = self.queryScores.filter { $0.value.lastUsed >= expirationTime }

            // Enforce capacity limit
            if self.queryScores.count > self.maxQueryItems {
                let sortedKeys = self.queryScores.keys.sorted {
                    let t1 = self.queryScores[$0]?.lastUsed ?? 0
                    let t2 = self.queryScores[$1]?.lastUsed ?? 0
                    return t1 > t2
                }

                let keysToKeep = sortedKeys.prefix(self.maxQueryItems)
                self.queryScores = self.queryScores.filter { keysToKeep.contains($0.key) }
            }

            if self.queryScores.count != initialQueryCount {
                print(
                    "[FrecencyManager] Pruned query scores: \(initialQueryCount) -> \(self.queryScores.count)"
                )
                self.scheduleQuerySaveScores()
                statsChanged = true
            }

            if statsChanged {
                print("[FrecencyManager] Cleanup complete.")
            }
        }
    }

    // MARK: - Private Helpers

    private func calculateScore(count: Int, lastUsed: TimeInterval) -> Double {
        let now = Date().timeIntervalSince1970
        let secondsSince = max(0, now - lastUsed)
        let daysSince = secondsSince / 86400.0

        let frequencyScore = Double(count) * 100.0
        let decayFactor = pow(1.2, daysSince)  // Decays by ~20% per day

        return frequencyScore / decayFactor
    }

    // MARK: - Persistence

    private func loadScores() {
        guard let url = storeFileURL else { return }
        guard let data = try? Data(contentsOf: url) else {
            print("[FrecencyManager] Failed to read frecency file")
            return
        }
        guard let json = try? JSONDecoder().decode([String: FrecencyData].self, from: data) else {
            print("[FrecencyManager] Failed to decode frecency data - file may be corrupted")
            return
        }
        scores = json
    }

    private func loadQueryScores() {
        guard let url = queryStoreFileURL else { return }
        guard let data = try? Data(contentsOf: url) else {
            print("[FrecencyManager] Failed to read query frecency file")
            return
        }
        guard let json = try? JSONDecoder().decode([String: QueryFrecencyData].self, from: data)
        else {
            print("[FrecencyManager] Failed to decode query frecency data - file may be corrupted")
            return
        }
        queryScores = json
    }

    private func scheduleSaveScores() {
        saveScoresWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.performSaveScores()
        }
        saveScoresWorkItem = workItem
        queue.asyncAfter(deadline: .now() + saveDebounceInterval, execute: workItem)
    }

    private func scheduleQuerySaveScores() {
        saveQueryScoresWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.performSaveQueryScores()
        }
        saveQueryScoresWorkItem = workItem
        queue.asyncAfter(deadline: .now() + saveDebounceInterval, execute: workItem)
    }

    private func performSaveScores() {
        guard let url = storeFileURL else { return }
        do {
            let data = try JSONEncoder().encode(scores)
            try data.write(to: url, options: .atomic)
        } catch {
            print("[FrecencyManager] Failed to save frecency data: \(error)")
        }
    }

    private func performSaveQueryScores() {
        guard let url = queryStoreFileURL else { return }
        do {
            let data = try JSONEncoder().encode(queryScores)
            try data.write(to: url, options: .atomic)
        } catch {
            print("[FrecencyManager] Failed to save query frecency data: \(error)")
        }
    }
}

private struct FrecencyData: Codable {
    var count: Int
    var lastUsed: TimeInterval
}

private struct QueryFrecencyData: Codable {
    var count: Int
    var lastUsed: TimeInterval
    var query: String
}
