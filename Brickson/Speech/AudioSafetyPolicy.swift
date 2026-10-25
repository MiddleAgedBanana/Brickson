import Accessibility
import Foundation

nonisolated enum AttentionAlertState: Equatable, Sendable {
    case idle
    case playing
    case failedToStart
    case stoppedUnexpectedly
}

nonisolated enum SpeechInterruptionState: Equatable {
    case idle
    case stoppedUnexpectedly
}

/// The control that is actually reachable on the surface where an interrupted
/// utterance, or an alarm that failed or stopped, must be recovered. Recovery
/// copy must never direct Voice Control to a button that the current mode has
/// structurally removed: over Home (`dismissThenRepeat`, Settings) neither
/// Again nor Get Attention is on screen.
nonisolated enum SpeechRecoveryAction: Equatable {
    case repeatLast
    case showPhrasesThenRepeat
    case dismissThenRepeat
}

/// Tracks a repeatable utterance that an OS interruption cut short. Keeping
/// this as a value type makes callback ordering and retry behavior testable
/// without depending on simulator speech timing.
nonisolated struct SpeechInterruptionStatus: Equatable {
    private(set) var state: SpeechInterruptionState = .idle
    private(set) var sequence = 0

    /// Use the app's unfinished-utterance bookkeeping: the system may have
    /// already stopped the synthesizer by the time its notification arrives.
    mutating func recordInterruption(repeatableSpeechActive: Bool) {
        guard repeatableSpeechActive else { return }
        state = .stoppedUnexpectedly
        sequence &+= 1
    }

    mutating func recordSpeechAttempt() {
        state = .idle
    }
}

nonisolated enum HomeAudioIssue: CaseIterable, Hashable {
    case attentionAlertFailed
    case attentionAlertStopped
    case speechStopped
    case typedSpeechStopped
    case modalSpeechStopped
    /// The alarm failed or stopped while a screen covers Home, where Get
    /// Attention is not: the way back comes first.
    case modalAttentionAlertSilent
    case audioSessionUnavailable
    case lowOutputVolume

    var compactMessage: String {
        switch self {
        case .attentionAlertFailed:
            String(localized: "Alert failed")
        case .attentionAlertStopped:
            String(localized: "Alert stopped")
        case .speechStopped:
            String(localized: "Stopped — Again")
        case .typedSpeechStopped:
            String(localized: "Stopped: Phrases")
        case .modalSpeechStopped:
            String(localized: "Stopped — Back")
        case .modalAttentionAlertSilent:
            String(localized: "No alert — Back")
        case .audioSessionUnavailable:
            String(localized: "Audio failed")
        case .lowOutputVolume:
            String(localized: "Volume low")
        }
    }

    var announcementUrgency: AudioAnnouncementUrgency {
        switch self {
        case .attentionAlertFailed, .attentionAlertStopped, .speechStopped,
             .typedSpeechStopped, .modalSpeechStopped, .modalAttentionAlertSilent,
             .audioSessionUnavailable:
            .urgent
        case .lowOutputVolume:
            .informational
        }
    }

    var message: String {
        switch self {
        case .attentionAlertFailed:
            String(localized: "Get Attention did not start. Choose it again.")
        case .attentionAlertStopped:
            String(localized: "Get Attention stopped unexpectedly. Choose it again to restart.")
        case .speechStopped:
            String(localized: "Speech stopped unexpectedly. Choose Again to repeat it.")
        case .typedSpeechStopped:
            String(localized: "Speech stopped unexpectedly. Choose Phrases, then choose Again to repeat it.")
        case .modalSpeechStopped:
            String(localized: "Speech stopped unexpectedly. Choose Back until Home appears, then choose Again to repeat it.")
        case .modalAttentionAlertSilent:
            String(localized: "Get Attention is not sounding. Choose Back until Home appears, then choose Get Attention.")
        case .audioSessionUnavailable:
            String(localized: "Audio could not start. Speech and Get Attention may be silent. Try again.")
        case .lowOutputVolume:
            String(localized: "Device volume is very low. Raise it before relying on speech or Get Attention.")
        }
    }

    var systemImage: String {
        switch self {
        case .attentionAlertFailed, .attentionAlertStopped, .modalAttentionAlertSilent:
            "bell.slash.fill"
        case .speechStopped, .typedSpeechStopped, .modalSpeechStopped,
             .audioSessionUnavailable:
            "speaker.slash.fill"
        case .lowOutputVolume:
            "speaker.wave.1.fill"
        }
    }
}

nonisolated enum AudioAnnouncementUrgency: Equatable {
    case informational
    case urgent
}

nonisolated struct AudioSafetyPolicy {
    static let lowVolumeThreshold: Float = 0.2

    let attentionState: AttentionAlertState
    let speechInterruptionState: SpeechInterruptionState
    let speechRecoveryAction: SpeechRecoveryAction
    let audioSessionHealthy: Bool
    let outputVolume: Float

    init(
        attentionState: AttentionAlertState,
        speechInterruptionState: SpeechInterruptionState = .idle,
        speechRecoveryAction: SpeechRecoveryAction = .repeatLast,
        audioSessionHealthy: Bool,
        outputVolume: Float
    ) {
        self.attentionState = attentionState
        self.speechInterruptionState = speechInterruptionState
        self.speechRecoveryAction = speechRecoveryAction
        self.audioSessionHealthy = audioSessionHealthy
        self.outputVolume = outputVolume
    }

    var issue: HomeAudioIssue? {
        // A failed explicit Get Attention attempt needs immediate feedback,
        // even when an ambient volume/session warning was already present.
        if let attentionIssue = Self.attentionIssue(attentionState, recoveryAction: speechRecoveryAction) {
            return attentionIssue
        }

        if speechInterruptionState == .stoppedUnexpectedly {
            switch speechRecoveryAction {
            case .repeatLast:
                return .speechStopped
            case .showPhrasesThenRepeat:
                return .typedSpeechStopped
            case .dismissThenRepeat:
                return .modalSpeechStopped
            }
        }

        return ambientIssue
    }

    /// The problem with the audio itself, whatever the alarm and speech are
    /// doing: a session that could not start, then a very low volume.
    /// VoiceOver is told these from here rather than from `issue`, so a
    /// warning the line shows first never keeps one from being announced.
    var ambientIssue: HomeAudioIssue? {
        if !audioSessionHealthy {
            return .audioSessionUnavailable
        }
        if outputVolume < Self.lowVolumeThreshold {
            return .lowOutputVolume
        }
        return nil
    }

    /// The warning for an alarm that failed or stopped. Home and typing
    /// show Get Attention, so the warning says to choose it again; a screen
    /// over Home does not, so the warning names Back first.
    static func attentionIssue(
        _ state: AttentionAlertState,
        recoveryAction: SpeechRecoveryAction
    ) -> HomeAudioIssue? {
        switch state {
        case .idle, .playing:
            return nil
        case .failedToStart, .stoppedUnexpectedly:
            guard recoveryAction != .dismissThenRepeat else { return .modalAttentionAlertSilent }
            return state == .failedToStart ? .attentionAlertFailed : .attentionAlertStopped
        }
    }
}

/// What Home's one status line shows: a problem first, because something
/// cannot be heard (invariant 4); otherwise the alarm sounding, which goes
/// on until someone chooses Stop; otherwise speech in progress; otherwise a
/// typed message that cannot be kept (invariant 5), which lasts until the
/// next save and so waits behind what is about sound now
/// (docs/DECISIONS.md, "Typing on Home").
nonisolated enum HomeStatusLine: Equatable {
    case issue(HomeAudioIssue)
    case sounding
    case speaking
    case draft(DraftIssue)

    init?(issue: HomeAudioIssue?, alarmIsSounding: Bool, isSpeaking: Bool, draftIssue: DraftIssue? = nil) {
        if let issue {
            self = .issue(issue)
        } else if alarmIsSounding {
            self = .sounding
        } else if isSpeaking {
            self = .speaking
        } else if let draftIssue {
            self = .draft(draftIssue)
        } else {
            return nil
        }
    }
}

/// Keeps ambient-condition announcements separate from discrete alert failures.
/// `failureSequence` drives the latter so every failed retry is announced even
/// when the alert's state remains `.failedToStart`.
nonisolated enum AudioAnnouncementPolicy {
    static func ambientIssueToAnnounce(_ issue: HomeAudioIssue?) -> HomeAudioIssue? {
        switch issue {
        case .audioSessionUnavailable, .lowOutputVolume:
            issue
        case .attentionAlertFailed, .attentionAlertStopped, .speechStopped,
             .typedSpeechStopped, .modalSpeechStopped, .modalAttentionAlertSilent, nil:
            nil
        }
    }

    static func attentionIssueToAnnounce(
        _ state: AttentionAlertState,
        recoveryAction: SpeechRecoveryAction = .repeatLast
    ) -> HomeAudioIssue? {
        AudioSafetyPolicy.attentionIssue(state, recoveryAction: recoveryAction)
    }

    static func speechIssueToAnnounce(
        _ state: SpeechInterruptionState,
        recoveryAction: SpeechRecoveryAction
    ) -> HomeAudioIssue? {
        switch state {
        case .stoppedUnexpectedly:
            switch recoveryAction {
            case .repeatLast:
                .speechStopped
            case .showPhrasesThenRepeat:
                .typedSpeechStopped
            case .dismissThenRepeat:
                .modalSpeechStopped
            }
        case .idle:
            nil
        }
    }

    /// What VoiceOver says when a warning appears. A warning that only
    /// appears on screen is not heard by someone who is not looking at it,
    /// so Home posts this as an announcement. It is the full sentence, which
    /// names the control to use, not the short text the strip shows. Urgent
    /// failures interrupt whatever VoiceOver is saying and cannot be cut off
    /// (`.high`); low volume waits until VoiceOver has finished (`.low`).
    static func announcement(for issue: HomeAudioIssue) -> AttributedString {
        var announcement = AttributedString(issue.message)
        switch issue.announcementUrgency {
        case .urgent:
            announcement.accessibilitySpeechAnnouncementPriority = .high
        case .informational:
            announcement.accessibilitySpeechAnnouncementPriority = .low
        }
        return announcement
    }
}
