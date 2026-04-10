import Foundation
import NerwCore
import NerwSearchBackend
import NerwUI
import NerwUtils

func runActionContextTests() {
    print("[Testing] Starting Action Context tests...")

    testActionContextIncludesModifierAndConfigurationOperations()
    testActionContextHybridIncludesSecondaryOperation()
    testActionPreferenceStorePersistsAndClearsValues()
    testActionContextKeyboardRouting()
    testActionContextSelectionMovement()
    testActionContextTypeSelect()
    testActionContextVisualBridgeHeight()

    print("[Testing] All Action Context tests PASSED.")
}

private func withRestoredActionPreferences(for actionID: String, _ body: () -> Void) {
    let originalAliases = ConfigManager.shared.config.actionAliases[actionID]
    let originalHotkey = ConfigManager.shared.config.actionHotkeys[actionID]

    defer {
        if let originalAliases {
            ConfigManager.shared.config.actionAliases[actionID] = originalAliases
        } else {
            ConfigManager.shared.config.actionAliases.removeValue(forKey: actionID)
        }

        if let originalHotkey {
            ConfigManager.shared.config.actionHotkeys[actionID] = originalHotkey
        } else {
            ConfigManager.shared.config.actionHotkeys.removeValue(forKey: actionID)
        }

        ConfigManager.shared.save()
    }

    body()
}

func testActionContextIncludesModifierAndConfigurationOperations() {
    let actionID = "test.action.context.\(UUID().uuidString)"

    withRestoredActionPreferences(for: actionID) {
        NerwActionPreferenceStore.updateAliases(rawValue: "alpha beta alpha", for: actionID)
        NerwActionPreferenceStore.updateHotkey("Cmd+Shift+K", for: actionID)

        let action = NerwAction(
            id: actionID,
            title: "Search Google",
            subtitle: "Search the web",
            icon: .system("globe"),
            modifiers: [
                .shift: NerwAction.ModifierAction(
                    title: "Lucky Search",
                    subtitle: "Jump straight to the best result",
                    perform: { _ in }
                )
            ],
            type: .instant(perform: { _ in })
        )

        let context = NerwActionContextBuilder.build(for: action)

        let sectionTitles = context.sections.map(\.title)
        if sectionTitles != ["Action", "Modifiers", "Configuration"] {
            fatalError(
                "FAIL: Action Context section layout changed unexpectedly. Got \(sectionTitles)")
        }

        if !context.operations.contains(where: { $0.kind == .primary }) {
            fatalError("FAIL: Action Context must always include a primary operation.")
        }

        if !context.operations.contains(where: { $0.kind == .modifier(.shift) }) {
            fatalError("FAIL: Action Context did not expose the modifier-backed operation.")
        }

        guard let aliasOperation = context.operations.first(where: { $0.kind == .alias }) else {
            fatalError("FAIL: Action Context must include the alias operation.")
        }

        if case .textInput(_, let value) = aliasOperation.interaction {
            if value != "alpha beta" {
                fatalError("FAIL: Alias operation did not surface the stored aliases. Got \(value)")
            }
        } else {
            fatalError("FAIL: Alias operation must use text input interaction.")
        }

        guard let hotkeyOperation = context.operations.first(where: { $0.kind == .hotkey }) else {
            fatalError("FAIL: Action Context must include the hotkey operation.")
        }

        if case .hotkeyInput(let value) = hotkeyOperation.interaction {
            if value != "Cmd+Shift+K" {
                fatalError("FAIL: Hotkey operation did not surface the stored hotkey. Got \(value)")
            }
        } else {
            fatalError("FAIL: Hotkey operation must use hotkey input interaction.")
        }
    }

    print("  ✓ testActionContextIncludesModifierAndConfigurationOperations passed.")
}

func testActionContextHybridIncludesSecondaryOperation() {
    let quickAction = NerwAction(
        id: "test.action.context.quick.\(UUID().uuidString)",
        title: "Find Running Process",
        subtitle: "Open the quick process search",
        triggers: ["process"],
        type: .args(
            placeholder: "Process Name",
            searcher: { _, _, completion in completion([]) },
            perform: nil
        )
    )

    let action = NerwAction(
        id: "test.action.context.hybrid.\(UUID().uuidString)",
        title: "Activity Monitor",
        subtitle: "Application",
        type: .hybrid(
            perform: { _ in },
            action: NerwActionBox(quickAction)
        )
    )

    let context = NerwActionContextBuilder.build(for: action)
    guard let secondaryOperation = context.operations.first(where: { $0.kind == .secondary }) else {
        fatalError("FAIL: Hybrid actions must expose their secondary action in Action Context.")
    }

    if secondaryOperation.title != quickAction.title {
        fatalError(
            "FAIL: Secondary Action Context title mismatch. Expected \(quickAction.title), got \(secondaryOperation.title)"
        )
    }

    print("  ✓ testActionContextHybridIncludesSecondaryOperation passed.")
}

func testActionPreferenceStorePersistsAndClearsValues() {
    let actionID = "test.action.preferences.\(UUID().uuidString)"

    withRestoredActionPreferences(for: actionID) {
        NerwActionPreferenceStore.updateAliases(
            rawValue: "alpha   beta\nalpha\tgamma",
            for: actionID
        )

        let aliases = NerwActionPreferenceStore.aliases(for: actionID)
        if aliases != ["alpha", "beta", "gamma"] {
            fatalError("FAIL: Alias parsing changed unexpectedly. Got \(aliases)")
        }

        NerwActionPreferenceStore.updateHotkey("Cmd+Opt+P", for: actionID)
        if NerwActionPreferenceStore.hotkey(for: actionID) != "Cmd+Opt+P" {
            fatalError("FAIL: Hotkey store failed to persist the assigned shortcut.")
        }

        NerwActionPreferenceStore.updateHotkey("", for: actionID)
        if !NerwActionPreferenceStore.hotkey(for: actionID).isEmpty {
            fatalError("FAIL: Hotkey store failed to clear the assigned shortcut.")
        }
    }

    print("  ✓ testActionPreferenceStorePersistsAndClearsValues passed.")
}

func testActionContextKeyboardRouting() {
    let ctrlDown = ActionContextKeyboardRouter.command(
        keyCode: 45,
        charactersIgnoringModifiers: "n",
        modifierFlags: [.control]
    )
    if ctrlDown != .moveDown {
        fatalError("FAIL: Ctrl-N must map to moveDown. Got \(String(describing: ctrlDown))")
    }

    let moveDown = ActionContextKeyboardRouter.command(
        keyCode: 125,
        charactersIgnoringModifiers: nil,
        modifierFlags: []
    )
    if moveDown != .moveDown {
        fatalError("FAIL: Down arrow must map to moveDown. Got \(String(describing: moveDown))")
    }

    let moveUp = ActionContextKeyboardRouter.command(
        keyCode: 0,
        charactersIgnoringModifiers: "p",
        modifierFlags: [.control]
    )
    if moveUp != .moveUp {
        fatalError("FAIL: Ctrl-P must map to moveUp. Got \(String(describing: moveUp))")
    }

    let activate = ActionContextKeyboardRouter.command(
        keyCode: 36,
        charactersIgnoringModifiers: "\r",
        modifierFlags: []
    )
    if activate != .activate {
        fatalError("FAIL: Enter must map to activate. Got \(String(describing: activate))")
    }

    let cancel = ActionContextKeyboardRouter.command(
        keyCode: 40,
        charactersIgnoringModifiers: "k",
        modifierFlags: [.command]
    )
    if cancel != .cancel {
        fatalError("FAIL: Cmd-K must map to cancel. Got \(String(describing: cancel))")
    }

    let escape = ActionContextKeyboardRouter.command(
        keyCode: 53,
        charactersIgnoringModifiers: nil,
        modifierFlags: []
    )
    if escape != .cancel {
        fatalError("FAIL: Escape must map to cancel. Got \(String(describing: escape))")
    }

    print("  ✓ testActionContextKeyboardRouting passed.")
}

func testActionContextSelectionMovement() {
    let movedForward = ActionContextSelection.movedIndex(current: 0, delta: 1, count: 3)
    if movedForward != 1 {
        fatalError(
            "FAIL: Selection should move forward by one. Got \(String(describing: movedForward))")
    }

    let clampedTop = ActionContextSelection.movedIndex(current: 0, delta: -1, count: 3)
    if clampedTop != 0 {
        fatalError(
            "FAIL: Selection should stay at top when moving above first item. Got \(String(describing: clampedTop))"
        )
    }

    let clampedBottom = ActionContextSelection.movedIndex(current: 2, delta: 1, count: 3)
    if clampedBottom != 2 {
        fatalError(
            "FAIL: Selection should stay at bottom when moving past last item. Got \(String(describing: clampedBottom))"
        )
    }

    let empty = ActionContextSelection.movedIndex(current: 0, delta: 1, count: 0)
    if empty != nil {
        fatalError("FAIL: Empty action lists must not produce a selected index.")
    }

    print("  ✓ testActionContextSelectionMovement passed.")
}

func testActionContextTypeSelect() {
    if ActionContextTypeSelect.initials(for: "Set Hotkey") != "sh" {
        fatalError("FAIL: Type-select initials changed unexpectedly.")
    }

    let items = [
        ActionContextTypeSelect.Item(title: "Run", keywords: ["Search Google"]),
        ActionContextTypeSelect.Item(title: "Set Alias"),
        ActionContextTypeSelect.Item(title: "Set Hotkey"),
        ActionContextTypeSelect.Item(title: "Lucky Search"),
    ]

    let aliasMatch = ActionContextTypeSelect.matchingIndex(
        query: "sa",
        currentIndex: 0,
        items: items
    )
    if aliasMatch != 1 {
        fatalError(
            "FAIL: Type-select should match Set Alias by initials. Got \(String(describing: aliasMatch))"
        )
    }

    let hotkeyMatch = ActionContextTypeSelect.matchingIndex(
        query: "sh",
        currentIndex: 1,
        items: items
    )
    if hotkeyMatch != 2 {
        fatalError(
            "FAIL: Type-select should match Set Hotkey by initials. Got \(String(describing: hotkeyMatch))"
        )
    }

    let primaryMatch = ActionContextTypeSelect.matchingIndex(
        query: "sg",
        currentIndex: 2,
        items: items
    )
    if primaryMatch != 0 {
        fatalError(
            "FAIL: Type-select should match the action title keywords and wrap. Got \(String(describing: primaryMatch))"
        )
    }

    let missingMatch = ActionContextTypeSelect.matchingIndex(
        query: "zz",
        currentIndex: 0,
        items: items
    )
    if missingMatch != nil {
        fatalError(
            "FAIL: Unknown type-select queries must not match. Got \(String(describing: missingMatch))"
        )
    }

    print("  ✓ testActionContextTypeSelect passed.")
}

func testActionContextVisualBridgeHeight() {
    let standardHeight = ActionContextVisualBridge.height(
        forSelectionBackgroundHeight: 44,
        availableHeight: 160
    )
    if standardHeight != 44 {
        fatalError(
            "FAIL: Connector line should match the selection background height when space allows. Got \(standardHeight)"
        )
    }

    let clampedHeight = ActionContextVisualBridge.height(
        forSelectionBackgroundHeight: 44,
        availableHeight: 20
    )
    if clampedHeight != 20 {
        fatalError(
            "FAIL: Connector line should clamp to the available popup height. Got \(clampedHeight)")
    }

    let emptyHeight = ActionContextVisualBridge.height(
        forSelectionBackgroundHeight: -4,
        availableHeight: 20
    )
    if emptyHeight != 0 {
        fatalError("FAIL: Connector line height must not go negative. Got \(emptyHeight)")
    }

    print("  ✓ testActionContextVisualBridgeHeight passed.")
}
