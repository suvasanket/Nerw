import Foundation

#if canImport(FoundationModels)
    import FoundationModels
#endif

public class FoundationModelHandler: AIModelHandler {
    #if canImport(FoundationModels)
        @available(macOS 26.0, *)
        private static var currentSession: LanguageModelSession?
    #endif

    public init() {}

    public func generateResponse(
        messages: [AIChatMessage], images: [Data], isStreaming: Bool,
        actionIntents: Set<ActionIntent>
    )
        async throws
        -> AsyncThrowingStream<String, Error>
    {
        #if canImport(FoundationModels)
            if #available(macOS 26.0, *) {
                if SystemLanguageModel.default.isAvailable {
                    return try await runRealModel(
                        messages: messages, isStreaming: isStreaming, actionIntents: actionIntents)
                }
            }
        #endif
        let lastUserMessage = messages.last(where: { $0.role == .user })?.content ?? ""
        return runSimulatedModel(prompt: lastUserMessage, isStreaming: isStreaming)
    }

    #if canImport(FoundationModels)
        @available(macOS 26.0, *)
        private func runRealModel(
            messages: [AIChatMessage], isStreaming: Bool, actionIntents: Set<ActionIntent>
        ) async throws -> AsyncThrowingStream<String, Error> {
            if FoundationModelHandler.currentSession == nil || messages.count <= 3 {
                FoundationModelHandler.currentSession = LanguageModelSession()
            }

            let aiConfig = ConfigManager.shared.config.aiConfig
            let finalSystemPrompt = AIInstructionManager.shared.buildSystemPrompt(
                basePrompt: aiConfig.systemPrompt, actionIntents: actionIntents)

            var prompt = messages.last?.content ?? ""

            // Inject Personal Context Information (PCI) and System Prompts
            if messages.count <= 3 || !actionIntents.isEmpty {
                prompt = "System Context:\n\(finalSystemPrompt)\n\nUser Query:\n\(prompt)"
            }

            let session = FoundationModelHandler.currentSession!

            if isStreaming {
                let stream = session.streamResponse(to: prompt)
                return AsyncThrowingStream<String, Error> { continuation in
                    let task = Task {
                        do {
                            var lastContent = ""
                            for try await chunk in stream {
                                if Task.isCancelled { break }

                                let mirror = Mirror(reflecting: chunk)
                                var contentStr = ""
                                var hasContent = false

                                for child in mirror.children {
                                    if child.label == "content", let val = child.value as? String {
                                        contentStr = val
                                        hasContent = true
                                    } else if child.label == "text", !hasContent,
                                        let val = child.value as? String
                                    {
                                        contentStr = val
                                        hasContent = true
                                    }
                                }

                                if hasContent {
                                    if contentStr.hasPrefix(lastContent) {
                                        let delta = String(contentStr.dropFirst(lastContent.count))
                                        continuation.yield(delta)
                                        lastContent = contentStr
                                    } else {
                                        continuation.yield(contentStr)
                                        lastContent = contentStr
                                    }
                                } else {
                                    continuation.yield("\(chunk)")
                                }
                            }
                            continuation.finish()
                        } catch {
                            continuation.finish(throwing: error)
                        }
                    }
                    continuation.onTermination = { termination in
                        if case .cancelled = termination {
                            task.cancel()
                        }
                    }
                }
            } else {
                let response = try await session.respond(to: prompt)
                return AsyncThrowingStream<String, Error> { continuation in
                    let mirror = Mirror(reflecting: response)
                    var contentStr = ""
                    var hasContent = false
                    for child in mirror.children {
                        if child.label == "content", let val = child.value as? String {
                            contentStr = val
                            hasContent = true
                        } else if child.label == "text", !hasContent,
                            let val = child.value as? String
                        {
                            contentStr = val
                            hasContent = true
                        }
                    }

                    if hasContent {
                        continuation.yield(contentStr)
                    } else {
                        continuation.yield("\(response)")
                    }
                    continuation.finish()
                }
            }
        }
    #endif

    private func runSimulatedModel(prompt: String, isStreaming: Bool) -> AsyncThrowingStream<
        String, Error
    > {
        return AsyncThrowingStream<String, Error> {
            (continuation: AsyncThrowingStream<String, Error>.Continuation) in
            let task = Task {
                let simulatedText = """
                    [Apple Intelligence Simulation Mode]
                    Foundation model integration is currently unavailable on this device. Please configure and use the BYOK backend in Settings.

                    You queried: "\(prompt)"
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
