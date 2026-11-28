import Foundation
import SwiftUI
import Testing
@testable import Brickson

/// While a message is spoken, Home's message marks the word the voice is
/// saying: the words already said in full ink, the word being said with a
/// bar under it, the words still to come dimmed. Only the synthesizer's own
/// word reports move the mark (docs/DECISIONS.md, "The word being spoken is
/// marked"), so these tests pin how a reported place becomes the three
/// groups of words, whatever the voice reports.
struct SpokenWordMarkingTests {
    /// The states of every word, in order, for a message and a report.
    private func states(_ message: String, _ place: Range<Int>?) -> [SpokenWordState] {
        let words = MessageWords(message)
        let marking = words.marking(reported: place)
        return words.places.indices.map { marking.state(ofWord: $0) }
    }

    /// The UTF-16 place of `word` in `message`, as the synthesizer reports
    /// it (`NSRange` counts UTF-16 units).
    private func place(of word: String, in message: String) throws -> Range<Int> {
        let found = try #require((message as NSString).range(of: word).toOptional)
        return found.location..<(found.location + found.length)
    }

    /// A word is a run of characters between spaces or line breaks, the
    /// same split the message's lines are set by (`WordFit.words(in:)`), so a
    /// marked word is always one whole word as drawn. Fails if the two
    /// splits differ.
    @Test func wordsAreSplitTheWayTheMessageIsSetInLines() {
        let message = "  Please  turn\nme over.  "
        let words = MessageWords(message)
        let drawn = WordFit.words(in: message).map(String.init)

        #expect(words.places.map { String((message as NSString).substring(with: NSRange($0))) } == drawn)
        #expect(words.places.count == 4)
    }

    /// Before the voice reports a word, every word is still to come.
    /// Fails if a word is marked before the voice reported it.
    @Test func nothingReportedLeavesEveryWordToCome() {
        #expect(states("I would like some water.", nil) == Array(repeating: .toCome, count: 5))
    }

    @Test func theFirstWord() throws {
        let message = "I would like some water."
        #expect(states(message, try place(of: "I", in: message)) == [.beingSpoken, .toCome, .toCome, .toCome, .toCome])
    }

    @Test func aMiddleWord() throws {
        let message = "I would like some water."
        #expect(states(message, try place(of: "like", in: message)) == [.spoken, .spoken, .beingSpoken, .toCome, .toCome])
    }

    /// The last word's report may leave out the full stop; the word as
    /// drawn, "water.", is still the one marked.
    @Test func theLastWord() throws {
        let message = "I would like some water."
        #expect(states(message, try place(of: "water", in: message)) == [.spoken, .spoken, .spoken, .spoken, .beingSpoken])
    }

    /// A report wholly past the end names no word of this message, so it
    /// marks none. Fails if it marks every word as said, which would show a
    /// message as finished while its voice still speaks.
    @Test func aRangePastTheEndMarksNoWord() {
        let message = "Yes, please."
        let length = (message as NSString).length
        #expect(states(message, length..<(length + 4)) == [.toCome, .toCome])
        #expect(states(message, (length + 3)..<(length + 9)) == [.toCome, .toCome])
    }

    /// A report that starts inside the message and runs past its end marks
    /// the words it does cover.
    @Test func aRangeRunningPastTheEndIsCutAtTheEnd() throws {
        let message = "Yes, please."
        let start = try place(of: "please", in: message).lowerBound
        #expect(states(message, start..<(start + 40)) == [.spoken, .beingSpoken])
    }

    /// An empty report names no word, even one that falls inside a word:
    /// none is marked as being spoken, and the words wholly before it count
    /// as said. Fails if an empty place inside a word marks that word.
    @Test func anEmptyRangeMarksNoWordAsBeingSpoken() throws {
        let message = "I would like some water."
        let start = try place(of: "like", in: message).lowerBound
        #expect(states(message, start..<start) == [.spoken, .spoken, .toCome, .toCome, .toCome])
        #expect(states(message, 0..<0) == Array(repeating: .toCome, count: 5))
        // Inside a word too: an empty place there names none of its letters.
        #expect(states(message, (start + 2)..<(start + 2)) == [.spoken, .spoken, .toCome, .toCome, .toCome])
        #expect(states("Try this", 1..<1) == [.toCome, .toCome])
    }

    /// A person's own punctuation stays part of the word it is drawn
    /// with. A voice that reports "Wait" and then "what" inside "Wait—what?!"
    /// marks that one drawn word both times, and a report covering only a
    /// space marks no word.
    @Test func aPersonsOwnPunctuationStaysWithItsWord() throws {
        let message = "Wait—what?! ¿Qué? ...okay"
        #expect(MessageWords(message).places.count == 3)
        #expect(states(message, try place(of: "Wait", in: message)) == [.beingSpoken, .toCome, .toCome])
        #expect(states(message, try place(of: "what", in: message)) == [.beingSpoken, .toCome, .toCome])
        #expect(states(message, try place(of: "Qué", in: message)) == [.spoken, .beingSpoken, .toCome])
        #expect(states(message, try place(of: "okay", in: message)) == [.spoken, .spoken, .beingSpoken])
        let space = try place(of: " ", in: message)
        #expect(states(message, space) == [.spoken, .toCome, .toCome])
    }

    /// The synthesizer counts in UTF-16 units, as `NSRange` does, so a
    /// word after an emoji or an accented letter is found where it really
    /// is. Fails if places are counted in characters.
    @Test func placesAreCountedInUTF16Units() throws {
        let message = "👍🏽 Café, then home"
        let words = MessageWords(message)
        #expect(words.places.first == 0..<4)
        #expect(states(message, try place(of: "then", in: message)) == [.spoken, .spoken, .beingSpoken, .toCome])
    }

    /// One report that covers two drawn words marks both as being spoken.
    @Test func aReportOverTwoWordsMarksBoth() throws {
        let message = "Go to New York now"
        #expect(states(message, try place(of: "New York", in: message)) == [.spoken, .spoken, .beingSpoken, .beingSpoken, .toCome])
    }

    @Test func anEmptyMessageHasNoWords() {
        #expect(MessageWords("").places.isEmpty)
        #expect(MessageWords("   \n ").places.isEmpty)
        #expect(MessageWords("").marking(reported: 0..<3) == .nothingReported)
    }

    // MARK: - How each word is drawn

    /// The look of each state: words said and the word being said in full
    /// ink, words to come dimmed, and a bar only under the word being said.
    /// Under Increase Contrast the dimmed words are darker against the
    /// screen and the bar is thicker. Fails if any word is drawn fainter
    /// than its state allows or the bar leaves the word being spoken.
    @Test(arguments: [false, true])
    func eachStateHasItsLook(increasedContrast: Bool) {
        let style = SpokenWordStyle(increasedContrast: increasedContrast)
        #expect(style.look(for: .spoken) == SpokenWordLook(opacity: 1, hasBar: false))
        #expect(style.look(for: .beingSpoken) == SpokenWordLook(opacity: 1, hasBar: true))
        #expect(style.look(for: .toCome) == SpokenWordLook(opacity: style.dimOpacity, hasBar: false))
        #expect(style.look(for: nil) == SpokenWordLook(opacity: 1, hasBar: false))
        #expect(style.dimOpacity < 1)
        #expect(style.barHeight == (increasedContrast ? 4 : 3))
        #expect(SpokenWordStyle(increasedContrast: true).dimOpacity > SpokenWordStyle(increasedContrast: false).dimOpacity)
    }

    /// The bar is a shape, drawn in the words' own ink, so the word being
    /// spoken is told apart without colour (Differentiate Without Colour)
    /// and without the difference in brightness. It sits under the word's
    /// line, as wide as the word, a point below the line's descent, and the
    /// renderer asks for that room below its text so it is never clipped.
    @Test(arguments: [false, true])
    func theBarSitsUnderTheWordAsWideAsIt(increasedContrast: Bool) {
        let style = SpokenWordStyle(increasedContrast: increasedContrast)
        let bar = style.bar(underWordAt: CGRect(x: 30, y: 10, width: 64, height: 33), baseline: 37, descent: 6)

        #expect(bar == CGRect(x: 30, y: 37 + 6 + SpokenWordStyle.barGap, width: 64, height: style.barHeight))
        #expect(style.roomBelow == SpokenWordStyle.barGap + style.barHeight)
        #expect(SpokenWordRenderer(marking: nil, style: style).displayPadding.bottom == style.roomBelow)
    }

    /// The mark steps from one word to the next: the renderer has nothing
    /// SwiftUI can animate, so no setting, Reduce Motion included, ever sees
    /// it slide. Fails if the renderer gains animatable data.
    @Test func theMarkStepsAndNeverAnimates() {
        let renderer = SpokenWordRenderer(marking: .nothingReported, style: SpokenWordStyle(increasedContrast: false))
        #expect(type(of: renderer.animatableData) == EmptyAnimatableData.self)
    }

    /// Not speaking, every word is drawn as it always was, with no bar.
    @Test func notSpeakingDrawsEveryWordPlain() {
        let style = SpokenWordStyle(increasedContrast: false)
        let renderer = SpokenWordRenderer(marking: nil, style: style)
        #expect((0..<4).allSatisfy { renderer.look(ofWord: $0) == SpokenWordLook(opacity: 1, hasBar: false) })
        #expect(renderer.look(ofWord: nil) == SpokenWordLook(opacity: 1, hasBar: false))
    }
}

private extension NSRange {
    var toOptional: NSRange? { location == NSNotFound ? nil : self }
}
