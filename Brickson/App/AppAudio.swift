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
    /// and rate.
    static func makeForApp(settings: UserDefaults) -> AppAudio {
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
        let speech = SpeechService(
            audioSession: session,
            events: events,
            makeSynthesizer: { SystemSpeechSynthesizer() },
            voiceCatalog: SystemVoiceCatalog(),
            settings: settings,
            notificationCenter: .default,
            requestPersonalVoiceAuthorization: SystemPersonalVoice.requestAuthorization,
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
}
