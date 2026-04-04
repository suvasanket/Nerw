import Cocoa
import CoreServices
import NerwCore

public class AppSearch {
    public static let shared = AppSearch()
    private let fileManager = FileManager.default

    public struct AppInfo {
        public let name: String
        public let path: String

        public init(name: String, path: String) {
            self.name = name
            self.path = path
        }
    }

    private var cachedApps: [AppInfo] = []
    // Allow refreshing to be async but cache access sync
    private let cacheQueue = DispatchQueue(
        label: "com.nerw.appsearch.cache", attributes: .concurrent)
    private let metadataUpdateQueue = DispatchQueue(label: "com.nerw.appsearch.metadata")
    private var pendingRefreshWorkItem: DispatchWorkItem?

    private var metadataQuery: NSMetadataQuery!

    private init() {
        if Thread.isMainThread {
            startLiveQuery()
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.startLiveQuery()
            }
        }
    }

    public func getAllApps() -> [AppInfo] {
        return cacheQueue.sync { cachedApps }
    }

    public var monitoredSearchScopePaths: [String] {
        searchScopeURLs.map(\.path)
    }

    // Manual refresh is no longer needed with live query, but kept for compatibility
    public func refreshCache() {
        // No-op or force re-query if needed, but live query handles it.
        // We can just log or trigger a stop/start if we really wanted to restart it.
    }

    private func startLiveQuery() {
        print("[AppSearch] Starting NSMetadataQuery...")
        metadataQuery = NSMetadataQuery()

        // Search for Applications
        metadataQuery.predicate = NSPredicate(
            format: "kMDItemContentType == 'com.apple.application-bundle'")

        // Explicitly set scopes to user-facing application directories only.
        // Explicitly set scopes.
        // Include /System/Library/CoreServices for Finder, Archive Utility, Screen Sharing, etc.
        metadataQuery.searchScopes = searchScopeURLs

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(queryDidUpdate(_:)),
            name: .NSMetadataQueryDidFinishGathering,
            object: metadataQuery)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(queryDidUpdate(_:)),
            name: .NSMetadataQueryDidUpdate,
            object: metadataQuery)

        if metadataQuery.start() {
            print("[AppSearch] NSMetadataQuery started successfully")
        } else {
            print("[AppSearch] NSMetadataQuery failed to start")
        }
    }

    @objc private func queryDidUpdate(_ notification: Notification) {
        metadataQuery.disableUpdates()
        let results = (0..<metadataQuery.resultCount).compactMap {
            metadataQuery.result(at: $0) as? NSMetadataItem
        }
        metadataQuery.enableUpdates()

        pendingRefreshWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            let newApps = self.buildAppList(from: results)

            self.cacheQueue.async(flags: .barrier) {
                self.cachedApps = newApps
            }
        }
        pendingRefreshWorkItem = workItem
        metadataUpdateQueue.async(execute: workItem)
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

    private var searchScopeURLs: [URL] {
        let homeApplications = fileManager.homeDirectoryForCurrentUser.appendingPathComponent(
            "Applications")

        return [
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: "/System/Applications"),
            homeApplications,
            URL(fileURLWithPath: "/System/Library/CoreServices"),
        ]
    }

    private func buildAppList(from items: [NSMetadataItem]) -> [AppInfo] {
        var newApps: [AppInfo] = []
        var seenPaths = Set<String>()

        for item in items {
            guard let path = item.value(forAttribute: kMDItemPath as String) as? String else {
                continue
            }

            if !shouldIncludeApp(at: path) || !seenPaths.insert(path).inserted {
                continue
            }

            let name = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
            newApps.append(AppInfo(name: name, path: path))
        }

        return newApps.sorted {
            if $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedSame {
                return $0.path.localizedCaseInsensitiveCompare($1.path) == .orderedAscending
            }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private func shouldIncludeApp(at path: String) -> Bool {
        if path.range(of: ".app/", options: .caseInsensitive) != nil {
            return false
        }

        if path.contains("/System/Library/") {
            if path.contains("/CoreServices/") {
                let isCoreServicesApp = path.contains("/CoreServices/Applications/")
                let isFinder = path.hasSuffix("/CoreServices/Finder.app")
                if !(isCoreServicesApp || isFinder) {
                    return false
                }
            } else {
                return false
            }
        } else if path.contains("/Library/"), !path.contains("/Applications/") {
            return false
        }

        if path.contains("/.") || path.starts(with: "/private") {
            return false
        }

        return true
    }
}
