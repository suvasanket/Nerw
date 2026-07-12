import Cocoa
import QuickLookThumbnailing

public class IconUtils {
    public static func getIconAsync(
        for url: URL, size: CGSize, completion: @escaping (NSImage?) -> Void
    ) {
        let resolvedURL = url.resolvingSymlinksInPath()
        let request = QLThumbnailGenerator.Request(
            fileAt: resolvedURL,
            size: size,
            scale: NSScreen.main?.backingScaleFactor ?? 2.0,
            representationTypes: .all
        )

        QLThumbnailGenerator.shared.generateRepresentations(for: request) {
            (representation, type, error) in
            DispatchQueue.main.async {
                if let representation = representation {
                    completion(representation.nsImage)
                } else {
                    completion(nil)
                }
            }
        }
    }
    public static func combinedIcon(
        mainImage finalMain: NSImage,
        subImage finalSub: NSImage,
        subIconScale: CGFloat = 0.55,
        mainIconScale: CGFloat = 1.0,  // Keep at 1.0 to prevent clipping
        isTemplate: Bool = true
    ) -> NSImage {
        let canvasSize = finalMain.size
        let newImage = NSImage(size: canvasSize, flipped: false) { rect in
            // Draw main icon covering the rect
            let dx = rect.width * (1.0 - mainIconScale) / 2.0
            let dy = rect.height * (1.0 - mainIconScale) / 2.0
            let mainRect = rect.insetBy(dx: dx, dy: dy)
            finalMain.draw(in: mainRect)

            // Calculate sub icon rect
            let subAspect = finalSub.size.width / finalSub.size.height
            var subRect = NSRect.zero

            // Base sub icon size on the width (or height if it's smaller)
            let referenceDim = min(rect.width, rect.height)
            let maxSubDim = referenceDim * subIconScale
            if subAspect > 1.0 {
                subRect.size.width = maxSubDim
                subRect.size.height = maxSubDim / subAspect
            } else {
                subRect.size.height = maxSubDim
                subRect.size.width = maxSubDim * subAspect
            }

            // Position sub icon at bottom right corner (overlap main icon)
            let offset = (mainIconScale - 1.0) * referenceDim * 0.15
            subRect.origin.x = rect.width - subRect.width + offset
            subRect.origin.y = -offset

            if let ctx = NSGraphicsContext.current?.cgContext {
                ctx.setBlendMode(.clear)
                let gap = maxSubDim * 0.1
                ctx.fillEllipse(in: subRect.insetBy(dx: -gap, dy: -gap))
                ctx.setBlendMode(.normal)
            }

            finalSub.draw(in: subRect)

            return true
        }

        // Copy the alignment rect from the original symbol so NSImageView lays it out perfectly
        newImage.alignmentRect = finalMain.alignmentRect
        newImage.isTemplate = isTemplate
        return newImage
    }

    public static func combinedIcon(
        mainSymbol: String, mainConfig: NSImage.SymbolConfiguration? = nil,
        subSymbol: String, subConfig: NSImage.SymbolConfiguration? = nil,
        subIconScale: CGFloat = 0.55,
        mainIconScale: CGFloat = 1.0,  // Keep at 1.0 to prevent clipping
        isTemplate: Bool = true
    ) -> NSImage? {
        let mainImageBase = NSImage(systemSymbolName: mainSymbol, accessibilityDescription: nil)
        let mainImage =
            mainConfig != nil ? mainImageBase?.withSymbolConfiguration(mainConfig!) : mainImageBase

        let subImageBase = NSImage(systemSymbolName: subSymbol, accessibilityDescription: nil)
        let subImage =
            subConfig != nil ? subImageBase?.withSymbolConfiguration(subConfig!) : subImageBase

        guard let finalMain = mainImage, let finalSub = subImage else {
            return nil
        }

        return combinedIcon(
            mainImage: finalMain,
            subImage: finalSub,
            subIconScale: subIconScale,
            mainIconScale: mainIconScale,
            isTemplate: isTemplate
        )
    }
}
