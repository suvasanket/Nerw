import Foundation

/// Help command to display usage information
struct HelpCommand: Command {
    let metadata = CommandMetadata(
        name: "help",
        description: "Show help message",
        usage: "nerw help [command]"
    )

    func execute(args: [String]) -> Never {
        if let target = args.first {
            guard let command = CommandRegistry.shared.get(target) else {
                print("Error: Unknown command '\(target)'")
                print("Run 'nerw help' for available commands.")
                exit(1)
            }
            printHelp(for: command)
            exit(0)
        }

        printGeneralHelp()
        exit(0)
    }

    private func pad(_ count: Int) -> String {
        String(repeating: " ", count: count)
    }

    private func printGeneralHelp() {
        print("Nerw CLI - macOS Popup Utility Controller")
        print("")
        print("Usage: nerw <command> [options]")
        print("")
        print("Commands:")

        let commands = CommandRegistry.shared.allCommands
        for cmd in commands {
            print("  \(cmd.name)\(pad(max(0, 14 - cmd.name.count)))\(cmd.description)")
        }

        print("")
        print("Use 'nerw help <command>' for more information about a command.")
    }

    private func printHelp(for command: CommandMetadata) {
        print("\(command.name.uppercased())")
        print("")
        print(command.description)
        print("")
        print("Usage: \(command.usage)")

        if !command.flags.isEmpty {
            print("")
            print("Flags:")
            for flag in command.flags {
                let flagStr = flag.names.joined(separator: ", ")
                print("  \(flagStr)\(pad(max(0, 24 - flagStr.count)))\(flag.description)")
            }
        }

        if let subcommands = command.subcommands, !subcommands.isEmpty {
            print("")
            print("Subcommands:")
            for sub in subcommands {
                print("  \(sub.name)\(pad(max(0, 16 - sub.name.count)))\(sub.description)")

                if !sub.flags.isEmpty {
                    for flag in sub.flags {
                        let flagStr = flag.names.joined(separator: ", ")
                        print("    \(flagStr)\(pad(max(0, 24 - flagStr.count)))\(flag.description)")
                    }
                }
            }
        }
    }
}
