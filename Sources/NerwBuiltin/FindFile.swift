import Cocoa
import NerwSearchBackend // For Fuse

public class FindFile {
    public static let shared = FindFile()

    private enum SearchStrategy {
        case fd
        case mdfind
    }

    private var strategy: SearchStrategy = .mdfind // Default to mdfind until checked
    private var hasCheckedStrategy = false

    // Smart Cache State
    private var cachedPaths: [String] = []
    private var lastQuery: String = ""
    private let MAX_CACHE_SIZE = 3000

    // Ignore Patterns
    private let ignorePatterns = [
        "node_modules",
        ".git",
        ".cache",
        ".DS_Store",
        ".vscode",
        ".idea",
        "build",
        "dist",
        "target", // Rust/Maven
        "DerivedData", // Xcode
        "__pycache__",
        "venv",
        ".env"
    ]

    private init() {
        checkTools()
    }

    private func checkTools() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let process = Process()
            process.launchPath = "/bin/zsh"
            process.arguments = ["-c", "which fd"]

            // Silence
            process.standardOutput = Pipe()
            process.standardError = Pipe()

            try? process.run()
            process.waitUntilExit()

            if process.terminationStatus == 0 {
                self?.strategy = .fd
                print("[FindFile] 'fd' detected.")
            } else {
                self?.strategy = .mdfind
                print("[FindFile] 'fd' not found. Fallback to mdfind.")
            }
            self?.hasCheckedStrategy = true
        }
    }

    // Debounce timer
    private var searchWorkItem: DispatchWorkItem?

    public func check(query: String) -> BuiltinResult? {
        let triggers = ["find", "file"]
        let lowerQuery = query.lowercased()

        guard triggers.contains(where: { $0.starts(with: lowerQuery) }) else {
            return nil
        }

        let finderIcon = NSWorkspace.shared.icon(forFile: "/System/Library/CoreServices/Finder.app")

        return BuiltinResult(
            title: "Find File",
            subtitle: "Search and Reveal in Finder",
            icon: finderIcon,
            supportsArguments: true,
            handler: { _ in
                 NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: NSHomeDirectory())
            },
            searcher: { argument, completion in
                self.liveSearch(query: argument, completion: completion)
            }
        )
    }

    public func findByTrigger(_ trigger: String) -> BuiltinResult? {
        let triggers = ["find", "file"]
        let lowerTrigger = trigger.lowercased()

        guard triggers.contains(lowerTrigger) else { return nil }

        let finderIcon = NSWorkspace.shared.icon(forFile: "/System/Library/CoreServices/Finder.app")

        return BuiltinResult(
            title: "Find File",
            subtitle: "Search and Reveal in Finder",
            icon: finderIcon,
            supportsArguments: true,
            handler: { _ in
                 NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: NSHomeDirectory())
            },
            searcher: { argument, completion in
                self.liveSearch(query: argument, completion: completion)
            }
        )
    }

    private func liveSearch(query: String, completion: @escaping ([BuiltinResult]) -> Void) {
        searchWorkItem?.cancel()

        guard !query.isEmpty else {
            completion([])
            return
        }

        // 1. Check Smart Cache (Main Thread Check for Safety/Speed)
        // If query refined previous query AND we captured everything last time (<MAX)
        if !cachedPaths.isEmpty && !lastQuery.isEmpty && query.lowercased().hasPrefix(lastQuery.lowercased()) && cachedPaths.count < MAX_CACHE_SIZE {
            // Refine in-memory
            // We run this on background to avoid blocking UI if cache is large (3000 items)
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else { return }
                self.refineResults(query: query, paths: self.cachedPaths, completion: completion)
            }
            return
        }

        // 2. Fallback: Full Process Fetch
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.performFetchAndSearch(query: query, completion: completion)
        }

        searchWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: workItem)
    }

    private func performFetchAndSearch(query: String, completion: @escaping ([BuiltinResult]) -> Void) {
        let strategy = self.strategy
        var script = ""

        // Fetch up to MAX_CACHE_SIZE for potential refinement later
        if strategy == .fd {
            let excludes = ignorePatterns.map { "--exclude '\($0)'" }.joined(separator: " ")
            let home = NSHomeDirectory()
            script = "fd -i --max-results \(MAX_CACHE_SIZE) \(excludes) '\(query)' '\(home)'"
        } else {
            let home = NSHomeDirectory()
            let grepExcludes = ignorePatterns.map { "| grep -v '\($0)'" }.joined(separator: " ")
            script = "mdfind -onlyin '\(home)' -name '\(query)' \(grepExcludes) | head -n \(MAX_CACHE_SIZE)"
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let task = Process()
            task.launchPath = "/bin/zsh"
            task.arguments = ["-c", script]

            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = pipe // Capture error too just in case

            try? task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else {
                DispatchQueue.main.async { completion([]) }
                return
            }

            let paths = output.components(separatedBy: .newlines).filter { !$0.isEmpty }

            // UPDATE CACHE
            // Only cache if we didn't hit the limit (meaning specific enough) OR if it's a good base
            // Actually, plan says: Cache always, but only use for refinement if count < MAX
            DispatchQueue.main.async { // Write to state on Main Thread for safety
                self.cachedPaths = paths
                self.lastQuery = query.lowercased()
            }

            // Now Fuse Search/Rank the results we just fetched
            self.refineResults(query: query, paths: paths, completion: completion)
        }
    }

    private func refineResults(query: String, paths: [String], completion: @escaping ([BuiltinResult]) -> Void) {
        // Use Fuse to rank/filter
        let fuse = Fuse()
        // Fuse search expects [Fuseable], String is Fuseable
        // Search
        let searchResults = fuse.searchSync(query, in: paths)

        let topResults = searchResults.prefix(20) // Take top 20

        let builtins = topResults.compactMap { result -> BuiltinResult? in
            let path = paths[result.index]
            let url = URL(fileURLWithPath: path)
            let name = url.lastPathComponent

            // Sanity Filter for mdfind if needed (double check)
           if self.strategy == .mdfind {
               let components = path.components(separatedBy: "/")
               if components.contains(where: { self.ignorePatterns.contains($0) }) {
                   return nil
               }
           }

            return BuiltinResult(
                title: name,
                subtitle: path.replacingOccurrences(of: NSHomeDirectory(), with: "~"),
                icon: NSWorkspace.shared.icon(forFile: path),
                supportsArguments: false,
                handler: { _ in
                    if NSApp.currentEvent?.modifierFlags.contains(.command) == true {
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    } else {
                        NSWorkspace.shared.open(url)
                    }
                }
            )
        }

        DispatchQueue.main.async {
            completion(builtins)
        }
    }
}

// MARK: - End of FindFile
