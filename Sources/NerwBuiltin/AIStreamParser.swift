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

    public init() {}

    public func append(text: String) {
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
                if let nextTagRange = buffer.range(of: "<") {
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
}
