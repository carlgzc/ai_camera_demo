// FileName: AICamera/ViewModels/AppSettings.swift
import SwiftUI

@MainActor
class AppSettings: ObservableObject {
    @Published var aiProvider: AIProvider { didSet { save() } }
    @Published var apiKey: String { didSet { save() } }
    @Published var openAIAPIKey: String { didSet { save() } }

    @Published var vlmModelID: String { didSet { save() } }
    @Published var openAIVLMModelID: String { didSet { save() } }
    @Published var imageEditModelID: String { didSet { save() } }
    @Published var openAIImageModelID: String { didSet { save() } }
    @Published var videoGenModelID: String { didSet { save() } }
    
    // Prompts
    @Published var doubaoAssistantPrompt: String { didSet { save() } }
    @Published var photographyMasterPrompt: String { didSet { save() } }
    @Published var poetPrompt: String { didSet { save() } }
    @Published var translationAssistantPrompt: String { didSet { save() } }
    @Published var encyclopediaPrompt: String { didSet { save() } }
    @Published var storytellerPrompt: String { didSet { save() } }
    @Published var healthAssistantPrompt: String { didSet { save() } }
    @Published var imageEditPrompt: String { didSet { save() } }
    @Published var videoStoryPrompt: String { didSet { save() } }
    @Published var highlightReelPrompt: String { didSet { save() } }
    
    // Feature Toggles
    @Published var isDeepThinkingEnabled: Bool { didSet { save() } }
    @Published var isAutoReadEnabled: Bool { didSet { save() } }

    private let userDefaults = UserDefaults.standard
    
    private enum Keys {
        static let aiProvider = "aiProvider_v3"
        static let apiKey = "doubaoAPIKey_v3"
        static let openAIAPIKey = "openAIAPIKey_v3"
        static let vlmModelID = "vlmModelID_v3"
        static let openAIVLMModelID = "openAIVLMModelID_v3"
        static let imageEditModelID = "imageEditModelID_v3"
        static let openAIImageModelID = "openAIImageModelID_v3"
        static let videoGenModelID = "videoGenModelID_v3"
        static let doubaoAssistantPrompt = "doubaoAssistantPrompt_v3"
        static let photographyMasterPrompt = "photographyMasterPrompt_v3"
        static let poetPrompt = "poetPrompt_v3"
        static let translationAssistantPrompt = "translationAssistantPrompt_v3"
        static let encyclopediaPrompt = "encyclopediaPrompt_v3"
        static let storytellerPrompt = "storytellerPrompt_v3"
        static let healthAssistantPrompt = "healthAssistantPrompt_v3"
        static let imageEditPrompt = "imageEditPrompt_v3"
        static let videoStoryPrompt = "videoStoryPrompt_v3"
        static let highlightReelPrompt = "highlightReelPrompt_v1"
        static let isDeepThinkingEnabled = "isDeepThinkingEnabled_v3"
        static let isAutoReadEnabled = "isAutoReadEnabled_v3"
    }
    
    // ✅ 优化: 更新 Prompts，指示 AI 寻找视觉标记，而不是文字坐标。
    struct DefaultValues {
        static let aiProvider: AIProvider = .doubao
        static let apiKey = ""
        static let openAIAPIKey = ""
        static let vlmModelID = "ep-20250719131318-27rck"
        static let openAIVLMModelID = "gpt-4o"
        static let imageEditModelID = "ep-20250725101032-2zcfj"
        static let openAIImageModelID = "dall-e-3"
        static let videoGenModelID = "doubao-seedance-1-0-pro-250528"
        
        static let secretInstruction = "你的回复必须看起来像是对整个画面的自然感悟。如果画面中出现一个微小的、半透明的蓝色圆圈标记，请将其作为你分析的重点区域，但绝不允许在你的最终回复中以任何形式提及这个标记、焦点、或任何与坐标相关的信息。"
        
        static let doubaoAssistant = "你的任务是：1. 深入分析眼前的画面，洞察其特色、情感或潜在的矛盾冲突。2. 基于你的分析，选择一个最合适的专家角色（例如摄影师、文字诗人、语言学者、博物学者、故事大师、健康助手等）。3. 直接以该角色的身份，用Markdown格式，给出你对画面理解。\(secretInstruction)"
        static let photographyMaster = "作为一位光影诗人，请根据眼前画面的光影、色彩与构图特点，直接给出最核心的拍摄技巧或构图方法论。\(secretInstruction) 请使用Markdown格式输出。"
        static let healthAssistant = "作为一位健康生活禅师，请根据眼前画面的特点，提供一条相关的、可执行的健康建议。\(secretInstruction) 请使用Markdown格式输出。"
        static let poet = "作为一位文字诗人，请将眼前景象的特点与意境化为一首短诗。\(secretInstruction) 请使用Markdown格式输出。"
        static let translationAssistant = "作为一位语言学者，请识别画面中的外文，并将其翻译成中文，或介绍与该语言文字相关的背景故事或冷知识。\(secretInstruction) 请使用Markdown格式输出。"
        static let encyclopedia = "作为一位博物学者，请识别眼前场景或物体的特点，提供一个相关的、有趣的冷知识或背景信息。\(secretInstruction) 请使用Markdown格式输出。"
        static let storyteller = "作为一位织梦者，请根据眼前画面的特点，构思一个充满悬念或想象力的微型故事开头。\(secretInstruction) 请使用Markdown格式输出。"
        static let imageEdit = "请根据场景生成一个宫崎骏风格的卡通图片"
        static let videoStory = "请化身为一位电影导演，用一句话的电影化描述（logline）来概括这张图片的核心故事或情感瞬间，这将作为视频创作的剧本。"
        static let highlightReel = "你是一位顶级的社交媒体视频编剧。请根据我提供的这一系列图片（它们按时间顺序排列），讲述一个连贯、引人入- 入胜的故事或总结这次经历。你的输出需要包含三部分：一个吸引人的'title'，一段适合作为视频旁白的'caption'，以及一组'hashtags'（数组形式）。请严格使用JSON格式返回结果。"
    }

    init() {
        let storedProvider = userDefaults.string(forKey: Keys.aiProvider)
        aiProvider = storedProvider.flatMap(AIProvider.init) ?? DefaultValues.aiProvider
        apiKey = userDefaults.string(forKey: Keys.apiKey) ?? DefaultValues.apiKey
        openAIAPIKey = userDefaults.string(forKey: Keys.openAIAPIKey) ?? DefaultValues.openAIAPIKey
        vlmModelID = userDefaults.string(forKey: Keys.vlmModelID) ?? DefaultValues.vlmModelID
        openAIVLMModelID = userDefaults.string(forKey: Keys.openAIVLMModelID) ?? DefaultValues.openAIVLMModelID
        imageEditModelID = userDefaults.string(forKey: Keys.imageEditModelID) ?? DefaultValues.imageEditModelID
        openAIImageModelID = userDefaults.string(forKey: Keys.openAIImageModelID) ?? DefaultValues.openAIImageModelID
        videoGenModelID = userDefaults.string(forKey: Keys.videoGenModelID) ?? DefaultValues.videoGenModelID
        doubaoAssistantPrompt = userDefaults.string(forKey: Keys.doubaoAssistantPrompt) ?? DefaultValues.doubaoAssistant
        photographyMasterPrompt = userDefaults.string(forKey: Keys.photographyMasterPrompt) ?? DefaultValues.photographyMaster
        poetPrompt = userDefaults.string(forKey: Keys.poetPrompt) ?? DefaultValues.poet
        translationAssistantPrompt = userDefaults.string(forKey: Keys.translationAssistantPrompt) ?? DefaultValues.translationAssistant
        encyclopediaPrompt = userDefaults.string(forKey: Keys.encyclopediaPrompt) ?? DefaultValues.encyclopedia
        storytellerPrompt = userDefaults.string(forKey: Keys.storytellerPrompt) ?? DefaultValues.storyteller
        healthAssistantPrompt = userDefaults.string(forKey: Keys.healthAssistantPrompt) ?? DefaultValues.healthAssistant
        imageEditPrompt = userDefaults.string(forKey: Keys.imageEditPrompt) ?? DefaultValues.imageEdit
        videoStoryPrompt = userDefaults.string(forKey: Keys.videoStoryPrompt) ?? DefaultValues.videoStory
        highlightReelPrompt = userDefaults.string(forKey: Keys.highlightReelPrompt) ?? DefaultValues.highlightReel
        isDeepThinkingEnabled = userDefaults.object(forKey: Keys.isDeepThinkingEnabled) as? Bool ?? false
        isAutoReadEnabled = userDefaults.object(forKey: Keys.isAutoReadEnabled) as? Bool ?? false
    }
    
    func save() {
        userDefaults.set(aiProvider.rawValue, forKey: Keys.aiProvider)
        userDefaults.set(apiKey, forKey: Keys.apiKey)
        userDefaults.set(openAIAPIKey, forKey: Keys.openAIAPIKey)
        userDefaults.set(vlmModelID, forKey: Keys.vlmModelID)
        userDefaults.set(openAIVLMModelID, forKey: Keys.openAIVLMModelID)
        userDefaults.set(imageEditModelID, forKey: Keys.imageEditModelID)
        userDefaults.set(openAIImageModelID, forKey: Keys.openAIImageModelID)
        userDefaults.set(videoGenModelID, forKey: Keys.videoGenModelID)
        userDefaults.set(doubaoAssistantPrompt, forKey: Keys.doubaoAssistantPrompt)
        userDefaults.set(photographyMasterPrompt, forKey: Keys.photographyMasterPrompt)
        userDefaults.set(poetPrompt, forKey: Keys.poetPrompt)
        userDefaults.set(translationAssistantPrompt, forKey: Keys.translationAssistantPrompt)
        userDefaults.set(encyclopediaPrompt, forKey: Keys.encyclopediaPrompt)
        userDefaults.set(storytellerPrompt, forKey: Keys.storytellerPrompt)
        userDefaults.set(healthAssistantPrompt, forKey: Keys.healthAssistantPrompt)
        userDefaults.set(imageEditPrompt, forKey: Keys.imageEditPrompt)
        userDefaults.set(videoStoryPrompt, forKey: Keys.videoStoryPrompt)
        userDefaults.set(highlightReelPrompt, forKey: Keys.highlightReelPrompt)
        userDefaults.set(isDeepThinkingEnabled, forKey: Keys.isDeepThinkingEnabled)
        userDefaults.set(isAutoReadEnabled, forKey: Keys.isAutoReadEnabled)
    }
    
    func resetToDefaults() {
        aiProvider = DefaultValues.aiProvider
        apiKey = DefaultValues.apiKey
        openAIAPIKey = DefaultValues.openAIAPIKey
        vlmModelID = DefaultValues.vlmModelID
        openAIVLMModelID = DefaultValues.openAIVLMModelID
        imageEditModelID = DefaultValues.imageEditModelID
        openAIImageModelID = DefaultValues.openAIImageModelID
        videoGenModelID = DefaultValues.videoGenModelID
        doubaoAssistantPrompt = DefaultValues.doubaoAssistant
        photographyMasterPrompt = DefaultValues.photographyMaster
        poetPrompt = DefaultValues.poet
        translationAssistantPrompt = DefaultValues.translationAssistant
        encyclopediaPrompt = DefaultValues.encyclopedia
        storytellerPrompt = DefaultValues.storyteller
        healthAssistantPrompt = DefaultValues.healthAssistant
        imageEditPrompt = DefaultValues.imageEdit
        videoStoryPrompt = DefaultValues.videoStory
        highlightReelPrompt = DefaultValues.highlightReel
        isDeepThinkingEnabled = false
        isAutoReadEnabled = false
        save()
    }
    
    func prompt(for persona: InspirationPersona) -> String {
        switch persona {
        case .doubaoAssistant: return doubaoAssistantPrompt
        case .photographyMaster: return photographyMasterPrompt
        case .poet: return poetPrompt
        case .translationAssistant: return translationAssistantPrompt
        case .encyclopedia: return encyclopediaPrompt
        case .storyteller: return storytellerPrompt
        case .healthAssistant: return healthAssistantPrompt
        }
    }
}
