import Foundation
import NerwUtils

public class AIStreamParser {
    public var onTextReady: ((String) -> Void)?
    public var onThinkingStateChanged: ((Bool) -> Void)?
    public var onActionDetected: ((String, [String: Any]) -> Void)?

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
            currentText += buffer
            buffer = ""
            onTextReady?(currentText)
        }
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
                        currentText += "![action:\(type)]\n"
                        onTextReady?(currentText)
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
                        currentText += beforeTag
                        onTextReady?(currentText)
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
                            currentText += String(buffer.first!)
                            buffer.removeFirst()
                            onTextReady?(currentText)
                        }
                    }
                } else {
                    currentText += buffer
                    buffer = ""
                    onTextReady?(currentText)
                }
            }
        }
    }
}
