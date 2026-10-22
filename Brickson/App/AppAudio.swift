import Foundation

/// The app's audio objects, built once at launch. Speech and the Get
/// Attention alarm share one audio session through one coordinator, and
/// every audio notification reaches them through one adapter, so nothing
/// configures or observes the session on its own (docs/DECISIONS.md,
/// "Background audio").
@MainActor
struct AppAudio {
    let events: AudioSessionEvents
    let safety: AudioSafetyMonitor
    let session: AudioSessionCoordinator
    let speech: SpeechService
    let attention: AttentionAlertPlayer

    /// The real objects. `settings` is where speech keeps the chosen voice
    /// and rate. `personalVoiceTrial` is a debug launch's request to ask for
    /// Personal Voice from Voice Settings instead (`LaunchOptions`); a
    /// release build always passes nil.
    static func makeForApp(
        settings: UserDefaults,
        personalVoiceTrial: LaunchOptions.PersonalVoiceTrial? = nil
    ) -> AppAudio {
        let events = AudioSessionEvents()
        let safety = AudioSafetyMonitor(events: events)
        let session = AudioSessionCoordinator(
            session: SystemAudioSession(),
            audioSafety: safety,
            events: events,
            policy: .keepActive
        )
        // Set (but don't activate) the category at launch, so the first
        // sound, a phrase or Get Attention, already plays with the silent
        // switch on.
        session.configure()
        let sleep: @MainActor @Sendable (Duration) async -> Void = { duration in
            // A cancelled sleep only ends a check early; nothing is lost.
            _ = try? await Task.sleep(for: duration)
        }
        let personalVoice: any PersonalVoiceAuthorizing = switch personalVoiceTrial {
        case .standInRefuses: StandInPersonalVoice(answer: .denied)
        case .askFromSettings, nil: SystemPersonalVoice()
        }
        let speech = SpeechService(
            audioSession: session,
            events: events,
            makeSynthesizer: { SystemSpeechSynthesizer() },
            voiceCatalog: SystemVoiceCatalog(),
            settings: settings,
            notificationCenter: .default,
            personalVoice: personalVoice,
            personalVoiceAskPolicy: personalVoiceAskPolicy(for: personalVoiceTrial),
            sleep: sleep
        )
        let attention = AttentionAlertPlayer(
            audioSession: session,
            events: events,
            makePlayback: { try SystemAttentionTonePlayback.bundled() },
            sleep: sleep
        )
        return AppAudio(
            events: events,
            safety: safety,
            session: session,
            speech: speech,
            attention: attention
        )
    }

    /// When the app asks for Personal Voice permission. The app's policy is
    /// the first line: `.atLaunch`, today's behaviour, until device check D1
    /// shows a voice allowed after the first phrase speaks without a
    /// relaunch (docs/DECISIONS.md, "Personal Voice permission is asked at
    /// launch, for now"). A debug launch can ask for `.fromSettings` to run
    /// that check.
    static func personalVoiceAskPolicy(for trial: LaunchOptions.PersonalVoiceTrial?) -> PersonalVoiceAskPolicy {
        guard trial != nil else { return .atLaunch }
        return .fromSettings
    }
}
