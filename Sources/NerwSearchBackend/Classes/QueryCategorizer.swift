import Foundation
import NaturalLanguage

/// Result of query categorization.
public struct QueryCategorizerResult {
    /// Detected category, or `nil` if the query doesn't strongly match any category.
    public let category: QueryCategory?
    /// Confidence score from 0.0 to 1.0.
    public let confidence: Double

    public init(category: QueryCategory?, confidence: Double) {
        self.category = category
        self.confidence = confidence
    }
}

/// NLP-based query categorizer using Apple's NaturalLanguage framework.
/// Classifies user input into categories (URL, web search, etc.) for smart result boosting.
///
/// Thread-safe. All regex and NLTagger instances are pre-allocated once.
/// Call `classifySync(_:)` from any background queue.
public final class QueryCategorizer {
    public static let shared = QueryCategorizer()

    // MARK: - Pre-compiled patterns (one-time cost)

    /// Matches explicit protocol URLs: http://, https://, ftp://
    private let protocolPattern: NSRegularExpression
    /// Matches www. prefix
    private let wwwPattern: NSRegularExpression
    /// Matches domain-like strings: word.tld (e.g. github.com, docs.swift.org)
    private let domainPattern: NSRegularExpression
    /// Matches IP addresses (v4)
    private let ipPattern: NSRegularExpression
    /// Matches localhost with optional port
    private let localhostPattern: NSRegularExpression
    /// Matches basic math expressions
    private let mathPattern: NSRegularExpression
    /// Matches unit/currency conversions (e.g. 10 kg to lbs)
    private let conversionPattern: NSRegularExpression

    // MARK: - NLP

    /// Reusable tagger — allocated once, string swapped per call.
    private let tagger = NLTagger(tagSchemes: [.lexicalClass])
    private let taggerLock = NSLock()

    // MARK: - Phrase lists (sorted longest-first for greedy matching)

    private let webPhrases: [String]

    private let questionWords: Set<String> = [
        "what", "why", "how", "when", "where", "who", "which",
        "is", "are", "can", "could", "would", "should", "do",
        "does", "did", "will",
    ]

    // MARK: - Init

    private init() {
        func rx(_ p: String) -> NSRegularExpression {
            try! NSRegularExpression(pattern: p, options: .caseInsensitive)
        }

        protocolPattern = rx(#"^[a-zA-Z][a-zA-Z0-9+\-.]*://"#)
        wwwPattern = rx(#"^www\."#)
        domainPattern = rx(
            #"^[a-zA-Z0-9]([a-zA-Z0-9\-]*[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]*[a-zA-Z0-9])?)*\.(com|org|net|io|dev|app|co|me|ai|xyz|edu|gov|info|biz|us|uk|de|fr|jp|in|au|ca|ru|br|it|nl|se|no|fi|dk|be|at|ch|es|pt|pl|cz|kr|cn|tw|hk|sg|nz|za|ar|mx|cl|pe|ph|th|vn|id|my|ng|ke|eg|ae|sa|il|tr|ie|is|lt|lv|ee|hr|si|sk|hu|ro|bg|ua|by|rs|ba|mk|al|me|md|ge|am|az|kz|uz|tm|kg|tj|mn|la|mm|kh|bn|pg|ws|fj|to|vu|sb|tv|fm|pw|ki|mh|nr|cc|cx|ac|sh|gg|je|gi|im|coop|museum|travel|aero|pro|mobi|tel|asia|cat|jobs|xxx|post|bike|clothing|guru|holdings|plumbing|singles|ventures|voyage|zone|agency|bargains|boutique|builders|cab|camera|camp|center|chat|cheap|city|cleaning|clinic|club|codes|coffee|community|company|computer|construction|consulting|contractors|cool|dating|dental|design|diamonds|directory|domains|education|email|engineering|enterprises|equipment|estate|events|exchange|expert|exposed|express|fail|farm|finance|fish|fitness|flights|florist|foundation|fund|furniture|gallery|gifts|glass|graphics|gripe|guide|health|help|house|images|immobilien|industries|ink|institute|insure|international|jetzt|kitchen|land|lease|life|lighting|limited|limo|link|loans|management|mango|market|marketing|media|menu|network|partners|parts|photo|photography|photos|pics|pink|place|press|productions|properties|pub|recipes|red|rehab|reise|reisen|rentals|repair|report|rest|restaurant|reviews|rocks|run|schule|services|shoes|site|social|software|solar|solutions|space|store|studio|style|supplies|supply|support|surgery|systems|tax|technology|tips|today|tools|town|toys|training|university|watch|website|wiki|work|works|world|wtf|xyz)(\/.*)?"#
        )
        ipPattern = rx(
            #"^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}(:\d+)?(\/.*)?$"#
        )
        localhostPattern = rx(#"^localhost(:\d+)?(\/.*)?$"#)

        // Math matches digits, operators, parens, and spaces. At least one digit and one operator.
        // E.g. "10 + 20", "10^20", "5 * (2 + 3)"
        // Needs at least one digit and one operator to prevent empty strings or just numbers
        mathPattern = rx(#"^[\d\s\+\-\*\/\^\(\)\.]+$"#)
        // Unit conversion matches: number [spaces] unit [spaces] to/in [spaces] unit
        conversionPattern = rx(#"^([0-9.]+)\s*([a-zA-Z]{1,4})\s+(to|in)\s+([a-zA-Z]{1,4})$"#)

        // Web search signal phrases — sorted longest-first
        webPhrases = [
            "how to fix", "where to buy", "how to install", "how to use",
            "how to make", "how to get", "how to set up", "how to create",
            "release date", "stock price", "live score", "time in",
            "price of", "cost of", "recipe for", "near me",
            "best", "latest", "news", "today", "current", "recent",
            "trending", "results", "buy", "cheap", "deal", "discount",
            "review", "reviews", "rating", "download", "schedule",
            "hours", "weather", "lyrics", "wiki", "trailer",
            "vs", "versus", "comparison", "troubleshoot", "update",
        ].sorted { $0.count > $1.count }
    }

    // MARK: - Public API

    /// Classify a query synchronously. Call from a background queue.
    public func classifySync(_ query: String) -> QueryCategorizerResult {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            return QueryCategorizerResult(category: nil, confidence: 1.0)
        }

        let lower = trimmed.lowercased()

        // ── FAST PATH: URL detection ──────────────────────────────────

        if let urlResult = detectURL(lower) {
            return urlResult
        }

        // ── MATH / CONVERSION detection ───────────────────────────────

        let nsRange = NSRange(trimmed.startIndex..., in: trimmed)

        if conversionPattern.firstMatch(in: trimmed, range: nsRange) != nil {
            return QueryCategorizerResult(category: .mathConversion, confidence: 1.0)
        }

        if mathPattern.firstMatch(in: trimmed, range: nsRange) != nil {
            // Check if it's not just a single number or empty string
            // It should contain at least one operator to be a math expression
            if trimmed.contains(where: { "+-*/^()".contains($0) }) {
                return QueryCategorizerResult(category: .mathConversion, confidence: 1.0)
            }
        }

        // ── WEB SEARCH detection ──────────────────────────────────────

        let words = lower.split(separator: " ", maxSplits: 30, omittingEmptySubsequences: true)
        let wordCount = words.count

        // Single word queries → almost certainly an app/action name, not a web search
        if wordCount <= 1 {
            return QueryCategorizerResult(category: nil, confidence: 1.0)
        }

        var webScore: Double = 0.0

        // 1. Phrase matching
        webScore += phraseScore(lower, webPhrases)

        // 2. Question word at start
        let firstWord = String(words[0])
        if questionWords.contains(firstWord) {
            if wordCount >= 4 {
                webScore += 2.5  // "how to install docker" — strong web signal
            } else {
                webScore += 1.5  // "what is swift" — moderate
            }
        }

        // 3. Question mark at end
        if lower.hasSuffix("?") {
            webScore += 1.0
        }

        // 4. NLP analysis (only if we have enough words to analyze)
        if wordCount >= 3 {
            webScore += nlpWebScore(trimmed)
        }

        // 5. Word count heuristic — most action triggers are 1-2 words,
        // so multi-word queries increasingly signal web search intent.
        // Graduated scoring gives progressively stronger web signals.
        if wordCount >= 3 {
            webScore += 1.0  // 3 words: mild signal ("swift ui tutorial")
        }
        if wordCount >= 4 {
            webScore += 1.0  // 4 words: moderate ("how to install docker")
        }
        if wordCount >= 5 {
            webScore += 0.8  // 5 words: strong ("best restaurants near me now")
        }
        if wordCount >= 6 {
            webScore += 0.5  // 6+ words: very strong — almost certainly a web search
        }

        // ── Confidence calculation ────────────────────────────────────
        // webScore of 3.0+ → high confidence
        // webScore of 1.5-3.0 → moderate confidence
        // webScore < 1.5 → not enough evidence

        if webScore >= 1.5 {
            // Normalize to 0.6–0.98 range
            let confidence = min(0.98, 0.6 + (webScore - 1.5) * 0.06)
            return QueryCategorizerResult(category: .webSearch, confidence: confidence)
        }

        // Not enough signal for any category
        return QueryCategorizerResult(category: nil, confidence: 1.0)
    }

    // MARK: - Private: URL Detection

    private func detectURL(_ lower: String) -> QueryCategorizerResult? {
        let nsRange = NSRange(lower.startIndex..., in: lower)

        // Protocol URLs (http://, https://, ftp://)
        if protocolPattern.firstMatch(in: lower, range: nsRange) != nil {
            return QueryCategorizerResult(category: .url, confidence: 0.99)
        }

        // www. prefix
        if wwwPattern.firstMatch(in: lower, range: nsRange) != nil {
            return QueryCategorizerResult(category: .url, confidence: 0.97)
        }

        // localhost
        if localhostPattern.firstMatch(in: lower, range: nsRange) != nil {
            return QueryCategorizerResult(category: .url, confidence: 0.95)
        }

        // IP address
        if ipPattern.firstMatch(in: lower, range: nsRange) != nil {
            return QueryCategorizerResult(category: .url, confidence: 0.93)
        }

        // Domain pattern (e.g. github.com, docs.swift.org)
        // Only check if no spaces (URLs don't have spaces)
        if !lower.contains(" ") && domainPattern.firstMatch(in: lower, range: nsRange) != nil {
            return QueryCategorizerResult(category: .url, confidence: 0.92)
        }

        return nil
    }

    // MARK: - Private: Phrase Scoring

    private func phraseScore(_ query: String, _ phrases: [String]) -> Double {
        var score = 0.0
        for phrase in phrases where query.contains(phrase) {
            let phraseWordCount = phrase.split(separator: " ").count
            score += Double(phraseWordCount) * 1.0
        }
        return score
    }

    // MARK: - Private: NLP Analysis

    private func nlpWebScore(_ query: String) -> Double {
        taggerLock.lock()
        defer { taggerLock.unlock() }

        tagger.string = query
        let range = query.startIndex..<query.endIndex

        var verbs = 0
        var nouns = 0
        var tokens = 0

        tagger.enumerateTags(in: range, unit: .word, scheme: .lexicalClass) { tag, _ in
            tokens += 1
            switch tag {
            case .verb: verbs += 1
            case .noun: nouns += 1
            default: break
            }
            return true
        }

        guard tokens > 0 else { return 0 }

        var score = 0.0

        // Verb + noun combination suggests a search-like query ("install docker", "buy iPhone")
        if verbs >= 1 && nouns >= 1 {
            score += 1.2
        }

        // Many tokens with nouns → likely a descriptive search query
        if tokens >= 4 && nouns >= 2 {
            score += 0.8
        }

        return score
    }
}
