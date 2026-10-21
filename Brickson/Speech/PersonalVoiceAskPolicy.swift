/// When Brickson asks for permission to use the person's Personal Voice.
/// `AppAudio` chooses it in one line, so moving the question from launch to
/// Settings is a one-line change (docs/DECISIONS.md, "Personal Voice
/// permission is asked at launch, for now"). Free of AVFoundation, so it is
/// tested with plain values.
nonisolated enum PersonalVoiceAskPolicy: Equatable, Sendable {
    /// Ask every time the app starts, before anything is spoken. The app's
    /// policy today: on the first launch the system's question appears with
    /// no explanation.
    case atLaunch
    /// Ask only from the explained button on Settings' Voice screen
    /// (`SpeechService.requestPersonalVoiceAuthorization()`). For when that
    /// button exists and a device shows a voice allowed after the first
    /// phrase is used without a relaunch.
    case fromSettings

    /// Whether the app asks when it starts. `alreadyAllowed` is whether the
    /// system already reports permission. Asking again then shows no
    /// question, because the person is asked only the first time and
    /// changes the answer in the Settings app (Apple,
    /// `personalVoiceAuthorizationStatus`), and it keeps the path the
    /// reference app found reliable, so `.fromSettings` still asks then.
    func asksAtLaunch(alreadyAllowed: Bool) -> Bool {
        switch self {
        case .atLaunch: true
        case .fromSettings: alreadyAllowed
        }
    }
}
