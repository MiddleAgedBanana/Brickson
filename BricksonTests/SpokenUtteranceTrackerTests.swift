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
        tracker.ended(1)

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
        tracker.ended(1)

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

        tracker.ended(1)

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
        tracker.ended(7)
        #expect(tracker.activeID == nil)
    }

    @Test func onlyAnUnfinishedPhraseNeedsInterruptionRecovery() {
        var tracker = SpokenUtteranceTracker<Int>()
        #expect(!tracker.isRepeatableSpeechActive)

        tracker.began(1, text: "I need help now.", at: start)
        #expect(tracker.isRepeatableSpeechActive)

        tracker.ended(1)
        #expect(!tracker.isRepeatableSpeechActive)

        tracker.began(2, source: .preview(.previewVoice), at: start)
        #expect(!tracker.isRepeatableSpeechActive)

        tracker.began(3, text: "I'm cold.", at: start)
        tracker.ended(2)
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

        tracker.ended(1)
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
}
