import Foundation
import NerwAction
import NerwBuiltin
import NerwCore
import NerwUtils

func runTests() {
    print("[Testing] Starting SearchService functional tests...")

    testAppQuickActionsCreation()
    testRegularAppHasNoQuickAction()
    testInlineArgFallbackExtraction()
    testSearchServiceCaching()
    testMemoryLimits()
    testAppSearchScopes()
    testSystemActionsDoNotIncludeSleep()

    print("[Testing] Starting Builtin & UI tests...")
    testClipboardManagerStorage()
    testSplitPaneInitialization()
    runMainPanelTests()
    runActionContextTests()
    runExtensionPanelTests()
    runNotificationTests()
    runTextExpansionTests()
    runBookmarkTests()
    runDaemonTests()
    runAITests()

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

func testSearchServiceCaching() {
    SearchService.shared.clearCache()
    // By default, asyncUpdate: false makes it synchronous load
    SearchService.shared.loadCache(asyncUpdate: false)
    let candidates = SearchService.shared.getCandidates()
    if candidates.isEmpty {
        fatalError("FAIL: Candidates should not be empty after synchronous cache load.")
    }

    // Test clear
    SearchService.shared.clearCache()
    // It should transparently rebuild since it's empty
    let newCandidates = SearchService.shared.getCandidates()
    if newCandidates.isEmpty {
        fatalError("FAIL: getCandidates must fallback and rebuild if cache is cleared.")
    }
    print("  ✓ testSearchServiceCaching passed.")
}

func testMemoryLimits() {
    SearchService.shared.clearCache()

    // Simulate low threshold
    MemoryManager.shared.maxAllowedMemoryMB = 0.0001

    if !MemoryManager.shared.isMemoryHigh() {
        fatalError("FAIL: memory manager did not trip when threshold is 0.0001 MB")
    }

    // load cache - should immediately clear and do nothing further
    SearchService.shared.loadCache(asyncUpdate: false)
    // fallback mechanisms in getCandidates should still return things
    let candidates = SearchService.shared.getCandidates()
    if candidates.isEmpty {
        fatalError("FAIL: getCandidates must return candidates even when memory is high")
    }

    // restore
    MemoryManager.shared.maxAllowedMemoryMB = 40.0
    print("  ✓ testMemoryLimits passed.")
}

func testAppSearchScopes() {
    let scopes = Set(AppSearch.shared.monitoredSearchScopePaths)
    let homeApplicationsPath = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Applications").path

    let expectedScopes: Set<String> = [
        "/Applications",
        "/System/Applications",
        "/System/Library/CoreServices",
        homeApplicationsPath,
    ]

    if scopes != expectedScopes {
        fatalError("FAIL: AppSearch scopes changed unexpectedly. Got \(scopes)")
    }

    if scopes.contains("/Users") {
        fatalError("FAIL: AppSearch must not index the entire /Users tree.")
    }

    print("  ✓ testAppSearchScopes passed.")
}

func testSystemActionsDoNotIncludeSleep() {
    let systemActions = System.shared.getAllActions()

    if systemActions.contains(where: {
        $0.id == "nerw.system.sleep" || $0.title == "Sleep" || $0.triggers.contains("sleep")
    }) {
        fatalError("FAIL: System actions must not include Sleep.")
    }

    print("  ✓ testSystemActionsDoNotIncludeSleep passed.")
}

// Execute
runTests()
