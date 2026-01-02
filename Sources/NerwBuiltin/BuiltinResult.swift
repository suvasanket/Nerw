import Cocoa

public struct BuiltinResult {
    public let title: String
    public let subtitle: String
    public let iconName: String?
    public let icon: NSImage?
    public let supportsArguments: Bool
    public let handler: (String) -> Void
    public let searcher: ((String) -> [BuiltinResult])?
    
    public init(title: String, subtitle: String, iconName: String? = nil, icon: NSImage? = nil, supportsArguments: Bool, handler: @escaping (String) -> Void, searcher: ((String) -> [BuiltinResult])? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.iconName = iconName
        self.icon = icon
        self.supportsArguments = supportsArguments
        self.handler = handler
        self.searcher = searcher
    }
}
