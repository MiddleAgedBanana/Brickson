import Foundation
import Testing
@testable import Brickson

/// `WordFit` with stand-in measurements: a list of text sizes, largest first,
/// and every character 0.6 of the point size wide. The real fonts are checked
/// against Home's real slots in `StarterLabelFitTests`.
struct WordFitTests {
    /// Accessibility sizes down to the default, as Apple's 17pt styles step.
    private static let sizes: [CGFloat] = [53, 47, 40, 33, 28, 23, 21, 19, 17]

    private static func choices(
        _ text: String, sizes: [CGFloat] = sizes, width: CGFloat, icon: CGFloat? = nil
    ) -> [WordFit.Choice] {
        WordFit.choices(
            stepCount: sizes.count,
            hasIcon: icon != nil,
            width: width,
            widestWord: { step in
                CGFloat(WordFit.words(in: text).map(\.count).max() ?? 0) * 0.6 * sizes[step]
            },
            iconAdvance: { _ in icon ?? 0 }
        )
    }

    private static func choice(_ step: Int, icon: Bool = false) -> WordFit.Choice {
        WordFit.Choice(step: step, showsIcon: icon)
    }

    /// Fails if a label that fits at the person's size is not offered at
    /// that size with its icon first.
    @Test func aLabelThatFitsIsOfferedFirstAtItsSizeWithItsIcon() {
        // "Yes" at 17pt is 30.6pt wide; with a 25pt icon it needs 55.6 plus slack.
        let result = Self.choices("Yes", sizes: [17], width: 80, icon: 25)
        #expect(result == [Self.choice(0, icon: true), Self.choice(0)])
    }

    /// Fails if a label shrinks before it has dropped its icon (AGENTS.md,
    /// "drop a decorative icon before shrinking words"), or if a smaller size
    /// is offered with the icon.
    @Test func theIconGoesBeforeTheWordsShrink() {
        // "Emergency" (9 characters) at 19pt is 102.6pt wide: it fits alone
        // in 110, not beside a 25pt icon.
        let result = Self.choices("Emergency", sizes: [19, 17], width: 110, icon: 25)
        #expect(result == [Self.choice(0), Self.choice(1)])
    }

    /// Fails if a size at which the widest word is wider than the slot is
    /// offered: drawn there, the word would break.
    @Test func sizesAtWhichAWordWouldBreakAreLeftOut() {
        // "understand." (11 characters) is 6.6pt per point of size. In a 160pt
        // label, less 2 of slack, sizes up to 23pt fit (151.8) and 28pt does
        // not (184.8).
        let result = Self.choices("I understand.", width: 160)
        #expect(result.first == Self.choice(5))
        #expect(result == (5..<Self.sizes.count).map { Self.choice($0) })
    }

    /// Fails if the default size is not always offered last, or if anything
    /// below it is ever offered (AGENTS.md, "never render below their
    /// default size").
    @Test func theDefaultSizeIsAlwaysTheLastChoiceEvenWhenItDoesNotFit() {
        // "Conversation" at 17pt is 122.4pt wide: wider than a 100pt slot.
        let result = Self.choices("Conversation", width: 100, icon: 25)
        #expect(result == [Self.choice(Self.sizes.count - 1)])
    }

    /// Fails if a person who chose a text size below the default is shrunk
    /// further: their own size is the only one.
    @Test func aSmallerChosenSizeIsNeverShrunkFurther() {
        let result = Self.choices("Conversation", sizes: [14], width: 50)
        #expect(result == [Self.choice(0)])
    }

    /// Fails if the slack beside the widest word is dropped: a word exactly
    /// as wide as the slot is not counted as fitting.
    @Test func aWordAsWideAsTheSlotDoesNotFit() {
        // "No" at 17pt is 20.4pt wide.
        #expect(Self.choices("No", sizes: [17, 17], width: 20.4) == [Self.choice(1)])
        #expect(Self.choices("No", sizes: [17, 17], width: 22.4) == [Self.choice(0), Self.choice(1)])
    }

    /// Fails if a slot with no width yet (the first layout pass) is treated
    /// as fitting anything.
    @Test func aZeroWidthSlotOffersOnlyTheDefaultSize() {
        #expect(Self.choices("Hi", width: 0, icon: 10) == [Self.choice(Self.sizes.count - 1)])
    }

    @Test func noSizesMeansNoChoices() {
        #expect(Self.choices("Hi", sizes: [], width: 100).isEmpty)
    }

    /// Fails if a label could break anywhere but between words.
    /// Fails if a label is drawn at a choice whose height does not fit when
    /// a later one does, or if the smallest choice is not drawn when none
    /// fits (nothing smaller is allowed).
    @Test func theFirstChoiceWhoseHeightFitsIsDrawn() {
        let choices = [Self.choice(0, icon: true), Self.choice(0), Self.choice(1), Self.choice(2)]
        #expect(WordFit.first(of: choices, whereHeightFits: { $0.step >= 1 }) == Self.choice(1))
        #expect(WordFit.first(of: choices, whereHeightFits: { _ in true }) == Self.choice(0, icon: true))
        #expect(WordFit.first(of: choices, whereHeightFits: { _ in false }) == Self.choice(2))
        #expect(WordFit.first(of: [], whereHeightFits: { _ in true }) == Self.choice(0))
    }

    @Test func wordsSplitOnWhitespaceOnly() {
        #expect(WordFit.words(in: "I don't know.") == ["I", "don't", "know."])
        #expect(WordFit.words(in: "  Thank\tyou.\n") == ["Thank", "you."])
        #expect(WordFit.words(in: "").isEmpty)
    }
}
