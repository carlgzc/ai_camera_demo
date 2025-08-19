// FileName: AICamera/Views/AlbumDetailView.swift
import SwiftUI
import AVKit
import SwiftData

struct AlbumDetailView: View {
    // ✅ 重构: @Bindable 使得对 task 的修改能被 SwiftData 自动保存
    @Bindable var task: CaptureTask
    
    // ✅ 重构: 为了调用 AI 服务，我们临时创建一个 ViewModel 实例
    // 它需要访问环境中的 modelContext 和 appSettings
    @StateObject private var viewModel = CameraViewModel()
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appSettings: AppSettings

    @StateObject private var playerManager = PlayerManager()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                mediaContent(for: task)
                    .scaledToFit()
                    .cornerRadius(12)
                    .shadow(radius: 5)

                analysisContent(for: task)
                
                Divider().padding(.vertical, 8)

                if task.videoFileName == nil {
                    aiGenerationSection(for: task)
                }
            }
            .padding()
        }
        .onAppear {
            // ✅ 重构: 视图出现时，为临时的 ViewModel 配置必要的环境
            // 传入一个空的 tasks 数组，因为它只用于执行操作，不用于显示列表
            viewModel.configure(settings: appSettings, modelContext: modelContext, allTasks: [])
        }
        .navigationTitle(Text(task.creationDate.toString(format: "yyyy年M月d日 H:mm")))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                shareLink(for: task)
            }
        }
    }

    @ViewBuilder
    private func mediaContent(for task: CaptureTask) -> some View {
        if let videoData = task.videoData {
            VideoPlayer(player: playerManager.player)
                .onAppear { playerManager.setupPlayer(with: videoData, isGenerated: false) }
        } else if let image = task.originalImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
        }
    }

    @ViewBuilder
    private func analysisContent(for task: CaptureTask) -> some View {
        let textToShow = task.videoFileName != nil ? task.videoAnalysisText : task.inspirationText
        let personaToShow = task.inspirationPersona ?? .doubaoAssistant
        
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: personaToShow.systemImage)
                Text(personaToShow.rawValue + "的解读")
            }
            .font(.headline).foregroundColor(.secondary)
            
            if let text = textToShow, !text.isEmpty {
                Text(.init(text))
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if task.videoFileName != nil && task.videoAnalysisText == nil {
                ProgressView("正在解读影像...")
            } else if task.videoFileName == nil && task.inspirationText == nil {
                ProgressView("灵感正在涌现...")
            }
        }
        .padding()
    }

    @ViewBuilder
    private func aiGenerationSection(for task: CaptureTask) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 12) {
                Text("唤醒画中梦").font(.title2).bold()
                if let editedImage = task.editedImage {
                    Image(uiImage: editedImage)
                        .resizable().scaledToFit().cornerRadius(12).shadow(radius: 3)
                    actionButton(title: "珍藏入册", icon: "square.and.arrow.down") {
                        viewModel.saveToSystemPhotos(for: task, contentType: .editedImage)
                    }
                } else {
                    Text("基于原始照片，唤醒一幅具有独特艺术风格的画作。").font(.subheadline).foregroundColor(.secondary)
                    Button(action: { viewModel.generateAIEffects(for: task) }) {
                        HStack {
                            if task.isGeneratingEditedImage {
                                ProgressView()
                                Text("正在绘制梦境...").padding(.leading, 8)
                            } else {
                                Text("生成动漫风格画作")
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(task.isGeneratingEditedImage)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("重塑时光影").font(.title2).bold()
                if let videoData = task.generatedVideoData {
                    VideoPlayer(player: playerManager.player)
                        .frame(height: 250).cornerRadius(12)
                        .onAppear { playerManager.setupPlayer(with: videoData, isGenerated: true) }
                    actionButton(title: "珍藏入册", icon: "square.and.arrow.down") {
                        viewModel.saveToSystemPhotos(for: task, contentType: .generatedVideo)
                    }
                } else {
                    if let script = task.videoScript, !script.isEmpty {
                         VStack(alignment: .leading, spacing: 8) {
                            Text("灵感剧本:").font(.caption).foregroundColor(.secondary)
                            Text("“\(script)”").font(.body).italic()
                        }
                        .padding()
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    if task.isGeneratingVideo {
                         ProgressView("正在编织光影...").padding(.top)
                    } else if task.isGeneratingVideoScript {
                        ProgressView("正在构思剧本...").padding(.top)
                    } else {
                        Text("基于原始照片与灵感剧本，创造一段流动的影像诗。").font(.subheadline).foregroundColor(.secondary).padding(.top, 4)
                        Button(action: { viewModel.generateAIVideo(for: task) }) {
                            Text("开始创作")
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.top, 4)
                    }
                }
            }
        }
    }
    
    private func actionButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
    }

    @ViewBuilder
    private func shareLink(for task: CaptureTask) -> some View {
        if let videoData = task.generatedVideoData ?? task.videoData {
            if let url = playerManager.getShareableURL(for: videoData) {
                 ShareLink(item: url, preview: SharePreview("一段影像诗", icon: Image(systemName: "film")))
            }
        } else if let image = task.editedImage ?? task.originalImage {
            let shareableImage = Image(uiImage: image)
            ShareLink(item: shareableImage, preview: SharePreview("一帧记忆", image: shareableImage))
        }
    }
}

// 保持不变
extension Date {
    func toString(format: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        return formatter.string(from: self)
    }
}

@MainActor
class PlayerManager: ObservableObject {
    @Published var player = AVPlayer()
    
    private var originalVideoURL: URL?
    private var generatedVideoURL: URL?

    func setupPlayer(with data: Data, isGenerated: Bool) {
        let urlToPlay: URL?
        
        if isGenerated {
            if generatedVideoURL == nil { generatedVideoURL = createTempFile(from: data, ext: "mov") }
            urlToPlay = generatedVideoURL
        } else {
            if originalVideoURL == nil { originalVideoURL = createTempFile(from: data, ext: "mov") }
            urlToPlay = originalVideoURL
        }
        
        if let url = urlToPlay, player.currentItem?.asset !== (AVURLAsset(url: url) as AVAsset) {
            player.replaceCurrentItem(with: AVPlayerItem(url: url))
        }
    }
    
    func getShareableURL(for data: Data) -> URL? {
        if generatedVideoURL != nil { return generatedVideoURL }
        if originalVideoURL != nil { return originalVideoURL }
        return createTempFile(from: data, ext: "mov")
    }
    
    private func createTempFile(from data: Data, ext: String) -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension(ext)
        try? data.write(to: url)
        return url
    }
    
    deinit {
        if let url = originalVideoURL { try? FileManager.default.removeItem(at: url) }
        if let url = generatedVideoURL { try? FileManager.default.removeItem(at: url) }
    }
}
