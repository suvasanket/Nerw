import Foundation

public struct AIProviderPreset: Identifiable, Equatable {
    public var id: String { name }
    public let name: String
    public let defaultUrl: String
    public let domainMatch: String
    public let defaultSearchToolName: String
    public let defaultModelPlaceholder: String
    public let supportsCustomUrl: Bool

    public init(
        name: String,
        defaultUrl: String,
        domainMatch: String,
        defaultSearchToolName: String,
        defaultModelPlaceholder: String,
        supportsCustomUrl: Bool = false
    ) {
        self.name = name
        self.defaultUrl = defaultUrl
        self.domainMatch = domainMatch
        self.defaultSearchToolName = defaultSearchToolName
        self.defaultModelPlaceholder = defaultModelPlaceholder
        self.supportsCustomUrl = supportsCustomUrl
    }

    public static let openAI = AIProviderPreset(
        name: "OpenAI",
        defaultUrl: "https://api.openai.com/v1/chat/completions",
        domainMatch: "api.openai.com",
        defaultSearchToolName: "web_search",
        defaultModelPlaceholder: "gpt-4o"
    )

    public static let gemini = AIProviderPreset(
        name: "Google Gemini",
        defaultUrl: "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions",
        domainMatch: "generativelanguage.googleapis.com",
        defaultSearchToolName: "google_search",
        defaultModelPlaceholder: "gemini-2.5-flash"
    )

    public static let claude = AIProviderPreset(
        name: "Claude",
        defaultUrl: "https://api.anthropic.com/v1/messages",
        domainMatch: "anthropic.com",
        defaultSearchToolName: "web_search",
        defaultModelPlaceholder: "claude-3-5-sonnet-20241022"
    )

    public static let openRouter = AIProviderPreset(
        name: "OpenRouter",
        defaultUrl: "https://openrouter.ai/api/v1/chat/completions",
        domainMatch: "openrouter.ai",
        defaultSearchToolName: "openrouter:web_search",
        defaultModelPlaceholder: "google/gemini-2.5-flash"
    )

    public static let custom = AIProviderPreset(
        name: "Custom",
        defaultUrl: "",
        domainMatch: "",
        defaultSearchToolName: "web_search",
        defaultModelPlaceholder: "model-name",
        supportsCustomUrl: true
    )

    public static let allPresets: [AIProviderPreset] = [
        openAI,
        gemini,
        claude,
        openRouter,
        custom,
    ]

    /// Returns the preset matching the URL domain, or `.custom` if unrecognised/empty.
    public static func preset(forUrl url: String) -> AIProviderPreset {
        guard !url.isEmpty else { return custom }
        return allPresets.first { !$0.domainMatch.isEmpty && url.contains($0.domainMatch) }
            ?? custom
    }

    /// Returns the preset matching the given name, or `.custom` if unrecognised.
    public static func preset(forName name: String) -> AIProviderPreset {
        return allPresets.first { $0.name == name } ?? custom
    }
}
