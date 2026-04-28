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
/// Includes visual styling, layout dimensions, and positioning data
/// so extensions can build their own native-looking panels.
public struct NerwThemeConfig {
    // MARK: - Appearance
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

    // MARK: - Layout — Panel Dimensions
    public let mainPanelWidth: Double
    public let mainPanelHeight: Double

    // MARK: - Layout — Search Field
    public let searchFieldHeight: Double
    public let searchFieldFontSize: Double
    public let searchFieldTopMargin: Double
    public let searchFieldBottomMargin: Double

    // MARK: - Layout — Margins & Spacing
    public let horizontalMargin: Double
    public let iconSize: Double

    // MARK: - Layout — Results
    public let resultRowHeight: Double
    public let resultCellCornerRadius: Double
    public let resultTitleFontSize: Double
    public let resultSubtitleFontSize: Double

    // MARK: - Layout — Separator
    public let separatorHeight: Double
    public let separatorExpandedHeight: Double

    // MARK: - Layout — Split Pane
    public let splitPaneItemFontSize: Double

    // MARK: - Positioning — Main Panel
    public let mainPanelOriginX: Double
    public let mainPanelOriginY: Double
    public let mainPanelFrameWidth: Double
    public let mainPanelFrameHeight: Double

    // MARK: - Positioning — Screen
    public let screenVisibleX: Double
    public let screenVisibleY: Double
    public let screenVisibleWidth: Double
    public let screenVisibleHeight: Double

    public init(from settings: [String: Any]) {
        let themeData = settings["_theme"] as? [String: Any] ?? [:]

        // Appearance
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

        // Layout — Panel
        self.mainPanelWidth = themeData["mainPanelWidth"] as? Double ?? 700.0
        self.mainPanelHeight = themeData["mainPanelHeight"] as? Double ?? 500.0

        // Layout — Search Field
        self.searchFieldHeight = themeData["searchFieldHeight"] as? Double ?? 32.0
        self.searchFieldFontSize = themeData["searchFieldFontSize"] as? Double ?? 25.0
        self.searchFieldTopMargin = themeData["searchFieldTopMargin"] as? Double ?? 12.0
        self.searchFieldBottomMargin = themeData["searchFieldBottomMargin"] as? Double ?? 12.0

        // Layout — Margins & Spacing
        self.horizontalMargin = themeData["horizontalMargin"] as? Double ?? 20.0
        self.iconSize = themeData["iconSize"] as? Double ?? 26.0

        // Layout — Results
        self.resultRowHeight = themeData["resultRowHeight"] as? Double ?? 50.0
        self.resultCellCornerRadius = themeData["resultCellCornerRadius"] as? Double ?? 14.0
        self.resultTitleFontSize = themeData["resultTitleFontSize"] as? Double ?? 14.0
        self.resultSubtitleFontSize = themeData["resultSubtitleFontSize"] as? Double ?? 11.0

        // Layout — Separator
        self.separatorHeight = themeData["separatorHeight"] as? Double ?? 1.0
        self.separatorExpandedHeight = themeData["separatorExpandedHeight"] as? Double ?? 14.0

        // Layout — Split Pane
        self.splitPaneItemFontSize = themeData["splitPaneItemFontSize"] as? Double ?? 15.0

        // Positioning — Main Panel
        self.mainPanelOriginX = themeData["mainPanelOriginX"] as? Double ?? 0.0
        self.mainPanelOriginY = themeData["mainPanelOriginY"] as? Double ?? 0.0
        self.mainPanelFrameWidth = themeData["mainPanelFrameWidth"] as? Double ?? 0.0
        self.mainPanelFrameHeight = themeData["mainPanelFrameHeight"] as? Double ?? 0.0

        // Positioning — Screen
        self.screenVisibleX = themeData["screenVisibleX"] as? Double ?? 0.0
        self.screenVisibleY = themeData["screenVisibleY"] as? Double ?? 0.0
        self.screenVisibleWidth = themeData["screenVisibleWidth"] as? Double ?? 0.0
        self.screenVisibleHeight = themeData["screenVisibleHeight"] as? Double ?? 0.0
    }
}
