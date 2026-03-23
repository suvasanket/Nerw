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
    public let placeholder: String?
    public let isSecure: Bool

    public init(_ id: String, title: String, placeholder: String? = nil, secure: Bool = false) {
        self.id = id
        self.title = title
        self.placeholder = placeholder
        self.isSecure = secure
    }

    func serialize() -> [String: Any] {
        var dict: [String: Any] = ["id": id, "title": title]
        if let p = placeholder { dict["placeholder"] = p }
        if isSecure { dict["secure"] = true }
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
