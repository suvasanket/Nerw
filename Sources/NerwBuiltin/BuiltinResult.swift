import Foundation

public struct BuiltinResult {
    public let title: String
    public let subtitle: String
    public let iconName: String
    public let supportsArguments: Bool
    public let handler: (String) -> Void
    
    public init(title: String, subtitle: String, iconName: String, supportsArguments: Bool, handler: @escaping (String) -> Void) {
        self.title = title
        self.subtitle = subtitle
        self.iconName = iconName
        self.supportsArguments = supportsArguments
        self.handler = handler
    }
}
