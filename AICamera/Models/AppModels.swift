// FileName: AICamera/Models/AppModels.swift
import SwiftUI
import AVFoundation
import SwiftData

// ✅ FIX: Moved FileManagerHelper to a top-level scope here.
// This makes it accessible across the entire application, resolving the scope error.
struct FileManagerHelper {
    static func getDocumentsDirectory() -> URL {
        // Returns the URL for the app's documents directory, where user data is stored.
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    static func save(data: Data, to fileName: String) {
        let url = getDocumentsDirectory().appendingPathComponent(fileName)
        do {
            // Writes data to a file atomically and with complete file protection.
            try data.write(to: url, options: [.atomicWrite, .completeFileProtection])
        } catch {
            print("🔴 [FileManager] Failed to save data to \(fileName): \(error)")
        }
    }

    static func read(from fileName: String) -> Data? {
        let url = getDocumentsDirectory().appendingPathComponent(fileName)
        // Reads data from a file at the given URL.
        return try? Data(contentsOf: url)
    }

    static func getURL(for fileName: String) -> URL {
        // Returns the full URL for a given file name in the documents directory.
        return getDocumentsDirectory().appendingPathComponent(fileName)
    }

    static func delete(fileName: String?) {
        guard let fileName = fileName else { return }
        let url = getDocumentsDirectory().appendingPathComponent(fileName)
        // Checks if the file exists before attempting to delete it.
        if FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
        }
    }
}


@Model
final class CaptureTask: Identifiable {
    @Attribute(.unique) var id: UUID
    var creationDate: Date
    
    let originalImageFileName: String
    var videoFileName: String?
    var editedImageFileName: String?
    var generatedVideoFileName: String?
    
    var inspirationText: String?
    var inspirationPersona: InspirationPersona?
    var videoAnalysisText: String?
    var videoScript: String?
    
    var videoGenTaskID: String?
    var isGeneratingEditedImage: Bool = false
    var isGeneratingVideo: Bool = false
    var isGeneratingVideoScript: Bool = false

    var originalImage: UIImage? {
        let cacheKey = self.originalImageFileName
        if let cachedImage = ImageCacheManager.shared.get(forKey: cacheKey) {
            return cachedImage
        }
        
        guard let data = FileManagerHelper.read(from: originalImageFileName),
              let image = UIImage(data: data) else {
            return nil
        }
        
        ImageCacheManager.shared.set(image, forKey: cacheKey)
        return image
    }
    
    var editedImage: UIImage? {
        guard let fileName = editedImageFileName else { return nil }
        let cacheKey = fileName
        if let cachedImage = ImageCacheManager.shared.get(forKey: cacheKey) {
            return cachedImage
        }

        guard let data = FileManagerHelper.read(from: fileName),
              let image = UIImage(data: data) else {
            return nil
        }
              
        ImageCacheManager.shared.set(image, forKey: cacheKey)
        return image
    }
    
    var videoData: Data? {
        guard let fileName = videoFileName else { return nil }
        return FileManagerHelper.read(from: fileName)
    }

    var generatedVideoData: Data? {
        guard let fileName = generatedVideoFileName else { return nil }
        return FileManagerHelper.read(from: fileName)
    }
    
    init(id: UUID = UUID(), creationDate: Date = Date(), originalImageData: Data, videoData: Data? = nil) {
        self.id = id
        self.creationDate = creationDate
        
        self.originalImageFileName = "\(id)_original.jpg"
        FileManagerHelper.save(data: originalImageData, to: self.originalImageFileName)
        
        if let videoData = videoData {
            self.videoFileName = "\(id)_video.mov"
            FileManagerHelper.save(data: videoData, to: self.videoFileName!)
        }
    }
}

enum InspirationState: Equatable {
    case idle, capturing, thinking, reasoning, streaming, finished, error(String)
}

enum InspirationPersona: String, CaseIterable, Identifiable, Codable {
    case doubaoAssistant = "灵感助理"
    case photographyMaster = "光影诗人"
    case poet = "文字诗人"
    case translationAssistant = "语言学者"
    case encyclopedia = "博物学者"
    case storyteller = "织梦者"
    case healthAssistant = "生活禅师"
    
    var id: String { self.rawValue }
    
    var systemImage: String {
        switch self {
        case .doubaoAssistant: "sparkles"
        case .photographyMaster: "camera.aperture"
        case .poet: "pencil.and.scribble"
        case .translationAssistant: "character.book.closed.fill"
        case .encyclopedia: "book.closed.fill"
        case .storyteller: "quote.bubble.fill"
        case .healthAssistant: "leaf.fill"
        }
    }
}

enum AIProvider: String, CaseIterable, Identifiable {
    case doubao = "豆包大模型"
    case openAI = "OpenAI"
    var id: String { self.rawValue }
}

struct HighlightStoryResponse: Decodable, Equatable {
    let title: String
    let caption: String
    let hashtags: [String]
}
