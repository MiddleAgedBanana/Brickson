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
    /// Back to the system's normal speaking rate, placed apart from Slower
    /// and Faster.
    case normalRate
    case previewVoice
    /// A row in the voice list; nil is Automatic. Its sample plays in that
    /// voice, so a voice can be heard before it is chosen.
    case voice(id: String?)
}

/// How the synthesizer's "finished" report for an utterance is read.
nonisolated enum UtteranceEnding: Equatable, Sendable {
    /// The report was for an utterance that is no longer the current one.
    case notCurrent
    /// It reached its final word, or it reported no progress at all to judge by.
    case finished
    /// The synthesizer said it finished, but the words it reported never
    /// reached the final word: the system may have cut the phrase off.
    case endedBeforeItsFinalWord
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
/// It also decides whether an interruption cut a phrase off, from how far
/// the synthesizer said it had got (docs/DECISIONS.md, "A phrase the system
/// cuts off"). The system can report a phrase it stopped as finished, and
/// can report that before its interruption notice arrives; without this, the
/// person's sentence would stop half-way with nothing on screen.
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

    /// How soon after a phrase ended before its final word an interruption
    /// must arrive for the two to be read as one cut-off. The system stops
    /// the synthesizer and posts its notice together; a phrase that merely
    /// ended early, with no interruption near it, is left alone, so a voice
    /// that skips reporting its last word never shows a false warning.
    static var cutOffCorrelationWindow: Duration { .seconds(3) }

    private struct Active: Sendable {
        let id: ID
        let source: UtteranceSource
        var lastProgressAt: ContinuousClock.Instant
        /// UTF-16 offset of the final word of a phrase; nil for a sample, or
        /// for text with no letters or digits, which is never judged short.
        let finalWordStart: Int?
        /// The furthest UTF-16 offset the synthesizer has said it reached;
        /// nil until it reports a spoken range.
        var spokenThrough: Int?
    }

    private var active: Active?
    /// When the latest phrase ended before its final word, if it did and
    /// nothing has started or stopped since.
    private var endedEarlyAt: ContinuousClock.Instant?

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
        let finalWordStart: Int? = switch source {
        case let .phrase(text): Self.finalWordStart(in: text)
        case .preview: nil
        }
        active = Active(
            id: id,
            source: source,
            lastProgressAt: instant,
            finalWordStart: finalWordStart,
            spokenThrough: nil
        )
        endedEarlyAt = nil
    }

    /// Word callbacks refresh only the current utterance's recovery window.
    /// They can cross onto the main actor out of order, so an older callback
    /// must neither revive a replaced utterance nor shorten the current window.
    mutating func recordProgress(_ id: ID, at instant: ContinuousClock.Instant) {
        guard var current = active, current.id == id else { return }
        current.lastProgressAt = max(current.lastProgressAt, instant)
        active = current
    }

    /// A word callback that also says how far the synthesizer has got: the
    /// end of the spoken range, as a UTF-16 offset into the utterance's text
    /// (`NSRange`'s units). Out-of-order callbacks never move it backwards.
    mutating func recordProgress(
        _ id: ID,
        reaching offset: Int,
        at instant: ContinuousClock.Instant
    ) {
        guard var current = active, current.id == id else { return }
        current.lastProgressAt = max(current.lastProgressAt, instant)
        current.spokenThrough = max(current.spokenThrough ?? offset, offset)
        active = current
    }

    /// The synthesizer said the utterance finished. Ignores reports for
    /// anything but the current utterance: cancelling the previous sentence
    /// is reported asynchronously, after the next began.
    @discardableResult
    mutating func ended(_ id: ID, at instant: ContinuousClock.Instant) -> UtteranceEnding {
        guard let current = active, current.id == id else { return .notCurrent }
        active = nil
        guard let finalWordStart = current.finalWordStart,
              let spokenThrough = current.spokenThrough,
              spokenThrough <= finalWordStart
        else { return .finished }
        endedEarlyAt = instant
        return .endedBeforeItsFinalWord
    }

    /// Returns whether a cancelled current utterance needs Again guidance.
    mutating func cancelled(_ id: ID) -> Bool {
        guard active?.id == id else { return false }
        let needsRecovery = isRepeatableSpeechActive
        active = nil
        endedEarlyAt = nil
        return needsRecovery
    }

    mutating func reset() {
        active = nil
        endedEarlyAt = nil
    }

    /// Whether the interruption arriving now (a call, Siri, another app's
    /// alarm, a media-services reset) cut off a phrase: one still in
    /// progress, or one that ended before its final word moments ago. Reports
    /// the second case once.
    mutating func interruptionCutOffAPhrase(at now: ContinuousClock.Instant) -> Bool {
        let inProgress = isRepeatableSpeechActive
        let endedEarly = takeRecentEarlyEnding(at: now)
        return inProgress || endedEarly
    }

    /// Whether the output device disappearing just now cut off a phrase. A
    /// phrase still in progress carries on through the new output, so only
    /// one that ended before its final word moments ago counts. Reports it once.
    mutating func outputLossCutOffAPhrase(at now: ContinuousClock.Instant) -> Bool {
        takeRecentEarlyEnding(at: now)
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

    private mutating func takeRecentEarlyEnding(at now: ContinuousClock.Instant) -> Bool {
        guard let endedEarlyAt else { return false }
        self.endedEarlyAt = nil
        return now - endedEarlyAt < Self.cutOffCorrelationWindow
    }

    /// The UTF-16 offset of the start of the last run of letters or digits:
    /// the final word, or the final part of it ("known" in "well-known").
    /// The synthesizer reports the range of each word it is about to speak;
    /// a phrase whose reports never got past this offset never began its
    /// final word. Nil when the text has no letters or digits.
    static func finalWordStart(in text: String) -> Int? {
        var wordStart: String.Index?
        var index = text.endIndex
        while index > text.startIndex {
            let previous = text.index(before: index)
            let character = text[previous]
            if character.isLetter || character.isNumber {
                wordStart = previous
            } else if wordStart != nil {
                break
            }
            index = previous
        }
        return wordStart.map { $0.utf16Offset(in: text) }
    }
}
