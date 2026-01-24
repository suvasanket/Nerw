import Cocoa
import CoreServices
import NerwCore

public class AppSearch {
    public static let shared = AppSearch()

    public struct AppInfo {
        public let name: String
        public let path: String
    }

    private var cachedApps: [AppInfo] = []
    // Allow refreshing to be async but cache access sync
    private let cacheQueue = DispatchQueue(
        label: "com.nerw.appsearch.cache", attributes: .concurrent)

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
        var results: [AppInfo] = []

        // Strategy 1: Snapshot MDQuery (Native API) - FASTEST & NATIVE
        if let spotlightResults = runMDQuerySearch() {
            results = spotlightResults
        }
        // Strategy 2: fd (if installed)
        else if let fdResults = runFd() {
            results = fdResults
        }
        // Strategy 3: find (Fallback)
        else {
            results = runFind()
        }

        // Explicitly ensure Finder is present (System Essential)
        // Finder often lives in /System/Library/CoreServices, which might be out of scope for standard app queries
        if !results.contains(where: { $0.name == "Finder" }) {
            let finderPath = "/System/Library/CoreServices/Finder.app"
            if FileManager.default.fileExists(atPath: finderPath) {
                results.append(AppInfo(name: "Finder", path: finderPath))
            }
        }

        return results
    }

    // MARK: - Strategies

    private func runMDQuerySearch() -> [AppInfo]? {
        let queryString = "kMDItemContentType == 'com.apple.application-bundle'" as CFString

        // Create Query
        // Scopes: Applications, System Apps, User Apps
        // Note: MDQuery automatically respects permissions and user scope usually.
        // We can optionally set explicit scope if needed, but default is usually good.
        guard let mdQuery = MDQueryCreate(kCFAllocatorDefault, queryString, nil, nil) else {
            print("[AppSearch] Failed to create MDQuery")
            return nil
        }

        // Set explicit scope to match previous logic (broad app locations)
        let searchScopes: [CFURL] =
            [
                URL(fileURLWithPath: "/Applications"),
                URL(fileURLWithPath: "/System/Applications"),
                URL(fileURLWithPath: "/Users"),
            ] as [CFURL]
        MDQuerySetSearchScope(mdQuery, searchScopes as CFArray, 0)

        // Execute Synchronously ensures we get results immediately for this "snapshot"
        if !MDQueryExecute(mdQuery, CFOptionFlags(kMDQuerySynchronous.rawValue)) {
            print("[AppSearch] MDQueryExecute failed")
            return nil
        }

        let count = MDQueryGetResultCount(mdQuery)
        var results: [AppInfo] = []

        for i in 0..<count {
            guard let rawPtr = MDQueryGetResultAtIndex(mdQuery, i) else { continue }
            let item = Unmanaged<MDItem>.fromOpaque(rawPtr).takeUnretainedValue()

            if let path = MDItemCopyAttribute(item, kMDItemPath) as? String {
                // Filter out helper apps (apps inside other apps)
                if path.range(of: ".app/", options: .caseInsensitive) != nil {
                    continue
                }

                let name = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
                results.append(AppInfo(name: name, path: path))
            }
        }

        // MDQuery doesn't need explicit "Release" in Swift ARC usually,
        // but MDQueryStop is good practice if it were async.
        // Generational Analysis: ARC handles MDQueryRef? Yes, usually treated as CFType.

        return results.isEmpty ? nil : results
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
        task.standardError = Pipe()  // Silence errors

        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)?.trimmingCharacters(
                in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }
}
