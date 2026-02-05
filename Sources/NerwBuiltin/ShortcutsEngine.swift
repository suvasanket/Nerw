import Cocoa
import NerwBuiltin
import NerwCore

public class ShortcutsEngine {
    public static let shared = ShortcutsEngine()

    private var cachedShortcuts: [String] = []
    private var isRefreshing = false

    private init() {}

    public func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true

        Task {
            do {
                let shortcuts = try await ShortcutsManager.shared.listShortcuts()
                DispatchQueue.main.async { [weak self] in
                    self?.cachedShortcuts = shortcuts
                    self?.isRefreshing = false
                }
            } catch {
                print("Nerw: Failed to refresh shortcuts: \(error)")
                self.isRefreshing = false
            }
        }
    }

    public func getAllActions() -> [NerwAction] {
        return cachedShortcuts.map { name in
            NerwAction(
                id: "nerw.shortcuts.main.\(name)",
                title: name,
                subtitle: "Run Shortcut",
                icon: .system("command"),
                triggers: [name],
                type: .instant(perform: { _ in
                    Task {
                        try? await ShortcutsManager.shared.runShortcut(name)
                    }
                })
            )
        }
    }
}
