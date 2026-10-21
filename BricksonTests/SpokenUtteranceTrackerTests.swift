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

        #expect(tracker.ended(1, at: start + .seconds(0.8)) == .endedBeforeItsFinalWord)
        #expect(!tracker.isSpeaking)
    }

    /// Fails if a phrase that reached its final word is reported as cut off.
    @Test func aFinishThatReachedTheFinalWordIsComplete() {
        var tracker = SpokenUtteranceTracker<Int>()
        tracker.began(1, text: Self.helpNow, at: start)
        tracker.recordProgress(1, reaching: 11, at: start + .seconds(0.6))
        tracker.recordProgress(1, reaching: 15, at: start + .seconds(0.9))

        #expect(tracker.ended(1, at: start + .seconds(1.1)) == .finished)
        #expect(!tracker.interruptionCutOffAPhrase(at: start + .seconds(1.2)))
    }

    /// A voice that reports one range for the whole sentence is complete
    /// once that range is reported. Fails if the comparison uses where a
    /// range starts instead of where it ends.
    @Test func oneRangeForTheWholeSentenceCountsAsReachingTheFinalWord() {
        var tracker = SpokenUtteranceTracker<Int>()
        tracker.began(1, text: Self.helpNow, at: start)
        tracker.recordProgress(1, reaching: 16, at: start + .seconds(0.1))

        #expect(tracker.ended(1, at: start + .seconds(1)) == .finished)
    }

    /// With no word reports at all there is nothing to judge by, so the
    /// finish is trusted. Fails if silence about progress reads as a cut-off.
    @Test func aFinishWithNoProgressReportsIsTrusted() {
        var tracker = SpokenUtteranceTracker<Int>()
        tracker.began(1, text: Self.helpNow, at: start)
        tracker.recordProgress(1, at: start + .seconds(0.5))

        #expect(tracker.ended(1, at: start + .seconds(1)) == .finished)
        #expect(!tracker.interruptionCutOffAPhrase(at: start + .seconds(1.1)))
    }

    /// Word reports can arrive out of order. Fails if a late report of an
    /// earlier word moves the furthest point back.
    @Test func reorderedWordReportsNeverMoveTheFurthestPointBack() {
        var tracker = SpokenUtteranceTracker<Int>()
        tracker.began(1, text: Self.helpNow, at: start)
        tracker.recordProgress(1, reaching: 15, at: start + .seconds(0.9))
        tracker.recordProgress(1, reaching: 6, at: start + .seconds(0.3))

        #expect(tracker.ended(1, at: start + .seconds(1)) == .finished)
    }

    @Test func aReportForAnotherUtteranceIsNotCurrent() {
        var tracker = SpokenUtteranceTracker<Int>()
        tracker.began(1, text: Self.helpNow, at: start)
        tracker.began(2, text: "Yes.", at: start + .seconds(0.2))

        #expect(tracker.ended(1, at: start + .seconds(0.3)) == .notCurrent)
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

        #expect(tracker.interruptionCutOffAPhrase(at: start + .seconds(0.5)))
        // Reported once: a second notice for the same interruption (the
        // legacy and the newer notices together) adds nothing.
        #expect(!tracker.interruptionCutOffAPhrase(at: start + .seconds(0.6)))
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

        #expect(!tracker.interruptionCutOffAPhrase(at: start + .seconds(0.4) + window))
    }

    @Test func anInterruptionJustInsideTheWindowStillCounts() {
        var tracker = SpokenUtteranceTracker<Int>()
        let window = SpokenUtteranceTracker<Int>.cutOffCorrelationWindow
        tracker.began(1, text: Self.helpNow, at: start)
        tracker.recordProgress(1, reaching: 6, at: start + .seconds(0.3))
        tracker.ended(1, at: start + .seconds(0.4))

        #expect(tracker.interruptionCutOffAPhrase(
            at: start + .seconds(0.4) + window - .milliseconds(1)
        ))
    }

    /// The other order: the interruption arrives while the phrase is still
    /// current. Fails if an unfinished phrase stops counting.
    @Test func anInterruptionDuringAPhraseCutItOff() {
        var tracker = SpokenUtteranceTracker<Int>()
        tracker.began(1, text: Self.helpNow, at: start)

        #expect(tracker.interruptionCutOffAPhrase(at: start + .seconds(0.5)))
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
        #expect(!tracker.interruptionCutOffAPhrase(at: start + .seconds(0.8)))

        tracker.began(3, text: Self.helpNow, at: start + .seconds(1))
        tracker.recordProgress(3, reaching: 6, at: start + .seconds(1.3))
        tracker.ended(3, at: start + .seconds(1.4))
        tracker.reset()
        #expect(!tracker.interruptionCutOffAPhrase(at: start + .seconds(1.5)))
    }

    /// A Settings sample is never repeated with Again, so it never counts.
    @Test func aSampleThatEndsEarlyIsNeverACutOff() {
        var tracker = SpokenUtteranceTracker<Int>()
        tracker.began(1, source: .preview(.faster), at: start)
        tracker.recordProgress(1, reaching: 4, at: start + .seconds(0.2))

        #expect(tracker.ended(1, at: start + .seconds(0.3)) == .finished)
        #expect(!tracker.interruptionCutOffAPhrase(at: start + .seconds(0.4)))
    }

    /// Losing the output (a Bluetooth speaker switched off) does not stop a
    /// phrase that is still playing; it only confirms one that just ended
    /// early. Fails if output loss counts an unfinished phrase.
    @Test func outputLossOnlyConfirmsAPhraseThatAlreadyEndedEarly() {
        var tracker = SpokenUtteranceTracker<Int>()
        tracker.began(1, text: Self.helpNow, at: start)
        #expect(!tracker.outputLossCutOffAPhrase(at: start + .seconds(0.2)))
        #expect(tracker.isRepeatableSpeechActive)

        tracker.recordProgress(1, reaching: 6, at: start + .seconds(0.3))
        tracker.ended(1, at: start + .seconds(0.4))
        #expect(tracker.outputLossCutOffAPhrase(at: start + .seconds(0.5)))
        #expect(!tracker.outputLossCutOffAPhrase(at: start + .seconds(0.6)))
    }
}
