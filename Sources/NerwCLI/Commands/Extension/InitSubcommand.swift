import Foundation

/// Initialize a new extension template
struct InitSubcommand: Subcommand {
    let metadata = CommandMetadata(
        name: "init",
        description: "Initialize a new extension template",
        usage: "nerw extension init"
    )

    func execute(args: [String]) -> Never {
        print("Creating a new Nerw Extension...")

        print("Extension Name (e.g., My Search): ", terminator: "")
        guard let name = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty
        else {
            print("Error: Name is required")
            exit(1)
        }

        print("Extension ID (e.g., com.example.search): ", terminator: "")
        guard let id = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines), !id.isEmpty
        else {
            print("Error: ID is required")
            exit(1)
        }

        print("Trigger (e.g., g): ", terminator: "")
        guard let trigger = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines),
            !trigger.isEmpty
        else {
            print("Error: Trigger is required")
            exit(1)
        }

        let fileManager = FileManager.default
        let currentDir = CLIUtils.getCurrentExtensionDir()
        let extDir = currentDir.appendingPathComponent(
            name.lowercased().replacingOccurrences(of: " ", with: "-")
        )

        if fileManager.fileExists(atPath: extDir.path) {
            print("Error: Directory '\(extDir.lastPathComponent)' already exists")
            exit(1)
        }

        do {
            try fileManager.createDirectory(at: extDir, withIntermediateDirectories: true)

            let manifest: [String: Any] = [
                "id": id,
                "name": name,
                "description": "A new Nerw extension",
                "icon": "puzzlepiece.extension",
                "actions": [
                    [
                        "name": name,
                        "description": "A new Nerw extension",
                        "triggers": [trigger],
                        "icon": "puzzlepiece.extension",
                    ]
                ],
            ]

            let manifestData = try JSONSerialization.data(
                withJSONObject: manifest, options: .prettyPrinted)
            try manifestData.write(to: extDir.appendingPathComponent("manifest.json"))

            let template = """
                import Foundation
                import NerwExtensionKit

                struct \(name.replacingOccurrences(of: " ", with: "")): NerwExtension {
                    func query(input: QueryInput) -> [NerwResult] {
                        let query = input.query

                        return [
                            NerwResult("Example: \\(query)")
                                .subtitle("Custom result for trigger: \\(input.triggers.first ?? "none")")
                                .icon(.system("star"))
                                .instant(action: "https://google.com/search?q=\\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")
                        ]
                    }

                    func perform(action: ActionInput) {
                        // Handle function-based actions here
                    }
                }

                Nerw.run(\(name.replacingOccurrences(of: " ", with: ""))())
                """

            try template.write(
                to: extDir.appendingPathComponent("main.swift"), atomically: true, encoding: .utf8)

            print("Successfully created extension at: \(extDir.path)")
            print(
                "To test it, run: cd \(extDir.lastPathComponent) && nerw extension smoke-test 'hello'"
            )
            exit(0)

        } catch {
            print("Error: Failed to create extension: \(error)")
            exit(1)
        }
    }
}
