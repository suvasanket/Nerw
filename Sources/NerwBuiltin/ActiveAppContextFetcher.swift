import AppKit
import Foundation
import NerwCore

public class ActiveAppContextFetcher: ContextFetching {
    public var intentType: String { return "activeApp" }

    // Max characters to prevent blowing up context limit
    private let maxContentLength = 10000

    public init() {}

    public func canHandle(intent: ContextIntent) -> Bool {
        if case .activeAppAndScreen = intent { return true }
        return false
    }

    public func fetchContext(for intent: ContextIntent) async -> FetchedContext? {
        guard case .activeAppAndScreen = intent else { return nil }

        let screenData = ScreenCaptureManager.shared.latestCapture
        let images = screenData.map { [$0] } ?? []

        guard let frontApp = System.shared.lastActiveApp ?? NSWorkspace.shared.frontmostApplication,
            let appName = frontApp.localizedName
        else {
            return FetchedContext(
                text: "[Active Context]\nCannot determine active application.", images: images)
        }

        // Check if the frontmost app is a known browser
        if let info = BrowserURLFetcher.shared.getBrowserInfo(), let urlString = info.url {
            let title = info.title ?? "Unknown Title"

            var contextStr = """
                [Active Website Context]
                Browser: \(appName)
                Title: \(title)
                URL: \(urlString)
                """

            if let htmlContent = await fetchHTML(from: urlString) {
                let strippedText = extractText(from: htmlContent)
                let cappedText = String(strippedText.prefix(maxContentLength))

                contextStr += "\n\n[Website Content (Text Only)]\n\(cappedText)"
                if strippedText.count > maxContentLength {
                    contextStr += "\n... (Content truncated due to length limits)"
                }
            } else {
                contextStr += "\n\n(Could not fetch website content natively)"
            }

            return FetchedContext(text: contextStr, images: images)
        }

        // Fallback for non-browser apps
        return FetchedContext(
            text: "[Active Application Context]\nApplication Name: \(appName)", images: images)
    }

    private func fetchHTML(from urlString: String) async -> String? {
        guard let url = URL(string: urlString) else { return nil }

        var request = URLRequest(url: url)
        request.timeoutInterval = 5.0  // Fast timeout
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
            forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                (200...299).contains(httpResponse.statusCode)
            else {
                return nil
            }
            return String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1)
        } catch {
            return nil
        }
    }

    private func extractText(from html: String) -> String {
        var text = html

        // Remove scripts and styles using [\s\S]*? to match across newlines
        text = text.replacingOccurrences(
            of: "<script[^>]*>[\\s\\S]*?</script>", with: " ",
            options: [.regularExpression, .caseInsensitive])
        text = text.replacingOccurrences(
            of: "<style[^>]*>[\\s\\S]*?</style>", with: " ",
            options: [.regularExpression, .caseInsensitive])
        text = text.replacingOccurrences(
            of: "<svg[^>]*>[\\s\\S]*?</svg>", with: " ",
            options: [.regularExpression, .caseInsensitive])

        // Remove all other HTML tags
        text = text.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)

        // Basic HTML entity decoding
        text = text.replacingOccurrences(of: "&nbsp;", with: " ")
        text = text.replacingOccurrences(of: "&amp;", with: "&")
        text = text.replacingOccurrences(of: "&lt;", with: "<")
        text = text.replacingOccurrences(of: "&gt;", with: ">")
        text = text.replacingOccurrences(of: "&quot;", with: "\"")
        text = text.replacingOccurrences(of: "&#39;", with: "'")

        // Collapse multiple whitespace/newlines
        text = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

}
