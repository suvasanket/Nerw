import Foundation
import NaturalLanguage
import NerwSearchBackend

public enum ContextTimeFrame: String, Equatable {
    case today
    case week
    case month
    case all
}

public enum ContextIntent: Hashable {
    case calendar(TimeFrame: ContextTimeFrame)
    case reminder(TimeFrame: ContextTimeFrame)
    case notes(query: String)
    case clipboard
    case activeAppAndScreen
    case system
}

public enum ActionIntent: String, Hashable {
    case timer
    case reminder
    case calendar
    case memory
    case note
    case app
    case email
}

public class IntentClassifier {
    public static let shared = IntentClassifier()

    private let tagger = NLTagger(tagSchemes: [.lexicalClass, .lemma])
    private let taggerLock = NSLock()
    private let wordEmbedding: NLEmbedding? = NLEmbedding.wordEmbedding(for: .english)

    private enum DomainName: CaseIterable {
        case clipboard
        case activeAppAndScreen
        case appMenubar
        case calendar
        case reminder
        case note
        case timer
        case memory
        case email
    }

    private struct DomainRule {
        let canonicalKeywords: [String]
        let semanticAnchors: [String]
        let actionVerbs: [String]
        let explicitActionPhrases: [String]
    }

    private struct DomainEvidence {
        var score: Double = 0.0
        var isExactOrLemma: Bool = false
        var isFuzzyTypo: Bool = false
        var isSemantic: Bool = false
        var hasActionVerb: Bool = false
        var hasExplicitActionPhrase: Bool = false

        var isActivated: Bool {
            score >= 2.0
        }
    }

    private init() {}

    public func classify(_ query: String, history: [AIChatMessage] = []) -> (
        contextIntents: Set<ContextIntent>, actionIntents: Set<ActionIntent>
    ) {
        var contextIntents = Set<ContextIntent>()
        var actionIntents = Set<ActionIntent>()
        // System context is always injected
        contextIntents.insert(.system)

        let lower = query.lowercased()
        let (tokens, lemmas) = extractTokensAndLemmas(from: lower)

        // --- Multi-Stage Domain Evaluation ---
        let clipboardEv = evaluateDomain(
            for: .clipboard, queryLower: lower, tokens: tokens, lemmas: lemmas)
        if clipboardEv.isActivated {
            contextIntents.insert(.clipboard)
        }

        let activeAppEv = evaluateDomain(
            for: .activeAppAndScreen, queryLower: lower, tokens: tokens, lemmas: lemmas)
        if activeAppEv.isActivated {
            contextIntents.insert(.activeAppAndScreen)
            actionIntents.insert(.app)
        }

        let menubarEv = evaluateDomain(
            for: .appMenubar, queryLower: lower, tokens: tokens, lemmas: lemmas)
        if menubarEv.isActivated {
            actionIntents.insert(.app)
            contextIntents.insert(.activeAppAndScreen)
        }

        let calendarEv = evaluateDomain(
            for: .calendar, queryLower: lower, tokens: tokens, lemmas: lemmas)
        if calendarEv.isActivated {
            let timeFrame = extractTimeFrame(from: lower)
            contextIntents.insert(.calendar(TimeFrame: timeFrame))
            if calendarEv.hasActionVerb || calendarEv.hasExplicitActionPhrase
                || calendarEv.score >= 3.0
            {
                actionIntents.insert(.calendar)
            }
        }

        let reminderEv = evaluateDomain(
            for: .reminder, queryLower: lower, tokens: tokens, lemmas: lemmas)
        if reminderEv.isActivated {
            let timeFrame = extractTimeFrame(from: lower)
            contextIntents.insert(.reminder(TimeFrame: timeFrame))
            if reminderEv.hasActionVerb || reminderEv.hasExplicitActionPhrase
                || reminderEv.score >= 3.0
            {
                actionIntents.insert(.reminder)
            }
        }

        let noteEv = evaluateDomain(for: .note, queryLower: lower, tokens: tokens, lemmas: lemmas)
        if noteEv.isActivated {
            contextIntents.insert(.notes(query: lower))
            if noteEv.hasActionVerb || noteEv.hasExplicitActionPhrase || noteEv.score >= 3.0 {
                actionIntents.insert(.note)
            }
        }

        let timerEv = evaluateDomain(for: .timer, queryLower: lower, tokens: tokens, lemmas: lemmas)
        if timerEv.isActivated {
            actionIntents.insert(.timer)
        }

        let memoryEv = evaluateDomain(
            for: .memory, queryLower: lower, tokens: tokens, lemmas: lemmas)
        if memoryEv.isActivated {
            actionIntents.insert(.memory)
        }

        let emailEv = evaluateDomain(for: .email, queryLower: lower, tokens: tokens, lemmas: lemmas)
        if emailEv.isActivated {
            actionIntents.insert(.email)
        }

        // --- Implicit NLP fallback for fix / translate / rewrite ---
        var hasFixTranslateRewrite = false
        for lemma in lemmas {
            if ["fix", "translate", "rewrite", "summarize", "explain"].contains(lemma) {
                hasFixTranslateRewrite = true
            }
        }
        if hasFixTranslateRewrite && !lower.contains("this") && contextIntents.count == 1 {
            contextIntents.insert(.clipboard)
        }

        // --- Conversation Continuation from History ---
        if !history.isEmpty {
            let continuationKeywords = [
                "another", "again", "repeat", "reexecute", "re-execute", "more", "one more",
                "same", "previous", "do it", "do that", "continue", "next", "also", "too",
                "once more", "second", "third", "other",
            ]
            let isContinuation =
                actionIntents.isEmpty
                || continuationKeywords.contains(where: { lower.contains($0) })

            if isContinuation {
                let priorMessages = history.dropLast(
                    history.last?.content == query ? 1 : 0)
                for msg in priorMessages.reversed() {
                    if msg.role == .assistant {
                        let inherited = extractActionIntents(fromAssistantMessage: msg.content)
                        if !inherited.isEmpty {
                            for action in inherited {
                                actionIntents.insert(action)
                                appendContextIntent(
                                    for: action, into: &contextIntents, query: query)
                            }
                            break
                        }
                    } else if msg.role == .user {
                        let priorClassification = classify(msg.content, history: [])
                        if !priorClassification.actionIntents.isEmpty {
                            for action in priorClassification.actionIntents {
                                actionIntents.insert(action)
                                appendContextIntent(
                                    for: action, into: &contextIntents, query: query)
                            }
                            break
                        }
                    }
                }
            }
        }

        return (contextIntents, actionIntents)
    }

    private func evaluateDomain(
        for domain: DomainName,
        queryLower: String,
        tokens: [String],
        lemmas: [String]
    ) -> DomainEvidence {
        let rule = rules(for: domain)
        var evidence = DomainEvidence()

        // 1. Tier 1: Exact / Lemma Match (+3.0)
        let exactMatch =
            rule.canonicalKeywords.contains(where: { queryLower.contains($0) })
            || rule.canonicalKeywords.contains(where: { lemmas.contains($0) })
        if exactMatch {
            evidence.score += 3.0
            evidence.isExactOrLemma = true
        }

        // 2. Tier 2: Fuzzy Typo Match (+2.5)
        if !evidence.isExactOrLemma {
            if hasFuzzyTypoMatch(tokens: tokens, keywords: rule.canonicalKeywords) {
                evidence.score += 2.5
                evidence.isFuzzyTypo = true
            }
        }

        // 3. Tier 3: Semantic Similarity (+1.5)
        if evidence.score == 0.0 {
            if computeSemanticSimilarity(tokens: lemmas, anchors: rule.semanticAnchors) {
                evidence.score += 1.5
                evidence.isSemantic = true
            }
        }

        // 4. Tier 4: Action Verb Co-occurrence (+1.5)
        let matchesVerb = rule.actionVerbs.contains(where: { verb in
            queryLower.contains(verb) || lemmas.contains(verb) || tokens.contains(verb)
        })
        if matchesVerb {
            evidence.hasActionVerb = true
            if evidence.score > 0 {
                evidence.score += 1.5
            }
        }

        // 5. Explicit Action Phrase
        evidence.hasExplicitActionPhrase =
            rule.explicitActionPhrases.contains(where: {
                queryLower.contains($0) || lemmas.contains($0)
            }) || (evidence.isFuzzyTypo && evidence.hasActionVerb)

        return evidence
    }

    private func rules(for domain: DomainName) -> DomainRule {
        switch domain {
        case .clipboard:
            return DomainRule(
                canonicalKeywords: ["clipboard", "copied", "copy", "paste", "recently copied"],
                semanticAnchors: ["clipboard", "copy", "paste"],
                actionVerbs: ["copy", "paste"],
                explicitActionPhrases: []
            )
        case .activeAppAndScreen:
            return DomainRule(
                canonicalKeywords: [
                    "this page", "current screen", "current app", "frontmost app", "this site",
                    "this website", "this article", "look", "screen", "see", "what is this",
                    "this thing", "visual", "image", "sum up the total usage", "this chart",
                    "this graph", "screenshot", "this app", "this application", "active app",
                    "active application", "current application", "in this", "in here", "here",
                ],
                semanticAnchors: ["screen", "screenshot", "active", "frontmost", "visual"],
                actionVerbs: ["look", "see", "inspect"],
                explicitActionPhrases: []
            )
        case .appMenubar:
            return DomainRule(
                canonicalKeywords: [
                    "menubar", "menu bar", "menu", "click menu", "new tab", "new window",
                    "close tab", "close window", "split right", "split left", "split down",
                    "split up", "tab", "window",
                ],
                semanticAnchors: ["menubar", "tab", "window", "split", "workspace", "browser"],
                actionVerbs: ["open", "close", "split", "click", "new", "create"],
                explicitActionPhrases: [
                    "new tab", "new window", "close tab", "close window", "split",
                ]
            )
        case .calendar:
            return DomainRule(
                canonicalKeywords: [
                    "calendar", "calender", "meeting", "meetings", "schedule", "appointment",
                    "appointments", "event", "events",
                ],
                semanticAnchors: [
                    "calendar", "meeting", "schedule", "appointment", "event", "briefing",
                ],
                actionVerbs: ["schedule", "create", "add", "set", "book", "put"],
                explicitActionPhrases: ["schedule", "create", "add", "set up", "book"]
            )
        case .reminder:
            return DomainRule(
                canonicalKeywords: [
                    "reminder", "reminders", "task", "tasks", "todo", "to-do", "remind me",
                    "set a reminder", "remind",
                ],
                semanticAnchors: ["reminder", "task", "todo", "remind", "deadline"],
                actionVerbs: ["remind", "add", "create", "set", "make", "new"],
                explicitActionPhrases: ["remind me", "add", "create", "set a reminder", "remind"]
            )
        case .note:
            return DomainRule(
                canonicalKeywords: [
                    "notes", "files", "note", "file", "document", "documents", "look in notes",
                    "check notes", "write down", "save note", "create a note", "append to note",
                ],
                semanticAnchors: ["note", "document", "file", "memo", "jot", "write"],
                actionVerbs: ["write", "save", "create", "append", "add", "jot"],
                explicitActionPhrases: [
                    "write", "save note", "create", "append", "add to note", "save",
                ]
            )
        case .timer:
            return DomainRule(
                canonicalKeywords: ["timer", "set a timer", "countdown", "alarm"],
                semanticAnchors: ["timer", "countdown", "alarm", "stopwatch"],
                actionVerbs: ["set", "start", "create"],
                explicitActionPhrases: ["set a timer", "timer", "countdown", "alarm"]
            )
        case .memory:
            return DomainRule(
                canonicalKeywords: [
                    "remember that", "keep in mind", "my favorite", "i prefer", "memorize",
                ],
                semanticAnchors: ["remember", "memorize", "preference", "favorite"],
                actionVerbs: ["remember", "memorize", "prefer"],
                explicitActionPhrases: ["remember that", "keep in mind", "memorize"]
            )
        case .email:
            return DomainRule(
                canonicalKeywords: [
                    "send email", "email to", "send an email", "write an email", "compose email",
                    "compose an email", "draft an email", "draft email", "email",
                ],
                semanticAnchors: ["email", "mail", "compose", "draft"],
                actionVerbs: ["send", "write", "compose", "draft"],
                explicitActionPhrases: [
                    "send email", "email to", "send an email", "write an email", "compose email",
                    "draft an email",
                ]
            )
        }
    }

    private func hasFuzzyTypoMatch(tokens: [String], keywords: [String]) -> Bool {
        for token in tokens where token.count >= 4 {
            for keyword in keywords {
                if keyword.contains(token) || token.contains(keyword) { continue }
                let cleanKeyword = keyword.replacingOccurrences(of: " ", with: "")
                if token.levenshteinDistanceScore(to: cleanKeyword) >= 0.65 {
                    return true
                }
                let words = keyword.split(separator: " ").map(String.init)
                for word in words where word.count >= 4 {
                    if token.levenshteinDistanceScore(to: word) >= 0.65 {
                        return true
                    }
                }
            }
        }
        return false
    }

    private func computeSemanticSimilarity(tokens: [String], anchors: [String]) -> Bool {
        guard let embedding = wordEmbedding else { return false }
        for token in tokens {
            for anchor in anchors {
                let dist = embedding.distance(between: token, and: anchor)
                if dist < 0.8 {
                    return true
                }
            }
        }
        return false
    }

    private func extractTokensAndLemmas(from query: String) -> (tokens: [String], lemmas: [String])
    {
        var tokens: [String] = []
        var lemmas: [String] = []

        taggerLock.lock()
        defer { taggerLock.unlock() }

        tagger.string = query
        let range = query.startIndex..<query.endIndex

        tagger.enumerateTags(in: range, unit: .word, scheme: .lemma) { tag, tokenRange in
            let word = String(query[tokenRange]).lowercased()
            let cleanWord = word.trimmingCharacters(in: .punctuationCharacters)
            if cleanWord.count >= 2 {
                tokens.append(cleanWord)
                if let lemma = tag?.rawValue.lowercased(), !lemma.isEmpty {
                    lemmas.append(lemma)
                } else {
                    lemmas.append(cleanWord)
                }
            }
            return true
        }

        return (tokens, lemmas)
    }

    private func extractActionIntents(fromAssistantMessage content: String) -> Set<ActionIntent> {
        var actions = Set<ActionIntent>()
        let mappings: [(keywords: [String], intent: ActionIntent)] = [
            (["\"type\": \"app\"", "\"type\":\"app\"", "[action:app", "type = app"], .app),
            (["\"type\": \"timer\"", "\"type\":\"timer\"", "[action:timer"], .timer),
            (["\"type\": \"reminder\"", "\"type\":\"reminder\"", "[action:reminder"], .reminder),
            (["\"type\": \"calendar\"", "\"type\":\"calendar\"", "[action:calendar"], .calendar),
            (["\"type\": \"note\"", "\"type\":\"note\"", "[action:note"], .note),
            (["\"type\": \"email\"", "\"type\":\"email\"", "[action:email"], .email),
            (["\"type\": \"memory\"", "\"type\":\"memory\"", "[action:memory"], .memory),
        ]

        for mapping in mappings {
            if mapping.keywords.contains(where: { content.contains($0) }) {
                actions.insert(mapping.intent)
            }
        }
        return actions
    }

    private func appendContextIntent(
        for action: ActionIntent,
        into contextIntents: inout Set<ContextIntent>,
        query: String
    ) {
        switch action {
        case .app:
            contextIntents.insert(.activeAppAndScreen)
        case .calendar:
            contextIntents.insert(.calendar(TimeFrame: .today))
        case .reminder:
            contextIntents.insert(.reminder(TimeFrame: .today))
        case .note:
            contextIntents.insert(.notes(query: query))
        case .timer, .memory, .email:
            break
        }
    }

    private func extractTimeFrame(from text: String) -> ContextTimeFrame {
        if text.contains("today") || text.contains("tonight") {
            return .today
        } else if text.contains("next week") {
            return .all
        } else if text.contains("this week") || text.contains("weekend") {
            return .week
        } else if text.contains("this month") || text.contains("next month") {
            return .month
        } else if text.contains("all") || text.contains("everything") || text.contains("upcoming") {
            return .all
        }

        let days = [
            "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday",
            "tomorrow",
        ]
        if days.contains(where: { text.contains($0) }) {
            return .week
        }

        return .today
    }
}
