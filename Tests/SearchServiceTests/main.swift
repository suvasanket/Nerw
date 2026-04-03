import Foundation
import NerwBuiltin
import NerwCore

func runTests() {
    print("[Testing] Starting SearchService functional tests...")

    testAppQuickActionsCreation()
    testRegularAppHasNoQuickAction()
    testInlineArgFallbackExtraction()

    print("[Testing] All SearchService tests PASSED.")

    runBackendTests()
}

func testAppQuickActionsCreation() {
    let service = SearchService.shared

    let testedApps = [
        ("Activity Monitor", "/System/Applications/Utilities/Activity Monitor.app", "Quit Process"),
        ("finder", "/System/Library/CoreServices/Finder.app", "Find File"),
        ("shortcuts", "/System/Applications/Shortcuts.app", "Run Shortcut"),
        ("System Settings", "/System/Applications/System Settings.app", "System Settings"),
    ]

    for (appName, path, expectedSubtitle) in testedApps {
        let appInfo = AppSearch.AppInfo(name: appName, path: path)
        let action = service.createAction(for: appInfo)

        guard case .hybrid(_, let innerBox) = action.type else {
            fatalError("FAIL: Action for \(appName) must be of type .hybrid. Got \(action.type)")
        }

        let quickAction = innerBox.value
        if quickAction.title != expectedSubtitle {
            fatalError(
                "FAIL: Quick Action title mismatch for \(appName). Expected \(expectedSubtitle), Got \(quickAction.title)"
            )
        }

        guard case .args(let placeholder, _, _) = quickAction.type else {
            fatalError("FAIL: QuickAction for \(appName) must be of type .args")
        }

        if placeholder.isEmpty {
            fatalError("FAIL: Placeholder must not be empty for \(appName)")
        }
    }
    print("  ✓ testAppQuickActionsCreation passed.")
}

func testRegularAppHasNoQuickAction() {
    let service = SearchService.shared
    let appInfo = AppSearch.AppInfo(name: "Calculator", path: "/System/Applications/Calculator.app")
    let action = service.createAction(for: appInfo)

    guard case .instant(_) = action.type else {
        fatalError(
            "FAIL: Standard applications without explicit mappings must resolve to .instant type. Got \(action.type)"
        )
    }
    print("  ✓ testRegularAppHasNoQuickAction passed.")
}

func testInlineArgFallbackExtraction() {
    let fakeAction = NerwAction(
        id: "fake.inline",
        title: "Fake Command",
        subtitle: "Doing %s",
        icon: .system("globe"),
        triggers: ["fake"],
        type: .inlineArg(perform: { _, _ in }, searcher: nil)
    )

    let triggerQuery = "fake argument goes here"
    let lowerQuery = triggerQuery.lowercased()

    var matched = false
    var extractedArg = ""

    for trigger in fakeAction.triggers {
        if lowerQuery.starts(with: trigger.lowercased() + " ") {
            extractedArg = String(triggerQuery.dropFirst(trigger.count + 1)).trimmingCharacters(
                in: .whitespaces)
            matched = true
            break
        }
    }

    if !matched { fatalError("FAIL: Trigger must match string.") }
    if extractedArg != "argument goes here" {
        fatalError("FAIL: Inline argument extraction failed. Got '\(extractedArg)'")
    }

    print("  ✓ testInlineArgFallbackExtraction passed.")
}

// Execute
runTests()
