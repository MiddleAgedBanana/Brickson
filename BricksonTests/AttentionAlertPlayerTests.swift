import AVFoundation
import Foundation
import Testing

@testable import Brickson

@MainActor
struct AttentionAlertPlayerTests {
    // MARK: The bundled tone

    @Test func theBundledToneIsPackagedAndDecodes() throws {
        let url = try #require(Bundle.main.url(forResource: "AttentionTone", withExtension: "wav"))
        let player = try AVAudioPlayer(contentsOf: url)

        #expect(player.duration > 0)
        #expect(player.numberOfChannels > 0)
    }

    /// The real player loops forever until stopped. Fails if it is built to
    /// play once.
    @Test func theRealToneLoopsUntilStopped() throws {
        let playback = try SystemAttentionTonePlayback.bundled()

        #expect(playback.loopsUntilStopped)
    }

    // MARK: Starting

    @Test func startPlaysTheToneAndHoldsTheSession() {
        let harness = AudioHarness()

        harness.attention.start()

        #expect(harness.attention.state == .playing)
        #expect(harness.attention.isSounding)
        #expect(harness.tones.latest?.isPlaying == true)
        #expect(harness.coordinator.isHeld(by: .attentionAlert))
    }

    @Test func aToneThatCannotLoadShowsAlertFailed() {
        let harness = AudioHarness()
        harness.tones.queue = [nil]

        harness.attention.start()

        #expect(harness.attention.state == .failedToStart)
        #expect(harness.issue == .attentionAlertFailed)
        #expect(!harness.coordinator.isHeld(by: .attentionAlert))
    }

    @Test func aPlayerThatRefusesToStartShowsAlertFailed() {
        let harness = AudioHarness()
        harness.tones.queue = [FakeTonePlayback(playSucceeds: false)]

        harness.attention.start()

        #expect(harness.attention.state == .failedToStart)
        #expect(!harness.coordinator.isHeld(by: .attentionAlert))
    }

    @Test func aRetryAfterAFailureStartsWithANewPlayer() {
        let harness = AudioHarness()
        harness.tones.queue = [FakeTonePlayback(playSucceeds: false)]
        harness.attention.start()

        harness.attention.start()

        #expect(harness.tones.attempts == 2)
        #expect(harness.attention.state == .playing)
    }

    /// Each failed attempt is announced, even when the state stays the same.
    @Test func eachFailedAttemptProducesANewFailureEvent() {
        let harness = AudioHarness()
        harness.tones.queue = [nil, nil]

        harness.attention.start()
        let first = harness.attention.failureSequence
        harness.attention.start()

        #expect(first > 0)
        #expect(harness.attention.failureSequence == first + 1)
    }

    /// The session is activated before every attempt to play, so the tone
    /// plays with the silent switch on. Fails if a start skips activation.
    @Test func theSessionIsActivatedBeforeEveryAttemptToPlay() {
        let harness = AudioHarness()
        let refusing = FakeTonePlayback(playSucceeds: false)
        let working = FakeTonePlayback()
        var activationsAtPlay: [Int] = []
        refusing.onPlay = { activationsAtPlay.append(harness.audioSession.activeCalls.count) }
        working.onPlay = { activationsAtPlay.append(harness.audioSession.activeCalls.count) }
        harness.tones.queue = [refusing, working]

        harness.attention.start()
        harness.attention.start()

        #expect(activationsAtPlay == [1, 2])
    }

    /// When the session cannot be activated, the tone is tried anyway but
    /// may be muted by the silent switch, so the next Get Attention must
    /// retry the session rather than be absorbed as "already sounding".
    /// Fails if a failed activation leaves later activations absorbed.
    @Test func afterAFailedSessionActivationTheNextGetAttentionRetriesTheSession() {
        let harness = AudioHarness()
        harness.audioSession.refusesActivation = true
        harness.attention.start()
        #expect(harness.tones.latest?.isPlaying == true)
        #expect(!harness.safety.audioSessionHealthy)

        harness.audioSession.refusesActivation = false
        harness.attention.start()

        #expect(harness.tones.attempts == 2)
        #expect(harness.safety.audioSessionHealthy)
        #expect(harness.attention.state == .playing)

        // With the session active, a repeat is absorbed again.
        harness.attention.start()
        #expect(harness.tones.attempts == 2)
    }

    // MARK: Start-only

    /// Under dwell a held look can fire Get Attention again. That must never
    /// silence, restart or disturb the alarm; only the separate Stop control
    /// ends it (invariant 10).
    @Test func choosingGetAttentionAgainLeavesTheAlarmSounding() {
        let harness = AudioHarness()
        harness.attention.start()
        let tone = harness.tones.latest

        harness.attention.start()
        harness.attention.start()

        #expect(harness.attention.state == .playing)
        #expect(harness.tones.attempts == 1)
        #expect(tone?.playCount == 1)
        #expect(tone?.stopCount == 0)
    }

    /// If the tone went quiet without a report, the same activation
    /// restarts it instead of being swallowed by a stale "playing".
    @Test func choosingGetAttentionWhileItsToneIsQuietRestartsIt() {
        let harness = AudioHarness()
        harness.attention.start()
        harness.tones.latest?.goQuietWithoutReporting()

        harness.attention.start()

        #expect(harness.tones.attempts == 2)
        #expect(harness.tones.latest?.isPlaying == true)
        #expect(harness.attention.state == .playing)
    }

    @Test func stopReturnsToIdleAndReleasesTheSession() {
        let harness = AudioHarness()
        harness.attention.start()
        let tone = harness.tones.latest

        harness.attention.stop()

        #expect(tone?.stopCount == 1)
        #expect(harness.attention.state == .idle)
        #expect(!harness.coordinator.isHeld(by: .attentionAlert))
        #expect(harness.issue == nil)
    }

    @Test func stopNeverErasesAnUnresolvedStartFailure() {
        let harness = AudioHarness()
        harness.tones.queue = [nil]
        harness.attention.start()

        harness.attention.stop()

        #expect(harness.attention.state == .failedToStart)
    }

    // MARK: Speech never silences it

    /// Fails if a phrase stops the alarm, or the tone does not dip and come
    /// back.
    @Test func theToneDipsWhileAPhraseSpeaksAndComesBackAfter() {
        let harness = AudioHarness()
        harness.attention.start()
        let tone = harness.tones.latest

        harness.speech.speak("Please come here.")
        #expect(tone?.volume == AttentionAlertStatus.toneVolumeWhileSpeaking)
        #expect(harness.attention.state == .playing)

        harness.synthesizer.finish()
        #expect(tone?.volume == AttentionAlertStatus.fullToneVolume)
        #expect(harness.attention.state == .playing)
    }

    /// Every way a phrase ends brings the tone back to full.
    @Test func theToneComesBackWhenAPhraseIsStoppedOrCancelled() {
        let harness = AudioHarness()
        harness.attention.start()
        let tone = harness.tones.latest

        harness.speech.speak("Yes.")
        harness.speech.stop()
        #expect(tone?.volume == AttentionAlertStatus.fullToneVolume)

        harness.speech.speak("No.")
        harness.synthesizer.cancel()
        #expect(tone?.volume == AttentionAlertStatus.fullToneVolume)
    }

    /// Starting the alarm while a phrase speaks starts it already dipped.
    @Test func anAlarmStartedDuringAPhraseStartsDipped() {
        let harness = AudioHarness()
        harness.speech.speak("Please come here.")

        harness.attention.start()

        #expect(harness.tones.latest?.volume == AttentionAlertStatus.toneVolumeWhileSpeaking)
    }

    // MARK: Stopping by itself, and never resuming

    @Test(arguments: SessionEvent.allCases)
    func aSystemEventWhileSoundingStopsItVisibly(event: SessionEvent) {
        let harness = AudioHarness()
        harness.attention.start()
        let tone = harness.tones.latest

        event.post(with: harness.notifications)

        #expect(tone?.stopCount == 1)
        #expect(harness.attention.state == .stoppedUnexpectedly)
        #expect(harness.issue == .attentionAlertStopped)
        #expect(!harness.coordinator.isHeld(by: .attentionAlert))
    }

    @Test(arguments: SessionEvent.allCases)
    func aSystemEventWhileIdleInventsNoFailure(event: SessionEvent) {
        let harness = AudioHarness()

        event.post(with: harness.notifications)

        #expect(harness.attention.state == .idle)
        #expect(harness.attention.failureSequence == 0)
    }

    /// Brickson never resumes by itself (invariant 4). Fails if the end of
    /// an interruption restarts the tone.
    @Test func theEndOfAnInterruptionNeverRestartsTheTone() {
        let harness = AudioHarness()
        harness.attention.start()
        harness.notifications.interruptionBegan()

        harness.notifications.interruptionEnded()

        #expect(harness.tones.attempts == 1)
        #expect(harness.attention.state == .stoppedUnexpectedly)
    }

    @Test func aNewDeviceAppearingLeavesTheToneSounding() {
        let harness = AudioHarness()
        harness.attention.start()

        harness.notifications.routeChanged(.newDeviceAvailable)

        #expect(harness.attention.state == .playing)
    }

    @Test func aMediaResetMeansTheNextStartBuildsANewPlayer() {
        let harness = AudioHarness()
        harness.attention.start()

        harness.notifications.mediaServicesReset()
        harness.attention.start()

        #expect(harness.tones.attempts == 2)
        #expect(harness.attention.state == .playing)
    }

    @Test(arguments: AttentionTonePlaybackEvent.allCases)
    func aPlayerFailureAfterStartIsVisible(event: AttentionTonePlaybackEvent) {
        let harness = AudioHarness()
        harness.attention.start()

        harness.tones.latest?.send(event)

        #expect(harness.attention.state == .stoppedUnexpectedly)
        #expect(!harness.attention.isSounding)
    }

    /// Fails if an old player's late report can stop the restarted alarm.
    @Test func aLateReportFromAnOldPlayerCannotStopTheRestartedAlarm() {
        let harness = AudioHarness()
        harness.attention.start()
        let first = harness.tones.latest
        let lateReport = first?.eventHandler
        harness.attention.stop()
        harness.attention.start()

        lateReport?(.unexpectedFinish)

        #expect(harness.attention.state == .playing)
        #expect(harness.tones.latest?.stopCount == 0)
    }

    // MARK: The health check

    /// A tone that goes quiet with no report must not leave "Sounding" on
    /// screen over silence. Fails if the check never acts.
    @Test func theHealthCheckShowsAlertStoppedForAToneThatWentQuiet() async {
        let harness = AudioHarness()
        harness.attention.start()
        #expect(await waitUntil { harness.alarmSleeper.pendingDurations == [.seconds(1)] })
        harness.tones.latest?.goQuietWithoutReporting()

        #expect(await harness.alarmSleeper.wakeAll())

        #expect(harness.attention.state == .stoppedUnexpectedly)
        #expect(!harness.alarmSleeper.isAnyoneSleeping)
    }

    @Test func theHealthCheckLeavesAPlayingToneAlone() async {
        let harness = AudioHarness()
        harness.attention.start()
        #expect(await waitUntil { harness.alarmSleeper.isAnyoneSleeping })

        #expect(await harness.alarmSleeper.wakeAll())

        #expect(harness.alarmSleeper.pendingDurations == [.seconds(1)])
        #expect(harness.attention.state == .playing)
    }

    /// The check also runs when the app returns to the foreground.
    @Test func checkingOnReturnShowsAToneThatStoppedWhileAway() {
        let harness = AudioHarness()
        harness.attention.start()
        harness.tones.latest?.goQuietWithoutReporting()

        harness.attention.checkHealth()

        #expect(harness.attention.state == .stoppedUnexpectedly)
        #expect(harness.attention.failureSequence == 1)
    }

    @Test func checkingWhileIdleChangesNothing() {
        let harness = AudioHarness()

        harness.attention.checkHealth()

        #expect(harness.attention.state == .idle)
    }
}

/// The session events that stop a sounding alarm.
nonisolated enum SessionEvent: CaseIterable, Sendable {
    case interruption
    case outputLost
    case mediaLost
    case mediaReset

    @MainActor
    func post(with notifications: SessionNotifications) {
        switch self {
        case .interruption: notifications.interruptionBegan()
        case .outputLost: notifications.routeChanged(.oldDeviceUnavailable)
        case .mediaLost: notifications.mediaServicesLost()
        case .mediaReset: notifications.mediaServicesReset()
        }
    }
}
