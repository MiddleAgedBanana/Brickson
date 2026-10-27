/// Pure voice-selection logic, deliberately free of AVFoundation so it can be
/// unit-tested with plain values. `SpeechService` maps real
/// `AVSpeechSynthesisVoice`s into `VoiceDescriptor`s before calling this.

nonisolated struct VoiceDescriptor: Equatable, Sendable {
    let id: String
    let name: String
    /// BCP 47 code as reported by the system, e.g. "en-US".
    let languageCode: String
    let quality: VoiceQuality
    let isPersonalVoice: Bool
    /// Bells, Boing, Zarvox… — excluded from automatic selection unless
    /// nothing else exists.
    var isNovelty = false
}

nonisolated enum VoiceQuality: Int, Comparable, Sendable {
    case standard = 0
    case enhanced = 1
    case premium = 2

    static func < (lhs: VoiceQuality, rhs: VoiceQuality) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

nonisolated enum VoiceSelection {
    /// Precedence: the voice the person chose, if still installed → the
    /// Personal Voice Automatic already speaks in
    /// (`automaticPersonalVoiceID`), while it is listed → any Personal Voice
    /// (their own voice comes first) → the best-quality voice in the
    /// language the phrases are written in (premium > enhanced > standard) →
    /// any voice at all. Novelty voices (Bells, Boing…) rank below every real
    /// voice at each step: a communication app must not speak in a joke
    /// voice unless the person picked one or nothing else is installed.
    ///
    /// `automaticPersonalVoiceID` keeps Automatic on one Personal Voice when
    /// a device has several: the system's list order is not documented, so
    /// without it a second voice could take over between two launches
    /// (docs/DECISIONS.md, "Automatic keeps the person's Personal Voice").
    /// Only a Personal Voice counts there.
    ///
    /// `languageCode` is the language of the words being spoken (the app's
    /// current localization), not the device's region: an English phrase read
    /// by a French voice is hard to understand. Only its primary subtag
    /// counts, so "en" matches "en-US", "en-GB" and "en-AU".
    ///
    /// Returns nil only for an empty list, in which case the caller lets the
    /// system pick its default voice — speaking must never be blocked because
    /// a voice is missing.
    static func select(
        chosenID: String?,
        from voices: [VoiceDescriptor],
        languageCode: String = "en",
        automaticPersonalVoiceID: String? = nil
    ) -> VoiceDescriptor? {
        if let chosenID, let chosen = voices.first(where: { $0.id == chosenID }) {
            return chosen
        }
        if let automaticPersonalVoiceID,
           let kept = voices.first(where: { $0.id == automaticPersonalVoiceID && $0.isPersonalVoice }) {
            return kept
        }
        if let personal = voices.first(where: \.isPersonalVoice) {
            return personal
        }
        let language = primarySubtag(of: languageCode)
        let matching = voices.filter { primarySubtag(of: $0.languageCode) == language }
        return bestQuality(of: matching.filter { !$0.isNovelty })
            ?? voices.first { !$0.isNovelty }
            ?? bestQuality(of: matching)
            ?? voices.first
    }

    /// The voices a phrase may be spoken in. Without permission no Personal
    /// Voice is one, even if a list read before access was turned off still
    /// shows it: Apple makes personal voices available only while the app is
    /// allowed, and asking for one without permission may give silence
    /// (docs/DECISIONS.md, "A Personal Voice is used only while it is
    /// allowed"). The order is kept.
    static func usableVoices(_ voices: [VoiceDescriptor], personalVoiceAllowed: Bool) -> [VoiceDescriptor] {
        personalVoiceAllowed ? voices : voices.filter { !$0.isPersonalVoice }
    }

    private static func bestQuality(of voices: [VoiceDescriptor]) -> VoiceDescriptor? {
        voices.reduce(nil as VoiceDescriptor?) { best, candidate in
            guard let best else { return candidate }
            return candidate.quality > best.quality ? candidate : best
        }
    }

    /// "en-US" → "en"; "zh_Hant_TW" → "zh". Lowercased so "EN" matches "en".
    static func primarySubtag(of languageCode: String) -> String {
        let separators: Set<Character> = ["-", "_"]
        let primary = languageCode.split(whereSeparator: { separators.contains($0) }).first ?? ""
        return primary.lowercased()
    }
}
