import Foundation

enum AIError: LocalizedError {
    case noAPIKey
    case invalidAPIKey
    case overLimit
    case networkError(String)
    case decodingError(String)
    case imageNotSupported

    var errorDescription: String? {
        switch self {
        case .noAPIKey:         return "No API key set. Please add your Anthropic API key in Settings."
        case .invalidAPIKey:    return "Invalid API key. Please check your Anthropic API key in Settings."
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

    // MARK: - Streaming (display-model messages)

    func streamMessage(
        messages: [Message],
        systemPrompt: String = Constants.SystemPrompt.aria,
        plan: SubscriptionPlan,
        tools: [[String: Any]]? = nil
    ) -> AsyncThrowingStream<StreamEvent, Error> {
        streamRaw(apiMessages: toAPIMessages(messages), systemPrompt: systemPrompt, plan: plan, tools: tools)
    }

    // MARK: - Non-streaming for briefings / background tasks

    func sendMessage(
        messages: [Message],
        systemPrompt: String = Constants.SystemPrompt.aria
    ) async throws -> (String, TokenUsageSnapshot) {
        let key = AuthService.shared.apiKey
        guard !key.isEmpty else { throw AIError.noAPIKey }

        let request = try buildRequest(
            key: key, apiMessages: toAPIMessages(messages),
            systemPrompt: systemPrompt, stream: false
        )
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AIError.networkError("Invalid response") }
        if http.statusCode == 401 { throw AIError.invalidAPIKey }
        guard http.statusCode == 200 else {
            throw AIError.networkError("HTTP \(http.statusCode): \(String(data: data, encoding: .utf8) ?? "")")
        }

        struct NonStreamResponse: Decodable {
            let content: [TextContent]
            let usage: UsageInfo
            struct TextContent: Decodable { let text: String? }
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

    // MARK: - Non-streaming with tool support (for tool loop continuations)

    func sendRawWithTools(
        rawMessages: [[String: Any]],
        systemPrompt: String = Constants.SystemPrompt.aria,
        tools: [[String: Any]]? = nil
    ) async throws -> (text: String, toolCalls: [(id: String, name: String, input: [String: Any])], usage: TokenUsageSnapshot) {
        let key = AuthService.shared.apiKey
        guard !key.isEmpty else { throw AIError.noAPIKey }

        let request = try buildRequest(
            key: key, apiMessages: rawMessages,
            systemPrompt: systemPrompt, tools: tools, stream: false
        )
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AIError.networkError("Invalid response") }
        if http.statusCode == 401 { throw AIError.invalidAPIKey }
        guard http.statusCode == 200 else {
            throw AIError.networkError("HTTP \(http.statusCode): \(String(data: data, encoding: .utf8) ?? "")")
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AIError.decodingError("Invalid JSON response")
        }

        let content   = json["content"] as? [[String: Any]] ?? []
        let usageDict = json["usage"]   as? [String: Any]   ?? [:]

        var textParts: [String] = []
        var toolCalls: [(id: String, name: String, input: [String: Any])] = []

        for block in content {
            switch block["type"] as? String {
            case "text":
                if let t = block["text"] as? String { textParts.append(t) }
            case "tool_use":
                let id    = block["id"]    as? String        ?? ""
                let name  = block["name"]  as? String        ?? ""
                let input = block["input"] as? [String: Any] ?? [:]
                if !id.isEmpty && !name.isEmpty { toolCalls.append((id: id, name: name, input: input)) }
            default: break
            }
        }

        let snapshot = TokenUsageSnapshot(
            inputTokens:       usageDict["input_tokens"]                 as? Int ?? 0,
            outputTokens:      usageDict["output_tokens"]                as? Int ?? 0,
            cachedInputTokens: (usageDict["cache_read_input_tokens"]     as? Int ?? 0)
                             + (usageDict["cache_creation_input_tokens"] as? Int ?? 0)
        )
        return (textParts.joined(), toolCalls, snapshot)
    }

    // MARK: - Internal streaming engine

    private func streamRaw(
        apiMessages: [[String: Any]],
        systemPrompt: String,
        plan: SubscriptionPlan,
        tools: [[String: Any]]?
    ) -> AsyncThrowingStream<StreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let key = AuthService.shared.apiKey
                    guard !key.isEmpty else { throw AIError.noAPIKey }

                    let hasImages = apiMessages.contains { msg in
                        (msg["content"] as? [[String: Any]] ?? []).contains { ($0["type"] as? String) == "image" }
                    }
                    if hasImages && !plan.canAnalyzeImages { throw AIError.imageNotSupported }

                    let request = try buildRequest(
                        key: key, apiMessages: apiMessages,
                        systemPrompt: systemPrompt, tools: tools, stream: true
                    )
                    let (asyncBytes, response) = try await session.bytes(for: request)
                    guard let http = response as? HTTPURLResponse else {
                        throw AIError.networkError("Invalid response")
                    }
                    if http.statusCode == 401 { throw AIError.invalidAPIKey }
                    guard http.statusCode == 200 else {
                        throw AIError.networkError("HTTP \(http.statusCode)")
                    }

                    var inputTokens  = 0
                    var outputTokens = 0
                    var cachedTokens = 0
                    var toolBlocks: [Int: (id: String, name: String, json: String)] = [:]

                    for try await line in asyncBytes.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        let jsonStr = String(line.dropFirst(6))
                        guard jsonStr != "[DONE]" else { break }
                        guard let data = jsonStr.data(using: .utf8),
                              let event = try? JSONDecoder().decode(AnthropicStreamEvent.self, from: data)
                        else { continue }

                        let idx = event.index ?? -1

                        switch event.type {
                        case "message_start":
                            if let usage = event.message?.usage {
                                inputTokens  += usage.inputTokens ?? 0
                                cachedTokens += (usage.cacheReadInputTokens ?? 0) + (usage.cacheCreationInputTokens ?? 0)
                            }

                        case "content_block_start":
                            if let cb = event.contentBlock,
                               cb.type == "tool_use",
                               let toolId = cb.id, let toolName = cb.name {
                                toolBlocks[idx] = (id: toolId, name: toolName, json: "")
                            }

                        case "content_block_delta":
                            if let partial = event.delta?.partialJson {
                                toolBlocks[idx]?.json += partial
                            } else if let text = event.delta?.text {
                                continuation.yield(.text(text))
                            }

                        case "content_block_stop":
                            if let block = toolBlocks.removeValue(forKey: idx) {
                                let js = block.json.isEmpty ? "{}" : block.json
                                if let d = js.data(using: .utf8),
                                   let input = try? JSONSerialization.jsonObject(with: d) as? [String: Any] {
                                    continuation.yield(.toolCall(id: block.id, name: block.name, input: input))
                                }
                            }

                        case "message_delta":
                            if let reason = event.delta?.stopReason, reason == "tool_use" {
                                continuation.yield(.stopReason(reason))
                            }
                            if let usage = event.usage {
                                outputTokens += usage.outputTokens ?? 0
                            }

                        case "message_stop": break
                        default: break
                        }
                    }

                    continuation.yield(.usage(input: inputTokens, output: outputTokens, cached: cachedTokens))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - Helpers

    private func toAPIMessages(_ messages: [Message]) -> [[String: Any]] {
        messages.compactMap { msg -> [String: Any]? in
            guard msg.role != .system else { return nil }
            var contentBlocks: [[String: Any]] = []
            if msg.isUser && msg.hasImages {
                for img in msg.images where !img.base64Data.isEmpty {
                    contentBlocks.append([
                        "type": "image",
                        "source": ["type": "base64", "media_type": img.mediaType, "data": img.base64Data]
                    ])
                }
            }
            if !msg.content.isEmpty { contentBlocks.append(["type": "text", "text": msg.content]) }
            guard !contentBlocks.isEmpty else { return nil }
            return ["role": msg.role.rawValue, "content": contentBlocks]
        }
    }

    private func buildRequest(
        key: String,
        apiMessages: [[String: Any]],
        systemPrompt: String,
        tools: [[String: Any]]? = nil,
        stream: Bool = true
    ) throws -> URLRequest {
        var urlRequest = URLRequest(url: URL(string: Constants.API.messagesURL)!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json",        forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(key,                       forHTTPHeaderField: "x-api-key")
        urlRequest.setValue(Constants.API.version,     forHTTPHeaderField: "anthropic-version")
        urlRequest.setValue(Constants.API.betaHeaders, forHTTPHeaderField: "anthropic-beta")

        var body: [String: Any] = [
            "model":      Constants.API.model,
            "max_tokens": Constants.API.maxTokens,
            "system":     [["type": "text", "text": systemPrompt, "cache_control": ["type": "ephemeral"]]],
            "messages":   apiMessages,
            "stream":     stream
        ]
        if let tools = tools, !tools.isEmpty { body["tools"] = tools }
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)
        return urlRequest
    }
}

enum StreamEvent {
    case text(String)
    case toolCall(id: String, name: String, input: [String: Any])
    case stopReason(String)
    case usage(input: Int, output: Int, cached: Int)
}
