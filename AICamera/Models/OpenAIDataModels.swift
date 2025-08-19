// FileName: AICamera/Models/OpenAIDataModels.swift
import Foundation

// MARK: - OpenAI Vision Request Model
struct OpenAIVisionRequest: Encodable {
    struct Message: Encodable {
        struct Content: Encodable {
            enum ContentType: String, Encodable {
                case text
                case imageUrl = "image_url"
            }

            let type: ContentType
            let text: String?
            let imageUrl: ImageUrl?
            
            struct ImageUrl: Encodable {
                let url: String
                let detail: String?
            }

            static func text(_ text: String) -> Content {
                return Content(type: .text, text: text, imageUrl: nil)
            }
            
            static func imageUrl(url: String, detail: String = "low") -> Content {
                return Content(type: .imageUrl, text: nil, imageUrl: .init(url: url, detail: detail))
            }
        }
        
        let role: String
        let content: [Content]
    }
    
    let model: String
    let messages: [Message]
    let max_tokens: Int?
    let stream: Bool? // Optional for streaming responses
}

// MARK: - OpenAI Vision Response Model (Non-streaming)
struct OpenAIVisionResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let role: String
            let content: String
        }
        let message: Message
    }
    
    let id: String
    let model: String
    let choices: [Choice]
}

// ✅ 新增: 用于解析 OpenAI 流式响应的模型
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
