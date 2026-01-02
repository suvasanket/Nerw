import Cocoa
import NerwCore

public class AppSearch {
    public static let shared = AppSearch()
    
    public struct AppInfo {
        public let name: String
        public let path: String
        // Icon is NOT stored here to avoid loading overhead individually.
        // UI loads it using NSWorkspace.icon(forFile: path)
    }
    
    private var cachedApps: [AppInfo] = []
    // Allow refreshing to be async but cache access sync
    private let cacheQueue = DispatchQueue(label: "com.nerw.appsearch.cache", attributes: .concurrent)

    private init() {
        refreshCache()
    }
    
    public func getAllApps() -> [AppInfo] {
        return cacheQueue.sync { cachedApps }
    }
    
    public func refreshCache() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let apps = self?.performSearch() ?? []
            self?.cacheQueue.async(flags: .barrier) {
                self?.cachedApps = apps
            }
        }
    }
    
    private func performSearch() -> [AppInfo] {
        // Strategy 1: Spotlight Index (mdfind) - FASTEST & NATIVE
        // We use `mdfind` CLI for simplicity as it's cleaner than MDQuery in Swift without runloop handling sometimes.
        // Actually, let's try `mdfind` first.
        if let spotlightResults = runMdfind() {
            print("AppSearch: Using Spotlight Index (\(spotlightResults.count) apps)")
            return spotlightResults
        }
        
        // Strategy 2: fd (if installed)
        if let fdResults = runFd() {
            print("AppSearch: Using fd (\(fdResults.count) apps)")
            return fdResults
        }
        
        // Strategy 3: find (Fallback)
        print("AppSearch: Using find (Fallback)")
        return runFind()
    }
    
    // MARK: - Strategies
    
    private func runMdfind() -> [AppInfo]? {
        // kMDItemContentType == 'com.apple.application-bundle'
        // We scope to typical application directories to avoid random build artifacts or deep system internals
        let scope = "-onlyin /Applications -onlyin /System/Applications -onlyin /Users"
        let command = "mdfind \(scope) \"kMDItemContentType == 'com.apple.application-bundle'\""
        guard let output = runShell(command) else { return nil }
        
        // Output is newline separated paths
        let paths = output.components(separatedBy: .newlines).filter { !$0.isEmpty }
        if paths.isEmpty { return nil }
        
        return paths.compactMap { path in
            // Filter out helper apps (apps inside other apps)
            // If the path contains ".app/" somewhere in the middle, it's likely a helper.
            // e.g. /Applications/Xcode.app/Contents/Developer/.../Something.app
            if path.range(of: ".app/", options: .caseInsensitive) != nil {
                return nil
            }
            
            let name = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
            return AppInfo(name: name, path: path)
        }
    }
    
    private func runFd() -> [AppInfo]? {
        // Check if fd exists
        guard runShell("which fd") != nil else { return nil }
        
        // Search in standard app paths
        let command = "fd -e app . /Applications /System/Applications --max-depth 2"
        guard let output = runShell(command) else { return nil }
        
        let paths = output.components(separatedBy: .newlines).filter { !$0.isEmpty }
        return paths.map { path in
            let name = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
            return AppInfo(name: name, path: path)
        }
    }
    
    private func runFind() -> [AppInfo] {
        let command = "find /Applications /System/Applications -maxdepth 2 -name \"*.app\""
        guard let output = runShell(command) else { return [] }
        
        let paths = output.components(separatedBy: .newlines).filter { !$0.isEmpty }
        return paths.map { path in
            let name = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
            return AppInfo(name: name, path: path)
        }
    }
    
    private func runShell(_ command: String) -> String? {
        let task = Process()
        let pipe = Pipe()
        
        task.standardOutput = pipe
        task.arguments = ["-c", command]
        task.launchPath = "/bin/zsh"
        task.standardError = Pipe() // Silence errors
        
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }
}
