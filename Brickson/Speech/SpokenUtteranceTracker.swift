import Foundation

/// What a speech request is compared on when deciding whether a lingering
/// dwell re-fired it: a phrase by its words, a Settings voice sample by the
/// control that asked for it. Every sample control speaks the same sentence,
/// so comparing samples by text would swallow Faster right after Slower, or
/// a second voice right after the first — exactly when someone needs to hear
/// what changed.
nonisolated enum UtteranceSource: Equatable, Sendable {
    case phrase(String)
    case preview(VoicePreviewControl)
}

/// The Settings controls that play the voice sample.
nonisolated enum VoicePreviewControl: Equatable, Sendable {
    case slower
    case faster
    case previewVoice
    /// A row in the voice list; nil is Automatic.
    case voice(id: String?)
}

/// Bookkeeping for the utterance currently being spoken, and the rule for
/// absorbing a repeated activation of the phrase just chosen.
///
/// Under Eye Tracking or head tracking with Dwell, a person's gaze often stays
/// on the tile while they listen, and a second dwell can fire. Restarting the
/// same sentence from the top makes it stutter and harder to understand, so
/// an identical request while that sentence is still audibly playing is
/// absorbed. Everything else speaks: a different phrase, the same phrase once
/// it has finished, and any request the live synthesizer state cannot confirm
/// is redundant. Settings' voice samples follow the same rule, compared by
/// control (`UtteranceSource`).
///
/// This is not a confirmation step and never delays first activation
/// (AGENTS.md, invariant 2) — it only declines to interrupt the sentence
/// already playing.
///
/// Time is `ContinuousClock`, never `Date`: the wall clock can jump (time
/// zones, manual changes, network time), and a jump backwards would stretch
/// the recovery window (docs/LESSONS.md, "Timers use ContinuousClock").
/// Callers pass the current instant in, so tests never read the real clock.
nonisolated struct SpokenUtteranceTracker<ID: Equatable & Sendable>: Sendable {
    /// A synthesizer that reports no speech progress for this long may be
    /// stuck, and restarting is a better gamble than silence. Measure from
    /// the latest spoken unit, not the start: a long typed message may take
    /// minutes to finish and must not restart while it is making progress.
    static var repeatWindow: Duration { .seconds(20) }

    private struct Active: Sendable {
        let id: ID
        let source: UtteranceSource
        var lastProgressAt: ContinuousClock.Instant
    }

    private var active: Active?

    var isSpeaking: Bool { active != nil }

    /// A phrase still awaiting completion can be repeated with Again. A
    /// Settings sample cannot, and a completed phrase must not leave a stale
    /// recovery flag behind when an unrelated interruption arrives later.
    var isRepeatableSpeechActive: Bool {
        if case .phrase = active?.source { return true }
        return false
    }

    /// The utterance currently believed to be playing, if any.
    var activeID: ID? { active?.id }

    mutating func began(_ id: ID, text: String, at instant: ContinuousClock.Instant) {
        began(id, source: .phrase(text), at: instant)
    }

    mutating func began(_ id: ID, source: UtteranceSource, at instant: ContinuousClock.Instant) {
        active = Active(id: id, source: source, lastProgressAt: instant)
    }

    /// Word callbacks refresh only the current utterance's recovery window.
    /// They can cross onto the main actor out of order, so an older callback
    /// must neither revive a replaced utterance nor shorten the current window.
    mutating func recordProgress(_ id: ID, at instant: ContinuousClock.Instant) {
        guard var current = active, current.id == id else { return }
        current.lastProgressAt = max(current.lastProgressAt, instant)
        active = current
    }

    /// Ignores callbacks for anything but the current utterance: cancelling
    /// the previous sentence is reported asynchronously, after the next began.
    mutating func ended(_ id: ID) {
        guard active?.id == id else { return }
        active = nil
    }

    /// Returns whether a cancelled current utterance needs Again guidance.
    mutating func cancelled(_ id: ID) -> Bool {
        guard active?.id == id else { return false }
        let needsRecovery = isRepeatableSpeechActive
        ended(id)
        return needsRecovery
    }

    mutating func reset() {
        active = nil
    }

    func absorbsRepeat(
        of text: String,
        synthesizerIsSpeaking: Bool,
        now: ContinuousClock.Instant
    ) -> Bool {
        absorbsRepeat(of: .phrase(text), synthesizerIsSpeaking: synthesizerIsSpeaking, now: now)
    }

    func absorbsRepeat(
        of source: UtteranceSource,
        synthesizerIsSpeaking: Bool,
        now: ContinuousClock.Instant
    ) -> Bool {
        guard synthesizerIsSpeaking, let active, active.source == source else { return false }
        return now - active.lastProgressAt < Self.repeatWindow
    }
}
