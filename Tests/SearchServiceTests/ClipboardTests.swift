import Foundation
import NerwBuiltin

func testClipboardManagerStorage() {
    testClipboardBuiltinAction()
    testClipboardContextOperations()
    testClipboardPinnedInsertionIndex()
    testClipboardTogglePinOrdering()

    print("  ✓ testClipboardManagerStorage passed.")
}

private func testClipboardBuiltinAction() {
    let actions = ClipboardManager.builtinActions()
    if actions.isEmpty || actions[0].id != "builtin.clipboard" {
        fatalError("FAIL: Clipboard Builtin actions missing or invalid")
    }
}

private func testClipboardContextOperations() {
    let entry = ClipboardEntry(id: "test.clipboard.entry", text: "Pinned text", imagePath: nil)
    let context = ClipboardManager.context(for: entry)
    let operations = context.operations

    let operationIDs = operations.map(\.id)
    if operationIDs != [
        ClipboardContextOperationID.paste.rawValue,
        ClipboardContextOperationID.delete.rawValue,
        ClipboardContextOperationID.pin.rawValue,
    ] {
        fatalError("FAIL: Clipboard context operations changed unexpectedly. Got \(operationIDs)")
    }

    guard
        let paste = operations.first(where: { $0.id == ClipboardContextOperationID.paste.rawValue }
        ),
        paste.detailText == "⏎"
    else {
        fatalError("FAIL: Clipboard paste operation must show Enter binding.")
    }

    guard
        let delete = operations.first(where: {
            $0.id == ClipboardContextOperationID.delete.rawValue
        }),
        delete.detailText == "⌘⌫"
    else {
        fatalError("FAIL: Clipboard delete operation must show Cmd+Backspace binding.")
    }

    guard let pin = operations.first(where: { $0.id == ClipboardContextOperationID.pin.rawValue }),
        pin.title == "Pin"
    else {
        fatalError("FAIL: Clipboard context must expose Pin for unpinned entries.")
    }
}

private func testClipboardPinnedInsertionIndex() {
    let entries = [
        ClipboardEntry(id: "pinned.1", text: "Pinned 1", isPinned: true),
        ClipboardEntry(id: "pinned.2", text: "Pinned 2", isPinned: true),
        ClipboardEntry(id: "unpinned.1", text: "Unpinned 1"),
    ]

    let insertionIndex = ClipboardManager.insertionIndexForNewEntry(in: entries)
    if insertionIndex != 2 {
        fatalError("FAIL: New clipboard entries must insert after pinned entries.")
    }
}

private func testClipboardTogglePinOrdering() {
    let entries = [
        ClipboardEntry(id: "pinned", text: "Pinned", isPinned: true),
        ClipboardEntry(id: "latest", text: "Latest"),
        ClipboardEntry(id: "older", text: "Older"),
    ]

    let afterPinningOlder = ClipboardManager.entriesByTogglingPin(for: "older", in: entries)
    if afterPinningOlder.map(\.id) != ["older", "pinned", "latest"] {
        fatalError(
            "FAIL: Newly pinned clipboard entry must move to top. Got \(afterPinningOlder.map(\.id))"
        )
    }
    if afterPinningOlder[0].isPinned != true {
        fatalError("FAIL: Toggled clipboard entry should be marked pinned.")
    }

    let afterUnpinningOlder = ClipboardManager.entriesByTogglingPin(
        for: "older",
        in: afterPinningOlder
    )
    if afterUnpinningOlder.map(\.id) != ["pinned", "older", "latest"] {
        fatalError(
            "FAIL: Unpinned clipboard entry must move below pinned entries. Got \(afterUnpinningOlder.map(\.id))"
        )
    }
    if afterUnpinningOlder[1].isPinned != false {
        fatalError("FAIL: Toggled clipboard entry should be marked unpinned.")
    }
}
