// FileName: AICamera/App/AICameraApp.swift
import SwiftUI
import SwiftData

@main
struct AICameraApp: App {
    // 1. 创建 AppSettings 作为整个 App 的“单一数据源”
    @StateObject private var appSettings = AppSettings()

    // ✅ 重构: 为 CaptureTask 设置 SwiftData 容器
    let modelContainer: ModelContainer
    
    init() {
        do {
            modelContainer = try ModelContainer(for: CaptureTask.self)
        } catch {
            fatalError("Could not initialize ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            CameraView()
                // 2. 将 AppSettings 对象注入到 SwiftUI 环境中
                .environmentObject(appSettings)
        }
        // 3. ✅ 重构: 将模型容器注入到环境中，供所有子视图使用
        .modelContainer(modelContainer)
    }
}
