import Foundation

public final class ShortcutsManager: Sendable {
    public static let shared = ShortcutsManager()

    // Standard path for shortcuts CLI on macOS 12+
    private let shortcutsPath = "/usr/bin/shortcuts"

    private init() {}

    /// Lists all available shortcuts.
    public func listShortcuts() async throws -> [String] {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let output = try self.runShortcutsCommandSync(args: ["list"])
                    let list = output.components(separatedBy: .newlines)
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                        .filter { !$0.isEmpty }
                    continuation.resume(returning: list)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Runs a shortcut by name.
    public func runShortcut(_ name: String) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    _ = try self.runShortcutsCommandSync(args: ["run", name])
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // Synchronous internal helper
    private func runShortcutsCommandSync(args: [String]) throws -> String {
        guard FileManager.default.fileExists(atPath: shortcutsPath) else {
            throw NSError(
                domain: "NerwBuiltin.ShortcutsManager",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Shortcuts CLI not found at \(shortcutsPath)"]
            )
        }

        let task = Process()
        task.launchPath = shortcutsPath
        task.arguments = args

        let outPipe = Pipe()
        let errPipe = Pipe()
        task.standardOutput = outPipe
        task.standardError = errPipe

        try task.run()
        task.waitUntilExit()

        let data = outPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        if task.terminationStatus != 0 {
            let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            let errOutput = String(data: errData, encoding: .utf8) ?? ""

            // Should we return empty if it's just no output but success?
            // terminationStatus != 0 means error.
            throw NSError(
                domain: "NerwBuiltin.ShortcutsManager",
                code: Int(task.terminationStatus),
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "Shortcuts command failed (code \(task.terminationStatus)): \(errOutput.trimmingCharacters(in: .whitespacesAndNewlines))"
                ]
            )
        }

        return output
    }
}
