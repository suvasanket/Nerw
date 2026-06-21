import Foundation
import NerwUtils

public class BYOKModelHandler: AIModelHandler {
    public init() {}

    public func generateResponse(prompt: String, images: [Data], isStreaming: Bool) async throws
        -> AsyncThrowingStream<String, Error>
    {
        let aiConfig = ConfigManager.shared.config.aiConfig

        guard let url = URL(string: aiConfig.byokApiUrl) else {
            Logger.shared.error("BYOKModelHandler: Invalid API URL: \(aiConfig.byokApiUrl)")
            throw NSError(
                domain: "NerwAI", code: 400,
                userInfo: [
                    NSLocalizedDescriptionKey: "Invalid BYOK API URL: \(aiConfig.byokApiUrl)"
                ])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add Bearer Token authorization if key is provided
        if !aiConfig.byokApiKey.isEmpty {
            let maskedKey = aiConfig.byokApiKey.prefix(4) + "..." + aiConfig.byokApiKey.suffix(4)
            Logger.shared.info("BYOKModelHandler: Authorization header set (Key: \(maskedKey))")
            request.setValue("Bearer \(aiConfig.byokApiKey)", forHTTPHeaderField: "Authorization")
        } else {
            Logger.shared.warning("BYOKModelHandler: No API Key provided in config.")
        }

        // Build payload
        var userContent: Any
        if aiConfig.supportsImages && !images.isEmpty {
            var contentArray: [[String: Any]] = []
            contentArray.append(["type": "text", "text": prompt])
            for imageData in images {
                let base64 = imageData.base64EncodedString()
                contentArray.append([
                    "type": "image_url",
                    "image_url": [
                        "url": "data:image/jpeg;base64,\(base64)"
                    ],
                ])
            }
            userContent = contentArray
        } else {
            userContent = prompt
        }

        var messages: [[String: Any]] = []
        if !aiConfig.systemPrompt.isEmpty {
            messages.append(["role": "system", "content": aiConfig.systemPrompt])
        }
        messages.append(["role": "user", "content": userContent])

        var payload: [String: Any] = [
            "model": aiConfig.byokModelName,
            "messages": messages,
            "stream": isStreaming,
            "temperature": aiConfig.temperature,
        ]

        if aiConfig.maxTokens > 0 {
            payload["max_tokens"] = aiConfig.maxTokens
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        Logger.shared.info(
            "BYOKModelHandler: Request payload prepared. Model: \(aiConfig.byokModelName), stream: \(isStreaming)"
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
