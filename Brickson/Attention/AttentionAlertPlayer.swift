import Foundation
import Observation
import os

/// The Get Attention alarm: a loud, looping tone that calls someone into the
/// room. Its rules live in `AttentionAlertStatus`; this class plays the tone
/// and feeds the status what happened.
///
/// - Start-only: `start()` never silences the alarm, so a held look or a
///   second press re-firing Get Attention leaves it sounding. Only
///   `stop()`, called from a separate, differently placed Stop control,
///   ends it (invariant 10).
/// - Speaking never silences it: while a phrase speaks, the tone drops to
///   `AttentionAlertStatus.toneVolumeWhileSpeaking` and comes back up when
///   the phrase ends.
/// - A tone the system stops (a call, Siri, a lost output, a media-services
///   reset, a player error) is never restarted by itself. Home shows "Alert
///   stopped", and one Get Attention activation restarts it (invariant 4).
/// - There is no time limit: it sounds until someone chooses Stop.
@MainActor
@Observable
final class AttentionAlertPlayer {
    private(set) var status = AttentionAlertStatus()

    var state: AttentionAlertState { status.state }
    var failureSequence: Int { status.failureSequence }
    var isSounding: Bool { status.isSounding }

    @ObservationIgnored private var playback: (any AttentionTonePlayback)?
    /// Goes up whenever the player is replaced or discarded, so a late
    /// report from an old player, or an old health check, changes nothing.
    @ObservationIgnored private var playbackGeneration: UInt = 0
    /// Whether the session could not be activated for the tone now playing.
    /// The tone is tried anyway, but it may be muted by the silent switch,
    /// so the next Get Attention retries the session instead of being
    /// absorbed as "already sounding".
    @ObservationIgnored private var sessionActivationFailed = false
    @ObservationIgnored private let audioSession: AudioSessionCoordinator
    @ObservationIgnored private let makePlayback: @MainActor () throws -> any AttentionTonePlayback
    @ObservationIgnored private let sleep: @MainActor @Sendable (Duration) async -> Void
    private let logger = Logger(subsystem: AppLog.subsystem, category: "attention-alert")

    /// How often a sounding alarm checks that its player is really playing.
    static let healthCheckInterval: Duration = .seconds(1)
    /// How quickly the tone moves between its two levels when speech starts
    /// or ends, so the change is heard as a dip, not a click.
    static let volumeFadeDuration: TimeInterval = 0.15

    init(
        audioSession: AudioSessionCoordinator,
        events: AudioSessionEvents,
        makePlayback: @escaping @MainActor () throws -> any AttentionTonePlayback,
        sleep: @escaping @MainActor @Sendable (Duration) async -> Void
    ) {
        self.audioSession = audioSession
        self.makePlayback = makePlayback
        self.sleep = sleep
        events.subscribe { [weak self] event in
            self?.handle(event)
        }
        audioSession.onHoldersChanged { [weak self] in
            self?.matchToneVolumeToSpeech()
        }
    }

    /// Get Attention. Idempotent while the tone is really playing. A tone
    /// started while the session could not be activated is replaced, to
    /// retry the session, but it plays on until its replacement has
    /// started, so this never silences a tone that is sounding.
    func start() {
        let livePlayerIsPlaying = playback?.isPlaying ?? false
        switch status.startDecision(livePlayerIsPlaying: livePlayerIsPlaying && !sessionActivationFailed) {
        case .alreadySounding:
            logger.info("Get Attention chosen again while sounding; the alarm carries on")
            return
        case .start:
            break
        }

        // A tone still sounding here is one started without the session: a
        // held look re-firing Get Attention must not silence it, so it is
        // kept until a new tone plays. A player the state thought was
        // playing but which went quiet is rebuilt rather than trusted.
        let keepsLiveTone = status.isSounding && livePlayerIsPlaying
        if !keepsLiveTone {
            discardPlayback()
        }
        // A failed activation already shows "Audio failed" on Home. The tone
        // is still tried, since it may play; the next Get Attention retries.
        let activationFailed = audioSession.acquire(for: .attentionAlert) == .failed

        let candidate: any AttentionTonePlayback
        do {
            candidate = try makePlayback()
        } catch {
            logger.error("Could not load the Get Attention tone: \(error.localizedDescription)")
            recordFailedStart(keepingLiveTone: keepsLiveTone)
            return
        }

        // The generation the new tone takes once it replaces any kept one,
        // so until then the kept tone's reports and health check still count.
        let generation = playbackGeneration &+ 1
        candidate.eventHandler = { [weak self] _ in
            self?.playbackStopped(generation: generation)
        }
        candidate.setVolume(toneVolume, fadeDuration: 0)

        guard candidate.playFromBeginning() else {
            candidate.eventHandler = nil
            candidate.stop()
            logger.error("The Get Attention tone player refused to start")
            recordFailedStart(keepingLiveTone: keepsLiveTone)
            return
        }

        // The new tone is playing; only now does a kept one stop.
        discardPlayback()
        playbackGeneration = generation
        playback = candidate
        sessionActivationFailed = activationFailed
        status.recordStart(succeeded: true)
        watchHealth(generation: generation)
    }

    /// A start whose new tone could not load or play. A kept tone sounds on,
    /// still holding the session and still started without it, so Stop stays
    /// and the next Get Attention tries again. Otherwise the session is let
    /// go and Home shows "Alert failed".
    private func recordFailedStart(keepingLiveTone: Bool) {
        guard !keepingLiveTone else { return }
        audioSession.release(for: .attentionAlert)
        status.recordStart(succeeded: false)
    }

    /// Stop Alert. An intentional stop is ordinary idle; it never erases an
    /// unresolved failure.
    func stop() {
        discardPlayback()
        audioSession.release(for: .attentionAlert)
        status.recordStopRequested()
    }

    /// Checks that a sounding alarm's player is really playing, and shows
    /// "Alert stopped" if it went quiet without telling anyone. Runs every
    /// second while sounding, and when the app returns to the foreground.
    func checkHealth() {
        guard status.isSounding else { return }
        let livePlayerIsPlaying = playback?.isPlaying ?? false
        guard !livePlayerIsPlaying else { return }
        logger.error("The Get Attention tone went quiet without a report")
        discardPlayback()
        audioSession.release(for: .attentionAlert)
        status.recordHealthCheck(livePlayerIsPlaying: false)
    }

    private func watchHealth(generation: UInt) {
        let sleep = self.sleep
        Task { @MainActor [weak self] in
            while true {
                await sleep(AttentionAlertPlayer.healthCheckInterval)
                guard let self, self.playbackGeneration == generation else { return }
                self.checkHealth()
                // A tone found quiet was discarded, which ends this watch.
                guard self.playbackGeneration == generation else { return }
            }
        }
    }

    private func handle(_ event: AudioSessionEvent) {
        switch event {
        case .interrupted, .previousOutputUnavailable, .mediaServicesLost, .mediaServicesReset:
            // The tone stopped, or is about to play somewhere no one
            // expects. Say so; never restart by itself. After a reset the
            // old player is invalid, and the next start builds a new one.
            stopUnexpectedly()
        case .routeChanged:
            break
        }
    }

    private func playbackStopped(generation: UInt) {
        guard generation == playbackGeneration else { return }
        logger.error("The Get Attention tone player stopped by itself")
        stopUnexpectedly()
    }

    private func stopUnexpectedly() {
        discardPlayback()
        audioSession.release(for: .attentionAlert)
        status.recordUnexpectedStop()
    }

    private func discardPlayback() {
        playbackGeneration &+= 1
        playback?.eventHandler = nil
        playback?.stop()
        playback = nil
    }

    /// The tone's level for whether speech holds the audio session.
    private var toneVolume: Float {
        AttentionAlertStatus.toneVolume(whileSpeechIsActive: audioSession.isHeld(by: .speech))
    }

    private func matchToneVolumeToSpeech() {
        playback?.setVolume(toneVolume, fadeDuration: Self.volumeFadeDuration)
    }
}
