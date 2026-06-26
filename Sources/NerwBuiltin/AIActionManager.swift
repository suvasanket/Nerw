import AppKit
import EventKit
import Foundation
import NerwCore
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
        case "memory":
            handleMemory(payload: payload)
        case "note":
            handleNote(payload: payload)
        case "menubar":
            handleMenubar(payload: payload)
        case "email":
            handleEmail(payload: payload)
        default:
            Logger.shared.warning("AIActionManager: Unknown action type '\(type)'")
            DispatchQueue.main.async {
                Nerw.notify("AI Action: \(type)\n\(payload)", level: .info)
            }
        }
    }

    private func handleMemory(payload: [String: Any]) {
        guard let content = payload["content"] as? String else {
            Logger.shared.error(
                "AIActionManager: Memory payload missing 'content'. Payload: \(payload)")
            return
        }

        let importance = payload["importance"] as? Int ?? 5

        AIMemoryManager.shared.save(content: content, importance: importance)
        Logger.shared.info("AIActionManager: Saved memory: \(content) (importance: \(importance))")
        DispatchQueue.main.async {
            Nerw.notify("Memory Saved", level: .info)
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

        let dateString = payload["date"] as? String

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

            if let dateString = dateString {
                let formatter = ISO8601DateFormatter()
                if let dueDate = formatter.date(from: dateString) {
                    let components = Calendar.current.dateComponents(
                        [.year, .month, .day, .hour, .minute, .second], from: dueDate)
                    reminder.dueDateComponents = components
                    reminder.addAlarm(EKAlarm(absoluteDate: dueDate))
                } else {
                    Logger.shared.error(
                        "AIActionManager: Invalid ISO8601 date string for reminder: \(dateString)")
                }
            }

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

    private func handleNote(payload: [String: Any]) {
        guard let filename = payload["filename"] as? String,
            let content = payload["content"] as? String,
            let operation = payload["operation"] as? String
        else {
            Logger.shared.error(
                "AIActionManager: Note payload missing required fields. Payload: \(payload)")
            return
        }

        let aiConfig = ConfigManager.shared.config.aiConfig
        guard let notesDirPath = aiConfig.notesDirectoryPath else {
            Logger.shared.error("AIActionManager: notesDirectoryPath not configured.")
            DispatchQueue.main.async {
                Nerw.notify("Notes directory not configured in Settings.", level: .error)
            }
            return
        }

        let notesDir = URL(fileURLWithPath: notesDirPath)

        // Basic path traversal prevention
        guard !filename.contains("../") && !filename.contains("..\\") else {
            Logger.shared.error("AIActionManager: Invalid note filename: \(filename)")
            return
        }

        let fileURL = notesDir.appendingPathComponent(filename)

        do {
            switch operation {
            case "append":
                if FileManager.default.fileExists(atPath: fileURL.path) {
                    let fileHandle = try FileHandle(forWritingTo: fileURL)
                    fileHandle.seekToEndOfFile()
                    if let data = ("\n" + content).data(using: .utf8) {
                        fileHandle.write(data)
                    }
                    fileHandle.closeFile()
                } else {
                    try content.write(to: fileURL, atomically: true, encoding: .utf8)
                }
            case "create", "overwrite":
                try content.write(to: fileURL, atomically: true, encoding: .utf8)
            default:
                Logger.shared.warning("AIActionManager: Unknown note operation '\(operation)'")
                return
            }

            Logger.shared.info("AIActionManager: \(operation) note at \(fileURL.path)")
            DispatchQueue.main.async {
                Nerw.notify("Saved note: \(filename)", level: .info)
            }
        } catch {
            Logger.shared.error(
                "AIActionManager: Failed to write note: \(error.localizedDescription)")
            DispatchQueue.main.async {
                Nerw.notify("Failed to save note: \(error.localizedDescription)", level: .error)
            }
        }
    }

    private func handleMenubar(payload: [String: Any]) {
        guard let pathString = payload["path"] as? String, !pathString.isEmpty else {
            Logger.shared.error(
                "AIActionManager: Menubar payload missing 'path' string. Payload: \(payload)")
            return
        }

        let menubarActions = MenubarSearch.shared.getMenubarActions()

        let targetAction = menubarActions.first { action in
            let subtitle = action.subtitle
            guard let range = subtitle.range(of: "Menu: ") else { return false }
            let extractedPath = String(subtitle[range.upperBound...])
            return extractedPath.lowercased() == pathString.lowercased()
        }

        guard let actionToPerform = targetAction else {
            Logger.shared.error("AIActionManager: Menubar path '\(pathString)' not found.")
            DispatchQueue.main.async {
                Nerw.notify("Failed to find menubar item: \(pathString)", level: .error)
            }
            return
        }

        if case .instant(let performBlock) = actionToPerform.type {
            performBlock(actionToPerform)
            Logger.shared.info(
                "AIActionManager: Successfully executed menubar path: \(pathString)"
            )
            DispatchQueue.main.async {
                Nerw.notify("Executed: \(pathString)", level: .info)
            }
        } else {
            Logger.shared.error("AIActionManager: Menubar action is not of type .instant")
        }
    }

    private func handleEmail(payload: [String: Any]) {
        let to = payload["to"] as? String
        let subject = payload["subject"] as? String ?? ""
        let body = payload["body"] as? String ?? ""

        if let service = NSSharingService(named: .composeEmail) {
            if let to = to, !to.isEmpty {
                service.recipients = [to]
            }
            service.subject = subject

            DispatchQueue.main.async {
                if service.canPerform(withItems: [body]) {
                    service.perform(withItems: [body])
                    Logger.shared.info("AIActionManager: Opened email compose window")
                    Nerw.notify("Drafting email...", level: .info)
                } else {
                    self.fallbackToMailto(to: to, subject: subject, body: body)
                }
            }
        } else {
            DispatchQueue.main.async {
                self.fallbackToMailto(to: to, subject: subject, body: body)
            }
        }
    }

    private func fallbackToMailto(to: String?, subject: String, body: String) {
        var components = URLComponents()
        components.scheme = "mailto"
        if let to = to, !to.isEmpty {
            components.path = to
        }

        var queryItems: [URLQueryItem] = []
        if !subject.isEmpty {
            queryItems.append(URLQueryItem(name: "subject", value: subject))
        }
        if !body.isEmpty {
            queryItems.append(URLQueryItem(name: "body", value: body))
        }
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }

        if let url = components.url {
            NSWorkspace.shared.open(url)
            Logger.shared.info("AIActionManager: Opened mailto URL")
            Nerw.notify("Drafting email...", level: .info)
        } else {
            Logger.shared.error("AIActionManager: Failed to create mailto URL")
            Nerw.notify("Failed to open email client", level: .error)
        }
    }
}
