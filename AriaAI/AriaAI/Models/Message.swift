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

// Anthropic API request/response models
struct AnthropicRequest: Codable {
    let model: String
    let maxTokens: Int
    let system: [SystemBlock]
    let messages: [AnthropicMessage]
    let stream: Bool

    enum CodingKeys: String, CodingKey {
        case model, messages, stream
        case maxTokens = "max_tokens"
        case system
    }
}

struct SystemBlock: Codable {
    let type: String
    let text: String
    let cacheControl: CacheControl?

    enum CodingKeys: String, CodingKey {
        case type, text
        case cacheControl = "cache_control"
    }

    struct CacheControl: Codable {
        let type: String
    }
}

struct AnthropicMessage: Codable {
    let role: String
    var content: [ContentBlock]
}

enum ContentBlock: Codable {
    case text(String)
    case image(mediaType: String, data: String)

    enum CodingKeys: String, CodingKey {
        case type, text, source
    }

    struct ImageSource: Codable {
        let type: String
        let mediaType: String
        let data: String

        enum CodingKeys: String, CodingKey {
            case type
            case mediaType = "media_type"
            case data
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let t):
            try container.encode("text", forKey: .type)
            try container.encode(t, forKey: .text)
        case .image(let mediaType, let data):
            try container.encode("image", forKey: .type)
            let source = ImageSource(type: "base64", mediaType: mediaType, data: data)
            try container.encode(source, forKey: .source)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        if type == "text" {
            let text = try container.decode(String.self, forKey: .text)
            self = .text(text)
        } else {
            let source = try container.decode(ImageSource.self, forKey: .source)
            self = .image(mediaType: source.mediaType, data: source.data)
        }
    }
}

struct AnthropicStreamEvent: Decodable {
    let type: String
    let delta: Delta?
    let usage: UsageResponse?
    let message: MessageStart?

    struct Delta: Decodable {
        let type: String?
        let text: String?
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
}
