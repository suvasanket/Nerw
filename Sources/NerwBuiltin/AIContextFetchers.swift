import EventKit
import Foundation
import NerwCore

public class ClipboardContextFetcher: ContextFetching {
    public var intentType: String { return "clipboard" }

    public init() {}

    public func canHandle(intent: ContextIntent) -> Bool {
        if case .clipboard = intent { return true }
        return false
    }

    public func fetchContext(for intent: ContextIntent) async -> FetchedContext? {
        guard ConfigManager.shared.config.aiConfig.isClipboardContextEnabled else { return nil }
        let entries = ClipboardManager.shared.entries.prefix(3)
        guard !entries.isEmpty else { return nil }

        var contextStr = "[Recent Clipboard History]\n"
        for (i, entry) in entries.enumerated() {
            let app = entry.sourceApp ?? "Unknown App"
            if let text = entry.text {
                contextStr += "Entry \(i+1) (from \(app)):\n\"\(text.prefix(500))\"\n\n"
            }
        }

        return FetchedContext(text: contextStr.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

public class CalendarContextFetcher: ContextFetching {
    public var intentType: String { return "calendar" }
    private let eventStore = EKEventStore()

    public init() {}

    public func canHandle(intent: ContextIntent) -> Bool {
        if case .calendar = intent { return true }
        return false
    }

    public func fetchContext(for intent: ContextIntent) async -> FetchedContext? {
        guard ConfigManager.shared.config.aiConfig.isCalendarContextEnabled else { return nil }
        guard case .calendar(let timeFrame) = intent else { return nil }

        // Ensure we have access
        let status = EKEventStore.authorizationStatus(for: .event)
        var isAuthorized = false
        if #available(macOS 14.0, *) {
            isAuthorized = (status == .authorized || status == .fullAccess)
        } else {
            isAuthorized = (status == .authorized)
        }

        guard isAuthorized else {
            return FetchedContext(
                text: "[Calendar Context]\nCannot access calendar. Access denied or not requested.")
        }

        let now = Date()
        let endDate: Date

        switch timeFrame {
        case .today:
            endDate = Calendar.current.date(byAdding: .day, value: 1, to: now)!
        case .week:
            endDate = Calendar.current.date(byAdding: .day, value: 7, to: now)!
        case .month:
            endDate = Calendar.current.date(byAdding: .month, value: 1, to: now)!
        case .all:
            endDate = Calendar.current.date(byAdding: .day, value: 14, to: now)!
        }

        let predicate = eventStore.predicateForEvents(withStart: now, end: endDate, calendars: nil)
        let events = eventStore.events(matching: predicate).sorted { $0.startDate < $1.startDate }

        guard !events.isEmpty else {
            return FetchedContext(
                text:
                    "[Calendar Context]\nNo upcoming events in the requested timeframe (\(timeFrame.rawValue))."
            )
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short

        var contextStr = "[Upcoming Calendar Events - \(timeFrame.rawValue)]\n"
        for event in events.prefix(15) {
            let start = formatter.string(from: event.startDate)
            let end = formatter.string(from: event.endDate)
            contextStr += "- \(event.title ?? "Untitled") (\(start) to \(end))\n"
        }

        return FetchedContext(text: contextStr.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

public class ReminderContextFetcher: ContextFetching {
    public var intentType: String { return "reminder" }
    private let eventStore = EKEventStore()

    public init() {}

    public func canHandle(intent: ContextIntent) -> Bool {
        if case .reminder = intent { return true }
        return false
    }

    public func fetchContext(for intent: ContextIntent) async -> FetchedContext? {
        guard ConfigManager.shared.config.aiConfig.isReminderContextEnabled else { return nil }
        guard case .reminder(_) = intent else { return nil }

        let status = EKEventStore.authorizationStatus(for: .reminder)
        var isAuthorized = false
        if #available(macOS 14.0, *) {
            isAuthorized = (status == .authorized || status == .fullAccess)
        } else {
            isAuthorized = (status == .authorized)
        }

        guard isAuthorized else {
            return FetchedContext(
                text:
                    "[Reminders Context]\nCannot access reminders. Access denied or not requested.")
        }

        let predicate = eventStore.predicateForIncompleteReminders(
            withDueDateStarting: nil, ending: nil, calendars: nil)

        return await withCheckedContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                guard let reminders = reminders, !reminders.isEmpty else {
                    continuation.resume(
                        returning: FetchedContext(
                            text: "[Reminders Context]\nNo incomplete reminders."))
                    return
                }

                var contextStr = "[Incomplete Reminders]\n"
                for reminder in reminders.prefix(15) {
                    let title = reminder.title ?? "Untitled"
                    let priority = reminder.priority > 0 ? "(Priority: \(reminder.priority))" : ""
                    var due = ""
                    if let dueDateComponents = reminder.dueDateComponents,
                        let date = Calendar.current.date(from: dueDateComponents)
                    {
                        let formatter = DateFormatter()
                        formatter.dateStyle = .short
                        due = "[Due: \(formatter.string(from: date))]"
                    }
                    contextStr += "- \(title) \(priority) \(due)\n"
                }
                continuation.resume(
                    returning: FetchedContext(
                        text: contextStr.trimmingCharacters(in: .whitespacesAndNewlines)))
            }
        }
    }
}

public class AIMemoryContextFetcher: ContextFetching {
    public var intentType: String { return "system" }

    public init() {}

    public func canHandle(intent: ContextIntent) -> Bool {
        // Memory should always be injected if enabled
        if case .system = intent { return true }
        return false
    }

    public func fetchContext(for intent: ContextIntent) async -> FetchedContext? {
        guard ConfigManager.shared.config.aiConfig.isMemoryEnabled else { return nil }

        let passiveEntries = AIMemoryManager.shared.entries.filter { $0.type == .passive }
        guard !passiveEntries.isEmpty else { return nil }

        var contextStr = "[Persistent Memory]\n"
        contextStr +=
            "The following are important facts or preferences about the user from previous interactions:\n"

        let sortedEntries = passiveEntries.sorted(by: { $0.timestamp > $1.timestamp })
        for entry in sortedEntries {
            contextStr += "- \(entry.content)\n"
        }

        return FetchedContext(text: contextStr.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

public class NotesContextFetcher: ContextFetching {
    public var intentType: String { return "notes" }

    public init() {}

    public func canHandle(intent: ContextIntent) -> Bool {
        if case .notes = intent { return true }
        return false
    }

    public func fetchContext(for intent: ContextIntent) async -> FetchedContext? {
        guard ConfigManager.shared.config.aiConfig.isNotesContextEnabled else { return nil }
        guard case .notes(let query) = intent else { return nil }
        guard let notesPath = ConfigManager.shared.config.aiConfig.notesDirectoryPath,
            !notesPath.isEmpty
        else {
            return FetchedContext(
                text: "[Notes Context]\nNotes folder is not selected in Settings.")
        }

        let fileManager = FileManager.default
        let url = URL(fileURLWithPath: notesPath)

        guard
            let enumerator = fileManager.enumerator(
                at: url, includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants])
        else {
            return FetchedContext(
                text: "[Notes Context]\nFailed to access notes directory: \(notesPath)")
        }

        let allowedExtensions = [
            "txt", "md", "csv", "json", "swift", "py", "js", "html", "css", "yaml", "yml", "log",
            "sh",
        ]
        var files: [URL] = []

        for case let fileURL as URL in enumerator {
            let ext = fileURL.pathExtension.lowercased()
            if allowedExtensions.contains(ext) {
                files.append(fileURL)
            }
        }

        if files.isEmpty {
            return FetchedContext(
                text: "[Notes Context]\nNo readable files found in the Notes directory.")
        }

        // Check if query mentions any specific file
        var matchedFiles: [URL] = []
        let queryWords = query.components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { !$0.isEmpty }

        for file in files {
            let filename = file.lastPathComponent.lowercased()
            let nameWithoutExt = file.deletingPathExtension().lastPathComponent.lowercased()

            var matched = false
            if query.contains(filename) || query.contains(nameWithoutExt) {
                matched = true
            } else {
                // Fuzzy match to handle typos
                if !nameWithoutExt.contains(" ") && nameWithoutExt.count >= 4 {
                    let threshold = Swift.max(1, nameWithoutExt.count / 3)
                    for word in queryWords {
                        if word.count >= 4 {
                            if levenshteinDistance(word, nameWithoutExt) <= threshold {
                                matched = true
                                break
                            }
                        }
                    }
                }
            }

            if matched {
                matchedFiles.append(file)
            }
        }

        if matchedFiles.isEmpty {
            // No specific file requested, just list the names
            var contextStr = "[Notes Directory Files]\nAvailable readable files:\n"
            for file in files {
                // Show relative path from notes directory
                let relativePath = file.path.replacingOccurrences(of: url.path + "/", with: "")
                contextStr += "- \(relativePath)\n"
            }
            contextStr += "\n(To read a file's content, ask about it by name)"
            return FetchedContext(text: contextStr)
        } else {
            // Specific file(s) requested, read contents
            var contextStr = "[Notes File Contents]\n"
            for file in matchedFiles {
                let relativePath = file.path.replacingOccurrences(of: url.path + "/", with: "")
                if let content = try? String(contentsOf: file, encoding: .utf8) {
                    contextStr += "--- File: \(relativePath) ---\n"
                    if content.count > 10000 {
                        contextStr +=
                            "[SYSTEM INSTRUCTION: This file is too large to inject into context (\(content.count) characters, limit is 10000). Please apologize to the user and say the file is too big to read.]\n\n"
                    } else {
                        contextStr += content
                        contextStr += "\n\n"
                    }
                } else {
                    contextStr +=
                        "--- File: \(relativePath) ---\n(Could not read content natively)\n\n"
                }
            }
            return FetchedContext(text: contextStr.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let empty = [Int](repeating: 0, count: s2.count + 1)
        var last = [Int](0...s2.count)

        for (i, char1) in s1.enumerated() {
            var cur = [i + 1] + empty
            for (j, char2) in s2.enumerated() {
                cur[j + 1] = char1 == char2 ? last[j] : Swift.min(last[j], last[j + 1], cur[j]) + 1
            }
            last = cur
        }
        return last.last ?? 0
    }
}

public class ActiveMemoryContextFetcher: ContextFetching {
    public var intentType: String { return "activeMemory" }

    public init() {}

    public func canHandle(intent: ContextIntent) -> Bool {
        if case .activeMemory = intent { return true }
        return false
    }

    public func fetchContext(for intent: ContextIntent) async -> FetchedContext? {
        guard ConfigManager.shared.config.aiConfig.isMemoryEnabled else { return nil }
        guard case .activeMemory(let query) = intent else { return nil }

        let activeEntries = AIMemoryManager.shared.entries.filter { $0.type == .active }
        guard !activeEntries.isEmpty else { return nil }

        var matchedEntries: [MemoryEntry] = []
        let queryWords = query.components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { !$0.isEmpty }

        for entry in activeEntries {
            var matched = false
            let contentLower = entry.content.lowercased()
            let titleLower = entry.title.lowercased()
            let categoryLower = entry.category.lowercased()

            if contentLower.contains(query) || titleLower.contains(query)
                || categoryLower.contains(query)
            {
                matched = true
            } else {
                for word in queryWords {
                    if word.count >= 4
                        && (contentLower.contains(word) || titleLower.contains(word)
                            || categoryLower.contains(word))
                    {
                        matched = true
                        break
                    }
                }
            }

            if matched {
                matchedEntries.append(entry)
            }
        }

        if matchedEntries.isEmpty {
            return nil
        }

        var contextStr = "[Active Memory Search Results]\n"
        contextStr +=
            "The user has asked you to remember the following information in the past:\n\n"

        let sortedEntries = matchedEntries.sorted(by: { $0.timestamp > $1.timestamp })
        for entry in sortedEntries {
            contextStr += "--- \(entry.title) (Category: \(entry.category)) ---\n"
            contextStr += "\(entry.content)\n\n"
        }

        return FetchedContext(text: contextStr.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
