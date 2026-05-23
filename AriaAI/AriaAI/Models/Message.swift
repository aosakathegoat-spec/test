import Foundation
import UIKit

enum MessageRole: String, Codable {
    case user, assistant, system
}

struct AttachedImage: Codable, Identifiable {
    let id: UUID
    let base64Data: String
    let mediaType: String

    init(image: UIImage) {
        self.id = UUID()
        self.mediaType = "image/jpeg"
        self.base64Data = image.base64EncodedString() ?? ""
    }
}

struct Message: Identifiable, Codable {
    let id: UUID
    var role: MessageRole
    var content: String
    var images: [AttachedImage]
    var timestamp: Date
    var isStreaming: Bool
    var tokensUsed: TokenUsageSnapshot?

    init(
        id: UUID = UUID(),
        role: MessageRole,
        content: String,
        images: [AttachedImage] = [],
        isStreaming: Bool = false
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.images = images
        self.timestamp = Date()
        self.isStreaming = isStreaming
    }

    var isUser: Bool { role == .user }
    var isAssistant: Bool { role == .assistant }
    var hasImages: Bool { !images.isEmpty }
}

struct TokenUsageSnapshot: Codable {
    var inputTokens: Int
    var outputTokens: Int
    var cachedInputTokens: Int

    var totalTokens: Int { inputTokens + outputTokens }
    var totalCost: Double {
        Double(inputTokens) * Constants.TokenCost.inputPerToken +
        Double(outputTokens) * Constants.TokenCost.outputPerToken +
        Double(cachedInputTokens) * Constants.TokenCost.cachedPerToken
    }
}

struct AnthropicStreamEvent: Decodable {
    let type: String
    let index: Int?
    let delta: Delta?
    let usage: UsageResponse?
    let message: MessageStart?
    let contentBlock: ContentBlockInfo?

    struct Delta: Decodable {
        let type: String?
        let text: String?
        let partialJson: String?
        let stopReason: String?
        enum CodingKeys: String, CodingKey {
            case type, text
            case partialJson = "partial_json"
            case stopReason  = "stop_reason"
        }
    }
    struct ContentBlockInfo: Decodable {
        let type: String
        let id: String?
        let name: String?
    }
    struct UsageResponse: Decodable {
        let inputTokens: Int?
        let outputTokens: Int?
        let cacheReadInputTokens: Int?
        let cacheCreationInputTokens: Int?
        enum CodingKeys: String, CodingKey {
            case inputTokens = "input_tokens"
            case outputTokens = "output_tokens"
            case cacheReadInputTokens = "cache_read_input_tokens"
            case cacheCreationInputTokens = "cache_creation_input_tokens"
        }
    }
    struct MessageStart: Decodable {
        let usage: UsageResponse?
    }
    enum CodingKeys: String, CodingKey {
        case type, index, delta, usage, message
        case contentBlock = "content_block"
    }
}
