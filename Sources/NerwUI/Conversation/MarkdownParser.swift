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

        // 0. Cleanup HTML and citations
        let brPattern = "<br\\s*/?>"
        replaceMatches(pattern: brPattern, in: attrStr) { match, str in
            str.replaceCharacters(in: match.range, with: "\n")
        }

        let citationPattern = "【[^】]+】"
        replaceMatches(pattern: citationPattern, in: attrStr) { match, str in
            str.replaceCharacters(in: match.range, with: "")
        }

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 2
        paragraphStyle.paragraphSpacing = 4
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
                    .foregroundColor: NSColor.white,
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
                    .foregroundColor: NSColor.white,
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

        // 7. Tables
        let tablePattern = "(?m)^(?:\\|[^\n]*\\|\\s*\\n?)+"
        replaceMatches(pattern: tablePattern, in: attrStr) { match, str in
            if str.attribute(
                NerwCodeBlockBackgroundKey, at: match.range.location, effectiveRange: nil) != nil
            {
                return
            }

            let tableText = (str.string as NSString).substring(with: match.range)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let lines = tableText.components(separatedBy: .newlines)

            let parsedRows = lines.map { line -> [String] in
                var trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("|") { trimmed.removeFirst() }
                if trimmed.hasSuffix("|") { trimmed.removeLast() }
                return trimmed.components(separatedBy: "|").map {
                    $0.trimmingCharacters(in: .whitespaces)
                }
            }

            guard parsedRows.count >= 2 else { return }

            let textTable = NSTextTable()
            textTable.layoutAlgorithm = .automatic
            textTable.collapsesBorders = true

            let resultTable = NSMutableAttributedString()

            var rowIndex = 0
            for (i, row) in parsedRows.enumerated() {
                if i == 1
                    && row.allSatisfy({ $0.allSatisfy { $0 == "-" || $0 == ":" || $0 == " " } })
                {
                    continue
                }

                for (colIndex, cellText) in row.enumerated() {
                    let block = NSTextTableBlock(
                        table: textTable, startingRow: rowIndex, rowSpan: 1,
                        startingColumn: colIndex, columnSpan: 1)

                    block.backgroundColor = NSColor.clear
                    block.setBorderColor(accentColor.withAlphaComponent(0.3))
                    block.setWidth(1.0, type: .absoluteValueType, for: .border)

                    if rowIndex == 0 {
                        block.setWidth(0.0, type: .absoluteValueType, for: .border, edge: .minY)
                    }
                    if rowIndex == parsedRows.count - 1 {
                        block.setWidth(0.0, type: .absoluteValueType, for: .border, edge: .maxY)
                    }
                    if colIndex == 0 {
                        block.setWidth(0.0, type: .absoluteValueType, for: .border, edge: .minX)
                    }
                    if colIndex == row.count - 1 {
                        block.setWidth(0.0, type: .absoluteValueType, for: .border, edge: .maxX)
                    }

                    block.setWidth(8.0, type: .absoluteValueType, for: .padding)

                    let cellStyle = NSMutableParagraphStyle()
                    cellStyle.textBlocks = [block]
                    cellStyle.alignment = .left

                    let isHeader = (i == 0)
                    let cellFont =
                        isHeader
                        ? NSFont.systemFont(ofSize: baseFont.pointSize, weight: .bold) : baseFont

                    let cellParsed =
                        MarkdownParser.parse(
                            markdown: cellText, baseFont: cellFont, textColor: textColor,
                            accentColor: accentColor
                        ).mutableCopy() as! NSMutableAttributedString
                    cellParsed.addAttribute(
                        .paragraphStyle, value: cellStyle,
                        range: NSRange(location: 0, length: cellParsed.length))
                    cellParsed.append(
                        NSAttributedString(
                            string: "\n",
                            attributes: [
                                .font: cellFont,
                                .foregroundColor: textColor,
                                .paragraphStyle: cellStyle,
                            ]))

                    resultTable.append(cellParsed)
                }
                rowIndex += 1
            }

            resultTable.addAttribute(
                NerwCodeBlockBackgroundKey, value: textColor.withAlphaComponent(0.08),
                range: NSRange(location: 0, length: resultTable.length))
            str.replaceCharacters(in: match.range, with: resultTable)
        }

        // 8. Action Pills
        // Tag format emitted by AIStreamParser: ![action:type] or ![action:type|detail]
        // Memory tags are stripped silently — the brain icon in the card corner covers it.
        let actionPattern = "!\\[action:([^\\]|]+)(?:\\|([^\\]]*))?\\]"
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
                .trimmingCharacters(in: .whitespaces)

            // Strip surrounding whitespace for ALL tags to avoid double-newlines or inline mess
            var deleteRange = match.range
            let nsString = str.string as NSString
            while deleteRange.location > 0 {
                let charStr = nsString.substring(
                    with: NSRange(location: deleteRange.location - 1, length: 1))
                if charStr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    deleteRange.location -= 1
                    deleteRange.length += 1
                } else {
                    break
                }
            }
            while deleteRange.location + deleteRange.length < nsString.length {
                let charStr = nsString.substring(
                    with: NSRange(
                        location: deleteRange.location + deleteRange.length, length: 1))
                if charStr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    deleteRange.length += 1
                } else {
                    break
                }
            }

            // Resolve optional detail string embedded in the tag
            let detailRange = match.range(at: 2)
            let embeddedDetail: String? =
                detailRange.location != NSNotFound && detailRange.length > 0
                ? (str.string as NSString).substring(with: detailRange) : nil

            // Per-action icon + tint + display text
            let symbolName: String
            let tintColor: NSColor
            let displayText: String

            switch actionType.lowercased() {
            case "timer":
                symbolName = "timer"
                tintColor = NSColor.systemOrange
                displayText = embeddedDetail.map { " \($0)" } ?? ""
            case "reminder":
                symbolName = "bell.badge.fill"
                tintColor = NSColor.systemTeal
                displayText = embeddedDetail.map { " \($0)" } ?? ""
            case "calendar":
                symbolName = "calendar.badge.plus"
                tintColor = NSColor.systemGreen
                displayText = embeddedDetail.map { " \($0)" } ?? ""
            case "memory":
                symbolName = "brain.fill"
                tintColor = NSColor.systemCyan
                displayText = embeddedDetail.map { " \($0)" } ?? ""
            case "menubar":
                symbolName = "menubar.dock.rectangle"
                tintColor = NSColor.systemPink
                displayText = embeddedDetail.map { " \($0)" } ?? ""
            case "search":
                symbolName = "magnifyingglass"
                tintColor = NSColor.systemIndigo
                displayText = embeddedDetail.map { " \($0)" } ?? ""
            default:
                symbolName = "wand.and.sparkles"
                tintColor = NSColor.systemPurple
                displayText = embeddedDetail.map { " \($0)" } ?? ""
            }

            let pillContent = Self.createActionPill(
                iconName: symbolName,
                text: displayText,
                color: tintColor,
                font: baseFont,
                actionType: actionType,
                actionPayload: embeddedDetail ?? ""
            )

            // Prepend a newline if not at the start to prevent inline overlapping
            if deleteRange.location > 0 {
                pillContent.insert(
                    NSAttributedString(string: "\n", attributes: [.font: baseFont]), at: 0)
            }

            // Append a newline if not at the end so following text starts on the next line
            if deleteRange.location + deleteRange.length < attrStr.length {
                pillContent.append(NSAttributedString(string: "\n", attributes: [.font: baseFont]))
            }

            str.replaceCharacters(in: deleteRange, with: pillContent)
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

    private static func createActionPill(
        iconName: String, text: String, color: NSColor, font: NSFont, actionType: String,
        actionPayload: String
    ) -> NSMutableAttributedString {
        let textFont = NSFont.systemFont(ofSize: font.pointSize, weight: .medium)
        let foregroundColor = NSColor.black.withAlphaComponent(0.6)
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: textFont,
            .foregroundColor: foregroundColor,
        ]

        let textSize = (text as NSString).size(withAttributes: textAttributes)

        let pillHeight: CGFloat = 24.0
        let iconSize: CGFloat = 14.0
        let iconPaddingLeft: CGFloat = 4.0
        let iconSpacing: CGFloat = 4.0
        let textPaddingRight: CGFloat = 8.0

        let totalWidth =
            iconPaddingLeft + iconSize + iconSpacing + textSize.width + textPaddingRight
        let size = NSSize(width: totalWidth, height: pillHeight)

        let image = NSImage(size: size, flipped: false) { rect in
            // 1. Draw pill background
            color.setFill()
            let bgPath = NSBezierPath(
                roundedRect: rect, xRadius: pillHeight / 2, yRadius: pillHeight / 2)
            bgPath.fill()

            // 2. Draw dark circle for icon
            let iconBgRect = NSRect(x: 0, y: 0, width: pillHeight, height: pillHeight)
            NSColor.black.withAlphaComponent(0.15).setFill()
            let iconBgPath = NSBezierPath(ovalIn: iconBgRect)
            iconBgPath.fill()

            // 3. Draw Icon
            let config = NSImage.SymbolConfiguration(
                pointSize: font.pointSize - 3, weight: .semibold)
            if let iconImage = NSImage(systemSymbolName: iconName, accessibilityDescription: nil)?
                .withSymbolConfiguration(config)
            {
                iconImage.isTemplate = true
                foregroundColor.set()
                let iconRect = NSRect(
                    x: iconPaddingLeft, y: (pillHeight - iconSize) / 2, width: iconSize,
                    height: iconSize)
                iconImage.draw(in: iconRect)
            }

            // 4. Draw Text
            let textY = (pillHeight - textSize.height) / 2
            let textRect = NSRect(
                x: iconPaddingLeft + iconSize + iconSpacing, y: textY,
                width: textSize.width, height: textSize.height)
            (text as NSString).draw(in: textRect, withAttributes: textAttributes)

            return true
        }

        let attachment = NSTextAttachment()
        attachment.image = image
        let yOffset = (font.capHeight - pillHeight) / 2.0
        attachment.bounds = NSRect(x: 0, y: yOffset, width: size.width, height: size.height)

        let attrString = NSMutableAttributedString(attachment: attachment)

        // Add paragraph style for spacing
        let pillStyle = NSMutableParagraphStyle()
        pillStyle.lineSpacing = 6
        pillStyle.paragraphSpacing = 12

        attrString.addAttributes(
            [
                NerwInlineActionBackgroundKey: color,
                .paragraphStyle: pillStyle,
            ], range: NSRange(location: 0, length: attrString.length))

        return attrString
    }
}
