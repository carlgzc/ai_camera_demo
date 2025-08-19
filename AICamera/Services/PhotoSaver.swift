// FileName: PhotoSaver.swift
import SwiftUI
import Photos

@MainActor
class PhotoSaver {
    
    func save(content: Any) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized else {
            throw SaveError.permissionDenied
        }

        if let image = content as? UIImage {
            try await saveImage(image)
        } else if let imageData = content as? Data, let image = UIImage(data: imageData) {
            // Handle saving an image from Data
            try await saveImage(image)
        } else if let url = content as? URL {
            // Handle saving a video from a URL (e.g., a temporary file)
            try await saveVideo(from: url)
        } else if let videoData = content as? Data {
            // ✅ 优化: 直接从 Data 保存视频，避免不必要的磁盘写入
            try await saveVideo(fromData: videoData)
        } else {
            throw SaveError.unsupportedContentType
        }
    }
    
    private func saveImage(_ image: UIImage) async throws {
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }
    }
    
    private func saveVideo(from url: URL) async throws {
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
        }
    }

    // ✅ 优化: 新增辅助函数，用于从 Data 直接保存视频
    private func saveVideo(fromData data: Data) async throws {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("mov")
        
        do {
            try data.write(to: tempURL)
            try await saveVideo(from: tempURL)
            // 清理临时文件
            try? FileManager.default.removeItem(at: tempURL)
        } catch {
            // 如果保存失败，也要确保清理临时文件
            try? FileManager.default.removeItem(at: tempURL)
            throw error
        }
    }

    enum SaveError: Error, LocalizedError {
        case permissionDenied
        case unsupportedContentType
        case saveFailed(Error)
        
        var errorDescription: String? {
            switch self {
            case .permissionDenied: "需要相册访问权限。"
            case .unsupportedContentType: "不支持的保存内容类型。"
            case .saveFailed(let error): "保存时发生未知错误: \(error.localizedDescription)"
            }
        }
    }
}
