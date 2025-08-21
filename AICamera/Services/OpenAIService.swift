// FileName: AICamera/Services/OpenAIService.swift
import SwiftUI

@MainActor
class OpenAIService: AIService {
    private let settings: AppSettings
    private let baseURL = "https://api.openai.com/v1"
    private let session = URLSession.shared

    init(settings: AppSettings) {
        self.settings = settings
    }

    nonisolated func getVLMAnalysis(from imagesData: [Data], prompt: String) -> AsyncThrowingStream<AIChunk, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let apiKey = await settings.openAIAPIKey
                    let modelID = await settings.openAIVLMModelID
                    
                    if apiKey.isEmpty {
                        throw NSError(domain: "OpenAIService", code: -1002, userInfo: [NSLocalizedDescriptionKey: "OpenAI API Key 为空，请在App内设置。"])
                    }
                    
                    // ✅ 修改: 使用新的、正确的 ContentPart 模型来构建 content 数组
                    var content: [OpenAIVisionRequest.ContentPart] = [.text(prompt)]
                    for data in imagesData {
                        let base64Image = "data:image/jpeg;base64,\(data.base64EncodedString())"
                        content.append(.imageUrl(url: base64Image, detail: "auto"))
                    }
                    
                    let requestBody = OpenAIVisionRequest(
                        model: modelID,
                        messages: [.init(role: "user", content: content)],
                        max_completion_tokens: 4096,
                        stream: true
                    )
                    
                    var req = URLRequest(url: .init(string: "\(baseURL)/chat/completions")!)
                    req.httpMethod = "POST"
                    req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    req.httpBody = try! JSONEncoder().encode(requestBody)

                    let (bytes, res) = try await session.bytes(for: req)

                    guard let httpRes = res as? HTTPURLResponse, (200...299).contains(httpRes.statusCode) else {
                        let errorResponse = String(decoding: try await bytes.reduce(into: Data()) { $0.append($1) }, as: UTF8.self)
                        throw NSError(domain: "OpenAIService", code: (res as? HTTPURLResponse)?.statusCode ?? 500, userInfo: [NSLocalizedDescriptionKey: "无效的服务器响应。详情: \(errorResponse)"])
                    }
                    
                    for try await line in bytes.lines {
                         if Task.isCancelled {
                            continuation.finish(throwing: CancellationError())
                            return
                        }
                        
                        if line.hasPrefix("data: ") {
                            let contentStr = String(line.dropFirst(6))
                            if contentStr == "[DONE]" {
                                continuation.finish()
                                return
                            }
                            
                            guard let jsonData = contentStr.data(using: .utf8) else { continue }
                            
                            do {
                                let streamRes = try JSONDecoder().decode(OpenAIStreamResponse.self, from: jsonData)
                                if let contentChunk = streamRes.choices.first?.delta.content {
                                    continuation.yield(.content(contentChunk))
                                }
                            } catch {
                                print("🔴 [OpenAIService] Stream decoding error: \(error)")
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    nonisolated func generateEditedImage(from data: Data, prompt: String) async throws -> Data {
        let apiKey = await settings.openAIAPIKey
        let modelID = await settings.openAIImageModelID

        if apiKey.isEmpty {
            throw NSError(domain: "OpenAIService", code: -1002, userInfo: [NSLocalizedDescriptionKey: "OpenAI API Key 为空，请在App内设置。"])
        }

        let requestBody: [String: Any] = [
            "model": modelID,
            "prompt": prompt,
            "n": 1,
            "size": "1024x1024",
            "response_format": "b64_json"
        ]
        
        var req = URLRequest(url: .init(string: "\(baseURL)/images/generations")!)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try! JSONSerialization.data(withJSONObject: requestBody)
        
        let (resData, _) = try await performRequest(req)
        
        let json = try JSONDecoder().decode(OpenAIImageResponse.self, from: resData)
        if let b64String = json.data.first?.b64_json, let imageData = Data(base64Encoded: b64String) {
            return imageData
        } else {
            throw NSError(domain: "OpenAIService", code: 0, userInfo: [NSLocalizedDescriptionKey: "未能从OpenAI响应中解析图片数据。"])
        }
    }

    nonisolated func generateVideo(from data: Data, prompt: String) async throws -> Data {
        let apiKey = await settings.openAIAPIKey
        if apiKey.isEmpty {
            throw NSError(domain: "OpenAIService", code: -1002, userInfo: [NSLocalizedDescriptionKey: "OpenAI API Key 为空，请在App内设置。"])
        }
        try await Task.sleep(for: .seconds(2))
        throw NSError(domain: "OpenAIService", code: -999, userInfo: [NSLocalizedDescriptionKey: "OpenAI Sora API 当前不可用。此功能尚无法实现。"])
    }
    
    private nonisolated func performRequest(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, res) = try await URLSession.shared.data(for: request)
        guard let httpRes = res as? HTTPURLResponse else {
            throw NSError(domain: "OpenAIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的服务器响应"])
        }
        guard (200...299).contains(httpRes.statusCode) else {
            let errorDetail = try? JSONDecoder().decode(OpenAIErrorResponse.self, from: data)
            throw NSError(domain: "OpenAIService", code: httpRes.statusCode, userInfo: [NSLocalizedDescriptionKey: errorDetail?.error.message ?? "HTTP Error \(httpRes.statusCode)"])
        }
        return (data, httpRes)
    }
}
