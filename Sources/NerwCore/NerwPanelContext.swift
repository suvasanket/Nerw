import CoreGraphics
import Foundation

public class NerwPanelContext {
    public static let shared = NerwPanelContext()

    public private(set) var mainPanelFrame: CGRect = .zero
    public private(set) var configFontName: String?

    private init() {}

    public func update(mainPanelFrame: CGRect) {
        self.mainPanelFrame = mainPanelFrame
    }

    public func update(configFontName: String?) {
        self.configFontName = configFontName
    }

    public func origin(forSize size: CGSize, in screenVisibleFrame: CGRect) -> CGPoint {
        // Position secondary window directly below the main panel if space allows.
        let gap: CGFloat = 12.0
        let centeredX = screenVisibleFrame.origin.x + (screenVisibleFrame.width - size.width) / 2
        let targetY = mainPanelFrame.minY - size.height - gap

        if targetY >= screenVisibleFrame.minY {
            return CGPoint(x: centeredX, y: targetY)
        } else {
            let fallbackY = max(
                screenVisibleFrame.minY,
                screenVisibleFrame.origin.y + (screenVisibleFrame.height - size.height) / 2)
            return CGPoint(x: centeredX, y: fallbackY)
        }
    }

    public func exactOrigin(forSize size: CGSize, in screenVisibleFrame: CGRect) -> CGPoint {
        // Position the new window exactly where the main panel is.
        // It aligns the top of the new window to the top of the main panel, and centers horizontally to main panel.
        let targetX = mainPanelFrame.midX - (size.width / 2)
        // mainPanelFrame.maxY is the top edge (since origin is bottom-left).
        let targetY = mainPanelFrame.maxY - size.height

        return CGPoint(x: targetX, y: targetY)
    }

    public func sideOrigin(forSize size: CGSize, anchorRect: CGRect) -> CGPoint {
        // Position the window to the right of the anchor rect, centered vertically to it.
        return CGPoint(
            x: anchorRect.maxX,
            y: anchorRect.midY - size.height / 2
        )
    }
}
