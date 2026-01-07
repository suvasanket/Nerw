import Cocoa
import ApplicationServices
import UniformTypeIdentifiers
import CoreWLAN
import IOBluetooth


import NerwCore


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
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
        // Track last active app that IS NOT Nerw (self)
        if app.processIdentifier != NSRunningApplication.current.processIdentifier {
            self.lastActiveApp = app
        }
    }

    // MARK: - Public API

    public func check(query: String) -> NerwAction? {
        let lowerQuery = query.lowercased()

        // Empty Downloads
        if "empty downloads".starts(with: lowerQuery) && lowerQuery.count >= 6 {
            return NerwAction(
                id: "nerw.system.emptydownloads",
                title: "Empty Downloads",
                subtitle: "Move all Downloads folder contents to Trash",
                icon: .image(NSImage(named: "download") ?? NSImage(systemSymbolName: "arrow.down.circle", accessibilityDescription: nil)!),
                triggers: ["empty downloads"],
                arguments: nil,
                handler: { _ in self.emptyDownloads() }
            )
        }

        // Sleep
        if "sleep".starts(with: lowerQuery) {
            return NerwAction(
                id: "nerw.system.sleep",
                title: "Sleep",
                subtitle: "Put your Mac to sleep",
                icon: .system("moon.zzz.fill"),
                triggers: ["sleep"],
                arguments: nil,
                handler: { _ in self.sleep() }
            )
        }

        // Eject All
        if "eject all".starts(with: lowerQuery) && lowerQuery.count >= 6 {
            return NerwAction(
                id: "nerw.system.ejectall",
                title: "Eject All",
                subtitle: "Eject all external volumes",
                icon: .system("eject.fill"),
                triggers: ["eject all"],
                arguments: nil,
                handler: { _ in self.ejectAll() }
            )
        }

        // Eject (with argument)
        if "eject".starts(with: lowerQuery) && !query.contains("all") {
            return NerwAction(
                id: "nerw.system.eject",
                title: "Eject",
                subtitle: "Eject a specific volume",
                icon: .image(NSImage(named: "eject") ?? NSImage(systemSymbolName: "eject", accessibilityDescription: nil)!),
                triggers: ["eject"],
                arguments: ["Volume Name"],
                handler: { volumeName in
                    if !volumeName.isEmpty {
                        self.eject(volumeName: volumeName)
                    }
                },
                searcher: { query, completion in
                    self.searchVolumes(query: query, completion: completion)
                }
            )
        }

        // Menu Bar Search (WIP - Disabled)
        /*
        if "menu search".starts(with: lowerQuery) {
            return BuiltinResult(
                title: "Menu Bar Search",
                subtitle: "Search menu items of the active application",
                icon: NSImage(systemSymbolName: "menubar.rectangle", accessibilityDescription: nil),
                supportsArguments: true,
                handler: { _ in }, // Execution happens on leaf selection
                searcher: { query, completion in
                    self.searchMenuItems(query: query, completion: completion)
                }
            )
        }
        */

        // Quit Process (Guard Railed)
        if "ps".starts(with: lowerQuery) || "process".starts(with: lowerQuery) {
            return NerwAction(
                id: "nerw.system.process",
                title: "Quit Process",
                subtitle: "Terminate a running application",
                icon: .image(NSImage(named: "quit") ?? NSImage(systemSymbolName: "xmark.circle", accessibilityDescription: nil)!),
                triggers: ["ps", "process"],
                arguments: ["Process Name"],
                handler: { appName in
                    self.quitProcess(name: appName)
                },
                searcher: { query, completion in
                    self.searchProcesses(query: query, completion: completion)
                }
            )
        }

        // WiFi
        if "wifi".starts(with: lowerQuery) {
            return NerwAction(
                id: "nerw.system.wifi",
                title: "WiFi",
                subtitle: "Toggle WiFi or Connect to Network",
                icon: .image(NSImage(named: "wifi") ?? NSImage(systemSymbolName: "wifi", accessibilityDescription: nil)!),
                triggers: ["wifi"],
                arguments: ["SSID"],
                handler: { _ in self.toggleWifi() },
                searcher: { query, completion in
                    self.listAndSearchNetworks(query: query, completion: completion)
                }
            )
        }

        // Bluetooth
        if "bluetooth".starts(with: lowerQuery) || "bt".starts(with: lowerQuery) && lowerQuery.count >= 2 {
             return NerwAction(
                id: "nerw.system.bluetooth",
                title: "Bluetooth",
                subtitle: "Toggle Bluetooth or Connect Device",
                icon: .image(NSImage(named: "bluetooth") ?? NSImage(systemSymbolName: "iphone.gen3.radiowaves.left.and.right", accessibilityDescription: nil)!),
                triggers: ["bluetooth", "bt"],
                arguments: ["Device Name"],
                handler: { _ in self.toggleBluetooth() },
                searcher: { query, completion in
                    self.listAndSearchBluetoothDevices(query: query, completion: completion)
                }
            )
        }

        return nil
    }

    public func findByTrigger(_ trigger: String) -> NerwAction? {
        let lowerTrigger = trigger.lowercased()

        switch lowerTrigger {
        case "empty downloads":
            return NerwAction(
                id: "nerw.system.emptydownloads",
                title: "Empty Downloads",
                subtitle: "Move all Downloads folder contents to Trash",
                icon: .image(NSImage(named: "download") ?? NSImage(systemSymbolName: "arrow.down.circle", accessibilityDescription: nil)!),
                triggers: ["empty downloads"],
                arguments: nil,
                handler: { _ in self.emptyDownloads() }
            )

        case "sleep":
            return NerwAction(
                id: "nerw.system.sleep",
                title: "Sleep",
                subtitle: "Put your Mac to sleep",
                icon: .system("moon.zzz.fill"),
                triggers: ["sleep"],
                arguments: nil,
                handler: { _ in self.sleep() }
            )

        case "eject all":
            return NerwAction(
                id: "nerw.system.ejectall",
                title: "Eject All",
                subtitle: "Eject all external volumes",
                icon: .system("eject.fill"),
                triggers: ["eject all"],
                arguments: nil,
                handler: { _ in self.ejectAll() }
            )

        case "eject":
            return NerwAction(
                id: "nerw.system.eject",
                title: "Eject",
                subtitle: "Eject a specific volume",
                icon: .image(NSImage(named: "eject") ?? NSImage(systemSymbolName: "eject", accessibilityDescription: nil)!),
                triggers: ["eject"],
                arguments: ["Volume Name"],
                handler: { volumeName in
                    if !volumeName.isEmpty {
                        self.eject(volumeName: volumeName)
                    }
                },
                searcher: { query, completion in
                    self.searchVolumes(query: query, completion: completion)
                }
            )

        case "ps", "process":
            return NerwAction(
                id: "nerw.system.process",
                title: "Quit Process",
                subtitle: "Terminate a running application",
                icon: .image(NSImage(named: "quit") ?? NSImage(systemSymbolName: "xmark.circle", accessibilityDescription: nil)!),
                triggers: ["ps", "process"],
                arguments: ["Process Name"],
                handler: { appName in self.quitProcess(name: appName) },
                searcher: { query, completion in self.searchProcesses(query: query, completion: completion) }
            )

        case "wifi":
            return NerwAction(
                id: "nerw.system.wifi",
                title: "WiFi",
                subtitle: "Toggle WiFi or Connect to Network",
                icon: .image(NSImage(named: "wifi") ?? NSImage(systemSymbolName: "wifi", accessibilityDescription: nil)!),
                triggers: ["wifi"],
                arguments: ["SSID"],
                handler: { _ in self.toggleWifi() },
                searcher: { query, completion in
                    self.listAndSearchNetworks(query: query, completion: completion)
                }
            )

        case "bluetooth", "bt":
             return NerwAction(
                id: "nerw.system.bluetooth",
                title: "Bluetooth",
                subtitle: "Toggle Bluetooth or Connect Device",
                icon: .image(NSImage(named: "bluetooth") ?? NSImage(systemSymbolName: "iphone.gen3.radiowaves.left.and.right", accessibilityDescription: nil)!),
                triggers: ["bluetooth", "bt"],
                arguments: ["Device Name"],
                handler: { _ in self.toggleBluetooth() },
                searcher: { query, completion in
                    self.listAndSearchBluetoothDevices(query: query, completion: completion)
                }
            )

        /*
        case "menu search":
            return BuiltinResult(
                title: "Menu Bar Search",
                subtitle: "Search menu items of the active application",
                icon: NSImage(systemSymbolName: "menubar.rectangle", accessibilityDescription: nil),
                supportsArguments: true,
                handler: { _ in },
                searcher: { query, completion in self.searchMenuItems(query: query, completion: completion) }
            )
        */

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
            let keys: [URLResourceKey] = [.volumeIsEjectableKey, .volumeIsRemovableKey, .volumeIsInternalKey]
            guard let urls = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: keys, options: [.skipHiddenVolumes]) else { return }

            for url in urls {
                 guard let resourceValues = try? url.resourceValues(forKeys: Set(keys)),
                       let isEjectable = resourceValues.volumeIsEjectable,
                       isEjectable else { continue }

                 do {
                     try NSWorkspace.shared.unmountAndEjectDevice(at: url)
                 } catch {
                     print("[System] Failed to eject \(url.lastPathComponent): \(error)")
                 }
            }
        }
    }

    // MARK: - Process Management

    private func searchProcesses(query: String, completion: @escaping ([NerwAction]) -> Void) {
        // Run on background thread
        DispatchQueue.global(qos: .userInitiated).async {
            // Use 'ps -x -o pid,command' to list all processes owned by the user
            // -x: processes owned by user
            // -o pid,command: output format
            let task = Process()
            task.launchPath = "/bin/ps"
            task.arguments = ["-x", "-o", "pid,command"]

            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = Pipe() // Ignore error

            do {
                try task.run()
                task.waitUntilExit()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                guard let output = String(data: data, encoding: .utf8) else {
                    DispatchQueue.main.async { completion([]) }
                    return
                }

                let lowerQuery = query.lowercased()
                let currentPid = ProcessInfo.processInfo.processIdentifier

                // Critical processes to protect (Guard Rails)
                let protectedProcesses = ["loginwindow", "launchd", "UserEventAgent", "distnoted", "cfprefsd", "Nerw"]

                var results: [NerwAction] = []

                // Parse lines. output header is "  PID COMMAND"
                let lines = output.components(separatedBy: .newlines).dropFirst() // Skip header

                for line in lines {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { continue }

                    // Split PID and Command. PID is first non-space token.
                    let components = trimmed.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
                    guard components.count == 2,
                          let pid = Int(components[0]),
                          pid != currentPid // Don't allow killing self
                    else { continue }

                    let commandPath = String(components[1])
                    let commandName = commandPath.components(separatedBy: "/").last ?? commandPath

                    // Guard Rails Filter
                    if protectedProcesses.contains(commandName) { continue }

                    // Filter match
                    if !query.isEmpty && !commandName.lowercased().contains(lowerQuery) {
                        continue
                    }

                    // Icon
                    var icon: NSImage? = nil
                    if commandPath.hasSuffix(".app") || commandPath.contains(".app/") {
                        // Attempt to find app bundle path for icon
                        // Crude approximation: path up to .app
                        if let range = commandPath.range(of: ".app") {
                             let bundlePath = String(commandPath[..<range.upperBound])
                             icon = NSWorkspace.shared.icon(forFile: bundlePath)
                        }
                    }
                    if icon == nil {
                         icon = NSWorkspace.shared.icon(for: UTType.application)
                    }

                    results.append(NerwAction(
                        id: "nerw.system.process.\(pid)",
                        title: commandName,
                        subtitle: "PID: \(pid) • \(commandPath)",
                        icon: icon != nil ? .image(icon!) : .image(NSWorkspace.shared.icon(for: UTType.application)),
                        triggers: [commandName],
                        arguments: nil,
                        handler: { _ in
                            self.quitProcess(pid: pid, name: commandName)
                        }))
                }

                // Limit results if query is empty to avoid overwhelming list (though typically query isn't empty)
                // If query is empty, maybe show top 50?
                if query.isEmpty {
                    results = Array(results.prefix(50))
                }

                DispatchQueue.main.async {
                    completion(results)
                }

            } catch {
                print("[System] ps command error: \(error)")
                DispatchQueue.main.async { completion([]) }
            }
        }
    }

    private func quitProcess(name: String) {
        // Fallback for name-based kill (less precise)
        // killall? No, too dangerous.
        // Just inform use to use process list.
    }

    private func quitProcess(pid: Int, name: String) {
        DispatchQueue.global(qos: .userInitiated).async {
             // Try kill -TERM first (Graceful)
             let task = Process()
             task.launchPath = "/bin/kill"
             task.arguments = ["-TERM", "\(pid)"]
             task.standardOutput = FileHandle.nullDevice

             try? task.run()
             task.waitUntilExit()

             if task.terminationStatus != 0 {
                 // If failed, maybe ask user? For now, just Log.
                 // User requested "quit", usually expects it to go away.
                 // Force kill? Maybe too aggressive for default.
                 print("[System] Failed to TERM \(name) (\(pid)).")
             } else {
                 print("[System] Sent TERM to \(name) (\(pid)).")
             }
        }
    }

    // MARK: - Volume Search

    private func searchVolumes(query: String, completion: @escaping ([NerwAction]) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            var results: [NerwAction] = []

            let keys: [URLResourceKey] = [.volumeIsEjectableKey, .volumeNameKey]
            if let urls = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: keys, options: [.skipHiddenVolumes]) {

                let lowerQuery = query.lowercased()

                let ejectableVolumes = urls.compactMap { url -> (String, URL)? in
                    guard let values = try? url.resourceValues(forKeys: Set(keys)),
                          let isEjectable = values.volumeIsEjectable,
                          isEjectable,
                          let name = values.volumeName else { return nil }
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
                        icon: .image(NSWorkspace.shared.icon(forFile: url.path)),
                        triggers: [name],
                        arguments: nil,
                        handler: { _ in
                            self.eject(volumeName: name)
                        }
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
                    arguments: nil,
                    handler: { _ in
                        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                        NSWorkspace.shared.open(url)
                    }
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
            let result = AXUIElementCopyAttributeValue(appElement, kAXMenuBarAttribute as CFString, &menuBarValue)

            guard result == .success, let menuBar = menuBarValue else {
                DispatchQueue.main.async { completion([]) }
                return
            }

            let menuBarElement = menuBar as! AXUIElement
            var foundItems: [MenuItem] = []

            // Crawl
            self.crawlMenu(element: menuBarElement, path: [], query: query.lowercased(), results: &foundItems)

            let results = foundItems.map { item -> NerwAction in
                // Generate a stable ID if possible, or random
                let pathString = item.path.joined(separator: " > ")
                return NerwAction(
                    id: "nerw.system.menusExp.\(targetApp.processIdentifier).\(pathString.hashValue)",
                    title: item.title,
                    subtitle: "\(targetApp.localizedName ?? "App") > \(pathString)",
                    icon: .system("menubar.arrow.down.rectangle"),
                    triggers: [],
                    arguments: nil,
                    handler: { _ in
                        self.performMenuAction(element: item.element, app: targetApp)
                    }
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
    private func crawlMenu(element: AXUIElement, path: [String], query: String, results: inout [MenuItem], depth: Int = 0) {
        if depth > 5 { return } // Depth limiter

        // Get Children
        var childrenValue: AnyObject?
        let res = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenValue)
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
            let subRes = AXUIElementCopyAttributeValue(child, "AXSubmenu" as CFString, &submenuValue)
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
                crawlMenu(element: subMenu, path: newPath, query: query, results: &results, depth: depth + 1)
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
        guard let urls = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: keys, options: []) else { return nil }
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

    // MARK: - WiFi Logic

    private func getWiFiClient() -> CWWiFiClient? {
        return CWWiFiClient.shared()
    }

    private func getWiFiInterface() -> CWInterface? {
        return getWiFiClient()?.interface()
    }

    private func toggleWifi() {
        if let interface = getWiFiInterface() {
            let power = interface.powerOn()
            do {
                try interface.setPower(!power)
            } catch {
                print("[System] WiFi toggle failed: \(error)")
                // Fallback to networksetup if CoreWLAN fails (likely due to permissions/deprecation)
                toggleWifiShell(on: !power)
            }
        } else {
             // Fallback blindly
             // Check status first?
             toggleWifiShell(on: true) // Assume on if interface failure? No, awkward.
        }
    }

    private func toggleWifiShell(on: Bool) {
        let state = on ? "on" : "off"
        // Need to find device name, usually en0 or en1
        // networksetup -listallhardwareports
        // Blindly try en0 and en1
        runShellCommand(command: "networksetup -setairportpower en0 \(state)")
        runShellCommand(command: "networksetup -setairportpower en1 \(state)")
    }

    private func listAndSearchNetworks(query: String, completion: @escaping ([NerwAction]) -> Void) {
        print("[System] listAndSearchNetworks called. Query: '\(query)'")
        DispatchQueue.global(qos: .userInitiated).async {
             guard let interface = self.getWiFiInterface() else {
                 print("[System] No WiFi interface found.")
                 DispatchQueue.main.async { completion([]) }
                 return
             }
             print("[System] WiFi Interface found: \(interface.interfaceName ?? "Unknown")")

             do {
                 let networks = try interface.scanForNetworks(withSSID: nil)
                 let lowerQuery = query.lowercased()

                 // De-duplicate by SSID
                 var seen = Set<String>()
                 let uniqueNetworks = networks.filter { network in
                     guard let ssid = network.ssid, !ssid.isEmpty else { return false }
                     if seen.contains(ssid) { return false }
                     seen.insert(ssid)
                     return true
                 }

                 let filtered = uniqueNetworks.filter { network in
                     return query.isEmpty || (network.ssid?.lowercased().contains(lowerQuery) ?? false)
                 }

                 // Sort by RSSI (Signal Strength)
                 let sorted = filtered.sorted { $0.rssiValue > $1.rssiValue }

                 let results = sorted.map { network in
                     let ssid = network.ssid ?? "Unknown"
                     return NerwAction(
                         id: "nerw.system.wifi.\(ssid)",
                         title: ssid,
                         subtitle: "Signal: \(network.rssiValue) dBm • Security: \(self.securityString(network))",
                         icon: .system("wifi"),
                         triggers: [ssid],
                         arguments: nil,
                         handler: { _ in
                             self.connectToWifi(network: network)
                         }
                     )
                 }

                 DispatchQueue.main.async { 
                     print("[System] Found \(results.count) networks.")
                     completion(results) 
                 }

             } catch {
                 print("[System] WiFi Scan failed: \(error)")
                 DispatchQueue.main.async { completion([]) }
             }
        }
    }

    private func securityString(_ network: CWNetwork) -> String {
        if network.supportsSecurity(.wpa2Personal) { return "WPA2" }
        if network.supportsSecurity(.wpaPersonal) { return "WPA" }
        if network.supportsSecurity(.none) { return "Open" }
        return "Unknown"
    }

    private func connectToWifi(network: CWNetwork) {
        guard let interface = getWiFiInterface() else { return }

        // If password required, we can't easily handle it here without UI prompt.
        // For now, assume saved password or open?
        // Or generic associate.

        // If we want to prompt for password, it's UI heavy.
        // Best effort: connect with empty password (works if saved in keychain?)

        DispatchQueue.global(qos: .userInitiated).async {
             do {
                 try interface.associate(to: network, password: nil)
             } catch {
                 print("[System] Connection failed: \(error)")
             }
        }
    }


    // MARK: - Bluetooth Logic (Blueutil)

    private func getBlueutilPath() -> String? {
        // Check common system paths
        let paths = ["/opt/homebrew/bin/blueutil", "/usr/local/bin/blueutil"]
        for path in paths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        return nil
    }

    private func ensureBlueutilInstalled() -> Bool {
        if getBlueutilPath() != nil {
            return true
        }

        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Bluetooth Utility Missing"
            alert.informativeText = "Nerw requires 'blueutil' to manage Bluetooth.\n\nPlease install it using Homebrew:\nbrew install blueutil"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
        return false
    }

    private func runBlueutil(args: [String]) -> String? {
        guard let path = getBlueutilPath() else { return nil }

        let task = Process()
        task.launchPath = path
        task.arguments = args

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe() // Ignore error spam

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)
        } catch {
            print("[System] blueutil execution failed: \(error)")
            return nil
        }
    }

    private func toggleBluetooth() {
        if !ensureBlueutilInstalled() { return }

        DispatchQueue.global(qos: .userInitiated).async {
             // Check current state details to toggle
             // blueutil -p returns "0" or "1"
             guard let output = self.runBlueutil(args: ["-p"])?.trimmingCharacters(in: .whitespacesAndNewlines) else { return }
             let newState = (output == "1") ? "0" : "1"
             _ = self.runBlueutil(args: ["-p", newState])
        }
    }

    private func listAndSearchBluetoothDevices(query: String, completion: @escaping ([NerwAction]) -> Void) {
        if !ensureBlueutilInstalled() {
            DispatchQueue.main.async { completion([]) }
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            // blueutil --paired --format json
            guard let jsonString = self.runBlueutil(args: ["--paired", "--format", "json"]),
                  let data = jsonString.data(using: .utf8)
            else {
                DispatchQueue.main.async { completion([]) }
                return
            }

            do {
                let devices = try JSONDecoder().decode([BTDevice].self, from: data)
                let lowerQuery = query.lowercased()

                let filtered = devices.filter { device in
                    let name = device.name ?? device.address
                    return query.isEmpty || name.lowercased().contains(lowerQuery)
                }

                let results = filtered.map { device in
                    let name = device.name ?? device.address
                    let status = device.connected ? "Connected" : "Disconnected"

                    return NerwAction(
                        id: "nerw.system.bt.\(device.address)",
                        title: name,
                        subtitle: "\(status) • \(device.address)",
                        icon: .system("iphone.gen3.radiowaves.left.and.right"),
                        triggers: [name],
                        arguments: nil,
                        handler: { _ in
                            self.toggleConnectBluetooth(device: device)
                        }
                    )
                }

                DispatchQueue.main.async { completion(results) }
            } catch {
                print("[System] BT JSON Parse error: \(error)")
                DispatchQueue.main.async { completion([]) }
            }
        }
    }

    private struct BTDevice: Codable {
        let address: String
        let name: String?
        let connected: Bool
    }

    private func toggleConnectBluetooth(device: BTDevice) {
        if !ensureBlueutilInstalled() { return }

        DispatchQueue.global(qos: .userInitiated).async {
             if device.connected {
                 _ = self.runBlueutil(args: ["--disconnect", device.address])
             } else {
                 _ = self.runBlueutil(args: ["--connect", device.address])
             }
        }
    }

    private func runShellCommand(command: String) {
        let task = Process()
        task.launchPath = "/bin/zsh"
        task.arguments = ["-c", command]
        try? task.run()
    }
}
