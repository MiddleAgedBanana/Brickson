import Testing
@testable import Brickson

/// When the app asks to use the person's Personal Voice
/// (docs/DECISIONS.md, "Personal Voice permission is asked at launch, for
/// now").
struct PersonalVoiceAskPolicyTests {
    /// Today's behaviour: the request runs every time the app starts, before
    /// anything is spoken. Fails if `.atLaunch` stops asking in either case.
    @Test(arguments: [false, true])
    func atLaunchAlwaysAsksWhenTheAppStarts(alreadyAllowed: Bool) {
        #expect(PersonalVoiceAskPolicy.atLaunch.asksAtLaunch(alreadyAllowed: alreadyAllowed))
    }

    /// From Settings, the system's question comes only after the Voice
    /// screen has explained it. Fails if `.fromSettings` asks at launch
    /// before the person has allowed it, which shows the question with no
    /// explanation.
    @Test func fromSettingsNeverAsksAtLaunchBeforeThePersonAllowedIt() {
        #expect(!PersonalVoiceAskPolicy.fromSettings.asksAtLaunch(alreadyAllowed: false))
    }

    /// Once allowed, asking again at launch shows no question (Apple: the
    /// person is prompted initially and changes it in the Settings app) and
    /// keeps the path the reference app relied on. Fails if `.fromSettings`
    /// skips it.
    @Test func fromSettingsAsksAgainAtLaunchOnceAllowed() {
        #expect(PersonalVoiceAskPolicy.fromSettings.asksAtLaunch(alreadyAllowed: true))
    }

    /// The app's policy stays `.atLaunch` until device check D1 passes;
    /// only a debug launch that asks for a trial leaves the question to
    /// Voice Settings. Fails if the app's policy changes without that
    /// decision, or a trial still asks at launch.
    @Test func theAppAsksAtLaunchUnlessALaunchAsksForATrial() {
        #expect(AppAudio.personalVoiceAskPolicy(for: nil) == .atLaunch)
        #expect(AppAudio.personalVoiceAskPolicy(for: .askFromSettings) == .fromSettings)
        #expect(AppAudio.personalVoiceAskPolicy(for: .standInRefuses) == .fromSettings)
    }
}
