import Foundation
import NerwUtils

#if canImport(FoundationModels)
    import FoundationModels
#endif

public protocol AIModelHandler {
    func generateResponse(
        messages: [AIChatMessage], images: [Data], isStreaming: Bool,
        actionIntents: Set<ActionIntent>
    ) async throws
        -> AsyncThrowingStream<String, Error>
}

public class AIService {
    public static let shared = AIService()

    private init() {}

    /// Dynamically routes the generation request to the selected model provider based on configuration.
    public func generateResponse(
        messages: [AIChatMessage], images: [Data] = [], isStreaming: Bool = true
    )
        async throws -> AsyncThrowingStream<String, Error>
    {
        Logger.shared.info(
            "AIService: generateResponse called. Messages count: \(messages.count), images count: \(images.count), isStreaming: \(isStreaming)"
        )
        let config = ConfigManager.shared.config.aiConfig

        guard config.isEnabled else {
            Logger.shared.error("AIService: AI integration is currently disabled in settings.")
            throw NSError(
                domain: "NerwAI", code: 403,
                userInfo: [
                    NSLocalizedDescriptionKey: "AI integration is currently disabled in settings."
                ])
        }

        guard let activeProvider = config.activeProvider else {
            Logger.shared.error("AIService: No active AI provider found.")
            throw NSError(
                domain: "NerwAI", code: 404,
                userInfo: [
                    NSLocalizedDescriptionKey: "No active AI provider found."
                ])
        }

        let handler: AIModelHandler
        if activeProvider.type == "foundation" {
            Logger.shared.info("AIService: Selected FoundationModelHandler")
            handler = FoundationModelHandler()
        } else {
            Logger.shared.info(
                "AIService: Selected BYOKModelHandler (API URL: \(activeProvider.url), Model: \(activeProvider.modelName))"
            )
            handler = BYOKModelHandler(provider: activeProvider)
        }

        var updatedMessages = messages
        var allImages = images
        var actionIntents = Set<ActionIntent>()
        if let lastUserMsg = messages.last(where: { $0.role == .user }) {
            let classification = IntentClassifier.shared.classify(lastUserMsg.content)
            actionIntents = classification.actionIntents

            let injectedCtx = await AIInstructionManager.shared.resolveContext(
                for: lastUserMsg.content)
            if !injectedCtx.text.isEmpty {
                let ctxMessage = AIChatMessage(role: .system, content: injectedCtx.text)
                // Insert right before the last user message
                updatedMessages.insert(ctxMessage, at: updatedMessages.count - 1)
            }
            allImages.append(contentsOf: injectedCtx.images)
        }

        return try await handler.generateResponse(
            messages: updatedMessages, images: allImages, isStreaming: isStreaming,
            actionIntents: actionIntents)
    }

    /// Checks if the Foundation (Apple Intelligence) language model is available at runtime.
    public func checkFoundationAvailability() -> (isAvailable: Bool, statusMessage: String) {
        #if canImport(FoundationModels)
            if #available(macOS 26.0, *) {
                if SystemLanguageModel.default.isAvailable {
                    return (true, "Apple Intelligence is available.")
                } else {
                    return (false, "Apple Intelligence is not available on this device.")
                }
            }
        #endif
        return (
            false,
            "Foundation (Apple Intelligence) integration is unavailable or not supported on this device."
        )
    }
}
