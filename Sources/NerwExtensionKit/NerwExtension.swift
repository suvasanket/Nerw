import Foundation

// MARK: - Protocol

/// Protocol that all Nerw extensions must conform to.
public protocol NerwExtension {
    /// Called when the user types a query with this extension's trigger.
    func query(input: QueryInput) -> [NerwResult]

    /// Called when the user triggers a function-based action.
    func perform(action: ActionInput)
}

/// Default empty implementation — extensions that only return URL actions can skip this.
extension NerwExtension {
    public func perform(action: ActionInput) {}
}

// MARK: - Input Types

/// Input received during a query.
public struct QueryInput {
    public let query: String
    public let trigger: String?

    public init(query: String, trigger: String? = nil) {
        self.query = query
        self.trigger = trigger
    }
}

/// Input received when triggering an action.
public struct ActionInput {
    public let function: String
    public let args: [String]
    public let formValues: [String: String]

    public init(
        function: String, args: [String] = [], formValues: [String: String] = [:]
    ) {
        self.function = function
        self.args = args
        self.formValues = formValues
    }
}
