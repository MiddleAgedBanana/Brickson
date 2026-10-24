import Testing
@testable import Brickson

/// Inside Assistive Access, Settings' guides give the written path to a
/// page of the Settings app instead of a button that opens it
/// (docs/DECISIONS.md, "Accessibility API coverage").
struct SettingsAppLinkTests {
    /// Fails if Assistive Access stops hiding the button, if a page iOS
    /// says it cannot open gets one, or if a page it can open loses it
    /// outside Assistive Access.
    @Test func aButtonOpensSettingsOnlyOutsideAssistiveAccessWhereIOSCanOpenIt() {
        #expect(SettingsAppLink.offersButton(insideAssistiveAccess: false, systemCanOpen: true))
        #expect(!SettingsAppLink.offersButton(insideAssistiveAccess: false, systemCanOpen: false))
        #expect(!SettingsAppLink.offersButton(insideAssistiveAccess: true, systemCanOpen: true))
        #expect(!SettingsAppLink.offersButton(insideAssistiveAccess: true, systemCanOpen: false))
    }

    /// Voice Settings' Personal Voice card, turned off for Brickson inside
    /// Assistive Access: the written path to Allow Apps to Request to Use
    /// stays, and no button offers to open it. Fails if the guidance drops
    /// the path along with the button.
    @Test func personalVoiceKeepsItsWrittenPathInsideAssistiveAccess() {
        let guidance = PersonalVoiceGuidance.make(
            access: .denied,
            hasPersonalVoice: false,
            canAsk: false,
            canOpenSettings: SettingsAppLink.offersButton(insideAssistiveAccess: true, systemCanOpen: true)
        )

        #expect(guidance.action == nil)
        #expect(guidance.settingsPath == PersonalVoiceGuidance.allowAppsPath)
    }
}
