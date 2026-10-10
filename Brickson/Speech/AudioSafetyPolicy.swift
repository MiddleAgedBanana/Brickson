import Accessibility
import Foundation

nonisolated enum AttentionAlertState: Equatable {
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
/// utterance must be recovered. Recovery copy must never direct Voice Control
/// to a button that the current mode has structurally removed.
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
        case .audioSessionUnavailable:
            String(localized: "Audio failed")
        case .lowOutputVolume:
            String(localized: "Volume low")
        }
    }

    var announcementUrgency: AudioAnnouncementUrgency {
        switch self {
        case .attentionAlertFailed, .attentionAlertStopped, .speechStopped,
             .typedSpeechStopped, .modalSpeechStopped,
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
        case .audioSessionUnavailable:
            String(localized: "Audio could not start. Speech and Get Attention may be silent. Try again.")
        case .lowOutputVolume:
            String(localized: "Device volume is very low. Raise it before relying on speech or Get Attention.")
        }
    }

    var systemImage: String {
        switch self {
        case .attentionAlertFailed, .attentionAlertStopped:
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
        switch attentionState {
        case .failedToStart:
            return .attentionAlertFailed
        case .stoppedUnexpectedly:
            return .attentionAlertStopped
        case .idle, .playing:
            break
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

        if !audioSessionHealthy {
            return .audioSessionUnavailable
        }
        if outputVolume < Self.lowVolumeThreshold {
            return .lowOutputVolume
        }
        return nil
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
             .typedSpeechStopped, .modalSpeechStopped, nil:
            nil
        }
    }

    static func attentionIssueToAnnounce(_ state: AttentionAlertState) -> HomeAudioIssue? {
        switch state {
        case .failedToStart:
            .attentionAlertFailed
        case .stoppedUnexpectedly:
            .attentionAlertStopped
        case .idle, .playing:
            nil
        }
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
