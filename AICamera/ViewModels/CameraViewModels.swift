// FileName: AICamera/ViewModels/CameraViewModel.swift
import SwiftUI
import AVFoundation
import CoreImage
import Combine
import Vision
import SwiftData

@MainActor
class CameraViewModel: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate, AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureFileOutputRecordingDelegate {
    
    var modelContext: ModelContext?
    
    private let cameraActor: CameraActor
    let previewSession: AVCaptureSession
    @Published var isRecording = false

    @Published var showError = false
    @Published var errorTitle = "有缘无分"
    @Published var errorMessage = ""
    
    @Published var selectedPersona: InspirationPersona = .doubaoAssistant {
        didSet(oldValue) {
            if oldValue != selectedPersona {
                triggerGlobalInspiration()
            }
        }
    }
    
    @Published var inspirationState: InspirationState = .idle
    @Published var reasoningText: String = ""
    @Published var inspirationText: String = ""
    @Published var latency: Int? = nil

    @Published var latestTaskForPreview: CaptureTask?

    @Published var cameraPosition: AVCaptureDevice.Position = .back
    
    @Published var isAutoInspirationEnabled = true {
        didSet {
            if isAutoInspirationEnabled && inspirationState == .idle {
                triggerGlobalInspiration()
            } else if !isAutoInspirationEnabled {
                cancelInspiration(andRestart: false)
            }
        }
    }
    
    @Published var highlightStory: HighlightStoryResponse? = nil
    @Published var isGeneratingHighlightStory = false
    
    private var latestVideoFrame: CMSampleBuffer?
    private var lastFocusPoint: CGPoint? = nil
    
    private var appSettings: AppSettings?
    private var aiService: AIService?
    private let speechService = SpeechService()
    private var inspirationTask: Task<Void, Never>?
    private var recordingTimer: Timer?
    private let photoSaver = PhotoSaver()
    
    private let ciContext = CIContext()
    
    private var isInitialInspirationDone = false

    override init() {
        self.cameraActor = CameraActor()
        self.previewSession = cameraActor.session
        
        super.init()
        Task {
            await cameraActor.configureDelegates(photoDelegate: self, recordingDelegate: self, videoSampleBufferDelegate: self)
            self.cameraPosition = await cameraActor.getCurrentCameraPosition()
        }
    }
    
    func configure(settings: AppSettings, modelContext: ModelContext, allTasks: [CaptureTask]) {
        self.modelContext = modelContext
        self.latestTaskForPreview = allTasks.first
        
        if self.appSettings == nil {
            self.appSettings = settings
            self.updateAIService()
            resumeAllPendingVideoTasks(allTasks: allTasks)
        }
        Task { await cameraActor.start() }
    }
    
    func updateAIService() {
        guard let settings = appSettings else { return }
        switch settings.aiProvider {
        case .doubao: self.aiService = DoubaoService(settings: settings)
        case .openAI: self.aiService = OpenAIService(settings: settings)
        }
    }
    
    func onDisappear() { Task { await cameraActor.stop() } }

    func startRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.startRecording()
            }
        }
    }

    func cancelRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
    }
    
    func capturePhoto() { Task { await cameraActor.capturePhoto(delegate: self) } }
    func startRecording() {
        cancelRecordingTimer()
        isRecording = true
        Task { await cameraActor.startRecording() }
    }
    func stopRecording() {
        isRecording = false
        Task { await cameraActor.stopRecording() }
    }
    
    func switchCamera() {
        Task {
            await cameraActor.switchCamera()
            self.cameraPosition = await cameraActor.getCurrentCameraPosition()
        }
    }
    
    func focus(at point: CGPoint) {
        self.lastFocusPoint = point
        triggerGlobalInspiration(isFocusAction: true)
    }
    
    func triggerGlobalInspiration(isFocusAction: Bool = false) {
        cancelInspiration(andRestart: false)
        
        inspirationTask = Task {
            if isFocusAction, let point = self.lastFocusPoint {
                await cameraActor.focus(at: point)
            }
            do {
                try await startInspirationAnalysis()
            } catch {
                if !(error is CancellationError) {
                    self.inspirationState = .error("灵感连接中断: \(error.localizedDescription)")
                }
            }
            self.inspirationTask = nil
        }
    }

    func generateAIEffects(for task: CaptureTask) {
        task.isGeneratingEditedImage = true
        
        Task {
            do {
                guard let service = aiService, let settings = appSettings,
                      let originalData = FileManagerHelper.read(from: task.originalImageFileName) else {
                    throw NSError(domain: "ConfigError", code: 0)
                }
                
                let prompt = settings.imageEditPrompt
                let editedData = try await service.generateEditedImage(from: originalData, prompt: prompt)
                let editedFileName = "\(task.id)_edited.jpg"
                FileManagerHelper.save(data: editedData, to: editedFileName)
                
                task.editedImageFileName = editedFileName
            } catch {
                showAlert(message: "唤醒画中梦失败: \(error.localizedDescription)")
            }
            task.isGeneratingEditedImage = false
        }
    }

    func generateAIVideo(for task: CaptureTask) {
        if task.isGeneratingVideo || task.isGeneratingVideoScript { return }
        
        Task {
            task.isGeneratingVideoScript = true
            
            var script = ""
            do {
                guard let service = aiService, let settings = appSettings,
                      let originalData = FileManagerHelper.read(from: task.originalImageFileName) else {
                    throw NSError(domain: "ConfigError", code: 0)
                }
                
                let prompt = settings.videoStoryPrompt
                let stream = service.getVLMAnalysis(from: [originalData], prompt: prompt)
                for try await chunk in stream {
                     if case .content(let text) = chunk { script += text }
                }
                
                if script.isEmpty { throw NSError(domain: "VideoGen", code: 0, userInfo: [NSLocalizedDescriptionKey: "未能构思出合适的剧本。"]) }
                
                task.videoScript = script
                
            } catch {
                showAlert(message: "灵感剧本构思失败: \(error.localizedDescription)")
                task.isGeneratingVideoScript = false
                return
            }
            
            task.isGeneratingVideoScript = false

            guard let doubaoService = self.aiService as? DoubaoServiceProtocol else {
                showAlert(message: "重塑时光影的功能暂不可用。")
                return
            }

            do {
                guard let originalData = FileManagerHelper.read(from: task.originalImageFileName) else {
                    throw NSError(domain: "FileError", code: 0)
                }
                
                let videoTaskID = try await doubaoService.createVideoGenerationTask(from: originalData, prompt: script)
                
                task.videoGenTaskID = videoTaskID
                task.isGeneratingVideo = true
                
                pollVideoGenerationTask(for: task)
                
            } catch {
                showAlert(message: "发起时光重塑任务失败: \(error.localizedDescription)")
                task.isGeneratingVideo = false
            }
        }
    }
    
    private func pollVideoGenerationTask(for task: CaptureTask) {
        Task(priority: .background) {
            guard let videoGenID = task.videoGenTaskID else { return }
            
            guard let doubaoService = self.aiService as? DoubaoServiceProtocol else {
                handleVideoGenerationCompletion(for: task, result: .failure(NSError(domain: "ServiceError", code: 0, userInfo: [NSLocalizedDescriptionKey: "服务不可用"])))
                return
            }
            
            for _ in 0..<120 {
                do {
                    let statusResponse = try await doubaoService.checkVideoTaskStatus(taskID: videoGenID)
                    switch statusResponse.status {
                    case "succeeded":
                        if let urlStr = statusResponse.content?.video_url, let url = URL(string: urlStr) {
                            let (videoData, _) = try await URLSession.shared.data(from: url)
                            handleVideoGenerationCompletion(for: task, result: .success(videoData))
                            return
                        } else { throw NSError(domain: "DoubaoService", code: 0, userInfo: [NSLocalizedDescriptionKey: "影像已成，但获取时迷失了方向。"]) }
                    case "failed":
                        let message = statusResponse.error?.message ?? "未知的原因"
                        throw NSError(domain: "DoubaoService", code: 0, userInfo: [NSLocalizedDescriptionKey: "时光重塑失败: \(message)"])
                    case "processing", "pending":
                        try await Task.sleep(for: .seconds(5))
                    default:
                        throw NSError(domain: "DoubaoService", code: 0, userInfo: [NSLocalizedDescriptionKey: "未知的时空状态: \(statusResponse.status)"])
                    }
                } catch {
                    handleVideoGenerationCompletion(for: task, result: .failure(error))
                    return
                }
            }
            handleVideoGenerationCompletion(for: task, result: .failure(NSError(domain: "DoubaoService", code: 0, userInfo: [NSLocalizedDescriptionKey: "时光重塑超时(10分钟)，灵感逸散。"])))
        }
    }
    
    private func handleVideoGenerationCompletion(for task: CaptureTask, result: Result<Data, Error>) {
        switch result {
        case .success(let videoData):
            let fileName = "\(task.id)_generated.mov"
            FileManagerHelper.save(data: videoData, to: fileName)
            task.generatedVideoFileName = fileName
        case .failure(let error):
            showAlert(message: "重塑时光影失败: \(error.localizedDescription)")
        }
        
        task.isGeneratingVideo = false
    }
    
    private func resumeAllPendingVideoTasks(allTasks: [CaptureTask]) {
        let pendingTasks = allTasks.filter { $0.videoGenTaskID != nil && $0.generatedVideoFileName == nil && !$0.isGeneratingVideo }
        for task in pendingTasks {
            pollVideoGenerationTask(for: task)
            task.isGeneratingVideo = true
        }
    }
    
    enum ContentType { case editedImage, generatedVideo }
    
    func saveToSystemPhotos(for task: CaptureTask, contentType: ContentType) {
        var contentToSave: Any?
        
        switch contentType {
        case .editedImage:
            if let fileName = task.editedImageFileName {
                contentToSave = FileManagerHelper.read(from: fileName)
            }
        case .generatedVideo:
            if let fileName = task.generatedVideoFileName {
                contentToSave = FileManagerHelper.getURL(for: fileName)
            }
        }
        
        guard let content = contentToSave else {
            showAlert(message: "无物可藏。"); return
        }
        
        Task {
            do {
                try await photoSaver.save(content: content)
                showAlert(title: "珍藏成功", message: "这段记忆已妥善存入系统相册。")
            } catch {
                showAlert(message: "珍藏失败: \(error.localizedDescription)")
            }
        }
    }
    
    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput buffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        Task { @MainActor in
            self.latestVideoFrame = buffer
            
            if !self.isInitialInspirationDone && self.isAutoInspirationEnabled {
                self.isInitialInspirationDone = true
                self.triggerGlobalInspiration()
            }
        }
    }

    private func startInspirationAnalysis() async throws {
        while latestVideoFrame == nil {
            try await Task.sleep(for: .milliseconds(100))
            try Task.checkCancellation()
        }
        
        guard let service = aiService, let settings = appSettings, let frame = latestVideoFrame,
              let imageBuffer = CMSampleBufferGetImageBuffer(frame) else {
            throw NSError(domain: "PreconditionFailed", code: -1, userInfo: [NSLocalizedDescriptionKey: "AI 服务或视频帧不可用。"])
        }
        
        let frameCIImage = CIImage(cvPixelBuffer: imageBuffer)
        var finalImageData: Data?
        
        if let focusPoint = self.lastFocusPoint {
            let finalCIImage = drawImageWithFocusMarkerUsingCoreImage(on: frameCIImage, at: focusPoint)
            finalImageData = jpegData(from: finalCIImage, compressionQuality: 0.5)
            self.lastFocusPoint = nil
        } else {
            finalImageData = jpegData(from: frameCIImage, compressionQuality: 0.4)
        }

        guard let imageData = finalImageData else { return }
        
        let finalPrompt = settings.prompt(for: selectedPersona)

        try Task.checkCancellation()
        self.inspirationState = .thinking
        
        let stream = service.getVLMAnalysis(from: [imageData], prompt: finalPrompt)
        let streamStartDate = Date()
        
        var hasStartedContent = false
        var fullText = ""
        for try await chunk in stream {
            try Task.checkCancellation()
            if self.latency == nil { self.latency = Int(Date().timeIntervalSince(streamStartDate) * 1000) }
            
            switch chunk {
            case .reasoning(let text):
                if !hasStartedContent { if inspirationState != .reasoning { inspirationState = .reasoning }; self.reasoningText += text }
            case .content(let text):
                if !hasStartedContent { hasStartedContent = true; self.reasoningText = ""; if inspirationState != .streaming { inspirationState = .streaming } }
                fullText += text
                self.inspirationText = fullText
            }
        }
        
        try Task.checkCancellation()
        self.inspirationState = self.inspirationText.isEmpty ? .error("灵感暂时沉默") : .finished
        if inspirationState == .finished, settings.isAutoReadEnabled { speechService.speak(text: self.inspirationText) }
    }

    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        Task { @MainActor in
            guard let modelContext = self.modelContext else { return }

            if let error { showAlert(message: "瞬间捕捉失败: \(error.localizedDescription)"); return }
            guard var data = photo.fileDataRepresentation() else { showAlert(message: "无法承载此份记忆。"); return }
            
            let cameraPosition = await cameraActor.getCurrentCameraPosition()
            if cameraPosition == .front, let image = UIImage(data: data), let flipped = image.flippedHorizontally(), let flippedData = flipped.jpegData(compressionQuality: 1.0) {
                data = flippedData
            }

            let newTask = CaptureTask(originalImageData: data)
            if self.inspirationState == .finished {
                newTask.inspirationText = self.inspirationText
                newTask.inspirationPersona = self.selectedPersona
            }
            
            modelContext.insert(newTask)
            self.latestTaskForPreview = newTask
        }
    }

    nonisolated func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        Task { @MainActor in
            guard let modelContext = self.modelContext else { return }

            if let error { showAlert(message: "影像录制失败: \(error.localizedDescription)"); return }
            
            do {
                let videoData = try Data(contentsOf: outputFileURL)
                guard let frameData = await extractFrame(from: outputFileURL, at: 0.1) else { showAlert(message: "无法撷取影像封面。"); return }
                
                let newTask = CaptureTask(originalImageData: frameData, videoData: videoData)
                newTask.inspirationPersona = self.selectedPersona
                
                modelContext.insert(newTask)
                self.latestTaskForPreview = newTask
                
                await processVideoForInspiration(task: newTask, videoURL: outputFileURL)
            } catch {
                showAlert(message: "处理录制影像失败: \(error.localizedDescription)")
            }
            
            try? FileManager.default.removeItem(at: outputFileURL)
        }
    }
    
    private func processVideoForInspiration(task: CaptureTask, videoURL: URL) async {
        let frames = await extractFrames(from: videoURL, fps: 0.5, targetWidth: 720)
        guard !frames.isEmpty, let service = self.aiService, let settings = self.appSettings else {
            task.videoAnalysisText = "影像帧提取失败或AI服务配置错误。"
            return
        }
        
        let persona = task.inspirationPersona ?? .doubaoAssistant
        let prompt = "请基于这段影像的连续画面，并结合'\(settings.prompt(for: persona))'这一角色设定，对整个故事进行全面的解读与升华。"
        
        do {
            let stream = service.getVLMAnalysis(from: frames, prompt: prompt)
            var fullText = ""
            for try await chunk in stream {
                 if case .content(let text) = chunk { fullText += text }
            }
            task.videoAnalysisText = fullText
        } catch {
            task.videoAnalysisText = "解读影像失败: \(error.localizedDescription)"
        }
    }
    
    private func drawImageWithFocusMarkerUsingCoreImage(on ciImage: CIImage, at normalizedPoint: CGPoint) -> CIImage {
        let imageSize = ciImage.extent.size
        let markerCenter = CIVector(x: normalizedPoint.x * imageSize.width, y: (1 - normalizedPoint.y) * imageSize.height)

        let markerColor = CIColor(red: 0.1, green: 0.2, blue: 1.0, alpha: 0.5)
        let radialGradient = CIFilter(
            name: "CIRadialGradient",
            parameters: [
                "inputCenter": markerCenter,
                "inputRadius0": 20,
                "inputRadius1": 25,
                "inputColor0": markerColor,
                "inputColor1": CIColor.clear
            ]
        )?.outputImage

        guard let markerImage = radialGradient else { return ciImage }
        return markerImage.composited(over: ciImage)
    }

    private func jpegData(from ciImage: CIImage, compressionQuality: CGFloat) -> Data? {
        let scale = 720 / ciImage.extent.width
        let resizedImage = ciImage.transformed(by: .init(scaleX: scale, y: scale))
        
        guard let cgImage = ciContext.createCGImage(resizedImage, from: resizedImage.extent) else { return nil }
        
        var data: Data?
        if let mutableData = CFDataCreateMutable(nil, 0),
           let destination = CGImageDestinationCreateWithData(mutableData, "public.jpeg" as CFString, 1, nil) {
            CGImageDestinationAddImage(destination, cgImage, [kCGImageDestinationLossyCompressionQuality: compressionQuality] as CFDictionary)
            if CGImageDestinationFinalize(destination) {
                data = mutableData as Data
            }
        }
        return data
    }

    private func extractFrames(from url: URL, fps: Double, targetWidth: CGFloat) async -> [Data] {
        let asset = AVURLAsset(url: url)
        guard let duration = try? await asset.load(.duration) else { return [] }
        
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: targetWidth, height: 0)

        var frames: [Data] = []
        let frameCount = Int(duration.seconds * fps)
        let times = (0..<frameCount).map { CMTime(seconds: Double($0) / fps, preferredTimescale: 600) }

        do {
            for try await imageResult in generator.images(for: times) {
                if let data = UIImage(cgImage: try imageResult.image).jpegData(compressionQuality: 0.5) { frames.append(data) }
            }
        } catch { print("🔴 Failed to generate images: \(error)") }
        
        return frames
    }
    
    private func extractFrame(from url: URL, at timeInSeconds: Double) async -> Data? {
         let asset = AVURLAsset(url: url)
         let generator = AVAssetImageGenerator(asset: asset)
         generator.appliesPreferredTrackTransform = true
         let time = CMTime(seconds: timeInSeconds, preferredTimescale: 600)
        do {
            let cgImage = try await generator.image(at: time).image
            return UIImage(cgImage: cgImage).jpegData(compressionQuality: 0.7)
        } catch {
            print("🔴 Failed to extract single frame: \(error)")
            return nil
        }
     }
    
    func showAlert(title: String = "有缘无分", message: String) {
        self.errorTitle = title
        self.errorMessage = message
        self.showError = true
    }

    func cancelInspiration(andRestart: Bool) {
        inspirationTask?.cancel()
        inspirationTask = nil
        
        if inspirationState != .idle {
            speechService.stopSpeaking()
            inspirationState = .idle
            reasoningText = ""
            inspirationText = ""
            latency = nil
        }
        
        if andRestart && isAutoInspirationEnabled {
            triggerGlobalInspiration()
        }
    }
}
