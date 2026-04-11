import Cocoa
import CoreServices  // For MDQuery
import NerwAction
import NerwCore

public class FindFile {
    public static let shared = FindFile()

    // Core Search State
    private var currentQuery: MDQuery?
    private var currentTokens: [String] = []

    // Limits results to keep UI responsive
    private let maxResults = 50

    // Completion handler storage for live updates
    private var currentCompletion: (([NerwAction]) -> Void)?

    // MARK: - Exclusion Logic

    // Layer 1: Native Spotlight Exclusion (Performance)
    // Prevents system from sending us thousands of useless results.
    private let exclusionPredicate = """
        && kMDItemPath != '*node_modules*'
        && kMDItemPath != '*.git*'
        && kMDItemPath != '*.cache*'
        && kMDItemPath != '*.vscode*'
        && kMDItemPath != '*.idea*'
        && kMDItemPath != '*Library/Caches*'
        && kMDItemPath != '*DerivedData*'
        && kMDItemPath != '*__pycache__*'
        && kMDItemPath != '*/target/*'
        && kMDItemPath != '*/build/*'
        && kMDItemPath != '*/dist/*'
        && kMDItemPath != '*/venv/*'
        && kMDItemPath != '*/.venv/*'
        && kMDItemPath != '*/obj/*'
        && kMDItemPath != '*/.gradle/*'
        """

    // Layer 2: Swift-side Safety Net (Accuracy)
    // Checks path components strictly.
    private let ignorePatterns: Set<String> = [
        "node_modules", ".git", ".cache", ".DS_Store", ".vscode", ".idea",
        "build", "dist", "target", "DerivedData", "__pycache__", "venv", ".venv",
        ".env", "bin", "obj", ".next", "out", ".svelte-kit", ".gradle", ".m2",
        ".pytest_cache", ".mypy_cache", "vendor", "Library",
    ]

    private init() {}

    // MARK: - Entry Points

    // MARK: - Entry Points

    public func getTriggerAction() -> NerwAction {
        return createBaseResult()
    }

    private func createBaseResult() -> NerwAction {
        let finderIcon = NSWorkspace.shared.icon(forFile: "/System/Library/CoreServices/Finder.app")
        return NerwAction(
            id: "nerw.builtin.findfile",
            title: "Find File",
            subtitle: "Search and Reveal in Finder",
            icon: .image(finderIcon),
            triggers: ["find", "file"],
            type: .args(
                placeholder: "Filename",
                searcher: { _, argument, completion in
                    self.search(query: argument, completion: completion)
                },
                perform: nil
            )
        )
    }

    // MARK: - Live Search Engine
    public func search(query: String, completion: @escaping ([NerwAction]) -> Void) {
        // 1. Cleanup previous query
        stopCurrentQuery()

        // 2. Setup new state
        self.currentCompletion = completion

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            completion([])
            return
        }

        // 3. Tokenize & Construct Query
        let spaceTokens = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        self.currentTokens = spaceTokens

        var namePredicates: [String] = []
        for token in spaceTokens {
            // Split by slash to handle paths in input (e.g. "Sources/Nerw")
            let parts = token.components(separatedBy: "/").filter { !$0.isEmpty }
            for part in parts {
                let safe = part.replacingOccurrences(of: "'", with: "")
                namePredicates.append("kMDItemDisplayName == '*\(safe)*'wc")
            }
        }

        let combinedNames = namePredicates.joined(separator: " || ")
        let queryString = "(\(combinedNames)) \(exclusionPredicate)" as CFString

        // 4. Create MDQuery
        guard let mdQuery = MDQueryCreate(kCFAllocatorDefault, queryString, nil, nil) else {
            print("[FindFile] Failed to create MDQuery: \(queryString)")
            completion([])
            return
        }
        self.currentQuery = mdQuery

        // 5. Set Scope (User Home)
        if let home = FileManager.default.urls(for: .userDirectory, in: .allDomainsMask).first {
            MDQuerySetSearchScope(mdQuery, [home as CFURL] as CFArray, 0)
        }

        // 6. Add Observers
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onQueryUpdate(_:)),
            name: NSNotification.Name(kMDQueryProgressNotification as String),
            object: mdQuery
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onQueryUpdate(_:)),  // Use same handler for finish
            name: NSNotification.Name(kMDQueryDidFinishNotification as String),
            object: mdQuery
        )

        // 7. Execute
        if !MDQueryExecute(mdQuery, CFOptionFlags(kMDQueryWantsUpdates.rawValue)) {
            print("[FindFile] MDQueryExecute failed")
            completion([])
        }
    }

    private func stopCurrentQuery() {
        if let q = currentQuery {
            MDQueryStop(q)
            MDQueryDisableUpdates(q)
            NotificationCenter.default.removeObserver(
                self, name: NSNotification.Name(kMDQueryProgressNotification as String), object: q)
            NotificationCenter.default.removeObserver(
                self, name: NSNotification.Name(kMDQueryDidFinishNotification as String), object: q)
            currentQuery = nil
        }
    }

    @objc private func onQueryUpdate(_ notification: Notification) {
        processResults()
    }

    private func processResults() {
        guard let query = currentQuery, let completion = currentCompletion else { return }

        let count = MDQueryGetResultCount(query)
        // Scan limit: check more items than we display because we filter some out
        let scanLimit = min(count, 5000)
        var results: [NerwAction] = []

        for i in 0..<scanLimit {
            if results.count >= maxResults { break }

            guard let rawPtr = MDQueryGetResultAtIndex(query, i) else { continue }
            let item = Unmanaged<MDItem>.fromOpaque(rawPtr).takeUnretainedValue()

            if let path = MDItemCopyAttribute(item, kMDItemPath) as? String {
                // Layer 2 Filter
                if isExcluded(path) { continue }
                if !matchesAllTokens(path) { continue }

                let url = URL(fileURLWithPath: path)
                let name = url.lastPathComponent

                let result = NerwAction(
                    id: "nerw.findfile.result.\(path.hashValue)",  // Use hash or path for unique ID
                    title: name,
                    subtitle: path.replacingOccurrences(of: NSHomeDirectory(), with: "~"),
                    icon: .file(url),  // Use async file icon
                    type: .instant(perform: { _ in
                        if NSApp.currentEvent?.modifierFlags.contains(.command) == true {
                            NSWorkspace.shared.activateFileViewerSelecting([url])
                        } else {
                            NSWorkspace.shared.open(url)
                        }
                    })
                )
                results.append(result)
            }
        }

        // Dispatch completion on main thread
        DispatchQueue.main.async {
            completion(results)
        }
    }

    // MARK: - Swift Filters

    private func isExcluded(_ path: String) -> Bool {
        let components = path.lowercased().components(separatedBy: "/")
        for component in components {
            if ignorePatterns.contains(component) {
                return true
            }
        }
        return false
    }

    private func matchesAllTokens(_ path: String) -> Bool {
        if currentTokens.isEmpty { return true }
        let lowerPath = path.localizedLowercase
        for token in currentTokens {
            if !lowerPath.contains(token.localizedLowercase) {
                return false
            }
        }
        return true
    }
}
