import Cocoa
import NerwUtils

public class IconManager {
    public static let shared = IconManager()

    private let iconDirectory: URL
    private let fileManager = FileManager.default
    private let memoryCache: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = 64
        cache.totalCostLimit = 16 * 1024 * 1024
        return cache
    }()

    private init() {
        self.iconDirectory = NerwPaths.iconsDirectory

        try? fileManager.createDirectory(
            at: iconDirectory, withIntermediateDirectories: true, attributes: nil)
    }

    public func icon(for urlOrDomain: String) -> NSImage? {
        guard let domain = extractDomain(from: urlOrDomain) else { return nil }

        if let image = memoryCache.object(forKey: domain as NSString) {
            return image
        }

        let fileURL = iconDirectory.appendingPathComponent("\(domain).png")
        if fileManager.fileExists(atPath: fileURL.path),
            let image = NSImage(contentsOf: fileURL)
        {
            memoryCache.setObject(image, forKey: domain as NSString, cost: cacheCost(for: image))
            return image
        }

        return nil
    }

    /// Looks up an icon by its raw storage key (filename without extension),
    /// bypassing domain extraction. Use this for custom user-provided icons.
    public func icon(forKey key: String) -> NSImage? {
        if let image = memoryCache.object(forKey: key as NSString) { return image }

        let fileURL = iconDirectory.appendingPathComponent("\(key).png")
        if fileManager.fileExists(atPath: fileURL.path),
            let image = NSImage(contentsOf: fileURL)
        {
            memoryCache.setObject(image, forKey: key as NSString, cost: cacheCost(for: image))
            return image
        }
        return nil
    }

    public func fetchIcon(for urlOrDomain: String, completion: @escaping (NSImage?) -> Void) {
        guard let domain = extractDomain(from: urlOrDomain) else {
            completion(nil)
            return
        }

        // Return immediately if cached
        if let cached = icon(for: domain) {
            completion(cached)
            return
        }

        // Download
        // Use Google's service for high-res PNGs (sz=128)
        let iconURLString = "https://icons.duckduckgo.com/ip3/\(domain).ico"
        guard let iconURL = URL(string: iconURLString) else {
            completion(nil)
            return
        }

        URLSession.shared.dataTask(with: iconURL) { [weak self] data, response, error in
            guard let self = self, let data = data, let image = NSImage(data: data) else {
                completion(nil)
                return
            }

            // Save to Disk
            let fileURL = self.iconDirectory.appendingPathComponent("\(domain).png")
            if let tiffData = image.tiffRepresentation,
                let bitmap = NSBitmapImageRep(data: tiffData),
                let pngData = bitmap.representation(using: .png, properties: [:])
            {
                try? pngData.write(to: fileURL)
            }

            self.memoryCache.setObject(
                image, forKey: domain as NSString, cost: self.cacheCost(for: image))

            completion(image)
        }.resume()
    }

    /// Saves a custom user-provided image to disk under a given key (used for custom engine icons).
    /// Returns the key that should be stored in `Engine.icon`.
    @discardableResult
    public func saveCustomIcon(image: NSImage, key: String) -> String {
        let safeKey = key.replacingOccurrences(of: " ", with: "_").lowercased()

        // Ensure directory exists (createDirectory is idempotent)
        try? fileManager.createDirectory(
            at: iconDirectory, withIntermediateDirectories: true, attributes: nil)

        let fileURL = iconDirectory.appendingPathComponent("\(safeKey).png")

        // Resize to 128×128 before saving
        let targetSize = NSSize(width: 128, height: 128)
        let resized = NSImage(size: targetSize)
        resized.lockFocus()
        image.draw(
            in: NSRect(origin: .zero, size: targetSize),
            from: .zero, operation: .sourceOver, fraction: 1.0)
        resized.unlockFocus()

        // Write PNG atomically
        if let tiffData = resized.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiffData),
            let pngData = bitmap.representation(using: .png, properties: [:])
        {
            do {
                try pngData.write(to: fileURL, options: .atomic)
                print("Nerw: Saved custom icon → \(fileURL.path)")
            } catch {
                print("Nerw: Failed to save custom icon: \(error)")
            }
        }

        memoryCache.setObject(resized, forKey: safeKey as NSString, cost: cacheCost(for: resized))
        return safeKey
    }

    public func fetchFavicon(for url: URL) async -> NSImage? {
        var fallbackURL: URL?
        if let scheme = url.scheme, let host = url.host {
            fallbackURL = URL(string: "\(scheme)://\(host)/favicon.ico")
        }

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 5.0

            let (asyncBytes, response) = try await URLSession.shared.bytes(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                var data = Data()
                let maxBytes = 65536  // 64KB

                for try await byte in asyncBytes {
                    data.append(byte)
                    if data.count >= maxBytes {
                        break
                    }
                }

                if let html = String(data: data, encoding: .utf8)
                    ?? String(data: data, encoding: .ascii)
                {
                    let pattern =
                        "<link[^>]*rel=[\"']?(?:shortcut icon|icon|apple-touch-icon)[\"']?[^>]*href=[\"']?([^\"'>\\s]+)[\"']?"
                    if let regex = try? NSRegularExpression(
                        pattern: pattern, options: [.caseInsensitive]),
                        let match = regex.firstMatch(
                            in: html, options: [],
                            range: NSRange(location: 0, length: html.utf16.count)
                        )
                    {
                        if let hrefRange = Range(match.range(at: 1), in: html) {
                            let href = String(html[hrefRange])
                            if let iconURL = URL(string: href, relativeTo: url) {
                                if let image = await downloadImage(from: iconURL) {
                                    return image
                                }
                            }
                        }
                    }
                }
            }
        } catch {
            print("[IconManager] Error fetching HTML for favicon: \(error)")
        }

        // Try fallback
        if let fallback = fallbackURL, let image = await downloadImage(from: fallback) {
            return image
        }

        // Try DuckDuckGo
        if let domain = url.host,
            let duckURL = URL(string: "https://icons.duckduckgo.com/ip3/\(domain).ico")
        {
            if let image = await downloadImage(from: duckURL) {
                return image
            }
        }

        return nil
    }

    private func downloadImage(from url: URL) async -> NSImage? {
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 5.0
            let (data, _) = try await URLSession.shared.data(for: request)
            return NSImage(data: data)
        } catch {
            print("[IconManager] Failed to download image from \(url): \(error)")
            return nil
        }
    }

    public func clearMemoryCache() {
        memoryCache.removeAllObjects()
    }

    private func extractDomain(from urlString: String) -> String? {
        // If it's already a domain-like string
        if !urlString.contains("://") {
            return urlString.components(separatedBy: "/").first
        }

        if let url = URL(string: urlString) {
            return url.host
        }
        return nil
    }

    private func cacheCost(for image: NSImage) -> Int {
        let size = image.size
        let width = max(Int(size.width), 1)
        let height = max(Int(size.height), 1)
        return width * height * 4
    }
}
