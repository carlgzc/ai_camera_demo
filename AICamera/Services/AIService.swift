// FileName: AICamera/Services/AIService.swift
import Foundation

enum AIChunk {
    case reasoning(String)
    case content(String)
}

// ✅ FIX: Moved this extension here from CameraViewModel.
// This makes the '.content' helper property available project-wide,
// fixing the "cannot be used as an instance member" error.
extension AIChunk {
    var content: String? {
        if case .content(let text) = self {
            return text
        }
        return nil
    }
}

protocol AIService {
    nonisolated func getVLMAnalysis(from imagesData: [Data], prompt: String) -> AsyncThrowingStream<AIChunk, Error>
    nonisolated func generateEditedImage(from data: Data, prompt: String) async throws -> Data
    nonisolated func generateVideo(from data: Data, prompt: String) async throws -> Data
}
