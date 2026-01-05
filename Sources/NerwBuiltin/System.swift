import Cocoa

public class System {
    public static let shared = System()
    
    private let systemIcon = NSImage(systemSymbolName: "gearshape.2", accessibilityDescription: nil)
    
    private init() {}
    
    // MARK: - Public API
    
    public func check(query: String) -> BuiltinResult? {
        let lowerQuery = query.lowercased()
        
        // Empty Downloads
        if "empty downloads".starts(with: lowerQuery) && lowerQuery.count >= 6 {
            return BuiltinResult(
                title: "Empty Downloads",
                subtitle: "Move all Downloads folder contents to Trash",
                icon: NSImage(systemSymbolName: "arrow.down.circle.dotted", accessibilityDescription: nil),
                supportsArguments: false
            ) { _ in self.emptyDownloads() }
        }
        
        // Sleep
        if "sleep".starts(with: lowerQuery) {
            return BuiltinResult(
                title: "Sleep",
                subtitle: "Put your Mac to sleep",
                icon: NSImage(systemSymbolName: "moon.zzz.fill", accessibilityDescription: nil),
                supportsArguments: false
            ) { _ in self.sleep() }
        }
        
        // Eject All
        if "eject all".starts(with: lowerQuery) && lowerQuery.count >= 6 {
            return BuiltinResult(
                title: "Eject All",
                subtitle: "Eject all external volumes",
                icon: NSImage(systemSymbolName: "eject.fill", accessibilityDescription: nil),
                supportsArguments: false
            ) { _ in self.ejectAll() }
        }
        
        // Eject (with argument)
        if "eject".starts(with: lowerQuery) && !query.contains("all") {
            return BuiltinResult(
                title: "Eject",
                subtitle: "Eject a specific volume",
                icon: NSImage(systemSymbolName: "eject", accessibilityDescription: nil),
                supportsArguments: true,
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
        
        // Quit Process (Guard Railed)
        if "ps".starts(with: lowerQuery) || "process".starts(with: lowerQuery) {
            return BuiltinResult(
                title: "Quit Process",
                subtitle: "Terminate a running application",
                icon: NSImage(systemSymbolName: "xmark.circle", accessibilityDescription: nil),
                supportsArguments: true,
                handler: { appName in
                    self.quitProcess(name: appName)
                },
                searcher: { query, completion in
                    self.searchProcesses(query: query, completion: completion)
                }
            )
        }
        
        return nil
    }
    
    public func findByTrigger(_ trigger: String) -> BuiltinResult? {
        let lowerTrigger = trigger.lowercased()
        
        switch lowerTrigger {
        case "empty downloads":
            return BuiltinResult(
                title: "Empty Downloads",
                subtitle: "Move all Downloads folder contents to Trash",
                icon: NSImage(systemSymbolName: "arrow.down.circle.dotted", accessibilityDescription: nil),
                supportsArguments: false
            ) { _ in self.emptyDownloads() }
            
        case "sleep":
            return BuiltinResult(
                title: "Sleep",
                subtitle: "Put your Mac to sleep",
                icon: NSImage(systemSymbolName: "moon.zzz.fill", accessibilityDescription: nil),
                supportsArguments: false
            ) { _ in self.sleep() }
            
        case "eject all":
            return BuiltinResult(
                title: "Eject All",
                subtitle: "Eject all external volumes",
                icon: NSImage(systemSymbolName: "eject.fill", accessibilityDescription: nil),
                supportsArguments: false
            ) { _ in self.ejectAll() }
            
        case "eject":
            return BuiltinResult(
                title: "Eject",
                subtitle: "Eject a specific volume",
                icon: NSImage(systemSymbolName: "eject", accessibilityDescription: nil),
                supportsArguments: true,
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
            return BuiltinResult(
                title: "Quit Process",
                subtitle: "Terminate a running application",
                icon: NSImage(systemSymbolName: "xmark.circle", accessibilityDescription: nil),
                supportsArguments: true,
                handler: { appName in self.quitProcess(name: appName) },
                searcher: { query, completion in self.searchProcesses(query: query, completion: completion) }
            )
            
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
    
    private func searchProcesses(query: String, completion: @escaping ([BuiltinResult]) -> Void) {
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
                
                var results: [BuiltinResult] = []
                
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
                         icon = NSWorkspace.shared.icon(forFileType: NSFileTypeForHFSTypeCode(OSType(kGenericApplicationIcon)))
                    }
                    
                    results.append(BuiltinResult(
                        title: commandName,
                        subtitle: "PID: \(pid) • \(commandPath)",
                        icon: icon,
                        supportsArguments: false
                    ) { _ in
                        self.quitProcess(pid: pid, name: commandName)
                    })
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
    
    private func searchVolumes(query: String, completion: @escaping ([BuiltinResult]) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            var results: [BuiltinResult] = []
            
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
                    return BuiltinResult(
                        title: name,
                        subtitle: url.path,
                        icon: NSWorkspace.shared.icon(forFile: url.path),
                        supportsArguments: false
                    ) { _ in
                        self.eject(volumeName: name)
                    }
                }
            }
            
            DispatchQueue.main.async {
                completion(results)
            }
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
}
