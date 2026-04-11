import Foundation
import NerwSearchBackend

// `NerwActionPreferenceManager` handles preferences.

public struct NerwActionContext {
    public struct Section {
        public let id: String
        public let title: String
        public let operations: [Operation]

        public init(id: String, title: String, operations: [Operation]) {
            self.id = id
            self.title = title
            self.operations = operations
        }
    }

    public enum OperationKind: Equatable {
        case primary
        case secondary
        case modifier(NerwAction.ModifierKey)
        case alias
        case hotkey
    }

    public enum Interaction: Equatable {
        case execute
        case textInput(placeholder: String, value: String)
        case hotkeyInput(value: String)
    }

    public struct Operation {
        public let id: String
        public let kind: OperationKind
        public let title: String
        public let subtitle: String
        public let icon: NerwAction.IconType?
        public let interaction: Interaction

        public init(
            id: String,
            kind: OperationKind,
            title: String,
            subtitle: String,
            icon: NerwAction.IconType?,
            interaction: Interaction
        ) {
            self.id = id
            self.kind = kind
            self.title = title
            self.subtitle = subtitle
            self.icon = icon
            self.interaction = interaction
        }
    }

    public let actionID: String
    public let actionTitle: String
    public let actionSubtitle: String
    public let sections: [Section]

    public var operations: [Operation] {
        sections.flatMap(\.operations)
    }

    public init(actionID: String, actionTitle: String, actionSubtitle: String, sections: [Section])
    {
        self.actionID = actionID
        self.actionTitle = actionTitle
        self.actionSubtitle = actionSubtitle
        self.sections = sections
    }
}

public enum NerwActionContextBuilder {
    public static func build(for action: NerwAction) -> NerwActionContext {
        var sections: [NerwActionContext.Section] = [
            .init(id: "action", title: "Action", operations: primaryOperations(for: action))
        ]

        let modifierOperations = modifierOperations(for: action)
        if !modifierOperations.isEmpty {
            sections.append(
                .init(id: "modifiers", title: "Modifiers", operations: modifierOperations))
        }

        sections.append(
            .init(
                id: "configuration",
                title: "Configuration",
                operations: configurationOperations(for: action)
            ))

        return NerwActionContext(
            actionID: action.id,
            actionTitle: action.title,
            actionSubtitle: action.subtitle,
            sections: sections
        )
    }

    private static func primaryOperations(for action: NerwAction) -> [NerwActionContext.Operation] {
        var operations: [NerwActionContext.Operation] = [
            .init(
                id: "primary",
                kind: .primary,
                title: primaryTitle(for: action),
                subtitle: primarySubtitle(for: action),
                icon: action.icon,
                interaction: .execute
            )
        ]

        if case .hybrid(_, let quickActionBox) = action.type {
            let quickAction = quickActionBox.value
            operations.append(
                .init(
                    id: "secondary",
                    kind: .secondary,
                    title: secondaryTitle(for: action, quickAction: quickAction),
                    subtitle: secondarySubtitle(for: action, quickAction: quickAction),
                    icon: quickAction.icon,
                    interaction: .execute
                ))
        }

        return operations
    }

    private static func modifierOperations(for action: NerwAction) -> [NerwActionContext.Operation]
    {
        NerwAction.ModifierKey.allCases.compactMap { key in
            guard let modifier = action.modifiers[key] else { return nil }

            return .init(
                id: "modifier.\(key.rawValue)",
                kind: .modifier(key),
                title: modifier.title ?? "\(modifierName(for: key)) Action",
                subtitle: modifier.subtitle ?? "Run \(action.title) with \(modifierName(for: key))",
                icon: modifier.icon ?? action.icon,
                interaction: .execute
            )
        }
    }

    private static func configurationOperations(for action: NerwAction) -> [NerwActionContext
        .Operation]
    {
        let aliasesValue = NerwActionAlias.getString(for: action.id)
        let hotkeyValue = NerwActionHotkey.get(for: action.id)

        return [
            .init(
                id: "alias",
                kind: .alias,
                title: "Set Alias",
                subtitle: aliasesValue.isEmpty
                    ? "Add space-separated aliases for this action" : aliasesValue,
                icon: .system("at"),
                interaction: .textInput(
                    placeholder: "space-separated aliases",
                    value: aliasesValue
                )
            ),
            .init(
                id: "hotkey",
                kind: .hotkey,
                title: "Set Hotkey",
                subtitle: hotkeyValue.isEmpty
                    ? "Assign a global hotkey to this action" : hotkeyValue,
                icon: .system("command"),
                interaction: .hotkeyInput(value: hotkeyValue)
            ),
        ]
    }

    private static func primaryTitle(for action: NerwAction) -> String {
        if let customTitle = normalized(action.peek?.primaryActionName) {
            return customTitle
        }

        switch action.type {
        case .instant:
            return "Run"
        case .inlineArg:
            return "Start Inline Input"
        case .arg, .args:
            return "Enter Arguments"
        case .form(_, let submitLabel, _):
            return normalized(submitLabel) ?? "Open Form"
        case .hybrid:
            return "Default Action"
        }
    }

    private static func primarySubtitle(for action: NerwAction) -> String {
        switch action.type {
        case .instant, .hybrid:
            return normalized(action.subtitle) ?? "Execute \(action.title)"
        case .inlineArg:
            if let trigger = normalized(action.triggers.first) {
                return "Insert '\(trigger)' and keep typing"
            }
            return "Start inline input for \(action.title)"
        case .arg(let placeholders, _):
            if let placeholder = normalized(placeholders.first) {
                return "Start with \(placeholder)"
            }
            return "Collect arguments for \(action.title)"
        case .args(let placeholder, _, _):
            return "Start with \(placeholder)"
        case .form:
            return "Open the form for \(action.title)"
        }
    }

    private static func secondaryTitle(for action: NerwAction, quickAction: NerwAction) -> String {
        if let customTitle = normalized(action.peek?.secondaryActionName) {
            return customTitle
        }
        return quickAction.title
    }

    private static func secondarySubtitle(for action: NerwAction, quickAction: NerwAction) -> String
    {
        normalized(quickAction.subtitle) ?? "Open the secondary action for \(action.title)"
    }

    private static func modifierName(for key: NerwAction.ModifierKey) -> String {
        switch key {
        case .command:
            return "Command"
        case .shift:
            return "Shift"
        case .control:
            return "Control"
        case .option:
            return "Option"
        }
    }

    private static func normalized(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty
        else { return nil }
        return value
    }
}
