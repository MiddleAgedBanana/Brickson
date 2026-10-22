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

/// One place in the voice list while Voice Settings is open
/// (`VoiceList.keepingPlaces`).
nonisolated enum VoiceListPlace: Equatable, Identifiable, Sendable {
    /// A voice that can be heard and chosen.
    case voice(VoiceRow)
    /// A voice listed when the screen opened that is no longer offered: its
    /// place is kept, with passive words in it, until the screen closes.
    case gone(VoiceRow)

    var id: String {
        switch self {
        case .voice(let row), .gone(let row): row.id
        }
    }
}

/// Which voices Settings offers, in what order, and what each button is
/// called. Pure, so the order and the uniqueness of names are tested.
///
/// The order never depends on what is used (AGENTS.md, invariant 8):
/// Automatic first, then every Personal Voice by name, then the system voices in the
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
        // iOS promises no order, so sort, or two Personal Voices could swap
        // places between launches.
        let personal = voices
            .filter(\.isPersonalVoice)
            .sorted { lhs, rhs in
                if lhs.name != rhs.name { return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending }
                return lhs.id < rhs.id
            }
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

    /// The rows in the places they had when the screen opened (`shown`),
    /// so a voice that arrives or leaves while Voice Settings is open moves
    /// no Hear or Use button under a resting pointer (AGENTS.md,
    /// invariant 10). A voice that is gone keeps its place as passive words;
    /// a voice that arrives goes after every row already shown. Each voice
    /// still shown takes its current row, so which one is chosen is never
    /// out of date. The next time the screen opens, `rows` alone decides
    /// the order again.
    static func keepingPlaces(of shown: [VoiceRow], in current: [VoiceRow]) -> [VoiceListPlace] {
        let currentByID = Dictionary(current.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let shownIDs = Set(shown.map(\.id))
        let kept = shown.map { row in
            currentByID[row.id].map(VoiceListPlace.voice) ?? .gone(row)
        }
        let arrived = current
            .filter { !shownIDs.contains($0.id) }
            .map(VoiceListPlace.voice)
        return kept + arrived
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
