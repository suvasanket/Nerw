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

    // Quick Action: A secondary action available on this result (e.g. via Tab)
    // Wrapped in a class to avoid recursive struct value type error
    public let quickAction: NerwActionBox?

    public init(
        id: String,
        title: String,
        subtitle: String,
        icon: IconType? = nil,
        triggers: [String] = [],
        arguments: [String]? = nil,
        handler: ((String) -> Void)? = nil,
        searcher: ((String, @escaping ([NerwAction]) -> Void) -> Void)? = nil,
        quickAction: NerwAction? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.triggers = triggers
        self.arguments = arguments
        self.handler = handler
        self.searcher = searcher
        self.quickAction = quickAction.map { NerwActionBox($0) }
    }

    // Convenience for backward compatibility or simple boolean check
    public var supportsArguments: Bool {
        return arguments != nil
    }

    // Standardized Action Mode
    public enum ActionMode {
        case none
        case arguments
        case quickAction // Takes precedence if both exist
    }

    public var mode: ActionMode {
        if quickAction != nil { return .quickAction }
        if arguments != nil { return .arguments }
        return .none
    }

    // UI Automation Helpers
    public var modeIconName: String? {
        switch mode {
        case .none: return nil
        case .arguments: return "arrow.right.to.line"
        case .quickAction: return "bolt.fill"
        }
    }

    public var modeHintText: String? {
        switch mode {
        case .none:
            return nil
        case .arguments:
            if let args = arguments, !args.isEmpty {
                 return args[0]
            }
            return "Arguments"
        case .quickAction:
            return quickAction?.value.title
        }
    }
}
 
public class NerwActionBox {
    public let value: NerwAction
    public init(_ value: NerwAction) {
        self.value = value
    }
}
