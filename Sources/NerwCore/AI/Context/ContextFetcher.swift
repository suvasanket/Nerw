import Foundation

public struct FetchedContext {
    public let text: String?
    public let images: [Data]?

    public init(text: String? = nil, images: [Data]? = nil) {
        self.text = text
        self.images = images
    }
}

public struct InjectedContext {
    public let text: String
    public let images: [Data]
}

public protocol ContextFetching {
    var intentType: String { get }
    func canHandle(intent: ContextIntent) -> Bool
    func fetchContext(for intent: ContextIntent) async -> FetchedContext?
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

    public func fetchAllContext(for intents: [ContextIntent]) async -> InjectedContext {
        var contextBlocks: [String] = []
        var images: [Data] = []

        for intent in intents {
            for fetcher in fetchers {
                if fetcher.canHandle(intent: intent) {
                    if let result = await fetcher.fetchContext(for: intent) {
                        if let text = result.text {
                            contextBlocks.append(text)
                        }
                        if let fetchedImages = result.images {
                            images.append(contentsOf: fetchedImages)
                        }
                    }
                }
            }
        }

        let combinedText: String
        if contextBlocks.isEmpty {
            combinedText = ""
        } else {
            let combined = contextBlocks.joined(separator: "\n\n")
            combinedText = "<system_context>\n\(combined)\n</system_context>"
        }

        return InjectedContext(text: combinedText, images: images)
    }
}

public class SystemContextFetcher: ContextFetching {
    public var intentType: String { return "system" }

    public init() {}

    public func canHandle(intent: ContextIntent) -> Bool {
        if case .system = intent { return true }
        return false
    }

    public func fetchContext(for intent: ContextIntent) async -> FetchedContext? {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .long
        let now = Date()
        let timeString = formatter.string(from: now)
        let timeZone = TimeZone.current.identifier

        let text = """
            [System Context]
            Current Date & Time: \(timeString)
            Timezone: \(timeZone)
            OS: macOS
            """
        return FetchedContext(text: text)
    }
}
