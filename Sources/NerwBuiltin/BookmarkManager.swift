import Cocoa
import Foundation
import NerwAction
import NerwCore
import NerwUtils

public struct Bookmark: Codable {
    public let id: UUID
    public let url: String
    public let title: String
    public let faviconPath: String?
    public let createdAt: Date
}

public class BookmarkManager {
    public static let shared = BookmarkManager()

    private let bookmarksFileURL: URL
    private let iconsDirectoryURL: URL
    private var bookmarks: [Bookmark] = []

    private init() {
        let dataDir = NerwPaths.dataDirectory
        bookmarksFileURL = dataDir.appendingPathComponent("bookmarks.json")
        iconsDirectoryURL = dataDir.appendingPathComponent("BookmarkIcons")

        try? FileManager.default.createDirectory(
            at: dataDir, withIntermediateDirectories: true, attributes: nil)
        try? FileManager.default.createDirectory(
            at: iconsDirectoryURL, withIntermediateDirectories: true, attributes: nil)

        loadBookmarks()
    }

    private func loadBookmarks() {
        do {
            if FileManager.default.fileExists(atPath: bookmarksFileURL.path) {
                let data = try Data(contentsOf: bookmarksFileURL)
                bookmarks = try JSONDecoder().decode([Bookmark].self, from: data)
            }
        } catch {
            print("[BookmarkManager] Failed to load bookmarks: \(error)")
        }
    }

    private func saveBookmarks() {
        do {
            let data = try JSONEncoder().encode(bookmarks)
            try data.write(to: bookmarksFileURL, options: .atomic)
        } catch {
            print("[BookmarkManager] Failed to save bookmarks: \(error)")
        }
    }

    public func addBookmark(url: String, title: String) {
        let id = UUID()
        let faviconPath = iconsDirectoryURL.appendingPathComponent("\(id.uuidString).png")

        let bookmark = Bookmark(
            id: id, url: url, title: title, faviconPath: nil, createdAt: Date())
        bookmarks.append(bookmark)
        saveBookmarks()

        // Tell UI it changed so search cache can rebuild
        NotificationCenter.default.post(name: Notification.Name("NerwConfigDidUpdate"), object: nil)
        Nerw.notify("Bookmark Added: \(title)")

        // Fetch favicon asynchronously
        if let urlObj = URL(string: url) {
            Task {
                if let iconURL = await fetchFaviconURL(for: urlObj) {
                    let success = await downloadAndSaveFavicon(
                        iconURL: iconURL, destPath: faviconPath)
                    if success {
                        // Update bookmark
                        DispatchQueue.main.async {
                            if let index = self.bookmarks.firstIndex(where: { $0.id == id }) {
                                self.bookmarks[index] = Bookmark(
                                    id: id, url: url, title: title,
                                    faviconPath: faviconPath.path,
                                    createdAt: bookmark.createdAt)
                                self.saveBookmarks()
                                NotificationCenter.default.post(
                                    name: Notification.Name("NerwConfigDidUpdate"),
                                    object: nil)
                            }
                        }
                    }
                }
            }
        }
    }

    private func fetchFaviconURL(for url: URL) async -> URL? {
        var fallbackURL: URL?
        if let scheme = url.scheme, let host = url.host {
            fallbackURL = URL(string: "\(scheme)://\(host)/favicon.ico")
        }

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 5.0

            let (asyncBytes, response) = try await URLSession.shared.bytes(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200
            else {
                return fallbackURL
            }

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
                        in: html, options: [], range: NSRange(location: 0, length: html.utf16.count)
                    )
                {

                    if let hrefRange = Range(match.range(at: 1), in: html) {
                        let href = String(html[hrefRange])
                        if let iconURL = URL(string: href, relativeTo: url) {
                            return iconURL
                        }
                    }
                }
            }
        } catch {
            print("[BookmarkManager] Error fetching HTML for favicon: \(error)")
        }

        return fallbackURL
    }

    private func downloadAndSaveFavicon(iconURL: URL, destPath: URL) async -> Bool {
        do {
            var request = URLRequest(url: iconURL)
            request.timeoutInterval = 5.0
            let (data, _) = try await URLSession.shared.data(for: request)

            if let image = NSImage(data: data),
                let tiff = image.tiffRepresentation,
                let bitmap = NSBitmapImageRep(data: tiff),
                let pngData = bitmap.representation(using: .png, properties: [:])
            {
                try pngData.write(to: destPath)
                return true
            }
        } catch {
            print("[BookmarkManager] Failed to download favicon image: \(error)")
        }
        return false
    }

    public func deleteBookmark(id: UUID) {
        if let index = bookmarks.firstIndex(where: { $0.id == id }) {
            let bookmark = bookmarks[index]
            if let iconPath = bookmark.faviconPath {
                try? FileManager.default.removeItem(atPath: iconPath)
            }
            bookmarks.remove(at: index)
            saveBookmarks()
            NotificationCenter.default.post(
                name: Notification.Name("NerwConfigDidUpdate"), object: nil)
        }
    }

    public static func builtinActions() -> [NerwAction] {
        var actions: [NerwAction] = []

        let addAction = NerwAction(
            id: "builtin.bookmark.add",
            title: "Add Bookmark",
            subtitle: "Save a website to your bookmarks",
            icon: .system("bookmark.circle.fill"),
            category: .webSearch,
            triggers: ["add bookmark", "bookmark"],
            type: .form(
                fields: {
                    let info = BrowserURLFetcher.shared.getBrowserInfo()
                    return [
                        .init(
                            id: "url", title: "URL", placeholder: "https://example.com",
                            defaultValue: info?.url ?? "",
                            isFocused: false
                        ),
                        .init(
                            id: "title", title: "Name", placeholder: "Example Website",
                            defaultValue: info?.title ?? "",
                            isFocused: true
                        ),
                    ]
                },
                submitLabel: "Add Bookmark",
                perform: { _, values in
                    let urlStr = values["url"]?.trimmingCharacters(in: .whitespaces) ?? ""
                    let title = values["title"]?.trimmingCharacters(in: .whitespaces) ?? ""

                    if !urlStr.isEmpty && !title.isEmpty {
                        BookmarkManager.shared.addBookmark(url: urlStr, title: title)
                    } else {
                        Nerw.notify("Please enter a valid URL and Name", level: .warn)
                    }
                }
            )
        )
        actions.append(addAction)

        for bookmark in BookmarkManager.shared.bookmarks {
            var mainImage: NSImage?
            var isTemplate = true

            if let path = bookmark.faviconPath, FileManager.default.fileExists(atPath: path),
                let image = NSImage(contentsOfFile: path)
            {
                mainImage = image
                isTemplate = false
            } else {
                var symbol = "bookmark.circle.fill"
                if let firstChar = bookmark.title.first(where: { $0.isLetter || $0.isNumber }) {
                    symbol = "\(firstChar.lowercased()).circle.fill"
                }
                mainImage = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
            }

            var icon: NerwAction.IconType = .system("bookmark.circle.fill")
            if let mainImg = mainImage,
                let subImgBase = NSImage(
                    systemSymbolName: "bookmark.fill", accessibilityDescription: nil)
            {
                let config = NSImage.SymbolConfiguration(paletteColors: [.white])
                let subImg = subImgBase.withSymbolConfiguration(config) ?? subImgBase

                let combined = IconUtils.combinedIcon(
                    mainImage: mainImg,
                    subImage: subImg,
                    subIconScale: 0.45,
                    isTemplate: isTemplate
                )
                icon = .image(combined)
            } else if let mainImg = mainImage {
                icon = .image(mainImg)
            }

            let customContextOperations: [NerwActionContext.Operation] = [
                .init(
                    id: "edit",
                    kind: .custom("edit"),
                    title: "Edit Bookmark",
                    subtitle: "Modify URL or Name",
                    icon: .system("pencil"),
                    interaction: .execute
                ),
                .init(
                    id: "delete",
                    kind: .custom("delete"),
                    title: "Delete Bookmark",
                    subtitle: "Remove from bookmarks",
                    icon: .system("trash"),
                    interaction: .execute
                ),
            ]

            let performCustomContextOperation: ((NerwAction, String) -> NerwAction?) = {
                action, key in
                if key == "delete" {
                    BookmarkManager.shared.deleteBookmark(id: bookmark.id)
                    return nil
                } else if key == "edit" {
                    return NerwAction(
                        id: "builtin.bookmark.edit.\(bookmark.id.uuidString)",
                        title: "Edit Bookmark",
                        subtitle: "Modify details for \(bookmark.title)",
                        type: .form(
                            fields: {
                                return [
                                    .init(
                                        id: "url", title: "URL", placeholder: "https://example.com",
                                        defaultValue: bookmark.url,
                                        isFocused: false
                                    ),
                                    .init(
                                        id: "title", title: "Name", placeholder: "Example Website",
                                        defaultValue: bookmark.title,
                                        isFocused: true
                                    ),
                                ]
                            },
                            submitLabel: "Save Bookmark",
                            perform: { _, values in
                                let urlStr =
                                    values["url"]?.trimmingCharacters(in: .whitespaces) ?? ""
                                let title =
                                    values["title"]?.trimmingCharacters(in: .whitespaces) ?? ""

                                if !urlStr.isEmpty && !title.isEmpty {
                                    BookmarkManager.shared.deleteBookmark(id: bookmark.id)
                                    BookmarkManager.shared.addBookmark(url: urlStr, title: title)
                                } else {
                                    Nerw.notify("Please enter a valid URL and Name", level: .warn)
                                }
                            }
                        )
                    )
                }
                return nil
            }

            let action = NerwAction(
                id: "builtin.bookmark.\(bookmark.id.uuidString)",
                title: bookmark.title,
                subtitle: bookmark.url,
                icon: icon,
                triggers: [],
                type: .instant(perform: { _ in
                    if let url = URL(string: bookmark.url) {
                        NSWorkspace.shared.open(url)
                    }
                }),
                customContextOperations: customContextOperations,
                performCustomContextOperation: performCustomContextOperation
            )
            actions.append(action)
        }

        return actions
    }
}
