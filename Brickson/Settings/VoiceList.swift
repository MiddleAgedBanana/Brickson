import Foundation

/// One row of the voice list in Settings.
nonisolated struct VoiceRow: Equatable, Identifiable, Sendable {
    /// The voice identifier saved as the choice; nil is Automatic.
    let voiceID: String?
    let name: String
    /// Quality and language, such as "Enhanced, English (United Kingdom)".
    let detail: String
    let isPersonalVoice: Bool
    let isSelected: Bool
    /// Names for the two buttons, unique across the whole list so Voice
    /// Control and Full Keyboard Access can tell every row apart.
    let hearLabel: String
    let useLabel: String

    /// Never collides with a voice whose identifier happens to be "automatic".
    var id: String { voiceID.map { "voice:\($0)" } ?? "automatic" }
}

/// Which voices Settings offers, in what order, and what each button is
/// called. Pure, so the order and the uniqueness of names are tested.
///
/// The order never depends on what is used (AGENTS.md, invariant 8):
/// Automatic first, then every Personal Voice, then the system voices in the
/// language Brickson's words are written in, best quality first, then by
/// name. Novelty voices (Bells, Boing and others) are never offered: a
/// communication app must not be one stray activation away from a joke
/// voice. Voices in other languages are left out, because an English phrase
/// read by a French voice is hard to understand (`VoiceSelection`).
nonisolated enum VoiceList {
    static func rows(
        for voices: [VoiceDescriptor],
        selectedID: String?,
        languageCode: String,
        describeLanguage: (String) -> String = { $0 }
    ) -> [VoiceRow] {
        let language = VoiceSelection.primarySubtag(of: languageCode)
        let personal = voices.filter(\.isPersonalVoice)
        let system = voices
            .filter { !$0.isPersonalVoice && !$0.isNovelty }
            .filter { VoiceSelection.primarySubtag(of: $0.languageCode) == language }
            .sorted { lhs, rhs in
                if lhs.quality != rhs.quality { return lhs.quality > rhs.quality }
                if lhs.name != rhs.name { return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending }
                return lhs.id < rhs.id
            }
        let offered = personal + system
        let selectionIsOffered = offered.contains { $0.id == selectedID }

        var rows = [VoiceRow(
            voiceID: nil,
            name: String(localized: "Automatic"),
            detail: String(localized: "Your Personal Voice when it is allowed, otherwise the best voice on this device"),
            isPersonalVoice: false,
            isSelected: !selectionIsOffered,
            hearLabel: String(localized: "Hear Automatic"),
            useLabel: String(localized: "Use Automatic")
        )]

        // Names that would otherwise repeat get their quality, then their
        // language, then a number, until each one is unique.
        var taken: Set<String> = [rows[0].name.lowercased()]
        for voice in offered {
            let quality = qualityName(voice)
            let languageName = describeLanguage(voice.languageCode)
            let candidates = [
                voice.name,
                "\(voice.name), \(quality)",
                "\(voice.name), \(quality), \(languageName)",
            ]
            var label = candidates.first { !taken.contains($0.lowercased()) }
            var number = 2
            while label == nil {
                let numbered = "\(candidates[2]) \(number)"
                if !taken.contains(numbered.lowercased()) { label = numbered }
                number += 1
            }
            let unique = label!
            taken.insert(unique.lowercased())

            rows.append(VoiceRow(
                voiceID: voice.id,
                name: voice.name,
                detail: voice.isPersonalVoice
                    ? String(localized: "Personal Voice")
                    : "\(quality), \(languageName)",
                isPersonalVoice: voice.isPersonalVoice,
                isSelected: voice.id == selectedID,
                hearLabel: String(localized: "Hear \(unique)"),
                useLabel: String(localized: "Use \(unique)")
            ))
        }
        return rows
    }

    /// True when a voice was chosen but is no longer offered (deleted, or a
    /// Personal Voice whose permission was turned off). Brickson then speaks
    /// with Automatic's choice, and Settings says so.
    static func chosenVoiceIsMissing(selectedID: String?, from voices: [VoiceDescriptor]) -> Bool {
        guard let selectedID else { return false }
        return !voices.contains { $0.id == selectedID && !$0.isNovelty }
    }

    private static func qualityName(_ voice: VoiceDescriptor) -> String {
        if voice.isPersonalVoice { return String(localized: "Personal Voice") }
        switch voice.quality {
        case .premium: return String(localized: "Premium")
        case .enhanced: return String(localized: "Enhanced")
        case .standard: return String(localized: "Standard")
        }
    }
}
