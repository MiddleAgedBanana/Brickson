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

    // MARK: Automatic keeps the person's Personal Voice

    /// A second Personal Voice, listed first, must not take over a voice
    /// Automatic already speaks in (docs/DECISIONS.md, "Automatic keeps the
    /// person's Personal Voice"). Fails if the remembered voice is ignored.
    @Test func aSecondPersonalVoiceDoesNotChangeAutomatic() {
        let voices = [
            voice("second", personal: true),
            voice("own", personal: true),
        ]

        let automatic = VoiceSelection.select(chosenID: nil, from: voices, automaticPersonalVoiceID: "own")

        #expect(automatic?.id == "own")
    }

    /// The remembered voice counts only while it is listed. Fails if a
    /// missing one blocks the next Personal Voice.
    @Test func aRememberedVoiceThatIsGoneFallsToTheNextPersonalVoice() {
        let voices = [
            voice("premium-en", quality: .premium),
            voice("other", personal: true),
        ]

        let automatic = VoiceSelection.select(chosenID: nil, from: voices, automaticPersonalVoiceID: "gone")

        #expect(automatic?.id == "other")
    }

    /// Only a Personal Voice is kept this way; a system voice remembered by
    /// mistake never outranks the person's own voice. Fails if any listed
    /// remembered id wins.
    @Test func onlyAPersonalVoiceIsKept() {
        let voices = [
            voice("premium-en", quality: .premium),
            voice("own", personal: true),
        ]

        let automatic = VoiceSelection.select(chosenID: nil, from: voices, automaticPersonalVoiceID: "premium-en")

        #expect(automatic?.id == "own")
    }

    /// A voice the person chose still comes first. Fails if the remembered
    /// Personal Voice overrides an explicit choice.
    @Test func aChosenVoiceStillBeatsTheRememberedPersonalVoice() {
        let voices = [
            voice("premium-en", quality: .premium),
            voice("own", personal: true),
        ]

        let selected = VoiceSelection.select(chosenID: "premium-en", from: voices, automaticPersonalVoiceID: "own")

        #expect(selected?.id == "premium-en")
    }

    // MARK: A Personal Voice only while it is allowed

    /// Without permission, no Personal Voice is a candidate, even one a
    /// stale list still shows (docs/DECISIONS.md, "A Personal Voice is used
    /// only while it is allowed"). Fails if one is kept, or the other
    /// voices lose their order.
    @Test func withoutPermissionNoPersonalVoiceIsUsable() {
        let voices = [
            voice("standard-en"),
            voice("own", personal: true),
            voice("premium-en", quality: .premium),
        ]

        let usable = VoiceSelection.usableVoices(voices, personalVoiceAllowed: false)

        #expect(usable.map(\.id) == ["standard-en", "premium-en"])
        #expect(VoiceSelection.select(chosenID: "own", from: usable)?.id == "premium-en")
    }

    /// Fails if permission drops any voice.
    @Test func withPermissionEveryVoiceIsUsable() {
        let voices = [
            voice("standard-en"),
            voice("own", personal: true),
        ]

        #expect(VoiceSelection.usableVoices(voices, personalVoiceAllowed: true) == voices)
    }
}
