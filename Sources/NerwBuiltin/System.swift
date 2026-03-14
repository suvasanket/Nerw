import ApplicationServices
import Cocoa
import NerwCore
import UniformTypeIdentifiers

public class System {
    public static let shared = System()

    private let systemIcon = NSImage(systemSymbolName: "gearshape.2", accessibilityDescription: nil)

    private var lastActiveApp: NSRunningApplication?

    private init() {
        self.lastActiveApp = NSWorkspace.shared.frontmostApplication

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(appDidActivate(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
    }

    @objc private func appDidActivate(_ notification: Notification) {
        guard
            let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                as? NSRunningApplication
        else { return }
        // Track last active app that IS NOT Nerw (self)
        if app.processIdentifier != NSRunningApplication.current.processIdentifier {
            self.lastActiveApp = app
        }
    }

    // MARK: - Public API

    // MARK: - Public API

    public func getAllActions() -> [NerwAction] {
        return [
            // (Removed Define action, handled dynamically in SearchService)

            // Empty Downloads
            NerwAction(
                id: "nerw.system.emptydownloads",
                title: "Empty Downloads",
                subtitle: "Move all Downloads folder contents to Trash",
                icon: .image(
                    NSImage(named: "download") ?? NSImage(
                        systemSymbolName: "arrow.down.circle", accessibilityDescription: nil)!),
                triggers: ["empty downloads"],
                type: .instant(perform: { _ in self.emptyDownloads() })
            ),

            // Sleep
            NerwAction(
                id: "nerw.system.sleep",
                title: "Sleep",
                subtitle: "Put your Mac to sleep",
                icon: .system("moon.zzz.fill"),
                triggers: ["sleep"],
                type: .instant(perform: { _ in self.sleep() })
            ),

            // Eject All
            NerwAction(
                id: "nerw.system.ejectall",
                title: "Eject All",
                subtitle: "Eject all external volumes",
                icon: .system("eject.fill"),
                triggers: ["eject all"],
                type: .instant(perform: { _ in self.ejectAll() })
            ),

            // Eject (Argument)
            NerwAction(
                id: "nerw.system.eject",
                title: "Eject",
                subtitle: "Eject a specific volume",
                icon: .image(
                    NSImage(named: "eject") ?? NSImage(
                        systemSymbolName: "eject", accessibilityDescription: nil)!),
                triggers: ["eject"],
                type: .args(
                    placeholder: "Volume Name",
                    searcher: { _, query, completion in
                        self.searchVolumes(query: query, completion: completion)
                    },
                    perform: { _, volumeName in
                        if !volumeName.isEmpty {
                            self.eject(volumeName: volumeName)
                        }
                    }
                )
            ),
        ]
    }

    public func findByTrigger(_ trigger: String) -> NerwAction? {
        let lowerTrigger = trigger.lowercased()

        switch lowerTrigger {
        // (Removed explicit define trigger, handled in SearchService)

        case "empty downloads":
            return NerwAction(
                id: "nerw.system.emptydownloads",
                title: "Empty Downloads",
                subtitle: "Move all Downloads folder contents to Trash",
                icon: .image(
                    NSImage(named: "download") ?? NSImage(
                        systemSymbolName: "arrow.down.circle", accessibilityDescription: nil)!),
                triggers: ["empty downloads"],
                type: .instant(perform: { _ in self.emptyDownloads() })
            )

        case "sleep":
            return NerwAction(
                id: "nerw.system.sleep",
                title: "Sleep",
                subtitle: "Put your Mac to sleep",
                icon: .system("moon.zzz.fill"),
                triggers: ["sleep"],
                type: .instant(perform: { _ in self.sleep() })
            )

        case "eject all":
            return NerwAction(
                id: "nerw.system.ejectall",
                title: "Eject All",
                subtitle: "Eject all external volumes",
                icon: .system("eject.fill"),
                triggers: ["eject all"],
                type: .instant(perform: { _ in self.ejectAll() })
            )

        case "eject":
            return NerwAction(
                id: "nerw.system.eject",
                title: "Eject",
                subtitle: "Eject a specific volume",
                icon: .image(
                    NSImage(named: "eject") ?? NSImage(
                        systemSymbolName: "eject", accessibilityDescription: nil)!),
                triggers: ["eject"],
                type: .args(
                    placeholder: "Volume Name",
                    searcher: { _, query, completion in
                        self.searchVolumes(query: query, completion: completion)
                    },
                    perform: { _, volumeName in
                        if !volumeName.isEmpty {
                            self.eject(volumeName: volumeName)
                        }
                    }
                )
            )

        // Quit Process - Removed

        //        case "menu search":
        //            return BuiltinResult(
        //                title: "Menu Bar Search",
        //                subtitle: "Search menu items of the active application",
        //                icon: NSImage(systemSymbolName: "menubar.rectangle", accessibilityDescription: nil),
        //                supportsArguments: true,
        //                handler: { _ in },
        //                searcher: { query, completion in self.searchMenuItems(query: query, completion: completion) }
        //            )

        default:
            return nil
        }
    }

    // MARK: - Actions

    private func emptyDownloads() {
        let downloadsPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Downloads")

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let contents = try FileManager.default.contentsOfDirectory(
                    at: downloadsPath,
                    includingPropertiesForKeys: nil
                )

                for item in contents {
                    try FileManager.default.trashItem(at: item, resultingItemURL: nil)
                }
            } catch {
                print("[System] Empty Downloads error: \(error)")
            }
        }
    }

    private func sleep() {
        let script = "tell application \"System Events\" to sleep"
        runAppleScript(script)
    }

    private func eject(volumeName: String) {
        guard let url = getVolumeURL(name: volumeName) else { return }

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try NSWorkspace.shared.unmountAndEjectDevice(at: url)
            } catch {
                print("[System] Eject failed for \(volumeName): \(error)")
            }
        }
    }

    private func ejectAll() {
        DispatchQueue.global(qos: .userInitiated).async {
            let keys: [URLResourceKey] = [
                .volumeIsEjectableKey, .volumeIsRemovableKey, .volumeIsInternalKey,
            ]
            guard
                let urls = FileManager.default.mountedVolumeURLs(
                    includingResourceValuesForKeys: keys, options: [.skipHiddenVolumes])
            else { return }

            for url in urls {
                guard let resourceValues = try? url.resourceValues(forKeys: Set(keys)),
                    let isEjectable = resourceValues.volumeIsEjectable,
                    isEjectable
                else { continue }

                do {
                    try NSWorkspace.shared.unmountAndEjectDevice(at: url)
                } catch {
                    print("[System] Failed to eject \(url.lastPathComponent): \(error)")
                }
            }
        }
    }

    // MARK: - Process Management (Moved to QuickAction)

    // MARK: - Volume Search

    private func searchVolumes(query: String, completion: @escaping ([NerwAction]) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            var results: [NerwAction] = []

            let keys: [URLResourceKey] = [.volumeIsEjectableKey, .volumeNameKey]
            if let urls = FileManager.default.mountedVolumeURLs(
                includingResourceValuesForKeys: keys, options: [.skipHiddenVolumes])
            {

                let lowerQuery = query.lowercased()

                let ejectableVolumes = urls.compactMap { url -> (String, URL)? in
                    guard let values = try? url.resourceValues(forKeys: Set(keys)),
                        let isEjectable = values.volumeIsEjectable,
                        isEjectable,
                        let name = values.volumeName
                    else { return nil }
                    return (name, url)
                }

                let filtered = ejectableVolumes.filter { (name, _) in
                    return query.isEmpty || name.lowercased().contains(lowerQuery)
                }

                results = filtered.map { (name, url) in
                    return NerwAction(
                        id: "nerw.system.volume.\(name)",
                        title: name,
                        subtitle: url.path,
                        icon: .file(url),
                        triggers: [name],
                        type: .instant(perform: { _ in
                            self.eject(volumeName: name)
                        })
                    )
                }
            }

            DispatchQueue.main.async {
                completion(results)
            }
        }
    }

    // MARK: - Menu Bar Search

    private func searchMenuItems(query: String, completion: @escaping ([NerwAction]) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard AXIsProcessTrusted() else {
                let result = NerwAction(
                    id: "nerw.system.menusExp.permission",
                    title: "Accessibility Permissions Needed",
                    subtitle: "Press Enter to open System Settings",
                    icon: .system("hand.raised.fill"),
                    triggers: [],
                    type: .instant(perform: { _ in
                        let url = URL(
                            string:
                                "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
                        )!
                        NSWorkspace.shared.open(url)
                    })
                )
                DispatchQueue.main.async { completion([result]) }
                return
            }

            guard let targetApp = self.lastActiveApp else {
                DispatchQueue.main.async { completion([]) }
                return
            }

            let pid = targetApp.processIdentifier
            let appElement = AXUIElementCreateApplication(pid)

            var menuBarValue: AnyObject?
            let result = AXUIElementCopyAttributeValue(
                appElement, kAXMenuBarAttribute as CFString, &menuBarValue)

            guard result == .success, let menuBar = menuBarValue else {
                DispatchQueue.main.async { completion([]) }
                return
            }

            let menuBarElement = menuBar as! AXUIElement
            var foundItems: [MenuItem] = []

            // Crawl
            self.crawlMenu(
                element: menuBarElement, path: [], query: query.lowercased(), results: &foundItems)

            let results = foundItems.map { item -> NerwAction in
                // Generate a stable ID if possible, or random
                let pathString = item.path.joined(separator: " > ")
                return NerwAction(
                    id:
                        "nerw.system.menusExp.\(targetApp.processIdentifier).\(pathString.hashValue)",
                    title: item.title,
                    subtitle: "\(targetApp.localizedName ?? "App") > \(pathString)",
                    icon: .system("menubar.arrow.down.rectangle"),
                    triggers: [],
                    type: .instant(perform: { _ in
                        self.performMenuAction(element: item.element, app: targetApp)
                    })
                )
            }

            DispatchQueue.main.async {
                completion(results)
            }
        }
    }

    private struct MenuItem {
        let title: String
        let path: [String]
        let element: AXUIElement
    }

    // Recursive crawling with limit
    private func crawlMenu(
        element: AXUIElement, path: [String], query: String, results: inout [MenuItem],
        depth: Int = 0
    ) {
        if depth > 5 { return }  // Depth limiter

        // Get Children
        var childrenValue: AnyObject?
        let res = AXUIElementCopyAttributeValue(
            element, kAXChildrenAttribute as CFString, &childrenValue)
        guard res == .success, let children = childrenValue as? [AXUIElement] else { return }

        for child in children {
            // Check Enabled (Optional optimization: skip disabled? User might want to see them though. Let's show all.)
            // Get Title
            var titleValue: AnyObject?
            AXUIElementCopyAttributeValue(child, kAXTitleAttribute as CFString, &titleValue)
            guard let title = titleValue as? String, !title.isEmpty else { continue }

            // Filter: Apple Menu usually has empty title or system items.
            // Also "Apple" menu is often first child of MenuBar.
            // Path check: if depth == 0, path is top level menus (File, Edit).
            // Usually we want items INDSIDE them.

            var isLeaf = true
            // Check if it has children (Submenu)
            // A menu item usually has a kAXSubmenuAttribute? Or children?
            // Standard: MenuItem -> Children -> List? No.
            // MenuItem -> kAXSubmenuAttribute -> Menu -> Children -> MenuItem...
            // Or MenuItem has children directly?
            // Let's check Submenu attribute first

            var submenuValue: AnyObject?
            // Use "AXSubmenu" string literal
            let subRes = AXUIElementCopyAttributeValue(
                child, "AXSubmenu" as CFString, &submenuValue)
            // Let's rely on standard kAXSubmenuAttribute or just recurse children directly if any.
            // AXMenuItems having children usually means submenu.

            // Actually, checking children of a MenuItem directly often fails or returns empty if it's not open?
            // Standard crawler: MenuItem -> kAXSubmenuAttribute

            var subMenuElement: AXUIElement?
            if subRes == .success {
                subMenuElement = submenuValue as! AXUIElement?
            }

            if let subMenu = subMenuElement {
                // It's a menu (submenu). Recurse.
                let newPath = path + [title]
                crawlMenu(
                    element: subMenu, path: newPath, query: query, results: &results,
                    depth: depth + 1)
                isLeaf = false
            } else {
                // Try getting children directly (flat menu?)
                // Rarely happens for standard menus.
                // Assume Leaf.
            }

            if isLeaf {
                // Match Query
                // Only match leafs? Or match path too?
                // Match title mostly.
                if query.isEmpty || title.lowercased().contains(query) {
                    // Valid Result
                    // Exclude top level items themselves? (Like just "File")
                    if !path.isEmpty {
                        results.append(MenuItem(title: title, path: path, element: child))
                    }
                }
            }
        }
    }

    private func performMenuAction(element: AXUIElement, app: NSRunningApplication) {
        // Activate app first?
        app.activate(options: .activateIgnoringOtherApps)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            AXUIElementPerformAction(element, kAXPressAction as CFString)
        }
    }

    // MARK: - Helpers

    private func getVolumeURL(name: String) -> URL? {
        let keys: [URLResourceKey] = [.volumeNameKey]
        guard
            let urls = FileManager.default.mountedVolumeURLs(
                includingResourceValuesForKeys: keys, options: [])
        else { return nil }
        return urls.first { url in
            (try? url.resourceValues(forKeys: Set(keys)).volumeName) == name
        }
    }

    private func runAppleScript(_ source: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            let script = NSAppleScript(source: source)
            var error: NSDictionary?
            script?.executeAndReturnError(&error)
            if let error = error {
                print("[System] AppleScript error: \(error)")
            }
        }
    }

    private func runShellCommand(command: String) {
        let task = Process()
        task.launchPath = "/bin/zsh"
        task.arguments = ["-c", command]
        try? task.run()
    }

    // MARK: - System Settings

    private struct SystemSetting {
        let name: String
        let icon: String  // SF Symbol
        let paneID: String
    }

    private let systemSettings: [SystemSetting] = [
        SystemSetting(
            name: "Appearance", icon: "paintbrush.fill", paneID: "com.apple.preference.general"),
        SystemSetting(
            name: "Wallpaper", icon: "photo.fill",
            paneID: "com.apple.preference.desktopscreeneffect"),
        SystemSetting(
            name: "Screen Saver", icon: "display.and.arrow.down",
            paneID: "com.apple.preference.desktopscreeneffect?ScreenSaver"),
        SystemSetting(
            name: "Dock & Menu Bar", icon: "menubar.rectangle", paneID: "com.apple.preference.dock"),
        SystemSetting(
            name: "Control Center", icon: "switch.2", paneID: "com.apple.preference.controlcenter"),
        SystemSetting(name: "Siri", icon: "mic.fill", paneID: "com.apple.preference.speech"),
        SystemSetting(
            name: "Spotlight", icon: "magnifyingglass", paneID: "com.apple.preference.spotlight"),
        SystemSetting(name: "Language & Region", icon: "globe", paneID: "com.apple.localization"),
        SystemSetting(
            name: "Notifications", icon: "bell.fill", paneID: "com.apple.preference.notifications"),
        SystemSetting(
            name: "Internet Accounts", icon: "at", paneID: "com.apple.preferences.internetaccounts"),
        SystemSetting(
            name: "Users & Groups", icon: "person.2.fill", paneID: "com.apple.preferences.users"),
        SystemSetting(
            name: "Accessibility", icon: "figure.wave.circle.fill",
            paneID: "com.apple.preference.universalaccess"),
        SystemSetting(
            name: "Screen Time", icon: "hourglass", paneID: "com.apple.preference.screentime"),
        SystemSetting(
            name: "Extensions", icon: "puzzlepiece.fill", paneID: "com.apple.preferences.extensions"
        ),
        SystemSetting(
            name: "Security & Privacy", icon: "lock.shield.fill",
            paneID: "com.apple.preference.security"),
        SystemSetting(
            name: "Software Update", icon: "gear.badge.arrow.2.clockwise",
            paneID: "com.apple.preferences.softwareupdate"),
        SystemSetting(name: "Network", icon: "network", paneID: "com.apple.preference.network"),
        SystemSetting(
            name: "Bluetooth", icon: "iphone.gen3.radiowaves.left.and.right",
            paneID: "com.apple.preferences.bluetooth"),
        SystemSetting(
            name: "Sound", icon: "speaker.wave.2.fill", paneID: "com.apple.preference.sound"),
        SystemSetting(
            name: "Printers & Scanners", icon: "printer.fill",
            paneID: "com.apple.preference.printfax"),
        SystemSetting(
            name: "Keyboard", icon: "keyboard.fill", paneID: "com.apple.preference.keyboard"),
        SystemSetting(
            name: "Trackpad", icon: "hand.point.up.left.fill",
            paneID: "com.apple.preference.trackpad"),
        SystemSetting(name: "Mouse", icon: "mouse.fill", paneID: "com.apple.preference.mouse"),
        SystemSetting(name: "Displays", icon: "display", paneID: "com.apple.preference.displays"),
        SystemSetting(
            name: "Sidecar", icon: "ipad.and.arrow.forward", paneID: "com.apple.preference.sidecar"),
        SystemSetting(
            name: "Energy Saver", icon: "bolt.fill", paneID: "com.apple.preference.energysaver"),
        SystemSetting(name: "Battery", icon: "battery.100", paneID: "com.apple.preference.battery"),
        SystemSetting(
            name: "Date & Time", icon: "clock.fill", paneID: "com.apple.preference.datetime"),
        SystemSetting(
            name: "Sharing", icon: "folder.fill.badge.person.crop",
            paneID: "com.apple.preferences.sharing"),
        SystemSetting(
            name: "Time Machine", icon: "clock.arrow.circlepath", paneID: "com.apple.prefs.backup"),
        SystemSetting(
            name: "Startup Disk", icon: "internaldrive.fill",
            paneID: "com.apple.preference.startupdisk"),
        SystemSetting(
            name: "Profiles", icon: "person.badge.shield.checkmark.fill",
            paneID: "com.apple.preferences.configurationprofiles"),
    ]

    public func listSystemSettings(query: String, completion: @escaping ([NerwAction]) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let lowerQuery = query.lowercased()
            let filtered = self.systemSettings.filter { setting in
                query.isEmpty || setting.name.lowercased().contains(lowerQuery)
            }

            let results = filtered.map { setting in
                NerwAction(
                    id: "nerw.system.settings.\(setting.paneID)",
                    title: setting.name,
                    subtitle: "System Preference Pane",
                    icon: .system(setting.icon),
                    triggers: [setting.name],
                    type: .instant(perform: { _ in
                        self.openSystemSetting(paneID: setting.paneID)
                    })
                )
            }

            DispatchQueue.main.async { completion(results) }
        }
    }

    private func openSystemSetting(paneID: String) {
        let urlString = "x-apple.systempreferences:\(paneID)"
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Dictionary Search

    public func searchDictionary(query: String, completion: @escaping ([NerwAction]) -> Void) {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            completion([])
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let nsString = query as NSString
            let range = DCSGetTermRangeInString(nil, nsString, 0)

            // Note: DCSGetTermRangeInString returns kCFNotFound if it doesn't recognize the word,
            // but DCSCopyTextDefinition sometimes still returns a definition. We will just try to fetch it.
            let definitionCFString = DCSCopyTextDefinition(
                nil, nsString as CFString, CFRangeMake(0, nsString.length))

            var results: [NerwAction] = []

            if let definition = definitionCFString?.takeRetainedValue() as String? {
                results.append(
                    NerwAction(
                        id: "nerw.system.define.result",
                        title: query,
                        subtitle: "Open in Dictionary",
                        icon: .system("text.book.closed.fill"),
                        peek: NerwAction.PeekData(
                            title: query,
                            text: definition,
                            icon: .system("character.book.closed.fill"),
                            primaryActionName: nil,
                            secondaryActionName: nil
                        ),
                        triggers: [query],
                        type: .instant(perform: { _ in
                            if let encodedQuery = query.addingPercentEncoding(
                                withAllowedCharacters: .urlHostAllowed),
                                let url = URL(string: "dict://\(encodedQuery)")
                            {
                                NSWorkspace.shared.open(url)
                            }
                        })
                    )
                )
            } else {
                results.append(
                    NerwAction(
                        id: "nerw.system.define.notfound",
                        title: "No definition found for '\(query)'",
                        subtitle: "Press Enter to search Webster online",
                        icon: .system("magnifyingglass"),
                        triggers: [],
                        type: .instant(perform: { _ in
                            if let encodedQuery = query.addingPercentEncoding(
                                withAllowedCharacters: .urlHostAllowed),
                                let url = URL(
                                    string:
                                        "https://www.merriam-webster.com/dictionary/\(encodedQuery)"
                                )
                            {
                                NSWorkspace.shared.open(url)
                            }
                        })
                    )
                )
            }

            DispatchQueue.main.async { completion(results) }
        }
    }
}
