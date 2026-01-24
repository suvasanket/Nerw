import Foundation

public class CacheManager {
    public static let shared = CacheManager()

    private let fileManager = FileManager.default
    private let queue = DispatchQueue(label: "com.nerw.cache", attributes: .concurrent)
    private var cache: [String: Any] = [:]

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

    public func set(_ value: Any, forKey key: String) {
        queue.async(flags: .barrier) {
            self.cache[key] = value
            self.saveCache()
        }
    }

    public func get(forKey key: String) -> Any? {
        queue.sync {
            return cache[key]
        }
    }

    public func remove(forKey key: String) {
        queue.async(flags: .barrier) {
            self.cache.removeValue(forKey: key)
            self.saveCache()
        }
    }

    public func clear() {
        queue.async(flags: .barrier) {
            self.cache.removeAll()
            self.saveCache()
        }
    }

    // MARK: - Persistence

    private func loadCache() {
        guard let url = cacheFileURL,
            let data = try? Data(contentsOf: url),
            let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        else {
            return
        }
        cache = json
    }

    private func saveCache() {
        guard let url = cacheFileURL else { return }
        // JSONSerialization requires valid JSON types (NSString, NSNumber, NSArray, NSDictionary, or NSNull)
        // We assume 'value' passed to 'set' complies with this.

        do {
            let data = try JSONSerialization.data(
                withJSONObject: cache, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: url)
        } catch {
            print("[CacheManager] Failed to save cache: \(error)")
        }
    }
}
