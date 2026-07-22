import Cocoa
import NerwAction
import NerwCore
import NerwUtils

public class ShortcutsEngine: @unchecked Sendable {
    public static let shared = ShortcutsEngine()

    private var cachedShortcuts: [String] = []
    private var isRefreshing = false
    private var lastCheckedModDate: Date? = nil
    private var cachedCombinedIcon: NSImage?

    private let shortcutsStoragePaths: [String] = [
        NSString(
            string: "~/Library/Group Containers/group.com.apple.shortcuts/Database/Shortcuts.sqlite"
        ).expandingTildeInPath,
        NSString(string: "~/Library/Shortcuts").expandingTildeInPath,
    ]

    private init() {}

    /// Returns the composite icon featuring the Shortcuts app icon as main and bolt.fill as secondary badge.
    public var icon: NerwAction.IconType {
        return .image(combinedShortcutsIcon())
    }

    private func combinedShortcutsIcon() -> NSImage {
        if let existing = cachedCombinedIcon {
            return existing
        }

        // 1. Resolve Shortcuts app icon as main
        let appIcon: NSImage
        if let appURL = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: "com.apple.shortcuts")
        {
            appIcon = NSWorkspace.shared.icon(forFile: appURL.path)
        } else if FileManager.default.fileExists(atPath: "/System/Applications/Shortcuts.app") {
            appIcon = NSWorkspace.shared.icon(forFile: "/System/Applications/Shortcuts.app")
        } else {
            appIcon =
                NSImage(systemSymbolName: "command", accessibilityDescription: nil) ?? NSImage()
        }

        // 2. Resolve white bolt.fill badge symbol
        let boltSymbol: NSImage
        if let rawBolt = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: nil) {
            if #available(macOS 12.0, *) {
                let config = NSImage.SymbolConfiguration(paletteColors: [.white])
                boltSymbol = rawBolt.withSymbolConfiguration(config) ?? rawBolt
            } else {
                boltSymbol = rawBolt
            }
        } else {
            boltSymbol = NSImage()
        }

        // 3. Composite using project-wide standard IconUtils.combinedIcon helper
        let image = IconUtils.combinedIcon(
            mainImage: appIcon,
            subImage: boltSymbol,
            subIconScale: 0.5,
            mainIconScale: 1.0,
            isTemplate: false
        )

        self.cachedCombinedIcon = image
        return image
    }

    /// Performs an asynchronous, zero-UI-blocking timestamp check on macOS Shortcuts storage.
    /// Only triggers a full CLI re-index if storage files were modified since last check.
    public func refreshIfStale() {
        guard ConfigManager.shared.config.showShortcutsInMain else { return }

        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            let currentModDate = self.getMaxStorageModificationDate()

            if let last = self.lastCheckedModDate, let current = currentModDate, current <= last {
                // Storage has not changed since last check. Zero processes spawned!
                return
            }

            self.refresh(newModDate: currentModDate)
        }
    }

    /// Asynchronously fetches the list of shortcuts from macOS CLI.
    public func refresh(newModDate: Date? = nil) {
        guard !isRefreshing else { return }
        isRefreshing = true

        Task {
            do {
                let shortcuts = try await ShortcutsManager.shared.listShortcuts()
                let maxDate = newModDate ?? self.getMaxStorageModificationDate()
                DispatchQueue.main.async { [weak self] in
                    self?.cachedShortcuts = shortcuts
                    self?.lastCheckedModDate = maxDate
                    self?.isRefreshing = false
                }
            } catch {
                print("Nerw: Failed to refresh shortcuts: \(error)")
                DispatchQueue.main.async { [weak self] in
                    self?.isRefreshing = false
                }
            }
        }
    }

    private func getMaxStorageModificationDate() -> Date? {
        let fm = FileManager.default
        var maxDate: Date? = nil

        for path in shortcutsStoragePaths {
            if let attrs = try? fm.attributesOfItem(atPath: path),
                let modDate = attrs[.modificationDate] as? Date
            {
                if maxDate == nil || modDate > maxDate! {
                    maxDate = modDate
                }
            }
        }
        return maxDate
    }

    /// Returns actions formatted for Nerw main index.
    /// Uses .hybrid type to allow Enter (Instant execution) and Tab (Argument prompt execution).
    public func getAllActions() -> [NerwAction] {
        guard ConfigManager.shared.config.showShortcutsInMain else { return [] }

        let currentIcon = self.icon

        return cachedShortcuts.map { name in
            let argSubAction = NerwAction(
                id: "nerw.shortcuts.arg.\(name)",
                title: name,
                subtitle: "Run shortcut with argument",
                icon: currentIcon,
                triggers: [name],
                type: .arg(
                    placeholders: ["Arg"],
                    perform: { _, args in
                        let inputArg = args.first ?? ""
                        Task {
                            do {
                                try await ShortcutsManager.shared.runShortcut(name, input: inputArg)
                            } catch {
                                Nerw.notify(
                                    "Failed to run shortcut '\(name)': \(error.localizedDescription)",
                                    level: .error)
                            }
                        }
                    }
                )
            )

            return NerwAction(
                id: "nerw.shortcuts.main.\(name)",
                title: name,
                subtitle: "Shortcut",
                icon: currentIcon,
                triggers: [name],
                type: .hybrid(
                    perform: { _ in
                        Task {
                            do {
                                try await ShortcutsManager.shared.runShortcut(name)
                            } catch {
                                Nerw.notify(
                                    "Failed to run shortcut '\(name)': \(error.localizedDescription)",
                                    level: .error)
                            }
                        }
                    },
                    action: NerwActionBox(argSubAction)
                )
            )
        }
    }
}
