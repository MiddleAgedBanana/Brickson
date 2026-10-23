import Foundation
import Testing
@testable import Brickson

/// The stand-in Home's arrangement, from the width it is given. Widths are
/// content widths (the window less Home's 16pt margins): 288 is a 320pt
/// window (an iPad app in Slide Over), 343 a 375pt iPhone, 370 a 402pt
/// iPhone, 712 a 744pt window, 1000 an iPad Pro 13-inch in portrait.
struct HomeShapeTests {
    /// Every content width from the narrowest Home plans for to wider than
    /// any iPad, in half points.
    private static let everyWidth = Array(stride(from: CGFloat(288), through: 1400, by: 0.5))

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

    /// Fails if a wide window loses its single row of four categories, or
    /// keeps it where four buttons and Settings no longer fit.
    @Test func wideWindowsShowTheFourCategoriesInOneRow() {
        for width: CGFloat in [584, 708, 1000, 1336] {
            let shape = HomeShape(contentWidth: width)
            #expect(!shape.isCompact, "\(width)pt")
            #expect(shape.categoryColumns == 4 && shape.categoryRows == 1, "\(width)pt")
            #expect(shape.settingsPlacement == .beside, "\(width)pt")
        }
        // The narrowest wide windows hold four categories in a row only
        // without Settings beside them, so they take two rows of two.
        let narrowestWide = HomeShape(contentWidth: HomeShape.regularMinimumWidth)
        #expect(!narrowestWide.isCompact)
        #expect(narrowestWide.categoryColumns == 2 && narrowestWide.settingsPlacement == .beside)
        #expect(HomeShape(contentWidth: 583).categoryColumns == 2)
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

    /// Fails if a control keeps a fixed height when one line of its label at
    /// the person's text size is taller: the label would then have to step
    /// down, and Apple's audit reports text that does not follow Dynamic Type.
    @Test func controlsGrowToHoldOneLineOfTheirLabel() {
        let insets = 2 * HomeShape.labelInset.vertical
        let grown = HomeShape(contentWidth: 343, quickControlLineHeight: 70, categoryLineHeight: 60)
        #expect(grown.quickControlHeight == 70 + insets)
        #expect(grown.categoryHeight == 60 + insets)
        let floors = HomeShape(contentWidth: 1000, quickControlLineHeight: 20, categoryLineHeight: 20)
        #expect(floors.quickControlHeight == 88)
        #expect(floors.categoryHeight == 72)
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
    /// their inputs"): it is always sized for the capacity, with Settings.
    @Test func theCategoryRegionIsSizedForItsCapacity() {
        let narrow = HomeShape(contentWidth: 370)
        #expect(narrow.categoryRegionHeight == 2 * narrow.categoryHeight + HomeShape.controlSpacing)
        #expect(narrow.settingsHeight == narrow.categoryRegionHeight)
        let wide = HomeShape(contentWidth: 1000)
        #expect(wide.categoryRegionHeight == wide.categoryHeight)
        #expect(wide.settingsHeight == wide.categoryHeight)
        let narrowest = HomeShape(contentWidth: 288)
        #expect(narrowest.settingsPlacement == .below)
        #expect(narrowest.categoryRegionHeight == 3 * narrowest.categoryHeight + 2 * HomeShape.controlSpacing)
        #expect(narrowest.settingsHeight == narrowest.categoryHeight)
    }

    // MARK: The safety row and Settings

    /// Fails if a control of the safety row or the categories region gets
    /// narrower than the width its word needs, or Settings than its gear
    /// where it shows the gear alone, at any width, with Bold Text off or
    /// on. `StarterLabelFitTests` checks those widths with the real fonts.
    @Test(arguments: [false, true])
    func everyControlKeepsItsMinimumWidth(boldText: Bool) {
        let minimum = HomeShape.MinimumWidths.forBoldText(boldText)
        for width in Self.everyWidth {
            let shape = HomeShape(contentWidth: width, boldText: boldText)
            #expect(shape.yesNoWidth >= minimum.yesNo, "\(width)pt")
            #expect(shape.againWidth >= minimum.again, "\(width)pt")
            #expect(shape.emergencyWidth >= minimum.emergency, "\(width)pt")
            #expect(shape.categoryWidth >= minimum.category, "\(width)pt")
            let settings = shape.settingsShowsName ? minimum.settings : minimum.settingsSymbol
            #expect(shape.settingsWidth >= settings, "\(width)pt")
            #expect(shape.settingsShowsName == (shape.settingsWidth >= minimum.settings), "\(width)pt")
        }
    }

    /// Fails if the safety row or the categories region overflows the width
    /// or leaves part of it empty.
    @Test(arguments: [false, true])
    func theRegionsFillTheWidthExactly(boldText: Bool) {
        let spacing = HomeShape.controlSpacing
        for width in Self.everyWidth {
            let shape = HomeShape(contentWidth: width, boldText: boldText)
            switch shape.safetyRow {
            case .oneRow:
                let row = 2 * shape.yesNoWidth + shape.againWidth + shape.emergencyWidth + 3 * spacing
                #expect(abs(row - width) < 0.01, "\(width)pt")
            case .twoRows:
                #expect(abs(2 * shape.yesNoWidth + shape.emergencyWidth + 2 * spacing - width) < 0.01, "\(width)pt")
                #expect(shape.againWidth == width, "\(width)pt")
            }
            switch shape.settingsPlacement {
            case .beside:
                #expect(abs(shape.categoryGridWidth + spacing + shape.settingsWidth - width) < 0.01, "\(width)pt")
            case .below:
                #expect(abs(shape.categoryGridWidth - width) < 0.01, "\(width)pt")
                #expect(shape.settingsWidth == width, "\(width)pt")
            }
        }
    }

    /// Fails if Emergency stops being the safety row's widest control, or
    /// Yes, No and Again stop sharing one width in a single row wherever
    /// Again and Emergency have room: Emergency is the longest word and the
    /// easiest target to find.
    @Test(arguments: [false, true])
    func emergencyIsTheWidestQuickControl(boldText: Bool) {
        let minimum = HomeShape.MinimumWidths.forBoldText(boldText)
        for width in Self.everyWidth {
            let shape = HomeShape(contentWidth: width, boldText: boldText)
            #expect(shape.emergencyWidth > shape.yesNoWidth, "\(width)pt")
            if shape.safetyRow == .oneRow {
                #expect(shape.emergencyWidth > shape.againWidth, "\(width)pt")
                #expect(shape.againWidth >= shape.yesNoWidth, "\(width)pt")
                if shape.emergencyWidth > minimum.emergency {
                    #expect(shape.againWidth == shape.yesNoWidth, "\(width)pt")
                }
            }
        }
        let wide = HomeShape(contentWidth: 1000)
        #expect(abs(wide.emergencyWidth - (2 * wide.yesNoWidth + HomeShape.controlSpacing)) < 0.01)
    }

    /// Fails if a window keeps one safety row by narrowing anything but Yes
    /// and No, or splits the row while Yes and No still have room: their
    /// words are the shortest, and a second row costs the phrase grid a
    /// row's height.
    @Test(arguments: [false, true])
    func yesAndNoNarrowBeforeTheSafetyRowSplits(boldText: Bool) {
        let minimum = HomeShape.MinimumWidths.forBoldText(boldText)
        let spacing = HomeShape.controlSpacing
        let narrowestOneRow = 2 * minimum.yesNo + minimum.again + minimum.emergency + 3 * spacing
        let tight = HomeShape(contentWidth: narrowestOneRow, boldText: boldText)
        #expect(tight.safetyRow == .oneRow)
        #expect(tight.yesNoWidth == minimum.yesNo)
        #expect(tight.againWidth == minimum.again && tight.emergencyWidth == minimum.emergency)
        #expect(HomeShape(contentWidth: narrowestOneRow - 0.5, boldText: boldText).safetyRow == .twoRows)
        let smallPhone = HomeShape(contentWidth: 343, boldText: boldText)
        #expect(smallPhone.safetyRow == .oneRow)
        #expect(smallPhone.yesNoWidth <= smallPhone.againWidth)
    }

    /// Fails if a wider window ever gets the two-row safety row, or Settings
    /// on its own row, where a narrower one did not: the arrangement only
    /// gives up room as the window narrows.
    @Test(arguments: [false, true])
    func roomIsOnlyGivenUpAsTheWindowNarrows(boldText: Bool) {
        var sawOneRow = false
        var sawSettingsBeside = false
        var sawSettingsNameBeside = false
        for width in Self.everyWidth {
            let shape = HomeShape(contentWidth: width, boldText: boldText)
            let nameBeside = shape.settingsPlacement == .beside && shape.settingsShowsName
            if sawOneRow { #expect(shape.safetyRow == .oneRow, "\(width)pt") }
            if sawSettingsBeside { #expect(shape.settingsPlacement == .beside, "\(width)pt") }
            if sawSettingsNameBeside { #expect(nameBeside, "\(width)pt") }
            sawOneRow = sawOneRow || shape.safetyRow == .oneRow
            sawSettingsBeside = sawSettingsBeside || shape.settingsPlacement == .beside
            sawSettingsNameBeside = sawSettingsNameBeside || nameBeside
        }
    }

    /// Fails if a phone the app supports loses the one-row safety row or
    /// Settings beside the categories, with Bold Text off or on: either
    /// would take a row from the phrase grid, and a 375pt phone's starter
    /// library would scroll (invariant 11). Or if the narrowest window
    /// keeps them where the words would not fit.
    @Test(arguments: [false, true])
    func phonesKeepOneSafetyRowAndSettingsBesideTheCategories(boldText: Bool) {
        for width: CGFloat in [343, 358, 370, 408] {
            let shape = HomeShape(contentWidth: width, boldText: boldText)
            #expect(shape.safetyRow == .oneRow, "\(width)pt")
            #expect(shape.settingsPlacement == .beside, "\(width)pt")
        }
        let narrowest = HomeShape(contentWidth: 288, boldText: boldText)
        #expect(narrowest.safetyRow == .twoRows && narrowest.settingsPlacement == .below)
    }

    /// Fails if Bold Text costs a phone's phrase grid any height: the
    /// heavier words may narrow Yes and No, and leave Settings its gear
    /// alone, but never add a row above the phrases.
    @Test func boldTextTakesNoHeightFromAPhonesPhrases() {
        for width: CGFloat in [343, 358, 370, 408] {
            let regular = HomeShape(contentWidth: width)
            let bold = HomeShape(contentWidth: width, boldText: true)
            #expect(bold.safetyRegionHeight == regular.safetyRegionHeight, "\(width)pt")
            #expect(bold.categoryRegionHeight == regular.categoryRegionHeight, "\(width)pt")
        }
    }

    /// Fails if Settings shows its gear alone where its word fits beside
    /// the categories, or anywhere on a standard phone window without Bold
    /// Text. A 375pt phone with Bold Text, and a window 328 to 363pt wide
    /// without it, have room beside the categories only for the gear
    /// (docs/DECISIONS.md, "Settings on Home").
    @Test func settingsShowsItsNameWhereItFits() {
        for width: CGFloat in [343, 358, 370, 408, 712, 1000] {
            #expect(HomeShape(contentWidth: width).settingsShowsName, "\(width)pt")
        }
        for width: CGFloat in [358, 370, 408, 712, 1000] {
            #expect(HomeShape(contentWidth: width, boldText: true).settingsShowsName, "\(width)pt with Bold Text")
        }
        let boldSmallPhone = HomeShape(contentWidth: 343, boldText: true)
        #expect(!boldSmallPhone.settingsShowsName)
        #expect(boldSmallPhone.settingsWidth == HomeShape.MinimumWidths.boldText.settingsSymbol)
        #expect(boldSmallPhone.categoryWidth >= HomeShape.MinimumWidths.boldText.category)
        let narrowWindow = HomeShape(contentWidth: 308)
        #expect(!narrowWindow.settingsShowsName && narrowWindow.settingsPlacement == .beside)
        #expect(narrowWindow.settingsWidth == HomeShape.MinimumWidths.regular.settingsSymbol)
        #expect(HomeShape(contentWidth: 288).settingsShowsName)
    }

    /// Fails if a 402pt phone's categories and Settings stop sharing their
    /// row equally, or a narrower phone gives Settings more than its
    /// minimum instead of giving the categories' words the room.
    @Test func settingsSharesTheRowEquallyWhereTheCategoriesHaveRoom() {
        let phone = HomeShape(contentWidth: 370)
        #expect(phone.categoryWidth == phone.settingsWidth)
        let smaller = HomeShape(contentWidth: 343)
        #expect(smaller.settingsWidth == HomeShape.MinimumWidths.regular.settings)
        #expect(smaller.categoryWidth > smaller.settingsWidth)
    }

    /// Fails if the safety region's height does not follow its rows.
    @Test func theSafetyRegionHoldsItsRows() {
        let phone = HomeShape(contentWidth: 370)
        #expect(phone.safetyRegionHeight == phone.quickControlHeight)
        let narrowest = HomeShape(contentWidth: 288)
        #expect(narrowest.safetyRegionHeight == 2 * narrowest.quickControlHeight + HomeShape.controlSpacing)
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
