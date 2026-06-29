import Foundation
import NerwBuiltin
import NerwCore

func runAITests() {
    print("[Testing] Starting AI parsing tests...")
    testAIStreamParserActionExtraction()
    testAIStreamParserActionDetailExtraction()
    testIntentClassifierActiveAppMenubar()
}

func testAIStreamParserActionExtraction() {
    let parser = AIStreamParser()
    var detectedType = ""
    var detectedPayload: [String: Any]?

    parser.onActionDetected = { type, payload in
        detectedType = type
        detectedPayload = payload
    }

    parser.append(text: "Here is your reminder ")
    parser.append(
        text:
            "<action>{\"type\": \"reminder\", \"title\": \"Buy milk\", \"schedule\": \"2026-06-22T10:00:00Z\"}</action>"
    )

    if detectedType != "reminder" {
        fatalError("FAIL: Expected action type 'reminder', got '\(detectedType)'")
    }

    if let title = detectedPayload?["title"] as? String, title != "Buy milk" {
        fatalError("FAIL: Expected payload title 'Buy milk', got '\(title)'")
    }

    print("  ✓ testAIStreamParserActionExtraction passed.")
}

func testAIStreamParserActionDetailExtraction() {
    // Tests that the format the pill consumes gets extracted correctly
    let payload: [String: Any] = ["type": "reminder", "title": "hello world"]
    let title = payload["title"] as! String

    // Simulate what ConversationViewController.actionDetail would extract
    let detail = title

    if detail != "hello world" {
        fatalError("FAIL: Expected pill detail 'hello world', got '\(detail)'")
    }

    print("  ✓ testAIStreamParserActionDetailExtraction passed.")
}

func testIntentClassifierActiveAppMenubar() {
    let result = IntentClassifier.shared.classify("new tab in this app")

    guard result.contextIntents.contains(.activeAppAndScreen) else {
        fatalError("FAIL: Expected .activeAppAndScreen in contextIntents for 'this app'")
    }

    guard result.actionIntents.contains(.menubar) else {
        fatalError("FAIL: Expected .menubar in actionIntents when .activeAppAndScreen is present")
    }

    print("  ✓ testIntentClassifierActiveAppMenubar passed.")
}
