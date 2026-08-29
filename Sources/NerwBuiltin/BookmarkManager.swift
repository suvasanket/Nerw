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
    public private(set) var bookmarks: [Bookmark] = []

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
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: Notification.Name("NerwHubDataDidUpdate"), object: nil)
            }
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
                if let image = await IconManager.shared.fetchFavicon(for: urlObj) {
                    if let tiff = image.tiffRepresentation,
                        let bitmap = NSBitmapImageRep(data: tiff),
                        let pngData = bitmap.representation(using: .png, properties: [:])
                    {
                        do {
                            try pngData.write(to: faviconPath)
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
                        } catch {
                            print("[BookmarkManager] Failed to save favicon image: \(error)")
                        }
                    }
                }
            }
        }
    }

    public func updateBookmark(id: UUID, url: String, title: String) {
        guard let index = bookmarks.firstIndex(where: { $0.id == id }) else { return }
        let existing = bookmarks[index]
        let urlChanged = (existing.url != url)

        let updated = Bookmark(
            id: id,
            url: url,
            title: title,
            faviconPath: urlChanged ? nil : existing.faviconPath,
            createdAt: existing.createdAt
        )
        bookmarks[index] = updated
        saveBookmarks()

        NotificationCenter.default.post(name: Notification.Name("NerwConfigDidUpdate"), object: nil)
        Nerw.notify("Bookmark Updated: \(title)")

        if urlChanged, let urlObj = URL(string: url) {
            let faviconPath = iconsDirectoryURL.appendingPathComponent("\(id.uuidString).png")
            Task {
                if let image = await IconManager.shared.fetchFavicon(for: urlObj) {
                    if let tiff = image.tiffRepresentation,
                        let bitmap = NSBitmapImageRep(data: tiff),
                        let pngData = bitmap.representation(using: .png, properties: [:])
                    {
                        do {
                            try pngData.write(to: faviconPath)
                            DispatchQueue.main.async {
                                if let idx = self.bookmarks.firstIndex(where: { $0.id == id }) {
                                    self.bookmarks[idx] = Bookmark(
                                        id: id, url: url, title: title,
                                        faviconPath: faviconPath.path,
                                        createdAt: updated.createdAt)
                                    self.saveBookmarks()
                                    NotificationCenter.default.post(
                                        name: Notification.Name("NerwConfigDidUpdate"),
                                        object: nil)
                                }
                            }
                        } catch {
                            print("[BookmarkManager] Failed to save favicon image: \(error)")
                        }
                    }
                }
            }
        }
    }

    public func deleteBookmark(id: UUID) {
        if let index = bookmarks.firstIndex(where: { $0.id == id }) {
            let bookmark = bookmarks[index]
            if let iconPath = bookmark.faviconPath {
                try? FileManager.default.removeItem(atPath: iconPath)
            }
            bookmarks.remove(at: index)
            saveBookmarks()
            NerwActionPreferenceManager.shared.removePreferences(
                for: "builtin.bookmark.\(id.uuidString)")
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
                                    BookmarkManager.shared.updateBookmark(
                                        id: bookmark.id, url: urlStr, title: title)
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
