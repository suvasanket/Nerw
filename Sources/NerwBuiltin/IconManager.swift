import Cocoa

public class IconManager {
    public static let shared = IconManager()

    private let iconDirectory: URL
    private let fileManager = FileManager.default
    private let queue = DispatchQueue(label: "com.nerw.iconmanager", attributes: .concurrent)

    // Memory Cache
    private var memoryCache: [String: NSImage] = [:]

    private init() {
        let home = fileManager.homeDirectoryForCurrentUser
        self.iconDirectory = home.appendingPathComponent(".config/nerw/icons")

        try? fileManager.createDirectory(at: iconDirectory, withIntermediateDirectories: true, attributes: nil)
    }

    public func icon(for urlOrDomain: String) -> NSImage? {
        guard let domain = extractDomain(from: urlOrDomain) else { return nil }

        // Check Memory
        if let cached = memoryCache[domain] {
            return cached
        }

        // Check Disk
        let fileURL = iconDirectory.appendingPathComponent("\(domain).png")
        if fileManager.fileExists(atPath: fileURL.path),
           let image = NSImage(contentsOf: fileURL) {
            memoryCache[domain] = image
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
        let iconURLString = "https://www.google.com/s2/favicons?domain=\(domain)&sz=128"
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
               let pngData = bitmap.representation(using: .png, properties: [:]) {
                try? pngData.write(to: fileURL)
            }

            // Save to Memory
            self.queue.async(flags: .barrier) {
                self.memoryCache[domain] = image
            }

            completion(image)
        }.resume()
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
