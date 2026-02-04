import Foundation

public struct ExtensionManifest: Codable {
    public let id: String
    public let name: String
    public let trigger: String
    public let triggers: [String]?
    public let description: String
    public let icon: String?

    public var allTriggers: [String] {
        var all = [trigger]
        if let extras = triggers {
            all.append(contentsOf: extras)
        }
        return all
    }
}

public struct ExtensionResult: Codable {
    public let title: String
    public let subtitle: String?
    public let icon: String?
    public let action: String?

    public init(title: String, subtitle: String? = nil, icon: String? = nil, action: String? = nil)
    {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.action = action
    }
}
