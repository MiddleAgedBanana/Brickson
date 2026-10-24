import SwiftUI
import Testing
@testable import Brickson

/// The layout engine against the real fonts: the text sizes
/// `HomeLayoutEngineTests` lays out with are the ones `LabelFont` measures,
/// and the widths and heights the engine never goes below hold the words
/// they are for, at the default text size, with Bold Text off and on, the
/// way `StarterLabelFitTests` checks today's stand-in (AGENTS.md, *Words
/// never break*).
struct HomeLayoutEngineFontTests {
    private let library: LibrarySnapshot

    init() throws {
        library = try StarterLibrary.bundled()
    }

    private var phrases: [String] {
        library.categories.flatMap(\.phrases).map(\.text)
    }

    private static let inset = HomeShape.labelInset

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
        let words: [(String, CGFloat)] = [("Phrases", minimum.phrases), ("Type", minimum.type), ("Again", minimum.again), ("Speak", minimum.again)]
        for (word, width) in words {
            let label = CGSize(width: width - 2 * Self.inset.horizontal, height: 10_000)
            StarterLabelFitTests.expectFits(word, .quickControl, in: label, "\(word)'s narrowest slot", boldText: boldText)
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

    /// Fails if a starter phrase does not fit the narrowest tile the engine
    /// makes, at its floor: three compact columns, two compact columns on
    /// the narrowest window, and four regular columns on the narrowest
    /// regular window; and, for the regular tile's narrowest width, its
    /// widest word.
    @Test(arguments: [false, true])
    func everyStarterPhraseFitsTheNarrowestTiles(boldText: Bool) {
        let compactWidth = boldText ? HomeLayout.compactTile.boldMinimumWidth : HomeLayout.compactTile.minimumWidth
        let compactHeight = HomeLayout.compactTile.minimumHeight - 2 * HomeLayout.labelInsetVertical
        let twoColumns = (HomeShape.narrowestContentWidth - HomeLayout.controlSpacing) / 2
        let regularWidth = boldText ? HomeLayout.regularTile.boldMinimumWidth : HomeLayout.regularTile.minimumWidth
        let regular = Self.narrowestRegularLayout(boldText: boldText)
        #expect(regular.isRegular && regular.grid.columns == 4)
        let tiles: [(LabelFont, CGSize, String)] = [
            (.compactTile, CGSize(width: compactWidth - 2 * Self.inset.horizontal, height: compactHeight), "narrowest three-column tile"),
            (.compactTile, CGSize(width: twoColumns - 2 * Self.inset.horizontal, height: compactHeight), "narrowest two-column tile"),
            (
                .regularTile,
                CGSize(width: regular.grid.tileSize.width - 2 * Self.inset.horizontal, height: HomeLayout.regularTile.minimumHeight - 2 * HomeLayout.labelInsetVertical),
                "narrowest four-column tile"
            ),
            (.regularTile, CGSize(width: regularWidth - 2 * Self.inset.horizontal, height: 10_000), "narrowest regular tile width"),
        ]
        for (font, size, slot) in tiles {
            for phrase in phrases {
                StarterLabelFitTests.expectFits(phrase, font, in: size, slot, boldText: boldText)
            }
        }
    }

    /// The layout of the narrowest window that gets the regular
    /// arrangement.
    private static func narrowestRegularLayout(boldText: Bool) -> HomeLayout {
        let minimum = HomeLayout.MinimumWidths.forBoldText(boldText)
        let width = 5 * minimum.regularColumn + 4 * HomeLayout.controlSpacing + 2 * HomeLayout.margins.horizontal
        return HomeLayout(space: .init(size: CGSize(width: width, height: 1000)), text: .measured(at: .large, boldText: boldText))
    }

    /// Fails if the controls stop being sized for the starter library's
    /// largest category, or the categories region for its everyday
    /// categories.
    @Test func theReferenceGridIsTheStarterLibrarysLargestCategory() {
        let largest = library.categories.map(\.phrases.count).max() ?? 0
        #expect(largest == HomeLayout.referencePhraseCount)
        #expect(library.categories.filter { !$0.isEmergency }.count == HomeLayout.categoryCapacity)
    }
}
