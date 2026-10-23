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

    /// Fails if a phone loses the three columns that hold Stop's well, the
    /// four categories and Settings in two rows, or the narrowest window
    /// keeps them where Stop would have no room.
    @Test func phonesTakeThreeColumnsOfCategories() {
        for width: CGFloat in [343, 358, 370, 408] {
            let shape = HomeShape(contentWidth: width)
            #expect(shape.isCompact, "\(width)pt")
            #expect(shape.categoryArrangement == .threeColumns, "\(width)pt")
        }
        #expect(HomeShape(contentWidth: 288).categoryArrangement == .twoColumns)
    }

    /// Fails if a wide window loses the slot plan's band (Stop above the
    /// first category, the other three and Settings at full height), or
    /// keeps it where four categories and Settings' word no longer fit.
    @Test func wideWindowsTakeTheBand() {
        for width: CGFloat in [584, 708, 1000, 1336] {
            let shape = HomeShape(contentWidth: width)
            #expect(!shape.isCompact, "\(width)pt")
            #expect(shape.categoryArrangement == .band, "\(width)pt")
            #expect(shape.settingsShowsName, "\(width)pt")
        }
        let narrowestWide = HomeShape(contentWidth: HomeShape.regularMinimumWidth)
        #expect(!narrowestWide.isCompact)
        #expect(narrowestWide.categoryArrangement == .threeColumns)
        #expect(HomeShape(contentWidth: 583).categoryArrangement == .threeColumns)
        #expect(HomeShape(contentWidth: 629.5, boldText: true).categoryArrangement == .threeColumns)
        #expect(HomeShape(contentWidth: 630, boldText: true).categoryArrangement == .band)
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

    /// Fails if the categories region's height follows how many categories
    /// the library has (docs/LESSONS.md, "Positions are a pure function of
    /// their inputs"): it is always sized for Stop's well, the capacity and
    /// Settings.
    @Test func theCategoryRegionIsSizedForItsCapacity() {
        let spacing = HomeShape.controlSpacing
        let phone = HomeShape(contentWidth: 370)
        #expect(phone.categoryRegionHeight == 2 * phone.categoryHeight + spacing)
        #expect(phone.fullCellHeight == phone.categoryHeight)
        let wide = HomeShape(contentWidth: 1000)
        #expect(wide.categoryRegionHeight == 2 * wide.categoryHeight + spacing)
        #expect(wide.fullCellHeight == wide.categoryRegionHeight)
        let narrowest = HomeShape(contentWidth: 288)
        #expect(narrowest.categoryRegionHeight == 3 * narrowest.categoryHeight + 2 * spacing)
        for shape in [phone, wide, narrowest] {
            let frames = shape.slotFrames
            for slot in Self.categorySlots {
                #expect(frames[slot] != nil, "\(slot) has no cell")
            }
            let top = shape.safetyRegionHeight + HomeShape.regionSpacing
            let bottom = frames.values.map(\.maxY).max() ?? 0
            #expect(abs(bottom - top - shape.categoryRegionHeight) < 0.01)
        }
    }

    // MARK: The safety row, the categories and Settings

    /// Every content width from the narrowest Home plans for to wider than
    /// any iPad, with Bold Text off and on, and with the controls grown for
    /// larger text (one line of each label: none, a large size, and the
    /// largest accessibility size on a phone).
    private static var everyShape: [(shape: HomeShape, context: String)] {
        var shapes: [(HomeShape, String)] = []
        for boldText in [false, true] {
            for (quickLine, categoryLine) in [(CGFloat(0), CGFloat(0)), (31, 27), (67, 65)] {
                for width in everyWidth {
                    let shape = HomeShape(
                        contentWidth: width,
                        quickControlLineHeight: quickLine,
                        categoryLineHeight: categoryLine,
                        boldText: boldText
                    )
                    shapes.append((shape, "\(width)pt, lines \(quickLine)/\(categoryLine), Bold Text \(boldText)"))
                }
            }
        }
        return shapes
    }

    private static let categorySlots: [HomeShape.Slot] = (0..<HomeShape.categoryCapacity).map { .category($0) }
    private static let safetySlots: [HomeShape.Slot] = [.yes, .no, .emergency, .again, .getAttention]

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
            #expect(shape.getAttentionWidth >= minimum.getAttention, "\(width)pt")
            #expect(shape.categoryWidth >= minimum.category, "\(width)pt")
            #expect(shape.stopWidth >= minimum.stop, "\(width)pt")
            let settings = shape.settingsShowsName ? minimum.settings : minimum.settingsSymbol
            #expect(shape.settingsWidth >= settings, "\(width)pt")
            #expect(shape.settingsShowsName == (shape.settingsWidth >= minimum.settings), "\(width)pt")
        }
    }

    /// Fails if a slot overflows the width, overlaps another or sits closer
    /// than the control spacing to it, or a row leaves part of the width
    /// empty: across every row, the slots it crosses run from the leading
    /// edge to the trailing one with one control spacing between each.
    @Test func theRegionsFillTheWidthExactly() {
        let spacing = HomeShape.controlSpacing
        for (shape, context) in Self.everyShape {
            let frames = shape.slotFrames
            let width = 2 * shape.emergencyWidth + spacing
            #expect(frames.count == Self.safetySlots.count + Self.categorySlots.count + 2, "\(context)")
            for (slot, frame) in frames {
                #expect(frame.minX >= -0.01 && frame.maxX <= width + 0.01, "\(slot) leaves the width (\(context))")
                for (other, otherFrame) in frames where other != slot {
                    let apartSideways = otherFrame.minX - frame.maxX >= spacing - 0.01 || frame.minX - otherFrame.maxX >= spacing - 0.01
                    let apartUpAndDown = otherFrame.minY - frame.maxY >= spacing - 0.01 || frame.minY - otherFrame.maxY >= spacing - 0.01
                    #expect(apartSideways || apartUpAndDown, "\(slot) and \(other) are closer than \(spacing)pt (\(context))")
                }
            }
            for line in Set(frames.values.map { $0.minY + 0.5 }) {
                let crossing = frames.values.filter { $0.minY < line && $0.maxY > line }
                let filled = crossing.map(\.width).reduce(0, +) + CGFloat(crossing.count - 1) * spacing
                #expect(abs(filled - width) < 0.01, "the row at \(line) fills \(filled) of \(width) (\(context))")
            }
        }
    }

    /// Fails if Get Attention leaves the safety row's second row, or stops
    /// sitting directly under Emergency, or Emergency leaves the first
    /// row's trailing end, under Settings' Back to Talking. In the first
    /// row it would border the message, where a resting look must never
    /// meet an alarm (docs/DECISIONS.md, "Get Attention and Stop on Home").
    @Test func getAttentionIsDirectlyUnderEmergency() {
        for (shape, context) in Self.everyShape {
            let frames = shape.slotFrames
            guard let emergency = frames[.emergency], let getAttention = frames[.getAttention] else {
                Issue.record("Emergency or Get Attention has no slot (\(context))")
                continue
            }
            let width = 2 * shape.emergencyWidth + HomeShape.controlSpacing
            #expect(emergency.minY == 0 && abs(emergency.maxX - width) < 0.01, "\(context)")
            #expect(getAttention.minX == emergency.minX && getAttention.width == emergency.width, "\(context)")
            #expect(abs(getAttention.minY - emergency.maxY - HomeShape.controlSpacing) < 0.01, "\(context)")
            for slot in [HomeShape.Slot.yes, .no] {
                #expect(frames[slot]?.minY == 0, "\(slot) left the first row (\(context))")
            }
            #expect(frames[.again]?.minY == getAttention.minY, "\(context)")
        }
    }

    /// Fails if Stop's well has anything but a category directly under it,
    /// at the leading edge: Settings there (the slot plan's first draft)
    /// would open the cover on a held look after Stop.
    @Test func stopHasACategoryDirectlyUnderIt() {
        for (shape, context) in Self.everyShape {
            let frames = shape.slotFrames
            guard let stop = frames[.stop] else {
                Issue.record("Stop has no slot (\(context))")
                continue
            }
            #expect(stop.minX == 0, "\(context)")
            let below = frames.filter { abs($0.value.minY - stop.maxY - HomeShape.controlSpacing) < 0.01 && $0.value.minX < stop.midX && $0.value.maxX > stop.midX }
            #expect(below.count == 1, "\(context)")
            #expect(below.keys.allSatisfy { Self.categorySlots.contains($0) }, "\(below.keys) under Stop (\(context))")
        }
    }

    /// Invariant 10, scored on the shape's frames at every width: what a
    /// held look meets after Get Attention and after Stop, by nearest
    /// centre and by nearest edge, ties within half a point counted (the
    /// rules `SettingsOnHomeTests` and `GetAttentionOnHomeTests` apply to
    /// the app's own frames). After Get Attention it stays where it is,
    /// and the nearest other control is never Stop (a repeat would end the
    /// alarm) nor one that speaks. After Stop its well empties, and the
    /// nearest control is a category, which only changes which phrases
    /// show: never Get Attention (a repeat would restart the alarm), never
    /// one that speaks, never Settings.
    @Test func aHeldLookMeetsNothingHarmfulAfterGetAttentionOrStop() {
        let speaks: Set<HomeShape.Slot> = [.yes, .no, .again]
        for (shape, context) in Self.everyShape {
            let frames = shape.slotFrames
            guard let getAttention = frames[.getAttention], let stop = frames[.stop] else {
                Issue.record("Get Attention or Stop has no slot (\(context))")
                continue
            }
            let afterGetAttention = Self.nearest(to: CGPoint(x: getAttention.midX, y: getAttention.midY), among: frames.filter { $0.key != .getAttention })
            for (rule, nearest) in [("centre", afterGetAttention.byCentre), ("edge", afterGetAttention.byEdge)] {
                #expect(!nearest.contains(.stop), "Stop is nearest Get Attention by \(rule) (\(context))")
                #expect(nearest.isDisjoint(with: speaks), "\(nearest) nearest Get Attention by \(rule) (\(context))")
            }
            let afterStop = Self.nearest(to: CGPoint(x: stop.midX, y: stop.midY), among: frames.filter { $0.key != .stop })
            for (rule, nearest) in [("centre", afterStop.byCentre), ("edge", afterStop.byEdge)] {
                #expect(
                    !nearest.isEmpty && nearest.allSatisfy { Self.categorySlots.contains($0) },
                    "\(nearest) nearest Stop's empty well by \(rule) (\(context))"
                )
            }
        }
    }

    /// The slots nearest `point` by the distance to their centres and by
    /// the distance to their nearest edge (zero inside one), each with
    /// every slot within half a point of the nearest.
    private static func nearest(
        to point: CGPoint, among frames: [HomeShape.Slot: CGRect]
    ) -> (byCentre: Set<HomeShape.Slot>, byEdge: Set<HomeShape.Slot>) {
        func centreDistance(_ frame: CGRect) -> CGFloat {
            hypot(point.x - frame.midX, point.y - frame.midY)
        }
        func edgeDistance(_ frame: CGRect) -> CGFloat {
            let dx = max(frame.minX - point.x, 0, point.x - frame.maxX)
            let dy = max(frame.minY - point.y, 0, point.y - frame.maxY)
            return hypot(dx, dy)
        }
        let closestCentre = frames.values.map(centreDistance).min() ?? 0
        let closestEdge = frames.values.map(edgeDistance).min() ?? 0
        return (
            Set(frames.filter { centreDistance($0.value) - closestCentre < 0.5 }.keys),
            Set(frames.filter { edgeDistance($0.value) - closestEdge < 0.5 }.keys)
        )
    }

    /// Fails if Emergency stops being as wide as Again and Get Attention,
    /// or Yes and No stop sharing their column.
    @Test(arguments: [false, true])
    func theSafetyRowIsTwoEqualColumns(boldText: Bool) {
        let spacing = HomeShape.controlSpacing
        for width in Self.everyWidth {
            let shape = HomeShape(contentWidth: width, boldText: boldText)
            #expect(shape.emergencyWidth == shape.againWidth && shape.againWidth == shape.getAttentionWidth, "\(width)pt")
            #expect(abs(2 * shape.yesNoWidth + spacing - shape.againWidth) < 0.01, "\(width)pt")
            #expect(abs(2 * shape.emergencyWidth + spacing - width) < 0.01, "\(width)pt")
        }
    }

    /// Fails if a wider window ever gets a tighter arrangement of the
    /// categories, or loses Settings' word where a narrower one in three
    /// columns or the band had it: the arrangement only gives up room as
    /// the window narrows. (The narrowest windows' two columns give
    /// Settings half the width, so its word shows there again.)
    @Test(arguments: [false, true])
    func roomIsOnlyGivenUpAsTheWindowNarrows(boldText: Bool) {
        func rank(_ arrangement: HomeShape.CategoryArrangement) -> Int {
            switch arrangement {
            case .twoColumns: 0
            case .threeColumns: 1
            case .band: 2
            }
        }
        var widest = 0
        var sawName = false
        for width in Self.everyWidth {
            let shape = HomeShape(contentWidth: width, boldText: boldText)
            #expect(rank(shape.categoryArrangement) >= widest, "\(width)pt")
            widest = max(widest, rank(shape.categoryArrangement))
            guard shape.categoryArrangement != .twoColumns else { continue }
            if sawName { #expect(shape.settingsShowsName, "\(width)pt") }
            sawName = sawName || shape.settingsShowsName
        }
    }

    /// Fails if Bold Text costs a phone's phrase grid any height: the
    /// heavier words may narrow Stop and leave Settings its gear alone, but
    /// never add a row above the phrases.
    @Test func boldTextTakesNoHeightFromAPhonesPhrases() {
        for width: CGFloat in [343, 358, 370, 408] {
            let regular = HomeShape(contentWidth: width)
            let bold = HomeShape(contentWidth: width, boldText: true)
            #expect(bold.categoryArrangement == regular.categoryArrangement, "\(width)pt")
            #expect(bold.safetyRegionHeight == regular.safetyRegionHeight, "\(width)pt")
            #expect(bold.categoryRegionHeight == regular.categoryRegionHeight, "\(width)pt")
        }
    }

    /// Fails if Settings shows its gear alone where its word fits, or
    /// anywhere on a standard phone window without Bold Text. A 375pt
    /// phone with Bold Text, and a window 304 to 331pt wide without it,
    /// have room in Settings' cell only for the gear (docs/DECISIONS.md,
    /// "Settings on Home").
    @Test func settingsShowsItsNameWhereItFits() {
        for width: CGFloat in [343, 358, 370, 408, 712, 1000] {
            #expect(HomeShape(contentWidth: width).settingsShowsName, "\(width)pt")
        }
        for width: CGFloat in [358, 370, 408, 712, 1000] {
            #expect(HomeShape(contentWidth: width, boldText: true).settingsShowsName, "\(width)pt with Bold Text")
        }
        let boldSmallPhone = HomeShape(contentWidth: 343, boldText: true)
        #expect(!boldSmallPhone.settingsShowsName)
        #expect(boldSmallPhone.categoryWidth >= HomeShape.MinimumWidths.boldText.category)
        let narrowWindow = HomeShape(contentWidth: 308)
        #expect(!narrowWindow.settingsShowsName && narrowWindow.categoryArrangement == .threeColumns)
        #expect(HomeShape(contentWidth: 288).settingsShowsName)
    }

    /// Fails if a 402pt phone's categories, Stop and Settings stop sharing
    /// their rows equally, or a narrower phone gives Stop and Settings more
    /// than what the categories' words leave.
    @Test func theCategoriesKeepTheirRoomBeforeStopAndSettings() {
        let phone = HomeShape(contentWidth: 370)
        #expect(phone.categoryWidth == phone.stopWidth && phone.stopWidth == phone.settingsWidth)
        let smaller = HomeShape(contentWidth: 343)
        #expect(smaller.categoryWidth == HomeShape.MinimumWidths.regular.category)
        #expect(smaller.stopWidth == smaller.settingsWidth && smaller.stopWidth < smaller.categoryWidth)
    }

    /// Fails if the safety region's height does not hold its two rows.
    @Test func theSafetyRegionHoldsItsRows() {
        for width: CGFloat in [288, 370, 1000] {
            let shape = HomeShape(contentWidth: width)
            #expect(shape.safetyRegionHeight == 2 * shape.quickControlHeight + HomeShape.controlSpacing)
        }
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
