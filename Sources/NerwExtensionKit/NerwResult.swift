import Foundation

/// Box type to allow recursive NerwResult references (needed for hybrid quickAction).
public class NerwResultBox {
    public let value: NerwResult
    public init(_ value: NerwResult) { self.value = value }
}

/// A search result returned by an extension. Use builder methods to configure.
///
/// Example:
/// ```swift
/// NerwResult("Search Google")
///     .subtitle("Search the web")
///     .icon(.system("magnifyingglass"))
///     .arg(names: ["Query"], action: "doSearch")
/// ```
public struct NerwResult {
    public var title: String
    public var subtitleText: String
    public var resultIcon: NerwIcon

    // Action configuration
    var actionType: String
    var actionValue: String?
    var argNamesList: [String]?
    var quickActionResult: NerwResultBox?
    var formFieldsList: [NerwField]?
    var formSubmitLabelText: String?

    // Peek
    var peekData: NerwPeek?

    /// Create a new result with a title.
    public init(_ title: String) {
        self.title = title
        self.subtitleText = ""
        self.resultIcon = .system("puzzlepiece.extension")
        self.actionType = "instant"
    }

    // MARK: - Builder Methods

    /// Set the subtitle text.
    public func subtitle(_ text: String) -> NerwResult {
        var copy = self
        copy.subtitleText = text
        return copy
    }

    /// Set the icon.
    public func icon(_ icon: NerwIcon) -> NerwResult {
        var copy = self
        copy.resultIcon = icon
        return copy
    }

    /// Configure as instant action (executes immediately).
    /// `action` can be a URL string or a function name.
    public func instant(action: String) -> NerwResult {
        var copy = self
        copy.actionType = "instant"
        copy.actionValue = action
        return copy
    }

    /// Configure as argument action (prompts user for inputs).
    /// `names` defines the placeholder for each step.
    /// `action` is the function name called with collected args.
    public func arg(names: [String] = ["Query"], action: String) -> NerwResult {
        var copy = self
        copy.actionType = "arg"
        copy.actionValue = action
        copy.argNamesList = names
        return copy
    }

    /// Configure as hybrid action (Enter = primary, Tab = quick action).
    /// `action` is the primary action (URL or function name).
    /// `quickAction` defines the secondary action shown on Tab.
    public func hybrid(action: String, quickAction: NerwResult) -> NerwResult {
        var copy = self
        copy.actionType = "hybrid"
        copy.actionValue = action
        copy.quickActionResult = NerwResultBox(quickAction)
        return copy
    }

    /// Configure as form action (multi-field input).
    /// `fields` defines the form fields.
    /// `action` is the function name called with submitted values.
    public func form(
        fields: [NerwField],
        submitLabel: String? = nil,
        action: String
    ) -> NerwResult {
        var copy = self
        copy.actionType = "form"
        copy.actionValue = action
        copy.formFieldsList = fields
        copy.formSubmitLabelText = submitLabel
        return copy
    }

    /// Add peek (expanded inline preview).
    public func peek(_ peek: NerwPeek) -> NerwResult {
        var copy = self
        copy.peekData = peek
        return copy
    }

    /// Convenience: add peek with inline parameters.
    public func peek(
        title: String,
        text: String,
        icon: NerwIcon? = nil,
        primaryAction: String? = nil,
        secondaryAction: String? = nil
    ) -> NerwResult {
        peek(
            NerwPeek(
                title: title, text: text, icon: icon,
                primaryAction: primaryAction, secondaryAction: secondaryAction
            ))
    }

    // MARK: - Serialization

    func serialize() -> [String: Any] {
        var dict: [String: Any] = [
            "title": title,
            "subtitle": subtitleText,
            "icon": resultIcon.serialize(),
            "type": actionType,
        ]

        if let action = actionValue { dict["action"] = action }
        if let args = argNamesList { dict["argNames"] = args }

        if let qa = quickActionResult {
            dict["quickAction"] = qa.value.serialize()
        }

        if let fields = formFieldsList {
            var formDict: [String: Any] = [
                "fields": fields.map { $0.serialize() }
            ]
            if let label = formSubmitLabelText { formDict["submitLabel"] = label }
            dict["form"] = formDict
        }

        if let peek = peekData { dict["peek"] = peek.serialize() }

        return dict
    }
}
