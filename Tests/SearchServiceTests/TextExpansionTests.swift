import Foundation
import NerwAction
import NerwBuiltin
import NerwUtils

func runTextExpansionTests() {
    print("[Testing] Starting TextExpansion tests...")

    // Redirect storage to a temporary file to avoid polluting/wiping user's database
    let productionURL = NerwPaths.dataDirectory.appendingPathComponent("snippets.json")
    let testURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(
        "snippets_test_\(UUID().uuidString).json")

    SnippetManager.shared.setStorageURL(testURL)
    defer {
        // Restore production URL
        SnippetManager.shared.setStorageURL(productionURL)
        // Clean up test file
        try? FileManager.default.removeItem(at: testURL)
    }

    testSnippetPlaceholderResolution()
    testSnippetMultiplePlaceholders()
    testSnippetEmojiContent()
    testTriggerMapUpdates()
    print("[Testing] All TextExpansion tests PASSED.")
}

func testSnippetPlaceholderResolution() {
    clearSnippets()
    SnippetManager.shared.addSnippet(name: "Test", trigger: ";test", content: "Time: {{HH:mm}}")
    let snippet = SnippetManager.shared.snippets.first!

    let resolved = SnippetManager.shared.resolve(content: snippet.content)

    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm"
    let expectedTime = formatter.string(from: Date())

    if resolved != "Time: \(expectedTime)" {
        fatalError("FAIL: Expected 'Time: \(expectedTime)', got '\(resolved)'")
    }
}

func testSnippetMultiplePlaceholders() {
    clearSnippets()
    SnippetManager.shared.addSnippet(
        name: "Test", trigger: ";test", content: "Year: {{yyyy}}, Month: {{MM}}")
    let snippet = SnippetManager.shared.snippets.first!

    let resolved = SnippetManager.shared.resolve(content: snippet.content)

    let formatterY = DateFormatter()
    formatterY.dateFormat = "yyyy"
    let yyyy = formatterY.string(from: Date())

    let formatterM = DateFormatter()
    formatterM.dateFormat = "MM"
    let mm = formatterM.string(from: Date())

    if resolved != "Year: \(yyyy), Month: \(mm)" {
        fatalError("FAIL: Expected 'Year: \(yyyy), Month: \(mm)', got '\(resolved)'")
    }
}

func testSnippetEmojiContent() {
    clearSnippets()
    SnippetManager.shared.addSnippet(name: "Test", trigger: ";emoji", content: "Hello 🚀🌎")
    let snippet = SnippetManager.shared.snippets.first!

    let resolved = SnippetManager.shared.resolve(content: snippet.content)
    if resolved != "Hello 🚀🌎" {
        fatalError("FAIL: Expected 'Hello 🚀🌎', got '\(resolved)'")
    }
}

func testTriggerMapUpdates() {
    clearSnippets()
    SnippetManager.shared.addSnippet(name: "S1", trigger: ";s1", content: "S1 content")
    if SnippetManager.shared.triggerMap[";s1"] == nil {
        fatalError("FAIL: Expected triggerMap to contain ;s1")
    }

    SnippetManager.shared.addSnippet(name: "S2", trigger: ";s2", content: "S2 content")
    if SnippetManager.shared.triggerMap[";s2"] == nil {
        fatalError("FAIL: Expected triggerMap to contain ;s2")
    }

    let s1 = SnippetManager.shared.snippets.first { $0.name == "S1" }!
    SnippetManager.shared.deleteSnippet(id: s1.id)

    if SnippetManager.shared.triggerMap[";s1"] != nil {
        fatalError("FAIL: Expected triggerMap to NOT contain ;s1")
    }
    if SnippetManager.shared.triggerMap[";s2"] == nil {
        fatalError("FAIL: Expected triggerMap to contain ;s2")
    }

    let s2 = SnippetManager.shared.snippets.first { $0.name == "S2" }!
    SnippetManager.shared.deleteSnippet(id: s2.id)

    if SnippetManager.shared.triggerMap[";s2"] != nil {
        fatalError("FAIL: Expected triggerMap to NOT contain ;s2")
    }
}

private func clearSnippets() {
    let allIds = SnippetManager.shared.snippets.map { $0.id }
    for id in allIds {
        SnippetManager.shared.deleteSnippet(id: id)
    }
}
