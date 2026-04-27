import Foundation

// MARK: - Protocol

/// Protocol that all Nerw extensions must conform to.
public protocol NerwExtension {
    /// Called when the user types a query with this extension's trigger.
    func query(input: QueryInput) -> [NerwResult]

    /// Called when the user triggers a function-based action.
    func perform(action: ActionInput)
}

/// Default empty implementation — extensions that only return URL actions can skip this.
extension NerwExtension {
    public func perform(action: ActionInput) {}
}

// MARK: - Input Types

/// Input received during a query.
public struct QueryInput {
    public let query: String
    public let triggers: [String]
    public let settings: [String: Any]

    public init(query: String, triggers: [String] = [], settings: [String: Any] = [:]) {
        self.query = query
        self.triggers = triggers
        self.settings = settings
    }
}

/// Input received when triggering an action.
public struct ActionInput {
    public let function: String
    public let args: [String]
    public let formValues: [String: String]
    public let settings: [String: Any]

    public init(
        function: String, args: [String] = [], formValues: [String: String] = [:],
        settings: [String: Any] = [:]
    ) {
        self.function = function
        self.args = args
        self.formValues = formValues
        self.settings = settings
    }
}

// MARK: - Theme Configuration

/// Resolved theme configuration provided by the host.
public struct NerwThemeConfig {
    public let backgroundMaterial: String
    public let tintColorHex: String?
    public let tintOpacity: Double
    public let cornerRadius: Double
    public let borderColorHex: String
    public let borderOpacity: Double
    public let borderWidth: Double
    public let innerGlowEnabled: Bool
    public let innerGlowColorHex: String
    public let innerGlowOpacity: Double
    public let fontName: String?
    public let foregroundColorHex: String?
    public let selectionBackgroundColorHex: String?
    public let selectionForegroundColorHex: String?
    public let hintColorHex: String?

    public init(from settings: [String: Any]) {
        let themeData = settings["_theme"] as? [String: Any] ?? [:]

        self.backgroundMaterial = themeData["backgroundMaterial"] as? String ?? "fullScreenUI"
        self.tintColorHex = themeData["tintColorHex"] as? String
        self.tintOpacity = themeData["tintOpacity"] as? Double ?? 0.15
        self.cornerRadius = themeData["cornerRadius"] as? Double ?? 28.0
        self.borderColorHex = themeData["borderColorHex"] as? String ?? "#FFFFFF"
        self.borderOpacity = themeData["borderOpacity"] as? Double ?? 0.18
        self.borderWidth = themeData["borderWidth"] as? Double ?? 1.0
        self.innerGlowEnabled = themeData["innerGlowEnabled"] as? Bool ?? false
        self.innerGlowColorHex = themeData["innerGlowColorHex"] as? String ?? "#FFFFFF"
        self.innerGlowOpacity = themeData["innerGlowOpacity"] as? Double ?? 0.06
        self.fontName = themeData["fontName"] as? String
        self.foregroundColorHex = themeData["foregroundColorHex"] as? String
        self.selectionBackgroundColorHex = themeData["selectionBackgroundColorHex"] as? String
        self.selectionForegroundColorHex = themeData["selectionForegroundColorHex"] as? String
        self.hintColorHex = themeData["hintColorHex"] as? String
    }
}
