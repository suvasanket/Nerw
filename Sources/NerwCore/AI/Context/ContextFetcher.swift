import Foundation

public protocol ContextFetching {
    var intentType: String { get }
    func canHandle(intent: ContextIntent) -> Bool
    func fetchContext(for intent: ContextIntent) async -> String?
}

public class ContextInjectionManager {
    public static let shared = ContextInjectionManager()

    private var fetchers: [ContextFetching] = []

    private init() {
        register(SystemContextFetcher())
    }

    public func register(_ fetcher: ContextFetching) {
        fetchers.append(fetcher)
    }

    public func fetchAllContext(for intents: [ContextIntent]) async -> String {
        var contextBlocks: [String] = []

        for intent in intents {
            for fetcher in fetchers {
                if fetcher.canHandle(intent: intent) {
                    if let result = await fetcher.fetchContext(for: intent) {
                        contextBlocks.append(result)
                    }
                }
            }
        }

        guard !contextBlocks.isEmpty else { return "" }

        let combined = contextBlocks.joined(separator: "\n\n")
        return "<system_context>\n\(combined)\n</system_context>"
    }
}

public class SystemContextFetcher: ContextFetching {
    public var intentType: String { return "system" }

    public init() {}

    public func canHandle(intent: ContextIntent) -> Bool {
        if case .system = intent { return true }
        return false
    }

    public func fetchContext(for intent: ContextIntent) async -> String? {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .long
        let now = Date()
        let timeString = formatter.string(from: now)
        let timeZone = TimeZone.current.identifier

        return """
            [System Context]
            Current Date & Time: \(timeString)
            Timezone: \(timeZone)
            OS: macOS
            """
    }
}
