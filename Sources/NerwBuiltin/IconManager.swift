import Cocoa

public class IconManager {
    public static let shared = IconManager()

    private let iconDirectory: URL
    private let fileManager = FileManager.default
    private let queue = DispatchQueue(label: "com.nerw.iconmanager", attributes: .concurrent)

    // Memory Cache
    private var memoryCache: [String: NSImage] = [:]

    private init() {
        if let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first
        {
            self.iconDirectory = appSupport.appendingPathComponent("Nerw/Icons")
        } else {
            // Fallback to old path if AppSupport not found (unlikely)
            let home = fileManager.homeDirectoryForCurrentUser
            self.iconDirectory = home.appendingPathComponent(".Nerw/icons")
        }

        try? fileManager.createDirectory(
            at: iconDirectory, withIntermediateDirectories: true, attributes: nil)
    }

    public func icon(for urlOrDomain: String) -> NSImage? {
        guard let domain = extractDomain(from: urlOrDomain) else { return nil }

        // Check Memory (Thread-Safe Read)
        var cached: NSImage?
        queue.sync {
            cached = memoryCache[domain]
        }
        if let image = cached {
            return image
        }

        // Check Disk
        let fileURL = iconDirectory.appendingPathComponent("\(domain).png")
        if fileManager.fileExists(atPath: fileURL.path),
            let image = NSImage(contentsOf: fileURL)
        {
            // Update Memory (Thread-Safe Write)
            queue.async(flags: .barrier) {
                self.memoryCache[domain] = image
            }
            return image
        }

        return nil
    }

    /// Looks up an icon by its raw storage key (filename without extension),
    /// bypassing domain extraction. Use this for custom user-provided icons.
    public func icon(forKey key: String) -> NSImage? {
        // Check Memory
        var cached: NSImage?
        queue.sync {
            cached = memoryCache[key]
        }
        if let image = cached { return image }

        // Check Disk
        let fileURL = iconDirectory.appendingPathComponent("\(key).png")
        if fileManager.fileExists(atPath: fileURL.path),
            let image = NSImage(contentsOf: fileURL)
        {
            queue.async(flags: .barrier) {
                self.memoryCache[key] = image
            }
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

            // Save to Memory
            self.queue.async(flags: .barrier) {
                self.memoryCache[domain] = image
            }

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

        // Update memory cache synchronously so callers see it immediately (no race)
        queue.sync(flags: .barrier) {
            self.memoryCache[safeKey] = resized
        }
        return safeKey
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
}
