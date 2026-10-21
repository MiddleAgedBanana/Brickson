import Testing

@testable import Brickson

struct AttentionAlertStatusTests {
    @Test func startsIdleWithNoFailures() {
        let status = AttentionAlertStatus()

        #expect(status.state == .idle)
        #expect(status.failureSequence == 0)
        #expect(!status.isSounding)
    }

    /// A held look re-firing Get Attention is absorbed only while the tone
    /// really plays. Fails if a stale "playing" swallows the restart.
    @Test func aRepeatIsAbsorbedOnlyWhileTheTonePlays() {
        var status = AttentionAlertStatus()
        #expect(status.startDecision(livePlayerIsPlaying: false) == .start)

        status.recordStart(succeeded: true)

        #expect(status.startDecision(livePlayerIsPlaying: true) == .alreadySounding)
        #expect(status.startDecision(livePlayerIsPlaying: false) == .start)
    }

    @Test func eachFailedStartIsANewFailure() {
        var status = AttentionAlertStatus()

        status.recordStart(succeeded: false)
        status.recordStart(succeeded: false)

        #expect(status.state == .failedToStart)
        #expect(status.failureSequence == 2)
    }

    @Test func aSuccessfulRetryClearsTheFailure() {
        var status = AttentionAlertStatus()
        status.recordStart(succeeded: false)

        status.recordStart(succeeded: true)

        #expect(status.state == .playing)
        #expect(status.failureSequence == 1)
    }

    @Test func stopReturnsASoundingAlarmToIdle() {
        var status = AttentionAlertStatus()
        status.recordStart(succeeded: true)

        status.recordStopRequested()

        #expect(status.state == .idle)
        #expect(status.failureSequence == 0)
    }

    /// Fails if some other path asking to stop erases "Alert failed".
    @Test func stopNeverErasesAnUnresolvedFailure() {
        var status = AttentionAlertStatus()
        status.recordStart(succeeded: false)

        status.recordStopRequested()

        #expect(status.state == .failedToStart)
    }

    @Test func anUnexpectedStopIsRecordedOnlyWhileSounding() {
        var idle = AttentionAlertStatus()
        let stopReported = idle.recordUnexpectedStop()
        #expect(!stopReported)
        #expect(idle.state == .idle)
        #expect(idle.failureSequence == 0)

        var sounding = AttentionAlertStatus()
        sounding.recordStart(succeeded: true)
        let stopReported2 = sounding.recordUnexpectedStop()
        #expect(stopReported2)
        #expect(sounding.state == .stoppedUnexpectedly)
        #expect(sounding.failureSequence == 1)
        // Once stopped, a second report is nothing new.
        let stopReported3 = sounding.recordUnexpectedStop()
        #expect(!stopReported3)
        #expect(sounding.failureSequence == 1)
    }

    @Test func theHealthCheckReportsATonePlayerThatWentQuietOnce() {
        var status = AttentionAlertStatus()
        status.recordStart(succeeded: true)

        let quietReported = status.recordHealthCheck(livePlayerIsPlaying: true)
        #expect(!quietReported)
        #expect(status.state == .playing)
        let quietReported2 = status.recordHealthCheck(livePlayerIsPlaying: false)
        #expect(quietReported2)
        #expect(status.state == .stoppedUnexpectedly)
        let quietReported3 = status.recordHealthCheck(livePlayerIsPlaying: false)
        #expect(!quietReported3)
        #expect(status.failureSequence == 1)
    }

    /// The tone dips while a phrase speaks and never goes silent. Fails if
    /// speech silences it or the levels swap.
    @Test func theToneDipsButNeverGoesSilentWhileSpeechPlays() {
        let whileSpeaking = AttentionAlertStatus.toneVolume(whileSpeechIsActive: true)
        let otherwise = AttentionAlertStatus.toneVolume(whileSpeechIsActive: false)

        #expect(otherwise == AttentionAlertStatus.fullToneVolume)
        #expect(otherwise == 1)
        #expect(whileSpeaking == AttentionAlertStatus.toneVolumeWhileSpeaking)
        #expect(whileSpeaking > 0)
        #expect(whileSpeaking < otherwise)
    }
}
