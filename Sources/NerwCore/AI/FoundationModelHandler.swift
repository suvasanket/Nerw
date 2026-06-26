import Foundation

public class FoundationModelHandler: AIModelHandler {
    public init() {}

    public func generateResponse(
        messages: [AIChatMessage], images: [Data], isStreaming: Bool,
        actionIntents: Set<ActionIntent>
    )
        async throws
        -> AsyncThrowingStream<String, Error>
    {
        // Since Foundation model integration is paused, we always return the simulated model response
        let lastUserMessage = messages.last(where: { $0.role == .user })?.content ?? ""
        return runSimulatedModel(prompt: lastUserMessage, isStreaming: isStreaming)
    }

    private func runSimulatedModel(prompt: String, isStreaming: Bool) -> AsyncThrowingStream<
        String, Error
    > {
        return AsyncThrowingStream<String, Error> {
            (continuation: AsyncThrowingStream<String, Error>.Continuation) in
            let task = Task {
                let simulatedText = """
                    [Apple Intelligence Simulation Mode]
                    Foundation model integration is currently paused. Please configure and use the BYOK backend in Settings.

                    You queried: "\(prompt)"

                    This simulated message demonstrates that the socket IPC stream is fully operational.
                    """

                if isStreaming {
                    let words = simulatedText.split(
                        separator: " ", omittingEmptySubsequences: false)
                    for (index, word) in words.enumerated() {
                        if Task.isCancelled { break }
                        let delta = String(word) + (index == words.count - 1 ? "" : " ")
                        continuation.yield(delta)
                        try? await Task.sleep(nanoseconds: 30_000_000)
                    }
                } else {
                    continuation.yield(simulatedText)
                }
                continuation.finish()
            }

            continuation.onTermination = { termination in
                if case .cancelled = termination {
                    task.cancel()
                }
            }
        }
    }
}
