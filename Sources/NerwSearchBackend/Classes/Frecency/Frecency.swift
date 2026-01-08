import Foundation

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

    private var storeFileURL: URL? {
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let nerwDir = appSupport.appendingPathComponent("Nerw")
        try? fileManager.createDirectory(at: nerwDir, withIntermediateDirectories: true, attributes: nil)
        return nerwDir.appendingPathComponent("frecency.json")
    }
    
    private var queryStoreFileURL: URL? {
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let nerwDir = appSupport.appendingPathComponent("Nerw")
        return nerwDir.appendingPathComponent("frecency_query.json")
    }

    private init() {
        loadScores()
        loadQueryScores()
    }

    // MARK: - Public API

    /// Record usage of an item (legacy, query-agnostic)
    public func recordUsage(id: String) {
        queue.async(flags: .barrier) {
            var data = self.scores[id] ?? FrecencyData(count: 0, lastUsed: Date().timeIntervalSince1970)
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
            var data = self.queryScores[compositeKey] ?? QueryFrecencyData(count: 0, lastUsed: Date().timeIntervalSince1970, query: normalizedQuery)
            data.count += 1
            data.lastUsed = Date().timeIntervalSince1970
            self.queryScores[compositeKey] = data
            self.scheduleQuerySaveScores()
        }
    }

    /// Calculate score based on frequency and recency decay (legacy).
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
            
            return calculateScore(count: exactData.count, lastUsed: exactData.lastUsed) * sensitivity.multiplier
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
    public func combinedScore(for id: String, query: String, matchText: String?, querySensitivity: FrecencySensitivity, globalSensitivity: FrecencySensitivity) -> Double {
        let normalizedQuery = query.lowercased().trimmingCharacters(in: .whitespaces)
        guard !normalizedQuery.isEmpty else { return 0.0 }
        
        return queue.sync {
            var finalScore: Double = 0.0
            
            // 1. Smart Suggestion (Query Specific) - HIGHEST PRIORITY
            // Check EXACT query match first
            if querySensitivity != .disabled {
                let exactKey = "\(normalizedQuery):\(id)"
                if let exactData = queryScores[exactKey] {
                    let queryScore = calculateScore(count: exactData.count, lastUsed: exactData.lastUsed) * querySensitivity.multiplier
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
                        let globalScore = calculateScore(count: globalData.count, lastUsed: globalData.lastUsed) * globalSensitivity.multiplier
                        finalScore += globalScore
                    }
                }
            }
            
            return finalScore
        }
    }
    
    // MARK: - Private Helpers
    
    private func calculateScore(count: Int, lastUsed: TimeInterval) -> Double {
        let now = Date().timeIntervalSince1970
        let secondsSince = max(0, now - lastUsed)
        let daysSince = secondsSince / 86400.0
        
        let frequencyScore = Double(count) * 100.0
        let decayFactor = pow(1.2, daysSince) // Decays by ~20% per day
        
        return frequencyScore / decayFactor
    }

    // MARK: - Persistence

    private func loadScores() {
        guard let url = storeFileURL,
              let data = try? Data(contentsOf: url),
              let json = try? JSONDecoder().decode([String: FrecencyData].self, from: data) else {
            return
        }
        scores = json
    }
    
    private func loadQueryScores() {
        guard let url = queryStoreFileURL,
              let data = try? Data(contentsOf: url),
              let json = try? JSONDecoder().decode([String: QueryFrecencyData].self, from: data) else {
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

fileprivate struct FrecencyData: Codable {
    var count: Int
    var lastUsed: TimeInterval
}

fileprivate struct QueryFrecencyData: Codable {
    var count: Int
    var lastUsed: TimeInterval
    var query: String
}
