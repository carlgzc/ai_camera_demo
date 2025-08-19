// FileName: AICamera/Services/DoubaoService.swift
import SwiftUI

protocol DoubaoServiceProtocol: AIService {
    func createVideoGenerationTask(from data: Data, prompt: String) async throws -> String
    func checkVideoTaskStatus(taskID: String) async throws -> DoubaoVideoPollResponse
}

@MainActor
class DoubaoService: DoubaoServiceProtocol {
    private let settings: AppSettings
    private let baseURL = "https://ark.cn-beijing.volces.com/api/v3"
    private let session = URLSession.shared

    init(settings: AppSettings) {
        self.settings = settings
    }
    
    private func checkAPIKey() throws {
        if settings.apiKey.isEmpty {
            throw NSError(domain: "DoubaoService", code: -1001, userInfo: [NSLocalizedDescriptionKey: "API Key 为空，请在App内设置。"])
        }
    }
    
    // ✅ FIX: 此处无需修改，因为它现在正确地满足了协议的 nonisolated 要求
    nonisolated func getVLMAnalysis(from imagesData: [Data], prompt: String) -> AsyncThrowingStream<AIChunk, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    // 由于此方法 nonisolated，访问 settings 需要 actor-hopping
                    let apiKey = await settings.apiKey
                    let thinkingEnabled = await settings.isDeepThinkingEnabled
                    let vlmModelID = await settings.vlmModelID
                    
                    if apiKey.isEmpty {
                        throw NSError(domain: "DoubaoService", code: -1001, userInfo: [NSLocalizedDescriptionKey: "API Key 为空，请在App内设置。"])
                    }

                    var req = URLRequest(url: .init(string: "\(baseURL)/chat/completions")!)
                    req.httpMethod = "POST"
                    req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    
                    let thinkingType = thinkingEnabled ? "enabled" : "disabled"
                    let thinkingPayload = DoubaoVLMStreamRequest.Thinking(type: thinkingType)
                    
                    var content: [DoubaoVLMStreamRequest.Message.Content] = [.text(prompt)]
                    for data in imagesData {
                        content.append(.imageUrl("data:image/jpeg;base64,\(data.base64EncodedString())"))
                    }

                    let requestBody = DoubaoVLMStreamRequest(
                        model: vlmModelID,
                        messages: [.init(role: "user", content: content)],
                        stream: true,
                        thinking: thinkingPayload
                    )
                    
                    req.httpBody = try JSONEncoder().encode(requestBody)
                    
                    let (bytes, res) = try await URLSession.shared.bytes(for: req)
                    
                    guard let httpRes = res as? HTTPURLResponse, (200...299).contains(httpRes.statusCode) else {
                        let errorResponse = String(decoding: try await bytes.reduce(into: Data()) { $0.append($1) }, as: UTF8.self)
                        throw NSError(domain: "DoubaoService", code: (res as? HTTPURLResponse)?.statusCode ?? 500, userInfo: [NSLocalizedDescriptionKey: "无效的服务器响应。详情: \(errorResponse)"])
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
                                let streamRes = try JSONDecoder().decode(DoubaoStreamVLMResponse.self, from: jsonData)
                                guard let delta = streamRes.choices.first?.delta else { continue }
                                
                                if let reasoningChunk = delta.reasoning_content, !reasoningChunk.isEmpty {
                                    continuation.yield(.reasoning(reasoningChunk))
                                }
                                
                                if let contentChunk = delta.content, !contentChunk.isEmpty {
                                    continuation.yield(.content(contentChunk))
                                }
                                
                            } catch {
                                continuation.finish(throwing: error)
                                return
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
        let (apiKey, modelID) = await (settings.apiKey, settings.imageEditModelID)
        if apiKey.isEmpty { throw NSError(domain: "DoubaoService", code: -1001) }
        
        var req = URLRequest(url: .init(string: "\(baseURL)/images/generations")!)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        req.httpBody = try JSONEncoder().encode(DoubaoImageEditRequest(model: modelID, prompt: prompt, image: "data:image/jpeg;base64,\(data.base64EncodedString())", response_format: "url"))
        let (resData, _) = try await performRequest(req)
        let result = try JSONDecoder().decode(DoubaoImageEditResponse.self, from: resData)
        guard let urlStr = result.data.first?.url, let url = URL(string: urlStr) else {
            throw NSError(domain: "DoubaoService", code: 0, userInfo: [NSLocalizedDescriptionKey: "API未返回有效的图片URL"])
        }
        let (imageData, _) = try await URLSession.shared.data(from: url)
        return imageData
    }

    nonisolated func generateVideo(from data: Data, prompt: String) async throws -> Data {
        let genTaskID = try await createVideoGenerationTask(from: data, prompt: prompt)
        
        for _ in 0..<60 {
            let statusResponse = try await checkVideoTaskStatus(taskID: genTaskID)
            switch statusResponse.status {
            case "succeeded":
                if let urlStr = statusResponse.content?.video_url, let url = URL(string: urlStr) {
                    let (videoData, _) = try await URLSession.shared.data(from: url)
                    return videoData
                } else { throw NSError(domain: "DoubaoService", code: 0, userInfo: [NSLocalizedDescriptionKey: "视频任务成功但未返回URL。"]) }
            case "failed":
                let message = statusResponse.error?.message ?? "未知错误"
                throw NSError(domain: "DoubaoService", code: 0, userInfo: [NSLocalizedDescriptionKey: "视频生成失败: \(message)"])
            case "processing", "pending":
                try await Task.sleep(for: .seconds(5))
            default:
                throw NSError(domain: "DoubaoService", code: 0, userInfo: [NSLocalizedDescriptionKey: "未知的视频任务状态: \(statusResponse.status)"])
            }
        }
        
        throw NSError(domain: "DoubaoService", code: 0, userInfo: [NSLocalizedDescriptionKey: "视频生成超时。"])
    }
    
    func createVideoGenerationTask(from data: Data, prompt: String) async throws -> String {
        try checkAPIKey()
        let finalPrompt = "\(prompt) --dur 10 --resolution 720p --camerafixed false"
        var req = makeRequest(url: .init(string: "\(baseURL)/contents/generations/tasks")!)
        req.httpBody = try JSONEncoder().encode(DoubaoVideoTaskRequest(model: settings.videoGenModelID, content: [.text(finalPrompt), .imageUrl("data:image/jpeg;base64,\(data.base64EncodedString())")]))
        let (resData, _) = try await performRequest(req)
        return try JSONDecoder().decode(DoubaoVideoTaskResponse.self, from: resData).id
    }
    
    func checkVideoTaskStatus(taskID: String) async throws -> DoubaoVideoPollResponse {
        try checkAPIKey()
        let req = makeRequest(url: .init(string: "\(baseURL)/contents/generations/tasks/\(taskID)")!, method: "GET")
        let (data, _) = try await performRequest(req)
        return try JSONDecoder().decode(DoubaoVideoPollResponse.self, from: data)
    }
    
    private func makeRequest(url: URL, method: String = "POST") -> URLRequest {
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("Bearer \(settings.apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return req
    }
    
    private nonisolated func performRequest(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, res) = try await URLSession.shared.data(for: request)
        guard let httpRes = res as? HTTPURLResponse else {
            throw NSError(domain: "DoubaoService", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的服务器响应"])
        }
        guard (200...299).contains(httpRes.statusCode) else {
            let errDetail = try? JSONDecoder().decode(DoubaoErrorDetail.self, from: data)
            throw NSError(domain: "DoubaoService", code: httpRes.statusCode, userInfo: [NSLocalizedDescriptionKey: errDetail?.message ?? "HTTP Error \(httpRes.statusCode)"])
        }
        return (data, httpRes)
    }
}
