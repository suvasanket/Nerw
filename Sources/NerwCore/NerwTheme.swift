import Foundation

public struct NerwTheme: Codable {
    // Background
    public let backgroundMaterial: String
    public let tintColorHex: String?
    public let tintOpacity: Double

    // Shape
    public let cornerRadius: Double
    public let borderColorHex: String
    public let borderOpacity: Double
    public let borderWidth: Double

    // Inner glow
    public let innerGlowEnabled: Bool
    public let innerGlowColorHex: String
    public let innerGlowOpacity: Double

    // Liquid Glass
    public let liquidGlassEnabled: Bool

    // Text
    public let fontName: String?
    public let foregroundColorHex: String?
    public let selectionBackgroundColorHex: String?
    public let selectionForegroundColorHex: String?
    public let hintColorHex: String?

    public init(
        backgroundMaterial: String = "fullScreenUI",
        tintColorHex: String? = nil,
        tintOpacity: Double = 0.15,
        cornerRadius: Double = 28.0,
        borderColorHex: String = "#FFFFFF",
        borderOpacity: Double = 0.18,
        borderWidth: Double = 1.0,
        innerGlowEnabled: Bool = false,
        innerGlowColorHex: String = "#FFFFFF",
        innerGlowOpacity: Double = 0.06,
        fontName: String? = nil,
        foregroundColorHex: String? = nil,
        selectionBackgroundColorHex: String? = nil,
        selectionForegroundColorHex: String? = nil,
        hintColorHex: String? = nil,
        liquidGlassEnabled: Bool = true
    ) {
        self.backgroundMaterial = backgroundMaterial
        self.tintColorHex = tintColorHex
        self.tintOpacity = tintOpacity
        self.cornerRadius = cornerRadius
        self.borderColorHex = borderColorHex
        self.borderOpacity = borderOpacity
        self.borderWidth = borderWidth
        self.innerGlowEnabled = innerGlowEnabled
        self.innerGlowColorHex = innerGlowColorHex
        self.innerGlowOpacity = innerGlowOpacity
        self.fontName = fontName
        self.foregroundColorHex = foregroundColorHex
        self.selectionBackgroundColorHex = selectionBackgroundColorHex
        self.selectionForegroundColorHex = selectionForegroundColorHex
        self.hintColorHex = hintColorHex
        self.liquidGlassEnabled = liquidGlassEnabled
    }

    public static func current() -> NerwTheme {
        let config = ConfigManager.shared.config
        let layout = config.layoutConfig
        let ui = config.uiConfig

        return NerwTheme(
            backgroundMaterial: "fullScreenUI",  // Default for most panels
            tintColorHex: ui?.mainBackgroundColor,
            tintOpacity: 0.15,  // Default tint opacity
            cornerRadius: layout.cornerRadius,
            borderColorHex: "#FFFFFF",
            borderOpacity: 0.18,
            borderWidth: 1.0,
            innerGlowEnabled: false,  // Default is false, styles will override if needed
            innerGlowColorHex: "#FFFFFF",
            innerGlowOpacity: 0.06,
            fontName: ui?.font,
            foregroundColorHex: ui?.mainForegroundColor,
            selectionBackgroundColorHex: ui?.selectionBackgroundColor,
            selectionForegroundColorHex: ui?.selectionForegroundColor,
            hintColorHex: ui?.hintColor,
            liquidGlassEnabled: true
        )
    }
}
