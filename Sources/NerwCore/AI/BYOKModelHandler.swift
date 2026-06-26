import Foundation
import NerwUtils

public class BYOKModelHandler: AIModelHandler {
    private let provider: AIProvider

    public init(provider: AIProvider) {
        self.provider = provider
    }

    public func generateResponse(messages: [AIChatMessage], images: [Data], isStreaming: Bool)
        async throws
        -> AsyncThrowingStream<String, Error>
    {
        let aiConfig = ConfigManager.shared.config.aiConfig

        guard let url = URL(string: provider.url) else {
            Logger.shared.error("BYOKModelHandler: Invalid API URL: \(provider.url)")
            throw NSError(
                domain: "NerwAI", code: 400,
                userInfo: [
                    NSLocalizedDescriptionKey: "Invalid BYOK API URL: \(provider.url)"
                ])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add Bearer Token authorization if key is provided
        if !provider.apiKey.isEmpty {
            let maskedKey = provider.apiKey.prefix(4) + "..." + provider.apiKey.suffix(4)
            Logger.shared.info("BYOKModelHandler: Authorization header set (Key: \(maskedKey))")
            request.setValue("Bearer \(provider.apiKey)", forHTTPHeaderField: "Authorization")
        } else {
            Logger.shared.warning("BYOKModelHandler: No API Key provided in config.")
        }

        // Not building a single user content here. We will build it inside the messages loop.

        var apiMessages: [[String: Any]] = []
        let finalSystemPrompt = AIInstructionManager.shared.buildSystemPrompt(
            basePrompt: aiConfig.systemPrompt)

        if !finalSystemPrompt.isEmpty {
            apiMessages.append(["role": "system", "content": finalSystemPrompt])
        }

        for (index, msg) in messages.enumerated() {
            if msg.role == .user && index == messages.count - 1 && provider.supportsImages
                && !images.isEmpty
            {
                var contentArray: [[String: Any]] = []
                contentArray.append(["type": "text", "text": msg.content])
                for imageData in images {
                    let base64 = imageData.base64EncodedString()
                    contentArray.append([
                        "type": "image_url",
                        "image_url": [
                            "url": "data:image/jpeg;base64,\(base64)"
                        ],
                    ])
                }
                apiMessages.append(["role": msg.role.rawValue, "content": contentArray])
            } else {
                apiMessages.append(["role": msg.role.rawValue, "content": msg.content])
            }
        }

        var payload: [String: Any] = [
            "model": provider.modelName,
            "messages": apiMessages,
            "stream": isStreaming,
            "temperature": aiConfig.temperature,
        ]

        if aiConfig.maxTokens > 0 {
            payload["max_tokens"] = aiConfig.maxTokens
        }

        if let searchTool = provider.searchToolName, !searchTool.isEmpty {
            payload["tools"] = [["type": searchTool]]
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let logId = AILogger.shared.startLog(providerName: provider.name, payload: payload)

        Logger.shared.info(
            "BYOKModelHandler: Request payload prepared. Model: \(provider.modelName), stream: \(isStreaming)"
        )

        return AsyncThrowingStream<String, Error> {
            (continuation: AsyncThrowingStream<String, Error>.Continuation) in
            let task = Task {
                do {
                    Logger.shared.info("BYOKModelHandler: Starting URLSession request to \(url)...")
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)

                    guard let httpResponse = response as? HTTPURLResponse else {
                        Logger.shared.error(
                            "BYOKModelHandler: Invalid response type from URLSession.")
                        throw NSError(
                            domain: "NerwAI", code: 500,
                            userInfo: [
                                NSLocalizedDescriptionKey: "Invalid response from API endpoint"
                            ])
                    }

                    Logger.shared.info(
                        "BYOKModelHandler: HTTP Status Code = \(httpResponse.statusCode)")

                    guard httpResponse.statusCode == 200 else {
                        // Attempt to read the error body
                        var errorBody = ""
                        for try await line in bytes.lines {
                            errorBody += line + "\n"
                        }
                        let errorMsg =
                            errorBody.isEmpty
                            ? "HTTP error status \(httpResponse.statusCode)" : errorBody
                        Logger.shared.error("BYOKModelHandler: API Error body: \(errorMsg)")
                        throw NSError(
                            domain: "NerwAI", code: httpResponse.statusCode,
                            userInfo: [NSLocalizedDescriptionKey: "API Error: \(errorMsg)"])
                    }

                    if isStreaming {
                        Logger.shared.info("BYOKModelHandler: Starting stream consumption...")
                        var chunkCount = 0
                        var fullStreamedResponse = ""
                        for try await line in bytes.lines {
                            if Task.isCancelled {
                                Logger.shared.info(
                                    "BYOKModelHandler: Stream task cancelled by client.")
                                break
                            }

                            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !trimmed.isEmpty else { continue }

                            if trimmed.hasPrefix("data: ") {
                                let dataContent = String(trimmed.dropFirst(6)).trimmingCharacters(
                                    in: .whitespacesAndNewlines)

                                if dataContent == "[DONE]" {
                                    Logger.shared.info(
                                        "BYOKModelHandler: Stream [DONE] marker received.")
                                    break
                                }

                                guard let data = dataContent.data(using: .utf8) else { continue }
                                if let chunk = try? JSONDecoder().decode(
                                    ChatCompletionChunk.self, from: data)
                                {
                                    if let delta = chunk.choices.first?.delta.content {
                                        fullStreamedResponse += delta
                                        chunkCount += 1
                                        if chunkCount % 10 == 0 || chunkCount < 5 {
                                            Logger.shared.info(
                                                "BYOKModelHandler: Received chunk #\(chunkCount): '\(delta.replacingOccurrences(of: "\n", with: "\\n"))'"
                                            )
                                        }
                                        continuation.yield(delta)
                                    }
                                } else {
                                    Logger.shared.warning(
                                        "BYOKModelHandler: Failed to decode stream line: \(trimmed)"
                                    )
                                }
                            } else {
                                Logger.shared.info(
                                    "BYOKModelHandler: Non-data stream line received: \(trimmed)")
                            }
                        }
                        AILogger.shared.finishLog(logId: logId, responseText: fullStreamedResponse)
                        Logger.shared.info(
                            "BYOKModelHandler: Stream finished successfully. Total chunks: \(chunkCount)"
                        )
                    } else {
                        var responseBody = Data()
                        for try await byte in bytes {
                            if Task.isCancelled {
                                Logger.shared.info(
                                    "BYOKModelHandler: Non-stream task cancelled by client.")
                                break
                            }
                            responseBody.append(byte)
                        }

                        let responseObj = try JSONDecoder().decode(
                            ChatCompletionResponse.self, from: responseBody)
                        if let fullText = responseObj.choices.first?.message.content {
                            AILogger.shared.finishLog(logId: logId, responseText: fullText)
                            Logger.shared.info(
                                "BYOKModelHandler: Received full non-stream response length: \(fullText.count)"
                            )
                            continuation.yield(fullText)
                        } else {
                            Logger.shared.error(
                                "BYOKModelHandler: Failed to extract text from API response.")
                            throw NSError(
                                domain: "NerwAI", code: 500,
                                userInfo: [
                                    NSLocalizedDescriptionKey:
                                        "Failed to extract text from API response"
                                ])
                        }
                    }
                    continuation.finish()
                } catch {
                    Logger.shared.error(
                        "BYOKModelHandler: Caught exception: \(error.localizedDescription)")
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { termination in
                if case .cancelled = termination {
                    Logger.shared.info("BYOKModelHandler: Continuation terminated (cancelled).")
                    task.cancel()
                }
            }
        }
    }
}

// MARK: - Decodable Structs for OpenAI format

private struct ChatCompletionChunk: Decodable {
    struct Choice: Decodable {
        struct Delta: Decodable {
            let content: String?
        }
        let delta: Delta
    }
    let choices: [Choice]
}

private struct ChatCompletionResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String?
        }
        let message: Message
    }
    let choices: [Choice]
}
