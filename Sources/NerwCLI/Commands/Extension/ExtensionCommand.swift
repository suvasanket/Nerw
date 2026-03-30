import Foundation

/// Main extension management command
struct ExtensionCommand: Command {
    let metadata: CommandMetadata

    private let subcommands: [Subcommand]

    init() {
        let initCmd = InitSubcommand()
        let smokeTestCmd = SmokeTestSubcommand()
        let bundleCmd = BundleSubcommand()

        self.subcommands = [initCmd, smokeTestCmd, bundleCmd]

        self.metadata = CommandMetadata(
            name: "extension",
            description: "Manage Nerw extensions",
            usage: "nerw extension <subcommand>",
            subcommands: subcommands.map { $0.metadata }
        )
    }

    func execute(args: [String]) -> Never {
        guard let subcommandName = args.first else {
            HelpCommand().execute(args: ["extension"])
        }

        let remainingArgs = Array(args.dropFirst())

        guard let subcommand = subcommands.first(where: { $0.metadata.name == subcommandName })
        else {
            print("Error: Unknown subcommand '\(subcommandName)'")
            print("Run 'nerw help extension' for available subcommands.")
            exit(1)
        }

        subcommand.execute(args: remainingArgs)
    }
}
