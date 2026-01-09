import Cocoa
import QuickLookThumbnailing

public class IconUtils {
    public static func getIconAsync(for url: URL, size: CGSize, completion: @escaping (NSImage?) -> Void) {
        let resolvedURL = url.resolvingSymlinksInPath()
        let request = QLThumbnailGenerator.Request(
            fileAt: resolvedURL, 
            size: size, 
            scale: NSScreen.main?.backingScaleFactor ?? 2.0, 
            representationTypes: .icon
        )
        
        QLThumbnailGenerator.shared.generateRepresentations(for: request) { (representation, type, error) in
            DispatchQueue.main.async {
                if let representation = representation {
                    completion(representation.nsImage)
                } else {
                    completion(nil)
                }
            }
        }
    }
}
