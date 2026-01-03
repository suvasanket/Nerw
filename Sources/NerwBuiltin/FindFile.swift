import Cocoa

public class FindFile {
    public static let shared = FindFile()

    private init() {}

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
            searcher: { argument in
                return self.liveSearch(query: argument)
            }
        )
    }

    // Existing fallback handler for "Enter" without selection
    private func findAndReveal(query: String) {
        // ... (Keep existing logic if needed, or rely on live search results)
        // If user just types and hits enter without selecting, we can do the top 1 approach.
        let script = "mdfind -name '\(query)' | head -n 1"
        runSearch(script: script)
    }

    private func liveSearch(query: String) -> [BuiltinResult] {
        guard !query.isEmpty else { return [] }

        // Search for top 10 files
        let script = "mdfind -name '\(query)' | head -n 10"

        // We need to run this synchronously for now to return [BuiltinResult]
        // Ideally this should be async but our current signature is sync.
        // Given mdfind is fast and we limit output, it might be okay.

        let task = Process()
        task.launchPath = "/bin/bash"
        task.arguments = ["-c", script]

        let pipe = Pipe()
        task.standardOutput = pipe

        do {
            try task.run()
        } catch {
            return []
        }

        task.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return [] }

        let paths = output.components(separatedBy: .newlines).filter { !$0.isEmpty }

        return paths.map { path in
            let url = URL(fileURLWithPath: path)
            let icon = NSWorkspace.shared.icon(forFile: path)
            let name = url.lastPathComponent

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
    }

    // Helper
    private func runSearch(script: String) {
         let task = Process()
         task.launchPath = "/bin/bash"
         task.arguments = ["-c", script]
         let pipe = Pipe()
         task.standardOutput = pipe
         try? task.run()

         let data = pipe.fileHandleForReading.readDataToEndOfFile()
         if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !output.isEmpty {
             let url = URL(fileURLWithPath: output)
             NSWorkspace.shared.activateFileViewerSelecting([url])
         }
    }
}
