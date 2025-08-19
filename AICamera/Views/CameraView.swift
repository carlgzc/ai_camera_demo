// FileName: AICamera/Views/CameraView.swift
import SwiftUI
import SwiftData

struct CameraView: View {
    @StateObject private var cameraViewModel = CameraViewModel()
    @EnvironmentObject var appSettings: AppSettings
    @Environment(\.modelContext) private var modelContext
    
    @Query(sort: \CaptureTask.creationDate, order: .reverse) private var captureTasks: [CaptureTask]

    @State private var isShowingSettings = false
    @State private var isShowingAlbum = false
    
    @State private var isShutterAnimating = false
    @State private var orientation = UIDevice.current.orientation

    var body: some View {
        ZStack {
            CameraPreview(session: cameraViewModel.previewSession, cameraPosition: cameraViewModel.cameraPosition) { point in
                cameraViewModel.focus(at: point)
            }
            .ignoresSafeArea()
            .onAppear {
                cameraViewModel.configure(settings: appSettings, modelContext: modelContext, allTasks: captureTasks)
            }
            .onDisappear { cameraViewModel.onDisappear() }
            .onChange(of: appSettings.aiProvider) { cameraViewModel.updateAIService() }
            .onChange(of: appSettings.openAIAPIKey) { cameraViewModel.updateAIService() }
            .onChange(of: appSettings.apiKey) { cameraViewModel.updateAIService() }
            .onChange(of: captureTasks) {
                cameraViewModel.latestTaskForPreview = captureTasks.first
            }

            Group {
                if orientation.isLandscape {
                    landscapeLayout
                } else {
                    portraitLayout
                }
            }
            .animation(.easeInOut, value: orientation)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            self.orientation = UIDevice.current.orientation
        }
        .sheet(isPresented: $isShowingAlbum) {
            AlbumView()
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView().environmentObject(appSettings)
        }
        .alert(isPresented: $cameraViewModel.showError) {
            Alert(title: Text(cameraViewModel.errorTitle), message: Text(cameraViewModel.errorMessage), dismissButton: .default(Text("了然")))
        }
    }
    
    private var portraitLayout: some View {
        VStack {
            topControls
            Spacer()
            inspirationAndControls
        }
        .padding(.top, 10)
    }
    
    private var landscapeLayout: some View {
        HStack {
            Spacer()
            inspirationAndControls
            sideControls
        }
        .padding(.horizontal)
    }
    
    private var inspirationAndControls: some View {
        VStack(spacing: 20) {
            ZStack {
                Color.clear.frame(height: 150).padding(.horizontal, 30)

                if cameraViewModel.inspirationState != .idle {
                    InspirationView(
                        state: $cameraViewModel.inspirationState,
                        reasoningText: cameraViewModel.reasoningText,
                        inspirationText: cameraViewModel.inspirationText,
                        latency: cameraViewModel.latency,
                        onDismiss: {
                            // ✅ 修复: 调用新的方法，在关闭后立即重启灵感分析
                            cameraViewModel.cancelInspiration(andRestart: true)
                        }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: cameraViewModel.inspirationState)
            
            PersonaPicker(selection: $cameraViewModel.selectedPersona)
            
            HStack(alignment: .center, spacing: 20) {
                albumButton
                Spacer()
                captureButton
                Spacer()
                switchCameraButton
            }
            .padding(.horizontal, 20)
            .padding(.bottom, orientation.isLandscape ? 10 : 20)
            .frame(height: 90)
        }
    }

    private var topControls: some View {
        HStack {
            Spacer()
            
            autoInspirationButton
            
            Button(action: { appSettings.isAutoReadEnabled.toggle() }) {
                Image(systemName: appSettings.isAutoReadEnabled ? "ear.and_waveform" : "ear")
                    .modifier(ControlButtonModifier())
                    .foregroundColor(appSettings.isAutoReadEnabled ? .accentColor : .white)
            }
            
            Button(action: { isShowingSettings = true }) {
                Image(systemName: "gearshape.fill")
                    .modifier(ControlButtonModifier())
            }
            .padding(.trailing)
        }
        .padding(.top)
    }

    private var sideControls: some View {
        VStack {
            Button(action: { isShowingSettings = true }) {
                Image(systemName: "gearshape.fill")
                    .modifier(ControlButtonModifier())
            }
            
            Button(action: { appSettings.isAutoReadEnabled.toggle() }) {
                Image(systemName: appSettings.isAutoReadEnabled ? "ear.and_waveform" : "ear")
                    .modifier(ControlButtonModifier())
                    .foregroundColor(appSettings.isAutoReadEnabled ? .accentColor : .white)
            }
            
            autoInspirationButton
            
            Spacer()
        }
        .padding(.top)
    }
    
    private var autoInspirationButton: some View {
        Button(action: { cameraViewModel.isAutoInspirationEnabled.toggle() }) {
            Image(systemName: "wand.and.stars.inverse")
                .modifier(ControlButtonModifier())
                .foregroundColor(cameraViewModel.isAutoInspirationEnabled ? .yellow : .white)
                .scaleEffect(cameraViewModel.isAutoInspirationEnabled ? 1.2 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.5), value: cameraViewModel.isAutoInspirationEnabled)
        }
    }
    
    private var albumButton: some View {
        Button(action: { isShowingAlbum = true }) {
            if let lastTask = cameraViewModel.latestTaskForPreview, let image = lastTask.originalImage {
                Image(uiImage: image)
                    .resizable().scaledToFill().frame(width: 55, height: 55)
                    .cornerRadius(8).overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white, lineWidth: 1))
            } else {
                Image(systemName: "rectangle.stack")
                    .font(.largeTitle).frame(width: 55, height: 55)
                    .background(Color.black.opacity(0.3)).foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
    
    private var switchCameraButton: some View {
        Button(action: cameraViewModel.switchCamera) {
            Image(systemName: "arrow.triangle.2.circlepath.camera.fill")
                .font(.largeTitle).padding(15)
                .background(Color.black.opacity(0.3)).foregroundColor(.white)
                .clipShape(Circle())
        }
        .frame(width: 55, height: 55)
    }
    
    private var captureButton: some View {
        let hapticGenerator = UIImpactFeedbackGenerator(style: .medium)
        
        let gesture = DragGesture(minimumDistance: 0)
            .onChanged { _ in
                if !cameraViewModel.isRecording {
                    cameraViewModel.startRecordingTimer()
                }
            }
            .onEnded { _ in
                if cameraViewModel.isRecording {
                    cameraViewModel.stopRecording()
                } else {
                    hapticGenerator.impactOccurred()
                    cameraViewModel.cancelRecordingTimer()
                    cameraViewModel.capturePhoto()
                    
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        isShutterAnimating = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            isShutterAnimating = false
                        }
                    }
                }
            }

        return ZStack {
            Circle()
                .fill(cameraViewModel.isRecording ? .red : .white)
                .frame(width: 70, height: 70)
                .scaleEffect(cameraViewModel.isRecording ? 0.8 : 1.0)
            
            Circle()
                .stroke(Color.white, lineWidth: 4)
                .frame(width: 80, height: 80)
                .scaleEffect(isShutterAnimating ? 0.85 : 1.0)
        }
        .gesture(gesture)
        .animation(.spring(), value: cameraViewModel.isRecording)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isShutterAnimating)
    }
}

struct ControlButtonModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.title2)
            .foregroundColor(.white)
            .padding(12)
            .background(Color.black.opacity(0.4))
            .clipShape(Circle())
    }
}

struct PersonaPicker: View {
    @Binding var selection: InspirationPersona
    
    private let hapticGenerator = UISelectionFeedbackGenerator()
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(InspirationPersona.allCases) { persona in
                    Button(action: {
                        selection = persona
                        hapticGenerator.selectionChanged()
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: persona.systemImage)
                            Text(persona.rawValue)
                        }
                        .font(.caption).fontWeight(.semibold)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(selection == persona ? Color.white : Color.black.opacity(0.4))
                        .foregroundColor(selection == persona ? .black : .white)
                        .cornerRadius(20)
                        .animation(.easeInOut, value: selection)
                    }
                }
            }.padding(.horizontal)
        }
    }
}
