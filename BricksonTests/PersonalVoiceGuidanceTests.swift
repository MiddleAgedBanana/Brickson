import Testing
@testable import Brickson

/// Every Personal Voice state must name a next step a family member can
/// follow, and must still work when iOS can't open its Settings page.
struct PersonalVoiceGuidanceTests {
    private func guidance(
        _ access: PersonalVoiceAccess,
        hasVoice: Bool = false,
        canAsk: Bool = false,
        canOpen: Bool = true
    ) -> PersonalVoiceGuidance {
        PersonalVoiceGuidance.make(access: access, hasPersonalVoice: hasVoice, canAsk: canAsk, canOpenSettings: canOpen)
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

    @Test func unsupportedDevicesOfferNoDeadEnd() {
        let unsupported = guidance(.unsupported, canAsk: true)

        #expect(unsupported.action == nil)
        #expect(unsupported.settingsPath == nil)
        #expect(!unsupported.suggestsMakingOne)
    }
}
