// FileName: AICamera/Models/DoubaoDataModels.swift

struct DoubaoErrorDetail: Decodable {
    let message: String
    let type: String?
}

// MARK: VLM (视觉语言模型) 相关模型
struct DoubaoVLMStreamRequest: Encodable {
    // 定义 thinking 参数的结构
    struct Thinking: Encodable {
        let type: String // "enabled" 或 "disabled"
    }
    
    struct Message: Encodable {
        enum Content: Encodable {
            case text(String)
            case imageUrl(String)
            
            func encode(to encoder: Encoder) throws {
                var c = encoder.container(keyedBy: CodingKeys.self)
                switch self {
                case .text(let t):
                    try c.encode("text", forKey: .type)
                    try c.encode(t, forKey: .text)
                case .imageUrl(let u):
                    try c.encode("image_url", forKey: .type)
                    try c.encode(["url": u], forKey: .imageUrl)
                }
            }
            enum CodingKeys: String, CodingKey { case type, text, imageUrl = "image_url" }
        }
        let role: String
        let content: [Content]
    }
    
    let model: String
    let messages: [Message]
    let stream: Bool
    // 将 thinking 作为可选参数添加到请求体中
    let thinking: Thinking?
}

struct DoubaoStreamVLMResponse: Decodable {
    struct Choice: Decodable {
        struct Delta: Decodable {
            let content: String?
            let reasoning_content: String?
            let role: String?
        }
        let delta: Delta
    }
    let choices: [Choice]
}

// MARK: 图像编辑相关模型
struct DoubaoImageEditRequest: Encodable {
    let model: String
    let prompt: String
    let image: String
    let response_format: String
}

struct DoubaoImageEditResponse: Decodable {
    struct ImageData: Decodable { let url: String }
    let data: [ImageData]
}

// MARK: 视频生成相关模型
struct DoubaoVideoTaskRequest: Encodable {
    enum Content: Encodable {
        case text(String)
        case imageUrl(String)
        
        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .text(let t):
                try c.encode("text", forKey: .type)
                try c.encode(t, forKey: .text)
            case .imageUrl(let u):
                try c.encode("image_url", forKey: .type)
                try c.encode(["url": u], forKey: .imageUrl)
            }
        }
        enum CodingKeys: String, CodingKey { case type, text, imageUrl = "image_url" }
    }
    let model: String
    let content: [Content]
}

struct DoubaoVideoTaskResponse: Decodable {
    let id: String
}

struct DoubaoVideoPollResponse: Decodable {
    let id: String
    let status: String
    let error: DoubaoErrorDetail?
    let content: VideoContent?
    
    struct VideoContent: Decodable {
        let video_url: String
    }
}
