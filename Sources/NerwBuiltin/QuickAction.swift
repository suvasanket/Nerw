import Cocoa
import NerwCore
import UniformTypeIdentifiers

public class QuickAction {
    public static let shared = QuickAction()

    // MARK: - App Management

    public func searchProcesses(query: String, completion: @escaping ([NerwAction]) -> Void) {
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
            task.standardError = Pipe()  // Ignore error

            do {
                try task.run()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                task.waitUntilExit()

                guard let output = String(data: data, encoding: .utf8) else {
                    DispatchQueue.main.async { completion([]) }
                    return
                }

                let lowerQuery = query.lowercased()
                let currentPid = ProcessInfo.processInfo.processIdentifier

                // Critical processes to protect (Guard Rails)
                let protectedProcesses = [
                    "loginwindow", "launchd", "UserEventAgent", "distnoted", "cfprefsd", "Nerw",
                ]

                var results: [NerwAction] = []

                // Parse lines. output header is "  PID COMMAND"
                let lines = output.components(separatedBy: .newlines).dropFirst()  // Skip header

                for line in lines {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { continue }

                    // Split PID and Command. PID is first non-space token.
                    let components = trimmed.split(
                        separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
                    guard components.count == 2,
                        let pid = Int(components[0]),
                        pid != currentPid  // Don't allow killing self
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
                    var iconType: NerwAction.IconType
                    if commandPath.hasSuffix(".app") || commandPath.contains(".app/") {
                        // Attempt to find app bundle path for icon
                        if let range = commandPath.range(of: ".app") {
                            let bundlePath = String(commandPath[..<range.upperBound])
                            iconType = .file(URL(fileURLWithPath: bundlePath))
                        } else {
                            iconType = .image(NSWorkspace.shared.icon(for: UTType.application))
                        }
                    } else {
                        iconType = .image(NSWorkspace.shared.icon(for: UTType.application))
                    }

                    results.append(
                        NerwAction(
                            id: "nerw.system.process.\(pid)",
                            title: commandName,
                            subtitle: "PID: \(pid) • \(commandPath)",
                            icon: iconType,
                            triggers: [commandName],
                            type: .instant(perform: { _ in
                                self.quitProcess(pid: pid, name: commandName)
                            })))
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

    public func quitProcess(pid: Int, name: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            // Try kill -TERM first (Graceful)
            let task = Process()
            task.launchPath = "/bin/kill"
            task.arguments = ["-TERM", "\(pid)"]
            task.standardOutput = FileHandle.nullDevice

            try? task.run()
            task.waitUntilExit()

            if task.terminationStatus != 0 {
                print("[QuickAction] Failed to TERM \(name) (\(pid)).")
            } else {
                print("[QuickAction] Sent TERM to \(name) (\(pid)).")
            }
        }
    }

    // Static helper for individual usage if needed
    public static func terminateApp(pid: pid_t, name: String) {
        QuickAction.shared.quitProcess(pid: Int(pid), name: name)
    }
}
