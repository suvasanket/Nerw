import Cocoa
import CoreServices
import NerwCore

public class AppSearch {
    public static let shared = AppSearch()

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
        let searchScopes = [
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: "/System/Applications"),
            URL(fileURLWithPath: "/Users"),
            URL(fileURLWithPath: "/System/Library/CoreServices"),
        ]
        metadataQuery.searchScopes = searchScopes

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

        var newApps: [AppInfo] = []
        let count = metadataQuery.resultCount

        for i in 0..<count {
            guard let item = metadataQuery.result(at: i) as? NSMetadataItem,
                let path = item.value(forAttribute: kMDItemPath as String) as? String
            else {
                continue
            }

            // Filter out helper apps (apps inside other apps)
            if path.range(of: ".app/", options: .caseInsensitive) != nil {
                continue
            }

            // Refined Logic for System Libraries
            if path.contains("/System/Library/") {
                // Check for CoreServices
                if path.contains("/CoreServices/") {
                    // Allow:
                    // 1. Apps in /System/Library/CoreServices/Applications/ (e.g. Keychain Access, Archive Utility)
                    // 2. Finder.app (Root of CoreServices)
                    let isCoreServicesApp = path.contains("/CoreServices/Applications/")
                    let isFinder = path.hasSuffix("/CoreServices/Finder.app")

                    if isCoreServicesApp || isFinder {
                        // Keep it
                    } else {
                        // Block everything else in CoreServices (Dock, Siri, ControlCenter, etc.)
                        continue
                    }
                } else {
                    // Block all other System Libraries (Input Methods, Frameworks, etc.)
                    continue
                }
            } else if path.contains("/Library/") {
                // Block other general Library paths if any sneak in
                continue
            }

            // Exclude hidden folders/System internals
            if path.contains("/.") || path.starts(with: "/private") {
                continue
            }

            let name = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
            newApps.append(AppInfo(name: name, path: path))
        }

        // Removed manual Finder check as it should be found via CoreServices scope now.

        cacheQueue.async(flags: .barrier) {
            self.cachedApps = newApps
        }

        metadataQuery.enableUpdates()
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
