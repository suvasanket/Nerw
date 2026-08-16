import Cocoa
import NerwAction
import NerwBuiltin
import NerwUI

class MemoryController: SplitPaneDataSource, SplitPaneDelegate {
    private var filteredEntries: [MemoryEntry] = []
    private var currentQuery: String = ""

    var isVisible: Bool {
        return SplitPaneManager.shared.isVisible
    }

    func show() {
        currentQuery = ""
        refreshFilteredEntries()
        let icon =
            NSImage(systemSymbolName: "brain.head.profile", accessibilityDescription: nil)
            ?? NSImage()
        SplitPaneManager.shared.show(
            title: "Search AI Memories...", icon: icon, dataSource: self, delegate: self)
    }

    // MARK: - SplitPaneDataSource
    func numberOfItems() -> Int {
        return filteredEntries.count
    }

    func item(at index: Int) -> SplitPaneItem {
        return MemoryItemAdapter(entry: filteredEntries[index])
    }

    // MARK: - SplitPaneDelegate
    func didSelect(item: SplitPaneItem?) {
        // Handled naturally by SplitPaneViewController preview
    }

    func didActivate(item: SplitPaneItem) {
        if let adapter = item as? MemoryItemAdapter {
            // For now, activating could just hide or perhaps copy the memory.
            let pboard = NSPasteboard.general
            pboard.clearContents()
            pboard.setString(adapter.entry.content, forType: .string)
            Nerw.notify("Memory copied to clipboard", level: .info)
            SplitPaneManager.shared.hide()
        }
    }

    func didDelete(item: SplitPaneItem) {
        // We can add delete logic here if we update AIMemoryManager with a delete method
        // For the ad-hoc UI, just ignore or print for now
    }

    func didSearch(query: String) {
        currentQuery = query
        refreshFilteredEntries()
        SplitPaneManager.shared.reloadData()
    }

    func actionContext(for item: SplitPaneItem) -> NerwActionContext? {
        // Return nil to not show the 3-dot context menu for now
        return nil
    }

    func didInvokeActionContext(operation: NerwActionContext.Operation, for item: SplitPaneItem) {
        // Not used since actionContext returns nil
    }

    private func refreshFilteredEntries() {
        let entries = AIMemoryManager.shared.entries
        guard !currentQuery.isEmpty else {
            filteredEntries = entries.sorted(by: { $0.timestamp > $1.timestamp })
            return
        }

        let lowerQuery = currentQuery.lowercased()
        filteredEntries = entries.filter { entry in
            let titleMatch = entry.title.lowercased().contains(lowerQuery)
            let catMatch = entry.category.lowercased().contains(lowerQuery)
            let contentMatch = entry.content.lowercased().contains(lowerQuery)
            return titleMatch || catMatch || contentMatch
        }.sorted(by: { $0.timestamp > $1.timestamp })
    }

    func didCancel() {
        SplitPaneManager.shared.hide()
    }
}

struct MemoryItemAdapter: SplitPaneItem {
    let entry: MemoryEntry

    var id: String { entry.id.uuidString }

    var title: String {
        return entry.title
    }

    var subtitle: String? {
        return
            "[\(entry.type.rawValue.capitalized)] [\(entry.category)] Importance: \(entry.importance)/10"
    }

    var timestamp: Date? { entry.timestamp }

    var iconImage: NSImage? {
        return NSImage(systemSymbolName: "brain", accessibilityDescription: nil)
    }

    var previewText: String? { entry.content }
    var previewImagePath: String? { nil }
}
