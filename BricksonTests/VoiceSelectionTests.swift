import Testing
@testable import Brickson

struct VoiceSelectionTests {
    private func voice(
        _ id: String,
        lang: String = "en-US",
        quality: VoiceQuality = .standard,
        personal: Bool = false,
        novelty: Bool = false
    ) -> VoiceDescriptor {
        VoiceDescriptor(
            id: id, name: id, languageCode: lang, quality: quality,
            isPersonalVoice: personal, isNovelty: novelty
        )
    }

    @Test func chosenVoiceWinsOverEverything() {
        let voices = [
            voice("fr-standard", lang: "fr-FR"),
            voice("personal", personal: true),
            voice("premium-en", quality: .premium),
        ]
        #expect(VoiceSelection.select(chosenID: "fr-standard", from: voices)?.id == "fr-standard")
    }

    @Test func uninstalledChosenVoiceFallsBackToPersonalVoice() {
        let voices = [
            voice("premium-en", quality: .premium),
            voice("personal", personal: true),
        ]
        #expect(VoiceSelection.select(chosenID: "gone", from: voices)?.id == "personal")
    }

    @Test func personalVoiceBeatsPremiumEnglishWhenNothingChosen() {
        let voices = [
            voice("premium-en", quality: .premium),
            voice("personal", lang: "en-US", personal: true),
        ]
        #expect(VoiceSelection.select(chosenID: nil, from: voices)?.id == "personal")
    }

    @Test func premiumEnglishBeatsEnhancedBeatsStandard() {
        let voices = [
            voice("standard-en"),
            voice("enhanced-en", quality: .enhanced),
            voice("premium-en", quality: .premium),
        ]
        #expect(VoiceSelection.select(chosenID: nil, from: voices)?.id == "premium-en")

        let withoutPremium = voices.filter { $0.id != "premium-en" }
        #expect(VoiceSelection.select(chosenID: nil, from: withoutPremium)?.id == "enhanced-en")
    }

    @Test func firstOfEqualQualityWinsDeterministically() {
        let voices = [
            voice("premium-a", quality: .premium),
            voice("premium-b", quality: .premium),
        ]
        #expect(VoiceSelection.select(chosenID: nil, from: voices)?.id == "premium-a")
    }

    @Test func anyEnglishVariantQualifiesAsEnglish() {
        let voices = [
            voice("standard-us", lang: "en-US"),
            voice("premium-gb", lang: "en-GB", quality: .premium),
        ]
        #expect(VoiceSelection.select(chosenID: nil, from: voices)?.id == "premium-gb")
    }

    @Test func englishBeatsHigherQualityNonEnglish() {
        let voices = [
            voice("premium-fr", lang: "fr-FR", quality: .premium),
            voice("standard-en", lang: "en-US"),
        ]
        #expect(VoiceSelection.select(chosenID: nil, from: voices)?.id == "standard-en")
    }

    @Test func nonEnglishOnlyListStillReturnsAVoice() {
        let voices = [
            voice("de", lang: "de-DE"),
            voice("fr", lang: "fr-FR", quality: .premium),
        ]
        #expect(VoiceSelection.select(chosenID: nil, from: voices) != nil)
    }

    @Test func emptyListReturnsNilForSystemDefault() {
        #expect(VoiceSelection.select(chosenID: nil, from: []) == nil)
    }

    /// Auto-selection must never pick Bells/Boing/etc. over a real voice —
    /// a lifeline communication app speaking in a joke voice is a failure.
    @Test func realVoiceBeatsNoveltyEvenAtLowerQuality() {
        let voices = [
            voice("bells", quality: .premium, novelty: true),
            voice("samantha"),
        ]
        #expect(VoiceSelection.select(chosenID: nil, from: voices)?.id == "samantha")
    }

    @Test func aRealVoiceStillBeatsNoveltyWhenNoRealEnglishVoiceIsAvailable() {
        let voices = [
            voice("bells", quality: .premium, novelty: true),
            voice("real-french", lang: "fr-FR"),
        ]

        #expect(VoiceSelection.select(chosenID: nil, from: voices)?.id == "real-french")
    }

    @Test func noveltyVoiceIsStillUsableAsLastResort() {
        let voices = [voice("bells", novelty: true)]
        #expect(VoiceSelection.select(chosenID: nil, from: voices)?.id == "bells")
    }

    @Test func explicitlyChosenNoveltyVoiceIsRespected() {
        let voices = [
            voice("bells", novelty: true),
            voice("samantha"),
        ]
        #expect(VoiceSelection.select(chosenID: "bells", from: voices)?.id == "bells")
    }

    // MARK: The language of the words being spoken

    /// The app chooses a voice for the language its phrases are written in.
    /// English is the default because the starter phrases are English.
    @Test func aVoiceInThePhrasesLanguageBeatsHigherQualityOthers() {
        let voices = [
            voice("premium-en", lang: "en-US", quality: .premium),
            voice("standard-es", lang: "es-MX"),
        ]
        #expect(VoiceSelection.select(chosenID: nil, from: voices, languageCode: "es")?.id == "standard-es")
        #expect(VoiceSelection.select(chosenID: nil, from: voices)?.id == "premium-en")
    }

    @Test func languageMatchingIgnoresRegionAndCase() {
        let voices = [
            voice("fr", lang: "fr-FR"),
            voice("es-spain", lang: "es-ES", quality: .enhanced),
        ]
        #expect(VoiceSelection.select(chosenID: nil, from: voices, languageCode: "ES-mx")?.id == "es-spain")
    }

    @Test func primarySubtagReadsBothSeparatorStyles() {
        #expect(VoiceSelection.primarySubtag(of: "en-US") == "en")
        #expect(VoiceSelection.primarySubtag(of: "zh_Hant_TW") == "zh")
        #expect(VoiceSelection.primarySubtag(of: "DE") == "de")
        #expect(VoiceSelection.primarySubtag(of: "") == "")
    }

    /// Someone's own voice comes first in every language.
    @Test func personalVoiceStillComesFirstInAnotherLanguage() {
        let voices = [
            voice("premium-es", lang: "es-MX", quality: .premium),
            voice("personal", lang: "en-US", personal: true),
        ]
        #expect(VoiceSelection.select(chosenID: nil, from: voices, languageCode: "es")?.id == "personal")
    }
}
