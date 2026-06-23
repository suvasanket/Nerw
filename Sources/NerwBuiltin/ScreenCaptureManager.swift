import Cocoa

public class ScreenCaptureManager {
    public static let shared = ScreenCaptureManager()

    public private(set) var latestCapture: Data?

    public func captureAsync() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let mainDisplayRect = CGDisplayBounds(CGMainDisplayID())
            guard
                let cgImage = CGWindowListCreateImage(
                    mainDisplayRect, .optionOnScreenOnly, kCGNullWindowID, .nominalResolution)
            else { return }
            let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
            self?.latestCapture = bitmapRep.representation(
                using: .jpeg, properties: [.compressionFactor: 0.7])
        }
    }

    public func clear() {
        latestCapture = nil
    }
}
