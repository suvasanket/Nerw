import CoreGraphics
import Foundation

public struct GlobalLayout {
    /// Unified width for main panel and split pane
    public static var mainWidth: CGFloat = 700

    /// Standard height for split pane and secondary windows
    public static var mainHeight: CGFloat = 500

    /// Shared corner radius for all primary UI panels
    public static var cornerRadius: CGFloat = 28

    /// Horizontal margins for UI elements matching the panel design
    public static var horizontalMargin: CGFloat = 20

    // MARK: - Typography

    /// Font size for primary search input fields
    public static var fontSizeSearch: CGFloat = 25.0

    /// Font size for search result titles
    public static var fontSizeResultTitle: CGFloat = 14.0

    /// Font size for search result subtitles
    public static var fontSizeResultSubtitle: CGFloat = 11.0

    /// Font size for items in the Split Pane (e.g. Clipboard Manager)
    public static var fontSizeSplitPaneItem: CGFloat = 15.0

    /// Size for the primary search lens icon in the main panel
    public static var iconSizeMain: CGFloat = 26.0
}
