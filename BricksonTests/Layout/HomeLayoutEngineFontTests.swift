import SwiftUI
import Testing
@testable import Brickson

/// The layout engine against the real fonts: the text sizes
/// `HomeLayoutEngineTests` lays out with are the ones `LabelFont` measures,
/// and the widths and heights the engine never goes below hold the words
/// they are for, at the default text size, with Bold Text off and on
/// (AGENTS.md, *Words never break*). `StarterLabelFitTests` checks the
/// categories and the fixed controls at the narrowest widths.
struct HomeLayoutEngineFontTests {
    private let library: LibrarySnapshot

    init() throws {
        library = try StarterLibrary.bundled()
    }

    private var phrases: [String] {
        library.categories.flatMap(\.phrases).map(\.text)
    }

    private static let inset = HomeLayout.labelInset

    /// The Dynamic Type sizes `HomeLayoutEngineTests.textSizes` stands for,
    /// in its order.
    private static let dynamicTypeSizes: [DynamicTypeSize] = [.large, .xxxLarge, .accessibility1, .accessibility3, .accessibility5]

    /// Fails if a text size the pure tests lay out with is not one line of
    /// each label style as `LabelFont` measures it, so their windows,
    /// floors and keyboard checks would describe sizes no person uses.
    @Test(arguments: [false, true])
    func thePureTestsTextSizesAreTheRealOnes(boldText: Bool) {
        #expect(HomeLayoutEngineTests.textSizes.count == Self.dynamicTypeSizes.count)
        for ((name, plain), size) in zip(HomeLayoutEngineTests.textSizes, Self.dynamicTypeSizes) {
            var expected = plain
            expected.boldText = boldText
            #expect(HomeLayout.Text.measured(at: size, boldText: boldText) == expected, "\(name)")
        }
    }

    /// Fails if Phrases, Type or Again's slot (which shows Speak while
    /// typing) is too narrow for its word at the default size: the words
    /// the slot plan gives them (docs/DESIGN.md), in the quick controls'
    /// font, with the label inset.
    @Test(arguments: [false, true])
    func theNewControlsHoldTheirWords(boldText: Bool) {
        let minimum = HomeLayout.MinimumWidths.forBoldText(boldText)
        let words: [(String, CGFloat, CGFloat)] = [
            ("Phrases", minimum.phrases, HomeLayout.selectableSideInset),
            ("Type", minimum.type, HomeLayout.selectableSideInset),
            ("Again", minimum.again, Self.inset.horizontal),
            ("Speak", minimum.again, Self.inset.horizontal),
        ]
        for (word, width, sideInset) in words {
            let label = CGSize(width: width - 2 * sideInset, height: 10_000)
            StarterLabelFitTests.expectFits(word, .quickControl, in: label, "\(word)'s narrowest slot", boldText: boldText)
        }
    }

    /// Fails if camera fitting reports a valid layout but leaves a mode
    /// narrower than its real words at the actual selectable inset. A
    /// reserved input may instead report that it cannot fit; the fixture
    /// must not turn rejection into a requirement to shrink the words.
    @Test(arguments: [false, true])
    func cameraNarrowedModesHoldTheirWords(boldText: Bool) {
        let layout = HomeLayout(
            space: HomeReservedRegionTests.modeWordGapSpace(boldText: boldText),
            text: .measured(at: .large, boldText: boldText), modes: .phrasesAndTyping
        )
        if layout.controlsFit && layout.reservationIssues.isEmpty {
            for (slot, word) in [(HomeLayout.Slot.phrases, "Phrases"), (.type, "Type")] {
                let frame = layout.frame(slot)
                StarterLabelFitTests.expectFits(
                    word, .quickControl,
                    in: CGSize(
                        width: frame.width - 2 * HomeLayout.selectableSideInset,
                        height: frame.height - 2 * Self.inset.vertical
                    ),
                    "camera-narrowed mode", boldText: boldText
                )
            }
        }
    }

    /// Fails if `MinimumWidths.message` is too narrow for a starter phrase's
    /// widest word in the message font at the default size: the message
    /// would break the word.
    @Test(arguments: [false, true])
    func theMessageHoldsEveryStarterWord(boldText: Bool) {
        let width = HomeLayout.MinimumWidths.forBoldText(boldText).message
        for phrase in phrases {
            StarterLabelFitTests.expectFits(phrase, .message, in: CGSize(width: width, height: 10_000), "narrowest message", boldText: boldText)
        }
    }

    /// Fails if the message stops following the person's text size where
    /// its words fit, capped at a smaller size instead (Apple's audit
    /// reported that as "Dynamic Type font sizes are partially unsupported"
    /// on the first-run hint, in the narrower message Phrases and Type leave
    /// on a phone), may shrink below the default size, or sets a line wider
    /// than the message at the default size. Fails too if a word too wide
    /// even at the default size is no longer capped there.
    @Test(arguments: [false, true])
    func theMessageFollowsThePersonsTextSize(boldText: Bool) throws {
        let legibility: LegibilityWeight = boldText ? .bold : .regular
        let font = LabelFont.message.legible(legibility)
        // The message's width on CI's phone, with Phrases and Type beside it.
        let width: CGFloat = 217
        for size in DynamicTypeSize.allCases where size >= .large {
            let fit = font.messageFit(for: FirstRunHint.text, at: size, width: width)
            let lines = try #require(fit.lines, "\(size)")
            #expect(fit.cap == size, "\(size)")
            #expect(fit.smallestScale == font.pointSize(at: .large) / font.pointSize(at: size), "\(size)")
            #expect(lines.joined(separator: " ") == FirstRunHint.text, "\(size)")
            for line in lines {
                #expect(font.lineWidth(line, at: .large) <= width, "\(size): \(line)")
            }
        }
        #expect(font.messageFit(for: FirstRunHint.text, at: .accessibility5, width: width).smallestScale < 1)
        let tooWide = font.messageFit(for: "Supercalifragilisticexpialidocious", at: .accessibility3, width: width)
        #expect(tooWide == MessageFit(lines: nil, smallestScale: 1, cap: .large))
    }

    /// Fails if the message's two reserved lines, or the status line under
    /// them, draw taller than the engine keeps for them (two and one
    /// `LabelFont.lineHeight(at:)`), at any text size, with Bold Text off
    /// and on: they would spill into the gap above the safety row.
    @Test(arguments: [false, true])
    func theMessageAndStatusLinesFitTheirRegion(boldText: Bool) {
        let legibility: LegibilityWeight = boldText ? .bold : .regular
        for size in DynamicTypeSize.allCases where size >= .large {
            let text = HomeLayout.Text.measured(at: size, boldText: boldText)
            let message = Text(verbatim: " ")
                .font(LabelFont.message.legible(legibility).font)
                .lineLimit(2, reservesSpace: true)
                .dynamicTypeSize(size)
                .environment(\.legibilityWeight, legibility)
            let status = Text(verbatim: "Speaking")
                .font(LabelFont.status.legible(legibility).font)
                .dynamicTypeSize(size)
                .environment(\.legibilityWeight, legibility)
            let unbounded = CGSize(width: 10_000, height: 10_000)
            let messageHeight = UIHostingController(rootView: message).sizeThatFits(in: unbounded).height
            let statusHeight = UIHostingController(rootView: status).sizeThatFits(in: unbounded).height
            #expect(messageHeight <= 2 * text.messageLine, "message at \(size): draws \(messageHeight), has \(2 * text.messageLine)")
            #expect(statusHeight <= text.statusLine, "status line at \(size): draws \(statusHeight), has \(text.statusLine)")
        }
    }

    /// Fails if a starter phrase does not fit a tile at any of the floors
    /// the engine keeps (`HomeLayout.TileFloor`): at the narrowest width
    /// each floor applies to, in the lines its height holds, in the compact
    /// and the regular tile font. A wider tile at the same floor holds the
    /// same lines. Fails too if the narrowest tile of either font, the
    /// first floor's width, is too narrow for the widest word.
    @Test(arguments: [false, true])
    func everyStarterPhraseFitsEveryTileFloor(boldText: Bool) {
        #expect(HomeLayout.compactTile.minimumWidth == HomeLayout.TileFloor.compact.first?.width)
        #expect(HomeLayout.compactTile.boldMinimumWidth == HomeLayout.TileFloor.compact.first?.boldWidth)
        #expect(HomeLayout.regularTile.minimumWidth == HomeLayout.TileFloor.regular.first?.width)
        #expect(HomeLayout.regularTile.boldMinimumWidth == HomeLayout.TileFloor.regular.first?.boldWidth)
        let fonts: [(LabelFont, [HomeLayout.TileFloor], String)] = [
            (.compactTile, HomeLayout.TileFloor.compact, "compact"),
            (.regularTile, HomeLayout.TileFloor.regular, "regular"),
        ]
        for (font, floors, name) in fonts {
            for floor in floors {
                let width = boldText ? floor.boldWidth : floor.width
                let label = CGSize(width: width - 2 * Self.inset.horizontal, height: floor.height - 2 * Self.inset.vertical)
                for phrase in phrases {
                    StarterLabelFitTests.expectFits(phrase, font, in: label, "\(name) tile \(width) by \(floor.height)", boldText: boldText)
                }
            }
        }
    }

    /// Fails if "Get Attention" does not fit one line at its one-line
    /// width and the touch floor (two lines are too tall for it), or two
    /// lines at its narrowest width and the height the engine gives it
    /// there (`HomeLayout.twoLineQuickControlHeight`).
    @Test(arguments: [false, true])
    func getAttentionHoldsItsWordsOnOneLineOrTwo(boldText: Bool) {
        let minimum = HomeLayout.MinimumWidths.forBoldText(boldText)
        let words = HomeControlNames.getAttention.visible
        let floor = HomeLayout.Profile.touch.floor
        let oneLine = CGSize(width: minimum.getAttentionOneLine - 2 * Self.inset.horizontal, height: floor - 2 * Self.inset.vertical)
        StarterLabelFitTests.expectFits(words, .quickControl, in: oneLine, "Get Attention on one line", boldText: boldText)
        let twoLines = CGSize(
            width: minimum.getAttention - 2 * Self.inset.horizontal,
            height: HomeLayout.twoLineQuickControlHeight - 2 * Self.inset.vertical
        )
        StarterLabelFitTests.expectFits(words, .quickControl, in: twoLines, "Get Attention on two lines", boldText: boldText)
    }

    /// Fails if the controls stop being sized for the starter library's
    /// largest category, or the categories region for its everyday
    /// categories.
    @Test func theReferenceGridIsTheStarterLibrarysLargestCategory() {
        let largest = library.categories.map(\.phrases.count).max() ?? 0
        #expect(largest == HomeLayout.referencePhraseCount)
        #expect(library.categories.filter { !$0.isEmergency }.count == HomeLayout.categoryCapacity)
    }

    // MARK: LabelFont lineChoice, choice, Weight and TextStyle branches

    /// `LabelFont.lineChoice(for:systemImage:steps:width:)` keeps the icon when
    /// it fits at the first step, drops the decorative icon before shrinking
    /// words when the word fits without the icon at step 0, steps down to a
    /// smaller `DynamicTypeSize` when the word alone is too wide at step 0,
    /// and returns a sensible fallback when `steps` is empty.
    @Test func lineChoiceDropsIconBeforeShrinkingAndStepsDownWhenNeeded() {
        let font = LabelFont.category
        let steps = LabelFont.steps(downFrom: .accessibility3)
        let word = "Settings"
        let icon = "gearshape.fill"

        let wordAtTop = font.lineWidth(word, at: .accessibility3)
        let iconAtTop = font.iconAdvance(icon, at: .accessibility3)

        let wideEnoughForBoth = font.lineChoice(
            for: word, systemImage: icon, steps: steps, width: wordAtTop + iconAtTop + WordFit.widthSlack
        )
        #expect(wideEnoughForBoth == WordFit.Choice(step: 0, showsIcon: true))

        let wideEnoughForWordOnly = font.lineChoice(
            for: word, systemImage: icon, steps: steps, width: wordAtTop + WordFit.widthSlack
        )
        #expect(wideEnoughForWordOnly == WordFit.Choice(step: 0, showsIcon: false))

        let wordAtLarge = font.lineWidth(word, at: .large)
        let steppedDown = font.lineChoice(
            for: word, systemImage: icon, steps: steps, width: wordAtLarge + WordFit.widthSlack
        )
        #expect(steppedDown.step > 0)
        #expect(steppedDown.step < steps.count)
        #expect(!steppedDown.showsIcon)

        let tooNarrowEvenAtLarge = font.lineChoice(
            for: word, systemImage: icon, steps: steps, width: wordAtLarge - 5
        )
        #expect(tooNarrowEvenAtLarge == WordFit.Choice(step: steps.count - 1, showsIcon: false))

        let emptySteps = font.lineChoice(for: word, systemImage: icon, steps: [], width: 200)
        #expect(emptySteps == WordFit.Choice(step: 0, showsIcon: false))
    }

    /// `LabelFont.choice(for:systemImage:steps:size:)` drops the decorative
    /// icon at step 0 when keeping the icon forces an extra wrapped line that
    /// exceeds the available height, while the words without the icon fit on
    /// fewer lines at that same text size.
    @Test func choiceDropsIconBeforeShrinkingWhenIconWrappingExceedsHeight() {
        let font = LabelFont.category
        let steps = LabelFont.steps(downFrom: .accessibility2)
        let text = "Everyday Words"
        let icon = "star.fill"
        let topSize = DynamicTypeSize.accessibility2

        let oneLineWidth = font.lineWidth(text, at: topSize)
        let iconAdvance = font.iconAdvance(icon, at: topSize)
        let oneLineHeight = font.lineHeight(at: topSize)

        // Width holds `text` on 1 line without the icon, but with `iconAdvance`
        // subtracted it wraps to 2 lines, exceeding `oneLineHeight + 1`.
        let box = CGSize(width: oneLineWidth + WordFit.widthSlack, height: oneLineHeight + 1)
        #expect(oneLineWidth + iconAdvance > box.width)

        let chosen = font.choice(for: text, systemImage: icon, steps: steps, size: box)
        #expect(chosen == WordFit.Choice(step: 0, showsIcon: false))

        let emptySteps = font.choice(for: text, systemImage: icon, steps: [], size: box)
        #expect(emptySteps == WordFit.Choice(step: 0, showsIcon: false))
    }

    /// Every `Font.TextStyle` case and `LabelFont.Weight` case resolves a
    /// valid `UIFont` and SwiftUI `Font` with positive point size and line
    /// height across Bold Text off and on.
    @Test func everyTextStyleAndWeightResolvesPositiveMetrics() {
        let styles: [Font.TextStyle] = [
            .largeTitle, .title, .title2, .title3, .headline, .subheadline,
            .body, .callout, .footnote, .caption, .caption2,
        ]
        for style in styles {
            for weight in [LabelFont.Weight.regular, .semibold] {
                for bold in [false, true] {
                    let labelFont = LabelFont(textStyle: style, weight: weight, boldText: bold)
                    #expect(labelFont.pointSize(at: .large) > 0)
                    #expect(labelFont.lineHeight(at: .large) >= labelFont.pointSize(at: .large))
                }
            }
        }
    }
}
