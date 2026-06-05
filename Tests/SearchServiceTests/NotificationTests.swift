import Cocoa
import Foundation
import NerwCore

@testable import NerwUI

func runNotificationTests() {
    print("[Testing] Starting Notification UI tests...")

    testNotificationItemViewBadgePlacement()

    print("[Testing] All Notification UI tests PASSED.")
}

func testNotificationItemViewBadgePlacement() {
    let warnItem = NotificationItemView(
        id: UUID(), content: "Warning test", level: .warn, progressive: false)
    let errorItem = NotificationItemView(
        id: UUID(), content: "Error test", level: .error, progressive: false)
    let infoItem = NotificationItemView(
        id: UUID(), content: "Info test", level: .info, progressive: false)

    // Trigger layout to ensure colors are updated
    warnItem.layout()
    errorItem.layout()
    infoItem.layout()

    // Inspect the private badgeView property via Reflection
    let warnMirror = Mirror(reflecting: warnItem)
    let warnBadge = warnMirror.children.first(where: { $0.label == "badgeView" })?.value as? NSView
    if warnBadge == nil {
        fatalError("FAIL: Warning notification must have a badge view.")
    }
    if !warnItem.subviews.contains(warnBadge!) {
        fatalError("FAIL: Warning badge view was not added to subviews of NotificationItemView.")
    }

    let errorMirror = Mirror(reflecting: errorItem)
    let errorBadge =
        errorMirror.children.first(where: { $0.label == "badgeView" })?.value as? NSView
    if errorBadge == nil {
        fatalError("FAIL: Error notification must have a badge view.")
    }
    if !errorItem.subviews.contains(errorBadge!) {
        fatalError("FAIL: Error badge view was not added to subviews of NotificationItemView.")
    }

    let infoMirror = Mirror(reflecting: infoItem)
    let infoBadge = infoMirror.children.first(where: { $0.label == "badgeView" })?.value as? NSView
    if infoBadge != nil {
        fatalError("FAIL: Info notification must not have a badge view.")
    }

    print("  ✓ testNotificationItemViewBadgePlacement passed.")
}
