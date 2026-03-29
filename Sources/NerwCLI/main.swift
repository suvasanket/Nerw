import Foundation

struct NerwCLI {
    static func main() {
        let arguments = Array(CommandLine.arguments.dropFirst())

        guard let command = arguments.first else {
            printUsage()
            return
        }

        switch command {
        case "help":
            printUsage()
        case "extension":
            print("Nerw CLI: Extension management (to be implemented)")
        default:
            print("Error: Unknown command '\(command)'")
            printUsage()
            exit(1)
        }
    }

    static func printUsage() {
        print(
            """
            Nerw CLI - macOS Popup Utility Controller

            Usage: nerw <command> [options]

            Commands:
              help       Show this help message
              extension  Manage Nerw extensions
            """)
    }
}

NerwCLI.main()
