import Foundation
import Testing
@testable import Brickson

/// The layout engine's rules, checked on its frames at every width from the
/// narrowest window Home plans for to wider than any iPad, at window heights
/// from a 568pt phone to a 13-inch iPad in portrait, at the default and the
/// largest text sizes, with Bold Text off and on, in both of Home's modes:
/// browsing phrases only, Home's before typing came, and the slot plan's
/// own, Home's now, with Phrases and Type (`HomeLayout.Modes`). Plain logic: no
/// font is measured here (`HomeLayoutEngineFontTests` checks the engine
/// against the real fonts and the windows people use).
///
/// The text sizes are one line of each label style as `LabelFont` measures
/// it: Apple's point sizes for title 3, headline, title 1 and subheadline
/// (the default size: 20, 17, 28 and 15; xxxLarge: 26, 23, 34 and 21; AX5:
/// 55, 53, 58 and 49) times SF Pro's line height, rounded up, plus a point.
struct HomeLayoutEngineTests {
    nonisolated static let defaultText = HomeLayout.Text(quickControlLine: 25, categoryLine: 22, messageLine: 35, statusLine: 19)
    nonisolated static let largerText = HomeLayout.Text(quickControlLine: 33, categoryLine: 29, messageLine: 42, statusLine: 27)
    nonisolated static let largestText = HomeLayout.Text(quickControlLine: 67, categoryLine: 65, messageLine: 71, statusLine: 60)

    /// The text sizes docs/LESSONS.md asks every layout test to cover
    /// ("Apply a change only where it was measured"), smallest first:
    /// default, xxxLarge, AX1 (title 3 at 31 points, headline 28, title 1
    /// 38, subheadline 25), AX3 (43, 40, 48 and 36) and AX5.
    /// `HomeLayoutEngineFontTests` checks each against `LabelFont`.
    nonisolated static let textSizes: [(name: String, text: HomeLayout.Text)] = [
        ("default", defaultText),
        ("xxxLarge", largerText),
        ("AX1", HomeLayout.Text(quickControlLine: 38, categoryLine: 35, messageLine: 47, statusLine: 31)),
        ("AX3", HomeLayout.Text(quickControlLine: 53, categoryLine: 49, messageLine: 59, statusLine: 44)),
        ("AX5", largestText),
    ]

    private static func bold(_ text: HomeLayout.Text) -> HomeLayout.Text {
        var text = text
        text.boldText = true
        return text
    }

    nonisolated static let bothModes: [HomeLayout.Modes] = [.phrasesOnly, .phrasesAndTyping]

    /// Every window from 320pt wide to 1432pt, every 4pt, at heights from
    /// a 568pt phone to a 13-inch iPad in portrait, with no safe areas, at
    /// three text sizes, with Bold Text off and on, in both modes.
    static let everyLayout: [(layout: HomeLayout, text: HomeLayout.Text, context: String)] = {
        var layouts: [(HomeLayout, HomeLayout.Text, String)] = []
        for modes in bothModes {
            for (name, text) in [("default", defaultText), ("xxxLarge", largerText), ("AX5", largestText)] {
                for boldText in [false, true] {
                    let text = boldText ? bold(text) : text
                    for height: CGFloat in [568, 667, 744, 874, 1032, 1376] {
                        for width in stride(from: CGFloat(320), through: 1432, by: 4) {
                            let layout = HomeLayout(space: .init(size: CGSize(width: width, height: height)), text: text, modes: modes)
                            layouts.append((layout, text, "\(width)×\(height), \(name), Bold Text \(boldText), \(modes)"))
                        }
                    }
                }
            }
        }
        return layouts
    }()

    /// Whether Emergency is above Stop's well: only in the slot plan's
    /// one-row safety row, on regular widths with Phrases and Type.
    /// Everywhere else Again is.
    private static func emergencyIsAboveTheWell(_ layout: HomeLayout) -> Bool {
        layout.isRegular && layout.modes == .phrasesAndTyping
    }

    private static let speaks: Set<HomeLayout.Slot> = [.yes, .no, .again]
    private static let categories: Set<HomeLayout.Slot> = Set((0..<HomeLayout.categoryCapacity).map { .category($0) })

    // MARK: Regions and frames

    /// Fails if a layout loses a slot or has one its mode does not (Phrases
    /// and Type without typing), or a slot leaves the content, or two
    /// controls come closer than the spacing between controls.
    @Test func everySlotIsInsideTheContentAndApart() {
        let spacing = HomeLayout.controlSpacing
        var faults: [String] = []
        for (layout, _, context) in Self.everyLayout {
            let expected = layout.modes == .phrasesAndTyping ? HomeLayout.Slot.all.count : HomeLayout.Slot.all.count - 2
            if layout.frames.count != expected || Set(layout.frames.keys) != Set(layout.slots) {
                faults.append("\(layout.frames.count) slots (\(context))")
            }
            let content = layout.content.insetBy(dx: -0.01, dy: -0.01)
            for slot in layout.slots {
                let frame = layout.frame(slot)
                if frame.isNull || frame.minX < content.minX || frame.maxX > content.maxX || frame.minY < content.minY {
                    faults.append("\(slot) at \(frame) leaves \(layout.content) (\(context))")
                }
            }
            let controls = layout.controls + [.message, .statusLine]
            for (index, slot) in controls.enumerated() {
                for other in controls[(index + 1)...] where ![slot, other].allSatisfy({ [.message, .statusLine].contains($0) }) {
                    let a = layout.frame(slot), b = layout.frame(other)
                    let apart = b.minX - a.maxX >= spacing - 0.01 || a.minX - b.maxX >= spacing - 0.01
                        || b.minY - a.maxY >= spacing - 0.01 || a.minY - b.maxY >= spacing - 0.01
                    if !apart {
                        faults.append("\(slot) and \(other) closer than \(spacing)pt (\(context))")
                    }
                }
            }
        }
        // Counts in the expectation: a failure prints what it compared.
        let count = faults.count
        #expect(count == 0, "first: \(faults.first ?? "")")
    }

    /// Fails if the regions leave the slot plan's order, A, C, B, D from
    /// the top, or the gap between them leaves 10 to 12 points: never less
    /// than 2 points more than the gap between controls. B sits lower by
    /// `wellDrop` (`theCategoriesSitLowerOnlyWhereYesWouldReachStopsWell`).
    @Test func theRegionsRunTopToBottomInTheSlotPlansOrder() {
        var faults: [String] = []
        for (layout, _, context) in Self.everyLayout {
            let a = [HomeLayout.Slot.message, .statusLine, .phrases, .type].map(layout.frame).reduce(CGRect.null) { $0.union($1) }
            let c = [HomeLayout.Slot.yes, .no, .emergency, .again, .getAttention].map(layout.frame).reduce(CGRect.null) { $0.union($1) }
            let b = ([HomeLayout.Slot.stop, .settings] + Self.categories).map(layout.frame).reduce(CGRect.null) { $0.union($1) }
            let d = layout.frame(.phraseGrid)
            let gap = layout.regionGap
            if gap < HomeLayout.minimumRegionSpacing - 0.001 || gap > HomeLayout.regionSpacing + 0.001 {
                faults.append("gap \(gap) (\(context))")
            }
            for (upper, lower, apart, name) in [(a, c, gap, "A to C"), (c, b, gap + layout.wellDrop, "C to B"), (b, d, gap, "B to D")]
            where abs(lower.minY - upper.maxY - apart) > 0.01 {
                faults.append("\(name): \(lower.minY - upper.maxY) apart, gap \(gap), drop \(layout.wellDrop) (\(context))")
            }
            if abs(a.minY - layout.content.minY) > 0.01 {
                faults.append("A starts at \(a.minY), content at \(layout.content.minY) (\(context))")
            }
        }
        let count = faults.count
        #expect(count == 0, "first: \(faults.first ?? "")")
    }

    /// Fails if a row of controls leaves part of the width empty or runs
    /// past it: across every horizontal line through the controls, what it
    /// crosses runs from the leading edge to the trailing one with one
    /// control spacing between each.
    @Test func everyRowFillsTheWidth() {
        let spacing = HomeLayout.controlSpacing
        var faults: [String] = []
        for (layout, _, context) in Self.everyLayout {
            let slots = layout.controls + [.message]
            let frames = slots.map(layout.frame)
            for line in Set(frames.map { $0.minY + 0.5 }) {
                let crossing = frames.filter { $0.minY < line && $0.maxY > line }
                let filled = crossing.map(\.width).reduce(0, +) + CGFloat(crossing.count - 1) * spacing
                if abs(filled - layout.content.width) > 0.01 {
                    faults.append("the row at \(line) fills \(filled) of \(layout.content.width) (\(context))")
                }
            }
        }
        let count = faults.count
        #expect(count == 0, "first: \(faults.first ?? "")")
    }

    /// Fails if a control is smaller than the touch profile's 44 by 44
    /// points, or narrower than its words need, at any width, or if Get
    /// Attention, too narrow for its words on one line, is too short for
    /// two.
    @Test func everyControlKeepsItsFloorAndItsWords() {
        var faults: [String] = []
        for (layout, text, context) in Self.everyLayout {
            let minimum = HomeLayout.MinimumWidths.forBoldText(text.boldText)
            for slot in layout.controls {
                let frame = layout.frame(slot)
                if frame.width < 44 - 0.01 || frame.height < 44 - 0.01 {
                    faults.append("\(slot) is \(frame.size) (\(context))")
                }
            }
            let needs: [(HomeLayout.Slot, CGFloat)] = [
                (.yes, minimum.yesNo), (.no, minimum.yesNo), (.again, minimum.again), (.emergency, minimum.emergency),
                (.getAttention, minimum.getAttention), (.phrases, minimum.phrases), (.type, minimum.type), (.stop, minimum.stop),
                (.settings, layout.settingsShowsName ? minimum.settings : minimum.settingsSymbol),
            ] + Self.categories.map { ($0, minimum.category) }
            for (slot, need) in needs where layout.slots.contains(slot) && layout.frame(slot).width < need - 0.01 {
                faults.append("\(slot) is \(layout.frame(slot).width) wide, needs \(need) (\(context))")
            }
            let getAttention = layout.frame(.getAttention)
            if getAttention.width < minimum.getAttentionOneLine - 0.01 && getAttention.height < HomeLayout.twoLineQuickControlHeight - 0.01 {
                faults.append("Get Attention is \(getAttention.size), too short for two lines (\(context))")
            }
            if layout.settingsShowsName != (layout.frame(.settings).width >= minimum.settings) {
                faults.append("Settings' name and width disagree (\(context))")
            }
            let tile = layout.grid.tileSize
            let tileMinimum = layout.isRegular
                ? (text.boldText ? HomeLayout.regularTile.boldMinimumWidth : HomeLayout.regularTile.minimumWidth)
                : (text.boldText ? HomeLayout.compactTile.boldMinimumWidth : HomeLayout.compactTile.minimumWidth)
            if tile.width < tileMinimum - 0.01 && !(layout.grid.columns == 2) {
                faults.append("tiles \(tile.width) wide in \(layout.grid.columns) columns (\(context))")
            }
        }
        let count = faults.count
        #expect(count == 0, "first: \(faults.first ?? "")")
    }

    /// Known limit (docs/DECISIONS.md, "The layout engine", *The message
    /// on the narrowest windows*): beside Phrases and Type, the message is
    /// narrower than the starter library's widest word at the default size
    /// on compact windows under 345 points with Bold Text on. Fails if the
    /// message is too narrow anywhere else, across the width without typing
    /// included, and, strict, once it is wide enough there too.
    @Test func theMessageHoldsItsWidestWordExceptOnTheNarrowestBoldWindows() {
        var faults: [String] = []
        var tooNarrow = 0
        for (layout, text, context) in Self.everyLayout {
            let minimum = HomeLayout.MinimumWidths.forBoldText(text.boldText).message
            if layout.messageHoldsItsWords != (layout.frame(.message).width >= minimum) {
                faults.append("messageHoldsItsWords disagrees with the frame (\(context))")
            }
            if !layout.messageHoldsItsWords {
                let besidePhrasesAndType = layout.modes == .phrasesAndTyping && !layout.isRegular
                if text.boldText && besidePhrasesAndType && layout.content.width < 345 - 2 * HomeLayout.margins.horizontal {
                    tooNarrow += 1
                } else {
                    faults.append("the message is \(layout.frame(.message).width) wide, needs \(minimum) (\(context))")
                }
            }
        }
        let count = faults.count
        #expect(count == 0, "first: \(faults.first ?? "")")
        withKnownIssue("docs/DECISIONS.md, \"The layout engine\": the message on the narrowest windows") {
            #expect(tooNarrow == 0)
        }
    }

    /// Fails if a control is shorter than one line of its words at the
    /// person's text size with the label's inset: the words would step
    /// down, which Apple's audit reports as text that does not follow
    /// Dynamic Type.
    @Test(arguments: [defaultText, largerText, largestText])
    func controlsHoldOneLineOfTheirWords(text: HomeLayout.Text) {
        let insets = 2 * HomeLayout.labelInset.vertical
        let quick: [HomeLayout.Slot] = [.yes, .no, .emergency, .again, .getAttention, .phrases, .type]
        for modes in Self.bothModes {
            for width: CGFloat in [320, 375, 402, 744, 1032, 1376] {
                let layout = HomeLayout(space: .init(size: CGSize(width: width, height: 874)), text: text, modes: modes)
                let context = "\(width)pt, \(modes)"
                for slot in quick where layout.slots.contains(slot) {
                    #expect(layout.frame(slot).height >= text.quickControlLine + insets - 0.01, "\(slot) at \(context)")
                }
                for slot in [HomeLayout.Slot.stop, .settings] + Self.categories {
                    #expect(layout.frame(slot).height >= text.categoryLine + insets - 0.01, "\(slot) at \(context)")
                }
                #expect(layout.frame(.message).height >= 2 * text.messageLine - 0.01, "two lines of the message at \(context)")
                #expect(layout.frame(.statusLine).height >= text.statusLine - 0.01, "the status line at \(context)")
            }
        }
    }

    // MARK: Tile floors

    /// The floors a tile's width gives it (`HomeLayout.TileFloor`): the
    /// tallest starter phrase in four lines at the narrowest compact tile,
    /// three from 114 points (120 with Bold Text), two from 160 (170); and
    /// three lines at the narrowest regular tile, two from 198 (213). Fails
    /// if a width gets a floor its lines do not set: the shortest that
    /// applies, never one for a wider tile, never under the profile's.
    @Test(arguments: [false, true])
    func theTileFloorFollowsTheTilesWidth(boldText: Bool) {
        for floors in [HomeLayout.TileFloor.compact, HomeLayout.TileFloor.regular] {
            let widths = floors.map { boldText ? $0.boldWidth : $0.width }
            #expect(widths == widths.sorted() && Set(widths).count == widths.count, "\(floors)")
            #expect(floors.map(\.height) == floors.map(\.height).sorted(by: >), "\(floors)")
            #expect(floors.allSatisfy { $0.boldWidth >= $0.width }, "\(floors)")
            func floor(_ width: CGFloat) -> CGFloat {
                HomeLayout.TileFloor.height(for: width, in: floors, boldText: boldText, profileFloor: 44)
            }
            for (index, width) in widths.enumerated() {
                #expect(floor(width) == floors[index].height, "\(width)pt")
                #expect(floor(width - 0.5) == floors[max(0, index - 1)].height, "just under \(width)pt")
            }
            #expect(floor(widths[0] - 20) == floors[0].height, "narrower than the narrowest floor")
            #expect(floor(2000) == floors[floors.count - 1].height)
        }
        let short = [HomeLayout.TileFloor(width: 50, boldWidth: 50, height: 30)]
        #expect(HomeLayout.TileFloor.height(for: 100, in: short, boldText: boldText, profileFloor: 44) == 44)
    }

    /// Fails if a layout's grid takes a floor other than its tiles' width
    /// sets, or a tile is shorter than its floor.
    @Test func everyGridKeepsTheFloorItsWidthSets() {
        var faults: [String] = []
        for (layout, text, context) in Self.everyLayout {
            let floors = layout.isRegular ? HomeLayout.regularTile.floors : HomeLayout.compactTile.floors
            let floor = HomeLayout.TileFloor.height(for: layout.grid.tileSize.width, in: floors, boldText: text.boldText, profileFloor: 44)
            if layout.grid.tileFloor != floor || layout.grid.tileSize.height < floor - 0.001 {
                faults.append("tiles \(layout.grid.tileSize), floor \(layout.grid.tileFloor), expected \(floor) (\(context))")
            }
        }
        let count = faults.count
        #expect(count == 0, "first: \(faults.first ?? "")")
    }

    // MARK: The two arrangements

    /// Fails if a phone loses the compact arrangement, or a window that
    /// holds five columns of the widest words does not get the regular
    /// one, or the line between them moves off the widest words: in both
    /// modes, since the line comes from the width alone.
    @Test(arguments: [false, true])
    func theArrangementComesFromTheWidth(boldText: Bool) {
        let text = boldText ? Self.bold(Self.defaultText) : Self.defaultText
        let minimum = HomeLayout.MinimumWidths.forBoldText(boldText)
        let threshold = 5 * minimum.regularColumn + 4 * HomeLayout.controlSpacing + 2 * HomeLayout.margins.horizontal
        for modes in Self.bothModes {
            func layout(_ width: CGFloat) -> HomeLayout {
                HomeLayout(space: .init(size: CGSize(width: width, height: 1000)), text: text, modes: modes)
            }
            for width: CGFloat in [320, 375, 390, 402, 440, 466] {
                #expect(!layout(width).isRegular, "\(width)pt, \(modes)")
            }
            #expect(layout(threshold).isRegular)
            #expect(!layout(threshold - 0.5).isRegular)
            for width: CGFloat in [744, 834, 1032, 1376] {
                #expect(layout(width).isRegular, "\(width)pt, \(modes)")
                #expect(layout(width).categoryArrangement == .band, "\(width)pt, \(modes)")
                #expect(layout(width).grid.columns == 4, "\(width)pt, \(modes)")
            }
            #expect(layout(375).categoryArrangement == .threeColumns)
            // Three columns of tiles where three hold "understand.": with
            // Bold Text, from a 402-point window.
            #expect(layout(375).grid.columns == (boldText ? 2 : 3))
            #expect(layout(390).grid.columns == (boldText ? 2 : 3))
            #expect(layout(402).grid.columns == 3)
            #expect(layout(320).categoryArrangement == .twoColumns)
            #expect(layout(320).grid.columns == 2)
        }
    }

    /// Get Attention directly under Emergency, with Yes, No and Emergency
    /// in the first row and Again beside Get Attention in the second
    /// (docs/DECISIONS.md, "Get Attention and Stop on Home"): on compact
    /// widths, under Phrases and Type, and on every width without typing.
    /// Fails if Get Attention leaves the place under Emergency, or moves
    /// into the first row, where it would border the message.
    @Test func getAttentionIsDirectlyUnderEmergencyInTwoRows() {
        for (layout, _, context) in Self.everyLayout where !Self.emergencyIsAboveTheWell(layout) {
            let emergency = layout.frame(.emergency), getAttention = layout.frame(.getAttention)
            #expect(getAttention.minX == emergency.minX && getAttention.width == emergency.width, "\(context)")
            #expect(abs(getAttention.minY - emergency.maxY - HomeLayout.controlSpacing) < 0.01, "\(context)")
            #expect(layout.frame(.yes).minY == emergency.minY && layout.frame(.no).minY == emergency.minY, "\(context)")
            #expect(layout.frame(.again).minY == getAttention.minY, "\(context)")
            if layout.modes == .phrasesAndTyping {
                #expect(emergency.minX == layout.frame(.type).minX && emergency.width == layout.frame(.type).width, "\(context)")
            }
        }
    }

    /// Without typing, Home's arrangement before the engine, on the
    /// engine's frames: the message and its status line across the width,
    /// and the safety row in two equal columns, Yes and No sharing the
    /// leading one, Emergency at the first row's trailing end, under
    /// Settings' Back to Talking (docs/DECISIONS.md, "Settings on Home").
    /// Fails if Phrases or Type appear, the message narrows, or a column
    /// of the safety row stops matching the other.
    @Test func withoutTypingTheMessageSpansTheWidthAboveTwoEqualColumns() {
        let spacing = HomeLayout.controlSpacing
        for (layout, _, context) in Self.everyLayout where layout.modes == .phrasesOnly {
            let content = layout.content
            #expect(layout.frame(.phrases).isNull && layout.frame(.type).isNull, "\(context)")
            for slot in [HomeLayout.Slot.message, .statusLine] {
                #expect(layout.frame(slot).minX == content.minX && abs(layout.frame(slot).width - content.width) < 0.01, "\(slot) (\(context))")
            }
            let emergency = layout.frame(.emergency), again = layout.frame(.again), getAttention = layout.frame(.getAttention)
            #expect(emergency.width == again.width && again.width == getAttention.width, "\(context)")
            #expect(abs(2 * layout.frame(.yes).width + spacing - again.width) < 0.01, "\(context)")
            #expect(layout.frame(.yes).width == layout.frame(.no).width, "\(context)")
            #expect(abs(emergency.maxX - content.maxX) < 0.01 && layout.frame(.yes).minX == content.minX, "\(context)")
        }
    }

    /// The regular safety row with Phrases and Type is the slot plan's own:
    /// one row, Emergency, Yes, No, Again, Get Attention, with the message
    /// over Emergency, Yes and No and Phrases and Type over Again and Get
    /// Attention. Fails if the order changes or a second row appears.
    @Test func regularPutsTheSafetyRowInOneRow() {
        for (layout, _, context) in Self.everyLayout where Self.emergencyIsAboveTheWell(layout) {
            let order: [HomeLayout.Slot] = [.emergency, .yes, .no, .again, .getAttention]
            let frames = order.map(layout.frame)
            #expect(Set(frames.map(\.minY)).count == 1, "\(context)")
            #expect(frames.map(\.minX) == frames.map(\.minX).sorted(), "\(context)")
            #expect(abs(layout.frame(.message).maxX - layout.frame(.no).maxX) < 0.01, "\(context)")
            #expect(abs(layout.frame(.phrases).minX - layout.frame(.again).minX) < 0.01, "\(context)")
        }
    }

    /// Fails if Phrases stops sitting above Type in A's trailing column,
    /// beside the message, or the two stop sharing A's height.
    @Test func phrasesSitsAboveTypeBesideTheMessage() {
        for (layout, _, context) in Self.everyLayout where layout.modes == .phrasesAndTyping {
            let phrases = layout.frame(.phrases), type = layout.frame(.type), message = layout.frame(.message)
            #expect(phrases.minY == message.minY && phrases.minX > message.maxX, "\(context)")
            #expect(type.minX == phrases.minX && type.width == phrases.width && type.height == phrases.height, "\(context)")
            #expect(abs(type.minY - phrases.maxY - HomeLayout.controlSpacing) < 0.01, "\(context)")
            #expect(abs(type.maxY - layout.frame(.statusLine).maxY) < 0.01, "\(context)")
        }
    }

    /// Fails if Get Attention takes two lines on a compact window with room
    /// beside the message for its words on one: the trailing column is as
    /// wide as "Get Attention" wherever the message keeps its widest word
    /// beside it, because two lines would make the safety row, and Phrases
    /// and Type above it, taller (docs/DECISIONS.md, "Typing on Home").
    @Test func getAttentionTakesOneLineWhereTheMessageLeavesRoom() {
        var faults: [String] = []
        var checked = 0
        for (layout, text, context) in Self.everyLayout where layout.modes == .phrasesAndTyping && !layout.isRegular {
            let minimum = HomeLayout.MinimumWidths.forBoldText(text.boldText)
            guard layout.content.width - HomeLayout.controlSpacing - minimum.message >= minimum.getAttentionOneLine else { continue }
            checked += 1
            if layout.frame(.getAttention).width < minimum.getAttentionOneLine - 0.01 {
                faults.append("Get Attention is \(layout.frame(.getAttention).width) wide (\(context))")
            }
            if layout.frame(.message).width < minimum.message - 0.01 {
                faults.append("the message is \(layout.frame(.message).width) wide (\(context))")
            }
        }
        let count = faults.count
        #expect(count == 0, "first: \(faults.first ?? "")")
        #expect(checked > 0)
    }

    /// Settings' Back to Talking sits over Phrases, as tall, in the
    /// categories' font (docs/DECISIONS.md, "Typing on Home"). Fails if
    /// Phrases or Type is shorter than the profile's floor or one line of
    /// the quick controls' words, or, where Back to Talking is too narrow
    /// for its words on one line, shorter than two lines of them.
    @Test func phrasesHasRoomForBackToTalking() {
        var faults: [String] = []
        var narrow = 0
        for (layout, text, context) in Self.everyLayout where layout.modes == .phrasesAndTyping {
            let minimum = HomeLayout.MinimumWidths.forBoldText(text.boldText)
            let phrases = layout.frame(.phrases)
            let oneLine = max(HomeLayout.Profile.touch.floor, text.quickControlLine + 2 * HomeLayout.labelInset.vertical)
            if phrases.height < oneLine - 0.01 {
                faults.append("Phrases is \(phrases.height) tall, needs \(oneLine) (\(context))")
            }
            if layout.backToTalking.width < minimum.backToTalkingOneLine - 0.01 {
                narrow += 1
                if phrases.height < HomeLayout.twoLineCategoryHeight - 0.01 {
                    faults.append("Phrases is \(phrases.size), too short for Back to Talking on two lines (\(context))")
                }
            }
        }
        let count = faults.count
        #expect(count == 0, "first: \(faults.first ?? "")")
        #expect(narrow > 0)
    }

    /// Settings closes onto the phrases, so a look still resting on Back
    /// to Talking must meet Phrases, which does nothing while they show
    /// (invariant 10; docs/DECISIONS.md, "Typing on Home"). Fails if Back
    /// to Talking leaves Phrases' frame, or if any point across it is
    /// nearer another control than Phrases, by centre or by edge, ties
    /// counted: as it would be on regular widths with Back to Talking as
    /// wide as Phrases, whose lower corners are nearer Get Attention's
    /// centre or Again's, and on short regular windows with it a column
    /// wide. Also fails if it is not Phrases' frame on compact widths, or,
    /// on regular ones, not centred over Phrases and as tall, or wider than
    /// a column, or narrower than a column on any window 874 points tall
    /// or taller, where a column is never too wide.
    @Test func backToTalkingClosesOntoPhrasesAlone() {
        var faults: [String] = []
        var regular = 0
        var narrowed = 0
        for (layout, _, context) in Self.everyLayout where layout.modes == .phrasesAndTyping {
            let phrases = layout.frame(.phrases)
            let back = layout.backToTalking
            let inside = back.minX >= phrases.minX - 0.001 && back.maxX <= phrases.maxX + 0.001
                && back.minY >= phrases.minY - 0.001 && back.maxY <= phrases.maxY + 0.001
            if !inside || back.isEmpty {
                faults.append("Back to Talking \(back) is not over Phrases \(phrases) (\(context))")
                continue
            }
            if layout.isRegular {
                regular += 1
                let column = layout.frame(.again).width
                let tall = layout.content.height + 2 * HomeLayout.margins.vertical >= 874
                if back.width > column + 0.001 || (tall && back.width < column - 0.001)
                    || abs(back.midX - phrases.midX) > 0.001 || abs(back.height - phrases.height) > 0.001 {
                    faults.append("Back to Talking \(back) is not a column or less, centred over Phrases \(phrases) (\(context))")
                }
                if back.width < column - 0.001 { narrowed += 1 }
            } else if back != phrases {
                faults.append("Back to Talking \(back) is not Phrases' frame \(phrases) (\(context))")
            }
            let controls = Nearest.controls(in: layout)
            for point in Nearest.points(in: back) {
                let met = Nearest.to(point, among: controls)
                if met != [.phrases] {
                    faults.append("a look at \(point) on Back to Talking meets \(met.map(\.description).sorted()) (\(context))")
                    break
                }
            }
        }
        let count = faults.count
        #expect(count == 0, "first: \(faults.first ?? "")")
        #expect(regular > 0 && narrowed > 0)
    }

    /// Fails if Phrases and Type grow before the safety row has grown as
    /// far as it goes, or keep growth the keyboard's room needs: they grow
    /// toward the safety row's height after it, and where the keyboard's
    /// room is short they give back what they grew before the safety row
    /// gives back anything (docs/DECISIONS.md, "Typing on Home").
    @Test func phrasesAndTypeGrowAfterTheSafetyRowAndGiveItBackFirst() {
        var faults: [String] = []
        var grown = 0
        for (layout, text, context) in Self.everyLayout where layout.modes == .phrasesAndTyping {
            let minimum = HomeLayout.MinimumWidths.forBoldText(text.boldText)
            let spacing = HomeLayout.controlSpacing
            let insets = 2 * HomeLayout.labelInset.vertical
            let phrases = layout.frame(.phrases)
            let modeFloor = max(
                HomeLayout.Profile.touch.floor, text.quickControlLine + insets,
                layout.backToTalking.width < minimum.backToTalkingOneLine - 0.001 ? HomeLayout.twoLineCategoryHeight : 0
            )
            let messageBlock = 2 * text.messageLine + HomeLayout.statusSpacing + text.statusLine
            let floorHeight = (max(messageBlock, 2 * modeFloor + spacing) - spacing) / 2
            guard phrases.height > floorHeight + 0.01 else { continue }
            grown += 1
            let quickFloor = max(
                HomeLayout.Profile.touch.floor, text.quickControlLine + insets,
                layout.frame(.getAttention).width < minimum.getAttentionOneLine - 0.001 ? HomeLayout.twoLineQuickControlHeight : 0
            )
            let quickTarget = max(quickFloor, HomeLayout.Profile.touch.quickControlHeight(isRegular: layout.isRegular))
            if layout.quickControlHeight < quickTarget - 0.01 {
                faults.append("Phrases grew to \(phrases.height) with the safety row at \(layout.quickControlHeight) of \(quickTarget) (\(context))")
            }
            if phrases.height > max(modeFloor, quickTarget) + 0.01 {
                faults.append("Phrases grew to \(phrases.height), past \(max(modeFloor, quickTarget)) (\(context))")
            }
        }
        let count = faults.count
        #expect(count == 0, "first: \(faults.first ?? "")")
        #expect(grown > 0)
        // An iPhone 17 at the default size: room for all of it, so Phrases
        // and Type are as tall as the safety row's controls.
        let phone = HomeLayout(
            space: .init(size: CGSize(width: 402, height: 874), safeArea: .init(top: 62, leading: 0, bottom: 34, trailing: 0)),
            text: Self.defaultText, modes: .phrasesAndTyping
        )
        #expect(phone.frame(.phrases).height == phone.quickControlHeight && phone.quickControlHeight == 64)
    }

    /// Fails if Clear or Put Back takes the category cell under Stop's well
    /// or the one beside it, which a look still resting where Stop was
    /// meets, or if the two share a cell (docs/DECISIONS.md, "Typing on
    /// Home").
    @Test func clearAndPutBackStayOffStopsNeighbours() {
        let spacing = HomeLayout.controlSpacing
        for (layout, _, context) in Self.everyLayout where layout.modes == .phrasesAndTyping {
            let cells = layout.typingCells
            #expect(cells.clear != cells.putBack, "\(context)")
            let well = layout.frame(.stop)
            for index in [cells.clear, cells.putBack] {
                #expect((0..<HomeLayout.categoryCapacity).contains(index), "\(context)")
                let cell = layout.frame(.category(index))
                let under = abs(cell.minX - well.minX) < 0.01 && abs(cell.minY - well.maxY - spacing) < 0.01
                let beside = abs(cell.minY - well.minY) < 0.01 && abs(cell.minX - well.maxX - spacing) < 0.01
                #expect(!under && !beside, "category \(index + 1) (\(context))")
            }
        }
    }

    /// Fails if Stop's well leaves the leading edge or loses the category
    /// directly under it (Settings there, the slot plan's first draft,
    /// would open the cover on a held look after Stop), or, in the slot
    /// plan's one-row safety row, stops sitting directly under Emergency.
    @Test func stopHasACategoryDirectlyUnderIt() {
        for (layout, _, context) in Self.everyLayout {
            let stop = layout.frame(.stop)
            #expect(abs(stop.minX - layout.content.minX) < 0.01, "\(context)")
            let below = Below.controls(under: stop, in: layout)
            #expect(below.count == 1 && below.isSubset(of: Self.categories), "\(below) under Stop (\(context))")
            if Self.emergencyIsAboveTheWell(layout) {
                let emergency = layout.frame(.emergency)
                #expect(emergency.minX == stop.minX && emergency.width == stop.width, "\(context)")
            }
        }
    }

    /// Fails if a wider window ever gets a tighter arrangement of the
    /// categories, or loses Settings' word where a narrower one in three
    /// columns or the band had it: the arrangement only gives up room as
    /// the window narrows. (The narrowest windows' two columns give
    /// Settings half the width, so its word shows there again.)
    @Test(arguments: [false, true])
    func roomIsOnlyGivenUpAsTheWindowNarrows(boldText: Bool) {
        func rank(_ arrangement: HomeLayout.CategoryArrangement) -> Int {
            switch arrangement {
            case .twoColumns: 0
            case .threeColumns: 1
            case .band: 2
            }
        }
        let text = boldText ? Self.bold(Self.defaultText) : Self.defaultText
        var widest = 0
        var sawName = false
        for width in stride(from: CGFloat(320), through: 1432, by: 0.5) {
            let layout = HomeLayout(space: .init(size: CGSize(width: width, height: 874)), text: text, modes: .phrasesOnly)
            #expect(rank(layout.categoryArrangement) >= widest, "\(width)pt")
            widest = max(widest, rank(layout.categoryArrangement))
            guard layout.categoryArrangement != .twoColumns else { continue }
            if sawName { #expect(layout.settingsShowsName, "\(width)pt") }
            sawName = sawName || layout.settingsShowsName
        }
    }

    /// Fails if Settings shows its gear alone where its word fits, or on a
    /// phone's window without Bold Text. With Bold Text, 375 and 390-point
    /// phones show the gear alone: the categories keep the room their
    /// selection ring needs (`HomeLayout.selectableSideInset`), and what is
    /// left beside them is too narrow for "Settings" in its heaviest weight
    /// (docs/DECISIONS.md, "Settings on Home"). So do windows 344 to 371
    /// points wide without it.
    @Test func settingsShowsItsNameWhereItFits() {
        func layout(_ width: CGFloat, boldText: Bool = false) -> HomeLayout {
            let text = boldText ? Self.bold(Self.defaultText) : Self.defaultText
            return HomeLayout(space: .init(size: CGSize(width: width, height: 874)), text: text, modes: .phrasesOnly)
        }
        for width: CGFloat in [375, 390, 402, 440, 744, 1032] {
            #expect(layout(width).settingsShowsName, "\(width)pt")
        }
        for width: CGFloat in [402, 440, 744, 1032] {
            #expect(layout(width, boldText: true).settingsShowsName, "\(width)pt with Bold Text")
        }
        for width: CGFloat in [375, 390] {
            let bold = layout(width, boldText: true)
            #expect(!bold.settingsShowsName && bold.categoryArrangement == .threeColumns, "\(width)pt with Bold Text")
            #expect(bold.frame(.category(0)).width >= HomeLayout.MinimumWidths.boldText.category, "\(width)pt with Bold Text")
        }
        #expect(!layout(360).settingsShowsName && layout(360).categoryArrangement == .threeColumns)
        #expect(layout(320).settingsShowsName && layout(320).categoryArrangement == .twoColumns)
    }

    /// Fails if a 440-point phone's categories, Stop and Settings stop
    /// sharing their rows equally, or a narrower phone gives Stop and
    /// Settings more than what the categories' words leave.
    @Test func theCategoriesKeepTheirRoomBeforeStopAndSettings() {
        func layout(_ width: CGFloat) -> HomeLayout {
            HomeLayout(space: .init(size: CGSize(width: width, height: 874)), text: Self.defaultText, modes: .phrasesOnly)
        }
        let large = layout(440)
        #expect(abs(large.frame(.category(0)).width - large.frame(.stop).width) < 0.01)
        #expect(abs(large.frame(.stop).width - large.frame(.settings).width) < 0.01)
        for width: CGFloat in [375, 402] {
            let phone = layout(width)
            #expect(phone.frame(.category(0)).width == HomeLayout.MinimumWidths.regular.category, "\(width)pt")
            #expect(phone.frame(.stop).width == phone.frame(.settings).width, "\(width)pt")
            #expect(phone.frame(.stop).width < phone.frame(.category(0)).width, "\(width)pt")
        }
    }

    /// Fails if Bold Text costs a phone's controls any height: the heavier
    /// words may narrow Stop and leave Settings its gear alone, but never
    /// add a row above the phrases or shrink the safety row.
    @Test func boldTextTakesNoHeightFromAPhonesControls() {
        for width: CGFloat in [375, 390, 402, 440] {
            for height: CGFloat in [874, 956] {
                let plain = HomeLayout(space: .init(size: CGSize(width: width, height: height)), text: Self.defaultText, modes: .phrasesOnly)
                let bold = HomeLayout(space: .init(size: CGSize(width: width, height: height)), text: Self.bold(Self.defaultText), modes: .phrasesOnly)
                #expect(bold.categoryArrangement == plain.categoryArrangement, "\(width)×\(height)")
                #expect(bold.quickControlHeight == plain.quickControlHeight, "\(width)×\(height)")
                #expect(bold.categoryHeight == plain.categoryHeight, "\(width)×\(height)")
            }
        }
    }

    // MARK: What a held look meets next (invariant 10)

    /// After Get Attention it stays where it is, and the nearest other
    /// control, by nearest centre and by nearest edge, ties within half a
    /// point counted, is never Stop (a repeat would end the alarm) nor one
    /// that speaks.
    @Test func aHeldLookAfterGetAttentionMeetsNothingHarmful() {
        var faults: [String] = []
        for (layout, _, context) in Self.everyLayout {
            let met = Nearest.after(.getAttention, in: layout)
            if met.contains(.stop) || !met.isDisjoint(with: Self.speaks) {
                faults.append("\(met) after Get Attention (\(context))")
            }
        }
        let count = faults.count
        #expect(count == 0, "first: \(faults.first ?? "")")
    }

    /// After Stop its well empties, and the nearest control is a category,
    /// which only changes which phrases show: never Get Attention, one that
    /// speaks, or Settings.
    @Test func aHeldLookAfterStopMeetsACategory() {
        var faults: [String] = []
        for (layout, _, context) in Self.everyLayout {
            let met = Nearest.after(.stop, in: layout)
            if met.isEmpty || !met.isSubset(of: Self.categories) {
                faults.append("\(met) after Stop (\(context))")
            }
        }
        let count = faults.count
        #expect(count == 0, "first: \(faults.first ?? "")")
    }

    /// Known gap (docs/DECISIONS.md, "Get Attention and Stop on Home",
    /// *Fewer than three everyday categories*): a cell with no category
    /// holds nothing, so where the cell under Stop's well is empty, a look
    /// still resting where Stop was meets what is above the well. The cell
    /// under the well holds the first category in the band, the third in
    /// three columns and the second in two, so three everyday categories
    /// are safe everywhere. No screen can remove a category yet; the
    /// editing thread answers this before one can. Fails if a library of
    /// three or more stops being safe, and, strict, once fewer are safe too.
    @Test func aLibraryOfFewerThanThreeEverydayCategoriesLeavesTheWellUnsafe() {
        let safeFrom = 3
        var unsafe: [(count: Int, context: String)] = []
        for (layout, _, context) in Self.everyLayout {
            let stop = layout.frame(.stop)
            for count in 0...HomeLayout.categoryCapacity {
                let shown = Nearest.controls(in: layout, excluding: [.stop]).filter { slot, _ in
                    if case .category(let index) = slot { return index < count }
                    return true
                }
                let met = Nearest.to(CGPoint(x: stop.midX, y: stop.midY), among: shown)
                if !met.isSubset(of: Self.categories) || met.isEmpty {
                    unsafe.append((count, "\(count) categories, \(context)"))
                }
            }
        }
        // Counts, not the lists, in the expectations: a failure prints what
        // it compared, and the lists run to thousands of layouts.
        let unexpected = unsafe.filter { $0.count >= safeFrom }
        let unexpectedCount = unexpected.count
        #expect(unexpectedCount == 0, "first: \(unexpected.first?.context ?? "")")
        let unsafeCount = unsafe.count
        withKnownIssue("docs/DECISIONS.md, \"Get Attention and Stop on Home\": fewer than three everyday categories") {
            #expect(unsafeCount == 0, "first: \(unsafe.first?.context ?? "")")
        }
    }

    /// Phrases and Type only choose a mode, and each keeps its frame once
    /// chosen. After either, the nearest other control never speaks, never
    /// raises or ends the alarm: Phrases or Type, or, on short windows at
    /// large text sizes where Type is taller than the gap below it,
    /// Emergency, which only shows the emergency phrases.
    @Test func aHeldLookAfterPhrasesOrTypeMeetsNothingHarmful() {
        let harmful = Self.speaks.union([.getAttention, .stop])
        var faults: [String] = []
        for (layout, _, context) in Self.everyLayout where layout.modes == .phrasesAndTyping {
            for slot in [HomeLayout.Slot.phrases, .type] {
                let met = Nearest.after(slot, in: layout)
                if met.isEmpty || !met.isDisjoint(with: harmful) {
                    faults.append("\(met) after \(slot) (\(context))")
                }
            }
        }
        let count = faults.count
        #expect(count == 0, "first: \(faults.first ?? "")")
    }

    /// A look resting anywhere on the message or its status line never
    /// meets Get Attention or Stop, by either rule.
    @Test func aLookOnTheMessageNeverMeetsTheAlarm() {
        var faults: [String] = []
        for (layout, _, context) in Self.everyLayout {
            let controls = Nearest.controls(in: layout)
            for point in Nearest.points(in: layout.frame(.message).union(layout.frame(.statusLine))) {
                let met = Nearest.to(point, among: controls)
                if met.contains(.getAttention) || met.contains(.stop) {
                    faults.append("\(met) from \(point) (\(context))")
                    break
                }
            }
        }
        let count = faults.count
        #expect(count == 0, "first: \(faults.first ?? "")")
    }

    /// Known hazard, open (docs/DECISIONS.md, "Home's slot plan", *Open
    /// hazard, not accepted: Yes and No border the message*): a look
    /// resting on the message can meet Yes or No, which speak. Without
    /// typing, as Home is today, the message spans the width and Yes and
    /// No are under its leading half: about 56% of it by centre, 50% by
    /// edge, as before the engine. With Phrases and Type beside the
    /// message, as the slot plan has them, Yes and No are under nearly all
    /// of it on compact widths, and under two of its three columns on
    /// regular ones. The worst shares are pinned here, for the owner to
    /// accept or reject (docs/work/layout-engine.md, *Spec*). Fails if a
    /// layout's share grows past them, and, strict, once no point of the
    /// message is nearest a control that speaks.
    @Test(arguments: bothModes)
    func yesAndNoStillBorderTheMessage(modes: HomeLayout.Modes) {
        var worst = (compact: (centre: 0.0, edge: 0.0), regular: (centre: 0.0, edge: 0.0))
        // The message's frame follows the width and the text, not the
        // height: one window height covers it.
        for (layout, _, _) in Self.everyLayout where layout.content.height == 874 - 16 && layout.modes == modes {
            let share = Nearest.speakingShare(of: layout)
            if layout.isRegular {
                worst.regular = (max(share.centre, worst.regular.centre), max(share.edge, worst.regular.edge))
            } else {
                worst.compact = (max(share.centre, worst.compact.centre), max(share.edge, worst.compact.edge))
            }
        }
        let pinned = modes == .phrasesOnly
            ? (compact: (centre: 0.57, edge: 0.51), regular: (centre: 0.57, edge: 0.51))
            : (compact: (centre: 0.97, edge: 0.89), regular: (centre: 0.68, edge: 0.62))
        #expect(worst.compact.centre <= pinned.compact.centre && worst.compact.edge <= pinned.compact.edge, "\(worst.compact)")
        #expect(worst.regular.centre <= pinned.regular.centre && worst.regular.edge <= pinned.regular.edge, "\(worst.regular)")
        withKnownIssue("docs/DECISIONS.md, \"Home's slot plan\": Yes and No border the message") {
            #expect(worst.compact.centre == 0 && worst.regular.centre == 0 && worst.compact.edge == 0 && worst.regular.edge == 0)
        }
    }

    /// Known hazard (docs/DECISIONS.md, "Get Attention and Stop on Home",
    /// *Open: the top of Stop's well is nearest Again*): with Get Attention
    /// under Emergency, Again is the control above Stop's well, as it was
    /// before the engine, on every width without typing and on compact
    /// widths with it. Yes, two rows up, is never nearest any point of it
    /// (`HomeLayout.wellDrop`). In the slot plan's one-row safety row
    /// Emergency is above the well, and nothing that speaks is nearest any
    /// point of it. Fails if anything else is ever nearest a point of the
    /// well, Yes included, if the one-row safety row meets Again, and,
    /// strict, once the others do not.
    @Test func theTopOfStopsWellIsNearestAgainUnlessEmergencyIsAboveIt() {
        var meetsAgain = 0
        var faults: [String] = []
        for (layout, _, context) in Self.everyLayout {
            let others = Nearest.controls(in: layout, excluding: [.stop])
            let allowed: Set<HomeLayout.Slot> = Self.emergencyIsAboveTheWell(layout) ? [.emergency] : [.again]
            var again = false
            for point in Nearest.points(in: layout.frame(.stop)) {
                let met = Nearest.to(point, among: others).subtracting(Self.categories)
                if !met.isSubset(of: allowed) {
                    faults.append("\(met) from \(point) in Stop's well (\(context))")
                }
                again = again || met.contains(.again)
            }
            if again {
                meetsAgain += 1
            }
        }
        let count = faults.count
        #expect(count == 0, "first: \(faults.first ?? "")")
        withKnownIssue("docs/DECISIONS.md, \"Get Attention and Stop on Home\": the top of Stop's well is nearest Again") {
            #expect(meetsAgain == 0)
        }
    }

    /// Fails if Yes is nearest, ties counted, any point of the top edge of
    /// Stop's well, taken every tenth of a point, where Yes comes nearest
    /// the well: the points the other checks take, a few points apart,
    /// can fall either side of one. On PR #52, a 1356×568 window at AX5
    /// left Yes 0.36 points from the nearest at one point of the edge
    /// while the engine checked the well every 4 points.
    @Test func noPointOfTheTopOfStopsWellIsNearestYes() {
        var faults: [String] = []
        for (layout, _, context) in Self.everyLayout where !Self.emergencyIsAboveTheWell(layout) {
            let others = Nearest.controls(in: layout, excluding: [.stop])
            let well = layout.frame(.stop), yes = layout.frame(.yes)
            let under = Self.categories.map(layout.frame)
                .filter { abs($0.minX - well.minX) < 0.01 && $0.minY > well.maxY }
                .min { $0.minY < $1.minY }
            let rivals = [layout.frame(.again)] + (under.map { [$0] } ?? [])
            // Yes is met only where it comes within a tie of the nearer of
            // Again and the category under the well, by one rule or the
            // other. That margin changes by at most 2 points for each point
            // along the edge, so only the points within half a point of one
            // where it is under a tie and a point need taking every tenth of
            // a point.
            func margin(_ point: CGPoint) -> CGFloat {
                NearestRule.allCases.map { rule in
                    rule.distance(from: point, to: yes) - (rivals.map { rule.distance(from: point, to: $0) }.min() ?? .infinity)
                }.min() ?? .infinity
            }
            let samples = Int(well.width.rounded(.up))
            scan: for sample in 0...samples {
                let coarse = well.minX + well.width * CGFloat(sample) / CGFloat(samples)
                guard margin(CGPoint(x: coarse, y: well.minY)) <= ChainEngine.tie + 1 else { continue }
                for x in stride(from: max(well.minX, coarse - 0.5), through: min(well.maxX, coarse + 0.5), by: 0.1) {
                    let point = CGPoint(x: x, y: well.minY)
                    if margin(point) <= ChainEngine.tie && Nearest.to(point, among: others).contains(.yes) {
                        faults.append("Yes from \(point) (\(context))")
                        break scan
                    }
                }
            }
        }
        let count = faults.count
        #expect(count == 0, "first: \(faults.first ?? "")")
    }

    /// Fails if a look resting in Stop's empty well can meet Yes where the
    /// safety row is short: on PR #52, in a 400×568 window at the default
    /// size without typing, the well's top leading corner was nearest Yes
    /// by centre, until the categories sat lower there. Fails too if the
    /// categories sit lower on a phone or a full-screen iPad (the fit
    /// table's windows) other than by the drops pinned below, or if the
    /// room the drop takes leaves a library that fits scrolling.
    @Test func theCategoriesSitLowerOnlyWhereYesWouldReachStopsWell() {
        let found = HomeLayout(space: .init(size: CGSize(width: 400, height: 568)), text: Self.defaultText, modes: .phrasesOnly)
        let well = found.frame(.stop)
        let corner = CGPoint(x: well.minX + 0.5, y: well.minY + 0.5)
        #expect(found.wellDrop > 0)
        #expect(!Nearest.to(corner, among: Nearest.controls(in: found, excluding: [.stop])).contains(.yes))
        // The 375×667 phone with Phrases and Type, whose safety row is at its
        // 44pt floor there (docs/DECISIONS.md, "Typing on Home").
        let knownDrops: [String: CGFloat] = [
            "375×667 phone, default, Bold Text false, phrasesAndTyping": 0.5,
            "375×667 phone, default, Bold Text true, phrasesAndTyping": 5.5,
            "375×667 phone, xxxLarge, Bold Text true, phrasesAndTyping": 4,
        ]
        for window in Self.windows {
            let space = HomeLayout.Space(size: window.size, safeArea: .init(top: window.top, leading: 0, bottom: window.bottom, trailing: 0))
            for (name, plain) in Self.textSizes {
                for boldText in [false, true] {
                    for modes in Self.bothModes {
                        let layout = HomeLayout(space: space, text: boldText ? Self.bold(plain) : plain, modes: modes)
                        let context = "\(window.name), \(name), Bold Text \(boldText), \(modes)"
                        #expect(layout.wellDrop == knownDrops[context] ?? 0, "\(context)")
                    }
                }
            }
        }
        var faults: [String] = []
        for (layout, _, context) in Self.everyLayout where layout.startersFit && layout.grid.scrolls {
            faults.append("drop \(layout.wellDrop) (\(context))")
        }
        let count = faults.count
        #expect(count == 0, "first: \(faults.first ?? "")")
    }

    // MARK: Chains of held activations

    /// Home's map for the chain engine on the layout engine's frames
    /// (`HomeChains`), with Phrases and Type where the layout has them.
    /// Without `typing`, Type leads to typing, which the map does not have,
    /// so a chain stops there. With it, the map has typing too, and every
    /// state but typing has the largest category's tiles, as many as show
    /// without scrolling: a look resting on the empty grid while typing
    /// must not meet a control that fills the grid with phrases under it.
    static func chainMap(_ layout: HomeLayout, typing: Bool = false) -> ChainMap {
        let categories = (0..<HomeLayout.categoryCapacity).map { (name: "category \($0 + 1)", frame: layout.frame(.category($0))) }
        let hasModes = layout.modes == .phrasesAndTyping
        var tiles: [CGRect] = []
        if typing {
            let grid = layout.grid
            for index in 0..<HomeLayout.referencePhraseCount {
                let tile = grid.tile(row: index / grid.columns, column: index % grid.columns)
                if tile.minY < grid.frame.maxY { tiles.append(tile) }
            }
        }
        return HomeChains.map(HomeChains.Frames(
            yes: layout.frame(.yes), no: layout.frame(.no), emergency: layout.frame(.emergency), again: layout.frame(.again),
            getAttention: layout.frame(.getAttention), stop: layout.frame(.stop), settings: layout.frame(.settings),
            categories: categories, tiles: tiles,
            phrases: hasModes ? layout.frame(.phrases) : nil, type: hasModes ? layout.frame(.type) : nil,
            typing: typing && hasModes ? HomeChains.Typing(
                field: layout.frame(.message), clearCell: layout.typingCells.clear, putBackCell: layout.typingCells.putBack,
                grid: layout.frame(.phraseGrid)
            ) : nil
        ))
    }

    /// Fails if a chain of held activations on the engine's frames meets
    /// anything that speaks, alarms, changes data or moves things unasked,
    /// in any of Home's states, from any control a person chooses or any
    /// place a look rests, by nearest centre or nearest edge, with the
    /// pointer staying on the control or going back to the look
    /// (`ChainEngine`). Scores widths every 16pt and both sides of each
    /// change of arrangement, at a phone's and an iPad's height, at three
    /// text sizes, in both modes.
    ///
    /// One finding is known, wherever Again is above Stop's well (the tests
    /// above): a look resting in the well, empty or after choosing Stop,
    /// can meet Again, sometimes after choosing a category on the way.
    /// Anything else fails, Yes from the well included, and so does that
    /// finding where Emergency is above the well; strict, so it fails once
    /// it is gone everywhere.
    @Test(arguments: [false, true])
    func noChainOnTheEnginesFramesMeetsAHazardButStopsWell(boldText: Bool) {
        var known = 0
        var unexpected: [String] = []
        for modes in Self.bothModes {
            for (name, text) in [("default", Self.defaultText), ("xxxLarge", Self.largerText), ("AX5", Self.largestText)] {
                let text = boldText ? Self.bold(text) : text
                for height: CGFloat in [874, 1376] {
                    func layout(_ width: CGFloat) -> HomeLayout {
                        HomeLayout(space: .init(size: CGSize(width: width, height: height)), text: text, modes: modes)
                    }
                    for width in Self.chainWidths(layout) {
                        let layout = layout(width)
                        let context = "\(width)×\(height), \(name), Bold Text \(boldText), \(modes)"
                        let map = Self.chainMap(layout)
                        for finding in ChainFinding.findings(in: map.hazards(from: map.everyStart())) {
                            let start = finding.example.start
                            let fromTheWell = start.chosen?.name == HomeChains.stop || start.restingOn == HomeChains.emptyWell
                            let met = finding.example.hazard?.control.name
                            if !Self.emergencyIsAboveTheWell(layout) && fromTheWell && met == HomeChains.again {
                                known += 1
                            } else {
                                unexpected.append("\(finding) (\(context))")
                            }
                        }
                    }
                }
            }
        }
        // Counts, not the lists, in the expectations (see above).
        let unexpectedCount = unexpected.count
        #expect(unexpectedCount == 0, "first: \(unexpected.first ?? "")")
        withKnownIssue("docs/DECISIONS.md, \"Get Attention and Stop on Home\": the top of Stop's well is nearest Again") {
            #expect(known == 0)
        }
    }

    /// Typing on the engine's frames (docs/DECISIONS.md, "Typing on
    /// Home"): every Home state, typing with the draft empty, written or
    /// cleared included, scored as above, with the empty phrase grid a place
    /// a look rests on, sampled every 4 points half a point under its top
    /// edge as well as across it. Fewer widths than above (every 32pt, and
    /// both sides of each change of arrangement): there are six times the
    /// states.
    ///
    /// Two findings are known. Stop's well's, as above, where Speak, in
    /// Again's slot while typing, is what the well's top meets. And a look
    /// resting on the empty grid can meet Clear or Put Back, which border it
    /// on every arrangement: no pair of category cells keeps both away from
    /// it and from Stop's neighbours (`HomeLayout.typingCells`). Anything
    /// else fails: a category that left typing and filled the grid with
    /// phrases under the look, a phrase, Yes, No or the alarm. Strict, so
    /// it fails once the grid's finding is gone.
    @Test(arguments: [false, true])
    func typingChainsMeetOnlyTheEmptyGridsClearAndPutBack(boldText: Bool) {
        var known = 0
        var unexpected: [String] = []
        for (name, text) in [("default", Self.defaultText), ("xxxLarge", Self.largerText), ("AX5", Self.largestText)] {
            let text = boldText ? Self.bold(text) : text
            for height: CGFloat in [874, 1376] {
                func layout(_ width: CGFloat) -> HomeLayout {
                    HomeLayout(space: .init(size: CGSize(width: width, height: height)), text: text, modes: .phrasesAndTyping)
                }
                let boundaries = Self.chainWidths(layout).filter { $0.truncatingRemainder(dividingBy: 16) != 0 }
                for width in Set(stride(from: CGFloat(320), through: 1432, by: 32)).union(boundaries).sorted() {
                    let layout = layout(width)
                    let context = "\(width)×\(height), \(name), Bold Text \(boldText)"
                    let map = Self.chainMap(layout, typing: true)
                    let grid = layout.frame(.phraseGrid)
                    let starts = map.everyStart { frame in
                        let across = ChainEngine.points(across: frame, columns: 2, rows: 2)
                        guard frame == grid else { return across }
                        return across + stride(from: grid.minX + 0.5, through: grid.maxX - 0.5, by: 4).map { CGPoint(x: $0, y: grid.minY + 0.5) }
                    }
                    for finding in ChainFinding.findings(in: map.hazards(from: starts)) {
                        let start = finding.example.start
                        let fromTheWell = start.chosen?.name == HomeChains.stop || start.restingOn == HomeChains.emptyWell
                        let fromTheGrid = start.restingOn == HomeChains.emptyGrid
                        let met = finding.example.hazard?.control.name
                        if !Self.emergencyIsAboveTheWell(layout) && fromTheWell && (met == HomeChains.again || met == HomeChains.speak) {
                            continue
                        } else if fromTheGrid && (met == HomeChains.clear || met == HomeChains.putBack) {
                            known += 1
                        } else {
                            unexpected.append("\(finding) (\(context))")
                        }
                    }
                }
            }
        }
        let unexpectedCount = unexpected.count
        #expect(unexpectedCount == 0, "first: \(unexpected.first ?? "")")
        withKnownIssue("docs/DECISIONS.md, \"Typing on Home\": the empty phrase grid borders Clear and Put Back") {
            #expect(known == 0)
        }
    }

    /// Window widths for chain scoring: every 16pt from 320 to 1432, and
    /// both sides of each width where the arrangement, the categories'
    /// arrangement, Settings' word or the grid's columns change. Following
    /// every chain takes far longer than laying out, so not every 4 points.
    private static func chainWidths(_ layout: (CGFloat) -> HomeLayout) -> [CGFloat] {
        var widths = Set(stride(from: CGFloat(320), through: 1432, by: 16))
        var previous: (width: CGFloat, layout: HomeLayout)?
        for width in stride(from: CGFloat(320), through: 1432, by: 1) {
            let current = layout(width)
            if let previous,
               previous.layout.isRegular != current.isRegular
               || previous.layout.categoryArrangement != current.categoryArrangement
               || previous.layout.settingsShowsName != current.settingsShowsName {
                widths.insert(previous.width)
                widths.insert(width)
            }
            previous = (width, current)
        }
        return widths.sorted()
    }

    // MARK: The keyboard

    /// The band rule (docs/DECISIONS.md, "Typing is a state of Home"): on
    /// the windows `KeyboardProbeTests` measures, the message, Phrases and
    /// Type where Home has them, and the whole safety row end above the
    /// keyboard's room, at the default and the largest text size, in both
    /// modes (the probe checks Home's safety row today, before typing).
    /// Safe areas: CI's iPhone 17 (62 above, 34 below) and 13-inch iPad (32
    /// and 20, from CI's frames).
    @Test(arguments: [defaultText, largestText])
    func theSafetyRowEndsAboveTheKeyboard(text: HomeLayout.Text) {
        let windows: [(CGSize, HomeLayout.Insets)] = [
            (CGSize(width: 402, height: 874), .init(top: 62, leading: 0, bottom: 34, trailing: 0)),
            (CGSize(width: 1032, height: 1376), .init(top: 32, leading: 0, bottom: 20, trailing: 0)),
            (CGSize(width: 1376, height: 1032), .init(top: 32, leading: 0, bottom: 20, trailing: 0)),
        ]
        for modes in Self.bothModes {
            for (size, safeArea) in windows {
                let layout = HomeLayout(space: .init(size: size, safeArea: safeArea), text: text, modes: modes)
                #expect(layout.bandClearsKeyboard, "\(size), \(modes)")
                let band: [HomeLayout.Slot] = [.yes, .no, .emergency, .again, .getAttention, .type]
                let bottom = band.filter(layout.slots.contains).map { layout.frame($0).maxY }.max() ?? 0
                #expect(bottom <= layout.keyboard.bandLimit + 0.001, "\(size), \(modes): \(bottom) against \(layout.keyboard.bandLimit)")
            }
        }
    }

    /// Fails if growth carries the slot plan's safety row into the
    /// keyboard's room on a short wide window where its floors fit above
    /// it: the 13-inch iPad in landscape with Display Zoom set to Larger
    /// Text (1032 × 774, limit 276), with text about as large as the second
    /// accessibility size, where the safety row at today's 88 points would
    /// end at 287. It gives back what it grew, and the categories stay no
    /// taller than it.
    @Test func growthStopsAtTheKeyboard() {
        let text = HomeLayout.Text(quickControlLine: 46, categoryLine: 41, messageLine: 53, statusLine: 37)
        let layout = HomeLayout(
            space: .init(size: CGSize(width: 1032, height: 774), safeArea: .init(top: 32, leading: 0, bottom: 20, trailing: 0)),
            text: text, modes: .phrasesAndTyping
        )
        #expect(layout.isRegular)
        #expect(layout.keyboard.bandLimit == 276)
        #expect(layout.bandClearsKeyboard)
        #expect(abs(layout.frame(.yes).maxY - 276) < 0.001)
        #expect(layout.quickControlHeight < 88 && layout.quickControlHeight >= text.quickControlLine + 2 * HomeLayout.labelInset.vertical)
        #expect(layout.categoryHeight <= layout.quickControlHeight)
    }

    /// Without typing nothing on Home opens the keyboard, so the safety row
    /// keeps today's sizes where the window has room for them: on the same
    /// zoomed iPad, and on an iPad mini in landscape, it grows to 88 points
    /// and ends in the keyboard's room. Fails if the keyboard's room takes
    /// any of that back.
    @Test func withoutTypingNothingIsGivenBackForTheKeyboard() {
        let safeArea = HomeLayout.Insets(top: 32, leading: 0, bottom: 20, trailing: 0)
        for size in [CGSize(width: 1032, height: 774), CGSize(width: 1133, height: 744)] {
            let layout = HomeLayout(space: .init(size: size, safeArea: safeArea), text: Self.defaultText, modes: .phrasesOnly)
            #expect(layout.quickControlHeight == 88 && layout.regionGap == HomeLayout.regionSpacing, "\(size)")
            #expect(!layout.bandClearsKeyboard && layout.startersFit, "\(size)")
        }
    }

    /// Fails if a category is ever taller than the safety row's controls:
    /// the row stays the larger target, and the category under Stop's well
    /// stays nearer the well than the control above it.
    @Test func aCategoryIsNeverTallerThanTheSafetyRow() {
        var faults: [String] = []
        for (layout, _, context) in Self.everyLayout where layout.categoryHeight > layout.quickControlHeight + 0.001 {
            faults.append("categories \(layout.categoryHeight), safety row \(layout.quickControlHeight) (\(context))")
        }
        let count = faults.count
        #expect(count == 0, "first: \(faults.first ?? "")")
    }

    /// Known limit (docs/DECISIONS.md, "Typing is a state of Home"): on the
    /// same zoomed iPad at AX5 even the floors end below the keyboard's
    /// room. Fails, strict, once they fit.
    @Test func theZoomedIPadAtTheLargestTextSizeMeetsTheKeyboard() {
        let layout = HomeLayout(
            space: .init(size: CGSize(width: 1032, height: 774), safeArea: .init(top: 32, leading: 0, bottom: 20, trailing: 0)),
            text: Self.largestText, modes: .phrasesAndTyping
        )
        // At its floor: one line of the words with the label's inset.
        #expect(layout.quickControlHeight == Self.largestText.quickControlLine + 2 * HomeLayout.labelInset.vertical)
        withKnownIssue("docs/DECISIONS.md, \"Typing is a state of Home\": the zoomed 13-inch iPad at the largest text sizes") {
            #expect(layout.bandClearsKeyboard)
        }
    }

    // MARK: The windows people use

    /// A full-screen window and how far up the text sizes it holds the
    /// starter library without scrolling, with Bold Text off and on, as
    /// Home is today (`home`, without typing) and in the slot plan's own
    /// arrangement (`slotPlan`), and how far up the slot plan keeps the
    /// safety row above the keyboard's room: an index into `textSizes`, or
    /// nil for none.
    struct Window: Sendable {
        let name: String
        let size: CGSize
        let top: CGFloat
        let bottom: CGFloat
        let home: (plain: Int?, bold: Int?)
        let slotPlan: (plain: Int?, bold: Int?)
        let keyboardClearThrough: Int?
    }

    /// Phones in portrait (the only orientation an iPhone runs Brickson
    /// in), from the largest to Display Zoom's Larger Text on a 375×667
    /// phone, and iPads in both orientations, with Display Zoom's Larger
    /// Text on the 13-inch in landscape. Safe areas: CI's iPhone 17 and
    /// 13-inch iPad frames, Apple's for the other phones.
    /// docs/DECISIONS.md, "The layout engine", *Where the starter library
    /// fits*, has the table this pins.
    nonisolated static let windows: [Window] = [
        Window(name: "iPhone 17", size: CGSize(width: 402, height: 874), top: 62, bottom: 34, home: (3, 2), slotPlan: (3, 2), keyboardClearThrough: 4),
        Window(name: "iPhone 17 Pro Max", size: CGSize(width: 440, height: 956), top: 62, bottom: 34, home: (4, 4), slotPlan: (4, 4), keyboardClearThrough: 4),
        Window(name: "iPhone 16e", size: CGSize(width: 390, height: 844), top: 47, bottom: 34, home: (3, 3), slotPlan: (3, 3), keyboardClearThrough: 4),
        Window(name: "375×667 phone", size: CGSize(width: 375, height: 667), top: 20, bottom: 0, home: (0, nil), slotPlan: (nil, nil), keyboardClearThrough: 2),
        Window(name: "375×667 phone, zoomed", size: CGSize(width: 320, height: 568), top: 20, bottom: 0, home: (nil, nil), slotPlan: (nil, nil), keyboardClearThrough: nil),
        Window(name: "13-inch iPad", size: CGSize(width: 1032, height: 1376), top: 32, bottom: 20, home: (4, 4), slotPlan: (4, 4), keyboardClearThrough: 4),
        Window(name: "13-inch iPad, landscape", size: CGSize(width: 1376, height: 1032), top: 32, bottom: 20, home: (4, 4), slotPlan: (4, 4), keyboardClearThrough: 4),
        Window(name: "13-inch iPad, landscape, zoomed", size: CGSize(width: 1032, height: 774), top: 32, bottom: 20, home: (3, 3), slotPlan: (4, 4), keyboardClearThrough: 2),
        Window(name: "11-inch iPad", size: CGSize(width: 834, height: 1210), top: 32, bottom: 20, home: (4, 4), slotPlan: (4, 4), keyboardClearThrough: 4),
        Window(name: "11-inch iPad, landscape", size: CGSize(width: 1210, height: 834), top: 32, bottom: 20, home: (4, 4), slotPlan: (4, 4), keyboardClearThrough: 4),
        Window(name: "iPad mini", size: CGSize(width: 744, height: 1133), top: 32, bottom: 20, home: (4, 4), slotPlan: (4, 4), keyboardClearThrough: 4),
        Window(name: "iPad mini, landscape", size: CGSize(width: 1133, height: 744), top: 32, bottom: 20, home: (3, 3), slotPlan: (4, 4), keyboardClearThrough: 2),
    ]

    /// Where the starter library fits without scrolling on each window at
    /// each text size, in both modes, and where the slot plan keeps the
    /// safety row above the keyboard. Fails if a window that fits stops
    /// fitting, and, strict, once one that does not starts to
    /// (docs/DECISIONS.md, "The layout engine", *Where the starter library
    /// fits*): update the table and the decision then.
    @Test(arguments: windows.indices)
    func theStarterLibraryFitsWhereTheTableSays(window index: Int) {
        let window = Self.windows[index]
        let space = HomeLayout.Space(size: window.size, safeArea: .init(top: window.top, leading: 0, bottom: window.bottom, trailing: 0))
        for (sizeIndex, (name, plain)) in Self.textSizes.enumerated() {
            for boldText in [false, true] {
                let text = boldText ? Self.bold(plain) : plain
                for modes in Self.bothModes {
                    let layout = HomeLayout(space: space, text: text, modes: modes)
                    let context = "\(window.name), \(name), Bold Text \(boldText), \(modes)"
                    let fits = modes == .phrasesOnly ? window.home : window.slotPlan
                    if let through = boldText ? fits.bold : fits.plain, sizeIndex <= through {
                        #expect(layout.startersFit && !layout.grid.scrolls, "\(context): \(layout.shortfall)pt short")
                    } else {
                        withKnownIssue("docs/DECISIONS.md, \"The layout engine\": where the starter library fits") {
                            #expect(layout.startersFit, "\(context)")
                        }
                    }
                    guard modes == .phrasesAndTyping else { continue }
                    if let clear = window.keyboardClearThrough, sizeIndex <= clear {
                        #expect(layout.bandClearsKeyboard, "\(context)")
                    } else {
                        withKnownIssue("docs/DECISIONS.md, \"Typing is a state of Home\": the keyboard on short windows at large text sizes") {
                            #expect(layout.bandClearsKeyboard, "\(context)")
                        }
                    }
                }
            }
        }
    }

    // MARK: Growth and the library

    /// Fails if a window short of room keeps today's sizes and lets the
    /// starter library scroll, or a window with room leaves a control at
    /// its floor: the gaps grow first, then the safety row, then the
    /// categories, and the grid takes the rest.
    @Test func roomGoesToTheGapsThenTheSafetyRowThenTheCategories() {
        let smallSpace = HomeLayout.Space(size: CGSize(width: 375, height: 667), safeArea: .init(top: 20, leading: 0, bottom: 0, trailing: 0))
        // A 375×667 phone at the default size without typing: room for
        // the starter library with every control at its floor, and three
        // points more, which the gaps take.
        let today = HomeLayout(space: smallSpace, text: Self.defaultText, modes: .phrasesOnly)
        #expect(today.startersFit && !today.grid.scrolls)
        #expect(abs(today.regionGap - (HomeLayout.minimumRegionSpacing + 1)) < 0.001)
        #expect(today.quickControlHeight == 44 && today.categoryHeight == 44)
        #expect(today.grid.tileSize.height == today.grid.tileFloor)
        // With Phrases and Type the message's region is three points
        // taller, two controls at their floor, and the categories sit half
        // a point lower to keep Yes off Stop's well: the library is half a
        // point short, and nothing grows (docs/DECISIONS.md, "Typing on
        // Home"). Get Attention keeps one line beside the message.
        let small = HomeLayout(space: smallSpace, text: Self.defaultText, modes: .phrasesAndTyping)
        #expect(!small.startersFit && small.grid.scrolls)
        #expect(abs(small.shortfall - 0.5) < 0.001 && small.wellDrop == 0.5)
        #expect(small.regionGap == HomeLayout.minimumRegionSpacing)
        #expect(small.quickControlHeight == 44 && small.categoryHeight == 44 && small.frame(.phrases).height == 44)
        for modes in Self.bothModes {
            // An iPhone 17: room for today's sizes, and taller tiles.
            let phone = HomeLayout(
                space: .init(size: CGSize(width: 402, height: 874), safeArea: .init(top: 62, leading: 0, bottom: 34, trailing: 0)),
                text: Self.defaultText, modes: modes
            )
            #expect(phone.regionGap == HomeLayout.regionSpacing)
            #expect(phone.quickControlHeight == 64 && phone.categoryHeight == 48)
            #expect(phone.grid.tileSize.height > phone.grid.tileFloor)
            // A 13-inch iPad in portrait: today's wide sizes.
            let pad = HomeLayout(
                space: .init(size: CGSize(width: 1032, height: 1376), safeArea: .init(top: 32, leading: 0, bottom: 20, trailing: 0)),
                text: Self.defaultText, modes: modes
            )
            #expect(pad.quickControlHeight == 88 && pad.categoryHeight == 72)
        }
    }

    /// Fails if the controls' frames follow the library: only the phrase
    /// grid's rows do. A library with more phrases than the starter
    /// library's largest category scrolls at the tiles' floor, never below
    /// it; one with fewer gets taller tiles.
    @Test func onlyTheGridFollowsTheLibrary() {
        for (base, text, context) in Self.everyLayout where base.content.height == 874 - 16 {
            let space = HomeLayout.Space(size: CGSize(width: base.content.width + 32, height: 874))
            for count in [0, 1, 8, 9, 12, 40] {
                let other = HomeLayout(space: space, text: text, largestCategory: count, modes: base.modes)
                let moved = base.slots.filter { $0 != .phraseGrid && other.frame($0) != base.frame($0) }
                #expect(moved.isEmpty, "\(moved) moved for \(count) phrases (\(context))")
                #expect(other.frame(.phraseGrid) == base.frame(.phraseGrid))
                #expect(other.grid.rows == HomeLayout.Grid.rows(for: count, columns: base.grid.columns))
                let floor = base.grid.tileFloor
                #expect(other.grid.tileSize.height >= floor, "\(count) phrases (\(context))")
                if count > HomeLayout.referencePhraseCount && other.grid.scrolls {
                    #expect(other.grid.tileSize.height == floor, "\(count) phrases (\(context))")
                }
                if count < HomeLayout.referencePhraseCount && base.startersFit {
                    #expect(other.grid.tileSize.height >= base.grid.tileSize.height, "\(count) phrases (\(context))")
                }
            }
        }
    }

    /// Fails if tiles shrink below their floor instead of the grid
    /// scrolling, or a grid with room scrolls, or the rows stop coming from
    /// the largest category: a tile keeps its place whichever category
    /// shows (invariant 8).
    @Test func tilesFillTheGridOrItScrollsAtTheFloor() {
        func grid(height: CGFloat, phrases: Int = 9) -> HomeLayout.Grid {
            HomeLayout.Grid(frame: CGRect(x: 0, y: 0, width: 300, height: height), columns: 3, phraseCount: phrases, tileFloor: 64, spacing: 12)
        }
        #expect(!grid(height: 400).scrolls && grid(height: 400).tileSize.height == 125)
        #expect(grid(height: 200).scrolls && grid(height: 200).tileSize.height == 64)
        let exact = grid(height: 3 * 64 + 2 * 12)
        #expect(!exact.scrolls && exact.tileSize.height == 64)
        #expect(HomeLayout.Grid.rows(for: 8, columns: 3) == 3 && HomeLayout.Grid.rows(for: 9, columns: 3) == 3)
        #expect(HomeLayout.Grid.rows(for: 10, columns: 3) == 4 && HomeLayout.Grid.rows(for: 0, columns: 3) == 1)
    }

    // MARK: Reserved regions

    /// Fails if a reserved region that crosses a slot goes unreported, or
    /// one in the margins is reported. How Home keeps clear of a fold is
    /// settled with the open iPhone Duo (docs/work/layout-engine.md).
    @Test(arguments: bothModes)
    func reservedRegionsAreReported(modes: HomeLayout.Modes) {
        let size = CGSize(width: 1032, height: 1376)
        let clear = HomeLayout(space: .init(size: size), text: Self.defaultText, modes: modes)
        #expect(clear.slotsInReservedRegions.isEmpty)
        let fold = CGRect(x: 512, y: 0, width: 8, height: 1376)
        let folded = HomeLayout(space: .init(size: size, reservedRegions: [fold]), text: Self.defaultText, modes: modes)
        let crossed = folded.slots.filter { folded.frame($0).minX < fold.maxX && folded.frame($0).maxX > fold.minX }
        #expect(folded.slotsInReservedRegions == Set(crossed))
        #expect(!crossed.isEmpty)
        let margin = CGRect(x: 0, y: 0, width: 8, height: 1376)
        #expect(HomeLayout(space: .init(size: size, reservedRegions: [margin]), text: Self.defaultText, modes: modes).slotsInReservedRegions.isEmpty)
    }

    /// Fails if the engine stops naming the starter library as fitting
    /// where only the floors leave it room, or claims it fits where they do
    /// not: a 568pt phone 320pt wide has far too little. Its safety row
    /// keeps the floor: 44 points without typing, and with typing the
    /// height of Get Attention's two lines in A's narrow trailing column.
    @Test(arguments: bothModes)
    func theShortfallIsReported(modes: HomeLayout.Modes) {
        let zoomed = HomeLayout(
            space: .init(size: CGSize(width: 320, height: 568), safeArea: .init(top: 20, leading: 0, bottom: 0, trailing: 0)),
            text: Self.defaultText, modes: modes
        )
        #expect(!zoomed.startersFit && zoomed.shortfall > 100 && zoomed.grid.scrolls)
        #expect(zoomed.grid.tileSize.height == zoomed.grid.tileFloor)
        let floor: CGFloat = modes == .phrasesOnly ? 44 : HomeLayout.twoLineQuickControlHeight
        #expect(zoomed.quickControlHeight == floor && zoomed.regionGap == HomeLayout.minimumRegionSpacing)
    }
}

// MARK: - Helpers

private enum Below {
    /// The controls whose frames lie directly under `frame`: one control
    /// spacing below it, and across its centre.
    static func controls(under frame: CGRect, in layout: HomeLayout) -> Set<HomeLayout.Slot> {
        Set(layout.controls.filter { slot in
            let other = layout.frame(slot)
            return abs(other.minY - frame.maxY - HomeLayout.controlSpacing) < 0.01 && other.minX < frame.midX && other.maxX > frame.midX
        })
    }
}

/// What a resting look meets, by the chain engine's rules (`ChainEngine`;
/// docs/DECISIONS.md, "One chain engine for dwell safety"), so "nearest"
/// has one definition: the controls nearest a point by the distance to
/// their centre and by the distance to their nearest edge (zero inside
/// one), each with every control within half a point of the nearest
/// counted, because whether Snap to Item picks by centre or by edge is not
/// known yet (docs/HANDOFF.md, *Checks that need a real device*).
enum Nearest {
    /// The controls of `layout` a look can meet, less `excluded`.
    static func controls(in layout: HomeLayout, excluding excluded: Set<HomeLayout.Slot> = []) -> [HomeLayout.Slot: CGRect] {
        Dictionary(uniqueKeysWithValues: layout.controls.filter { !excluded.contains($0) }.map { ($0, layout.frame($0)) })
    }

    /// The controls nearest `point` by centre or by edge, ties counted.
    static func to(_ point: CGPoint, among controls: [HomeLayout.Slot: CGRect]) -> Set<HomeLayout.Slot> {
        let met = ChainEngine.nearest(to: point, among: controls)
        return met.byCentre.union(met.byEdge)
    }

    /// The nearest other controls to `slot`'s centre: where a held look
    /// lands after `slot` if the pointer does not stay on it.
    static func after(_ slot: HomeLayout.Slot, in layout: HomeLayout) -> Set<HomeLayout.Slot> {
        let frame = layout.frame(slot)
        return to(CGPoint(x: frame.midX, y: frame.midY), among: controls(in: layout, excluding: [slot]))
    }

    /// Points across `frame`, every eighth of its width and quarter of its
    /// height, half a point in from its edges.
    static func points(in frame: CGRect) -> [CGPoint] {
        ChainEngine.points(across: frame)
    }

    /// The share of points on the message and its status line, every 4
    /// points, whose nearest control speaks, by centre and by edge.
    static func speakingShare(of layout: HomeLayout) -> (centre: Double, edge: Double) {
        let block = layout.frame(.message).union(layout.frame(.statusLine))
        let speaks: Set<HomeLayout.Slot> = [.yes, .no, .again]
        let all = layout.controls
        let frames = all.map(layout.frame)
        let speaking = all.map { speaks.contains($0) }
        var total = 0, byCentre = 0, byEdge = 0
        for x in stride(from: block.minX + 2, to: block.maxX, by: 4) {
            for y in stride(from: block.minY + 2, to: block.maxY, by: 4) {
                let point = CGPoint(x: x, y: y)
                var centre = (index: 0, distance: CGFloat.infinity)
                var edge = (index: 0, distance: CGFloat.infinity)
                for index in frames.indices {
                    let toCentre = NearestRule.centre.distance(from: point, to: frames[index])
                    if toCentre < centre.distance { centre = (index, toCentre) }
                    let toEdge = NearestRule.edge.distance(from: point, to: frames[index])
                    if toEdge < edge.distance { edge = (index, toEdge) }
                }
                total += 1
                if speaking[centre.index] { byCentre += 1 }
                if speaking[edge.index] { byEdge += 1 }
            }
        }
        guard total > 0 else { return (0, 0) }
        return (Double(byCentre) / Double(total), Double(byEdge) / Double(total))
    }
}
