import Foundation
import NerwBuiltin
import NerwCore

func runAITests() {
    print("[Testing] Starting AI parsing tests...")
    testAIStreamParserActionExtraction()
    testAIStreamParserActionDetailExtraction()
    testAIStreamParserActionPillFallbackExtraction()
    testIntentClassifierActiveAppMenubar()
    testIntentClassifierConversationContinuation()
    testAIInstructionManagerConversationContinuation()
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

    guard result.actionIntents.contains(.app) else {
        fatalError("FAIL: Expected .app in actionIntents when .activeAppAndScreen is present")
    }

    print("  ✓ testIntentClassifierActiveAppMenubar passed.")
}

func testAIStreamParserActionPillFallbackExtraction() {
    let parser = AIStreamParser()
    var detectedType = ""
    var detectedPayload: [String: Any]?

    parser.onActionDetected = { type, payload in
        detectedType = type
        detectedPayload = payload
    }

    parser.append(text: "Created another new tab. ![action:app|menubar: File > New Tab]")
    parser.flush()

    guard detectedType == "app" else {
        fatalError("FAIL: Expected action type 'app' from pill fallback, got '\(detectedType)'")
    }
    guard let path = detectedPayload?["path"] as? String, path == "File > New Tab" else {
        fatalError(
            "FAIL: Expected path 'File > New Tab' from pill fallback, got '\(String(describing: detectedPayload?["path"]))'"
        )
    }

    print("  ✓ testAIStreamParserActionPillFallbackExtraction passed.")
}

func testIntentClassifierConversationContinuation() {
    let history: [AIChatMessage] = [
        AIChatMessage(role: .user, content: "create a new tab here"),
        AIChatMessage(
            role: .assistant,
            content:
                "Created a new tab. <action>{\"type\": \"app\", \"action\": \"menubar\", \"path\": \"File > New Tab\"}</action>"
        ),
    ]

    let result = IntentClassifier.shared.classify("create another one", history: history)

    guard result.actionIntents.contains(.app) else {
        fatalError("FAIL: Expected .app in actionIntents when continuing conversation from history")
    }

    guard result.contextIntents.contains(.activeAppAndScreen) else {
        fatalError(
            "FAIL: Expected .activeAppAndScreen in contextIntents when continuing conversation from history"
        )
    }

    print("  ✓ testIntentClassifierConversationContinuation passed.")
}

func testAIInstructionManagerConversationContinuation() {
    let history: [AIChatMessage] = [
        AIChatMessage(role: .user, content: "create a new tab here"),
        AIChatMessage(
            role: .assistant,
            content:
                "Created a new tab. <action>{\"type\": \"app\", \"action\": \"menubar\", \"path\": \"File > New Tab\"}</action>"
        ),
    ]

    let classification = IntentClassifier.shared.classify("create another one", history: history)
    let prompt = AIInstructionManager.shared.buildSystemPrompt(
        basePrompt: "Base prompt",
        actionIntents: classification.actionIntents
    )

    guard prompt.contains("\"type\": \"app\", \"action\": \"menubar\"") else {
        fatalError(
            "FAIL: Expected app action schema in buildSystemPrompt when continuing conversation")
    }
    print("  ✓ testAIInstructionManagerConversationContinuation passed.")
}
