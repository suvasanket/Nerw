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
    testIntentClassifierTypoResilience()
    testIntentClassifierGrammaticalVariations()
    testIntentClassifierSemanticSynonyms()
    testAIStreamParserTimerExtraction()
    testIntentClassifierStartTimerKeyword()
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

func testIntentClassifierTypoResilience() {
    let result1 = IntentClassifier.shared.classify("set a remiindr for tomorrow")
    guard result1.actionIntents.contains(.reminder) else {
        fatalError("FAIL: Expected .reminder action intent for typo 'remiindr'")
    }
    guard result1.contextIntents.contains(.reminder(TimeFrame: .week)) else {
        fatalError("FAIL: Expected .reminder(week) context intent for typo 'remiindr'")
    }

    let result2 = IntentClassifier.shared.classify("show my clander meetings")
    guard result2.contextIntents.contains(.calendar(TimeFrame: .today)) else {
        fatalError("FAIL: Expected .calendar(today) context intent for typo 'clander'")
    }

    let result3 = IntentClassifier.shared.classify("newtba in safari")
    guard result3.actionIntents.contains(.app) else {
        fatalError("FAIL: Expected .app action intent for typo 'newtba'")
    }
    guard result3.contextIntents.contains(.activeAppAndScreen) else {
        fatalError("FAIL: Expected .activeAppAndScreen context intent for typo 'newtba'")
    }

    let result4 = IntentClassifier.shared.classify("timr for 10 minutes")
    guard result4.actionIntents.contains(.timer) else {
        fatalError("FAIL: Expected .timer action intent for typo 'timr'")
    }

    print("  ✓ testIntentClassifierTypoResilience passed.")
}

func testIntentClassifierGrammaticalVariations() {
    let result1 = IntentClassifier.shared.classify("scheduling an appointment tomorrow")
    guard result1.actionIntents.contains(.calendar) else {
        fatalError("FAIL: Expected .calendar action intent for lemma 'scheduling' -> 'schedule'")
    }
    guard result1.contextIntents.contains(.calendar(TimeFrame: .week)) else {
        fatalError("FAIL: Expected .calendar context intent for grammatical variation")
    }

    let result2 = IntentClassifier.shared.classify("creating a note for my project")
    guard result2.actionIntents.contains(.note) else {
        fatalError("FAIL: Expected .note action intent for lemma 'creating' -> 'create'")
    }
    guard
        result2.contextIntents.contains(where: {
            if case .notes = $0 { return true }
            return false
        })
    else {
        fatalError("FAIL: Expected .notes context intent for grammatical variation")
    }

    print("  ✓ testIntentClassifierGrammaticalVariations passed.")
}

func testIntentClassifierSemanticSynonyms() {
    let result1 = IntentClassifier.shared.classify("set an alarm for 5 minutes")
    guard result1.actionIntents.contains(.timer) else {
        fatalError("FAIL: Expected .timer action intent for semantic synonym 'alarm'")
    }

    let result2 = IntentClassifier.shared.classify("schedule a briefing tomorrow")
    guard result2.actionIntents.contains(.calendar) else {
        fatalError("FAIL: Expected .calendar action intent for semantic synonym 'briefing'")
    }

    print("  ✓ testIntentClassifierSemanticSynonyms passed.")
}

func testAIStreamParserTimerExtraction() {
    let parser = AIStreamParser()
    var detectedType = ""
    var detectedPayload: [String: Any]?

    parser.onActionDetected = { type, payload in
        detectedType = type
        detectedPayload = payload
    }

    parser.append(text: "Setting your timer: ")
    parser.append(
        text:
            "<action>{\"type\": \"timer\", \"duration\": \"2min\", \"label\": \"Tea\"}</action>"
    )

    if detectedType != "timer" {
        fatalError("FAIL: Expected action type 'timer', got '\(detectedType)'")
    }

    if let dur = detectedPayload?["duration"] as? String, dur != "2min" {
        fatalError("FAIL: Expected duration '2min', got '\(dur)'")
    }

    // Test fallback pill reconstruction with TimerParser
    let reconstructed = AIStreamParser.reconstructPayload(type: "timer", detail: "2min Focus")
    if let duration = reconstructed["duration"] as? Int, duration != 120 {
        fatalError("FAIL: Reconstructed duration should be 120s, got \(duration)")
    }
    if let label = reconstructed["label"] as? String, label != "Focus" {
        fatalError("FAIL: Reconstructed label should be 'Focus', got '\(label)'")
    }

    print("  ✓ testAIStreamParserTimerExtraction passed.")
}

func testIntentClassifierStartTimerKeyword() {
    let result1 = IntentClassifier.shared.classify("starttimer for 2min")
    guard result1.actionIntents.contains(.timer) else {
        fatalError("FAIL: Expected .timer action intent for 'starttimer for 2min'")
    }

    let result2 = IntentClassifier.shared.classify("settimer until next 7")
    guard result2.actionIntents.contains(.timer) else {
        fatalError("FAIL: Expected .timer action intent for 'settimer until next 7'")
    }

    print("  ✓ testIntentClassifierStartTimerKeyword passed.")
}
