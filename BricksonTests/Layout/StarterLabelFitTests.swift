import SwiftUI
import Testing
import UIKit
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
/// Over); 560 is the narrowest regular window.
struct StarterLabelFitTests {
    private static let narrowestWidth: CGFloat = 288
    private static let inset = HomeShape.labelInset

    private let library: StarterLibrary

    init() throws {
        library = try StarterLibrary.bundled()
    }

    private var everydayCategoryNames: [String] {
        library.categories.filter { !$0.isEmergency }.map(\.name)
    }

    private var phrases: [String] {
        library.categories.flatMap(\.phrases)
    }

    /// What SwiftUI draws: `text` in `font` at the default size, laid out in
    /// `width` (or on one line when `width` is nil).
    private static func drawnSize(_ text: String, _ font: LabelFont, width: CGFloat? = nil) -> CGSize {
        let view = Text(verbatim: text).font(font.font).dynamicTypeSize(.large)
        return UIHostingController(rootView: view).sizeThatFits(
            in: CGSize(width: width ?? 10_000, height: 10_000)
        )
    }

    /// Checks that `text` fits a label `size` at the default text size: its
    /// widest word, with `WordFit`'s slack, fits the width both by UIKit's
    /// measure and by SwiftUI's, and its lines fit the height.
    private static func expectFits(
        _ text: String, _ font: LabelFont, in size: CGSize, _ slot: String
    ) {
        let measured = font.widestWord(text, at: .large)
        #expect(
            measured + WordFit.widthSlack <= size.width,
            "\(slot): \"\(text)\" needs \(measured) + \(WordFit.widthSlack), has \(size.width)"
        )
        for word in WordFit.words(in: text) {
            let drawn = drawnSize(String(word), font).width
            #expect(drawn <= size.width, "\(slot): \"\(word)\" draws \(drawn) wide, has \(size.width)")
            #expect(
                drawn <= font.widestWord(String(word), at: .large) + 0.5,
                "\(slot): SwiftUI draws \"\(word)\" at \(drawn), more than half a point over UIKit's measure"
            )
        }
        let height = drawnSize(text, font, width: size.width).height
        #expect(height <= size.height, "\(slot): \"\(text)\" draws \(height) tall, has \(size.height)")
    }

    private static func labelSize(_ control: CGSize) -> CGSize {
        CGSize(width: control.width - 2 * inset.horizontal, height: control.height - 2 * inset.vertical)
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

    /// Fails if a starter category's name would break on the narrowest
    /// window, or on the narrowest window with four categories in a row.
    @Test func everyStarterCategoryNameFitsItsButton() {
        let narrow = HomeShape(contentWidth: Self.narrowestWidth)
        let narrowButton = Self.labelSize(CGSize(
            width: (Self.narrowestWidth - HomeShape.controlSpacing) / 2,
            height: narrow.categoryHeight
        ))
        let wide = HomeShape(contentWidth: HomeShape.regularMinimumWidth)
        let wideButton = Self.labelSize(CGSize(
            width: (HomeShape.regularMinimumWidth - 3 * HomeShape.controlSpacing) / 4,
            height: wide.categoryHeight
        ))
        #expect(everydayCategoryNames.count == HomeShape.categoryCapacity)
        for name in everydayCategoryNames {
            Self.expectFits(name, .category, in: narrowButton, "narrowest category button")
            Self.expectFits(name, .category, in: wideButton, "narrowest regular category button")
        }
    }

    /// Fails if Yes, No, Emergency or Again would break or be cut off on the
    /// narrowest window.
    @Test func theQuickControlsFitTheNarrowestWindow() {
        let shape = HomeShape(contentWidth: Self.narrowestWidth)
        let widths = HomeShape.quickControlWidths(contentWidth: Self.narrowestWidth)
        let labels: [(String, CGFloat)] = [
            (String(localized: "Yes"), widths[0]),
            (String(localized: "No"), widths[1]),
            (String(localized: "Emergency"), widths[2]),
            // Again sits beside the message, one share wide.
            (String(localized: "Again", comment: "Repeats the last thing spoken."), widths[0]),
        ]
        for (label, width) in labels {
            Self.expectFits(
                label, .quickControl,
                in: Self.labelSize(CGSize(width: width, height: shape.quickControlHeight)),
                "quick control"
            )
        }
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
    /// size and at widths from the narrowest tile to a wide one: a set line
    /// SwiftUI wrapped again, or more leading than measured. `FittedLabel`
    /// would then choose a size whose words do not fit. Only widths at which
    /// every word fits are checked, the only ones it chooses.
    @Test func theHeightMeasureCoversWhatSwiftUIDraws() {
        let cases: [(LabelFont, [String], [CGFloat])] = [
            (.compactTile, phrases, [99, 140, 200]),
            (.regularTile, phrases, [168, 240, 320]),
            (.category, everydayCategoryNames, [126, 236]),
        ]
        for (font, texts, widths) in cases {
            for size in DynamicTypeSize.allCases where size >= .large {
                for width in widths {
                    for text in texts where font.widestWord(text, at: size) + WordFit.widthSlack <= width {
                        let lines = font.lines(text, width: width, at: size)
                        let view = Text(verbatim: lines.joined(separator: "\n")).font(font.font).dynamicTypeSize(size)
                        let drawn = UIHostingController(rootView: view)
                            .sizeThatFits(in: CGSize(width: width, height: 10_000)).height
                        let measured = font.textHeight(text, width: width, at: size)
                        #expect(
                            drawn <= measured,
                            "\(font.textStyle) at \(size), \(width) wide: \"\(text)\" draws \(drawn), measured \(measured)"
                        )
                    }
                }
            }
        }
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
