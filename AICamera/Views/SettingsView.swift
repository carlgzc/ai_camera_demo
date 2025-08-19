// FileName: AICamera/Views/SettingsView.swift
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @Environment(\.dismiss) var dismiss
    
    @State private var tempAiProvider: AIProvider = .doubao
    @State private var tempApiKey: String = ""
    @State private var tempOpenAIAPIKey: String = ""
    
    @State private var tempVlmModelID: String = ""
    @State private var tempOpenAIVLMModelID: String = ""
    @State private var tempImageEditModelID: String = ""
    @State private var tempOpenAIImageModelID: String = ""
    @State private var tempVideoGenModelID: String = ""
    
    @State private var tempIsDeepThinkingEnabled: Bool = false
    
    @State private var tempDoubaoAssistantPrompt: String = ""
    @State private var tempPhotographyMasterPrompt: String = ""
    @State private var tempPoetPrompt: String = ""
    // ✅ 修改: 绑定新的 Prompt
    @State private var tempTranslationAssistantPrompt: String = ""
    @State private var tempEncyclopediaPrompt: String = ""
    @State private var tempStorytellerPrompt: String = ""
    @State private var tempHealthAssistantPrompt: String = ""
    @State private var tempImageEditPrompt: String = ""
    @State private var tempVideoStoryPrompt: String = ""
    
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("AI 服务商")) {
                    Picker("选择服务商", selection: $tempAiProvider) {
                        ForEach(AIProvider.allCases) { provider in
                            Text(provider.rawValue).tag(provider)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if tempAiProvider == .doubao {
                    doubaoSettings
                } else {
                    openAISettings
                }
                
                Section(header: Text("灵感角色 Prompts")) {
                    promptEditor(for: .doubaoAssistant, text: $tempDoubaoAssistantPrompt)
                    promptEditor(for: .photographyMaster, text: $tempPhotographyMasterPrompt)
                    promptEditor(for: .poet, text: $tempPoetPrompt)
                    // ✅ 修改: 显示新的 Prompt 编辑器
                    promptEditor(for: .translationAssistant, text: $tempTranslationAssistantPrompt)
                    promptEditor(for: .encyclopedia, text: $tempEncyclopediaPrompt)
                    promptEditor(for: .storyteller, text: $tempStorytellerPrompt)
                    promptEditor(for: .healthAssistant, text: $tempHealthAssistantPrompt)
                }
                
                Section {
                    Button("恢复默认设置", role: .destructive, action: resetSettings)
                }
            }
            .onAppear(perform: loadCurrentSettings)
            .navigationTitle("应用设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消", action: dismiss.callAsFunction) }
                ToolbarItem(placement: .confirmationAction) { Button("保存", action: saveSettings) }
            }
            .alert(alertMessage, isPresented: $showAlert) {
                Button("好的") {
                    if alertMessage.contains("成功") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private var doubaoSettings: some View {
        Group {
            Section(header: Text("豆包 API 配置"), footer: Text("API Key 用于访问豆包大模型服务。")) {
                SecureField("豆包 API Key", text: $tempApiKey)
            }
            
            Section(header: Text("豆包模型 ID")) {
                VStack(alignment: .leading) {
                    Text("多模态理解 (VLM)").font(.caption).foregroundColor(.secondary)
                    TextField("Model ID", text: $tempVlmModelID).autocorrectionDisabled().textInputAutocapitalization(.never)
                    Toggle("启用深度思考模式", isOn: $tempIsDeepThinkingEnabled).padding(.top, 4)
                    Text("开启后，AI在回答前会进行更深入的思考，这可能会增加响应时间但提高回答质量。").font(.caption2).foregroundColor(.gray)
                }
                VStack(alignment: .leading) {
                    Text("图像编辑").font(.caption).foregroundColor(.secondary)
                    TextField("Model ID", text: $tempImageEditModelID).autocorrectionDisabled().textInputAutocapitalization(.never)
                }
                VStack(alignment: .leading) {
                    Text("视频生成").font(.caption).foregroundColor(.secondary)
                    TextField("Model ID", text: $tempVideoGenModelID).autocorrectionDisabled().textInputAutocapitalization(.never)
                }
            }
            
            Section(header: Text("核心功能 Prompts (豆包专用)")) {
                VStack(alignment: .leading) {
                    Text("动漫风格图 Prompt").font(.caption).foregroundColor(.secondary)
                    TextEditor(text: $tempImageEditPrompt).frame(minHeight: 80)
                }
                VStack(alignment: .leading) {
                    Text("故事视频剧本 Prompt").font(.caption).foregroundColor(.secondary)
                    TextEditor(text: $tempVideoStoryPrompt).frame(minHeight: 80)
                }
            }
        }
    }

    @ViewBuilder
    private var openAISettings: some View {
        Group {
            Section(header: Text("OpenAI API 配置")) {
                SecureField("OpenAI API Key", text: $tempOpenAIAPIKey)
            }
            Section(header: Text("OpenAI 模型 ID")) {
                VStack(alignment: .leading) {
                    Text("多模态理解 (VLM)").font(.caption).foregroundColor(.secondary)
                    TextField("Model ID", text: $tempOpenAIVLMModelID).autocorrectionDisabled().textInputAutocapitalization(.never)
                    Text("例如：gpt-4o, gpt-4-turbo").font(.caption2).foregroundColor(.gray)
                }
                VStack(alignment: .leading) {
                    Text("图像生成 (DALL·E)").font(.caption).foregroundColor(.secondary)
                    TextField("Model ID", text: $tempOpenAIImageModelID).autocorrectionDisabled().textInputAutocapitalization(.never)
                    Text("例如：dall-e-3").font(.caption2).foregroundColor(.gray)
                }
            }
        }
    }
    
    @ViewBuilder
    private func promptEditor(for persona: InspirationPersona, text: Binding<String>) -> some View {
        VStack(alignment: .leading) {
            HStack {
                Image(systemName: persona.systemImage)
                Text(persona.rawValue)
            }.font(.caption).foregroundColor(.secondary)
            TextEditor(text: text).frame(minHeight: 80)
        }
    }
    
    private func loadCurrentSettings() {
        tempAiProvider = settings.aiProvider
        tempApiKey = settings.apiKey
        tempOpenAIAPIKey = settings.openAIAPIKey
        tempVlmModelID = settings.vlmModelID
        tempOpenAIVLMModelID = settings.openAIVLMModelID
        tempImageEditModelID = settings.imageEditModelID
        tempOpenAIImageModelID = settings.openAIImageModelID
        tempVideoGenModelID = settings.videoGenModelID
        tempIsDeepThinkingEnabled = settings.isDeepThinkingEnabled
        tempDoubaoAssistantPrompt = settings.doubaoAssistantPrompt
        tempPhotographyMasterPrompt = settings.photographyMasterPrompt
        tempPoetPrompt = settings.poetPrompt
        // ✅ 修改: 加载新的 Prompt
        tempTranslationAssistantPrompt = settings.translationAssistantPrompt
        tempEncyclopediaPrompt = settings.encyclopediaPrompt
        tempStorytellerPrompt = settings.storytellerPrompt
        tempHealthAssistantPrompt = settings.healthAssistantPrompt
        tempImageEditPrompt = settings.imageEditPrompt
        tempVideoStoryPrompt = settings.videoStoryPrompt
    }
    
    private func saveSettings() {
        settings.aiProvider = tempAiProvider
        settings.apiKey = tempApiKey
        settings.openAIAPIKey = tempOpenAIAPIKey
        settings.vlmModelID = tempVlmModelID
        settings.openAIVLMModelID = tempOpenAIVLMModelID
        settings.imageEditModelID = tempImageEditModelID
        settings.openAIImageModelID = tempOpenAIImageModelID
        settings.videoGenModelID = tempVideoGenModelID
        settings.isDeepThinkingEnabled = tempIsDeepThinkingEnabled
        settings.doubaoAssistantPrompt = tempDoubaoAssistantPrompt
        settings.photographyMasterPrompt = tempPhotographyMasterPrompt
        settings.poetPrompt = tempPoetPrompt
        // ✅ 修改: 保存新的 Prompt
        settings.translationAssistantPrompt = tempTranslationAssistantPrompt
        settings.encyclopediaPrompt = tempEncyclopediaPrompt
        settings.storytellerPrompt = tempStorytellerPrompt
        settings.healthAssistantPrompt = tempHealthAssistantPrompt
        settings.imageEditPrompt = tempImageEditPrompt
        settings.videoStoryPrompt = tempVideoStoryPrompt
        
        alertMessage = "设置已保存成功！"
        showAlert = true
    }
    
    private func resetSettings() {
        settings.resetToDefaults()
        loadCurrentSettings()
        alertMessage = "已恢复为默认设置！"
        showAlert = true
    }
}
