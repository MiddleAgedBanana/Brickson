import AVFoundation
import Foundation
import Testing

@testable import Brickson

@MainActor
struct SpeechServiceTests {
    // MARK: Settings chosen at launch

    /// Test launches must restore their own speech preferences. Reading
    /// UserDefaults.standard instead of the supplied suite fails this;
    /// zero is a valid stored rate, not a missing preference.
    @Test func restoresVoiceAndRateFromTheProvidedSettings() throws {
        let suiteName = "SpeechServiceTests-\(UUID().uuidString)"
        let settings = try #require(UserDefaults(suiteName: suiteName))
        defer { settings.removePersistentDomain(forName: suiteName) }
        let voiceID = "test-voice-\(UUID().uuidString)"
        settings.set(voiceID, forKey: "selectedVoiceID")
        settings.set(AVSpeechUtteranceMinimumSpeechRate, forKey: "speechRate")

        let speech = AudioHarness(settings: settings).speech

        #expect(speech.selectedVoiceID == voiceID)
        #expect(speech.speechRate == AVSpeechUtteranceMinimumSpeechRate)
    }

    /// Preference changes must survive a new service using the same test
    /// suite. Writing either preference to a different store fails this.
    /// Choosing automatic voice must remove the old choice, not revive it
    /// on the next launch.
    @Test func savesAndClearsPreferencesInTheProvidedSettings() throws {
        let suiteName = "SpeechServiceTests-\(UUID().uuidString)"
        let settings = try #require(UserDefaults(suiteName: suiteName))
        defer { settings.removePersistentDomain(forName: suiteName) }
        let speech = AudioHarness(settings: settings).speech
        let voiceID = "test-voice-\(UUID().uuidString)"
        let rate: Float = 0.3

        speech.selectedVoiceID = voiceID
        speech.speechRate = rate

        #expect(settings.string(forKey: "selectedVoiceID") == voiceID)
        #expect(settings.float(forKey: "speechRate") == rate)
        let reloaded = AudioHarness(settings: settings).speech
        #expect(reloaded.selectedVoiceID == voiceID)
        #expect(reloaded.speechRate == rate)

        reloaded.selectedVoiceID = nil

        #expect(settings.object(forKey: "selectedVoiceID") == nil)
        #expect(AudioHarness(settings: settings).speech.selectedVoiceID == nil)
    }

    /// A fresh test launch must forget speech preferences too. Retaining
    /// old settings, or treating a missing rate as zero, fails this.
    @Test func freshTestStorageResetsSpeechPreferences() throws {
        let suiteName = "SpeechServiceTests-\(UUID().uuidString)"
        let settings = try #require(UserDefaults(suiteName: suiteName))
        defer { settings.removePersistentDomain(forName: suiteName) }
        settings.set("test-voice", forKey: "selectedVoiceID")
        settings.set(Float(0.3), forKey: "speechRate")
        let directory = URL.temporaryDirectory.appending(path: suiteName, directoryHint: .isDirectory)

        LaunchOptions.parse(["--fresh-test-storage"])
            .prepareStorage(directory: directory, settingsSuite: suiteName)
        let speech = AudioHarness(settings: settings).speech

        #expect(speech.selectedVoiceID == nil)
        #expect(speech.speechRate == AVSpeechUtteranceDefaultSpeechRate)
    }

    // MARK: Starting a phrase

    /// Home resets the message's scroll position on every phrase start, so
    /// a start that repeats the same words must still count. Fails if
    /// `phraseStartCount` only changes with `lastSpokenText`.
    @Test func everyPhraseStartIsCountedEvenWithTheSameWords() {
        let speech = AudioHarness().speech
        let before = speech.phraseStartCount

        speech.speak("Hello.")
        #expect(speech.phraseStartCount == before + 1)

        speech.stop()
        speech.speak("Hello.")
        #expect(speech.phraseStartCount == before + 2)
        #expect(speech.lastSpokenText == "Hello.")

        speech.stop()
        speech.repeatLast()
        #expect(speech.phraseStartCount == before + 3)
    }

    /// Nothing to say is not a start. Fails if blank text is counted or
    /// handed to the synthesizer.
    @Test func blankTextIsNotAStart() {
        let harness = AudioHarness()
        let before = harness.speech.phraseStartCount

        harness.speech.speak("   ")

        #expect(harness.speech.phraseStartCount == before)
        #expect(harness.speech.lastSpokenText == nil)
        #expect(harness.synthesizer.requests.isEmpty)
    }

    /// Fails if the words are not trimmed, or the rate is not the chosen one.
    @Test func thePhraseIsSpokenAtOnceAtTheChosenRate() {
        let harness = AudioHarness()
        harness.speech.speechRate = 0.42

        harness.speech.speak("  I need water.\n")

        let request = harness.synthesizer.requests.last
        #expect(request?.text == "I need water.")
        #expect(request?.rate == 0.42)
        #expect(harness.speech.isSpeaking)
    }

    /// A held look re-firing the tile while its phrase still plays must not
    /// restart it (SpokenUtteranceTracker). Fails if the repeat is spoken.
    @Test func aRepeatOfThePhraseStillSpeakingIsAbsorbed() {
        let harness = AudioHarness()
        harness.speech.speak("Water.")
        let starts = harness.speech.phraseStartCount

        harness.speech.speak("Water.")

        #expect(harness.synthesizer.requests.count == 1)
        #expect(harness.speech.phraseStartCount == starts)
    }

    /// A paused phrase is not audible, so choosing it again must speak.
    /// Fails if `isPaused` is ignored.
    @Test func aPausedPhraseIsNeverAbsorbed() {
        let harness = AudioHarness()
        harness.speech.speak("Water.")
        harness.synthesizer.isPaused = true

        harness.speech.speak("Water.")

        #expect(harness.synthesizer.requests.count == 2)
    }

    /// Fails if a new phrase waits for the old one, or keeps its token.
    @Test func aDifferentPhraseReplacesTheOneSpeakingAtOnce() {
        let harness = AudioHarness()
        harness.speech.speak("Yes.")

        harness.speech.speak("No.")

        let requests = harness.synthesizer.requests
        #expect(requests.map(\.text) == ["Yes.", "No."])
        #expect(harness.synthesizer.stopCount == 1)
        #expect(requests[0].token != requests[1].token)
    }

    // MARK: Tokens (code audit L1)

    /// The reference app keyed utterances by ObjectIdentifier, which the
    /// system may reuse once an utterance is freed, so a late finish for an
    /// old phrase could end the new one. Fails if an earlier phrase's
    /// report can end the phrase speaking now.
    @Test func aLateFinishForAReplacedPhraseLeavesTheNewOneSpeaking() {
        let harness = AudioHarness()
        harness.speech.speak("Yes.")
        let first = harness.synthesizer.latestToken
        harness.speech.speak("No.")

        harness.synthesizer.finish(first)
        harness.synthesizer.cancel(first)

        #expect(harness.speech.isSpeaking)
        #expect(harness.speech.speechInterruptionState == .idle)
    }

    @Test func tokensOnlyEverIncrease() {
        let harness = AudioHarness()
        for text in ["One.", "Two.", "Three."] {
            harness.speech.speak(text)
        }

        let values = harness.synthesizer.requests.map(\.token.rawValue)
        #expect(values == values.sorted())
        #expect(Set(values).count == values.count)
    }

    // MARK: Ends and cut-offs

    @Test func aFinishedPhraseClearsTheIndicatorAndShowsNothing() {
        let harness = AudioHarness()
        harness.speech.speak("I need help now.")
        harness.synthesizer.reportProgress(through: 16)

        harness.synthesizer.finish()

        #expect(!harness.speech.isSpeaking)
        #expect(harness.issue == nil)
    }

    /// An interruption mid-phrase stops it and names Again; the words stay
    /// for Again. Fails if nothing shows, or the text is lost.
    @Test func anInterruptionDuringAPhraseNamesAgain() {
        let harness = AudioHarness()
        harness.speech.speak("I need help now.")

        harness.notifications.interruptionBegan()

        #expect(harness.speech.speechInterruptionState == .stoppedUnexpectedly)
        #expect(harness.issue == .speechStopped)
        #expect(harness.speech.lastSpokenText == "I need help now.")
        #expect(!harness.speech.isSpeaking)
        #expect(harness.synthesizer.stopCount == 1)
    }

    @Test func anInterruptionWhileQuietShowsNothing() {
        let harness = AudioHarness()

        harness.notifications.interruptionBegan()

        #expect(harness.speech.speechInterruptionState == .idle)
    }

    /// Brickson never resumes by itself (invariant 4). Fails if the end of
    /// an interruption speaks anything.
    @Test func theEndOfAnInterruptionNeverSpeaks() {
        let harness = AudioHarness()
        harness.speech.speak("I need help now.")
        harness.notifications.interruptionBegan()

        harness.notifications.interruptionEnded()

        #expect(harness.synthesizer.requests.count == 1)
        #expect(!harness.speech.isSpeaking)
    }

    /// Code audit M1: the system can report a phrase it stopped as finished
    /// before its interruption notice arrives. Fails before the fix: the
    /// notice then found nothing speaking and Home showed nothing.
    @Test func aPhraseFinishedBeforeItsFinalWordThenInterruptedNamesAgain() {
        let harness = AudioHarness()
        harness.speech.speak("I need help now.")
        harness.synthesizer.reportProgress(through: 6) // "I need"
        harness.synthesizer.finish()

        harness.notifications.interruptionBegan()

        #expect(harness.speech.speechInterruptionState == .stoppedUnexpectedly)
        #expect(harness.speech.speechInterruptionSequence == 1)
    }

    /// The other side of M1: a phrase that got to its final word was heard.
    /// Fails if any interruption after a finish shows a warning.
    @Test func aPhraseThatReachedItsFinalWordIsNotCalledCutOff() {
        let harness = AudioHarness()
        harness.speech.speak("I need help now.")
        harness.synthesizer.reportProgress(through: 6)
        harness.synthesizer.reportProgress(through: 15) // "now"
        harness.synthesizer.finish()

        harness.notifications.interruptionBegan()

        #expect(harness.speech.speechInterruptionState == .idle)
    }

    /// Losing the output (headphones unplugged) while a phrase speaks lets it
    /// carry on through the new output; after an early finish it needs
    /// Again. Fails if either case is read the other way.
    @Test func losingTheOutputNamesAgainOnlyForAPhraseThatEndedEarly() {
        let carriesOn = AudioHarness()
        carriesOn.speech.speak("I need help now.")
        carriesOn.notifications.routeChanged(.oldDeviceUnavailable)
        #expect(carriesOn.speech.speechInterruptionState == .idle)
        #expect(carriesOn.speech.isSpeaking)

        let endedEarly = AudioHarness()
        endedEarly.speech.speak("I need help now.")
        endedEarly.synthesizer.reportProgress(through: 6)
        endedEarly.synthesizer.finish()
        endedEarly.notifications.routeChanged(.oldDeviceUnavailable)
        #expect(endedEarly.speech.speechInterruptionState == .stoppedUnexpectedly)
    }

    /// The system can cancel a phrase before its interruption notice; the
    /// two must show one warning. Fails if the warning is lost or doubled.
    @Test func aSystemCancelThenTheNoticeShowOneWarning() {
        let harness = AudioHarness()
        harness.speech.speak("I need help now.")

        harness.synthesizer.cancel()
        harness.notifications.interruptionBegan()

        #expect(harness.speech.speechInterruptionState == .stoppedUnexpectedly)
        #expect(harness.speech.speechInterruptionSequence == 1)
    }

    /// Settings' voice sample is not repeatable with Again, so cutting it off
    /// shows nothing. Fails if a sample leaves "Stopped — Again".
    @Test func aCutOffVoiceSampleShowsNothing() {
        let harness = AudioHarness()
        harness.speech.preview(from: .previewVoice)

        harness.notifications.interruptionBegan()

        #expect(harness.speech.speechInterruptionState == .idle)
        #expect(harness.speech.lastSpokenText == nil)
    }

    // MARK: Voice samples

    /// A voice row plays its sample in that row's voice, so a voice can be
    /// heard before it is chosen. Fails if the sample plays in the chosen
    /// voice instead.
    @Test func aVoiceRowsSamplePlaysInThatVoice() {
        let chosen = VoiceDescriptor(id: "chosen", name: "Chosen", languageCode: "en-US", quality: .premium, isPersonalVoice: false)
        let other = VoiceDescriptor(id: "other", name: "Other", languageCode: "en-US", quality: .standard, isPersonalVoice: false)
        let harness = AudioHarness(voices: [chosen, other])
        harness.speech.selectedVoiceID = "chosen"

        harness.speech.preview(from: .voice(id: "other"))

        #expect(harness.synthesizer.requests.last?.voiceIdentifier == "other")
        #expect(harness.synthesizer.requests.last?.text == SpeechService.previewSample)
        #expect(harness.speech.selectedVoiceID == "chosen")
    }

    /// Automatic's row plays the voice Automatic would pick, not the chosen
    /// one. Fails if it plays the chosen voice.
    @Test func theAutomaticRowsSamplePlaysTheAutomaticVoice() {
        let chosen = VoiceDescriptor(id: "chosen", name: "Chosen", languageCode: "en-US", quality: .standard, isPersonalVoice: false)
        let best = VoiceDescriptor(id: "best", name: "Best", languageCode: "en-US", quality: .premium, isPersonalVoice: false)
        let harness = AudioHarness(voices: [chosen, best])
        harness.speech.selectedVoiceID = "chosen"

        harness.speech.preview(from: .voice(id: nil))

        #expect(harness.synthesizer.requests.last?.voiceIdentifier == "best")
    }

    /// The other sample controls, and phrases, use the chosen voice.
    @Test(arguments: [VoicePreviewControl.slower, .faster, .normalRate, .previewVoice])
    func otherSamplesUseTheChosenVoice(control: VoicePreviewControl) {
        let chosen = VoiceDescriptor(id: "chosen", name: "Chosen", languageCode: "en-US", quality: .standard, isPersonalVoice: false)
        let best = VoiceDescriptor(id: "best", name: "Best", languageCode: "en-US", quality: .premium, isPersonalVoice: false)
        let harness = AudioHarness(voices: [chosen, best])
        harness.speech.selectedVoiceID = "chosen"

        harness.speech.preview(from: control)
        harness.speech.speak("Hello.")

        #expect(harness.synthesizer.requests.map(\.voiceIdentifier) == ["chosen", "chosen"])
    }

    /// Normal Speed returns to the system rate, and a held look on it
    /// cannot fire it twice while its sample plays.
    @Test func normalSpeedReturnsToTheSystemRate() {
        let harness = AudioHarness()
        harness.speech.speechRate = AVSpeechUtteranceMaximumSpeechRate

        harness.speech.stepRate({ _ in AVSpeechUtteranceDefaultSpeechRate }, from: .normalRate)
        harness.speech.stepRate({ _ in AVSpeechUtteranceMinimumSpeechRate }, from: .normalRate)

        #expect(harness.speech.speechRate == AVSpeechUtteranceDefaultSpeechRate)
        #expect(harness.synthesizer.requests.count == 1)
    }

    /// The next phrase clears the warning. Fails if it lingers.
    @Test func speakingAgainClearsTheWarning() {
        let harness = AudioHarness()
        harness.speech.speak("I need help now.")
        harness.notifications.interruptionBegan()

        harness.speech.repeatLast()

        #expect(harness.speech.speechInterruptionState == .idle)
        #expect(harness.speech.isSpeaking)
    }

    // MARK: The missed-finish watchdog

    /// Fails if the watchdog ends a phrase that is still playing.
    @Test func theWatchdogLeavesAPhraseThatIsStillPlaying() async {
        let harness = AudioHarness()
        harness.speech.speak("I need help now.")
        #expect(await waitUntil { harness.speechSleeper.pendingDurations == [.seconds(1)] })

        #expect(await harness.speechSleeper.wakeAll())

        #expect(harness.speechSleeper.pendingDurations == [.seconds(1)])
        #expect(harness.speech.isSpeaking)
        #expect(harness.speech.speechInterruptionState == .idle)
    }

    /// A synthesizer that goes quiet with no report must not leave
    /// "Speaking" on screen over silence. Fails if the watchdog never acts,
    /// or acts on the first quiet look.
    @Test func theWatchdogNamesAgainWhenThePhraseGoesQuietWithoutAReport() async {
        let harness = AudioHarness()
        harness.speech.speak("I need help now.")
        #expect(await waitUntil { harness.speechSleeper.isAnyoneSleeping })
        harness.synthesizer.goQuietWithoutReporting()

        #expect(await harness.speechSleeper.wakeAll())
        #expect(harness.speechSleeper.pendingDurations == [.milliseconds(500)])
        #expect(harness.speech.isSpeaking)

        #expect(await harness.speechSleeper.wakeAll())
        #expect(harness.speech.speechInterruptionState == .stoppedUnexpectedly)
        #expect(!harness.speech.isSpeaking)
        #expect(!harness.coordinator.isHeld(by: .speech))
    }

    /// An interruption can leave the synthesizer paused, which is silent.
    /// Fails if a paused synthesizer counts as playing, or is left paused.
    @Test func theWatchdogStopsASynthesizerLeftPaused() async {
        let harness = AudioHarness()
        harness.speech.speak("I need help now.")
        #expect(await waitUntil { harness.speechSleeper.isAnyoneSleeping })
        harness.synthesizer.isPaused = true

        #expect(await harness.speechSleeper.wakeAll())
        #expect(harness.speechSleeper.pendingDurations == [.milliseconds(500)])
        #expect(await harness.speechSleeper.wakeAll())

        #expect(harness.speech.speechInterruptionState == .stoppedUnexpectedly)
        #expect(harness.synthesizer.stopCount == 1)
        #expect(!harness.synthesizer.isPaused)
    }

    /// A report that lands between the two looks wins. Fails if the
    /// watchdog calls a finished phrase cut off.
    @Test func theWatchdogLeavesAPhraseWhoseFinishLandsDuringTheGrace() async {
        let harness = AudioHarness()
        harness.speech.speak("Yes.")
        #expect(await waitUntil { harness.speechSleeper.isAnyoneSleeping })
        harness.synthesizer.goQuietWithoutReporting()
        #expect(await harness.speechSleeper.wakeAll())
        #expect(harness.speechSleeper.pendingDurations == [.milliseconds(500)])

        harness.synthesizer.finish()
        #expect(await harness.speechSleeper.wakeAll())

        #expect(!harness.speechSleeper.isAnyoneSleeping)
        #expect(harness.speech.speechInterruptionState == .idle)
    }

    // MARK: Audio that never started (code audit L3)

    /// When the session could not activate, Home shows "Audio failed". The
    /// reference app's watchdog replaced it with "Stopped — Again", and Again
    /// failed the same way, round and round. Fails before the fix.
    @Test func whenAudioNeverStartedTheWatchdogLeavesAudioFailedShowing() async {
        let harness = AudioHarness()
        harness.audioSession.refusesActivation = true
        harness.speech.speak("I need help now.")
        #expect(harness.issue == .audioSessionUnavailable)
        #expect(await waitUntil { harness.speechSleeper.isAnyoneSleeping })
        harness.synthesizer.goQuietWithoutReporting()

        #expect(await harness.speechSleeper.wakeAll())
        #expect(harness.speechSleeper.pendingDurations == [.milliseconds(500)])
        #expect(await harness.speechSleeper.wakeAll())

        #expect(!harness.speech.isSpeaking)
        #expect(harness.speech.speechInterruptionState == .idle)
        #expect(harness.issue == .audioSessionUnavailable)
    }

    /// The same for a cancel. Fails if a cancel hides "Audio failed".
    @Test func whenAudioNeverStartedACancelLeavesAudioFailedShowing() {
        let harness = AudioHarness()
        harness.audioSession.refusesActivation = true
        harness.speech.speak("I need help now.")

        harness.synthesizer.cancel()

        #expect(harness.speech.speechInterruptionState == .idle)
        #expect(harness.issue == .audioSessionUnavailable)
    }

    /// During a call only a mixing session activates; speech still plays,
    /// so a cut-off still names Again. Fails if the mixed fallback is read
    /// as a failure.
    @Test func speechDuringACallStillNamesAgainWhenCutOff() {
        let harness = AudioHarness()
        harness.audioSession.refusesUnmixedActivation = true
        harness.speech.speak("I need help now.")
        #expect(harness.coordinator.lastActivation == .mixedWithOtherAudio)

        harness.notifications.interruptionBegan()

        #expect(harness.issue == .speechStopped)
    }

    // MARK: The audio session

    /// Speech holds the session only while it speaks, so the alarm's tone
    /// returns to full level on every ending. Fails if any ending keeps it.
    @Test func speechHoldsTheSessionOnlyWhileSpeaking() {
        let harness = AudioHarness()

        harness.speech.speak("One.")
        #expect(harness.coordinator.isHeld(by: .speech))
        harness.synthesizer.finish()
        #expect(!harness.coordinator.isHeld(by: .speech))

        harness.speech.speak("Two.")
        harness.speech.stop()
        #expect(!harness.coordinator.isHeld(by: .speech))

        harness.speech.speak("Three.")
        harness.synthesizer.cancel()
        #expect(!harness.coordinator.isHeld(by: .speech))

        harness.speech.speak("Four.")
        harness.notifications.interruptionBegan()
        #expect(!harness.coordinator.isHeld(by: .speech))

        harness.speech.speak("Five.")
        harness.notifications.mediaServicesReset()
        #expect(!harness.coordinator.isHeld(by: .speech))
    }

    @Test func everyPhraseActivatesTheSessionFirst() {
        let harness = AudioHarness()

        harness.speech.speak("Yes.")

        #expect(harness.audioSession.activeCalls == [true])
        #expect(harness.safety.audioSessionHealthy)
    }

    /// The media daemon restarted: speech must come back without a relaunch,
    /// name Again for the phrase it cut off, and speak nothing by itself.
    /// Fails if the old synthesizer is kept or its late reports count.
    @Test func aMediaResetBuildsANewSynthesizerAndNamesAgain() {
        let harness = AudioHarness()
        harness.speech.speak("I need help now.")
        let old = harness.synthesizer

        harness.notifications.mediaServicesReset()

        #expect(harness.synthesizers.made.count == 2)
        #expect(harness.speech.speechInterruptionState == .stoppedUnexpectedly)
        #expect(harness.speech.lastSpokenText == "I need help now.")
        #expect(harness.synthesizer.requests.isEmpty)
        #expect(!harness.safety.audioSessionHealthy)

        harness.speech.repeatLast()
        #expect(harness.synthesizer.requests.map(\.text) == ["I need help now."])
        old.finish()
        #expect(harness.speech.isSpeaking)
        #expect(harness.safety.audioSessionHealthy)
    }

    // MARK: Settings

    /// Fails if the voice or rate is kept anywhere but the settings given.
    @Test func theVoiceAndRateAreKeptInTheGivenSettings() {
        let defaults = freshDefaults()
        let first = AudioHarness(settings: defaults).speech

        first.selectedVoiceID = "voice.a"
        first.speechRate = 0.4

        #expect(defaults.string(forKey: SpeechService.voiceIDKey) == "voice.a")
        #expect(defaults.object(forKey: SpeechService.rateKey) as? Float == 0.4)
        let second = AudioHarness(settings: defaults).speech
        #expect(second.selectedVoiceID == "voice.a")
        #expect(second.speechRate == 0.4)
    }

    /// UI tests run on test-only settings, so the service must never read
    /// or write the app's own settings. Fails if it falls back to
    /// `UserDefaults.standard`.
    @Test func aServiceGivenTestSettingsNeverTouchesTheStandardSettings() {
        let standardVoice = UserDefaults.standard.object(forKey: SpeechService.voiceIDKey) as? String
        let standardRate = UserDefaults.standard.object(forKey: SpeechService.rateKey) as? Float
        let speech = AudioHarness(settings: freshDefaults()).speech

        speech.selectedVoiceID = "voice.only-in-the-test-suite"
        speech.speechRate = 0.123

        #expect(UserDefaults.standard.object(forKey: SpeechService.voiceIDKey) as? String == standardVoice)
        #expect(UserDefaults.standard.object(forKey: SpeechService.rateKey) as? Float == standardRate)
    }

    @Test func noSavedRateMeansTheSystemDefault() {
        let speech = AudioHarness().speech

        #expect(speech.speechRate == AVSpeechUtteranceDefaultSpeechRate)
        #expect(speech.selectedVoiceID == nil)
    }

    /// A saved minimum is a real choice, not a missing value. Fails if a
    /// stored 0 reads as "nothing saved".
    @Test func aSavedMinimumRateIsKept() {
        let defaults = freshDefaults()
        defaults.set(AVSpeechUtteranceMinimumSpeechRate, forKey: SpeechService.rateKey)

        let speech = AudioHarness(settings: defaults).speech

        #expect(speech.speechRate == AVSpeechUtteranceMinimumSpeechRate)
    }

    @Test func aSavedRateOutOfRangeIsClamped() {
        let defaults = freshDefaults()
        defaults.set(Float(50), forKey: SpeechService.rateKey)

        let speech = AudioHarness(settings: defaults).speech

        #expect(speech.speechRate == AVSpeechUtteranceMaximumSpeechRate)
    }

    // MARK: Voices

    /// A chosen voice that was uninstalled while the app was away falls to
    /// the next-best voice, not the system default, and the list is read
    /// again. Fails if the missing voice is requested or the list kept.
    @Test func aChosenVoiceThatNoLongerLoadsFallsToTheNextBest() {
        let chosen = VoiceDescriptor(id: "chosen", name: "Chosen", languageCode: "en-US", quality: .premium, isPersonalVoice: false)
        let next = VoiceDescriptor(id: "next", name: "Next", languageCode: "en-US", quality: .enhanced, isPersonalVoice: false)
        let harness = AudioHarness(voices: [chosen, next])
        harness.speech.selectedVoiceID = "chosen"
        harness.catalog.missingIDs = ["chosen"]
        let readsBefore = harness.catalog.readCount

        harness.speech.speak("Hello.")

        #expect(harness.synthesizer.requests.last?.voiceIdentifier == "next")
        #expect(harness.catalog.readCount == readsBefore + 1)
    }

    /// With no voices listed, speech still speaks in the system default.
    @Test func noVoicesStillSpeaks() {
        let harness = AudioHarness(voices: [])

        harness.speech.speak("Hello.")

        #expect(harness.synthesizer.requests.count == 1)
        #expect(harness.synthesizer.requests.last?.voiceIdentifier == nil)
    }

    @Test func theVoiceListIsReadAgainWhenTheSystemChangesIt() {
        let harness = AudioHarness(voices: [])
        let added = VoiceDescriptor(id: "added", name: "Added", languageCode: "en-US", quality: .standard, isPersonalVoice: false)
        harness.catalog.voices = [added]

        harness.notifications.center.post(name: AVSpeechSynthesizer.availableVoicesDidChangeNotification, object: nil)

        #expect(harness.speech.availableVoices == [added])
    }

    /// Fails if Personal Voice permission is not asked at start, or its
    /// answer does not reach the service.
    @Test func thePersonalVoiceAnswerIsKeptAndTheVoicesReadAgain() async throws {
        let harness = AudioHarness()
        #expect(harness.personalVoice.requestCount == 1)
        let completion = try #require(harness.personalVoice.completion)
        let readsBefore = harness.catalog.readCount

        completion(.authorized)

        #expect(await waitUntil { harness.speech.personalVoiceStatus == .authorized })
        #expect(harness.catalog.readCount == readsBefore + 1)
    }
}
