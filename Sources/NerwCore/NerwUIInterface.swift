import Cocoa
import Foundation

public enum NerwNotificationLevel {
    case info
    case warn
    case error
}

// Protocol defining interactions with the UI
public protocol NerwUIApplication {
    func hideWindow()
    func showWindow()
    func setQuery(_ query: String)
    @discardableResult
    func showNotification(
        content: String, level: NerwNotificationLevel, progressive: Bool, id: UUID?
    ) -> UUID
    func dismissNotification(id: UUID)
}

// Singleton accessor for UI
// usage: NerwSystem.shared.ui?.hideWindow()
public class NerwSystem {
    public static let shared = NerwSystem()

    public var ui: NerwUIApplication?

    private init() {}
}
