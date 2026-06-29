import Cocoa

public let NerwCodeBlockBackgroundKey = NSAttributedString.Key("NerwCodeBlockBackground")
public let NerwInlineCodeBackgroundKey = NSAttributedString.Key("NerwInlineCodeBackground")
public let NerwCodeLangKey = NSAttributedString.Key("NerwCodeLang")

public class RoundedBackgroundLayoutManager: NSLayoutManager {
    public override func drawBackground(forGlyphRange glyphsToShow: NSRange, at origin: NSPoint) {
        super.drawBackground(forGlyphRange: glyphsToShow, at: origin)

        guard let textStorage = textStorage else { return }
        let charRange = characterRange(forGlyphRange: glyphsToShow, actualGlyphRange: nil)

        // 1. Code Block Backgrounds
        textStorage.enumerateAttribute(NerwCodeBlockBackgroundKey, in: charRange, options: []) {
            value, range, _ in
            guard let bgColor = value as? NSColor else { return }

            let glRange = self.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
            var minY = CGFloat.greatestFiniteMagnitude
            var maxY = -CGFloat.greatestFiniteMagnitude
            var tc: NSTextContainer?

            self.enumerateLineFragments(forGlyphRange: glRange) {
                _, usedRect, textContainer, _, _ in
                tc = textContainer
                minY = min(minY, usedRect.minY)
                maxY = max(maxY, usedRect.maxY)
            }

            guard let textContainer = tc, minY < maxY else { return }

            // Use lineFragmentPadding so the rect aligns with text bounds.
            // The vertical/horizontal padding gives breathing room for the corners to show.
            let lfp = textContainer.lineFragmentPadding
            let cw = textContainer.size.width
            let pad: CGFloat = 8

            var bgRect = NSRect(
                x: lfp - pad,
                y: minY - pad,
                width: (cw - 2 * lfp) + 2 * pad,
                height: (maxY - minY) + 2 * pad
            )
            bgRect.origin.x += origin.x
            bgRect.origin.y += origin.y

            // Ensure we never draw outside the view's coordinate space
            if bgRect.origin.x < 0 {
                bgRect.size.width += bgRect.origin.x
                bgRect.origin.x = 0
            }

            bgColor.setFill()
            NSBezierPath(roundedRect: bgRect, xRadius: 8, yRadius: 8).fill()

            // 1b. Draw separator line between language label and code body
            textStorage.enumerateAttribute(NerwCodeLangKey, in: range, options: []) {
                lv, langRange, _ in
                guard (lv as? Bool) == true else { return }

                let langGlyphRange = self.glyphRange(
                    forCharacterRange: langRange, actualCharacterRange: nil)
                var langMaxY: CGFloat = 0

                self.enumerateLineFragments(forGlyphRange: langGlyphRange) {
                    _, usedRect, _, _, _ in
                    langMaxY = max(langMaxY, usedRect.maxY)
                }

                guard langMaxY > 0 else { return }

                // Faint horizontal rule
                let lineY = langMaxY + pad / 2
                let lineRect = NSRect(
                    x: bgRect.minX + 4,
                    y: lineY + origin.y - 0.5,
                    width: bgRect.width - 8,
                    height: 1
                )
                NSColor.white.withAlphaComponent(0.1).setFill()
                lineRect.fill()
            }
        }

        // 2. Inline Code Backgrounds — tight rect per token
        textStorage.enumerateAttribute(NerwInlineCodeBackgroundKey, in: charRange, options: []) {
            value, range, _ in
            guard let color = value as? NSColor else { return }

            let glRange = self.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
            color.setFill()

            self.enumerateLineFragments(forGlyphRange: glRange) {
                _, _, textContainer, lineGlyphRange, _ in
                let intersection = NSIntersectionRange(glRange, lineGlyphRange)
                guard intersection.length > 0 else { return }

                var r = self.boundingRect(forGlyphRange: intersection, in: textContainer)
                r.origin.x -= 3
                r.origin.y -= 2
                r.size.width += 6
                r.size.height += 4
                r.origin.x += origin.x
                r.origin.y += origin.y

                NSBezierPath(roundedRect: r, xRadius: 4, yRadius: 4).fill()
            }
        }

    }
}
