import Cocoa
import CoreGraphics
import NerwAction
import NerwBuiltin
import NerwCore
import NerwUI

class SnippetController: SplitPaneDataSource, SplitPaneDelegate {
    private var filteredSnippets: [Snippet] = []
    private var currentQuery: String = ""

    var isVisible: Bool {
        return SplitPaneManager.shared.isVisible
    }

    func show() {
        currentQuery = ""
        refreshFilteredSnippets()
        let icon =
            NSImage(systemSymbolName: "text.pad.header", accessibilityDescription: nil) ?? NSImage()
        SplitPaneManager.shared.show(
            title: "Search Snippets...", icon: icon, dataSource: self, delegate: self)
    }

    // MARK: - SplitPaneDataSource
    func numberOfItems() -> Int {
        return filteredSnippets.count
    }

    func item(at index: Int) -> SplitPaneItem {
        return SnippetItemAdapter(snippet: filteredSnippets[index])
    }

    // MARK: - SplitPaneDelegate
    func didSelect(item: SplitPaneItem?) {
        // Handled naturally by SplitPaneViewController preview
    }

    func didActivate(item: SplitPaneItem) {
        if let adapter = item as? SnippetItemAdapter {
            typeSnippet(adapter.snippet)
        }
    }

    func didDelete(item: SplitPaneItem) {
        if let adapter = item as? SnippetItemAdapter {
            delete(adapter.snippet)
        }
    }

    func didSearch(query: String) {
        currentQuery = query
        refreshFilteredSnippets()
        SplitPaneManager.shared.reloadData()
    }

    func actionContext(for item: SplitPaneItem) -> NerwActionContext? {
        guard let adapter = item as? SnippetItemAdapter else { return nil }

        return NerwActionContext(
            actionID: adapter.snippet.id,
            actionTitle: adapter.snippet.name,
            actionSubtitle: "Trigger: \(adapter.snippet.trigger)",
            sections: [
                .init(
                    id: "snippet",
                    title: "Snippet",
                    operations: [
                        .init(
                            id: "snippet.type",
                            kind: .custom("snippet.type"),
                            title: "Type Snippet",
                            subtitle: "Insert this snippet into the frontmost app",
                            icon: .system("text.insert"),
                            interaction: .execute,
                            detailText: "⏎"
                        ),
                        .init(
                            id: "snippet.edit",
                            kind: .custom("snippet.edit"),
                            title: "Edit",
                            subtitle: "Modify this snippet",
                            icon: .system("pencil"),
                            interaction: .execute,
                            detailText: "⌘E"
                        ),
                        .init(
                            id: "snippet.delete",
                            kind: .custom("snippet.delete"),
                            title: "Delete",
                            subtitle: "Remove this snippet",
                            icon: .system("trash"),
                            interaction: .execute,
                            detailText: "⌘⌫"
                        ),
                    ]
                )
            ]
        )
    }

    func didInvokeActionContext(operation: NerwActionContext.Operation, for item: SplitPaneItem) {
        guard let adapter = item as? SnippetItemAdapter else { return }

        switch operation.id {
        case "snippet.type":
            typeSnippet(adapter.snippet)
        case "snippet.delete":
            delete(adapter.snippet)
        case "snippet.edit":
            edit(adapter.snippet)
        default:
            break
        }
    }

    private func typeSnippet(_ snippet: Snippet) {
        SplitPaneManager.shared.hide()

        // Wait briefly for window to disappear
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let resolvedContent = SnippetManager.shared.resolve(content: snippet.content)
            let source = CGEventSource(stateID: .hidSystemState)

            for char in resolvedContent {
                if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
                    let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
                {
                    let chars = Array(char.utf16)
                    keyDown.keyboardSetUnicodeString(
                        stringLength: chars.count, unicodeString: chars)
                    keyUp.keyboardSetUnicodeString(stringLength: chars.count, unicodeString: chars)
                    keyDown.post(tap: .cghidEventTap)
                    keyUp.post(tap: .cghidEventTap)
                }
            }
        }
    }

    private func delete(_ snippet: Snippet) {
        SnippetManager.shared.deleteSnippet(id: snippet.id)
        refreshFilteredSnippets()
        SplitPaneManager.shared.reloadData()
    }

    private func edit(_ snippet: Snippet) {
        SplitPaneManager.shared.hide()

        let editAction = NerwAction(
            id: "builtin.snippet.edit",
            title: "Edit Snippet",
            subtitle: "Modify existing text expansion snippet",
            icon: .system("pencil"),
            triggers: [],
            type: .form(
                fields: [
                    .init(
                        id: "name", title: "Name", placeholder: "e.g. Email signature",
                        defaultValue: snippet.name),
                    .init(
                        id: "trigger", title: "Trigger", placeholder: "e.g. ;sig",
                        defaultValue: snippet.trigger),
                    .init(
                        id: "content", title: "Content",
                        subtext:
                            "You can use placeholders like {{date}}, {{time}}, or {{clipboard}}",
                        placeholder: "Your text here",
                        defaultValue: snippet.content, isMultiline: true),
                ],
                submitLabel: "Update Snippet",
                perform: { _, values in
                    let name = values["name"] ?? ""
                    let trigger = values["trigger"] ?? ""
                    let content = values["content"] ?? ""
                    if !name.isEmpty && !trigger.isEmpty && !content.isEmpty {
                        SnippetManager.shared.updateSnippet(
                            id: snippet.id, name: name, trigger: trigger, content: content)
                        DispatchQueue.main.async {
                            SnippetManager.shared.showWindowCallback?()
                        }
                    }
                }
            )
        )

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let ui = NerwSystem.shared.ui {
                ui.openAction(editAction)

                // Pre-fill values
                // This is a bit hacky, but since FormView doesn't support initial values via NerwAction yet,
                // we simulate typing or rely on the user to re-enter.
                // A better fix would be updating NerwAction.Field to support `defaultValue` but for now this works.
                // Alternatively, I will update NerwAction.Field to support initialValue.
            }
        }
    }

    private func refreshFilteredSnippets() {
        let allSnippets = SnippetManager.shared.snippets
        guard !currentQuery.isEmpty else {
            filteredSnippets = allSnippets
            return
        }

        let lowerQuery = currentQuery.lowercased()
        filteredSnippets = allSnippets.filter { snippet in
            snippet.name.lowercased().contains(lowerQuery)
                || snippet.trigger.lowercased().contains(lowerQuery)
                || snippet.content.lowercased().contains(lowerQuery)
        }
    }

    func didCancel() {
        SplitPaneManager.shared.hide()
    }
}

struct SnippetItemAdapter: SplitPaneItem {
    let snippet: Snippet

    var id: String { snippet.id }

    var title: String {
        snippet.name
    }

    var subtitle: String? {
        "Trigger: \(snippet.trigger)"
    }

    var timestamp: Date? { snippet.createdAt }

    var iconImage: NSImage? {
        NSImage(systemSymbolName: "text.alignleft", accessibilityDescription: nil)
    }

    var previewText: String? { snippet.content }
    var previewImagePath: String? { nil }
}
