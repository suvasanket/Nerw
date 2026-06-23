import Cocoa
import Foundation

public let NerwNodeKey = NSAttributedString.Key("NerwNode")
public let NerwInlineActionBackgroundKey = NSAttributedString.Key("NerwInlineActionBackground")
public let NerwInlineActionBorderKey = NSAttributedString.Key("NerwInlineActionBorder")

public enum NerwNodeType: String {
    case bold
    case codeBlock
    case link
}

public struct NerwMarkdownNode {
    public let type: NerwNodeType
    public let content: String
}

public struct MarkdownParser {

    public static func parse(
        markdown: String, baseFont: NSFont, textColor: NSColor, accentColor: NSColor
    ) -> NSAttributedString {
        let attrStr = NSMutableAttributedString(
            string: markdown,
            attributes: [
                .font: baseFont,
                .foregroundColor: textColor,
            ])

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 2
        paragraphStyle.paragraphSpacing = 8
        attrStr.addAttribute(
            .paragraphStyle, value: paragraphStyle,
            range: NSRange(location: 0, length: attrStr.length))

        // 1. Code Blocks — strip the ``` fences and show only inner content with background
        //    Pattern captures: group 1 = optional language tag, group 2 = inner code body
        let codeBlockPattern = "```([a-zA-Z]*)\\n?([\\s\\S]*?)(?:```|$)"
        replaceMatches(pattern: codeBlockPattern, in: attrStr) { match, str in
            let lang = (str.string as NSString).substring(with: match.range(at: 1))
            let body = (str.string as NSString).substring(with: match.range(at: 2))

            let codeFont = NSFont.monospacedSystemFont(
                ofSize: baseFont.pointSize - 1, weight: .regular)

            // Trim a single trailing newline that the closing ``` introduces
            let trimmedBody = body.hasSuffix("\n") ? String(body.dropLast()) : body

            let codeContent = NSMutableAttributedString()

            if !lang.isEmpty {
                // Language label line — marked with NerwCodeLangKey for separator drawing
                let langSmallFont = NSFont.monospacedSystemFont(
                    ofSize: baseFont.pointSize - 2, weight: .semibold)
                let langAttr = NSMutableAttributedString(
                    string: lang,
                    attributes: [
                        .font: langSmallFont,
                        NerwCodeBlockBackgroundKey: textColor.withAlphaComponent(0.08),
                        NerwCodeLangKey: true,
                        .foregroundColor: accentColor.withAlphaComponent(0.7),
                        .paragraphStyle: paragraphStyle,
                    ])
                codeContent.append(langAttr)
                // Separator newline (not marked with NerwCodeLangKey)
                let sep = NSAttributedString(
                    string: "\n",
                    attributes: [
                        .font: codeFont,
                        NerwCodeBlockBackgroundKey: textColor.withAlphaComponent(0.08),
                        .foregroundColor: accentColor,
                        .paragraphStyle: paragraphStyle,
                    ])
                codeContent.append(sep)
            }

            // Code body
            let bodyAttr = NSMutableAttributedString(
                string: trimmedBody,
                attributes: [
                    .font: codeFont,
                    NerwCodeBlockBackgroundKey: textColor.withAlphaComponent(0.08),
                    NerwNodeKey: NerwMarkdownNode(type: .codeBlock, content: trimmedBody),
                    .foregroundColor: accentColor,
                    .paragraphStyle: paragraphStyle,
                ])
            codeContent.append(bodyAttr)

            str.replaceCharacters(in: match.range, with: codeContent)
        }

        // 2. Inline Code — skip anything already inside a code block
        let inlineCodePattern = "(?<!`)`([^`\\n]+)`(?!`)"
        replaceMatches(pattern: inlineCodePattern, in: attrStr) { match, str in
            guard match.range.location < str.length else { return }
            if str.attribute(
                NerwCodeBlockBackgroundKey, at: match.range.location, effectiveRange: nil) != nil
            {
                return
            }

            let innerRange = match.range(at: 1)
            let innerText = (str.string as NSString).substring(with: innerRange)
            let codeFont = NSFont.monospacedSystemFont(
                ofSize: baseFont.pointSize - 1, weight: .regular)
            let codeContent = NSMutableAttributedString(
                string: innerText,
                attributes: [
                    .font: codeFont,
                    NerwInlineCodeBackgroundKey: textColor.withAlphaComponent(0.12),
                    .foregroundColor: accentColor,
                    .paragraphStyle: paragraphStyle,
                ])
            str.replaceCharacters(in: match.range, with: codeContent)
        }

        // 3. Bold — skip code regions
        let boldPattern = "(?:\\*\\*|__)(.+?)(?:\\*\\*|__)"
        replaceMatches(pattern: boldPattern, in: attrStr) { match, str in
            guard match.range.location < str.length else { return }
            if str.attribute(
                NerwCodeBlockBackgroundKey, at: match.range.location, effectiveRange: nil) != nil
            {
                return
            }
            if str.attribute(
                NerwInlineCodeBackgroundKey, at: match.range.location, effectiveRange: nil) != nil
            {
                return
            }

            let content =
                str.attributedSubstring(from: match.range(at: 1)).mutableCopy()
                as! NSMutableAttributedString
            let currentFont =
                content.attribute(.font, at: 0, effectiveRange: nil) as? NSFont ?? baseFont
            let boldFont = NSFontManager.shared.convert(currentFont, toHaveTrait: .boldFontMask)
            let rawText = content.string
            content.addAttribute(
                .font, value: boldFont, range: NSRange(location: 0, length: content.length))
            content.addAttribute(
                NerwNodeKey, value: NerwMarkdownNode(type: .bold, content: rawText),
                range: NSRange(location: 0, length: content.length))
            str.replaceCharacters(in: match.range, with: content)
        }

        // 4. Italic — skip code regions
        let italicPattern = "(?:\\*|_)(?<!\\*)(.+?)(?:\\*|_)(?!\\*)"
        replaceMatches(pattern: italicPattern, in: attrStr) { match, str in
            guard match.range.location < str.length else { return }
            if str.attribute(
                NerwCodeBlockBackgroundKey, at: match.range.location, effectiveRange: nil) != nil
            {
                return
            }
            if str.attribute(
                NerwInlineCodeBackgroundKey, at: match.range.location, effectiveRange: nil) != nil
            {
                return
            }

            let content =
                str.attributedSubstring(from: match.range(at: 1)).mutableCopy()
                as! NSMutableAttributedString
            let currentFont =
                content.attribute(.font, at: 0, effectiveRange: nil) as? NSFont ?? baseFont
            let italicFont = NSFontManager.shared.convert(currentFont, toHaveTrait: .italicFontMask)
            content.addAttribute(
                .font, value: italicFont, range: NSRange(location: 0, length: content.length))
            str.replaceCharacters(in: match.range, with: content)
        }

        // 5. Headings — skip code regions; replace the full `## Text` match with just `Text`
        //    and explicitly set clean attributes (no code background bleed)
        let headingPattern = "^(#{1,6})\\s+(.+)$"
        if let regex = try? NSRegularExpression(
            pattern: headingPattern, options: [.anchorsMatchLines])
        {
            let matches = regex.matches(
                in: attrStr.string, range: NSRange(location: 0, length: attrStr.length))
            for match in matches.reversed() {
                guard match.range.location < attrStr.length else { continue }
                if attrStr.attribute(
                    NerwCodeBlockBackgroundKey, at: match.range.location, effectiveRange: nil)
                    != nil
                {
                    continue
                }
                if attrStr.attribute(
                    NerwInlineCodeBackgroundKey, at: match.range.location, effectiveRange: nil)
                    != nil
                {
                    continue
                }

                let level = match.range(at: 1).length
                let headingFontSize = baseFont.pointSize + CGFloat((7 - level) * 2)
                let headingFont = NSFont.systemFont(ofSize: headingFontSize, weight: .bold)
                let headingText = (attrStr.string as NSString).substring(with: match.range(at: 2))

                // Build heading with ONLY the correct attributes — no leftovers
                let headingParagraph = NSMutableParagraphStyle()
                headingParagraph.lineSpacing = 2
                headingParagraph.paragraphSpacing = 6
                let heading = NSMutableAttributedString(
                    string: headingText,
                    attributes: [
                        .font: headingFont,
                        .foregroundColor: textColor,
                        .paragraphStyle: headingParagraph,
                    ])
                attrStr.replaceCharacters(in: match.range, with: heading)
            }
        }

        // 6. Links — skip code regions
        let linkPattern = "\\[(.+?)\\]\\((.+?)\\)"
        replaceMatches(pattern: linkPattern, in: attrStr) { match, str in
            guard match.range.location < str.length else { return }
            if str.attribute(
                NerwCodeBlockBackgroundKey, at: match.range.location, effectiveRange: nil) != nil
            {
                return
            }
            if str.attribute(
                NerwInlineCodeBackgroundKey, at: match.range.location, effectiveRange: nil) != nil
            {
                return
            }

            let linkText = (str.string as NSString).substring(with: match.range(at: 1))
            let urlString = (str.string as NSString).substring(with: match.range(at: 2))

            if let url = URL(string: urlString) {
                let linkContent = NSMutableAttributedString(
                    string: linkText,
                    attributes: [
                        .font: baseFont,
                        .foregroundColor: accentColor,
                        .link: url,
                        NerwNodeKey: NerwMarkdownNode(type: .link, content: urlString),
                        .underlineStyle: NSUnderlineStyle.single.rawValue,
                        .paragraphStyle: paragraphStyle,
                    ])
                str.replaceCharacters(in: match.range, with: linkContent)
            }
        }

        // 7. Action Pills
        let actionPattern = "!\\[action:(.+?)\\]"
        replaceMatches(pattern: actionPattern, in: attrStr) { match, str in
            guard match.range.location < str.length else { return }
            if str.attribute(
                NerwCodeBlockBackgroundKey, at: match.range.location, effectiveRange: nil) != nil
            {
                return
            }
            if str.attribute(
                NerwInlineCodeBackgroundKey, at: match.range.location, effectiveRange: nil) != nil
            {
                return
            }

            let actionType = (str.string as NSString).substring(with: match.range(at: 1))
            let displayName: String
            switch actionType.lowercased() {
            case "timer": displayName = "Timer"
            case "reminder": displayName = "Reminder"
            case "calendar": displayName = "Calendar"
            case "memory": displayName = "Memory"
            default: displayName = actionType.capitalized
            }

            let pillContent = NSMutableAttributedString()

            // Icon attachment
            if let image = NSImage(
                systemSymbolName: "wand.and.sparkles", accessibilityDescription: nil)
            {
                image.isTemplate = true
                let attachment = NSTextAttachment()
                attachment.image = image
                attachment.bounds = NSRect(x: 0, y: -2, width: 14, height: 14)
                let iconAttr = NSMutableAttributedString(attachment: attachment)
                iconAttr.addAttributes(
                    [
                        .foregroundColor: accentColor,
                        .font: baseFont,
                    ], range: NSRange(location: 0, length: iconAttr.length))
                pillContent.append(iconAttr)
            }

            // Text
            let textFont = NSFont.systemFont(ofSize: baseFont.pointSize - 1, weight: .medium)
            let textAttr = NSAttributedString(
                string: " Action: \(displayName)",
                attributes: [
                    .font: textFont,
                    .foregroundColor: accentColor,
                ])
            pillContent.append(textAttr)

            // Apply background and border keys
            pillContent.addAttributes(
                [
                    NerwInlineActionBackgroundKey: accentColor.withAlphaComponent(0.12),
                    NerwInlineActionBorderKey: accentColor.withAlphaComponent(0.3),
                    .paragraphStyle: paragraphStyle,
                ], range: NSRange(location: 0, length: pillContent.length))

            str.replaceCharacters(in: match.range, with: pillContent)
        }

        return attrStr
    }

    private static func replaceMatches(
        pattern: String, in attrStr: NSMutableAttributedString,
        using handler: (NSTextCheckingResult, NSMutableAttributedString) -> Void
    ) {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return }
        let matches = regex.matches(
            in: attrStr.string, range: NSRange(location: 0, length: attrStr.length))
        for match in matches.reversed() {
            handler(match, attrStr)
        }
    }
}
