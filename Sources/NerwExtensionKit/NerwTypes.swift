import Foundation

// MARK: - Icon

/// Icon type for search results.
public enum NerwIcon {
    /// SF Symbol name (e.g. "star.fill", "magnifyingglass").
    case system(String)
    /// Absolute file path to an image.
    case file(String)

    func serialize() -> String {
        switch self {
        case .system(let name): return name
        case .file(let path): return path
        }
    }
}

// MARK: - Form Field

/// A single input field in a form.
public struct NerwField {
    public let id: String
    public let title: String
    public let subtext: String?
    public let placeholder: String?
    public let isSecure: Bool
    public let isMultiline: Bool
    public let defaultValue: String?

    public init(
        _ id: String,
        title: String,
        subtext: String? = nil,
        placeholder: String? = nil,
        secure: Bool = false,
        multiline: Bool = false,
        defaultValue: String? = nil
    ) {
        self.id = id
        self.title = title
        self.subtext = subtext
        self.placeholder = placeholder
        self.isSecure = secure
        self.isMultiline = multiline
        self.defaultValue = defaultValue
    }

    func serialize() -> [String: Any] {
        var dict: [String: Any] = ["id": id, "title": title]
        if let s = subtext { dict["subtext"] = s }
        if let p = placeholder { dict["placeholder"] = p }
        if isSecure { dict["secure"] = true }
        if isMultiline { dict["multiline"] = true }
        if let d = defaultValue { dict["defaultValue"] = d }
        return dict
    }
}

// MARK: - Peek (Expanded Preview)

/// Configuration for an expanded inline preview (Peek).
public struct NerwPeek {
    public let title: String
    public let text: String
    public let icon: NerwIcon?
    public let primaryActionName: String?
    public let secondaryActionName: String?

    public init(
        title: String,
        text: String,
        icon: NerwIcon? = nil,
        primaryAction: String? = nil,
        secondaryAction: String? = nil
    ) {
        self.title = title
        self.text = text
        self.icon = icon
        self.primaryActionName = primaryAction
        self.secondaryActionName = secondaryAction
    }

    func serialize() -> [String: Any] {
        var dict: [String: Any] = ["title": title, "text": text]
        if let icon = icon { dict["icon"] = icon.serialize() }
        if let pa = primaryActionName { dict["primaryActionName"] = pa }
        if let sa = secondaryActionName { dict["secondaryActionName"] = sa }
        return dict
    }
}
