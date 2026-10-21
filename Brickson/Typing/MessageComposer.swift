import Foundation

/// The message a person is typing, and every rule for changing it.
///
/// It does not care which keyboard feeds it. Apple's keyboard reaches it
/// through a text field's new contents (`Edit.propose`); a later row of
/// word buttons or a Brickson keyboard would use `insert`, `complete` and
/// `deleteBackward`. Each rule lives here once, so it holds whichever
/// keyboard is in use (docs/DECISIONS.md, "The typed message"):
///
/// - **Return speaks** (docs/DECISIONS.md, "Return speaks"). A typed line
///   break is never stored: it becomes a request to speak the whole draft.
///   A line break inside pasted text becomes a space.
/// - **Speaking leaves the draft alone** unless `afterSpeaking` is
///   `.clearsDraft`, so it can be said again or added to.
/// - **This type says nothing itself.** It returns the words to speak
///   (`Outcome.textToSpeak`), and the view hands them to `SpeechService`, as
///   a phrase tile does. `SpeechService` has no seam for tests, and the
///   rules need to be tested without sound.
/// - **A length limit** (`maximumLength`) keeps an accidental paste from
///   speaking for many minutes. An edit that would pass it is refused whole,
///   and the outcome says so: a person's words are never cut short.
/// - **Clearing can be undone once.** The words Clear removed stay in memory
///   (never on disk) until `Edit.restoreCleared` brings them back into an
///   empty draft or the next Clear replaces them.
nonisolated struct MessageComposer: Equatable, Sendable {
    /// What happens to the draft once Speak or Return has spoken it.
    enum AfterSpeaking: Equatable, Sendable {
        /// The draft stays, to be said again or added to. The default.
        case keepsDraft
        /// The draft empties, and the words can be restored once. Not
        /// offered to anyone yet (docs/DECISIONS.md, "The typed message").
        case clearsDraft
    }

    /// One change to the draft. Every way of changing it is one of these,
    /// applied by `apply(_:)`.
    enum Edit: Equatable, Sendable {
        /// A text field's whole new contents, after the person typed,
        /// deleted, pasted, dictated or accepted a correction. Return
        /// arrives this way, as a line break.
        case propose(String)
        /// Text added at the end, from a key or a word button.
        case insert(String)
        /// A suggested word in place of the word being typed at the end,
        /// followed by a space.
        case complete(String)
        /// The last character removed.
        case deleteBackward
        /// Speak was chosen.
        case speak
        /// Clear was chosen.
        case clear
        /// The words Clear last removed, put back into an empty draft.
        case restoreCleared
    }

    /// What an edit did. The caller saves the draft when it changed, resets
    /// the field when asked, and passes `textToSpeak` to the speech engine.
    struct Outcome: Equatable, Sendable {
        /// The draft changed, so it must be saved.
        var draftChanged = false
        /// A text field showing the draft does not show `text` yet: a line
        /// break was taken out, an edit was refused, or the draft changed
        /// some other way. The field must be given `text` again.
        var fieldNeedsUpdate = false
        /// An edit was refused because the draft would pass `maximumLength`.
        var reachedLimit = false
        /// The words to hand to the speech engine, when Speak or Return
        /// asked for them and there was something to say.
        var textToSpeak: String?
        /// The words this edit cleared away (Clear, or speaking with
        /// `.clearsDraft`).
        var clearedText: String?

        /// Nothing happened.
        static let unchanged = Outcome()
    }

    /// The longest draft, in characters as people count them (an emoji or a
    /// letter with its accent is one). About two to three minutes of speech
    /// at the default rate.
    static let maximumLength = 2_000

    /// The draft. It never contains a line break.
    private(set) var text: String
    /// The words Clear last removed, kept in memory only.
    private(set) var recentlyCleared: String?
    var afterSpeaking: AfterSpeaking

    /// A draft restored from storage. Restoring never speaks. Line breaks
    /// (only an older or damaged file could hold one) become spaces, and a
    /// draft longer than `maximumLength` is kept whole: nothing may delete a
    /// person's own words (invariant 7).
    init(restoring saved: String = "", afterSpeaking: AfterSpeaking = .keepsDraft) {
        text = Self.replacingLineBreaks(in: saved)
        self.afterSpeaking = afterSpeaking
    }

    /// The words Speak would say: the draft without the spaces around it, or
    /// nil when there is nothing to say.
    var spokenText: String? {
        let words = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return words.isEmpty ? nil : words
    }

    var canSpeak: Bool { spokenText != nil }
    var canClear: Bool { !text.isEmpty }
    var canRestore: Bool { text.isEmpty && recentlyCleared != nil }

    /// The word being typed at the end of the draft, which a word
    /// suggestion would replace. Empty when the draft ends in a space or a
    /// mark that is not part of a word.
    var partialWord: Substring { text[partialWordStart...] }

    /// Applies one edit and reports what it did.
    mutating func apply(_ edit: Edit) -> Outcome {
        let before = text
        var outcome: Outcome
        switch edit {
        case .propose(let proposed):
            outcome = propose(proposed)
        case .insert(let fragment):
            outcome = propose(text + fragment)
        case .complete(let word):
            outcome = complete(with: word)
        case .deleteBackward:
            outcome = Outcome()
            if !text.isEmpty { text.removeLast() }
        case .speak:
            outcome = speakDraft(Outcome())
        case .clear:
            outcome = Outcome()
            clearDraft(into: &outcome)
        case .restoreCleared:
            outcome = Outcome()
            if canRestore, let restored = recentlyCleared {
                text = restored
                recentlyCleared = nil
            }
        }
        outcome.draftChanged = text != before
        if case .propose(let proposed) = edit {
            outcome.fieldNeedsUpdate = text != proposed
        } else {
            outcome.fieldNeedsUpdate = outcome.draftChanged
        }
        return outcome
    }

    // MARK: - Edits

    /// Works out what one edit to a text field did, by comparing the draft
    /// with the field's new contents: the characters both share at the start
    /// and at the end, and the run between them that the edit put in.
    private mutating func propose(_ proposed: String) -> Outcome {
        guard proposed != text else { return Outcome() }
        let current = Array(text)
        let next = Array(proposed)
        let sharedStart = zip(current, next).prefix { $0 == $1 }.count
        var sharedEnd = 0
        while sharedEnd < min(current.count, next.count) - sharedStart,
              current[current.count - 1 - sharedEnd] == next[next.count - 1 - sharedEnd] {
            sharedEnd += 1
        }
        let start = String(current[..<sharedStart])
        let end = String(current[(current.count - sharedEnd)...])
        let inserted = next[sharedStart..<(next.count - sharedEnd)]

        // The draft never holds a line break, so any line break in the field
        // came in with this edit.
        guard inserted.contains(where: \.isNewline) else {
            return replaceDraft(with: proposed)
        }
        guard inserted.last?.isNewline == true else {
            // A paste with line breaks inside it: they become spaces.
            return replaceDraft(with: start + Self.replacingLineBreaks(in: String(inserted)) + end)
        }

        // Return. A correction or dictated words can arrive in the same
        // edit, so whatever came before the line break is kept. Return on
        // its own never changes the draft, even over a selection.
        var typed = inserted
        while typed.last?.isNewline == true { typed.removeLast() }
        var outcome = Outcome()
        if !typed.isEmpty {
            outcome = replaceDraft(with: start + Self.replacingLineBreaks(in: String(typed)) + end)
        }
        return speakDraft(outcome)
    }

    /// Puts `word` in place of the partial word at the end, then a space, so
    /// the next word can follow. With no partial word, the word is added,
    /// after a space if the draft doesn't already end with one.
    private mutating func complete(with word: String) -> Outcome {
        let completion = Self.replacingLineBreaks(in: word).trimmingCharacters(in: .whitespaces)
        guard !completion.isEmpty else { return Outcome() }
        let start = partialWordStart
        var kept = String(text[..<start])
        if start == text.endIndex, let last = kept.last, !last.isWhitespace {
            kept += " "
        }
        return replaceDraft(with: kept + completion + " ")
    }

    /// Speaks the draft, if there is anything to say, and clears it when
    /// `afterSpeaking` says so.
    private mutating func speakDraft(_ outcome: Outcome) -> Outcome {
        var outcome = outcome
        guard let words = spokenText else { return outcome }
        outcome.textToSpeak = words
        if afterSpeaking == .clearsDraft {
            clearDraft(into: &outcome)
        }
        return outcome
    }

    private mutating func clearDraft(into outcome: inout Outcome) {
        guard !text.isEmpty else { return }
        outcome.clearedText = text
        recentlyCleared = text
        text = ""
    }

    /// Takes `candidate` as the new draft unless it would pass the length
    /// limit. A draft already past the limit (restored from an older
    /// version) can still get shorter.
    private mutating func replaceDraft(with candidate: String) -> Outcome {
        var outcome = Outcome()
        let length = candidate.count
        if length > Self.maximumLength, length > text.count {
            outcome.reachedLimit = true
        } else {
            text = candidate
        }
        return outcome
    }

    // MARK: - Characters

    private var partialWordStart: String.Index {
        var start = text.endIndex
        while start > text.startIndex {
            let previous = text.index(before: start)
            guard Self.isPartOfWord(text[previous]) else { break }
            start = previous
        }
        return start
    }

    /// Letters, digits and apostrophes, so "don't" is one word.
    private static func isPartOfWord(_ character: Character) -> Bool {
        character.isLetter || character.isNumber || character == "'" || character == "\u{2019}"
    }

    /// Every kind of line break (`\n`, `\r`, `\r\n`, and the Unicode line
    /// and paragraph separators) becomes a space.
    private static func replacingLineBreaks(in text: String) -> String {
        String(text.map { $0.isNewline ? " " : $0 })
    }
}
