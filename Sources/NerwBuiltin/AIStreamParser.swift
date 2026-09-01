import Foundation
import NerwUtils

public class AIStreamParser {
    public var onTextReady: ((String) -> Void)?
    public var onThinkingStateChanged: ((Bool) -> Void)?
    public var onActionDetected: ((String, [String: Any]) -> Void)?
    public var onActionFormat: ((String, [String: Any]) -> String)?

    private var buffer = ""
    private var isThinking = false
    private var isAction = false
    private var actionPayloadBuffer = ""
    private var currentText = ""
    public private(set) var rawText = ""

    public init() {}

    public func append(text: String) {
        rawText += text
        buffer += text
        processBuffer()
    }

    public func flush() {
        if !isThinking && !isAction && !buffer.isEmpty {
            appendToCurrentText(buffer)
            buffer = ""
        }

        let trimmed = currentText.replacingOccurrences(
            of: "\\s+$", with: "", options: .regularExpression)
        if trimmed != currentText {
            currentText = trimmed
            onTextReady?(currentText)
        }
    }

    private func appendToCurrentText(_ text: String) {
        var strToAppend = text

        if currentText.isEmpty {
            strToAppend = strToAppend.replacingOccurrences(
                of: "^\\s+", with: "", options: .regularExpression)
            if strToAppend.isEmpty { return }
        }

        for char in strToAppend {
            if char == "\n", currentText.hasSuffix("\n\n") {
                continue
            }
            currentText.append(char)
        }

        onTextReady?(currentText)
    }

    private func processBuffer() {
        while !buffer.isEmpty {
            if isThinking {
                if let endRange = buffer.range(of: "</think>") {
                    isThinking = false
                    buffer.removeSubrange(buffer.startIndex..<endRange.upperBound)
                    onThinkingStateChanged?(false)
                } else {
                    if let lastLess = buffer.lastIndex(of: "<") {
                        buffer.removeSubrange(buffer.startIndex..<lastLess)
                    } else {
                        buffer = ""
                    }
                    break
                }
            } else if isAction {
                if let endRange = buffer.range(of: "</action>") {
                    actionPayloadBuffer += String(buffer[buffer.startIndex..<endRange.lowerBound])
                    isAction = false
                    buffer.removeSubrange(buffer.startIndex..<endRange.upperBound)

                    if let data = actionPayloadBuffer.data(using: .utf8),
                        let json = try? JSONSerialization.jsonObject(with: data, options: [])
                            as? [String: Any],
                        let type = json["type"] as? String
                    {
                        onActionDetected?(type, json)
                        if let formatter = onActionFormat {
                            let detail = formatter(type, json)
                            let tag =
                                detail.isEmpty ? "![action:\(type)]" : "![action:\(type)|\(detail)]"
                            appendToCurrentText(tag)
                        } else {
                            appendToCurrentText("![action:\(type)]")
                        }
                    } else {
                        Logger.shared.warning(
                            "AIStreamParser: Failed to parse action JSON: \(actionPayloadBuffer)")
                    }
                    actionPayloadBuffer = ""
                } else {
                    if let lastLess = buffer.lastIndex(of: "<") {
                        actionPayloadBuffer += String(buffer[buffer.startIndex..<lastLess])
                        buffer.removeSubrange(buffer.startIndex..<lastLess)
                    } else {
                        actionPayloadBuffer += buffer
                        buffer = ""
                    }
                    break
                }
            } else {
                let lessRange = buffer.range(of: "<")
                let actionRange = buffer.range(of: "![action:")

                if let actRange = actionRange,
                    lessRange == nil || actRange.lowerBound < lessRange!.lowerBound
                {
                    if let endRange = buffer.range(
                        of: "]", range: actRange.upperBound..<buffer.endIndex)
                    {
                        let beforeTag = String(
                            buffer[buffer.startIndex..<actRange.lowerBound])
                        if !beforeTag.isEmpty {
                            appendToCurrentText(beforeTag)
                        }
                        let tagContent = String(
                            buffer[actRange.upperBound..<endRange.lowerBound])
                        let fullTag = String(
                            buffer[actRange.lowerBound...endRange.lowerBound])
                        buffer.removeSubrange(buffer.startIndex...endRange.lowerBound)

                        let components = tagContent.split(separator: "|", maxSplits: 1)
                            .map(String.init)
                        if let type = components.first {
                            let detail = components.count > 1 ? components[1] : ""
                            let payload = Self.reconstructPayload(
                                type: type, detail: detail)
                            onActionDetected?(type, payload)
                        }
                        appendToCurrentText(fullTag)
                        continue
                    } else {
                        let before = String(
                            buffer[buffer.startIndex..<actRange.lowerBound])
                        if !before.isEmpty {
                            appendToCurrentText(before)
                            buffer.removeSubrange(
                                buffer.startIndex..<actRange.lowerBound)
                        }
                        break
                    }
                } else if let nextTagRange = lessRange {
                    let beforeTag = String(buffer[buffer.startIndex..<nextTagRange.lowerBound])
                    if !beforeTag.isEmpty {
                        appendToCurrentText(beforeTag)
                    }

                    buffer.removeSubrange(buffer.startIndex..<nextTagRange.lowerBound)

                    if buffer.hasPrefix("<think>") {
                        isThinking = true
                        buffer.removeSubrange(
                            buffer.startIndex..<buffer.index(buffer.startIndex, offsetBy: 7))
                        onThinkingStateChanged?(true)
                    } else if buffer.hasPrefix("<action>") {
                        isAction = true
                        actionPayloadBuffer = ""
                        buffer.removeSubrange(
                            buffer.startIndex..<buffer.index(buffer.startIndex, offsetBy: 8))
                    } else {
                        if "<think>".hasPrefix(buffer) || "<action>".hasPrefix(buffer)
                            || "</think>".hasPrefix(buffer) || "</action>".hasPrefix(buffer)
                        {
                            // Wait for more data
                            break
                        } else {
                            appendToCurrentText(String(buffer.first!))
                            buffer.removeFirst()
                        }
                    }
                } else {
                    appendToCurrentText(buffer)
                    buffer = ""
                }
            }
        }
    }

    public static func reconstructPayload(type: String, detail: String) -> [String: Any] {
        switch type {
        case "app":
            if detail.hasPrefix("menubar: ") {
                let path = String(detail.dropFirst("menubar: ".count))
                    .trimmingCharacters(in: .whitespaces)
                return ["type": "app", "action": "menubar", "path": path]
            } else {
                return ["type": "app", "action": "menubar", "path": detail]
            }
        case "timer":
            if let parsed = TimerParser.shared.parse(query: detail) {
                return ["type": "timer", "duration": Int(parsed.duration), "label": parsed.label]
            } else {
                return ["type": "timer", "duration": 60, "label": detail]
            }
        case "reminder":
            return ["type": "reminder", "title": detail]
        case "calendar":
            return ["type": "calendar", "title": detail, "date": ""]
        case "note":
            return ["type": "note", "operation": "append", "filename": "", "content": detail]
        case "memory":
            return ["type": "memory", "action": "save", "content": detail]
        case "email":
            return ["type": "email", "subject": detail, "body": ""]
        default:
            return ["type": type, "detail": detail]
        }
    }
}
