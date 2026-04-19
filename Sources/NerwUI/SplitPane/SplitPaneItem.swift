import Cocoa
import NerwAction

public protocol SplitPaneItem {
    var id: String { get }
    var title: String { get }
    var subtitle: String? { get }
    var timestamp: Date? { get }
    var iconImage: NSImage? { get }

    // Preview content
    var previewText: String? { get }
    var previewImagePath: String? { get }
}

public protocol SplitPaneDataSource: AnyObject {
    func numberOfItems() -> Int
    func item(at index: Int) -> SplitPaneItem
}

public protocol SplitPaneDelegate: AnyObject {
    func didSelect(item: SplitPaneItem?)
    func didActivate(item: SplitPaneItem)  // triggered on Enter
    func didDelete(item: SplitPaneItem)  // triggered on Delete / Backspace
    func didCancel()  // triggered on Esc
    func didSearch(query: String)  // triggered when typing in search field
    func actionContext(for item: SplitPaneItem) -> NerwActionContext?
    func didInvokeActionContext(operation: NerwActionContext.Operation, for item: SplitPaneItem)
}

extension SplitPaneDelegate {
    public func didSearch(query: String) {}
    public func actionContext(for item: SplitPaneItem) -> NerwActionContext? { nil }
    public func didInvokeActionContext(
        operation: NerwActionContext.Operation,
        for item: SplitPaneItem
    ) {}
}
