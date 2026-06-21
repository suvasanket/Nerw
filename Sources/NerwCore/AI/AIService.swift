import Foundation
import NerwUtils

public protocol AIModelHandler {
    func generateResponse(prompt: String, images: [Data], isStreaming: Bool) async throws
        -> AsyncThrowingStream<String, Error>
}

public class AIService {
    public static let shared = AIService()

    private init() {}

    /// Dynamically routes the generation request to the selected model provider based on configuration.
    public func generateResponse(prompt: String, images: [Data] = [], isStreaming: Bool = true)
        async throws -> AsyncThrowingStream<String, Error>
    {
        Logger.shared.info(
            "AIService: generateResponse called. Prompt length: \(prompt.count), images count: \(images.count), isStreaming: \(isStreaming)"
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

        let handler: AIModelHandler
        if config.selectedModelType == "foundation" {
            Logger.shared.info("AIService: Selected FoundationModelHandler")
            handler = FoundationModelHandler()
        } else {
            Logger.shared.info(
                "AIService: Selected BYOKModelHandler (API URL: \(config.byokApiUrl), Model: \(config.byokModelName))"
            )
            handler = BYOKModelHandler()
        }

        return try await handler.generateResponse(
            prompt: prompt, images: images, isStreaming: isStreaming)
    }

    /// Checks if the Foundation (Apple Intelligence) language model is available at runtime.
    public func checkFoundationAvailability() -> (isAvailable: Bool, statusMessage: String) {
        return (
            false,
            "Foundation (Apple Intelligence) integration is currently paused. Please use the BYOK backend model type."
        )
    }
}
