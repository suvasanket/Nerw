import Cocoa

public class FindFile {
    public static let shared = FindFile()

    private init() {}

    // Debounce timer
    private var searchWorkItem: DispatchWorkItem?

    public func check(query: String) -> BuiltinResult? {
        let triggers = ["find", "file"]
        let lowerQuery = query.lowercased()

        // Check if triggers start with query (e.g. "f", "fi", "find")
        guard triggers.contains(where: { $0.starts(with: lowerQuery) }) else {
            return nil
        }

        let finderIcon = NSWorkspace.shared.icon(forFile: "/System/Library/CoreServices/Finder.app")

        return BuiltinResult(
            title: "Find File",
            subtitle: "Search and Reveal in Finder",
            icon: finderIcon,
            supportsArguments: true,
            handler: { argument in
                 self.findAndReveal(query: argument)
            },
            searcher: { argument, completion in
                self.liveSearch(query: argument, completion: completion)
            }
        )
    }

    // Existing fallback handler for "Enter" without selection
    private func findAndReveal(query: String) {
        // If user just types and hits enter without selecting, we can do the top 1 approach.
        let script = "mdfind -name '\(query)' | head -n 1"
        runSearch(script: script)
    }

    private func liveSearch(query: String, completion: @escaping ([BuiltinResult]) -> Void) {
        // Cancel previous pending search
        searchWorkItem?.cancel()

        guard !query.isEmpty else {
            completion([])
            return
        }

        // Create new work item (Debounce 0.2s)
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.performSearch(query: query, completion: completion)
        }

        searchWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: workItem)
    }

    private func performSearch(query: String, completion: @escaping ([BuiltinResult]) -> Void) {
        // Search for top 10 files
        let script = "mdfind -name '\(query)' | head -n 10"

        DispatchQueue.global(qos: .userInitiated).async {
            let task = Process()
            task.launchPath = "/bin/bash"
            task.arguments = ["-c", script]

            let pipe = Pipe()

            task.standardOutput = pipe
            task.standardError = FileHandle.nullDevice

            do {
                try task.run()
            } catch {
                DispatchQueue.main.async { completion([]) }
                return
            }

            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else {
                DispatchQueue.main.async { completion([]) }
                return
            }

            let paths = output.components(separatedBy: .newlines).filter { !$0.isEmpty }

            let results = paths.map { path -> BuiltinResult in
                let url = URL(fileURLWithPath: path)
                let icon = NSWorkspace.shared.icon(forFile: path)
                let name = url.lastPathComponent

                // We must use main thread for icon if possible, but NSWorkspace.icon is thread-safe.
                // However, constructing BuiltinResult is fine on bg thread.

                return BuiltinResult(
                    title: name,
                    subtitle: path,
                    icon: icon,
                    supportsArguments: false,
                    handler: { _ in
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    }
                )
            }

            DispatchQueue.main.async {
                completion(results)
            }
        }
    }

    // Helper
    private func runSearch(script: String) {
         let task = Process()
         task.launchPath = "/bin/bash"
         task.arguments = ["-c", script]
         let pipe = Pipe()
         task.standardOutput = pipe
         task.standardError = FileHandle.nullDevice
         try? task.run()

         let data = pipe.fileHandleForReading.readDataToEndOfFile()
         if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !output.isEmpty {
             let url = URL(fileURLWithPath: output)
             NSWorkspace.shared.activateFileViewerSelecting([url])
         }
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
            handler: { argument in
                 self.findAndReveal(query: argument)
            },
            searcher: { argument, completion in
                self.liveSearch(query: argument, completion: completion)
            }
        )
    }
}
