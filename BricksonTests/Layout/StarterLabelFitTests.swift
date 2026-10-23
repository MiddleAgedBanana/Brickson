import SwiftUI
import Testing
@testable import Brickson

/// Every starter label fits its slot at the default text size in the
/// narrowest window Home plans for, measured with the real fonts, so no word
/// breaks and no tile needs to scroll (AGENTS.md, "Words never break").
///
/// These pin `HomeShape`'s sizes to what SwiftUI actually draws. If Apple's
/// fonts change, these fail first, before a person sees a broken word. They
/// also check the measurements `WordFit` and `FittedLabel` rely on: UIKit's
/// width for a word, rounded up, is never more than half a point narrower
/// than SwiftUI's, and `LabelFont.textHeight` is never less than SwiftUI's
/// height.
///
/// Widths are content widths: the window less Home's 16pt margins. 288 is
/// the narrowest window this checks, a 320pt window (an iPad app in Slide
/// Over); 560 is the narrowest regular window. The safety row, the category
/// buttons and Settings are checked at the narrowest widths `HomeShape`
/// gives them, which `HomeShapeTests` checks at every width.
struct StarterLabelFitTests {
    private static let narrowestWidth = HomeShape.narrowestContentWidth
    private static let inset = HomeShape.labelInset

    private let library: LibrarySnapshot

    init() throws {
        library = try StarterLibrary.bundled()
    }

    private var everydayCategoryNames: [String] {
        library.categories.filter { !$0.isEmergency }.map(\.name)
    }

    private var phrases: [String] {
        library.categories.flatMap(\.phrases).map(\.text)
    }

    /// What SwiftUI draws: `text` in `font` at the default size, laid out in
    /// `width` (or on one line when `width` is nil).
    private static func drawnSize(
        _ text: String, _ font: LabelFont, width: CGFloat? = nil, boldText: Bool = false
    ) -> CGSize {
        let view = Text(verbatim: text)
            .font(font.font)
            .dynamicTypeSize(.large)
            .environment(\.legibilityWeight, boldText ? .bold : .regular)
        return UIHostingController(rootView: view).sizeThatFits(
            in: CGSize(width: width ?? 10_000, height: 10_000)
        )
    }

    /// Checks that `text` fits a label `size` at the default text size: its
    /// widest word, with `WordFit`'s slack, fits the width both by UIKit's
    /// measure and by SwiftUI's, and its lines fit the height. With
    /// `boldText`, UIKit measures at the weight `FittedLabel` measures Bold
    /// Text at, and SwiftUI draws with Bold Text on.
    private static func expectFits(
        _ text: String, _ font: LabelFont, in size: CGSize, _ slot: String, boldText: Bool = false
    ) {
        let measuring = font.legible(boldText ? .bold : .regular)
        let slot = boldText ? "\(slot), Bold Text" : slot
        let measured = measuring.widestWord(text, at: .large)
        #expect(
            measured + WordFit.widthSlack <= size.width,
            "\(slot): \"\(text)\" needs \(measured) + \(WordFit.widthSlack), has \(size.width)"
        )
        for word in WordFit.words(in: text) {
            let drawn = drawnSize(String(word), font, boldText: boldText).width
            #expect(drawn <= size.width, "\(slot): \"\(word)\" draws \(drawn) wide, has \(size.width)")
            #expect(
                drawn <= measuring.widestWord(String(word), at: .large) + 0.5,
                "\(slot): SwiftUI draws \"\(word)\" at \(drawn), more than half a point over UIKit's measure"
            )
        }
        let height = drawnSize(text, font, width: size.width, boldText: boldText).height
        #expect(height <= size.height, "\(slot): \"\(text)\" draws \(height) tall, has \(size.height)")
    }

    private static func labelSize(_ control: CGSize, sideInset: CGFloat = inset.horizontal) -> CGSize {
        CGSize(width: control.width - 2 * sideInset, height: control.height - 2 * inset.vertical)
    }

    /// Fails if `HomeShape.minimumTileWidth` or `minimumTileHeight` is too
    /// small for a starter phrase on a narrow window: a word would break, or
    /// the phrase would be cut off or force the grid to scroll.
    @Test func everyStarterPhraseFitsTheNarrowestThreeColumnTile() {
        let shape = HomeShape(contentWidth: 3 * HomeShape.minimumTileWidth + 2 * HomeShape.controlSpacing)
        #expect(shape.gridColumns == 3 && shape.isCompact)
        let tile = Self.labelSize(CGSize(width: HomeShape.minimumTileWidth, height: shape.minimumTileHeight))
        for phrase in phrases {
            Self.expectFits(phrase, .compactTile, in: tile, "narrowest three-column tile")
        }
    }

    /// Fails if the narrowest window's two-column tiles cannot hold a starter
    /// phrase.
    @Test func everyStarterPhraseFitsTheNarrowestTwoColumnTile() {
        let shape = HomeShape(contentWidth: Self.narrowestWidth)
        #expect(shape.gridColumns == 2)
        let width = (Self.narrowestWidth - HomeShape.controlSpacing) / 2
        let tile = Self.labelSize(CGSize(width: width, height: shape.minimumTileHeight))
        for phrase in phrases {
            Self.expectFits(phrase, .compactTile, in: tile, "narrowest two-column tile")
        }
    }

    /// Fails if the narrowest regular window's tiles cannot hold a starter
    /// phrase in the larger tile font.
    @Test func everyStarterPhraseFitsTheNarrowestRegularTile() {
        let shape = HomeShape(contentWidth: HomeShape.regularMinimumWidth)
        #expect(!shape.isCompact && shape.gridColumns == 3)
        let width = (HomeShape.regularMinimumWidth - 2 * HomeShape.controlSpacing) / 3
        let tile = Self.labelSize(CGSize(width: width, height: shape.minimumTileHeight))
        for phrase in phrases {
            Self.expectFits(phrase, .regularTile, in: tile, "narrowest regular tile")
        }
    }

    /// Fails if a starter category's name would break in the narrowest
    /// category button Home makes (`HomeShape.MinimumWidths`), with Bold
    /// Text off or on. `HomeShapeTests` checks no button is narrower.
    @Test(arguments: [false, true])
    func everyStarterCategoryNameFitsTheNarrowestButton(boldText: Bool) {
        let minimum = HomeShape.MinimumWidths.forBoldText(boldText)
        let narrow = HomeShape(contentWidth: Self.narrowestWidth)
        let button = Self.labelSize(CGSize(width: minimum.category, height: narrow.categoryHeight))
        #expect(everydayCategoryNames.count == HomeShape.categoryCapacity)
        for name in everydayCategoryNames {
            Self.expectFits(name, .category, in: button, "narrowest category button", boldText: boldText)
        }
    }

    /// Fails if Yes, No, Again, Emergency, Get Attention, Stop or Settings
    /// would break or be cut off in the narrowest width Home gives it
    /// (`HomeShape.MinimumWidths`), with Bold Text off or on. Get Attention
    /// takes two lines there, which the quick control's height holds.
    /// `HomeShapeTests` checks no control is narrower.
    @Test(arguments: [false, true])
    func theFixedControlsFitTheirNarrowestWidths(boldText: Bool) {
        let minimum = HomeShape.MinimumWidths.forBoldText(boldText)
        let narrow = HomeShape(contentWidth: Self.narrowestWidth)
        let usual = Self.inset.horizontal
        let quick: [(ControlNames, CGFloat, CGFloat)] = [
            (HomeControlNames.yes, minimum.yesNo, usual),
            (HomeControlNames.no, minimum.yesNo, usual),
            (HomeControlNames.again, minimum.again, usual),
            (HomeControlNames.emergency, minimum.emergency, HomeShape.emergencyLabelInset),
            (HomeControlNames.getAttention, minimum.getAttention, usual),
        ]
        for (names, width, sideInset) in quick {
            Self.expectFits(
                names.visible, .quickControl,
                in: Self.labelSize(CGSize(width: width, height: narrow.quickControlHeight), sideInset: sideInset),
                "quick control", boldText: boldText
            )
        }
        Self.expectFits(
            HomeControlNames.stop.visible, .category,
            in: Self.labelSize(CGSize(width: minimum.stop, height: narrow.categoryHeight)),
            "Stop", boldText: boldText
        )
        Self.expectFits(
            HomeControlNames.settings.visible, .category,
            in: Self.labelSize(CGSize(width: minimum.settings, height: narrow.categoryHeight)),
            "Settings", boldText: boldText
        )
        // Where Settings shows its gear alone, the narrowest button has
        // room for the gear at its default side, which is no smaller than
        // the gear beside the word.
        let room = Self.labelSize(CGSize(width: minimum.settingsSymbol, height: narrow.categoryHeight))
        #expect(
            SettingsButton.symbolSide <= min(room.width, room.height),
            "Settings' gear alone is \(SettingsButton.symbolSide)pt, more than the \(room) it is given"
        )
        let besideTheWord = LabelFont.category.legible(boldText ? .bold : .regular)
            .iconWidth(SettingsButton.symbol, at: .large)
        #expect(
            SettingsButton.symbolSide >= besideTheWord,
            "Settings' gear alone is \(SettingsButton.symbolSide)pt, smaller than beside its word (\(besideTheWord)pt)"
        )
    }

    /// Fails if `LabelFont.lineHeight(at:)` is ever shorter than one line as
    /// SwiftUI draws it: a control sized from it would then cut its label
    /// off or make it step down.
    @Test func oneLineFitsTheLineHeightAtEveryTextSize() {
        for font in [LabelFont.quickControl, .category] {
            for size in DynamicTypeSize.allCases {
                let view = Text(verbatim: "Ag").font(font.font).dynamicTypeSize(size)
                let drawn = UIHostingController(rootView: view)
                    .sizeThatFits(in: CGSize(width: 10_000, height: 10_000)).height
                let planned = font.lineHeight(at: size)
                #expect(drawn <= planned, "\(font.textStyle) at \(size): draws \(drawn), planned \(planned)")
            }
        }
    }

    /// Fails if `LabelFont.textHeight` is ever less than the height SwiftUI
    /// draws a starter label's set lines in (`LabelFont.lines`), at any text
    /// size, with Bold Text off and on, and at widths from the narrowest tile
    /// to a wide one: a set line SwiftUI wrapped again, or more leading than
    /// measured. `FittedLabel` would then choose a size whose words do not
    /// fit. Only widths at which every word fits are checked, the only ones
    /// it chooses.
    @Test(arguments: [false, true])
    func theHeightMeasureCoversWhatSwiftUIDraws(boldText: Bool) {
        let legibility: LegibilityWeight = boldText ? .bold : .regular
        let cases: [(LabelFont, [String], [CGFloat])] = [
            (.compactTile, phrases, [99, 140, 200]),
            (.regularTile, phrases, [168, 240, 320]),
            (.category, everydayCategoryNames, [126, 236]),
        ]
        for (style, texts, widths) in cases {
            let font = style.legible(legibility)
            for size in DynamicTypeSize.allCases where size >= .large {
                for width in widths {
                    for text in texts where font.widestWord(text, at: size) + WordFit.widthSlack <= width {
                        let lines = font.lines(text, width: width, at: size)
                        let view = Text(verbatim: lines.joined(separator: "\n"))
                            .font(font.font)
                            .dynamicTypeSize(size)
                            .environment(\.legibilityWeight, legibility)
                        let drawn = UIHostingController(rootView: view)
                            .sizeThatFits(in: CGSize(width: width, height: 10_000)).height
                        let measured = font.textHeight(text, width: width, at: size)
                        #expect(
                            drawn <= measured,
                            "\(font.textStyle), Bold Text \(boldText ? "on" : "off"), at \(size), \(width) wide: \"\(text)\" draws \(drawn), measured \(measured)"
                        )
                    }
                }
            }
        }
    }

    /// Fails if a word SwiftUI draws with Bold Text on is more than half a
    /// point wider than `LabelFont` measures it under Bold Text: a bold label
    /// would then be given a size or lines its words do not fit. Apple does
    /// not document how much heavier Bold Text draws, so this pins the
    /// weight `LabelFont.boldTextUIFontWeight` measures.
    @Test func boldTextWordsAreNoWiderThanMeasured() {
        let cases: [(LabelFont, [String])] = [
            (.quickControl, ["Yes", "No", "Emergency", "Again", HomeControlNames.getAttention.visible]),
            (.category, everydayCategoryNames + [HomeControlNames.settings.visible, HomeControlNames.stop.visible]),
            (.compactTile, phrases),
            (.regularTile, phrases),
            (.message, phrases),
        ]
        for (style, texts) in cases {
            let font = style.legible(.bold)
            for size in [DynamicTypeSize.large, .xxxLarge, .accessibility5] {
                for word in Set(texts.flatMap { WordFit.words(in: $0).map(String.init) }) {
                    let view = Text(verbatim: word)
                        .font(font.font)
                        .dynamicTypeSize(size)
                        .environment(\.legibilityWeight, .bold)
                    let drawn = UIHostingController(rootView: view)
                        .sizeThatFits(in: CGSize(width: 10_000, height: 10_000)).width
                    let measured = font.widestWord(word, at: size)
                    #expect(
                        drawn <= measured + 0.5,
                        "\(font.textStyle) at \(size) with Bold Text: \"\(word)\" draws \(drawn), measured \(measured)"
                    )
                }
            }
        }
    }

    /// Fails if Bold Text is ignored when measuring: the bold measure must be
    /// wider, and no setting or the regular one must measure as before.
    @Test func boldTextIsMeasuredHeavier() {
        let font = LabelFont.category
        #expect(font.legible(nil) == font)
        #expect(font.legible(.regular) == font)
        #expect(font.legible(.bold).widestWord("Conversation", at: .large) > font.widestWord("Conversation", at: .large))
    }

    /// Fails if the text sizes a label may step through ever include one
    /// below the default, or skip the person's own size.
    @Test func labelsStepFromThePersonsSizeDownToTheDefault() {
        #expect(LabelFont.steps(downFrom: .accessibility5).first == .accessibility5)
        #expect(LabelFont.steps(downFrom: .accessibility5).last == .large)
        #expect(LabelFont.steps(downFrom: .accessibility5).count == 9)
        #expect(LabelFont.steps(downFrom: .large) == [.large])
        #expect(LabelFont.steps(downFrom: .small) == [.small])
        let steps = LabelFont.steps(downFrom: .xxxLarge)
        #expect(steps == [.xxxLarge, .xxLarge, .xLarge, .large])
    }
}
