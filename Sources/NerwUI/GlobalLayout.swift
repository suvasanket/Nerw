import CoreGraphics
import Foundation
import NerwCore

public struct GlobalLayout {
    /// Unified width for main panel and split pane
    public static var mainWidth: CGFloat {
        CGFloat(ConfigManager.shared.config.layoutConfig.mainWidth)
    }

    /// Standard height for split pane and secondary windows
    public static var mainHeight: CGFloat {
        CGFloat(ConfigManager.shared.config.layoutConfig.mainHeight)
    }

    /// Shared corner radius for all primary UI panels
    public static var cornerRadius: CGFloat {
        CGFloat(ConfigManager.shared.config.layoutConfig.cornerRadius)
    }

    /// Horizontal margins for UI elements matching the panel design
    public static var horizontalMargin: CGFloat {
        CGFloat(ConfigManager.shared.config.layoutConfig.horizontalMargin)
    }

    // MARK: - Typography

    /// Font size for primary search input fields
    public static var fontSizeSearch: CGFloat {
        CGFloat(ConfigManager.shared.config.layoutConfig.fontSizeSearch)
    }

    /// Font size for search result titles
    public static var fontSizeResultTitle: CGFloat {
        CGFloat(ConfigManager.shared.config.layoutConfig.fontSizeResultTitle)
    }

    /// Font size for search result subtitles
    public static var fontSizeResultSubtitle: CGFloat {
        CGFloat(ConfigManager.shared.config.layoutConfig.fontSizeResultSubtitle)
    }

    /// Font size for items in the Split Pane (e.g. Clipboard Manager)
    public static var fontSizeSplitPaneItem: CGFloat {
        CGFloat(ConfigManager.shared.config.layoutConfig.fontSizeSplitPaneItem)
    }

    /// Size for the primary search lens icon in the main panel
    public static var iconSizeMain: CGFloat {
        CGFloat(ConfigManager.shared.config.layoutConfig.iconSizeMain)
    }
}
