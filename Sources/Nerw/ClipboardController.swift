import Cocoa
import NerwAction
import NerwBuiltin
import NerwUI

class ClipboardController: SplitPaneDataSource, SplitPaneDelegate {
    private var filteredEntries: [ClipboardEntry] = []
    private var currentQuery: String = ""

    var isVisible: Bool {
        return SplitPaneManager.shared.isVisible
    }

    func show() {
        currentQuery = ""
        refreshFilteredEntries()
        let icon =
            NSImage(systemSymbolName: "document.on.document", accessibilityDescription: nil)
            ?? NSImage()
        SplitPaneManager.shared.show(
            title: "Search Clipboard History...", icon: icon, dataSource: self, delegate: self)
    }

    // MARK: - SplitPaneDataSource
    func numberOfItems() -> Int {
        return filteredEntries.count
    }

    func item(at index: Int) -> SplitPaneItem {
        return ClipboardItemAdapter(entry: filteredEntries[index])
    }

    // MARK: - SplitPaneDelegate
    func didSelect(item: SplitPaneItem?) {
        // Handled naturally by SplitPaneViewController preview
    }

    func didActivate(item: SplitPaneItem) {
        if let adapter = item as? ClipboardItemAdapter {
            paste(adapter.entry)
        }
    }

    func didDelete(item: SplitPaneItem) {
        if let adapter = item as? ClipboardItemAdapter {
            delete(adapter.entry)
        }
    }

    func didSearch(query: String) {
        currentQuery = query
        refreshFilteredEntries()
        SplitPaneManager.shared.reloadData()
    }

    func actionContext(for item: SplitPaneItem) -> NerwActionContext? {
        guard let adapter = item as? ClipboardItemAdapter else { return nil }
        return ClipboardManager.context(for: adapter.entry)
    }

    func didInvokeActionContext(operation: NerwActionContext.Operation, for item: SplitPaneItem) {
        guard let adapter = item as? ClipboardItemAdapter else { return }

        switch operation.id {
        case ClipboardContextOperationID.paste.rawValue:
            paste(adapter.entry)
        case ClipboardContextOperationID.delete.rawValue:
            delete(adapter.entry)
        case ClipboardContextOperationID.pin.rawValue:
            ClipboardManager.shared.togglePinned(id: adapter.entry.id)
            refreshFilteredEntries()
            SplitPaneManager.shared.reloadData()
        default:
            break
        }
    }

    private func paste(_ entry: ClipboardEntry) {
        ClipboardManager.shared.paste(entry: entry)
        SplitPaneManager.shared.hide()
    }

    private func delete(_ entry: ClipboardEntry) {
        ClipboardManager.shared.deleteEntry(id: entry.id)
        refreshFilteredEntries()
        SplitPaneManager.shared.reloadData()
    }

    private func refreshFilteredEntries() {
        let entries = ClipboardManager.shared.entries
        guard !currentQuery.isEmpty else {
            filteredEntries = entries
            return
        }

        let lowerQuery = currentQuery.lowercased()
        filteredEntries = entries.filter { entry in
            let title = ClipboardManager.title(for: entry).lowercased()
            if title.contains(lowerQuery) {
                return true
            }
            if let text = entry.text {
                return text.lowercased().contains(lowerQuery)
            }
            return false
        }
    }

    func didCancel() {
        SplitPaneManager.shared.hide()
    }
}

struct ClipboardItemAdapter: SplitPaneItem {
    let entry: ClipboardEntry

    var id: String { entry.id }

    var title: String {
        ClipboardManager.title(for: entry)
    }

    var subtitle: String? {
        ClipboardManager.subtitle(for: entry)
    }

    var timestamp: Date? { entry.timestamp }

    var iconImage: NSImage? {
        if entry.text != nil {
            return NSImage(systemSymbolName: "text.alignleft", accessibilityDescription: nil)
        } else if entry.imagePath != nil {
            return NSImage(systemSymbolName: "photo", accessibilityDescription: nil)
        }
        return nil
    }

    var previewText: String? { entry.text }
    var previewImagePath: String? { entry.imagePath }
}
