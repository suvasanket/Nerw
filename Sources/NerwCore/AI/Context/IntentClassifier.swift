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

    private init() {}

    public func classify(_ query: String) -> (
        contextIntents: Set<ContextIntent>, actionIntents: Set<ActionIntent>
    ) {
        var contextIntents = Set<ContextIntent>()
        var actionIntents = Set<ActionIntent>()
        // System context is always injected
        contextIntents.insert(.system)

        let lower = query.lowercased()

        // --- Context & Action Matching ---

        // Clipboard
        let clipboardKeywords = ["clipboard", "copied", "copy", "paste", "recently copied"]
        if clipboardKeywords.contains(where: { lower.contains($0) }) {
            contextIntents.insert(.clipboard)
        }

        // Active App / Screen / Website / Visual
        let activeAppKeywords = [
            "this page", "current screen", "current app", "frontmost app", "this site",
            "this website", "this article", "look", "screen", "see", "what is this",
            "this thing", "visual", "image", "sum up the total usage", "this chart",
            "this graph", "screenshot", "this app", "this application", "active app",
            "active application", "current application", "in this", "in here", "here",
        ]
        if activeAppKeywords.contains(where: { lower.contains($0) }) {
            contextIntents.insert(.activeAppAndScreen)
            actionIntents.insert(.app)
        }

        // Menubar Action
        let menubarKeywords = ["menubar", "menu bar", "menu", "click menu"]
        if menubarKeywords.contains(where: { lower.contains($0) }) {
            actionIntents.insert(.app)
            contextIntents.insert(.activeAppAndScreen)
        }

        // Calendar
        let calendarKeywords = [
            "calendar", "calender", "meeting", "meetings", "schedule", "appointment",
            "appointments",
        ]
        if calendarKeywords.contains(where: { lower.contains($0) }) {
            let timeFrame = extractTimeFrame(from: lower)
            contextIntents.insert(.calendar(TimeFrame: timeFrame))
            if lower.contains("schedule") || lower.contains("create") || lower.contains("add")
                || lower.contains("set up")
            {
                actionIntents.insert(.calendar)
            }
        }

        // Reminders
        let reminderKeywords = [
            "reminder", "reminders", "task", "tasks", "todo", "to-do", "remind me",
            "set a reminder",
        ]
        if reminderKeywords.contains(where: { lower.contains($0) }) {
            let timeFrame = extractTimeFrame(from: lower)
            contextIntents.insert(.reminder(TimeFrame: timeFrame))
            if lower.contains("remind me") || lower.contains("add") || lower.contains("create")
                || lower.contains("set")
            {
                actionIntents.insert(.reminder)
            }
        }

        // Notes & Local Files
        let notesKeywords = [
            "notes", "files", "note", "file", "document", "documents", "look in notes",
            "check notes", "write down", "save note", "create a note", "append to note",
        ]
        if notesKeywords.contains(where: { lower.contains($0) }) {
            contextIntents.insert(.notes(query: lower))
            if lower.contains("write") || lower.contains("save note") || lower.contains("create")
                || lower.contains("append") || lower.contains("add to note")
            {
                actionIntents.insert(.note)
            }
        }

        // Timer
        let timerKeywords = ["timer", "set a timer", "countdown"]
        if timerKeywords.contains(where: { lower.contains($0) }) {
            actionIntents.insert(.timer)
        }

        // Memory
        let memoryKeywords = [
            "remember that", "keep in mind", "my favorite", "i prefer", "memorize",
        ]
        if memoryKeywords.contains(where: { lower.contains($0) }) {
            actionIntents.insert(.memory)
        }

        // Email
        let emailKeywords = [
            "send email", "email to", "send an email", "write an email", "compose email",
            "compose an email", "draft an email", "draft email",
        ]
        if emailKeywords.contains(where: { lower.contains($0) }) {
            actionIntents.insert(.email)
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
        if hasFixTranslateRewrite && !lower.contains("this") && contextIntents.count == 1 {
            contextIntents.insert(.clipboard)
        }

        return (contextIntents, actionIntents)
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
