import Foundation
import Testing
@testable import Brickson

/// Under Eye Tracking or head tracking with Dwell, a person's gaze often
/// stays on the tile they just chose while they listen. If the dwell fires
/// again, restarting the sentence makes the app stutter ("I'm— I'm— I'm cold")
/// and buries what they said. These tests pin down when a repeat activation is
/// absorbed — and, just as importantly, every case where it must still speak.
struct SpokenUtteranceTrackerTests {
    /// Tests never read the clock again after this: every later instant is
    /// `start` plus an offset, so they stay fast and deterministic.
    private let start = ContinuousClock.now

    @Test func nothingIsAbsorbedWhenNothingIsSpeaking() {
        let tracker = SpokenUtteranceTracker<Int>()
        #expect(!tracker.isSpeaking)
        #expect(!tracker.absorbsRepeat(of: "I'm cold.", synthesizerIsSpeaking: false, now: start))
        #expect(!tracker.absorbsRepeat(of: "I'm cold.", synthesizerIsSpeaking: true, now: start))
    }

    @Test func identicalRequestWhileThatSentenceIsStillPlayingIsAbsorbed() {
        var tracker = SpokenUtteranceTracker<Int>()
        tracker.began(1, text: "I'm cold.", at: start)

        #expect(tracker.isSpeaking)
        #expect(tracker.absorbsRepeat(
            of: "I'm cold.",
            synthesizerIsSpeaking: true,
            now: start + .seconds(1.2)
        ))
    }

    @Test func aDifferentPhraseAlwaysSpeaks() {
        var tracker = SpokenUtteranceTracker<Int>()
        tracker.began(1, text: "I'm cold.", at: start)

        #expect(!tracker.absorbsRepeat(
            of: "I'm hot.",
            synthesizerIsSpeaking: true,
            now: start + .seconds(0.5)
        ))
    }

    @Test func theSamePhraseSpeaksAgainOnceTheFirstHasFinished() {
        var tracker = SpokenUtteranceTracker<Int>()
        tracker.began(1, text: "Yes.", at: start)
        tracker.ended(1, at: start)

        #expect(!tracker.isSpeaking)
        #expect(!tracker.absorbsRepeat(
            of: "Yes.",
            synthesizerIsSpeaking: false,
            now: start + .seconds(0.8)
        ))
    }

    /// The live synthesizer state is the safety valve: if a finish callback
    /// was never delivered, stale bookkeeping must not swallow a request.
    @Test func staleBookkeepingNeverSilencesARequest() {
        var tracker = SpokenUtteranceTracker<Int>()
        tracker.began(1, text: "I need help now.", at: start)

        #expect(!tracker.absorbsRepeat(
            of: "I need help now.",
            synthesizerIsSpeaking: false,
            now: start + .seconds(1)
        ))
    }

    /// An engine that makes no progress must still allow a retry, even if it
    /// continues to claim it is speaking.
    @Test func absorptionExpiresAfterTheRepeatWindowWithoutProgress() {
        var tracker = SpokenUtteranceTracker<Int>()
        tracker.began(1, text: "I need help now.", at: start)
        let window = SpokenUtteranceTracker<Int>.repeatWindow

        #expect(tracker.absorbsRepeat(
            of: "I need help now.",
            synthesizerIsSpeaking: true,
            now: start + window - .milliseconds(100)
        ))
        #expect(!tracker.absorbsRepeat(
            of: "I need help now.",
            synthesizerIsSpeaking: true,
            now: start + window
        ))
    }

    /// A typed message can take much longer than 20 seconds to say. Ongoing
    /// word callbacks prove it is progressing; a second dwell must not keep
    /// restarting that message before its final words can be heard.
    @Test func progressingSpeechRemainsProtectedBeyondTheInitialRepeatWindow() {
        var tracker = SpokenUtteranceTracker<Int>()
        let text = "This is a longer message that I am still saying."
        tracker.began(1, text: text, at: start)

        tracker.recordProgress(1, at: start + .seconds(19))
        #expect(tracker.absorbsRepeat(
            of: text,
            synthesizerIsSpeaking: true,
            now: start + .seconds(20)
        ))

        tracker.recordProgress(1, at: start + .seconds(38))
        #expect(tracker.absorbsRepeat(
            of: text,
            synthesizerIsSpeaking: true,
            now: start + .seconds(40)
        ))

        // A different phrase still interrupts immediately, and the same one
        // remains available if the synthesizer says playback has stopped.
        #expect(!tracker.absorbsRepeat(
            of: "I need help now.",
            synthesizerIsSpeaking: true,
            now: start + .seconds(40)
        ))
        #expect(!tracker.absorbsRepeat(
            of: text,
            synthesizerIsSpeaking: false,
            now: start + .seconds(40)
        ))
    }

    @Test func aStallAfterProgressStillAllowsARetry() {
        var tracker = SpokenUtteranceTracker<Int>()
        tracker.began(1, text: "A longer message.", at: start)
        tracker.recordProgress(1, at: start + .seconds(19))

        #expect(tracker.absorbsRepeat(
            of: "A longer message.",
            synthesizerIsSpeaking: true,
            now: start + .seconds(38.9)
        ))
        #expect(!tracker.absorbsRepeat(
            of: "A longer message.",
            synthesizerIsSpeaking: true,
            now: start + .seconds(39)
        ))
    }

    @Test func lateProgressFromThePreviousUtteranceCannotRenewItsReplacement() {
        var tracker = SpokenUtteranceTracker<Int>()
        tracker.began(1, text: "First message.", at: start)
        tracker.began(2, text: "Second message.", at: start + .seconds(1))

        tracker.recordProgress(1, at: start + .seconds(19))

        #expect(!tracker.absorbsRepeat(
            of: "Second message.",
            synthesizerIsSpeaking: true,
            now: start + .seconds(21)
        ))
        #expect(tracker.activeID == 2)
    }

    @Test func reorderedProgressCannotMoveTheLastProgressTimeBackwards() {
        var tracker = SpokenUtteranceTracker<Int>()
        tracker.began(1, text: "A longer message.", at: start)

        tracker.recordProgress(1, at: start + .seconds(19))
        tracker.recordProgress(1, at: start + .seconds(2))

        #expect(tracker.absorbsRepeat(
            of: "A longer message.",
            synthesizerIsSpeaking: true,
            now: start + .seconds(30)
        ))
    }

    @Test func progressAfterFinishingCannotReviveAnUtterance() {
        var tracker = SpokenUtteranceTracker<Int>()
        tracker.began(1, text: "Finished message.", at: start)
        tracker.ended(1, at: start)

        tracker.recordProgress(1, at: start + .seconds(19))

        #expect(!tracker.isSpeaking)
        #expect(!tracker.absorbsRepeat(
            of: "Finished message.",
            synthesizerIsSpeaking: true,
            now: start + .seconds(20)
        ))
    }

    /// Choosing a new phrase cancels the old utterance, and AVFoundation
    /// reports that cancel asynchronously — after the new one has begun.
    @Test func lateEndOfAnEarlierUtteranceDoesNotClearTheCurrentOne() {
        var tracker = SpokenUtteranceTracker<Int>()
        tracker.began(1, text: "I'm cold.", at: start)
        tracker.began(2, text: "I'm hot.", at: start + .seconds(0.4))

        tracker.ended(1, at: start)

        #expect(tracker.isSpeaking)
        #expect(tracker.absorbsRepeat(
            of: "I'm hot.",
            synthesizerIsSpeaking: true,
            now: start + .seconds(1)
        ))
    }

    @Test func activeIDFollowsTheCurrentUtterance() {
        var tracker = SpokenUtteranceTracker<Int>()
        #expect(tracker.activeID == nil)
        tracker.began(7, text: "Hello.", at: start)
        #expect(tracker.activeID == 7)
        tracker.ended(7, at: start)
        #expect(tracker.activeID == nil)
    }

    @Test func onlyAnUnfinishedPhraseNeedsInterruptionRecovery() {
        var tracker = SpokenUtteranceTracker<Int>()
        #expect(!tracker.isRepeatableSpeechActive)

        tracker.began(1, text: "I need help now.", at: start)
        #expect(tracker.isRepeatableSpeechActive)

        tracker.ended(1, at: start)
        #expect(!tracker.isRepeatableSpeechActive)

        tracker.began(2, source: .preview(.previewVoice), at: start)
        #expect(!tracker.isRepeatableSpeechActive)

        tracker.began(3, text: "I'm cold.", at: start)
        tracker.ended(2, at: start)
        #expect(tracker.isRepeatableSpeechActive)

        tracker.reset()
        #expect(!tracker.isRepeatableSpeechActive)
    }

    @Test func cancellationBeforeTheInterruptionNotificationStillNeedsRecovery() {
        var tracker = SpokenUtteranceTracker<Int>()
        tracker.began(1, text: "I need help now.", at: start)

        let needsRecovery = tracker.cancelled(1)

        #expect(needsRecovery)
        #expect(!tracker.isSpeaking)
    }

    @Test func cancellingAPreviewNeverOffersToRepeatTheSample() {
        var tracker = SpokenUtteranceTracker<Int>()
        tracker.began(1, source: .preview(.previewVoice), at: start)

        let needsRecovery = tracker.cancelled(1)

        #expect(!needsRecovery)
        #expect(!tracker.isSpeaking)
    }

    @Test func cancellationAfterAnIntentionalStopCannotInventAnInterruption() {
        var tracker = SpokenUtteranceTracker<Int>()
        tracker.began(1, text: "I'm cold.", at: start)
        tracker.reset()

        let needsRecovery = tracker.cancelled(1)

        #expect(!needsRecovery)
    }

    @Test func cancellationOfTheReplacedPhraseCannotInterruptItsReplacement() {
        var tracker = SpokenUtteranceTracker<Int>()
        tracker.began(1, text: "I'm cold.", at: start)
        tracker.began(2, text: "I'm hot.", at: start)

        let needsRecovery = tracker.cancelled(1)

        #expect(!needsRecovery)
        #expect(tracker.activeID == 2)
        #expect(tracker.isRepeatableSpeechActive)
    }

    // MARK: Settings voice samples
    //
    // Slower, Faster, Preview Voice, and every voice row speak the same sample
    // sentence. A held look on one of them must not restart the sample or step
    // the rate again — but moving to a different control is a new choice, and
    // whoever is choosing has to hear what it changed.

    @Test func theSameSettingsControlWhileItsSampleIsPlayingIsAbsorbed() {
        var tracker = SpokenUtteranceTracker<Int>()
        tracker.began(1, source: .preview(.slower), at: start)

        #expect(tracker.absorbsRepeat(
            of: .preview(.slower),
            synthesizerIsSpeaking: true,
            now: start + .seconds(1.2)
        ))
    }

    @Test func aDifferentSettingsControlAlwaysSpeaks() {
        var tracker = SpokenUtteranceTracker<Int>()
        tracker.began(1, source: .preview(.slower), at: start)
        #expect(!tracker.absorbsRepeat(
            of: .preview(.faster),
            synthesizerIsSpeaking: true,
            now: start + .seconds(0.5)
        ))

        tracker.began(2, source: .preview(.voice(id: "voice-a")), at: start)
        #expect(!tracker.absorbsRepeat(
            of: .preview(.voice(id: "voice-b")),
            synthesizerIsSpeaking: true,
            now: start + .seconds(0.5)
        ))
        #expect(!tracker.absorbsRepeat(
            of: .preview(.voice(id: nil)),
            synthesizerIsSpeaking: true,
            now: start + .seconds(0.5)
        ))
    }

    /// A tile may say the very words of the sample; they are still different
    /// requests, and neither may swallow the other.
    @Test func phrasesAndSamplesNeverAbsorbEachOther() {
        let sample = "This is how I will sound."
        var tracker = SpokenUtteranceTracker<Int>()

        tracker.began(1, source: .preview(.previewVoice), at: start)
        #expect(!tracker.absorbsRepeat(
            of: sample,
            synthesizerIsSpeaking: true,
            now: start + .seconds(0.5)
        ))

        tracker.began(2, text: sample, at: start)
        #expect(!tracker.absorbsRepeat(
            of: .preview(.previewVoice),
            synthesizerIsSpeaking: true,
            now: start + .seconds(0.5)
        ))
    }

    @Test func theSameSettingsControlSpeaksAgainOnceItsSampleHasStopped() {
        var tracker = SpokenUtteranceTracker<Int>()
        tracker.began(1, source: .preview(.faster), at: start)

        #expect(!tracker.absorbsRepeat(
            of: .preview(.faster),
            synthesizerIsSpeaking: false,
            now: start + .seconds(0.5)
        ))

        tracker.ended(1, at: start)
        #expect(!tracker.absorbsRepeat(
            of: .preview(.faster),
            synthesizerIsSpeaking: true,
            now: start + .seconds(3)
        ))
    }

    @Test func resetForgetsTheActiveUtterance() {
        var tracker = SpokenUtteranceTracker<Int>()
        tracker.began(1, text: "I'm cold.", at: start)

        tracker.reset()

        #expect(!tracker.isSpeaking)
        #expect(!tracker.absorbsRepeat(
            of: "I'm cold.",
            synthesizerIsSpeaking: true,
            now: start + .seconds(0.5)
        ))
    }

    // MARK: A phrase that does not start
    //
    // The system's speech service can take a phrase and never begin it,
    // while the synthesizer says it is speaking: on CI it stayed silent for
    // about three minutes after Yes. A phrase that has said nothing by the
    // start limit is treated as not spoken (docs/DECISIONS.md, "A phrase
    // that does not start").

    /// Fails if a phrase is called not started before the limit, or never.
    @Test func aPhraseWithNoStartReportFailsOnlyOnceTheStartLimitHasPassed() {
        var tracker = SpokenUtteranceTracker<Int>()
        tracker.began(1, text: "Yes.", at: start)
        let limit = SpokenUtteranceTracker<Int>.startLimit

        #expect(!tracker.hasFailedToStart(1, at: start))
        #expect(!tracker.hasFailedToStart(1, at: start + limit - .milliseconds(1)))
        #expect(tracker.hasFailedToStart(1, at: start + limit))
    }

    /// Apple documents the start report as the moment speech begins. A long
    /// typed message may then speak for minutes. Fails if a phrase that
    /// began is ever called not started.
    @Test func aPhraseThatReportedItsStartNeverFailsToStart() {
        var tracker = SpokenUtteranceTracker<Int>()
        tracker.began(1, text: Self.helpNow, at: start)

        tracker.recordStart(1, at: start + .seconds(14))

        #expect(!tracker.hasFailedToStart(1, at: start + .seconds(600)))
    }

    /// A word is reported only once speech is under way, so it counts as a
    /// start even if the start report itself never came. Fails if only the
    /// start report counts.
    @Test func aWordReportAlsoCountsAsAStart() {
        var tracker = SpokenUtteranceTracker<Int>()
        tracker.began(1, text: Self.helpNow, at: start)

        tracker.recordProgress(1, reaching: 1, at: start + .seconds(2))

        #expect(!tracker.hasFailedToStart(1, at: start + .seconds(600)))
    }

    /// The plain word report, without an offset, counts the same way.
    @Test func aWordReportWithoutAnOffsetAlsoCountsAsAStart() {
        var tracker = SpokenUtteranceTracker<Int>()
        tracker.began(1, text: Self.helpNow, at: start)

        tracker.recordProgress(1, at: start + .seconds(2))

        #expect(!tracker.hasFailedToStart(1, at: start + .seconds(600)))
    }

    /// Reports for the phrase it replaced must not vouch for the new one.
    /// Fails if a late report for an earlier utterance counts as a start.
    @Test func reportsForAReplacedUtteranceDoNotStartTheNewOne() {
        var tracker = SpokenUtteranceTracker<Int>()
        tracker.began(1, text: "Yes.", at: start)
        tracker.began(2, text: "No.", at: start + .seconds(1))

        tracker.recordStart(1, at: start + .seconds(2))
        tracker.recordProgress(1, reaching: 3, at: start + .seconds(2))

        #expect(tracker.hasFailedToStart(2, at: start + .seconds(1) + SpokenUtteranceTracker<Int>.startLimit))
    }

    /// Only the current utterance can fail to start: one replaced, ended or
    /// forgotten is no longer the app's to recover. Fails if a stale token
    /// could stop the phrase now speaking.
    @Test func onlyTheCurrentUtteranceCanFailToStart() {
        var tracker = SpokenUtteranceTracker<Int>()
        tracker.began(1, text: "Yes.", at: start)
        tracker.began(2, text: "No.", at: start)
        #expect(!tracker.hasFailedToStart(1, at: start + .seconds(600)))

        tracker.ended(2, at: start + .seconds(1))
        #expect(!tracker.hasFailedToStart(2, at: start + .seconds(600)))

        tracker.began(3, text: "Maybe.", at: start)
        tracker.reset()
        #expect(!tracker.hasFailedToStart(3, at: start + .seconds(600)))
    }

    /// The first start report says how long the phrase took to begin, which
    /// the app logs so the limit can be checked against real starts. Fails if
    /// it reports a repeat, another utterance, or the wrong length.
    @Test func theFirstStartReportSaysHowLongThePhraseTookToBegin() {
        var tracker = SpokenUtteranceTracker<Int>()
        tracker.began(1, text: "Yes.", at: start)

        #expect(tracker.recordStart(2, at: start + .seconds(1)) == nil)
        #expect(tracker.recordStart(1, at: start + .milliseconds(5_100)) == .milliseconds(5_100))
        #expect(tracker.recordStart(1, at: start + .seconds(6)) == nil)
    }

    /// A voice may report its first word before its start, or never report
    /// a start at all; the slow start must still be measured, once. Fails
    /// if only a start report returns the measurement, or if a later report
    /// returns it again.
    @Test func aWordReportThatComesFirstSaysHowLongThePhraseTookToBegin() {
        var tracker = SpokenUtteranceTracker<Int>()
        tracker.began(1, text: "Yes, please.", at: start)

        #expect(tracker.recordProgress(2, reaching: 3, at: start + .seconds(1)) == nil)
        #expect(tracker.recordProgress(1, reaching: 3, at: start + .seconds(8)) == .seconds(8))
        #expect(tracker.recordStart(1, at: start + .milliseconds(8_100)) == nil)
        #expect(tracker.recordProgress(1, reaching: 5, at: start + .seconds(9)) == nil)

        var withoutOffsets = SpokenUtteranceTracker<Int>()
        withoutOffsets.began(1, text: "Yes, please.", at: start)
        #expect(withoutOffsets.recordProgress(1, at: start + .seconds(2)) == .seconds(2))
        #expect(withoutOffsets.recordProgress(1, at: start + .seconds(3)) == nil)
    }

    /// A phrase that began late is still audibly playing for a while after
    /// its start, so a lingering dwell on its tile is absorbed for the
    /// repeat window counted from the start, not from the moment it was
    /// handed over. Fails if a start report does not count as progress.
    @Test func aLateStartKeepsAbsorbingARepeatFromWhenItBegan() {
        var tracker = SpokenUtteranceTracker<Int>()
        tracker.began(1, text: "Yes.", at: start)
        tracker.recordStart(1, at: start + .seconds(5))

        let window = SpokenUtteranceTracker<Int>.repeatWindow
        #expect(tracker.absorbsRepeat(
            of: "Yes.",
            synthesizerIsSpeaking: true,
            now: start + window + .seconds(2)
        ))
        #expect(!tracker.absorbsRepeat(
            of: "Yes.",
            synthesizerIsSpeaking: true,
            now: start + .seconds(5) + window
        ))
    }

    /// The limit comes from evidence. On an overloaded CI simulator the
    /// slowest healthy first phrase measured took at most 5.4 seconds from
    /// the test's tap to its first audio (the app hands the phrase over
    /// between the two), so the limit leaves room for twice that and more;
    /// and the person learns of a phrase that will not be heard before the
    /// 20 seconds after which the app already treats a synthesizer that says
    /// nothing as possibly stuck
    /// (`repeatWindow`). Fails if the limit is shortened into the range of
    /// slow healthy starts, or stretched past that window.
    @Test func theStartLimitLeavesRoomForASlowFirstPhrase() {
        let slowestHealthyStartMeasured: Duration = .milliseconds(5_400)
        let limit = SpokenUtteranceTracker<Int>.startLimit

        #expect(limit >= slowestHealthyStartMeasured * 2)
        #expect(limit < SpokenUtteranceTracker<Int>.repeatWindow)
    }

    // MARK: A phrase the system cuts off
    //
    // The system can stop a phrase (a call, Siri) and report it as finished,
    // sometimes before its interruption notice arrives. How far the
    // synthesizer said it had got decides whether the phrase was cut off; an
    // interruption close behind it confirms it (docs/DECISIONS.md, "A phrase
    // the system cuts off").

    private static let helpNow = "I need help now."
    /// "I need help now.": the words end at UTF-16 offsets 1, 6, 11 and 15;
    /// the final word, "now", starts at 12.
    private static let helpNowFinalWordStart = 12

    @Test func theFinalWordStartsAfterTheLastSeparator() {
        typealias Tracker = SpokenUtteranceTracker<Int>
        #expect(Tracker.finalWordStart(in: Self.helpNow) == Self.helpNowFinalWordStart)
        #expect(Tracker.finalWordStart(in: "Yes.") == 0)
        #expect(Tracker.finalWordStart(in: "It's well-known") == 10)
        #expect(Tracker.finalWordStart(in: "Thank you 🙏") == 6)
        #expect(Tracker.finalWordStart(in: "Call 911!") == 5)
        // Offsets are UTF-16 units, as the synthesizer's NSRange reports
        // them: the emoji before the final word counts as two.
        #expect(Tracker.finalWordStart(in: "🙂 ok") == 3)
        #expect(Tracker.finalWordStart(in: "?!") == nil)
        #expect(Tracker.finalWordStart(in: "") == nil)
    }

    /// Fails if a finish whose words stopped short of the final word is read
    /// as complete.
    @Test func aFinishThatNeverReachedTheFinalWordIsReadAsEndedEarly() {
        var tracker = SpokenUtteranceTracker<Int>()
        tracker.began(1, text: Self.helpNow, at: start)
        tracker.recordProgress(1, reaching: 1, at: start + .seconds(0.2))
        tracker.recordProgress(1, reaching: 11, at: start + .seconds(0.6))

        let ending = tracker.ended(1, at: start + .seconds(0.8))
        #expect(ending == .endedBeforeItsFinalWord)
        #expect(!tracker.isSpeaking)
    }

    /// Fails if a phrase that reached its final word is reported as cut off.
    @Test func aFinishThatReachedTheFinalWordIsComplete() {
        var tracker = SpokenUtteranceTracker<Int>()
        tracker.began(1, text: Self.helpNow, at: start)
        tracker.recordProgress(1, reaching: 11, at: start + .seconds(0.6))
        tracker.recordProgress(1, reaching: 15, at: start + .seconds(0.9))

        let ending = tracker.ended(1, at: start + .seconds(1.1))
        #expect(ending == .finished)
        let cutOff = tracker.interruptionCutOffAPhrase(at: start + .seconds(1.2))
        #expect(!cutOff)
    }

    /// A voice that reports one range for the whole sentence is complete
    /// once that range is reported. Fails if the comparison uses where a
    /// range starts instead of where it ends.
    @Test func oneRangeForTheWholeSentenceCountsAsReachingTheFinalWord() {
        var tracker = SpokenUtteranceTracker<Int>()
        tracker.began(1, text: Self.helpNow, at: start)
        tracker.recordProgress(1, reaching: 16, at: start + .seconds(0.1))

        let ending = tracker.ended(1, at: start + .seconds(1))
        #expect(ending == .finished)
    }

    /// With no word reports at all there is nothing to judge by, so the
    /// finish is trusted. Fails if silence about progress reads as a cut-off.
    @Test func aFinishWithNoProgressReportsIsTrusted() {
        var tracker = SpokenUtteranceTracker<Int>()
        tracker.began(1, text: Self.helpNow, at: start)
        tracker.recordProgress(1, at: start + .seconds(0.5))

        let ending = tracker.ended(1, at: start + .seconds(1))
        #expect(ending == .finished)
        let cutOff = tracker.interruptionCutOffAPhrase(at: start + .seconds(1.1))
        #expect(!cutOff)
    }

    /// Word reports can arrive out of order. Fails if a late report of an
    /// earlier word moves the furthest point back.
    @Test func reorderedWordReportsNeverMoveTheFurthestPointBack() {
        var tracker = SpokenUtteranceTracker<Int>()
        tracker.began(1, text: Self.helpNow, at: start)
        tracker.recordProgress(1, reaching: 15, at: start + .seconds(0.9))
        tracker.recordProgress(1, reaching: 6, at: start + .seconds(0.3))

        let ending = tracker.ended(1, at: start + .seconds(1))
        #expect(ending == .finished)
    }

    @Test func aReportForAnotherUtteranceIsNotCurrent() {
        var tracker = SpokenUtteranceTracker<Int>()
        tracker.began(1, text: Self.helpNow, at: start)
        tracker.began(2, text: "Yes.", at: start + .seconds(0.2))

        let ending = tracker.ended(1, at: start + .seconds(0.3))
        #expect(ending == .notCurrent)
        #expect(tracker.activeID == 2)
    }

    /// The M1 order: the system stops the phrase, reports it finished, then
    /// posts the interruption. Fails if the interruption no longer counts the
    /// phrase as cut off, so Home would show nothing.
    @Test func anInterruptionJustAfterAnEarlyEndingCutOffThePhrase() {
        var tracker = SpokenUtteranceTracker<Int>()
        tracker.began(1, text: Self.helpNow, at: start)
        tracker.recordProgress(1, reaching: 6, at: start + .seconds(0.3))
        tracker.ended(1, at: start + .seconds(0.4))

        let cutOff = tracker.interruptionCutOffAPhrase(at: start + .seconds(0.5))
        #expect(cutOff)
        // Reported once: a second notice for the same interruption (the
        // legacy and the newer notices together) adds nothing.
        let cutOff2 = tracker.interruptionCutOffAPhrase(at: start + .seconds(0.6))
        #expect(!cutOff2)
    }

    /// An early ending with no interruption near it is not a cut-off: a voice
    /// that skips its last word report must never show a false warning.
    /// Fails if the window is removed or measured the wrong way round.
    @Test func anInterruptionLongAfterAnEarlyEndingIsUnrelated() {
        var tracker = SpokenUtteranceTracker<Int>()
        let window = SpokenUtteranceTracker<Int>.cutOffCorrelationWindow
        tracker.began(1, text: Self.helpNow, at: start)
        tracker.recordProgress(1, reaching: 6, at: start + .seconds(0.3))
        tracker.ended(1, at: start + .seconds(0.4))

        let cutOff = tracker.interruptionCutOffAPhrase(at: start + .seconds(0.4) + window)
        #expect(!cutOff)
    }

    @Test func anInterruptionJustInsideTheWindowStillCounts() {
        var tracker = SpokenUtteranceTracker<Int>()
        let window = SpokenUtteranceTracker<Int>.cutOffCorrelationWindow
        tracker.began(1, text: Self.helpNow, at: start)
        tracker.recordProgress(1, reaching: 6, at: start + .seconds(0.3))
        tracker.ended(1, at: start + .seconds(0.4))

        let cutOff = tracker.interruptionCutOffAPhrase(at: start + .seconds(0.4) + window - .milliseconds(1))
        #expect(cutOff)
    }

    /// The other order: the interruption arrives while the phrase is still
    /// current. Fails if an unfinished phrase stops counting.
    @Test func anInterruptionDuringAPhraseCutItOff() {
        var tracker = SpokenUtteranceTracker<Int>()
        tracker.began(1, text: Self.helpNow, at: start)

        let cutOff = tracker.interruptionCutOffAPhrase(at: start + .seconds(0.5))
        #expect(cutOff)
    }

    /// A new phrase, or an intentional stop, supersedes an earlier early
    /// ending. Fails if the memory survives either.
    @Test func aNewPhraseOrAStopForgetsAnEarlierEarlyEnding() {
        var tracker = SpokenUtteranceTracker<Int>()
        tracker.began(1, text: Self.helpNow, at: start)
        tracker.recordProgress(1, reaching: 6, at: start + .seconds(0.3))
        tracker.ended(1, at: start + .seconds(0.4))
        tracker.began(2, text: "Yes.", at: start + .seconds(0.5))
        tracker.recordProgress(2, reaching: 3, at: start + .seconds(0.6))
        tracker.ended(2, at: start + .seconds(0.7))
        let cutOff = tracker.interruptionCutOffAPhrase(at: start + .seconds(0.8))
        #expect(!cutOff)

        tracker.began(3, text: Self.helpNow, at: start + .seconds(1))
        tracker.recordProgress(3, reaching: 6, at: start + .seconds(1.3))
        tracker.ended(3, at: start + .seconds(1.4))
        tracker.reset()
        let cutOff2 = tracker.interruptionCutOffAPhrase(at: start + .seconds(1.5))
        #expect(!cutOff2)
    }

    /// A Settings sample is never repeated with Again, so it never counts.
    @Test func aSampleThatEndsEarlyIsNeverACutOff() {
        var tracker = SpokenUtteranceTracker<Int>()
        tracker.began(1, source: .preview(.faster), at: start)
        tracker.recordProgress(1, reaching: 4, at: start + .seconds(0.2))

        let ending = tracker.ended(1, at: start + .seconds(0.3))
        #expect(ending == .finished)
        let cutOff = tracker.interruptionCutOffAPhrase(at: start + .seconds(0.4))
        #expect(!cutOff)
    }

    /// Losing the output (a Bluetooth speaker switched off) does not stop a
    /// phrase that is still playing; it only confirms one that just ended
    /// early. Fails if output loss counts an unfinished phrase.
    @Test func outputLossOnlyConfirmsAPhraseThatAlreadyEndedEarly() {
        var tracker = SpokenUtteranceTracker<Int>()
        tracker.began(1, text: Self.helpNow, at: start)
        let outputLossCutOff = tracker.outputLossCutOffAPhrase(at: start + .seconds(0.2))
        #expect(!outputLossCutOff)
        #expect(tracker.isRepeatableSpeechActive)

        tracker.recordProgress(1, reaching: 6, at: start + .seconds(0.3))
        tracker.ended(1, at: start + .seconds(0.4))
        let outputLossCutOff2 = tracker.outputLossCutOffAPhrase(at: start + .seconds(0.5))
        #expect(outputLossCutOff2)
        let outputLossCutOff3 = tracker.outputLossCutOffAPhrase(at: start + .seconds(0.6))
        #expect(!outputLossCutOff3)
    }

    // MARK: - The word being spoken (docs/DECISIONS.md, "The word being spoken is marked")

    /// A phrase being spoken is named with its words and the latest place
    /// the voice reported, so Home can mark that word. Before any report
    /// the place is nil. Fails if a word report does not reach it.
    @Test func thePhraseBeingSpokenCarriesTheLatestReportedPlace() {
        var tracker = SpokenUtteranceTracker<Int>()
        tracker.began(1, text: "I would like water.", at: start)
        #expect(tracker.phraseInProgress == PhraseInProgress(text: "I would like water.", latestWord: nil))

        tracker.recordProgress(1, speaking: 2..<7, at: start + .seconds(0.2))
        #expect(tracker.phraseInProgress == PhraseInProgress(text: "I would like water.", latestWord: 2..<7))
        tracker.recordProgress(1, speaking: 8..<12, at: start + .seconds(0.4))
        #expect(tracker.phraseInProgress?.latestWord == 8..<12)
    }

    /// Every way a phrase ends clears its place, so no word stays marked
    /// after the voice stops: a finish, a cancel and a reset (which
    /// `SpeechService` uses for Stop, an interruption and a media reset).
    @Test func everyEndingClearsThePlace() {
        var finished = SpokenUtteranceTracker<Int>()
        finished.began(1, text: "Yes.", at: start)
        finished.recordProgress(1, speaking: 0..<3, at: start)
        finished.ended(1, at: start + .seconds(1))
        #expect(finished.phraseInProgress == nil)

        var cancelled = SpokenUtteranceTracker<Int>()
        cancelled.began(1, text: "Yes.", at: start)
        cancelled.recordProgress(1, speaking: 0..<3, at: start)
        _ = cancelled.cancelled(1)
        #expect(cancelled.phraseInProgress == nil)

        var reset = SpokenUtteranceTracker<Int>()
        reset.began(1, text: "Yes.", at: start)
        reset.recordProgress(1, speaking: 0..<3, at: start)
        reset.reset()
        #expect(reset.phraseInProgress == nil)
    }

    /// A Settings voice sample is never shown on Home, so it never names a
    /// phrase in progress. Fails if a sample's words would be marked over
    /// the person's last message.
    @Test func aVoiceSampleIsNeverAPhraseInProgress() {
        var tracker = SpokenUtteranceTracker<Int>()
        tracker.began(1, source: .preview(.previewVoice), at: start)
        tracker.recordProgress(1, speaking: 0..<4, at: start + .seconds(0.1))
        #expect(tracker.isSpeaking)
        #expect(tracker.phraseInProgress == nil)
    }

    /// A late report for the phrase that was replaced never marks a word of
    /// the new one.
    @Test func aLateReportForAReplacedPhraseMarksNothing() {
        var tracker = SpokenUtteranceTracker<Int>()
        tracker.began(1, text: "First message.", at: start)
        tracker.began(2, text: "Second message.", at: start + .seconds(1))

        tracker.recordProgress(1, speaking: 6..<13, at: start + .seconds(1.1))
        #expect(tracker.phraseInProgress == PhraseInProgress(text: "Second message.", latestWord: nil))
    }

    /// A report that names a place before the one already reported, or no
    /// place of this phrase at all, leaves the mark where it was: the mark
    /// only follows the voice forward, through this phrase's own words.
    /// Both still count as progress, so the start limit and the cut-off rule
    /// read exactly what they did. Fails if a stray report moves the mark
    /// back, or past the end of the words.
    @Test func aReportBackwardsOrPastTheEndKeepsThePlace() {
        var tracker = SpokenUtteranceTracker<Int>()
        let text = "Please turn me over."
        tracker.began(1, text: text, at: start)
        tracker.recordProgress(1, speaking: 7..<11, at: start + .seconds(0.2))

        tracker.recordProgress(1, speaking: 0..<6, at: start + .seconds(0.3))
        #expect(tracker.phraseInProgress?.latestWord == 7..<11)
        let length = (text as NSString).length
        tracker.recordProgress(1, speaking: length..<(length + 5), at: start + .seconds(0.4))
        #expect(tracker.phraseInProgress?.latestWord == 7..<11)
    }

    /// A report over only the space between two words, or an empty one,
    /// names no word, so the word already marked keeps its mark rather
    /// than losing its bar until the next word. Fails if such a report
    /// moves the mark.
    @Test func aReportOverOnlyASpaceKeepsThePlace() {
        var tracker = SpokenUtteranceTracker<Int>()
        let text = "Please turn  me over."
        tracker.began(1, text: text, at: start)
        tracker.recordProgress(1, speaking: 7..<11, at: start + .seconds(0.2))

        tracker.recordProgress(1, speaking: 11..<13, at: start + .seconds(0.3))
        #expect(tracker.phraseInProgress?.latestWord == 7..<11)
        tracker.recordProgress(1, speaking: 14..<14, at: start + .seconds(0.4))
        #expect(tracker.phraseInProgress?.latestWord == 7..<11)
        tracker.recordProgress(1, speaking: 12..<15, at: start + .seconds(0.5))
        #expect(tracker.phraseInProgress?.latestWord == 12..<15)
    }

    /// A report that names no place (the system's NSNotFound, say) still
    /// shows the phrase began, so the start limit does not stop it, and
    /// moves no mark. Fails if such a report stops counting as a start.
    @Test func aReportWithNoPlaceStillShowsThePhraseBegan() {
        var tracker = SpokenUtteranceTracker<Int>()
        tracker.began(1, text: "Yes.", at: start)
        let delay = tracker.recordProgress(1, speaking: nil, at: start + .seconds(2))

        #expect(delay == .seconds(2))
        #expect(!tracker.hasFailedToStart(1, at: start + SpokenUtteranceTracker<Int>.startLimit))
        #expect(tracker.phraseInProgress == PhraseInProgress(text: "Yes.", latestWord: nil))
    }

    /// Reporting a place records how far the voice has got exactly as the
    /// end offset did before places were kept, so the cut-off rule reads
    /// the same: a phrase whose reports reach its final word ended whole,
    /// one whose reports stop short ended early.
    @Test func aReportedPlaceFeedsTheCutOffRuleByItsEnd() {
        var whole = SpokenUtteranceTracker<Int>()
        whole.began(1, text: Self.helpNow, at: start)
        let final = SpokenUtteranceTracker<Int>.finalWordStart(in: Self.helpNow) ?? 0
        whole.recordProgress(1, speaking: final..<(final + 3), at: start + .seconds(0.2))
        #expect(whole.ended(1, at: start + .seconds(0.3)) == .finished)

        var short = SpokenUtteranceTracker<Int>()
        short.began(1, text: Self.helpNow, at: start)
        short.recordProgress(1, speaking: 0..<final, at: start + .seconds(0.2))
        #expect(short.ended(1, at: start + .seconds(0.3)) == .endedBeforeItsFinalWord)
    }
}
