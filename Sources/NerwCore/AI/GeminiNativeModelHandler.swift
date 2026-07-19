import Foundation
import NerwUtils

public class GeminiNativeModelHandler: AIModelHandler {
    private let provider: AIProvider

    public init(provider: AIProvider) {
        self.provider = provider
    }

    public func generateResponse(
        messages: [AIChatMessage], images: [Data], isStreaming: Bool,
        actionIntents: Set<ActionIntent>
    )
        async throws
        -> AsyncThrowingStream<String, Error>
    {
        let aiConfig = ConfigManager.shared.config.aiConfig

        let cleanModelName =
            provider.modelName.hasPrefix("models/")
            ? String(provider.modelName.dropFirst(7)) : provider.modelName
        let baseURL = "https://generativelanguage.googleapis.com/v1beta/models/\(cleanModelName)"
        let endpoint = isStreaming ? "streamGenerateContent?alt=sse" : "generateContent"

        guard var urlComponents = URLComponents(string: "\(baseURL):\(endpoint)") else {
            throw NSError(
                domain: "NerwAI", code: 400,
                userInfo: [NSLocalizedDescriptionKey: "Invalid Gemini API URL"])
        }

        if !provider.apiKey.isEmpty {
            var qItems = urlComponents.queryItems ?? []
            qItems.append(URLQueryItem(name: "key", value: provider.apiKey))
            urlComponents.queryItems = qItems
        }

        guard let url = urlComponents.url else {
            throw NSError(
                domain: "NerwAI", code: 400,
                userInfo: [NSLocalizedDescriptionKey: "Failed to construct URL"])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var apiContents: [[String: Any]] = []
        var systemInstruction: [String: Any]? = nil

        let finalSystemPrompt = AIInstructionManager.shared.buildSystemPrompt(
            basePrompt: aiConfig.systemPrompt, actionIntents: actionIntents)

        if !finalSystemPrompt.isEmpty {
            systemInstruction = [
                "parts": [["text": finalSystemPrompt]]
            ]
        }

        for (index, msg) in messages.enumerated() {
            let role = msg.role == .user ? "user" : "model"
            if msg.role == .system {
                continue
            }

            var parts: [[String: Any]] = []
            parts.append(["text": msg.content])

            if msg.role == .user && index == messages.count - 1 && provider.supportsImages
                && !images.isEmpty
            {
                for imageData in images {
                    let base64 = imageData.base64EncodedString()
                    parts.append([
                        "inlineData": [
                            "mimeType": "image/jpeg",
                            "data": base64,
                        ]
                    ])
                }
            }
            apiContents.append(["role": role, "parts": parts])
        }

        var temperature = aiConfig.temperature
        if !actionIntents.isEmpty {
            temperature = 0.0
        }

        var payload: [String: Any] = [
            "contents": apiContents,
            "generationConfig": [
                "temperature": temperature
            ],
        ]

        if aiConfig.maxTokens > 0 {
            var genConfig = payload["generationConfig"] as? [String: Any] ?? [:]
            genConfig["maxOutputTokens"] = aiConfig.maxTokens
            payload["generationConfig"] = genConfig
        }

        if let sysInst = systemInstruction {
            payload["system_instruction"] = sysInst
        }

        if let searchTool = provider.searchToolName, !searchTool.isEmpty,
            searchTool == "google_search"
        {
            payload["tools"] = [
                ["googleSearch": [String: Any]()]
            ]
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let logId = AILogger.shared.startLog(providerName: provider.name, payload: payload)

        return AsyncThrowingStream<String, Error> { continuation in
            let task = Task {
                do {
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)

                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw NSError(
                            domain: "NerwAI", code: 500,
                            userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
                    }

                    guard httpResponse.statusCode == 200 else {
                        var errorBody = ""
                        for try await line in bytes.lines { errorBody += line + "\n" }
                        throw NSError(
                            domain: "NerwAI", code: httpResponse.statusCode,
                            userInfo: [NSLocalizedDescriptionKey: "API Error: \(errorBody)"])
                    }

                    if isStreaming {
                        var fullStreamedResponse = ""
                        for try await line in bytes.lines {
                            if Task.isCancelled { break }
                            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !trimmed.isEmpty else { continue }

                            if trimmed.hasPrefix("data: ") {
                                let dataContent = String(trimmed.dropFirst(6)).trimmingCharacters(
                                    in: .whitespacesAndNewlines)
                                guard let data = dataContent.data(using: .utf8) else { continue }

                                if let chunk = try? JSONDecoder().decode(
                                    GeminiGenerateContentResponse.self, from: data),
                                    let text = chunk.candidates?.first?.content?.parts?.first?.text
                                {
                                    fullStreamedResponse += text
                                    continuation.yield(text)
                                }
                            }
                        }
                        AILogger.shared.finishLog(logId: logId, responseText: fullStreamedResponse)
                    } else {
                        var responseBody = Data()
                        for try await byte in bytes {
                            if Task.isCancelled { break }
                            responseBody.append(byte)
                        }

                        let responseObj = try JSONDecoder().decode(
                            GeminiGenerateContentResponse.self, from: responseBody)
                        if let text = responseObj.candidates?.first?.content?.parts?.first?.text {
                            AILogger.shared.finishLog(logId: logId, responseText: text)
                            continuation.yield(text)
                        } else {
                            throw NSError(
                                domain: "NerwAI", code: 500,
                                userInfo: [NSLocalizedDescriptionKey: "Failed to extract text"])
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { termination in
                if case .cancelled = termination { task.cancel() }
            }
        }
    }
}

private struct GeminiGenerateContentResponse: Decodable {
    struct Candidate: Decodable {
        struct Content: Decodable {
            struct Part: Decodable {
                let text: String?
            }
            let parts: [Part]?
        }
        let content: Content?
    }
    let candidates: [Candidate]?
}
