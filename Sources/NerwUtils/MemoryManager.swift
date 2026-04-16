import Foundation
import MachO

public class MemoryManager {
    public static let shared = MemoryManager()

    // Configurable maximum allowed memory size in MB
    public var maxAllowedMemoryMB: Double = 40.0

    private init() {}

    /// Returns the current resident memory size of the application in megabytes.
    public func currentMemoryUsageMB() -> Double? {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        if kerr == KERN_SUCCESS {
            return Double(info.resident_size) / 1048576.0  // Convert Bytes to MB
        }
        return nil
    }

    /// Trims Foundation-managed caches that are safe to drop at any time.
    public func forceMemoryFree() {
        if isMemoryHigh() {
            DispatchQueue.global(qos: .background).async {
                URLCache.shared.removeAllCachedResponses()
            }
        }
    }

    /// Checks if the current memory usage exceeds the configured threshold.
    public func isMemoryHigh() -> Bool {
        guard let usedMB = currentMemoryUsageMB() else { return false }
        return usedMB > maxAllowedMemoryMB
    }
}
