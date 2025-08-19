// FileName: Services/SpeechService.swift
import AVFoundation

@MainActor
class SpeechService: NSObject, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    private let bestVoice: AVSpeechSynthesisVoice?

    override init() {
        self.bestVoice = SpeechService.findBestVoice(forLanguage: "zh-CN")
        super.init()
        synthesizer.delegate = self
        
        if let voice = bestVoice {
            print("✅ [SpeechService] Found best voice: \(voice.name) (\(voice.quality.rawValue))")
        } else {
            print("⚠️ [SpeechService] Could not find an enhanced or premium voice. Using default.")
        }
    }

    func speak(text: String) {
        stopSpeaking()
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = bestVoice ?? AVSpeechSynthesisVoice(language: "zh-CN")
        utterance.rate = 0.48
        utterance.pitchMultiplier = 1.0
        utterance.postUtteranceDelay = 0.2
        
        synthesizer.speak(utterance)
    }

    func stopSpeaking() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }
    
    private static func findBestVoice(forLanguage languageCode: String) -> AVSpeechSynthesisVoice? {
        let voices = AVSpeechSynthesisVoice.speechVoices()
        let languageVoices = voices.filter { $0.language == languageCode }
        
        if let premiumVoice = languageVoices.first(where: { $0.quality == .premium }) {
            return premiumVoice
        }
        
        if let enhancedVoice = languageVoices.first(where: { $0.quality == .enhanced }) {
            return enhancedVoice
        }
        
        return languageVoices.first
    }
    
    // MARK: - AVSpeechSynthesizerDelegate (日志输出)
    
    // ✅ FIX: 将代理方法标记为 nonisolated 以满足协议要求
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        print("✅ [SpeechService] Finished speaking.")
    }
    
    // ✅ FIX: 将代理方法标记为 nonisolated 以满足协议要求
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        print("🛑 [SpeechService] Speech cancelled.")
    }
}
