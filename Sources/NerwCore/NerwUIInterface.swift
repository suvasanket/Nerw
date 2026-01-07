import Cocoa

// Protocol defining interactions with the UI
public protocol NerwUIApplication {
    func hideWindow()
    func showWindow()
    func setQuery(_ query: String)
}

// Singleton accessor for UI
// usage: NerwSystem.shared.ui?.hideWindow()
public class NerwSystem {
    public static let shared = NerwSystem()

    public var ui: NerwUIApplication?

    private init() {}
}
