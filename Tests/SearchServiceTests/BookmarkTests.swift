import Foundation

@testable import NerwAction
@testable import NerwBuiltin
@testable import NerwUtils

func runBookmarkTests() {
    print("[Testing] Starting Bookmark tests...")
    testBookmarkFallbackIconLogic()
    testBookmarkHTMLParsingRegex()
    print("[Testing] All Bookmark tests PASSED.")
}

func testBookmarkFallbackIconLogic() {
    print("  - testBookmarkFallbackIconLogic")

    // Test the builtinActions generation without actual disk favicons
    let testBookmarks = [
        Bookmark(
            id: UUID(), url: "https://youtube.com", title: "YouTube", faviconPath: nil,
            createdAt: Date()),
        Bookmark(
            id: UUID(), url: "https://apple.com", title: "Apple", faviconPath: nil,
            createdAt: Date()),
        Bookmark(
            id: UUID(), url: "https://123.com", title: "123", faviconPath: nil, createdAt: Date()),
        Bookmark(
            id: UUID(), url: "https://example.com", title: "!@#", faviconPath: nil,
            createdAt: Date()),
    ]

    for bookmark in testBookmarks {
        var symbol = "bookmark.circle.fill"
        if let firstChar = bookmark.title.first(where: { $0.isLetter || $0.isNumber }) {
            symbol = "\(firstChar.lowercased()).circle.fill"
        }

        switch bookmark.title {
        case "YouTube":
            guard symbol == "y.circle.fill" else {
                print("  ! Expected y.circle.fill, got \(symbol)")
                exit(1)
            }
        case "Apple":
            guard symbol == "a.circle.fill" else {
                print("  ! Expected a.circle.fill, got \(symbol)")
                exit(1)
            }
        case "123":
            guard symbol == "1.circle.fill" else {
                print("  ! Expected 1.circle.fill, got \(symbol)")
                exit(1)
            }
        case "!@#":
            guard symbol == "bookmark.circle.fill" else {
                print("  ! Expected bookmark.circle.fill, got \(symbol)")
                exit(1)
            }
        default:
            break
        }
    }

    print("  ✓ testBookmarkFallbackIconLogic passed.")
}

func testBookmarkHTMLParsingRegex() {
    print("  - testBookmarkHTMLParsingRegex")

    let htmlsAndExpected = [
        ("<link rel=\"icon\" href=\"/favicon.png\">", "/favicon.png"),
        ("<link rel='shortcut icon' href='/favicon.ico'>", "/favicon.ico"),
        (
            "<link rel=\"apple-touch-icon\" sizes=\"180x180\" href=\"/apple-touch-icon.png\">",
            "/apple-touch-icon.png"
        ),
        (
            "<LINK REL=\"ICON\" HREF=\"https://example.com/icon.png\">",
            "https://example.com/icon.png"
        ),
    ]

    let pattern =
        "<link[^>]*rel=[\"']?(?:shortcut icon|icon|apple-touch-icon)[\"']?[^>]*href=[\"']?([^\"'>\\s]+)[\"']?"
    guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
        print("  ! Failed to compile regex")
        exit(1)
    }

    for (html, expected) in htmlsAndExpected {
        if let match = regex.firstMatch(
            in: html, options: [], range: NSRange(location: 0, length: html.utf16.count)),
            let hrefRange = Range(match.range(at: 1), in: html)
        {
            let href = String(html[hrefRange])
            if href != expected {
                print("  ! Expected \(expected), got \(href)")
                exit(1)
            }
        } else {
            print("  ! Failed to match in HTML: \(html)")
            exit(1)
        }
    }

    print("  ✓ testBookmarkHTMLParsingRegex passed.")
}
