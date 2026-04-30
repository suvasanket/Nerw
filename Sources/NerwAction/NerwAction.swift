import Cocoa
import NerwSearchBackend

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

    public struct PeekData {
        public let title: String
        public let text: String
        public let icon: IconType?
        public let primaryActionName: String?
        public let secondaryActionName: String?

        public init(
            title: String, text: String, icon: IconType? = nil, primaryActionName: String? = nil,
            secondaryActionName: String? = nil
        ) {
            self.title = title
            self.text = text
            self.icon = icon
            self.primaryActionName = primaryActionName
            self.secondaryActionName = secondaryActionName
        }
    }
    public let peek: PeekData?

    /// Optional category tag for smart ranking.
    /// Actions with a category get boosted when the query categorizer detects matching intent.
    public let category: QueryCategory?

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
        /// Executes immediately (e.g., "Reload Config").
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

        /// Inline Argument: Trigger + Space + Argument in the same field.
        /// e.g., "map <query>"
        /// - perform: Executed with the argument.
        /// - searcher: Optional. Provides dynamic results based on the argument.
        case inlineArg(
            perform: (NerwAction, String) -> Void,
            searcher: ((NerwAction, String, @escaping ([NerwAction]) -> Void) -> Void)? = nil
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

    public enum ModifierKey: String, Codable, CaseIterable {
        case command = "cmd"
        case shift = "shift"
        case control = "ctrl"
        case option = "opt"
    }

    public struct ModifierAction {
        public let title: String?
        public let subtitle: String?
        public let icon: IconType?
        public let perform: (NerwAction) -> Void

        public init(
            title: String? = nil, subtitle: String? = nil, icon: IconType? = nil,
            perform: @escaping (NerwAction) -> Void
        ) {
            self.title = title
            self.subtitle = subtitle
            self.icon = icon
            self.perform = perform
        }
    }

    public let modifiers: [ModifierKey: ModifierAction]

    public let type: ActionType

    public let isPersistent: Bool

    public init(
        id: String,
        title: String,
        subtitle: String,
        icon: IconType? = nil,
        peek: PeekData? = nil,
        category: QueryCategory? = nil,
        triggers: [String] = [],
        modifiers: [ModifierKey: ModifierAction] = [:],
        type: ActionType,
        isPersistent: Bool = false
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.peek = peek
        self.category = category

        // Merge custom aliases from config
        var allTriggers = triggers
        let customAliases = NerwActionPreferenceManager.shared.aliases(for: id)
        if !customAliases.isEmpty {
            allTriggers.append(contentsOf: customAliases)
        }
        // Deduplicate and filter empty, preserving order if possible but Set is easier
        // Actually, let's keep it simple
        var uniqueTriggers: [String] = []
        for t in allTriggers {
            let trimmed = t.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty && !uniqueTriggers.contains(trimmed) {
                uniqueTriggers.append(trimmed)
            }
        }
        self.triggers = uniqueTriggers

        self.modifiers = modifiers
        self.type = type
        self.isPersistent = isPersistent
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
        case .inlineArg:
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
        case .none:
            if case .inlineArg = type { return "bolt.horizontal.fill" }
            return nil
        case .arguments: return "arrow.right.to.line"
        case .form: return "pencil"
        case .quickAction: return "bolt.fill"
        }
    }

    public var modeHintText: String? {
        switch type {
        case .instant:
            return nil
        case .inlineArg:
            return triggers.first ?? "Arg"
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
        case .arg, .args, .form, .inlineArg: return true
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
