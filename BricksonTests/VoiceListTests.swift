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

    /// iOS lists voices in no promised order, so two Personal Voices must
    /// not swap places when it lists them the other way round.
    @Test func personalVoicesKeepTheirPlacesWhateverOrderIOSGives() {
        let mine = VoiceDescriptor(id: "mine", name: "My Voice", languageCode: "en-US", quality: .premium, isPersonalVoice: true)
        let older = VoiceDescriptor(id: "older", name: "Earlier Voice", languageCode: "en-US", quality: .premium, isPersonalVoice: true)

        let one = VoiceList.rows(for: [mine, older], selectedID: nil, languageCode: "en").map(\.voiceID)
        let other = VoiceList.rows(for: [older, mine], selectedID: nil, languageCode: "en").map(\.voiceID)

        #expect(one == [nil, "older", "mine"])
        #expect(other == one)
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

    // MARK: - Places while the screen is open

    /// A voice that arrives while Voice Settings is open, such as a
    /// Personal Voice allowed in the Settings app, goes after every row
    /// already shown. Fails if the live order is used, which would put it
    /// second and move every row below it.
    @Test func aVoiceThatArrivesGoesAfterTheRowsAlreadyShown() {
        let withoutMine = voices.filter { $0.id != "mine" }
        let shown = VoiceList.rows(for: withoutMine, selectedID: nil, languageCode: "en")
        let current = VoiceList.rows(for: voices, selectedID: nil, languageCode: "en")

        let places = VoiceList.keepingPlaces(of: shown, in: current)

        #expect(places.map(\.id) == shown.map(\.id) + ["voice:mine"])
    }

    /// A voice that leaves keeps its place, as words, so nothing below it
    /// moves up under a resting pointer. Fails if a gone voice is dropped.
    @Test func aVoiceThatLeavesKeepsItsPlace() {
        let shown = VoiceList.rows(for: voices, selectedID: nil, languageCode: "en")
        let current = VoiceList.rows(for: voices.filter { $0.id != "daniel" }, selectedID: nil, languageCode: "en")

        let places = VoiceList.keepingPlaces(of: shown, in: current)

        #expect(places.map(\.id) == shown.map(\.id))
        let daniel = shown.first { $0.voiceID == "daniel" }!
        #expect(places.filter { if case .gone = $0 { true } else { false } } == [.gone(daniel)])
    }

    /// Each voice still listed shows whether it is chosen now. Fails if the
    /// rows from when the screen opened are shown as they were.
    @Test func whichVoiceIsChosenIsNeverOutOfDate() {
        let shown = VoiceList.rows(for: voices, selectedID: nil, languageCode: "en")
        let current = VoiceList.rows(for: voices, selectedID: "samantha", languageCode: "en")

        let chosen = VoiceList.keepingPlaces(of: shown, in: current).filter { place in
            if case .voice(let row) = place { row.isSelected } else { false }
        }

        #expect(chosen.map(\.id) == ["voice:samantha"])
    }

    /// Without Personal Voice permission a chosen Personal Voice is only
    /// left out of the list, not gone from the device, so neither note may
    /// say it is gone then. Fails if one wording is used for both.
    @Test func aVoiceWhoseAccessIsOffIsNeverCalledGone() {
        let gone = "no longer on this device"
        #expect(VoiceList.missingVoiceNote(personalVoiceAllowed: true).contains(gone))
        #expect(!VoiceList.missingVoiceNote(personalVoiceAllowed: false).contains(gone))

        let rows = VoiceList.rows(for: voices, selectedID: nil, languageCode: "en")
        let mine = rows.first { $0.voiceID == "mine" }!
        let daniel = rows.first { $0.voiceID == "daniel" }!
        #expect(!VoiceList.goneVoiceNote(for: mine, personalVoiceAllowed: false).contains(gone))
        #expect(VoiceList.goneVoiceNote(for: mine, personalVoiceAllowed: true).contains(gone))
        #expect(VoiceList.goneVoiceNote(for: daniel, personalVoiceAllowed: false).contains(gone))
        #expect(VoiceList.goneVoiceNote(for: mine, personalVoiceAllowed: false).hasPrefix("My Voice"))
    }

    @Test func withNothingChangedThePlacesAreTheRows() {
        let rows = VoiceList.rows(for: voices, selectedID: "daniel", languageCode: "en")

        #expect(VoiceList.keepingPlaces(of: rows, in: rows) == rows.map(VoiceListPlace.voice))
    }
}
