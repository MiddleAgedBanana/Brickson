import Accessibility
import Testing

@testable import Brickson

struct AudioSafetyPolicyTests {
    @Test func volumeBelowThresholdWarns() {
        let policy = AudioSafetyPolicy(
            attentionState: .idle,
            audioSessionHealthy: true,
            outputVolume: 0.19
        )

        #expect(policy.issue == .lowOutputVolume)
    }

    @Test func volumeAtThresholdDoesNotWarn() {
        let policy = AudioSafetyPolicy(
            attentionState: .idle,
            audioSessionHealthy: true,
            outputVolume: AudioSafetyPolicy.lowVolumeThreshold
        )

        #expect(policy.issue == nil)
    }

    @Test func failedAlertOutranksUnavailableSession() {
        let policy = AudioSafetyPolicy(
            attentionState: .failedToStart,
            audioSessionHealthy: false,
            outputVolume: 0
        )

        #expect(policy.issue == .attentionAlertFailed)
    }

    @Test func acuteStopsOutrankAmbientWarningsAndOfferRecovery() {
        let alertPolicy = AudioSafetyPolicy(
            attentionState: .stoppedUnexpectedly,
            audioSessionHealthy: true,
            outputVolume: 0
        )

        #expect(alertPolicy.issue == .attentionAlertStopped)

        let speechPolicy = AudioSafetyPolicy(
            attentionState: .idle,
            speechInterruptionState: .stoppedUnexpectedly,
            audioSessionHealthy: true,
            outputVolume: 1
        )

        #expect(speechPolicy.issue == .speechStopped)
        #expect(speechPolicy.issue?.announcementUrgency == .urgent)
        #expect(speechPolicy.issue?.compactMessage.contains("Again") == true)
        #expect(speechPolicy.issue?.message.contains("Again") == true)

        let typedSpeechPolicy = AudioSafetyPolicy(
            attentionState: .idle,
            speechInterruptionState: .stoppedUnexpectedly,
            speechRecoveryAction: .showPhrasesThenRepeat,
            audioSessionHealthy: true,
            outputVolume: 1
        )

        #expect(typedSpeechPolicy.issue == .typedSpeechStopped)
        #expect(typedSpeechPolicy.issue?.compactMessage == "Stopped: Phrases")
        #expect(typedSpeechPolicy.issue?.message.contains("Phrases") == true)
        #expect(typedSpeechPolicy.issue?.message.contains("Again") == true)
        #expect(typedSpeechPolicy.issue?.message.contains("Speak") == false)

        let modalSpeechPolicy = AudioSafetyPolicy(
            attentionState: .idle,
            speechInterruptionState: .stoppedUnexpectedly,
            speechRecoveryAction: .dismissThenRepeat,
            audioSessionHealthy: true,
            outputVolume: 1
        )

        #expect(modalSpeechPolicy.issue == .modalSpeechStopped)
        #expect(modalSpeechPolicy.issue?.compactMessage == "Stopped — Back")
        #expect(modalSpeechPolicy.issue?.message.contains("Choose Back") == true)
        #expect(modalSpeechPolicy.issue?.message.contains("Close") == false)
        #expect(modalSpeechPolicy.issue?.message.contains("Again") == true)
    }

    @Test func unavailableSessionOutranksLowVolume() {
        let policy = AudioSafetyPolicy(
            attentionState: .idle,
            audioSessionHealthy: false,
            outputVolume: 0
        )

        #expect(policy.issue == .audioSessionUnavailable)
    }

    @Test func nextSpeechAttemptClearsOnlyARepeatableInterruptionWarning() {
        var speechStatus = SpeechInterruptionStatus()

        speechStatus.recordInterruption(
            repeatableSpeechActive: false
        )
        #expect(speechStatus.state == .idle)
        #expect(speechStatus.sequence == 0)

        speechStatus.recordInterruption(
            repeatableSpeechActive: true
        )
        #expect(speechStatus.state == .stoppedUnexpectedly)
        #expect(speechStatus.sequence == 1)

        speechStatus.recordInterruption(
            repeatableSpeechActive: true
        )
        #expect(speechStatus.sequence == 2)

        speechStatus.recordSpeechAttempt()
        #expect(speechStatus.state == .idle)
        #expect(speechStatus.sequence == 2)

        let policy = AudioSafetyPolicy(
            attentionState: .idle,
            speechInterruptionState: speechStatus.state,
            audioSessionHealthy: true,
            outputVolume: 1
        )

        #expect(policy.issue == nil)
    }

    /// The system can stop synthesis before delivering the interruption.
    /// Its live flag cannot decide whether the tracked sentence needs retry.
    @Test func interruptedPhraseStillOffersRecoveryAfterTheSynthesizerStops() {
        var speechStatus = SpeechInterruptionStatus()

        speechStatus.recordInterruption(
            repeatableSpeechActive: true
        )

        #expect(speechStatus.state == .stoppedUnexpectedly)
        #expect(speechStatus.sequence == 1)
    }

    @Test(arguments: [true, false])
    func interruptionAndCancellationOrderingProducesOneRecoveryEvent(cancellationArrivesFirst: Bool) {
        var tracker = SpokenUtteranceTracker<Int>()
        var speechStatus = SpeechInterruptionStatus()
        tracker.began(1, text: "I need help now.", at: .now)

        if cancellationArrivesFirst {
            speechStatus.recordInterruption(repeatableSpeechActive: tracker.cancelled(1))
        }

        speechStatus.recordInterruption(repeatableSpeechActive: tracker.isRepeatableSpeechActive)
        tracker.reset()

        if !cancellationArrivesFirst {
            speechStatus.recordInterruption(repeatableSpeechActive: tracker.cancelled(1))
        }

        #expect(speechStatus.state == .stoppedUnexpectedly)
        #expect(speechStatus.sequence == 1)
        #expect(!tracker.isSpeaking)
    }

    @Test func successfulAlertRetryRemovesItsSpecificWarning() {
        let policy = AudioSafetyPolicy(
            attentionState: .playing,
            audioSessionHealthy: true,
            outputVolume: 1
        )

        #expect(policy.issue == nil)
    }

    @Test func alertFailureDoesNotRecommendAnotherPotentiallySilentAppAction() {
        let message = HomeAudioIssue.attentionAlertFailed.message.lowercased()

        #expect(!message.contains("emergency phrase"))
        #expect(!message.contains("another way"))
    }

    @Test func stoppedAlertCopyDoesNotInventACause() {
        let message = HomeAudioIssue.attentionAlertStopped.message.lowercased()

        #expect(message.contains("unexpectedly"))
        #expect(!message.contains("because"))
    }

    @Test func provisionalThresholdCopyDoesNotClaimMeasuredInaudibility() {
        let message = HomeAudioIssue.lowOutputVolume.message.lowercased()

        #expect(message.contains("very low"))
        #expect(!message.contains("too low"))
    }

    @Test(arguments: [
        HomeAudioIssue.attentionAlertFailed,
        .attentionAlertStopped,
        .speechStopped,
        .typedSpeechStopped,
        .modalSpeechStopped,
        .modalAttentionAlertSilent,
        .audioSessionUnavailable,
    ])
    func acuteFailuresRequestUrgentAnnouncements(issue: HomeAudioIssue) {
        #expect(issue.announcementUrgency == .urgent)
    }

    @Test func lowVolumeAnnouncementRemainsInformational() {
        #expect(HomeAudioIssue.lowOutputVolume.announcementUrgency == .informational)
    }

    /// Every issue, including any added later, fits the reserved strip.
    @Test(arguments: HomeAudioIssue.allCases)
    func compactStatusCopyFitsAReservedStrip(issue: HomeAudioIssue) {
        #expect(!issue.compactMessage.isEmpty)
        #expect(issue.compactMessage.count <= 16)
    }

    @Test func ambientIssueChangesAreAnnouncedIncludingInitialDelivery() {
        #expect(
            AudioAnnouncementPolicy.ambientIssueToAnnounce(.audioSessionUnavailable)
                == .audioSessionUnavailable
        )
        #expect(
            AudioAnnouncementPolicy.ambientIssueToAnnounce(.lowOutputVolume)
                == .lowOutputVolume
        )
    }

    @Test func discreteFailureIssuesUseIndependentEvents() {
        #expect(AudioAnnouncementPolicy.ambientIssueToAnnounce(.attentionAlertFailed) == nil)
        #expect(AudioAnnouncementPolicy.ambientIssueToAnnounce(.attentionAlertStopped) == nil)
        #expect(AudioAnnouncementPolicy.ambientIssueToAnnounce(.speechStopped) == nil)
        #expect(AudioAnnouncementPolicy.ambientIssueToAnnounce(.typedSpeechStopped) == nil)
        #expect(AudioAnnouncementPolicy.ambientIssueToAnnounce(.modalSpeechStopped) == nil)
        #expect(AudioAnnouncementPolicy.ambientIssueToAnnounce(.modalAttentionAlertSilent) == nil)
        #expect(
            AudioAnnouncementPolicy.speechIssueToAnnounce(
                .stoppedUnexpectedly,
                recoveryAction: .repeatLast
            )
                == .speechStopped
        )
        #expect(
            AudioAnnouncementPolicy.speechIssueToAnnounce(
                .stoppedUnexpectedly,
                recoveryAction: .showPhrasesThenRepeat
            ) == .typedSpeechStopped
        )
        #expect(
            AudioAnnouncementPolicy.speechIssueToAnnounce(
                .stoppedUnexpectedly,
                recoveryAction: .dismissThenRepeat
            ) == .modalSpeechStopped
        )
        #expect(
            AudioAnnouncementPolicy.speechIssueToAnnounce(
                .idle,
                recoveryAction: .repeatLast
            ) == nil
        )
    }

    @Test(arguments: [
        (AttentionAlertState.failedToStart, HomeAudioIssue.attentionAlertFailed),
        (.stoppedUnexpectedly, .attentionAlertStopped),
    ])
    func everyAttentionFailureEventGetsItsOwnAnnouncement(
        state: AttentionAlertState,
        expectedIssue: HomeAudioIssue
    ) {
        #expect(AudioAnnouncementPolicy.attentionIssueToAnnounce(state) == expectedIssue)
    }

    @Test(arguments: [AttentionAlertState.idle, .playing])
    func ordinaryAttentionStatesDoNotAnnounceFailure(state: AttentionAlertState) {
        #expect(AudioAnnouncementPolicy.attentionIssueToAnnounce(state) == nil)
        #expect(AudioAnnouncementPolicy.attentionIssueToAnnounce(state, recoveryAction: .dismissThenRepeat) == nil)
    }

    /// Settings covers Home and has no Get Attention, so an alarm that
    /// failed or stopped while it is open names the way back first, on its
    /// line and in what VoiceOver hears (invariant 4: the text names a
    /// reachable control). Fails if Settings' words send the person to a
    /// Get Attention that is not on screen, or if Home's or typing's words
    /// lose Get Attention, which is on screen there.
    @Test(arguments: [AttentionAlertState.failedToStart, .stoppedUnexpectedly])
    func overSettingsAnAlarmProblemNamesBackThenGetAttention(state: AttentionAlertState) {
        let overSettings = AudioSafetyPolicy(
            attentionState: state,
            speechRecoveryAction: .dismissThenRepeat,
            audioSessionHealthy: true,
            outputVolume: 1
        )
        #expect(overSettings.issue == .modalAttentionAlertSilent)
        #expect(AudioAnnouncementPolicy.attentionIssueToAnnounce(state, recoveryAction: .dismissThenRepeat) == .modalAttentionAlertSilent)
        let message = HomeAudioIssue.modalAttentionAlertSilent.message
        #expect(message.contains("Choose Back"))
        #expect(message.contains("Get Attention"))
        #expect(HomeAudioIssue.modalAttentionAlertSilent.compactMessage.contains("Back"))

        let onHome = state == .failedToStart ? HomeAudioIssue.attentionAlertFailed : .attentionAlertStopped
        for recovery in [SpeechRecoveryAction.repeatLast, .showPhrasesThenRepeat] {
            let policy = AudioSafetyPolicy(
                attentionState: state,
                speechRecoveryAction: recovery,
                audioSessionHealthy: true,
                outputVolume: 1
            )
            #expect(policy.issue == onHome, "\(recovery)")
            #expect(AudioAnnouncementPolicy.attentionIssueToAnnounce(state, recoveryAction: recovery) == onHome, "\(recovery)")
        }
    }

    /// Home's one status line: a problem first, because something cannot be
    /// heard; then the alarm sounding; then speech. Fails if "Speaking"
    /// hides "Sounding", or "Sounding" hides a problem such as "Alert
    /// stopped".
    @Test func theStatusLinePutsProblemsThenTheAlarmThenSpeech() {
        #expect(HomeStatusLine(issue: .lowOutputVolume, alarmIsSounding: true, isSpeaking: true) == .issue(.lowOutputVolume))
        #expect(HomeStatusLine(issue: .attentionAlertStopped, alarmIsSounding: false, isSpeaking: false) == .issue(.attentionAlertStopped))
        #expect(HomeStatusLine(issue: nil, alarmIsSounding: true, isSpeaking: true) == .sounding)
        #expect(HomeStatusLine(issue: nil, alarmIsSounding: true, isSpeaking: false) == .sounding)
        #expect(HomeStatusLine(issue: nil, alarmIsSounding: false, isSpeaking: true) == .speaking)
        #expect(HomeStatusLine(issue: nil, alarmIsSounding: false, isSpeaking: false) == nil)
    }

    /// VoiceOver hears the whole sentence, which names the control to use,
    /// not the short text the warning strip shows.
    @Test func announcementsSayTheFullSentence() {
        for issue in HomeAudioIssue.allCases {
            let announcement = AudioAnnouncementPolicy.announcement(for: issue)
            #expect(String(announcement.characters) == issue.message, "\(issue)")
        }
        #expect(
            String(AudioAnnouncementPolicy.announcement(for: .speechStopped).characters)
                .contains("Again")
        )
    }

    /// Urgent failures interrupt whatever VoiceOver is saying and cannot be
    /// cut off; low volume waits until VoiceOver has finished.
    @Test func urgentAnnouncementsInterruptAndLowVolumeWaits() {
        for issue in HomeAudioIssue.allCases {
            let priority = AudioAnnouncementPolicy.announcement(for: issue)
                .accessibilitySpeechAnnouncementPriority
            switch issue.announcementUrgency {
            case .urgent:
                #expect(priority == .high, "\(issue)")
            case .informational:
                #expect(priority == .low, "\(issue)")
            }
        }
    }
}
