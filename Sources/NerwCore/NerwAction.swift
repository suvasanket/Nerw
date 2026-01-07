import Cocoa

public struct NerwAction {
    public let id: String
    public let title: String
    public let subtitle: String

    public enum IconType {
        case system(String)
        case image(NSImage)
    }
    public let icon: IconType?

    public let triggers: [String] // Trigger words

    // Arguments configuration
    public let arguments: [String]? // List of argument names/placeholders. Nil if no args.

    // Execution Logic
    // Handler: Executed when the action is final (or args are collected)
    // Parameter is the collected arguments string (or query)
    public let handler: ((String) -> Void)?

    // Searcher: For dynamic results (argument gathering or recursive search)
    public let searcher: ((String, @escaping ([NerwAction]) -> Void) -> Void)?

    public init(
        id: String,
        title: String,
        subtitle: String,
        icon: IconType? = nil,
        triggers: [String] = [],
        arguments: [String]? = nil,
        handler: ((String) -> Void)? = nil,
        searcher: ((String, @escaping ([NerwAction]) -> Void) -> Void)? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.triggers = triggers
        self.arguments = arguments
        self.handler = handler
        self.searcher = searcher
    }

    // Convenience for backward compatibility or simple boolean check
    public var supportsArguments: Bool {
        return arguments != nil
    }
}
