import Cocoa

public struct NerwAction {
    public let id: String
    public let title: String
    public let subtitle: String

    public enum IconType {
        case system(String)
        case image(NSImage)
        case file(URL)
    }
    public let icon: IconType?

    public let triggers: [String]

    public struct Field {
        public let id: String
        public let title: String
        public let placeholder: String?
        public let isSecure: Bool

        public init(id: String, title: String, placeholder: String? = nil, isSecure: Bool = false) {
            self.id = id
            self.title = title
            self.placeholder = placeholder
            self.isSecure = isSecure
        }
    }

    public enum ActionType {
        /// Executes immediately (e.g., "Reload Config", "Sleep").
        /// - perform: Handler receives the action instance itself.
        case instant(
            perform: (NerwAction) -> Void
        )

        /// Requires arguments (Input), NO suggestions provided by this action.
        /// - placeholders: Hints for each argument step (e.g. ["Query"], ["URL", "Trigger"]).
        /// - perform: Executed when all arguments are collected.
        case arg(
            placeholders: [String],
            perform: (NerwAction, [String]) -> Void
        )

        /// Requires argument (Input), HAS suggestions (Search/Catalog).
        /// - placeholder: Hint for the input.
        /// - searcher: Provides dynamic results (autocomplete).
        /// - perform: Optional. If set, allows executing the raw input (e.g. "Google <text>").
        case args(
            placeholder: String,
            searcher: (NerwAction, String, @escaping ([NerwAction]) -> Void) -> Void,
            perform: ((NerwAction, String) -> Void)? = nil
        )

        /// Form-based input with multiple named fields.
        case form(
            fields: [Field],
            submitLabel: String? = nil,
            perform: (NerwAction, [String: String]) -> Void
        )

        /// Hybrid: Combination of Instant & Drill-down.
        /// - perform: Executed on Enter (Instant).
        /// - action: The secondary action triggered by Tab/Drill-down.
        ///           This can be .arg (Instant & Arg) or .args (Instant & Args).
        case hybrid(
            perform: (NerwAction) -> Void,
            action: NerwActionBox
        )
    }

    public let type: ActionType

    public init(
        id: String,
        title: String,
        subtitle: String,
        icon: IconType? = nil,
        triggers: [String] = [],
        type: ActionType
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.triggers = triggers
        self.type = type
    }

    // MARK: - Compatibility / UI Helpers

    public enum ActionMode {
        case none
        case arguments
        case form
        case quickAction
    }

    public var mode: ActionMode {
        switch type {
        case .instant:
            return .none
        case .arg, .args:
            return .arguments
        case .form:
            return .form
        case .hybrid:
            return .quickAction
        }
    }

    public var modeIconName: String? {
        switch mode {
        case .none: return nil
        case .arguments: return "arrow.right.to.line"
        case .form: return "list.bullet.rectangle.portrait"
        case .quickAction: return "bolt.fill"
        }
    }

    public var modeHintText: String? {
        switch type {
        case .instant:
            return nil
        case .arg(let placeholders, _):
            return placeholders.first
        case .args(let placeholder, _, _):
            return placeholder
        case .form(_, let submitLabel, _):
            return submitLabel ?? "Submit"
        case .hybrid(_, let box):
            return box.value.title
        }
    }

    public var supportsArguments: Bool {
        switch type {
        case .arg, .args, .form: return true
        default: return false
        }
    }
}

public class NerwActionBox {
    public let value: NerwAction
    public init(_ value: NerwAction) {
        self.value = value
    }
}
