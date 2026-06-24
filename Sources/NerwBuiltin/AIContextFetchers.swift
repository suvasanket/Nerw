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

        let entries = AIMemoryManager.shared.entries
        guard !entries.isEmpty else { return nil }

        var contextStr = "[Persistent Memory]\n"
        contextStr +=
            "The following are important facts or preferences about the user from previous interactions:\n"

        let sortedEntries = entries.sorted(by: { $0.timestamp > $1.timestamp })
        for entry in sortedEntries {
            contextStr += "- \(entry.content)\n"
        }

        return FetchedContext(text: contextStr.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
