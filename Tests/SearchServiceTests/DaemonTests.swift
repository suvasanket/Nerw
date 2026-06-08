import Foundation
import NerwCore

func runDaemonTests() {
    print("[Testing] Starting Daemon tests...")

    testDaemonRegistry()
    testDaemonResourceMonitor()

    print("[Testing] All Daemon tests PASSED.")
}

func testDaemonRegistry() {
    let registry = DaemonRegistry.shared
    let testId = "com.test.daemon.extension"

    // Reset state for test
    registry.revoke(testId)

    if registry.isApproved(testId) {
        fatalError("FAIL: Daemon should not be approved initially.")
    }

    registry.approve(testId)
    if !registry.isApproved(testId) {
        fatalError("FAIL: Daemon should be approved.")
    }

    if !registry.isRunnable(testId) {
        fatalError("FAIL: Daemon should be runnable.")
    }

    for _ in 0..<5 {
        registry.recordCrash(testId)
    }

    if registry.isRunnable(testId) {
        fatalError("FAIL: Daemon should not be runnable after 5 crashes.")
    }

    registry.revoke(testId)
    print("  ✓ testDaemonRegistry passed.")
}

func testDaemonResourceMonitor() {
    // Basic test of resource monitor init
    _ = DaemonResourceMonitor.shared
    // We can't easily mock process CPU/Memory here, but we can verify it doesn't crash on init
    print("  ✓ testDaemonResourceMonitor passed.")
}
