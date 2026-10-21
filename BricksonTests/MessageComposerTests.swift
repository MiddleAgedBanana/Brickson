import Testing
@testable import Brickson

/// The rules for the message being typed (`MessageComposer`). Each test's
/// comment names the change to the composer that would make it fail.
struct MessageComposerTests {
    /// A composer holding `text`, as if it had been typed.
    private func composer(
        _ text: String = "",
        afterSpeaking: MessageComposer.AfterSpeaking = .keepsDraft
    ) -> MessageComposer {
        MessageComposer(restoring: text, afterSpeaking: afterSpeaking)
    }

    // MARK: Typing

    /// Fails if a field's new contents are not taken as the draft.
    @Test func typingInTheFieldBecomesTheDraft() {
        var message = composer()
        var outcomes: [MessageComposer.Outcome] = []
        for typed in ["H", "He", "Hel", "Help"] {
            outcomes.append(message.apply(.propose(typed)))
        }

        #expect(message.text == "Help")
        #expect(outcomes.allSatisfy { $0.draftChanged && !$0.fieldNeedsUpdate && $0.textToSpeak == nil })
    }

    /// Fails if an edit that changes nothing reports a change, which would
    /// save the draft for no reason.
    @Test func proposingTheSameTextChangesNothing() {
        var message = composer("Water, please.")

        #expect(message.apply(.propose("Water, please.")) == .unchanged)
    }

    /// Fails if deleting, replacing a selection or editing the middle of the
    /// draft is handled differently from typing at the end.
    @Test func editsAnywhereInTheDraftAreKept() {
        var message = composer("I want water.")

        _ = message.apply(.propose("I want cold water."))
        #expect(message.text == "I want cold water.")
        _ = message.apply(.propose("I want cold tea."))
        #expect(message.text == "I want cold tea.")
        _ = message.apply(.propose("I want tea."))
        #expect(message.text == "I want tea.")
        let emptied = message.apply(.propose(""))
        #expect(message.text == "")
        #expect(emptied.draftChanged)
        #expect(emptied.clearedText == nil, "deleting in the field is not Clear")
    }

    /// Fails if typing ever speaks without Return or Speak (invariant 3's
    /// spirit: nothing is said that the person didn't ask to say).
    @Test func typingNeverSpeaks() {
        var message = composer()
        for typed in ["Hello", "Hello.", "Hello. ", "Hello. How", "Hello. How are you?"] {
            #expect(message.apply(.propose(typed)).textToSpeak == nil)
        }
    }

    // MARK: Return speaks

    /// Fails if Return inserts a line break instead of speaking, the
    /// reference app's bug (docs/LESSONS.md, "The return key must speak").
    @Test func returnAtTheEndSpeaksTheDraftAndStoresNoLineBreak() {
        var message = composer("I'm cold.")

        let outcome = message.apply(.propose("I'm cold.\n"))

        #expect(outcome.textToSpeak == "I'm cold.")
        #expect(message.text == "I'm cold.")
        #expect(!outcome.draftChanged)
        #expect(outcome.fieldNeedsUpdate, "the field still shows the line break and must be reset")
    }

    /// Fails if Return with the cursor in the middle speaks only part of the
    /// draft, or keeps the line break.
    @Test func returnInTheMiddleSpeaksTheWholeDraft() {
        var message = composer("Please call my sister.")

        let outcome = message.apply(.propose("Please call\n my sister."))

        #expect(outcome.textToSpeak == "Please call my sister.")
        #expect(message.text == "Please call my sister.")
    }

    /// Fails if any kind of line break is missed: each is a Return from some
    /// keyboard, dictation or a paste.
    @Test(arguments: ["\n", "\r", "\r\n", "\u{2028}", "\u{2029}", "\u{0085}", "\u{000B}", "\u{000C}"])
    func everyKindOfLineBreakSpeaks(lineBreak: String) {
        var message = composer("Yes")

        let outcome = message.apply(.propose("Yes" + lineBreak))

        #expect(outcome.textToSpeak == "Yes")
        #expect(message.text == "Yes")
    }

    /// Fails if Return pressed twice before the field reports it speaks
    /// twice or stores a line break.
    @Test func severalLineBreaksAtOnceSpeakOnce() {
        var message = composer("No")

        let outcome = message.apply(.propose("No\n\n"))

        #expect(outcome.textToSpeak == "No")
        #expect(message.text == "No")
    }

    /// Fails if Return on an empty or blank draft asks the speech engine to
    /// say nothing, or keeps the line break.
    @Test(arguments: ["", " ", "   "])
    func returnWithNothingToSaySpeaksNothing(draft: String) {
        var message = composer(draft)

        let outcome = message.apply(.propose(draft + "\n"))

        #expect(outcome.textToSpeak == nil)
        #expect(message.text == draft)
        #expect(outcome.fieldNeedsUpdate)
    }

    /// Fails if Return typed over selected words deletes them: Return only
    /// speaks, so it never changes the person's words.
    @Test func returnOverASelectionKeepsTheSelectedWords() {
        var message = composer("Turn me over now.")

        // "now" was selected and Return typed over it.
        let outcome = message.apply(.propose("Turn me over \n."))

        #expect(message.text == "Turn me over now.")
        #expect(outcome.textToSpeak == "Turn me over now.")
        #expect(!outcome.draftChanged)
    }

    /// Fails if a correction that arrives with Return (autocorrect, or a
    /// dictated phrase committed by it) is lost, or the uncorrected words
    /// are spoken.
    @Test func returnKeepsACorrectionThatArrivesWithIt() {
        var message = composer("I want teh")

        let outcome = message.apply(.propose("I want the\n"))

        #expect(message.text == "I want the")
        #expect(outcome.textToSpeak == "I want the")
        #expect(outcome.draftChanged)
    }

    /// Fails if line breaks inside pasted text are stored, or the paste
    /// speaks.
    @Test func lineBreaksInsideAPasteBecomeSpaces() {
        var message = composer("Note: ")

        let outcome = message.apply(.propose("Note: first line\nsecond line"))

        #expect(message.text == "Note: first line second line")
        #expect(outcome.textToSpeak == nil)
        #expect(outcome.fieldNeedsUpdate)
    }

    /// Fails if a paste ending in a line break is not treated as Return. It
    /// cannot be told apart from text typed and then Return, so it speaks;
    /// a Return that fails to speak is the worse mistake.
    @Test func aPasteEndingInALineBreakSpeaks() {
        var message = composer()

        let outcome = message.apply(.propose("first\nsecond\n"))

        #expect(message.text == "first second")
        #expect(outcome.textToSpeak == "first second")
    }

    // MARK: Speak

    /// Fails if Speak changes the draft (docs/DECISIONS.md, "The typed
    /// message": the draft stays, to be said again or added to).
    @Test func speakSaysTheDraftAndKeepsIt() {
        var message = composer("Thank you.")

        let outcome = message.apply(.speak)

        #expect(outcome.textToSpeak == "Thank you.")
        #expect(message.text == "Thank you.")
        #expect(!outcome.draftChanged)
        #expect(!outcome.fieldNeedsUpdate)
        #expect(outcome.clearedText == nil)
    }

    /// Fails if the spaces around the draft are spoken or block speaking.
    @Test func speakTrimsTheSpacesAroundTheWords() {
        var message = composer("  Hello there.  ")

        #expect(message.apply(.speak).textToSpeak == "Hello there.")
        #expect(message.text == "  Hello there.  ", "trimming is for speech only")
        #expect(message.spokenText == "Hello there.")
    }

    /// Fails if Speak asks the engine to say an empty or blank draft.
    @Test(arguments: ["", " ", "\t "])
    func speakWithNothingToSaySpeaksNothing(draft: String) {
        var message = composer(draft)

        #expect(!message.canSpeak)
        #expect(message.apply(.speak) == .unchanged)
    }

    /// Fails if speaking twice in a row needs anything between: a second
    /// Speak says the same words again (the speech engine absorbs a repeat
    /// that is still playing).
    @Test func speakingAgainSaysTheSameWords() {
        var message = composer("Come here.")

        #expect(message.apply(.speak).textToSpeak == "Come here.")
        #expect(message.apply(.speak).textToSpeak == "Come here.")
    }

    /// Fails if clear-after-speaking loses the words, or keeps them in the
    /// draft.
    @Test func speakingCanClearTheDraftAndTheWordsCanComeBack() {
        var message = composer("See you tomorrow.", afterSpeaking: .clearsDraft)

        let outcome = message.apply(.speak)

        #expect(outcome.textToSpeak == "See you tomorrow.")
        #expect(outcome.clearedText == "See you tomorrow.")
        #expect(outcome.draftChanged)
        #expect(message.text == "")
        #expect(message.canRestore)
        _ = message.apply(.restoreCleared)
        #expect(message.text == "See you tomorrow.")
    }

    /// Fails if Return ignores `afterSpeaking`.
    @Test func returnClearsTheDraftWhenSpeakingClears() {
        var message = composer("Good night.", afterSpeaking: .clearsDraft)

        let outcome = message.apply(.propose("Good night.\n"))

        #expect(outcome.textToSpeak == "Good night.")
        #expect(message.text == "")
        #expect(outcome.fieldNeedsUpdate)
    }

    /// Fails if clear-after-speaking empties a blank draft that said
    /// nothing.
    @Test func aBlankDraftIsNotClearedBySpeaking() {
        var message = composer("   ", afterSpeaking: .clearsDraft)

        #expect(message.apply(.speak) == .unchanged)
        #expect(message.text == "   ")
    }

    // MARK: Clear and restore

    /// Fails if Clear doesn't empty the draft, or doesn't hand back what it
    /// removed.
    @Test func clearEmptiesTheDraftAndReturnsTheWords() {
        var message = composer("I need the nurse.")

        let outcome = message.apply(.clear)

        #expect(message.text == "")
        #expect(outcome.clearedText == "I need the nurse.")
        #expect(outcome.draftChanged)
        #expect(outcome.textToSpeak == nil, "Clear never speaks")
    }

    /// Fails if Clear on an empty draft reports a change: a repeated
    /// activation must do nothing.
    @Test func clearingAnEmptyDraftDoesNothing() {
        var message = composer()

        #expect(!message.canClear)
        #expect(message.apply(.clear) == .unchanged)
    }

    /// Fails if a repeated Clear forgets the words the first one removed:
    /// the second finds an empty draft and must leave them restorable.
    @Test func aRepeatedClearKeepsTheWordsRestorable() {
        var message = composer("Long message typed slowly.")

        _ = message.apply(.clear)
        _ = message.apply(.clear)

        #expect(message.canRestore)
        _ = message.apply(.restoreCleared)
        #expect(message.text == "Long message typed slowly.")
    }

    /// Fails if Restore works only once in a way that toggles: a second
    /// activation must do nothing, never clear again.
    @Test func restoreBringsTheWordsBackOnce() {
        var message = composer("Please wait.")
        _ = message.apply(.clear)

        let restored = message.apply(.restoreCleared)
        let again = message.apply(.restoreCleared)

        #expect(restored.draftChanged)
        #expect(message.text == "Please wait.")
        #expect(again == .unchanged)
        #expect(!message.canRestore)
    }

    /// Fails if Restore replaces words typed after Clear.
    @Test func restoreNeverReplacesNewWords() {
        var message = composer("Old words.")
        _ = message.apply(.clear)
        _ = message.apply(.propose("New"))

        #expect(!message.canRestore)
        #expect(message.apply(.restoreCleared) == .unchanged)
        #expect(message.text == "New")
    }

    /// Fails if the newest Clear does not win: only the last cleared words
    /// are kept.
    @Test func onlyTheLastClearedWordsAreKept() {
        var message = composer("First.")
        _ = message.apply(.clear)
        _ = message.apply(.propose("Second."))
        _ = message.apply(.clear)

        _ = message.apply(.restoreCleared)

        #expect(message.text == "Second.")
    }

    /// Fails if a new composer (a relaunch) has anything to restore: cleared
    /// words are kept in memory only.
    @Test func nothingIsRestorableAfterARelaunch() {
        #expect(!composer("Saved draft.").canRestore)
        #expect(!composer().canRestore)
    }

    // MARK: Keys and word buttons

    /// Fails if inserted text is not added at the end.
    @Test func insertAddsTextAtTheEnd() {
        var message = composer("I")

        _ = message.apply(.insert(" want"))
        let outcome = message.apply(.insert(" water"))

        #expect(message.text == "I want water")
        #expect(outcome.draftChanged)
        #expect(outcome.fieldNeedsUpdate, "a field showing the draft must be given the new text")
    }

    /// Fails if a Return key on a Brickson keyboard (an inserted line break)
    /// doesn't speak.
    @Test func insertingALineBreakSpeaks() {
        var message = composer("Yes, please")

        let outcome = message.apply(.insert("\n"))

        #expect(outcome.textToSpeak == "Yes, please")
        #expect(message.text == "Yes, please")
    }

    /// Fails if inserting nothing reports a change.
    @Test func insertingNothingChangesNothing() {
        var message = composer("Hi")

        #expect(message.apply(.insert("")) == .unchanged)
    }

    /// Fails if delete removes more or less than one character as people
    /// count them: an emoji, a flag or a letter with its accent is one.
    @Test(arguments: [
        ("Thanks 👍", "Thanks "),
        ("Hi 👨‍👩‍👧", "Hi "),
        ("Go 🇺🇸", "Go "),
        ("Cafe\u{301}", "Caf"),
        ("ok", "o"),
    ])
    func deleteRemovesOneCharacter(before: String, after: String) {
        var message = composer(before)

        let outcome = message.apply(.deleteBackward)

        #expect(message.text == after)
        #expect(outcome.draftChanged)
    }

    /// Fails if delete on an empty draft reports a change.
    @Test func deletingFromAnEmptyDraftDoesNothing() {
        var message = composer()

        #expect(message.apply(.deleteBackward) == .unchanged)
    }

    /// Fails if a word suggestion is put in the wrong place, or loses the
    /// words before it.
    @Test(arguments: [
        ("I want wat", "water", "I want water "),
        ("wat", "water", "water "),
        ("", "water", "water "),
        ("I want ", "water", "I want water "),
        ("Hello,", "friend", "Hello, friend "),
        ("I don", "don't", "I don't "),
        ("It\u{2019}s goi", "going", "It\u{2019}s going "),
        ("(wat", "water", "(water "),
        ("Room 1", "12", "Room 12 "),
    ])
    func aSuggestionReplacesThePartialWord(draft: String, word: String, result: String) {
        var message = composer(draft)

        _ = message.apply(.complete(word))

        #expect(message.text == result)
    }

    /// Fails if the partial word a suggestion would replace is worked out
    /// differently from where `complete` puts it.
    @Test(arguments: [
        ("I want wat", "wat"),
        ("I want ", ""),
        ("", ""),
        ("Hello,", ""),
        ("I don't", "don't"),
    ])
    func thePartialWordIsTheWordBeingTyped(draft: String, partial: String) {
        #expect(composer(draft).partialWord == partial)
    }

    /// Fails if an empty suggestion, or one with a line break, changes the
    /// draft or speaks.
    @Test func aSuggestionNeverSpeaksAndIsNeverEmpty() {
        var message = composer("I wa")

        #expect(message.apply(.complete("")) == .unchanged)
        #expect(message.apply(.complete("  ")) == .unchanged)
        let outcome = message.apply(.complete("want\n"))
        #expect(outcome.textToSpeak == nil)
        #expect(message.text == "I want ")
    }

    // MARK: Length

    private static let atLimit = String(repeating: "a", count: MessageComposer.maximumLength)

    /// Fails if a draft exactly at the limit is refused.
    @Test func aDraftCanReachTheLimit() {
        var message = composer(String(Self.atLimit.dropLast()))

        let outcome = message.apply(.propose(Self.atLimit))

        #expect(message.text.count == MessageComposer.maximumLength)
        #expect(!outcome.reachedLimit)
    }

    /// Fails if typing past the limit is accepted, or refused silently.
    @Test func typingPastTheLimitIsRefusedAndSaysSo() {
        var message = composer(Self.atLimit)

        let outcome = message.apply(.propose(Self.atLimit + "b"))

        #expect(message.text == Self.atLimit)
        #expect(outcome.reachedLimit)
        #expect(!outcome.draftChanged)
        #expect(outcome.fieldNeedsUpdate, "the field shows the refused letter and must be reset")
    }

    /// Fails if a long paste is cut to fit instead of refused whole: a
    /// half-pasted message could be spoken as if it were complete.
    @Test func aPasteThatWouldPassTheLimitIsRefusedWhole() {
        var message = composer("Start: ")
        let paste = String(repeating: "word ", count: 500)

        let outcome = message.apply(.propose("Start: " + paste))

        #expect(message.text == "Start: ")
        #expect(outcome.reachedLimit)
    }

    /// Fails if the limit counts UTF-16 units or bytes instead of the
    /// characters people see.
    @Test func theLimitCountsCharactersAsPeopleSeeThem() {
        let emoji = String(repeating: "👍", count: MessageComposer.maximumLength)
        var message = composer(String(emoji.dropLast()))

        let outcome = message.apply(.insert("👍"))

        #expect(!outcome.reachedLimit)
        #expect(message.text.count == MessageComposer.maximumLength)
    }

    /// Fails if inserted text or a suggestion can pass the limit.
    @Test func keysAndSuggestionsRespectTheLimit() {
        // Words and spaces, so a suggestion has no partial word to replace.
        let full = String(repeating: "a ", count: MessageComposer.maximumLength / 2)
        var message = composer(full)

        let inserted = message.apply(.insert("b"))
        let completed = message.apply(.complete("water"))

        #expect(inserted.reachedLimit)
        #expect(completed.reachedLimit)
        #expect(message.text == full)
    }

    /// Fails if Return at the limit doesn't speak, or if a correction that
    /// would pass the limit is applied.
    @Test func returnAtTheLimitStillSpeaks() {
        var message = composer(Self.atLimit)

        let outcome = message.apply(.propose(Self.atLimit + "bb\n"))

        #expect(outcome.textToSpeak == Self.atLimit)
        #expect(outcome.reachedLimit)
        #expect(message.text == Self.atLimit)
    }

    /// Fails if a draft longer than the limit (restored from an older
    /// version) loses words, or can't be shortened (invariant 7: nothing
    /// deletes a person's own words).
    @Test func aRestoredDraftPastTheLimitIsKeptAndCanShrink() {
        let long = Self.atLimit + "extra"
        var message = composer(long)
        #expect(message.text == long)

        _ = message.apply(.deleteBackward)
        #expect(message.text == Self.atLimit + "extr")
        #expect(message.apply(.insert("a")).reachedLimit)
        _ = message.apply(.propose(Self.atLimit + "EXTR"))
        #expect(message.text == Self.atLimit + "EXTR", "a same-length correction is allowed")
    }

    // MARK: Restoring

    /// Fails if a restored draft keeps line breaks, or loses words.
    @Test func restoringTurnsLineBreaksIntoSpaces() {
        let message = composer("first\nsecond\r\nthird")

        #expect(message.text == "first second third")
    }

    // MARK: The draft never holds a line break

    /// Fails if any sequence of edits can store a line break or pass the
    /// limit. Runs every edit after every other, from a few starting drafts.
    @Test func noSequenceOfEditsStoresALineBreakOrPassesTheLimit() {
        let edits: [MessageComposer.Edit] = [
            .propose("a\nb"), .propose("\n"), .propose("x\r\n"), .insert("\u{2028}"),
            .insert("word"), .complete("next\n"), .deleteBackward, .speak, .clear,
            .restoreCleared, .propose(Self.atLimit + "\nz"), .insert(Self.atLimit),
        ]
        for start in ["", "Hello", "Line\nbreak"] {
            for first in edits {
                for second in edits {
                    for afterSpeaking in [MessageComposer.AfterSpeaking.keepsDraft, .clearsDraft] {
                        var message = composer(start, afterSpeaking: afterSpeaking)
                        _ = message.apply(first)
                        _ = message.apply(second)
                        let holdsALineBreak = message.text.contains { $0.isNewline }
                        #expect(!holdsALineBreak, "\(first) then \(second)")
                        #expect(message.text.count <= MessageComposer.maximumLength, "\(first) then \(second)")
                    }
                }
            }
        }
    }
}
