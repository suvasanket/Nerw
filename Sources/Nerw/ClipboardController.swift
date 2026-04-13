import Cocoa
import NerwBuiltin
import NerwUI

class ClipboardController: SplitPaneDataSource, SplitPaneDelegate {
    private var windowController: SplitPaneWindowController?
    private var filteredEntries: [ClipboardEntry] = []

    var isVisible: Bool {
        return windowController?.isVisible == true
    }

    func show() {
        filteredEntries = ClipboardManager.shared.entries
        if windowController == nil {
            windowController = SplitPaneWindowController(
                title: "Search Clipboard History...",
                icon: NSImage(named: "clipboard") ?? NSImage(
                    systemSymbolName: "clipboard", accessibilityDescription: nil) ?? NSImage(
                        systemSymbolName: "doc.on.clipboard", accessibilityDescription: nil)
                    ?? NSImage(),
                dataSource: self,
                delegate: self
            )
        }
        windowController?.show()
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
            ClipboardManager.shared.paste(entry: adapter.entry)
            windowController?.hide()
        }
    }

    func didDelete(item: SplitPaneItem) {
        if let adapter = item as? ClipboardItemAdapter {
            ClipboardManager.shared.deleteEntry(id: adapter.entry.id)
            filteredEntries.removeAll { $0.id == adapter.entry.id }
            windowController?.reloadData()
        }
    }

    func didSearch(query: String) {
        if query.isEmpty {
            filteredEntries = ClipboardManager.shared.entries
        } else {
            let lowerQuery = query.lowercased()
            filteredEntries = ClipboardManager.shared.entries.filter { entry in
                if let text = entry.text {
                    return text.lowercased().contains(lowerQuery)
                }
                return false
            }
        }
        windowController?.reloadData()
    }

    func didCancel() {
        windowController?.hide()
    }
}

struct ClipboardItemAdapter: SplitPaneItem {
    let entry: ClipboardEntry

    var id: String { entry.id }

    var title: String {
        if let t = entry.text {
            let s =
                t.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: .newlines)
                .first ?? t
            return s.isEmpty ? "Empty Text" : String(s.prefix(50))
        } else if entry.imagePath != nil {
            return "Image"
        }
        return "Unknown"
    }

    var subtitle: String? {
        if let t = entry.text {
            return "Text • \(t.count) chars"
        } else if entry.imagePath != nil {
            return "Image"
        }
        return nil
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
