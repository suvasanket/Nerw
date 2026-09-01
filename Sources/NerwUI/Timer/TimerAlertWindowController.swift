import Cocoa
import NerwBuiltin
import NerwCore

public class TimerAlertWindowController: NSWindowController {
    public static let shared = TimerAlertWindowController()

    private var panel: TimerAlertPanel!
    private var alertVC: TimerAlertViewController!
    private var pendingTimers: [NerwTimer] = []
    private var activeTimer: NerwTimer?

    public init() {
        super.init(window: nil)
        setupPanel()
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupPanel() {
        let contentRect = NSRect(x: 0, y: 0, width: 420, height: 260)
        panel = TimerAlertPanel(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        alertVC = TimerAlertViewController()
        alertVC.onComplete = { [weak self] in
            self?.handleComplete()
        }
        alertVC.onSnooze = { [weak self] in
            self?.handleSnooze()
        }

        panel.contentViewController = alertVC
        panel.onComplete = { [weak self] in
            self?.handleComplete()
        }
        panel.onSnooze = { [weak self] in
            self?.handleSnooze()
        }
        panel.onDismiss = { [weak self] in
            self?.handleComplete()
        }

        self.window = panel
    }

    public func show(for timer: NerwTimer) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            if self.panel.isVisible, let current = self.activeTimer, current.id != timer.id {
                // If a popup is already visible, queue the new timer
                if !self.pendingTimers.contains(where: { $0.id == timer.id }) {
                    self.pendingTimers.append(timer)
                }
                return
            }

            self.activeTimer = timer
            self.alertVC.configure(with: timer)
            self.centerPanelOnScreen()

            // Entrance Spring Animation
            self.panel.alphaValue = 0.0
            self.panel.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)

            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.25
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                self.panel.animator().alphaValue = 1.0
            }

            self.alertVC.animateIconPulse()
        }
    }

    public func hide() {
        TimerSoundPlayer.shared.stop()

        NSAnimationContext.runAnimationGroup(
            { context in
                context.duration = 0.2
                context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                self.panel.animator().alphaValue = 0.0
            },
            completionHandler: { [weak self] in
                guard let self = self else { return }
                self.panel.orderOut(nil)
                self.activeTimer = nil

                // Show next queued timer if any
                if !self.pendingTimers.isEmpty {
                    let next = self.pendingTimers.removeFirst()
                    self.show(for: next)
                }
            })
    }

    private func handleComplete() {
        if let current = activeTimer {
            TimerManager.shared.completeTimer(id: current.id)
        }
        hide()
    }

    private func handleSnooze() {
        if let current = activeTimer {
            TimerManager.shared.snoozeTimer(id: current.id, duration: 300)
        }
        hide()
    }

    private func centerPanelOnScreen() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let screenRect = screen.visibleFrame
        let panelSize = NSSize(width: 420, height: 260)

        let x = screenRect.midX - (panelSize.width / 2)
        let y = screenRect.midY - (panelSize.height / 2)

        panel.setFrame(NSRect(origin: NSPoint(x: x, y: y), size: panelSize), display: true)
    }
}
