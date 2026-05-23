import Foundation

enum AIError: LocalizedError {
    case noAPIKey
    case overLimit
    case networkError(String)
    case decodingError(String)
    case imageNotSupported

    var errorDescription: String? {
        switch self {
        case .noAPIKey:         return "No API key set. Please add your Anthropic API key in Settings."
        case .overLimit:        return "You've reached your daily token limit. Upgrade your plan or wait until 8 AM PST for a reset."
        case .networkError(let m): return "Network error: \(m)"
        case .decodingError(let m): return "Response error: \(m)"
        case .imageNotSupported: return "Image analysis requires a Pro or Ultra plan."
        }
    }
}

actor AIService {
    static let shared = AIService()

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120
        config.timeoutIntervalForResource = 300
        return URLSession(configuration: config)
    }()

    private init() {}

    func streamMessage(
        messages: [Message],
        systemPrompt: String = Constants.SystemPrompt.aria,
        plan: SubscriptionPlan
    ) -> AsyncThrowingStream<StreamEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let key = AuthService.shared.apiKey
                    guard !key.isEmpty else { throw AIError.noAPIKey }
                    let hasImages = messages.contains { $0.hasImages }
                    if hasImages && !plan.canAnalyzeImages { throw AIError.imageNotSupported }

                    let request = try buildRequest(
                        messages: messages,
                        systemPrompt: systemPrompt
                    )

                    let (asyncBytes, response) = try await session.bytes(for: request)

                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw AIError.networkError("Invalid response")
                    }

                    if httpResponse.statusCode == 401 { throw AIError.noAPIKey }
                    if httpResponse.statusCode != 200 {
                        throw AIError.networkError("HTTP \(httpResponse.statusCode)")
                    }

                    var inputTokens  = 0
                    var outputTokens = 0
                    var cachedTokens = 0

                    for try await line in asyncBytes.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        let jsonStr = String(line.dropFirst(6))
                        guard jsonStr != "[DONE]" else { break }

                        guard let data = jsonStr.data(using: .utf8),
                              let event = try? JSONDecoder().decode(AnthropicStreamEvent.self, from: data)
                        else { continue }

                        switch event.type {
                        case "message_start":
                            if let usage = event.message?.usage {
                                inputTokens  += usage.inputTokens ?? 0
                                cachedTokens += (usage.cacheReadInputTokens ?? 0) + (usage.cacheCreationInputTokens ?? 0)
                            }
                        case "content_block_delta":
                            if let text = event.delta?.text {
                                continuation.yield(.text(text))
                            }
                        case "message_delta":
                            if let usage = event.usage {
                                outputTokens += usage.outputTokens ?? 0
                            }
                        case "message_stop":
                            break
                        default:
                            break
                        }
                    }

                    continuation.yield(.usage(input: inputTokens, output: outputTokens, cached: cachedTokens))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // Non-streaming for briefings and background tasks
    func sendMessage(
        messages: [Message],
        systemPrompt: String = Constants.SystemPrompt.aria
    ) async throws -> (String, TokenUsageSnapshot) {
        let key = AuthService.shared.apiKey
        guard !key.isEmpty else { throw AIError.noAPIKey }

        let request = try buildRequest(
            messages: messages, systemPrompt: systemPrompt, stream: false
        )
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AIError.networkError("Invalid response") }
        if http.statusCode == 401 { throw AIError.noAPIKey }
        guard http.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw AIError.networkError("HTTP \(http.statusCode): \(body)")
        }

        struct NonStreamResponse: Decodable {
            let content: [TextContent]
            let usage: UsageInfo
            struct TextContent: Decodable {
                let text: String?
            }
            struct UsageInfo: Decodable {
                let inputTokens: Int
                let outputTokens: Int
                let cacheReadInputTokens: Int?
                let cacheCreationInputTokens: Int?
                enum CodingKeys: String, CodingKey {
                    case inputTokens = "input_tokens"
                    case outputTokens = "output_tokens"
                    case cacheReadInputTokens = "cache_read_input_tokens"
                    case cacheCreationInputTokens = "cache_creation_input_tokens"
                }
            }
        }

        let decoded = try JSONDecoder().decode(NonStreamResponse.self, from: data)
        let text = decoded.content.compactMap { $0.text }.joined()
        let snapshot = TokenUsageSnapshot(
            inputTokens: decoded.usage.inputTokens,
            outputTokens: decoded.usage.outputTokens,
            cachedInputTokens: (decoded.usage.cacheReadInputTokens ?? 0) + (decoded.usage.cacheCreationInputTokens ?? 0)
        )
        return (text, snapshot)
    }

    private func buildRequest(
        messages: [Message],
        systemPrompt: String,
        stream: Bool = true
    ) throws -> URLRequest {
        var urlRequest = URLRequest(url: URL(string: Constants.API.messagesURL)!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json",        forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(AuthService.shared.apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue(Constants.API.version,    forHTTPHeaderField: "anthropic-version")
        urlRequest.setValue(Constants.API.betaHeaders, forHTTPHeaderField: "anthropic-beta")

        let systemBlocks: [[String: Any]] = [
            [
                "type": "text",
                "text": systemPrompt,
                "cache_control": ["type": "ephemeral"]
            ]
        ]

        var apiMessages: [[String: Any]] = []
        for (i, msg) in messages.enumerated() {
            guard msg.role != .system else { continue }
            var contentBlocks: [[String: Any]] = []

            // Attach stored images for any user message that has them
            if msg.isUser && msg.hasImages {
                for img in msg.images {
                    contentBlocks.append([
                        "type": "image",
                        "source": [
                            "type": "base64",
                            "media_type": img.mediaType,
                            "data": img.base64Data
                        ]
                    ])
                }
            }
            contentBlocks.append(["type": "text", "text": msg.content])

            apiMessages.append([
                "role": msg.role.rawValue,
                "content": contentBlocks
            ])
        }

        let body: [String: Any] = [
            "model": Constants.API.model,
            "max_tokens": Constants.API.maxTokens,
            "system": systemBlocks,
            "messages": apiMessages,
            "stream": stream
        ]

        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)
        return urlRequest
    }
}

enum StreamEvent {
    case text(String)
    case usage(input: Int, output: Int, cached: Int)
}
