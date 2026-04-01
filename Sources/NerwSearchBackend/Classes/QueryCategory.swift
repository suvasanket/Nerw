/// Categories that can be assigned to actions and detected from queries.
/// The categorizer classifies user input and boosts actions matching the detected category.
///
/// Extensible: add new cases here for future category support (e.g. `.ai`, `.calc`, `.file`).
public enum QueryCategory: String, CaseIterable, Hashable, Sendable {
    /// The query looks like a web search (natural language question, multi-word lookup, etc.)
    case webSearch = "webSearch"
    /// The query looks like a URL or domain name
    case url = "url"
}
