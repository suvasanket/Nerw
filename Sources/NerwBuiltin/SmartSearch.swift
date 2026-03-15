import Cocoa
import Foundation

public class SmartSearch {
    public static let shared = SmartSearch()

    // Known domains/sites people navigate to directly
    private let knownSites: Set<String> = [
        "youtube", "reddit", "github", "stackoverflow", "stack overflow",
        "twitter", "x.com", "facebook", "instagram", "linkedin",
        "amazon", "ebay", "netflix", "spotify", "twitch",
        "wikipedia", "wiki", "gmail", "google drive", "outlook",
        "notion", "figma", "canva", "chatgpt", "claude",
        "whatsapp", "telegram", "discord", "slack",
        "medium", "substack", "hackernews", "hacker news",
        "imdb", "rottentomatoes", "craigslist",
        "dropbox", "drive", "maps", "translate",
        "pinterest", "tumblr", "tiktok", "snapchat",
    ]

    // Patterns that indicate user wants to BROWSE results
    private let researchPatterns: [NSRegularExpression] = [
        "\\bhow\\s+(to|do|does|can|is|are|was|were|much|many|long|often|far)\\b",
        "\\bwhat\\s+(is|are|was|were|does|do|should|would|could|can)\\b",
        "\\bwhy\\s+(is|are|do|does|did|was|were|can|should|would)\\b",
        "\\bwhen\\s+(is|are|do|does|did|was|were|can|should|will)\\b",
        "\\bwhere\\s+(is|are|do|does|did|was|were|can|should|to)\\b",
        "\\bwhich\\s+(is|are|one|ones|should|would)\\b",
        "\\bwho\\s+(is|are|was|were|did|does|can|should)\\b",
        "\\b(best|top|worst|cheapest|fastest|easiest)\\b",
        "\\b(compare|comparison|vs\\.?|versus|difference between|or)\\b",
        "\\b(review|reviews|rating|ratings|opinions?)\\b",
        "\\b(alternatives?|similar to|like)\\b",
        "\\b(pros? and cons?|advantages?|disadvantages?)\\b",
        "\\b(guide|tutorial|learn|explain|meaning|definition)\\b",
        "\\b(list of|examples? of|types? of|ways to)\\b",
        "\\b(should i|can i|is it worth|is it safe|is it possible)\\b",
        "\\b(error|fix|solve|debug|troubleshoot|issue|problem)\\b",
        "\\b(recipe|ingredients|instructions|steps)\\b",
        "\\b(salary|cost|price|how much|pricing)\\b",
        "\\b(near me|in \\w+|around)\\b",
        "\\b(reddit|forum|discussion|opinions?)\\s*$",
        "\\b(2024|2025|latest|newest|recent|update)\\b",
    ].compactMap { try? NSRegularExpression(pattern: $0, options: .caseInsensitive) }

    // Patterns that indicate DIRECT navigation
    private let directPatterns: [NSRegularExpression] = [
        "^(go to|open|visit|navigate to)\\s+",
        "\\.(com|org|net|io|dev|app|co|me|ai|gov|edu)\\b",
        "\\b(login|log in|sign in|signin|signup|sign up|dashboard)\\b",
        "\\b(download|install)\\s+\\w+$",
        "\\b(official\\s*(site|website|page|docs?))\\b",
        "\\b(docs?|documentation|api|reference)\\s+(for\\s+)?\\w+$",
    ].compactMap { try? NSRegularExpression(pattern: $0, options: .caseInsensitive) }

    // Site-specific navigations
    private let siteSearchPatterns: [String: String] = [
        "youtube": "https://www.youtube.com/results?search_query=",
        "reddit": "https://www.reddit.com/search/?q=",
        "github": "https://github.com/search?q=",
        "stackoverflow": "https://stackoverflow.com/search?q=",
        "stack overflow": "https://stackoverflow.com/search?q=",
        "amazon": "https://www.amazon.com/s?k=",
        "ebay": "https://www.ebay.com/sch/i.html?_nkw=",
        "wikipedia": "https://en.wikipedia.org/wiki/Special:Search?search=",
        "wiki": "https://en.wikipedia.org/wiki/Special:Search?search=",
        "twitter": "https://twitter.com/search?q=",
        "imdb": "https://www.imdb.com/find?q=",
        "pinterest": "https://www.pinterest.com/search/pins/?q=",
        "spotify": "https://open.spotify.com/search/",
    ]

    private init() {}

    public enum Classification {
        case direct(url: String)
        case siteSearch(url: String)
        case results
    }

    public func classify(query: String) -> Classification {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        // 1. Check if it looks like a raw URL
        if isURL(q) {
            let url = q.hasPrefix("http") ? q : "https://\(q)"
            return .direct(url: url)
        }

        // 2. Check for site-specific search
        if let siteResult = checkSiteSearch(q) {
            return .siteSearch(url: siteResult)
        }

        // 3. Check if it matches research patterns
        if isMatch(q, patterns: researchPatterns) {
            return .results
        }

        // 4. Check if it matches direct navigation patterns
        if isMatch(q, patterns: directPatterns) {
            let encoded = q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? q
            return .direct(url: "https://lite.duckduckgo.com/lite/?q=%5C\(encoded)")
        }

        // 5. Check if query is just a known site name
        if isKnownSite(q) {
            let encoded = q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? q
            return .direct(url: "https://lite.duckduckgo.com/lite/?q=%5C\(encoded)")
        }

        // 6. Short queries
        let words = q.split(separator: " ")
        if words.count <= 2 && !isMatch(q, patterns: researchPatterns) {
            let encoded = q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? q
            return .direct(url: "https://lite.duckduckgo.com/lite/?q=%5C\(encoded)")
        }

        // 7. Default
        return .results
    }

    private func isURL(_ q: String) -> Bool {
        let pattern = "^(https?://)?([\\w-]+\\.)+[a-z]{2,}(/\\S*)?$"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        else { return false }
        let range = NSRange(location: 0, length: q.utf16.count)
        return regex.firstMatch(in: q, options: [], range: range) != nil
    }

    private func checkSiteSearch(_ q: String) -> String? {
        for (site, searchUrl) in siteSearchPatterns {
            let pattern = "^\\s*\(NSRegularExpression.escapedPattern(for: site))\\s+(.+)$"
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
            else { continue }

            let range = NSRange(location: 0, length: q.utf16.count)
            if let match = regex.firstMatch(in: q, options: [], range: range) {
                if let termRange = Range(match.range(at: 1), in: q) {
                    let searchTerm = String(q[termRange]).trimmingCharacters(
                        in: .whitespacesAndNewlines)
                    if let encodedTerm = searchTerm.addingPercentEncoding(
                        withAllowedCharacters: .urlQueryAllowed)
                    {
                        return searchUrl + encodedTerm
                    }
                }
            }
        }
        return nil
    }

    private func isMatch(_ q: String, patterns: [NSRegularExpression]) -> Bool {
        let range = NSRange(location: 0, length: q.utf16.count)
        for regex in patterns {
            if regex.firstMatch(in: q, options: [], range: range) != nil {
                return true
            }
        }
        return false
    }

    private func isKnownSite(_ q: String) -> Bool {
        let cleaned = q.replacingOccurrences(of: "[^\\w\\s]", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return knownSites.contains(cleaned)
    }

    public func performSearch(query: String) {
        let classification = classify(query: query)

        switch classification {
        case .direct(let urlString):
            if let url = URL(string: urlString) {
                NSWorkspace.shared.open(url)
            }
        case .siteSearch(let urlString):
            if let url = URL(string: urlString) {
                NSWorkspace.shared.open(url)
            }
        case .results:
            // Standard search URL
            let encodedQuery =
                query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
            let urlString = "https://duckduckgo.com/?q=\(encodedQuery)"
            if let url = URL(string: urlString) {
                NSWorkspace.shared.open(url)
            }
        }
    }
}
