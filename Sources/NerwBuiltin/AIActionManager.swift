import EventKit
import Foundation
import NerwUtils

public class AIActionManager {
    public static let shared = AIActionManager()

    private let eventStore = EKEventStore()

    private init() {
        // No init required
    }

    public func handleAction(type: String, payload: [String: Any]) {
        switch type {
        case "timer":
            handleTimer(payload: payload)
        case "reminder":
            handleReminder(payload: payload)
        case "calendar":
            handleCalendar(payload: payload)
        default:
            Logger.shared.warning("AIActionManager: Unknown action type '\(type)'")
            DispatchQueue.main.async {
                Nerw.notify("AI Action: \(type)\n\(payload)", level: .info)
            }
        }
    }

    private func handleTimer(payload: [String: Any]) {
        guard let duration = payload["duration"] as? Int else {
            Logger.shared.error(
                "AIActionManager: Timer payload missing 'duration'. Payload: \(payload)")
            return
        }
        let label = payload["label"] as? String ?? "AI Timer"

        Logger.shared.info("AIActionManager: Timer set for \(duration) seconds.")
        DispatchQueue.main.async {
            Nerw.notify("Timer set for \(duration) seconds: \(label)", level: .info)
        }

        DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(duration)) {
            DispatchQueue.main.async {
                Nerw.notify("Timer Finished: \(label)", level: .info)
            }
        }
    }

    private func handleReminder(payload: [String: Any]) {
        guard let title = payload["title"] as? String else {
            Logger.shared.error(
                "AIActionManager: Reminder payload missing 'title'. Payload: \(payload)")
            return
        }

        requestRemindersAccess { [weak self] granted in
            guard let self = self else { return }
            guard granted else {
                Logger.shared.error("AIActionManager: Reminders access denied.")
                DispatchQueue.main.async {
                    Nerw.notify("Reminders access denied.", level: .error)
                }
                return
            }

            let reminder = EKReminder(eventStore: self.eventStore)
            reminder.title = title
            reminder.calendar = self.eventStore.defaultCalendarForNewReminders()

            do {
                try self.eventStore.save(reminder, commit: true)
                Logger.shared.info("AIActionManager: Added reminder '\(title)'")
                DispatchQueue.main.async {
                    Nerw.notify("Added Reminder: \(title)", level: .info)
                }
            } catch {
                Logger.shared.error(
                    "AIActionManager: Failed to save reminder: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    Nerw.notify(
                        "Failed to save reminder: \(error.localizedDescription)", level: .error)
                }
            }
        }
    }

    private func handleCalendar(payload: [String: Any]) {
        guard let title = payload["title"] as? String,
            let dateString = payload["date"] as? String
        else {
            Logger.shared.error(
                "AIActionManager: Calendar payload missing 'title' or 'date'. Payload: \(payload)")
            return
        }

        let formatter = ISO8601DateFormatter()
        // If the date string doesn't include time zone but ends with Z or uses offset
        guard let startDate = formatter.date(from: dateString) else {
            Logger.shared.error("AIActionManager: Invalid ISO8601 date string: \(dateString)")
            DispatchQueue.main.async {
                Nerw.notify("Invalid date format for calendar event.", level: .error)
            }
            return
        }

        requestCalendarAccess { [weak self] granted in
            guard let self = self else { return }
            guard granted else {
                Logger.shared.error("AIActionManager: Calendar access denied.")
                DispatchQueue.main.async {
                    Nerw.notify("Calendar access denied.", level: .error)
                }
                return
            }

            let event = EKEvent(eventStore: self.eventStore)
            event.title = title
            event.startDate = startDate
            event.endDate = startDate.addingTimeInterval(3600)  // Default 1 hour duration
            event.calendar = self.eventStore.defaultCalendarForNewEvents

            do {
                try self.eventStore.save(event, span: .thisEvent, commit: true)
                Logger.shared.info(
                    "AIActionManager: Added calendar event '\(title)' for \(startDate)")
                DispatchQueue.main.async {
                    Nerw.notify("Added Event: \(title)", level: .info)
                }
            } catch {
                Logger.shared.error(
                    "AIActionManager: Failed to save calendar event: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    Nerw.notify(
                        "Failed to save event: \(error.localizedDescription)", level: .error)
                }
            }
        }
    }

    private func requestRemindersAccess(completion: @escaping (Bool) -> Void) {
        if #available(macOS 14.0, *) {
            eventStore.requestFullAccessToReminders { granted, error in
                completion(granted)
            }
        } else {
            eventStore.requestAccess(to: .reminder) { granted, error in
                completion(granted)
            }
        }
    }

    private func requestCalendarAccess(completion: @escaping (Bool) -> Void) {
        if #available(macOS 14.0, *) {
            eventStore.requestFullAccessToEvents { granted, error in
                completion(granted)
            }
        } else {
            eventStore.requestAccess(to: .event) { granted, error in
                completion(granted)
            }
        }
    }
}
