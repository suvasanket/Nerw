import Foundation

/// Nerw CLI - Main entry point
struct NerwCLI {
    private static var commands: [String: Command] = [:]

    static func main() {
        registerCommands()

        let arguments = Array(CommandLine.arguments.dropFirst())

        guard let commandName = arguments.first else {
            HelpCommand().execute(args: [])
        }

        guard let command = commands[commandName] else {
            print("Error: Unknown command '\(commandName)'")
            print("Run 'nerw help' for available commands.")
            exit(1)
        }

        command.execute(args: Array(arguments.dropFirst()))
    }

    private static func registerCommands() {
        let extensionCmd = ExtensionCommand()
        commands["extension"] = extensionCmd
        CommandRegistry.shared.register(extensionCmd.metadata)

        let daemonCmd = DaemonCommand()
        commands["daemon"] = daemonCmd
        CommandRegistry.shared.register(daemonCmd.metadata)

        let helpCmd = HelpCommand()
        commands["help"] = helpCmd
        CommandRegistry.shared.register(helpCmd.metadata)
    }
}

NerwCLI.main()
