import Foundation

public class FrecencyManager {
    public static let shared = FrecencyManager()
    public static var enabled: Bool = false // Feature toggle

    private let fileManager = FileManager.default
    private let queue = DispatchQueue(label: "com.nerw.frecency", attributes: .concurrent)

    // Key: Item ID, Value: Score Data
    private var scores: [String: FrecencyData] = [:]

    private var storeFileURL: URL? {
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let nerwDir = appSupport.appendingPathComponent("Nerw")
        try? fileManager.createDirectory(at: nerwDir, withIntermediateDirectories: true, attributes: nil)
        return nerwDir.appendingPathComponent("frecency.json")
    }

    private init() {
        loadScores()
    }

    // MARK: - Public API

    public func recordUsage(id: String) {
        queue.async(flags: .barrier) {
            var data = self.scores[id] ?? FrecencyData(count: 0, lastUsed: Date().timeIntervalSince1970)
            data.count += 1
            data.lastUsed = Date().timeIntervalSince1970
            self.scores[id] = data
            self.saveScores()
        }
    }

    /// Calculate score based on frequency and recency decay.
    /// Algorithm: Score = (Count * 100) / (DecayFactor ^ DaysSinceLastUse)
    /// DecayFactor = 2.0 (Double score halves every day)
    public func score(for id: String) -> Double {
        queue.sync {
            guard let data = scores[id] else { return 0.0 }

            let now = Date().timeIntervalSince1970
            let secondsSince = max(0, now - data.lastUsed)
            let daysSince = secondsSince / 86400.0

            let frequencyScore = Double(data.count) * 100.0
            // Decay: score halves every 7 days? Let's try 2.0 ^ days
            // If used today: 100 * count / 1 = 100 * count.
            // If used yesterday: 100 * count / 2.
            // Let's use a milder decay: 1.1 ^ days
            let decayFactor = pow(1.2, daysSince) // Decays by ~20% per day

            return frequencyScore / decayFactor
        }
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

    private func saveScores() {
        guard let url = storeFileURL else { return }
        do {
            let data = try JSONEncoder().encode(scores)
            try data.write(to: url)
        } catch {
            print("[FrecencyManager] Failed to save frecency data: \(error)")
        }
    }
}

fileprivate struct FrecencyData: Codable {
    var count: Int
    var lastUsed: TimeInterval
}
