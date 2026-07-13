import Cocoa
import NerwAction
import NerwCore

public class ConversationManager {
    public static let shared = ConversationManager()

    public var showWindowCallback: ((String?) -> Void)?

    private init() {}

    public static func builtinActions() -> [NerwAction] {
        return []
    }
}
