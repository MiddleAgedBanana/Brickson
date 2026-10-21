import Foundation
import Testing
@testable import Brickson

/// The voice list's order must never depend on use (invariant 8), must never
/// offer a joke voice, and every button must have a unique name so Voice
/// Control and Full Keyboard Access can reach each one.
struct VoiceListTests {
    private let voices = [
        VoiceDescriptor(id: "samantha", name: "Samantha", languageCode: "en-US", quality: .standard, isPersonalVoice: false),
        VoiceDescriptor(id: "samantha-enhanced", name: "Samantha", languageCode: "en-US", quality: .enhanced, isPersonalVoice: false),
        VoiceDescriptor(id: "daniel", name: "Daniel", languageCode: "en-GB", quality: .premium, isPersonalVoice: false),
        VoiceDescriptor(id: "thomas", name: "Thomas", languageCode: "fr-FR", quality: .premium, isPersonalVoice: false),
        VoiceDescriptor(id: "bells", name: "Bells", languageCode: "en-US", quality: .standard, isPersonalVoice: false, isNovelty: true),
        VoiceDescriptor(id: "mine", name: "My Voice", languageCode: "en-US", quality: .premium, isPersonalVoice: true),
    ]

    @Test func automaticComesFirstThenPersonalVoicesThenTheBestSystemVoices() {
        let rows = VoiceList.rows(for: voices, selectedID: nil, languageCode: "en")

        #expect(rows.map(\.voiceID) == [nil, "mine", "daniel", "samantha-enhanced", "samantha"])
    }

    @Test func noveltyVoicesAndOtherLanguagesAreNeverOffered() {
        let ids = VoiceList.rows(for: voices, selectedID: nil, languageCode: "en").map(\.voiceID)

        #expect(!ids.contains("bells"))
        #expect(!ids.contains("thomas"))
    }

    /// The order comes from the voices themselves, so choosing one never
    /// moves any row.
    @Test func choosingAVoiceMovesNoRow() {
        let before = VoiceList.rows(for: voices, selectedID: nil, languageCode: "en").map(\.voiceID)
        let after = VoiceList.rows(for: voices, selectedID: "samantha", languageCode: "en").map(\.voiceID)

        #expect(before == after)
    }

    @Test func exactlyOneRowIsSelected() {
        for selected in [nil, "mine", "daniel", "samantha"] as [String?] {
            let rows = VoiceList.rows(for: voices, selectedID: selected, languageCode: "en")
            #expect(rows.filter(\.isSelected).map(\.voiceID) == [selected], "selected \(String(describing: selected))")
        }
    }

    /// A choice that is gone (or never offered) shows Automatic as chosen,
    /// which is what speech then uses.
    @Test func aMissingChoiceShowsAutomaticAsChosen() {
        let rows = VoiceList.rows(for: voices, selectedID: "deleted", languageCode: "en")

        #expect(rows.filter(\.isSelected).map(\.voiceID) == [nil])
        #expect(VoiceList.chosenVoiceIsMissing(selectedID: "deleted", from: voices))
        #expect(!VoiceList.chosenVoiceIsMissing(selectedID: "daniel", from: voices))
        #expect(!VoiceList.chosenVoiceIsMissing(selectedID: nil, from: voices))
    }

    @Test func everyButtonNameIsUnique() {
        let crowded = voices + [
            VoiceDescriptor(id: "samantha-2", name: "Samantha", languageCode: "en-US", quality: .standard, isPersonalVoice: false),
            VoiceDescriptor(id: "samantha-au", name: "Samantha", languageCode: "en-AU", quality: .standard, isPersonalVoice: false),
            VoiceDescriptor(id: "automatic", name: "Automatic", languageCode: "en-US", quality: .standard, isPersonalVoice: false),
        ]
        let rows = VoiceList.rows(for: crowded, selectedID: nil, languageCode: "en")
        let labels = rows.flatMap { [$0.hearLabel.lowercased(), $0.useLabel.lowercased()] }

        #expect(Set(labels).count == labels.count, "\(labels)")
        #expect(Set(rows.map(\.id)).count == rows.count)
    }

    @Test func aNameThatIsAlreadyUniqueIsLeftAlone() {
        let rows = VoiceList.rows(for: voices, selectedID: nil, languageCode: "en")
        let daniel = rows.first { $0.voiceID == "daniel" }

        #expect(daniel?.useLabel == "Use Daniel")
        #expect(daniel?.hearLabel == "Hear Daniel")
    }
}
