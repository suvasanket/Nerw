import Foundation

public final class CacheManager {
    public static let shared = CacheManager()

    private let fileManager = FileManager.default
    private let queue = DispatchQueue(label: "com.nerw.cache", attributes: .concurrent)
    private var cache: CacheData = CacheData()

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
        return nerwDir.appendingPathComponent("cache.json")
    }

    private init() {
        loadCache()
    }

    // MARK: - Public API

    public func set<T: Codable>(_ value: T, forKey key: String) {
        queue.async(flags: .barrier) {
            self.cache.storage[key] = CachedValue(value)
            self.saveCache()
        }
    }

    public func get<T: Codable>(forKey key: String, as type: T.Type) -> T? {
        queue.sync {
            guard let cached = cache.storage[key] else {
                return nil
            }
            return cached.getValue(as: type)
        }
    }

    public func remove(forKey key: String) {
        queue.async(flags: .barrier) {
            self.cache.storage.removeValue(forKey: key)
            self.saveCache()
        }
    }

    public func clear() {
        queue.async(flags: .barrier) {
            self.cache.storage.removeAll()
            self.saveCache()
        }
    }

    // MARK: - Persistence

    private func loadCache() {
        guard let url = cacheFileURL,
            let data = try? Data(contentsOf: url),
            let json = try? JSONDecoder().decode(CacheData.self, from: data)
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
            print("[CacheManager] Failed to save cache: \(error)")
        }
    }
}

// MARK: - Codable Types

private struct CacheData: Codable {
    var storage: [String: CachedValue] = [:]
}

private struct CachedValue: Codable {
    let data: Data

    init(_ value: some Codable) {
        self.data = (try? JSONEncoder().encode(value)) ?? Data()
    }

    func getValue<T: Codable>(as type: T.Type) -> T? {
        return try? JSONDecoder().decode(type, from: data)
    }
}
