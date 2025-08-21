// FileName: AICamera/Models/OpenAIDataModels.swift
import Foundation

// MARK: - OpenAI Vision Request Model
struct OpenAIVisionRequest: Encodable {
    
    struct ContentPart: Encodable {
        let type: String
        let text: String?
        let imageUrl: ImageUrl?

        enum CodingKeys: String, CodingKey {
            case type
            case text
            case imageUrl = "image_url"
        }
        
        static func text(_ text: String) -> ContentPart {
            return ContentPart(type: "text", text: text, imageUrl: nil)
        }
        
        static func imageUrl(url: String, detail: String = "auto") -> ContentPart {
            return ContentPart(type: "image_url", text: nil, imageUrl: .init(url: url, detail: detail))
        }
    }

    struct ImageUrl: Encodable {
        let url: String
        let detail: String?
    }
    
    struct Message: Encodable {
        let role: String
        let content: [ContentPart]
    }
    
    let model: String
    let messages: [Message]
    let max_completion_tokens: Int?
    let stream: Bool?
    
    // ✅ FIX: Changed the coding key from "max_tokens" back to "max_completion_tokens"
    // to match the specific model's API requirements.
    enum CodingKeys: String, CodingKey {
        case model, messages, stream
        case max_completion_tokens
    }
}

// MARK: - OpenAI Vision Stream Response Models
struct OpenAIStreamResponse: Decodable {
    let id: String
    let choices: [OpenAIStreamChoice]
}

struct OpenAIStreamChoice: Decodable {
    struct Delta: Decodable {
        let content: String?
        let role: String?
    }
    let delta: Delta
}


// MARK: - OpenAI Image Generation Response Model
struct OpenAIImageResponse: Decodable {
    struct ImageData: Decodable {
        let b64_json: String?
        let url: String?
    }
    let created: Int
    let data: [ImageData]
}


// MARK: - OpenAI Error Response
struct OpenAIErrorResponse: Decodable {
    struct ErrorDetail: Decodable {
        let message: String
        let type: String?
        let code: String?
    }
    let error: ErrorDetail
}
