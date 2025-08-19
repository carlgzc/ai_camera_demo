// FileName: AICamera/ImageCacheManager.swift
// CREATED TO OPTIMIZE IMAGE LOADING PERFORMANCE

import UIKit

/**
 一个简单的单例类，用于在内存中缓存解码后的 UIImage 对象。
 使用 NSCache 可以利用其自动处理内存警告时资源释放的特性。
 这将显著提升在滚动视图（如 AlbumView）中显示图片时的性能，
 因为它避免了每次视图出现时都从磁盘重复读取和解码图像数据。
 */
class ImageCacheManager {
    // 创建一个全局共享的单例实例
    static let shared = ImageCacheManager()
    
    // 使用 NSCache 来存储图片。NSCache 的键必须是遵循 a
    // a'n's'c'o'd'i'n'g 的类，所以我们用 NSString。
    private let cache = NSCache<NSString, UIImage>()

    // 将构造函数设为私有，确保全局只有一个实例
    private init() {}

    /**
     将一个 UIImage 对象存入缓存。
     - Parameters:
       - image: 需要缓存的图片。
       - key: 与图片关联的唯一键，通常是文件名。
     */
    func set(_ image: UIImage, forKey key: String) {
        cache.setObject(image, forKey: key as NSString)
    }

    /**
     根据键从缓存中获取一个 UIImage 对象。
     - Parameter key: 需要查找的图片的唯一键。
     - Returns: 如果缓存中存在，则返回对应的 UIImage；否则返回 nil。
     */
    func get(forKey key: String) -> UIImage? {
        return cache.object(forKey: key as NSString)
    }
}
