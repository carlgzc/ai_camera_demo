// FileName: AICamera/Views/AlbumView.swift
import SwiftUI
import AVKit
import SwiftData

struct AlbumView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Query(sort: \CaptureTask.creationDate, order: .reverse) private var captureTasks: [CaptureTask]
    
    @StateObject private var highlightViewModel = HighlightViewModel()
    @EnvironmentObject var appSettings: AppSettings

    @State private var isEditing = false
    @State private var selectedTaskIDs = Set<UUID>()
    @State private var showHighlightReel = false
    @State private var isShowingLoadingOverlay = false
    @State private var showGenerationFailedAlert = false

    var body: some View {
        ZStack {
            NavigationStack {
                ScrollView {
                    if captureTasks.isEmpty {
                        Text("回廊空荡，待您捕捉瞬间")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                            .padding(.top, 200)
                    } else {
                        LazyVStack(spacing: 28) {
                            ForEach(captureTasks) { task in
                                AlbumStoryItemView(task: task, isEditing: $isEditing, selectedTaskIDs: $selectedTaskIDs)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top)
                    }
                }
                .onAppear {
                    highlightViewModel.configure(settings: appSettings)
                }
                .navigationTitle("记忆回廊")
                .navigationBarTitleDisplayMode(.inline)
                .navigationDestination(for: CaptureTask.self) { task in
                    AlbumDetailView(task: task)
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(isEditing ? "取消" : "返回") {
                            if isEditing {
                                isEditing = false
                                selectedTaskIDs.removeAll()
                            } else {
                                dismiss()
                            }
                        }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        if isEditing {
                             Button("删除 (\(selectedTaskIDs.count))", role: .destructive) {
                                deleteSelectedTasks()
                            }
                            .disabled(selectedTaskIDs.isEmpty)
                        } else {
                            Button("选择") {
                                isEditing = true
                            }
                        }
                    }
                    
                    if !isEditing && !captureTasks.isEmpty {
                        ToolbarItem(placement: .bottomBar) {
                            Button(action: {
                                generateHighlightStoryAction()
                            }) {
                                Label(selectedTaskIDs.isEmpty ? "为全部生成故事" : "为 \(selectedTaskIDs.count) 项生成故事", systemImage: "sparkles")
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }
                .navigationDestination(isPresented: $showHighlightReel) {
                    HighlightReelView(viewModel: highlightViewModel)
                }
            }
            .alert("生成失败", isPresented: $showGenerationFailedAlert) {
                 Button("好的", role: .cancel) { }
            } message: {
                Text(highlightViewModel.errorMessage)
            }
            
            if isShowingLoadingOverlay {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                
                VStack {
                    ProgressView()
                        .padding()
                    Text("AI 正在为您创作故事...")
                        .foregroundColor(.white)
                }
                .padding(30)
                .background(.ultraThinMaterial)
                .cornerRadius(20)
            }
        }
    }
    
    private func generateHighlightStoryAction() {
        isShowingLoadingOverlay = true
        // If no tasks are selected in edit mode, use all tasks. Otherwise, use the selected ones.
        let tasksToProcess: [CaptureTask]
        if selectedTaskIDs.isEmpty {
            tasksToProcess = captureTasks
        } else {
            tasksToProcess = captureTasks.filter { selectedTaskIDs.contains($0.id) }
        }
        
        Task {
            await highlightViewModel.generateHighlightStory(for: tasksToProcess)
            await MainActor.run {
                isShowingLoadingOverlay = false
                if highlightViewModel.highlightStory != nil {
                    showHighlightReel = true
                } else {
                    showGenerationFailedAlert = true
                }
            }
        }
    }

    private func deleteSelectedTasks() {
        do {
            try modelContext.delete(model: CaptureTask.self, where: #Predicate { task in
                selectedTaskIDs.contains(task.id)
            })
            isEditing = false
            selectedTaskIDs.removeAll()
        } catch {
            print("🔴 Failed to delete selected tasks: \(error)")
        }
    }
}

struct AlbumStoryItemView: View {
    @Bindable var task: CaptureTask
    @Binding var isEditing: Bool
    @Binding var selectedTaskIDs: Set<UUID>
    
    @State private var player: AVPlayer?
    @State private var playerLooper: AVPlayerLooper?

    private var analysisText: String? {
        let text = task.videoFileName != nil ? task.videoAnalysisText : task.inspirationText
        return (text?.isEmpty ?? true) ? nil : text
    }
    
    private var persona: InspirationPersona? {
        return task.inspirationPersona
    }
    
    private var isSelected: Bool {
        selectedTaskIDs.contains(task.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            mediaPreview
                .aspectRatio(3/4, contentMode: .fill)
                .cornerRadius(12)
                .shadow(radius: 5)
                .frame(maxWidth: .infinity)
                .overlay(
                    ZStack {
                        if isEditing {
                            Color.black.opacity(0.4)
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .font(.largeTitle)
                                .foregroundColor(.white)
                        }
                    }
                    .animation(.easeInOut, value: isSelected)
                    .contentShape(Rectangle())
                )
                .onTapGesture {
                    if isEditing {
                        if isSelected {
                            selectedTaskIDs.remove(task.id)
                        } else {
                            selectedTaskIDs.insert(task.id)
                        }
                    }
                }
            
            if let text = analysisText {
                VStack(alignment: .leading, spacing: 6) {
                    if let persona = persona {
                        HStack(spacing: 6) {
                            Image(systemName: persona.systemImage)
                            Text(persona.rawValue + "的低语")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    Text(.init(text))
                        .font(.body)
                        .lineLimit(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.thinMaterial)
            } else if task.videoFileName != nil && task.videoAnalysisText == nil {
                 HStack {
                    ProgressView()
                    Text("影像解读中...")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                 }
                 .padding()
                 .frame(maxWidth: .infinity, alignment: .leading)
                 .background(.thinMaterial)
            }
            
            NavigationLink(value: task) {
                HStack {
                    Text("探索更多可能")
                    Spacer()
                    Image(systemName: "arrow.right")
                }
                .font(.footnote.weight(.bold))
                .foregroundColor(.accentColor)
                .padding()
            }
            .disabled(isEditing)
            .background(.thinMaterial)

        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.2), lineWidth: isSelected ? 3 : 1)
        )
        .animation(.easeInOut, value: isSelected)
    }
    
    @ViewBuilder
    private var mediaPreview: some View {
        if task.videoFileName != nil {
            ZStack {
                if let player = player {
                    VideoPlayer(player: player)
                        .disabled(true)
                } else {
                    Rectangle().fill(Color.black)
                    ProgressView().tint(.white)
                }
            }
            .onAppear { setupPlayer() }
            .onDisappear { cleanupPlayer() }
        } else if let image = task.originalImage {
            Image(uiImage: image)
                .resizable()
        } else {
            Color.gray.opacity(0.3)
        }
    }
    
    private func setupPlayer() {
        guard player == nil, let fileName = task.videoFileName else { return }
        let url = FileManagerHelper.getURL(for: fileName)
        
        let item = AVPlayerItem(url: url)
        let queuePlayer = AVQueuePlayer(playerItem: item)
        self.playerLooper = AVPlayerLooper(player: queuePlayer, templateItem: item)
        
        queuePlayer.isMuted = true
        self.player = queuePlayer
        queuePlayer.play()
    }

    private func cleanupPlayer() {
        player?.pause()
        player = nil
        playerLooper = nil
    }
}

@MainActor
class HighlightViewModel: ObservableObject {
    @Published var highlightStory: HighlightStoryResponse? = nil
    @Published var isGeneratingHighlightStory = false
    @Published var errorMessage = ""
    
    private var aiService: AIService?
    private var appSettings: AppSettings?
    
    func configure(settings: AppSettings) {
        self.appSettings = settings
        switch settings.aiProvider {
        case .doubao: self.aiService = DoubaoService(settings: settings)
        case .openAI: self.aiService = OpenAIService(settings: settings)
        }
    }

    func generateHighlightStory(for tasks: [CaptureTask]) async {
        guard let service = aiService, let settings = appSettings else {
            self.errorMessage = "AI 服务未正确配置。"
            return
        }
        
        isGeneratingHighlightStory = true
        highlightStory = nil
        errorMessage = ""
        
        do {
            let imagesData: [Data] = tasks.compactMap { FileManagerHelper.read(from: $0.originalImageFileName) }
            
            guard !imagesData.isEmpty else { throw NSError(domain: "DataError", code: 0, userInfo: [NSLocalizedDescriptionKey: "无法加载所选图片。"]) }
            
            let prompt = settings.highlightReelPrompt
            
            // ✅ FIX: Switched from a problematic chained .reduce to a clear for-await-in loop.
            // This is the modern, correct way to consume an AsyncThrowingStream.
            var fullText = ""
            let stream = service.getVLMAnalysis(from: imagesData, prompt: prompt)
            for try await chunk in stream {
                // Use `if case let` to safely extract the string from the .content case.
                if case .content(let text) = chunk {
                    fullText += text
                }
            }

            if let data = fullText.data(using: .utf8),
               let result = try? JSONDecoder().decode(HighlightStoryResponse.self, from: data) {
                self.highlightStory = result
            } else {
                throw NSError(domain: "AIError", code: 0, userInfo: [NSLocalizedDescriptionKey: "AI未能生成有效的故事脚本，请检查Prompt或网络。"])
            }
            
        } catch {
            self.errorMessage = "生成高光卷轴失败: \(error.localizedDescription)"
            print("🔴 Highlight Story generation failed: \(self.errorMessage)")
        }
        
        isGeneratingHighlightStory = false
    }
}
