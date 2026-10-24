import Foundation
import Testing
@testable import Brickson

/// The layout engine's rules, checked on its frames at every width from the
/// narrowest window Home plans for to wider than any iPad, at window heights
/// from a 568pt phone to a 13-inch iPad in portrait, at the default and the
/// largest text sizes, with Bold Text off and on. Plain logic: no font is
/// measured here (`HomeLayoutEngineFontTests` checks the engine against the real
/// fonts and the windows people use).
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

    /// Every window from 320pt wide to 1432pt, every 4pt, at heights from
    /// a 568pt phone to a 13-inch iPad in portrait, with no safe areas, at
    /// three text sizes, with Bold Text off and on.
    static let everyLayout: [(layout: HomeLayout, text: HomeLayout.Text, context: String)] = {
        var layouts: [(HomeLayout, HomeLayout.Text, String)] = []
        for (name, text) in [("default", defaultText), ("xxxLarge", largerText), ("AX5", largestText)] {
            for boldText in [false, true] {
                let text = boldText ? bold(text) : text
                for height: CGFloat in [568, 667, 744, 874, 1032, 1376] {
                    for width in stride(from: CGFloat(320), through: 1432, by: 4) {
                        let layout = HomeLayout(space: .init(size: CGSize(width: width, height: height)), text: text)
                        layouts.append((layout, text, "\(width)×\(height), \(name), Bold Text \(boldText)"))
                    }
                }
            }
        }
        return layouts
    }()

    private static let speaks: Set<HomeLayout.Slot> = [.yes, .no, .again]
    private static let categories: Set<HomeLayout.Slot> = Set((0..<HomeLayout.categoryCapacity).map { .category($0) })

    // MARK: Regions and frames

    /// Fails if a layout loses a slot, or a slot leaves the content, or two
    /// controls come closer than the spacing between controls.
    @Test func everySlotIsInsideTheContentAndApart() {
        let spacing = HomeLayout.controlSpacing
        var faults: [String] = []
        for (layout, _, context) in Self.everyLayout {
            if layout.frames.count != HomeLayout.Slot.all.count {
                faults.append("\(layout.frames.count) slots (\(context))")
            }
            let content = layout.content.insetBy(dx: -0.01, dy: -0.01)
            for slot in HomeLayout.Slot.all {
                let frame = layout.frame(slot)
                if frame.isNull || frame.minX < content.minX || frame.maxX > content.maxX || frame.minY < content.minY {
                    faults.append("\(slot) at \(frame) leaves \(layout.content) (\(context))")
                }
            }
            let controls = HomeLayout.Slot.controls + [.message, .statusLine]
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
    /// than 2 points more than the gap between controls.
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
            for (upper, lower, name) in [(a, c, "A to C"), (c, b, "C to B"), (b, d, "B to D")] where abs(lower.minY - upper.maxY - gap) > 0.01 {
                faults.append("\(name): \(lower.minY - upper.maxY) apart, gap \(gap) (\(context))")
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
            let slots = HomeLayout.Slot.controls + [.message]
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
    /// points, or narrower than its words need, at any width.
    @Test func everyControlKeepsItsFloorAndItsWords() {
        var faults: [String] = []
        for (layout, text, context) in Self.everyLayout {
            let minimum = HomeLayout.MinimumWidths.forBoldText(text.boldText)
            for slot in HomeLayout.Slot.controls {
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
            for (slot, need) in needs where layout.frame(slot).width < need - 0.01 {
                faults.append("\(slot) is \(layout.frame(slot).width) wide, needs \(need) (\(context))")
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
    /// message is too narrow anywhere else, and, strict, once it is wide
    /// enough there too.
    @Test func theMessageHoldsItsWidestWordExceptOnTheNarrowestBoldWindows() {
        var faults: [String] = []
        var tooNarrow = 0
        for (layout, text, context) in Self.everyLayout {
            let minimum = HomeLayout.MinimumWidths.forBoldText(text.boldText).message
            if layout.messageHoldsItsWords != (layout.frame(.message).width >= minimum) {
                faults.append("messageHoldsItsWords disagrees with the frame (\(context))")
            }
            if !layout.messageHoldsItsWords {
                if text.boldText && !layout.isRegular && layout.content.width < 345 - 2 * HomeLayout.margins.horizontal {
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
        let insets = 2 * HomeLayout.labelInsetVertical
        for width: CGFloat in [320, 375, 402, 744, 1032, 1376] {
            let layout = HomeLayout(space: .init(size: CGSize(width: width, height: 874)), text: text)
            for slot in [HomeLayout.Slot.yes, .no, .emergency, .again, .getAttention, .phrases, .type] {
                #expect(layout.frame(slot).height >= text.quickControlLine + insets - 0.01, "\(slot) at \(width)pt")
            }
            for slot in [HomeLayout.Slot.stop, .settings] + Self.categories {
                #expect(layout.frame(slot).height >= text.categoryLine + insets - 0.01, "\(slot) at \(width)pt")
            }
            #expect(layout.frame(.message).height >= 2 * text.messageLine - 0.01, "two lines of the message at \(width)pt")
            #expect(layout.frame(.statusLine).height >= text.statusLine - 0.01, "the status line at \(width)pt")
        }
    }

    /// Fails if a measure the engine shares with today's stand-in drifts
    /// from it before Home moves onto the engine: the spacing, the label
    /// inset, the compact tile and the minimum widths both measure on CI
    /// (`StarterLabelFitTests`). Again's slot is wider, for "Speak".
    @Test func theSharedMeasuresMatchTheStandIn() {
        #expect(HomeLayout.controlSpacing == HomeShape.controlSpacing)
        #expect(HomeLayout.labelInsetVertical == HomeShape.labelInset.vertical)
        #expect(HomeLayout.compactTile.minimumWidth == HomeShape.minimumTileWidth)
        #expect(HomeLayout.compactTile.minimumHeight == HomeShape(contentWidth: HomeShape.narrowestContentWidth).minimumTileHeight)
        for boldText in [false, true] {
            let engine = HomeLayout.MinimumWidths.forBoldText(boldText)
            let standIn = HomeShape.MinimumWidths.forBoldText(boldText)
            #expect(engine.yesNo == standIn.yesNo && engine.emergency == standIn.emergency)
            #expect(engine.getAttention == standIn.getAttention && engine.category == standIn.category)
            #expect(engine.stop == standIn.stop && engine.settings == standIn.settings)
            #expect(engine.settingsSymbol == standIn.settingsSymbol)
            #expect(engine.again >= standIn.again)
        }
    }

    // MARK: The two arrangements

    /// Fails if a phone loses the compact arrangement, or a window that
    /// holds five columns of the widest words does not get the regular
    /// one, or the line between them moves off the widest words.
    @Test(arguments: [false, true])
    func theArrangementComesFromTheWidth(boldText: Bool) {
        let text = boldText ? Self.bold(Self.defaultText) : Self.defaultText
        let minimum = HomeLayout.MinimumWidths.forBoldText(boldText)
        let threshold = 5 * minimum.regularColumn + 4 * HomeLayout.controlSpacing + 2 * HomeLayout.margins.horizontal
        func layout(_ width: CGFloat) -> HomeLayout {
            HomeLayout(space: .init(size: CGSize(width: width, height: 1000)), text: text)
        }
        for width: CGFloat in [320, 375, 402, 440, 466] {
            #expect(!layout(width).isRegular, "\(width)pt")
        }
        #expect(layout(threshold).isRegular)
        #expect(!layout(threshold - 0.5).isRegular)
        for width: CGFloat in [744, 834, 1032, 1376] {
            #expect(layout(width).isRegular, "\(width)pt")
            #expect(layout(width).categoryArrangement == .band, "\(width)pt")
            #expect(layout(width).grid.columns == 4, "\(width)pt")
        }
        #expect(layout(375).categoryArrangement == .threeColumns)
        // Three columns of tiles where three hold "understand.": with Bold
        // Text, from a 402-point window.
        #expect(layout(375).grid.columns == (boldText ? 2 : 3))
        #expect(layout(402).grid.columns == 3)
        #expect(layout(320).categoryArrangement == .twoColumns)
        #expect(layout(320).grid.columns == 2)
    }

    /// The compact safety row: Yes, No and Emergency, then Again and Get
    /// Attention, Get Attention directly under Emergency, both under
    /// Phrases and Type (docs/DECISIONS.md, "Get Attention and Stop on
    /// Home"). Fails if Get Attention leaves the place under Emergency, or
    /// moves into the first row, where it would border the message.
    @Test func compactPutsGetAttentionDirectlyUnderEmergency() {
        for (layout, _, context) in Self.everyLayout where !layout.isRegular {
            let emergency = layout.frame(.emergency), getAttention = layout.frame(.getAttention)
            #expect(getAttention.minX == emergency.minX && getAttention.width == emergency.width, "\(context)")
            #expect(abs(getAttention.minY - emergency.maxY - HomeLayout.controlSpacing) < 0.01, "\(context)")
            #expect(layout.frame(.yes).minY == emergency.minY && layout.frame(.no).minY == emergency.minY, "\(context)")
            #expect(layout.frame(.again).minY == getAttention.minY, "\(context)")
            #expect(emergency.minX == layout.frame(.type).minX && emergency.width == layout.frame(.type).width, "\(context)")
        }
    }

    /// The regular safety row is the slot plan's own: one row, Emergency,
    /// Yes, No, Again, Get Attention, with the message over Emergency, Yes
    /// and No and Phrases and Type over Again and Get Attention. Fails if
    /// the order changes or a second row appears.
    @Test func regularPutsTheSafetyRowInOneRow() {
        for (layout, _, context) in Self.everyLayout where layout.isRegular {
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
        for (layout, _, context) in Self.everyLayout {
            let phrases = layout.frame(.phrases), type = layout.frame(.type), message = layout.frame(.message)
            #expect(phrases.minY == message.minY && phrases.minX > message.maxX, "\(context)")
            #expect(type.minX == phrases.minX && type.width == phrases.width && type.height == phrases.height, "\(context)")
            #expect(abs(type.minY - phrases.maxY - HomeLayout.controlSpacing) < 0.01, "\(context)")
            #expect(abs(type.maxY - layout.frame(.statusLine).maxY) < 0.01, "\(context)")
        }
    }

    /// Fails if Stop's well leaves the leading edge or loses the category
    /// directly under it, or, on regular widths, stops sitting directly
    /// under Emergency, as the slot plan puts it.
    @Test func stopHasACategoryDirectlyUnderIt() {
        for (layout, _, context) in Self.everyLayout {
            let stop = layout.frame(.stop)
            #expect(abs(stop.minX - layout.content.minX) < 0.01, "\(context)")
            let below = Below.controls(under: stop, in: layout)
            #expect(below.count == 1 && below.isSubset(of: Self.categories), "\(below) under Stop (\(context))")
            if layout.isRegular {
                let emergency = layout.frame(.emergency)
                #expect(emergency.minX == stop.minX && emergency.width == stop.width, "\(context)")
            }
        }
    }

    // MARK: What a held look meets next (invariant 10)

    /// After Get Attention it stays where it is, and the nearest other
    /// control, by nearest centre and by nearest edge, ties within half a
    /// point counted, is never Stop (a repeat would end the alarm) nor one
    /// that speaks. The same rules `HomeShapeTests` applies to today's Home.
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

    /// Phrases and Type only choose a mode, and each keeps its frame once
    /// chosen. After either, the nearest other control never speaks, never
    /// raises or ends the alarm: Phrases or Type, or, on short windows at
    /// large text sizes where Type is taller than the gap below it,
    /// Emergency, which only shows the emergency phrases.
    @Test func aHeldLookAfterPhrasesOrTypeMeetsNothingHarmful() {
        let harmful = Self.speaks.union([.getAttention, .stop])
        var faults: [String] = []
        for (layout, _, context) in Self.everyLayout {
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
    /// resting on the message can meet Yes or No, which speak. With Phrases
    /// and Type beside the message, as the slot plan has them, Yes and No
    /// are under nearly all of it on compact widths, and under two of its
    /// three columns on regular ones: more than today's Home, whose message
    /// spans the width (about 56% by centre, 50% by edge). The engine's
    /// worst shares are pinned here, for the owner to accept or reject
    /// (docs/work/layout-engine.md, *Spec*). Fails if a layout's share
    /// grows past them, and, strict, once no point of the message is
    /// nearest a control that speaks.
    @Test func yesAndNoStillBorderTheMessage() {
        var worst = (compact: (centre: 0.0, edge: 0.0), regular: (centre: 0.0, edge: 0.0))
        // The message's frame follows the width and the text, not the
        // height: one window height covers it.
        for (layout, _, _) in Self.everyLayout where layout.content.height == 874 - 16 {
            let share = Nearest.speakingShare(of: layout)
            if layout.isRegular {
                worst.regular = (max(share.centre, worst.regular.centre), max(share.edge, worst.regular.edge))
            } else {
                worst.compact = (max(share.centre, worst.compact.centre), max(share.edge, worst.compact.edge))
            }
        }
        #expect(worst.compact.centre <= 0.97 && worst.compact.edge <= 0.89, "\(worst.compact)")
        #expect(worst.regular.centre <= 0.68 && worst.regular.edge <= 0.62, "\(worst.regular)")
        withKnownIssue("docs/DECISIONS.md, \"Home's slot plan\": Yes and No border the message") {
            #expect(worst.compact.centre == 0 && worst.regular.centre == 0 && worst.compact.edge == 0 && worst.regular.edge == 0)
        }
    }

    /// Known hazard on compact widths (docs/DECISIONS.md, "Get Attention and
    /// Stop on Home", *Open: the top of Stop's well is nearest Again*): with
    /// Get Attention under Emergency, Again is the control above Stop's
    /// well, and on windows narrower than any iPhone in portrait with Bold
    /// Text on, the well's top leading corner ties Yes by centre too. On
    /// regular widths Emergency is above the well, as the slot plan has it,
    /// and nothing that speaks is nearest any point of it. Fails if
    /// anything else is ever nearest a point of the well, if Yes is met
    /// anywhere else, if regular widths meet Again, and, strict, once
    /// compact ones do not.
    @Test func theTopOfStopsWellIsNearestAgainOnlyOnCompactWidths() {
        var compactMeetsAgain = 0
        var faults: [String] = []
        for (layout, text, context) in Self.everyLayout {
            let others = Nearest.controls(in: layout, excluding: [.stop])
            let yesAllowed = !layout.isRegular && text.boldText && layout.content.width < 375 - 2 * HomeLayout.margins.horizontal
            let allowed: Set<HomeLayout.Slot> = layout.isRegular ? [.emergency] : (yesAllowed ? [.again, .yes] : [.again])
            var meetsAgain = false
            for point in Nearest.points(in: layout.frame(.stop)) {
                let met = Nearest.to(point, among: others).subtracting(Self.categories)
                if !met.isSubset(of: allowed) {
                    faults.append("\(met) from \(point) in Stop's well (\(context))")
                }
                meetsAgain = meetsAgain || met.contains(.again)
            }
            if meetsAgain && !layout.isRegular {
                compactMeetsAgain += 1
            }
        }
        let count = faults.count
        #expect(count == 0, "first: \(faults.first ?? "")")
        withKnownIssue("docs/DECISIONS.md, \"Get Attention and Stop on Home\": the top of Stop's well is nearest Again") {
            #expect(compactMeetsAgain == 0)
        }
    }

    // MARK: Chains of held activations

    /// Home's map for the chain engine on the layout engine's frames
    /// (`HomeChains`), built as `HomeShapeTests` builds it from today's
    /// stand-in, with Phrases and Type added: Phrases does nothing while the
    /// phrases show, and Type leads to typing, which the map does not have
    /// yet, so a chain stops there.
    static func chainMap(_ layout: HomeLayout) -> ChainMap {
        let categories = (0..<HomeLayout.categoryCapacity).map { (name: "category \($0 + 1)", frame: layout.frame(.category($0))) }
        var map = HomeChains.map(HomeChains.Frames(
            yes: layout.frame(.yes), no: layout.frame(.no), emergency: layout.frame(.emergency), again: layout.frame(.again),
            getAttention: layout.frame(.getAttention), stop: layout.frame(.stop), settings: layout.frame(.settings),
            categories: categories
        ))
        for state in map.states.keys {
            map.states[state]?.append(ChainControl("phrases", layout.frame(.phrases), .nothing))
            map.states[state]?.append(ChainControl("type", layout.frame(.type), .navigates, leadsTo: "Typing"))
        }
        return map
    }

    /// Fails if a chain of held activations on the engine's frames meets
    /// anything that speaks, alarms, changes data or moves things unasked,
    /// in any of Home's states, from any control a person chooses or any
    /// place a look rests, by nearest centre or nearest edge, with the
    /// pointer staying on the control or going back to the look
    /// (`ChainEngine`): the check `HomeShapeTests.noChainOnHomeMeetsAHazard`
    /// makes on today's Home. Scores widths every 16pt and both sides of
    /// each change of arrangement, at a phone's and an iPad's height, at
    /// three text sizes.
    ///
    /// One finding is known, on compact widths only (the test above): a look
    /// resting in Stop's well, empty or after choosing Stop, can meet Again,
    /// or Yes at the well's corner on the narrowest bold windows. Anything
    /// else fails, and so does that finding on a regular width; strict, so
    /// it fails once compact widths do not meet it either.
    @Test(arguments: [false, true])
    func noChainOnTheEnginesFramesMeetsAHazardButStopsWell(boldText: Bool) {
        var known = 0
        var unexpected: [String] = []
        for (name, text) in [("default", Self.defaultText), ("xxxLarge", Self.largerText), ("AX5", Self.largestText)] {
            let text = boldText ? Self.bold(text) : text
            for height: CGFloat in [874, 1376] {
                func layout(_ width: CGFloat) -> HomeLayout {
                    HomeLayout(space: .init(size: CGSize(width: width, height: height)), text: text)
                }
                for width in Self.chainWidths(layout) {
                    let layout = layout(width)
                    let context = "\(width)×\(height), \(name), Bold Text \(boldText)"
                    let map = Self.chainMap(layout)
                    for finding in ChainFinding.findings(in: map.hazards(from: map.everyStart())) {
                        let start = finding.example.start
                        let fromTheWell = start.chosen?.name == HomeChains.stop || start.restingOn == HomeChains.emptyWell
                        let met = finding.example.hazard?.control.name
                        if !layout.isRegular && fromTheWell && (met == HomeChains.again || met == HomeChains.yes) {
                            known += 1
                        } else {
                            unexpected.append("\(finding) (\(context))")
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

    /// Window widths for chain scoring: every 16pt from 320 to 1432, and
    /// both sides of each width where the arrangement, the categories'
    /// arrangement or Settings' word changes. Following every chain takes
    /// far longer than laying out, so not every 4 points.
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
    /// the windows `KeyboardProbeTests` measures, the message, Phrases,
    /// Type and the whole safety row end above the keyboard's room, at the
    /// default and the largest text size; the safety row never grows into
    /// that room where its floors fit above it. Safe areas: CI's iPhone 17
    /// (62 above, 34 below) and 13-inch iPad (32 and 20, from CI's frames).
    @Test(arguments: [defaultText, largestText])
    func theSafetyRowEndsAboveTheKeyboard(text: HomeLayout.Text) {
        let windows: [(CGSize, HomeLayout.Insets)] = [
            (CGSize(width: 402, height: 874), .init(top: 62, leading: 0, bottom: 34, trailing: 0)),
            (CGSize(width: 1032, height: 1376), .init(top: 32, leading: 0, bottom: 20, trailing: 0)),
            (CGSize(width: 1376, height: 1032), .init(top: 32, leading: 0, bottom: 20, trailing: 0)),
        ]
        for (size, safeArea) in windows {
            let layout = HomeLayout(space: .init(size: size, safeArea: safeArea), text: text)
            #expect(layout.bandClearsKeyboard, "\(size)")
            let bottom = [HomeLayout.Slot.yes, .no, .emergency, .again, .getAttention, .type].map { layout.frame($0).maxY }.max() ?? 0
            #expect(bottom <= layout.keyboard.bandLimit + 0.001, "\(size): \(bottom) against \(layout.keyboard.bandLimit)")
        }
    }

    /// Fails if growth carries the safety row into the keyboard's room on a
    /// short wide window where its floors fit above it: the 13-inch iPad in
    /// landscape with Display Zoom set to Larger Text (1032 × 774, limit
    /// 276), with text about as large as the second accessibility size,
    /// where the safety row at today's 88 points would end at 287. It gives
    /// back what it grew, and the categories stay no taller than it.
    @Test func growthStopsAtTheKeyboard() {
        let text = HomeLayout.Text(quickControlLine: 46, categoryLine: 41, messageLine: 53, statusLine: 37)
        let layout = HomeLayout(
            space: .init(size: CGSize(width: 1032, height: 774), safeArea: .init(top: 32, leading: 0, bottom: 20, trailing: 0)),
            text: text
        )
        #expect(layout.isRegular)
        #expect(layout.keyboard.bandLimit == 276)
        #expect(layout.bandClearsKeyboard)
        #expect(abs(layout.frame(.yes).maxY - 276) < 0.001)
        #expect(layout.quickControlHeight < 88 && layout.quickControlHeight >= text.quickControlLine + 2 * HomeLayout.labelInsetVertical)
        #expect(layout.categoryHeight <= layout.quickControlHeight)
    }

    /// Fails if a category is ever taller than the safety row's controls:
    /// the row stays the larger target, and the category under Stop's well
    /// stays nearer the well than Emergency above it.
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
            text: Self.largestText
        )
        // At its floor: one line of the words with the label's inset.
        #expect(layout.quickControlHeight == Self.largestText.quickControlLine + 2 * HomeLayout.labelInsetVertical)
        withKnownIssue("docs/DECISIONS.md, \"Typing is a state of Home\": the zoomed 13-inch iPad at the largest text sizes") {
            #expect(layout.bandClearsKeyboard)
        }
    }

    // MARK: The windows people use

    /// A full-screen window and how far up the text sizes it holds the
    /// starter library without scrolling, and keeps the safety row above
    /// the keyboard's room, with Bold Text off and on: an index into
    /// `textSizes`, or nil for none.
    struct Window: Sendable {
        let name: String
        let size: CGSize
        let top: CGFloat
        let bottom: CGFloat
        let fitsThrough: (plain: Int?, bold: Int?)
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
        Window(name: "iPhone 17", size: CGSize(width: 402, height: 874), top: 62, bottom: 34, fitsThrough: (2, 2), keyboardClearThrough: 4),
        Window(name: "iPhone 17 Pro Max", size: CGSize(width: 440, height: 956), top: 62, bottom: 34, fitsThrough: (3, 3), keyboardClearThrough: 4),
        Window(name: "iPhone 16e", size: CGSize(width: 390, height: 844), top: 47, bottom: 34, fitsThrough: (2, 0), keyboardClearThrough: 4),
        Window(name: "375×667 phone", size: CGSize(width: 375, height: 667), top: 20, bottom: 0, fitsThrough: (0, nil), keyboardClearThrough: 2),
        Window(name: "375×667 phone, zoomed", size: CGSize(width: 320, height: 568), top: 20, bottom: 0, fitsThrough: (nil, nil), keyboardClearThrough: 0),
        Window(name: "13-inch iPad", size: CGSize(width: 1032, height: 1376), top: 32, bottom: 20, fitsThrough: (4, 4), keyboardClearThrough: 4),
        Window(name: "13-inch iPad, landscape", size: CGSize(width: 1376, height: 1032), top: 32, bottom: 20, fitsThrough: (4, 4), keyboardClearThrough: 4),
        Window(name: "13-inch iPad, landscape, zoomed", size: CGSize(width: 1032, height: 774), top: 32, bottom: 20, fitsThrough: (4, 4), keyboardClearThrough: 2),
        Window(name: "11-inch iPad", size: CGSize(width: 834, height: 1210), top: 32, bottom: 20, fitsThrough: (4, 4), keyboardClearThrough: 4),
        Window(name: "11-inch iPad, landscape", size: CGSize(width: 1210, height: 834), top: 32, bottom: 20, fitsThrough: (4, 4), keyboardClearThrough: 4),
        Window(name: "iPad mini", size: CGSize(width: 744, height: 1133), top: 32, bottom: 20, fitsThrough: (4, 4), keyboardClearThrough: 4),
        Window(name: "iPad mini, landscape", size: CGSize(width: 1133, height: 744), top: 32, bottom: 20, fitsThrough: (3, 3), keyboardClearThrough: 2),
    ]

    /// Where the starter library fits without scrolling, and where the
    /// safety row stays above the keyboard, on each window at each text
    /// size. Fails if a window that fits stops fitting, and, strict, once
    /// one that does not starts to (docs/DECISIONS.md, "Home's stand-in
    /// layout", *Where the grid still scrolls*): update the table and the
    /// decision then.
    @Test(arguments: windows.indices)
    func theStarterLibraryFitsWhereTheTableSays(window index: Int) {
        let window = Self.windows[index]
        let space = HomeLayout.Space(size: window.size, safeArea: .init(top: window.top, leading: 0, bottom: window.bottom, trailing: 0))
        for (sizeIndex, (name, plain)) in Self.textSizes.enumerated() {
            for boldText in [false, true] {
                let text = boldText ? Self.bold(plain) : plain
                let layout = HomeLayout(space: space, text: text)
                let context = "\(window.name), \(name), Bold Text \(boldText)"
                let through = boldText ? window.fitsThrough.bold : window.fitsThrough.plain
                if let through, sizeIndex <= through {
                    #expect(layout.startersFit && !layout.grid.scrolls, "\(context): \(layout.shortfall)pt short")
                } else {
                    withKnownIssue("docs/DECISIONS.md, \"Home's stand-in layout\": where the grid still scrolls") {
                        #expect(layout.startersFit, "\(context)")
                    }
                }
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

    // MARK: Growth and the library

    /// Fails if a window short of room keeps today's sizes and lets the
    /// starter library scroll, or a window with room leaves a control at
    /// its floor: the gaps grow first, then the safety row, then the
    /// categories, and the grid takes the rest.
    @Test func roomGoesToTheGapsThenTheSafetyRowThenTheCategories() {
        // A 375×667 phone at the default size: exactly room for the
        // starter library with every control at its floor.
        let small = HomeLayout(
            space: .init(size: CGSize(width: 375, height: 667), safeArea: .init(top: 20, leading: 0, bottom: 0, trailing: 0)),
            text: Self.defaultText
        )
        #expect(small.startersFit && !small.grid.scrolls)
        #expect(small.regionGap == HomeLayout.minimumRegionSpacing)
        #expect(small.quickControlHeight == 44 && small.categoryHeight == 44)
        #expect(small.grid.tileSize.height == HomeLayout.compactTile.minimumHeight)
        // An iPhone 17: room for today's sizes, and taller tiles.
        let phone = HomeLayout(
            space: .init(size: CGSize(width: 402, height: 874), safeArea: .init(top: 62, leading: 0, bottom: 34, trailing: 0)),
            text: Self.defaultText
        )
        #expect(phone.regionGap == HomeLayout.regionSpacing)
        #expect(phone.quickControlHeight == 64 && phone.categoryHeight == 48)
        #expect(phone.grid.tileSize.height > HomeLayout.compactTile.minimumHeight)
        // A 13-inch iPad in portrait: today's wide sizes.
        let pad = HomeLayout(
            space: .init(size: CGSize(width: 1032, height: 1376), safeArea: .init(top: 32, leading: 0, bottom: 20, trailing: 0)),
            text: Self.defaultText
        )
        #expect(pad.quickControlHeight == 88 && pad.categoryHeight == 72)
    }

    /// Fails if the controls' frames follow the library: only the phrase
    /// grid's rows do. A library with more phrases than the starter
    /// library's largest category scrolls at the tiles' floor, never below
    /// it; one with fewer gets taller tiles.
    @Test func onlyTheGridFollowsTheLibrary() {
        for (base, text, context) in Self.everyLayout where base.content.height == 874 - 16 {
            let space = HomeLayout.Space(size: CGSize(width: base.content.width + 32, height: 874))
            for count in [0, 1, 8, 9, 12, 40] {
                let other = HomeLayout(space: space, text: text, largestCategory: count)
                let moved = HomeLayout.Slot.all.filter { $0 != .phraseGrid && other.frame($0) != base.frame($0) }
                #expect(moved.isEmpty, "\(moved) moved for \(count) phrases (\(context))")
                #expect(other.frame(.phraseGrid) == base.frame(.phraseGrid))
                #expect(other.grid.rows == HomeLayout.Grid.rows(for: count, columns: base.grid.columns))
                let floor = base.isRegular ? HomeLayout.regularTile.minimumHeight : HomeLayout.compactTile.minimumHeight
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

    // MARK: Reserved regions

    /// Fails if a reserved region that crosses a slot goes unreported, or
    /// one in the margins is reported. How Home keeps clear of a fold is
    /// settled with the open iPhone Duo (docs/work/layout-engine.md).
    @Test func reservedRegionsAreReported() {
        let size = CGSize(width: 1032, height: 1376)
        let clear = HomeLayout(space: .init(size: size), text: Self.defaultText)
        #expect(clear.slotsInReservedRegions.isEmpty)
        let fold = CGRect(x: 512, y: 0, width: 8, height: 1376)
        let folded = HomeLayout(space: .init(size: size, reservedRegions: [fold]), text: Self.defaultText)
        let crossed = HomeLayout.Slot.all.filter { folded.frame($0).minX < fold.maxX && folded.frame($0).maxX > fold.minX }
        #expect(folded.slotsInReservedRegions == Set(crossed))
        #expect(!crossed.isEmpty)
        let margin = CGRect(x: 0, y: 0, width: 8, height: 1376)
        #expect(HomeLayout(space: .init(size: size, reservedRegions: [margin]), text: Self.defaultText).slotsInReservedRegions.isEmpty)
    }

    /// Fails if the engine stops naming the starter library as fitting
    /// where only the floors leave it room, or claims it fits where they do
    /// not: a 568pt phone 320pt wide has far too little.
    @Test func theShortfallIsReported() {
        let zoomed = HomeLayout(
            space: .init(size: CGSize(width: 320, height: 568), safeArea: .init(top: 20, leading: 0, bottom: 0, trailing: 0)),
            text: Self.defaultText
        )
        #expect(!zoomed.startersFit && zoomed.shortfall > 100 && zoomed.grid.scrolls)
        #expect(zoomed.grid.tileSize.height == HomeLayout.compactTile.minimumHeight)
        #expect(zoomed.quickControlHeight == 44 && zoomed.regionGap == HomeLayout.minimumRegionSpacing)
    }
}

// MARK: - Helpers

private enum Below {
    /// The controls whose frames lie directly under `frame`: one control
    /// spacing below it, and across its centre.
    static func controls(under frame: CGRect, in layout: HomeLayout) -> Set<HomeLayout.Slot> {
        Set(HomeLayout.Slot.controls.filter { slot in
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
        Dictionary(uniqueKeysWithValues: HomeLayout.Slot.controls.filter { !excluded.contains($0) }.map { ($0, layout.frame($0)) })
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
        let all = HomeLayout.Slot.controls
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
