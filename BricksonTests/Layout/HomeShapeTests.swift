import Foundation
import Testing
@testable import Brickson

/// The stand-in Home's arrangement, from the width it is given. Widths are
/// content widths (the window less Home's 16pt margins): 288 is a 320pt
/// window (an iPad app in Slide Over), 343 a 375pt iPhone, 370 a 402pt
/// iPhone, 712 a 744pt window, 1000 an iPad Pro 13-inch in portrait.
struct HomeShapeTests {
    /// Fails if the category region scrolls sideways or hides a starter
    /// category on a phone (the code audit's M3).
    @Test func phonesShowTheFourCategoriesTwoByTwo() {
        for width: CGFloat in [288, 343, 370, 408] {
            let shape = HomeShape(contentWidth: width)
            #expect(shape.isCompact, "\(width)pt")
            #expect(shape.categoryColumns * shape.categoryRows >= HomeShape.categoryCapacity, "\(width)pt")
            #expect(shape.categoryColumns == 2, "\(width)pt")
        }
    }

    @Test func wideWindowsShowTheFourCategoriesInOneRow() {
        for width: CGFloat in [HomeShape.regularMinimumWidth, 708, 1000, 1336] {
            let shape = HomeShape(contentWidth: width)
            #expect(!shape.isCompact, "\(width)pt")
            #expect(shape.categoryColumns == 4 && shape.categoryRows == 1, "\(width)pt")
        }
    }

    /// Fails if the narrowest regular window cannot hold four category
    /// buttons of the minimum tile width or more. (The real fit of
    /// "Conversation" is checked with real fonts in `StarterLabelFitTests`.)
    @Test func theRegularThresholdLeavesRoomForFourCategoryButtons() {
        let cell = (HomeShape.regularMinimumWidth - 3 * HomeShape.controlSpacing) / 4
        #expect(cell >= HomeShape.minimumTileWidth)
    }

    /// Fails if a wide window's controls drop below AGENTS.md's gaze floors
    /// (quick controls 88pt, categories 72pt, phrase tiles 110pt), or a
    /// narrow window's below Apple's 44pt touch minimum.
    @Test func controlSizesMeetTheirFloors() {
        let wide = HomeShape(contentWidth: 1000)
        #expect(wide.quickControlHeight >= 88)
        #expect(wide.categoryHeight >= 72)
        #expect(wide.minimumTileHeight >= 110)
        let narrow = HomeShape(contentWidth: 343)
        for height in [narrow.quickControlHeight, narrow.categoryHeight, narrow.minimumTileHeight] {
            #expect(height >= 44)
        }
    }

    /// Fails if phones lose the three-column grid that keeps the starter
    /// library from scrolling, or if a window too narrow for the starter
    /// words gets three columns anyway.
    @Test func phonesGetThreeColumnsUnlessTilesWouldBeTooNarrow() {
        for width: CGFloat in [343, 358, 370, 408] {
            #expect(HomeShape(contentWidth: width).gridColumns == 3, "\(width)pt")
        }
        #expect(HomeShape(contentWidth: 288).gridColumns == 2)
        let narrowestThree = 3 * HomeShape.minimumTileWidth + 2 * HomeShape.controlSpacing
        #expect(HomeShape(contentWidth: narrowestThree).gridColumns == 3)
        #expect(HomeShape(contentWidth: narrowestThree - 1).gridColumns == 2)
    }

    /// Fails if the grid's rows follow the category that is showing: a slot
    /// must keep its place across categories (invariant 8).
    @Test func gridRowsComeFromTheLargestCategory() {
        let shape = HomeShape(contentWidth: 370)
        #expect(shape.gridRows(largestCategoryCount: 8) == 3)
        #expect(shape.gridRows(largestCategoryCount: 9) == 3)
        #expect(shape.gridRows(largestCategoryCount: 10) == 4)
        #expect(shape.gridRows(largestCategoryCount: 0) == 1)
    }

    /// Fails if the category region's height follows how many categories
    /// the library has (docs/LESSONS.md, "Positions are a pure function of
    /// their inputs"): it is always sized for the capacity.
    @Test func theCategoryRegionIsSizedForItsCapacity() {
        let narrow = HomeShape(contentWidth: 370)
        #expect(narrow.categoryRegionHeight == 2 * narrow.categoryHeight + HomeShape.controlSpacing)
        let wide = HomeShape(contentWidth: 1000)
        #expect(wide.categoryRegionHeight == wide.categoryHeight)
    }

    /// Fails if Emergency loses its double share or the row overflows.
    @Test func emergencyTakesTwoSharesOfTheQuickRow() {
        let widths = HomeShape.quickControlWidths(contentWidth: 370)
        #expect(widths.count == 3)
        #expect(widths[0] == widths[1] && widths[2] == 2 * widths[0])
        #expect(widths.reduce(0, +) + 2 * HomeShape.controlSpacing == 370)
    }

    /// Fails if tiles shrink below the minimum instead of the grid scrolling,
    /// or if a grid with room scrolls.
    @Test func tilesFillTheGridOrItScrollsAtTheMinimum() {
        let roomy = GridSizing(availableHeight: 400, rows: 3, spacing: 12, minimumTileHeight: 64)
        #expect(!roomy.scrolls)
        #expect(roomy.tileHeight == 125)

        let tight = GridSizing(availableHeight: 200, rows: 3, spacing: 12, minimumTileHeight: 64)
        #expect(tight.scrolls)
        #expect(tight.tileHeight == 64)

        let exact = GridSizing(availableHeight: 3 * 64 + 2 * 12, rows: 3, spacing: 12, minimumTileHeight: 64)
        #expect(!exact.scrolls)
        #expect(exact.tileHeight == 64)
    }
}
