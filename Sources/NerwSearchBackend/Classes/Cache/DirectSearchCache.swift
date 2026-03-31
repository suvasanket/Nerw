import Foundation

public struct DirectSearchEntry: Codable {
    public var url: String
    public var count: Int
    public var lastUsed: TimeInterval

    public init(url: String, count: Int = 1, lastUsed: TimeInterval = Date().timeIntervalSince1970)
    {
        self.url = url
        self.count = count
        self.lastUsed = lastUsed
    }
}

public class DirectSearchCache {
    public static let shared = DirectSearchCache()

    private let fileManager = FileManager.default
    private let queue = DispatchQueue(label: "com.nerw.directsearchcache", attributes: .concurrent)
    private var cache: [String: DirectSearchEntry] = [:]
    private let maxEntries = 500

    private var cacheFileURL: URL? {
        guard
            let appSupport = fileManager.urls(
                for: .applicationSupportDirectory, in: .userDomainMask
            )
            .first
        else {
            return nil
        }
        let nerwDir = appSupport.appendingPathComponent("Nerw")
        try? fileManager.createDirectory(
            at: nerwDir, withIntermediateDirectories: true, attributes: nil)
        return nerwDir.appendingPathComponent("direct_search_cache.json")
    }

    private init() {
        loadCache()
    }

    // MARK: - Public API

    public func get(for query: String) -> String? {
        let normalizedQuery = query.lowercased().trimmingCharacters(in: .whitespaces)
        return queue.sync {
            guard var entry = cache[normalizedQuery] else { return nil }

            // Increment count on hit
            entry.count += 1
            entry.lastUsed = Date().timeIntervalSince1970

            // Update cache asynchronously
            queue.async(flags: .barrier) {
                self.cache[normalizedQuery] = entry
                self.saveCache()
            }

            return entry.url
        }
    }

    public func set(url: String, for query: String) {
        let normalizedQuery = query.lowercased().trimmingCharacters(in: .whitespaces)
        queue.async(flags: .barrier) {
            if var entry = self.cache[normalizedQuery] {
                entry.url = url
                entry.count += 1
                entry.lastUsed = Date().timeIntervalSince1970
                self.cache[normalizedQuery] = entry
            } else {
                // New entry
                if self.cache.count >= self.maxEntries {
                    self.pruneCache()
                }
                self.cache[normalizedQuery] = DirectSearchEntry(url: url)
            }
            self.saveCache()
        }
    }

    // MARK: - Private Helpers

    private func pruneCache() {
        // Remove entries with the least counts
        let sortedKeys = cache.keys.sorted {
            let c1 = cache[$0]?.count ?? 0
            let c2 = cache[$1]?.count ?? 0
            if c1 == c2 {
                // If counts are equal, remove older one
                return (cache[$0]?.lastUsed ?? 0) > (cache[$1]?.lastUsed ?? 0)
            }
            return c1 > c2
        }

        // Keep top 80% (remove bottom 20%)
        let keepCount = Int(Double(maxEntries) * 0.8)
        let keysToKeep = Set(sortedKeys.prefix(keepCount))

        cache = cache.filter { keysToKeep.contains($0.key) }
    }

    private func loadCache() {
        guard let url = cacheFileURL,
            let data = try? Data(contentsOf: url),
            let json = try? JSONDecoder().decode([String: DirectSearchEntry].self, from: data)
        else {
            return
        }
        cache = json
    }

    private func saveCache() {
        guard let url = cacheFileURL else { return }
        do {
            let data = try JSONEncoder().encode(cache)
            try data.write(to: url, options: .atomic)
        } catch {
            print("[DirectSearchCache] Failed to save cache: \(error)")
        }
    }
}
