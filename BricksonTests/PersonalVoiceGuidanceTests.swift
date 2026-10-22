import Testing
@testable import Brickson

/// Every Personal Voice state must name a next step a family member can
/// follow, and must still work when iOS can't open its Settings page.
struct PersonalVoiceGuidanceTests {
    private func guidance(
        _ access: PersonalVoiceAccess,
        hasVoice: Bool = false,
        canAsk: Bool = false,
        canOpen: Bool = true,
        asked: Bool = false
    ) -> PersonalVoiceGuidance {
        PersonalVoiceGuidance.make(
            access: access,
            hasPersonalVoice: hasVoice,
            canAsk: canAsk,
            canOpenSettings: canOpen,
            askedOnThisVisit: asked
        )
    }

    @Test func askingIsOfferedOnlyWhenThisScreenCanAsk() {
        #expect(guidance(.notDetermined, canAsk: true).action == .askPermission)
        // Today Brickson asks by itself at launch, so the screen only explains.
        #expect(guidance(.notDetermined, canAsk: false).action == nil)
    }

    @Test func turnedOffShowsTheWayToTurnItOn() {
        let turnedOff = guidance(.denied)

        #expect(turnedOff.action == .openPersonalVoiceSettings)
        #expect(turnedOff.settingsPath == PersonalVoiceGuidance.allowAppsPath)
    }

    /// The written path is the fallback when the button can't open Settings.
    @Test func theWrittenPathStaysWhenSettingsCannotBeOpened() {
        let turnedOff = guidance(.denied, canOpen: false)

        #expect(turnedOff.action == nil)
        #expect(turnedOff.settingsPath != nil)

        let noVoice = guidance(.authorized, canOpen: false)
        #expect(noVoice.action == nil)
        #expect(noVoice.settingsPath == PersonalVoiceGuidance.personalVoicePath)
    }

    /// iOS can open only Personal Voice's "Allow Apps to Request to Use"
    /// page, which is not where a voice is made, so this state offers the
    /// written path and no button.
    @Test func allowedWithNoVoiceSuggestsMakingOne() {
        let noVoice = guidance(.authorized, hasVoice: false)

        #expect(noVoice.suggestsMakingOne)
        #expect(noVoice.action == nil)
        #expect(noVoice.settingsPath == PersonalVoiceGuidance.personalVoicePath)
    }

    @Test func allowedWithAVoiceNeedsNothingMore() {
        let ready = guidance(.authorized, hasVoice: true)

        #expect(ready.action == nil)
        #expect(!ready.suggestsMakingOne)
        #expect(ready.settingsPath == nil)
    }

    /// The words above the Ask button name it and the answer to give,
    /// before iOS asks. Fails if the button's own name or Allow is missing.
    @Test func theAskButtonIsExplainedBeforeIOSAsks() {
        let ask = guidance(.notDetermined, canAsk: true)

        #expect(ask.message.contains("Ask to Use Personal Voice"))
        #expect(ask.message.contains("Allow"))
    }

    /// After the Ask button is used, a refusal gives the written path but
    /// no Open Personal Voice Settings button until the screen opens
    /// again, so nothing that leaves the app lands beside the spot just
    /// activated (AGENTS.md, invariant 10). Fails if the button is offered
    /// on the same visit, or the path is dropped.
    @Test func afterAskingHereNoNewButtonAppearsOnThisVisit() {
        let refused = guidance(.denied, canAsk: true, canOpen: true, asked: true)

        #expect(refused.action == nil)
        #expect(refused.settingsPath == PersonalVoiceGuidance.allowAppsPath)
        // The next visit offers it again.
        #expect(guidance(.denied, canAsk: true, canOpen: true).action == .openPersonalVoiceSettings)
    }

    /// Asking again before an answer is the same button in the same place,
    /// so it stays. Fails if using it once takes it away before iOS
    /// answers.
    @Test func theAskButtonStaysUntilIOSAnswers() {
        #expect(guidance(.notDetermined, canAsk: true, asked: true).action == .askPermission)
    }

    /// Every answer iOS can give has words the screen keeps room for while
    /// the button shows, and none of them offers a button. Fails if an
    /// answer is missing or one offers a control.
    @Test func everyAnswerToAskingOffersNoButton() {
        let outcomes = PersonalVoiceGuidance.outcomesOfAsking()

        #expect(outcomes.count == 4)
        #expect(outcomes.allSatisfy { $0.action == nil })
        #expect(outcomes.contains(guidance(.authorized, hasVoice: true, asked: true)))
        #expect(outcomes.contains(guidance(.authorized, hasVoice: false, asked: true)))
        #expect(outcomes.contains(guidance(.denied, asked: true)))
        #expect(outcomes.contains(guidance(.unsupported, asked: true)))
    }

    @Test func unsupportedDevicesOfferNoDeadEnd() {
        let unsupported = guidance(.unsupported, canAsk: true)

        #expect(unsupported.action == nil)
        #expect(unsupported.settingsPath == nil)
        #expect(!unsupported.suggestsMakingOne)
    }
}
