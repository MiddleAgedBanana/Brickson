import AVFoundation

/// What the tone player can report after it started.
nonisolated enum AttentionTonePlaybackEvent: CaseIterable, Equatable, Sendable {
    case decodeError
    /// A looping tone never finishes by itself; a finish means it stopped.
    case unexpectedFinish
}

/// The alarm's view of the tone player, as a seam so the alarm's rules are
/// tested without sound.
@MainActor
protocol AttentionTonePlayback: AnyObject {
    var eventHandler: (@MainActor (AttentionTonePlaybackEvent) -> Void)? { get set }
    /// Whether the player says it is playing right now.
    var isPlaying: Bool { get }
    /// The player's own gain, from 0 to 1. Never the system volume, which the
    /// app observes but never sets (invariant 4).
    func setVolume(_ volume: Float, fadeDuration: TimeInterval)
    /// Plays from the start, looping until stopped. Returns whether it began.
    func playFromBeginning() -> Bool
    func stop()
}

/// The real tone: an `AVAudioPlayer` under the shared `.playback` session,
/// never `AudioServicesPlaySystemSound`, which obeys the silent switch. It
/// loops until stopped and keeps playing with the screen locked.
@MainActor
final class SystemAttentionTonePlayback: NSObject, AttentionTonePlayback, AVAudioPlayerDelegate {
    var eventHandler: (@MainActor (AttentionTonePlaybackEvent) -> Void)?

    private let player: AVAudioPlayer

    /// The tone shipped in the app bundle.
    static func bundled(in bundle: Bundle = .main) throws -> SystemAttentionTonePlayback {
        guard let url = bundle.url(forResource: "AttentionTone", withExtension: "wav") else {
            throw AttentionToneError.missingBundledTone
        }
        return try SystemAttentionTonePlayback(contentsOf: url)
    }

    init(contentsOf url: URL) throws {
        player = try AVAudioPlayer(contentsOf: url)
        super.init()
        player.numberOfLoops = -1
        player.volume = AttentionAlertStatus.fullToneVolume
        player.delegate = self
    }

    var isPlaying: Bool { player.isPlaying }

    /// A negative loop count repeats until `stop()`.
    var loopsUntilStopped: Bool { player.numberOfLoops < 0 }

    func setVolume(_ volume: Float, fadeDuration: TimeInterval) {
        player.setVolume(volume, fadeDuration: fadeDuration)
    }

    func playFromBeginning() -> Bool {
        player.currentTime = 0
        return player.play()
    }

    func stop() {
        player.stop()
    }

    // AVAudioPlayer gives no thread guarantee for its delegate, so these are
    // nonisolated and hop to the main actor (`OffMainThreadCallbackTests`).

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            self?.eventHandler?(.unexpectedFinish)
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: (any Error)?) {
        Task { @MainActor [weak self] in
            self?.eventHandler?(.decodeError)
        }
    }
}

/// A tone that makes no sound, for UI tests (`--attention-tone=silent`,
/// read only by debug builds: `LaunchOptions`). It says it is playing from
/// `playFromBeginning()` until `stop()`, so the alarm's state, Home's Stop
/// and the status line behave as with the real tone, without depending on
/// the simulator's audio.
@MainActor
final class SilentAttentionTonePlayback: AttentionTonePlayback {
    var eventHandler: (@MainActor (AttentionTonePlaybackEvent) -> Void)?
    private(set) var isPlaying = false

    func setVolume(_ volume: Float, fadeDuration: TimeInterval) {}

    func playFromBeginning() -> Bool {
        isPlaying = true
        return true
    }

    func stop() {
        isPlaying = false
    }
}

nonisolated enum AttentionToneError: LocalizedError {
    case missingBundledTone

    var errorDescription: String? {
        "AttentionTone.wav is missing from the app bundle."
    }
}
