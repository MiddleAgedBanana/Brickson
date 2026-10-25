import AVFoundation

extension VoiceDescriptor {
    init(_ voice: AVSpeechSynthesisVoice) {
        self.init(
            id: voice.identifier,
            name: voice.name,
            languageCode: voice.language,
            quality: VoiceQuality(voice.quality),
            isPersonalVoice: voice.voiceTraits.contains(.isPersonalVoice),
            isNovelty: voice.voiceTraits.contains(.isNoveltyVoice)
        )
    }
}

extension VoiceQuality {
    init(_ quality: AVSpeechSynthesisVoiceQuality) {
        switch quality {
        case .premium: self = .premium
        case .enhanced: self = .enhanced
        default: self = .standard
        }
    }
}
