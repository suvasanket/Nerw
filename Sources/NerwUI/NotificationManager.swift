import Cocoa
import Foundation
import NerwCore

public class NerwNotificationManager {
    public static let shared = NerwNotificationManager()

    private let panel = NotificationPanel()

    // Auto-dismissal timer duration
    private let displayDuration: TimeInterval = 3.5

    private var activeNotifications: [NotificationItemView] = []
    private var dismissalTimers: [UUID: Timer] = [:]

    private init() {
        // panel.contentView is already an NSView from NotificationPanel initialization
    }

    private func updateStackLayout() {
        guard panel.contentView != nil, let screen = NSScreen.main else { return }
        let maxVisible = 3

        let screenRect = screen.visibleFrame
        let panelWidth: CGFloat = 400
        let panelHeight: CGFloat = 160  // Affords space for the stack offset

        let x = screenRect.midX - (panelWidth / 2)
        let y = screenRect.maxY - panelHeight - 15

        // Always maintain the panel frame correctly
        panel.setFrame(NSRect(x: x, y: y, width: panelWidth, height: panelHeight), display: true)

        NSAnimationContext.runAnimationGroup(
            { context in
                context.duration = 0.4
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                context.allowsImplicitAnimation = true

                for (index, view) in activeNotifications.enumerated() {
                    if index >= maxVisible {
                        view.animator().alphaValue = 0
                        continue
                    }

                    let size = view.fittingSize

                    // Genuine macOS stack look: cards peek out from below, slightly narrower, solid opacity
                    let yOffset: CGFloat = CGFloat(index) * 8.0  // Shift down 8 points per index
                    let narrowedWidth = size.width - (CGFloat(index) * 16.0)  // 8 points narrower per side

                    let viewX = (panelWidth - narrowedWidth) / 2
                    // Since macOS origin is bottom-left, decreasing Y means lower on screen.
                    let viewY = panelHeight - size.height - yOffset

                    let finalFrame = NSRect(
                        x: viewX, y: viewY, width: narrowedWidth, height: size.height)

                    view.animator().frame = finalFrame

                    // Opacity is solid to emulate layered physical cards casting shadows on each other
                    view.animator().alphaValue = 1.0

                    // Ensure front view is appropriately highest in z space
                    view.layer?.zPosition = CGFloat(maxVisible - index)
                }
            }, completionHandler: nil)
    }

    @discardableResult
    public func show(
        content: String, level: NerwNotificationLevel = .info, progressive: Bool = false,
        id: UUID? = nil
    ) -> UUID {
        let finalId = id ?? UUID()
        let view = NotificationItemView(
            id: finalId, content: content, level: level, progressive: progressive)

        DispatchQueue.main.async {
            self.addNotification(view: view, progressive: progressive)
        }
        return finalId
    }

    public func dismiss(id: UUID) {
        DispatchQueue.main.async {
            self.removeNotification(id: id)
        }
    }

    private func addNotification(view: NotificationItemView, progressive: Bool) {
        // Insert at 0 so it's the frontmost item
        activeNotifications.insert(view, at: 0)
        panel.contentView?.addSubview(view)

        // Initial state for drop-in animation
        guard NSScreen.main != nil else { return }
        let panelWidth: CGFloat = 400
        let panelHeight: CGFloat = 160
        let size = view.fittingSize
        let startY = panelHeight + 20  // start above the panel
        let startX = (panelWidth - size.width) / 2
        view.frame = NSRect(x: startX, y: startY, width: size.width, height: size.height)
        view.alphaValue = 0.0

        if !panel.isVisible {
            panel.alphaValue = 1.0
            panel.orderFront(nil)
        }

        updateStackLayout()

        if !progressive {
            let timer = Timer.scheduledTimer(withTimeInterval: displayDuration, repeats: false) {
                [weak self] _ in
                self?.removeNotification(id: view.id)
            }
            dismissalTimers[view.id] = timer
        }
    }

    private func removeNotification(id: UUID) {
        guard let index = activeNotifications.firstIndex(where: { $0.id == id }) else { return }
        let view = activeNotifications[index]

        // Animate removal
        NSAnimationContext.runAnimationGroup(
            { context in
                context.duration = 0.3
                context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                view.animator().alphaValue = 0
                // Slide up to exit
                var exitFrame = view.frame
                exitFrame.origin.y += 20
                view.animator().frame = exitFrame
            },
            completionHandler: {
                view.removeFromSuperview()

                if let activeIndex = self.activeNotifications.firstIndex(where: { $0.id == id }) {
                    self.activeNotifications.remove(at: activeIndex)
                }

                self.dismissalTimers[id]?.invalidate()
                self.dismissalTimers.removeValue(forKey: id)

                if self.activeNotifications.isEmpty {
                    self.panel.orderOut(nil)
                } else {
                    self.updateStackLayout()
                }
            })
    }
}
