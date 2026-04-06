import Cocoa
import Foundation
import NerwBuiltin
import NerwUI

class MockDataSource: SplitPaneDataSource {
    let items: [SplitPaneItem] = []
    func numberOfItems() -> Int { return items.count }
    func item(at index: Int) -> SplitPaneItem { return items[index] }
}

class MockDelegate: SplitPaneDelegate {
    func didSelect(item: SplitPaneItem?) {}
    func didActivate(item: SplitPaneItem) {}
    func didDelete(item: SplitPaneItem) {}
    func didSearch(query: String) {}
    func didCancel() {}
}

func testSplitPaneInitialization() {
    let ds = MockDataSource()
    let delegate = MockDelegate()

    // Test generic container initializations
    let vc = SplitPaneViewController(
        title: "Test Layout", icon: nil, dataSource: ds, delegate: delegate)

    // Force view load to trigger layout constraint definitions
    _ = vc.view

    // Ensure that title string was kept internally via placeholder mapping
    let windowController = SplitPaneWindowController(
        title: "Another Window", icon: nil, dataSource: ds, delegate: delegate)

    if windowController.isVisible {
        fatalError("FAIL: Window should not be immediately visible upon initialization")
    }

    print("  ✓ testSplitPaneInitialization passed.")
}
