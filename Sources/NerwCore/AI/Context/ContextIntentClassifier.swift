import Foundation
import NaturalLanguage

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

public class ContextIntentClassifier {
    public static let shared = ContextIntentClassifier()

    private let tagger = NLTagger(tagSchemes: [.lexicalClass, .lemma])
    private let taggerLock = NSLock()

    private init() {}

    public func classify(_ query: String) -> [ContextIntent] {
        var intents = Set<ContextIntent>()
        // System context is always injected
        intents.insert(.system)

        let lower = query.lowercased()

        // Clipboard
        let clipboardKeywords = ["clipboard", "copied", "copy", "paste", "recently copied"]
        if clipboardKeywords.contains(where: { lower.contains($0) }) {
            intents.insert(.clipboard)
        }

        // Active App / Screen / Website / Visual
        let activeAppKeywords = [
            "this page", "current screen", "current app", "frontmost app", "this site",
            "this website", "this article", "look", "screen", "see", "what is this",
            "this thing", "visual", "image", "sum up the total usage", "this chart",
            "this graph", "screenshot",
        ]
        if activeAppKeywords.contains(where: { lower.contains($0) }) {
            intents.insert(.activeAppAndScreen)
        }

        // Calendar
        let calendarKeywords = [
            "calendar", "calender", "meeting", "meetings", "schedule", "appointment",
            "appointments",
        ]
        if calendarKeywords.contains(where: { lower.contains($0) }) {
            let timeFrame = extractTimeFrame(from: lower)
            intents.insert(.calendar(TimeFrame: timeFrame))
        }

        // Reminders
        let reminderKeywords = [
            "reminder", "reminders", "task", "tasks", "todo", "to-do", "remind me",
        ]
        if reminderKeywords.contains(where: { lower.contains($0) }) {
            let timeFrame = extractTimeFrame(from: lower)
            intents.insert(.reminder(TimeFrame: timeFrame))
        }

        // Notes & Local Files
        let notesKeywords = [
            "notes", "files", "note", "file", "document", "documents", "look in notes",
            "check notes",
        ]
        if notesKeywords.contains(where: { lower.contains($0) }) {
            intents.insert(.notes(query: lower))
        }

        // NLP based analysis for implicit intents
        taggerLock.lock()
        defer { taggerLock.unlock() }

        tagger.string = lower
        let range = lower.startIndex..<lower.endIndex

        var hasFixTranslateRewrite = false
        tagger.enumerateTags(in: range, unit: .word, scheme: .lemma) { tag, _ in
            guard let tag = tag else { return true }
            let lemma = tag.rawValue
            if ["fix", "translate", "rewrite", "summarize", "explain"].contains(lemma) {
                hasFixTranslateRewrite = true
            }
            return true
        }

        // If asking to fix/translate/rewrite without a clear target, maybe they mean clipboard
        if hasFixTranslateRewrite && !lower.contains("this") && intents.count == 1 {
            intents.insert(.clipboard)
        }

        return Array(intents)
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

        // Check for specific days (e.g. "monday", "tuesday") -> default to week
        let days = [
            "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday",
            "tomorrow",
        ]
        if days.contains(where: { text.contains($0) }) {
            return .week
        }

        // Default: If no specific time frame, we usually just want today's or all relevant short-term context.
        return .today
    }
}
