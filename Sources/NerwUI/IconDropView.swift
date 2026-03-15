import Cocoa

/// Alfred-style rectangular image drop zone.
/// Displays a placeholder when empty and the dropped/set image when filled.
/// Supports drag-and-drop of image files, and also acts as an `NSButton`-style click target
/// to open a file picker.
class IconDropView: NSView {

    // MARK: - Public

    /// Called whenever the image changes (drop or file picker).
    var onImageChanged: ((NSImage) -> Void)?

    /// The current icon image. Setting this updates the display.
    var image: NSImage? {
        didSet { needsDisplay = true }
    }

    // MARK: - Private

    private let borderRadius: CGFloat = 10
    private var isHighlighted = false

    // MARK: - Init

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        wantsLayer = true
        registerForDraggedTypes([.fileURL, .tiff, .png])
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        let rect = bounds.insetBy(dx: 1, dy: 1)
        let path = NSBezierPath(roundedRect: rect, xRadius: borderRadius, yRadius: borderRadius)

        // Background
        if isHighlighted {
            NSColor.selectedContentBackgroundColor.withAlphaComponent(0.15).setFill()
        } else {
            NSColor.quaternaryLabelColor.setFill()
        }
        path.fill()

        // Border (dashed when empty)
        if image == nil {
            let dashPattern: [CGFloat] = [5, 4]
            path.setLineDash(dashPattern, count: 2, phase: 0)
        }
        NSColor.tertiaryLabelColor.setStroke()
        path.lineWidth = 1.5
        path.stroke()

        if let img = image {
            // Draw image centred and aspect-fitted
            let size = img.size
            let scale = min(rect.width / size.width, rect.height / size.height)
            let drawSize = NSSize(width: size.width * scale, height: size.height * scale)
            let origin = NSPoint(
                x: rect.midX - drawSize.width / 2,
                y: rect.midY - drawSize.height / 2
            )
            img.draw(
                in: NSRect(origin: origin, size: drawSize),
                from: .zero, operation: .sourceOver, fraction: 1.0)
        } else {
            // Placeholder: small photo icon + two short lines centered
            let iconSize: CGFloat = 20
            let icon = NSImage(systemSymbolName: "photo", accessibilityDescription: nil)
            let iconOrigin = NSPoint(
                x: rect.midX - iconSize / 2,
                y: rect.midY + 3
            )
            icon?.draw(
                in: NSRect(origin: iconOrigin, size: NSSize(width: iconSize, height: iconSize)),
                from: .zero, operation: .sourceOver, fraction: 0.35)

            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 9),
                .foregroundColor: NSColor.tertiaryLabelColor,
            ]
            let line1 = "Drop or" as NSString
            let line2 = "click" as NSString
            let s1 = line1.size(withAttributes: attrs)
            let s2 = line2.size(withAttributes: attrs)
            line1.draw(
                at: NSPoint(x: rect.midX - s1.width / 2, y: rect.midY - 3 - s1.height),
                withAttributes: attrs)
            line2.draw(
                at: NSPoint(
                    x: rect.midX - s2.width / 2, y: rect.midY - 3 - s1.height - s2.height - 1),
                withAttributes: attrs)
        }
    }

    // MARK: - Click → File Picker

    override func mouseDown(with event: NSEvent) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url, let img = NSImage(contentsOf: url) {
            image = img
            onImageChanged?(img)
        }
    }

    // MARK: - Drag & Drop

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        if canAccept(sender) {
            isHighlighted = true
            needsDisplay = true
            return .copy
        }
        return []
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        isHighlighted = false
        needsDisplay = true
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        return canAccept(sender) ? .copy : []
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        isHighlighted = false
        needsDisplay = true

        let pb = sender.draggingPasteboard

        // Try file URL first
        if let urls = pb.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
            let url = urls.first, let img = NSImage(contentsOf: url)
        {
            image = img
            onImageChanged?(img)
            return true
        }

        // Try raw image data
        if let data = pb.data(forType: .tiff), let img = NSImage(data: data) {
            image = img
            onImageChanged?(img)
            return true
        }

        return false
    }

    // MARK: - Helper

    private func canAccept(_ sender: NSDraggingInfo) -> Bool {
        let pb = sender.draggingPasteboard
        return pb.availableType(from: [.fileURL, .tiff, .png]) != nil
    }
}
