import Foundation

/// The layout engine: where every slot on Home goes, worked out from the
/// space a window gives it, the input profile, the person's text size and
/// the library's shape. Plain logic, tested without a screen.
///
/// It names no device (AGENTS.md, *Layout on every device and window*). It
/// is given the window's size, its safe areas and the regions the system
/// reserves in it (a fold, a camera), never a device model, the screen's
/// physical size or a table of devices. Size classes are not read either:
/// the arrangement comes from the width itself.
///
/// It follows the slot plan (docs/DECISIONS.md, "Home's slot plan"):
/// regions top to bottom A (the message, with Phrases above Type in a
/// trailing column), C (the safety row), B (Stop's well, the categories
/// and Settings) and D (the phrase grid). Every slot keeps its frame in
/// every state of Home, because Home's state is not an input: Stop's well
/// is there while no alarm sounds, and Speak shows in Again's slot while
/// typing (invariant 8). Two arrangements, chosen from the width alone:
///
/// - **Compact** (three columns): Yes, No and Emergency, then Again and
///   Get Attention, Get Attention directly under Emergency, the trailing
///   column beside the message as wide as Emergency's
///   (docs/DECISIONS.md, "Get Attention and Stop on Home"); Stop's well,
///   two categories, then two categories and Settings, a category under
///   Stop; three columns of phrases, two where three would break a word.
/// - **Regular** (five columns): the slot plan's own safety row in one
///   row, Emergency, Yes, No, Again, Get Attention; the message over the
///   first three columns and Phrases and Type over the last two; Stop's
///   well directly under Emergency with the first category under it, the
///   other three categories and Settings at the band's full height; four
///   columns of phrases.
///
/// Heights start at each control's floor (the profile's, or one line of
/// its words at the person's text size, whichever is taller) and grow
/// toward today's sizes only where the window has room once the starter
/// library's largest category fits: first the gaps between regions, then
/// the safety row, then the categories; the phrase grid takes the rest.
/// The safety row never grows past the room Apple's keyboard leaves
/// (`KeyboardAllowance`). Where even the floors leave the starter library
/// too little room, the grid scrolls at its floor and `startersFit` says
/// so, with the height it lacks: a target is never made smaller than its
/// floor to avoid scrolling (invariant 11).
///
/// Nothing on screen uses it yet: Home moves onto it in the pull request
/// after this one (docs/ROADMAP.md, Wave 3 item 4; docs/work/layout-engine.md).
nonisolated struct HomeLayout: Equatable, Sendable {
    // MARK: Inputs

    /// The space a window gives Home: everything the layout knows about
    /// where it runs.
    struct Space: Equatable, Sendable {
        /// The window, in points.
        var size: CGSize
        /// What the system keeps for itself at each edge: the status bar,
        /// the home indicator, a camera housing, window controls.
        var safeArea: Insets
        /// Regions the system reserves inside the window, in the window's
        /// coordinates: a fold, a camera that can turn on
        /// (`reservedRegions(kind:options:layoutDirectionBehavior:)`).
        /// Reported, not yet avoided: how Home keeps clear of a fold is
        /// settled once the open iPhone Duo has been looked at
        /// (docs/work/layout-engine.md, *Spec*, *A fold*).
        var reservedRegions: [CGRect]

        init(size: CGSize, safeArea: Insets = .zero, reservedRegions: [CGRect] = []) {
            self.size = size
            self.safeArea = safeArea
            self.reservedRegions = reservedRegions
        }
    }

    /// Distances from each edge of the window, leading and trailing in the
    /// layout direction.
    struct Insets: Equatable, Sendable {
        var top: CGFloat
        var leading: CGFloat
        var bottom: CGFloat
        var trailing: CGFloat

        static let zero = Insets(top: 0, leading: 0, bottom: 0, trailing: 0)
    }

    /// How the person reaches the screen. Each profile sets the floors no
    /// target goes below and the sizes targets grow to where there is room
    /// (docs/DECISIONS.md, "Layouts from the space available"). Only touch
    /// is defined until the profiles of docs/ROADMAP.md, Wave 3 items 8 and
    /// 9, which come after R0's first build has gone to App Review.
    enum Profile: Equatable, Sendable {
        case touch

        /// The smallest any target may be, in each direction. For touch,
        /// Apple's 44 by 44 points (invariant 1): about 6.9 mm on the
        /// densest supported screens (163 points per inch), more on the
        /// rest.
        var floor: CGFloat {
            switch self {
            case .touch: 44
            }
        }

        /// How tall Yes, No, Emergency, Again and Get Attention grow where
        /// there is room: today's sizes, 64 points on compact widths and 88
        /// on regular ones (docs/DECISIONS.md, "Home's stand-in layout").
        func quickControlHeight(isRegular: Bool) -> CGFloat {
            switch self {
            case .touch: isRegular ? 88 : 64
            }
        }

        /// How tall the categories, Stop and Settings grow where there is
        /// room: today's sizes, 48 points on compact widths and 72 on
        /// regular ones.
        func categoryHeight(isRegular: Bool) -> CGFloat {
            switch self {
            case .touch: isRegular ? 72 : 48
            }
        }
    }

    /// One line of each of Home's label styles at the person's text size,
    /// as `LabelFont.lineHeight(at:)` measures it, and whether Bold Text is
    /// on. The engine never measures text itself, so it runs anywhere;
    /// `measured(at:boldText:)` fills this from the real fonts.
    struct Text: Equatable, Sendable {
        /// Yes, No, Emergency, Again, Get Attention, Phrases and Type.
        var quickControlLine: CGFloat
        /// The categories, Stop and Settings.
        var categoryLine: CGFloat
        /// The message the listener reads.
        var messageLine: CGFloat
        /// The status line under the message.
        var statusLine: CGFloat
        /// Bold Text's heavier words need wider controls (`MinimumWidths`).
        var boldText: Bool

        init(quickControlLine: CGFloat, categoryLine: CGFloat, messageLine: CGFloat, statusLine: CGFloat, boldText: Bool = false) {
            self.quickControlLine = quickControlLine
            self.categoryLine = categoryLine
            self.messageLine = messageLine
            self.statusLine = statusLine
            self.boldText = boldText
        }
    }

    // MARK: Fixed measures

    /// Home's margins inside the safe area: 16 points at the sides, 8 above
    /// and below (`HomeView` today).
    static let margins = (horizontal: CGFloat(16), vertical: CGFloat(8))
    /// The gap between controls inside a region.
    static let controlSpacing: CGFloat = 8
    /// The gap between regions where there is room: larger than the gap
    /// between controls, so each region reads as a group.
    static let regionSpacing: CGFloat = 12
    /// The smallest gap between regions. Still more than the gap between
    /// controls, by more than the half point the chain checks count as a
    /// tie, so a look resting in a well keeps meeting the control in its
    /// own region first (`HomeLayoutEngineTests`). A window short of room gives
    /// these four points back before any control shrinks to its floor.
    static let minimumRegionSpacing: CGFloat = 10
    /// The room between a label and its control's top and bottom edges
    /// (`HomeShape.labelInset`).
    static let labelInsetVertical: CGFloat = 6
    /// The space between the message's two lines and the status line
    /// under them (`HomeView`).
    static let statusSpacing: CGFloat = 4
    /// Everyday categories with a cell of their own (the slot plan's four).
    static let categoryCapacity = 4
    /// The starter library's largest category, Basics and Needs (eight
    /// phrases each): the grid the controls above it leave room for. A
    /// library with more scrolls at the tiles' floor; one with fewer gets
    /// taller tiles. The controls' frames never follow the library.
    static let referencePhraseCount = 8

    /// The narrowest compact tile, and the shortest: the starter library's
    /// widest word, "understand.", at the default size (`HomeShape`'s 107
    /// points; 118 with Bold Text, which `HomeShape` does not yet allow
    /// for), and its tallest phrase in four lines (`HomeShape`'s 99
    /// points). `HomeLayoutEngineFontTests` checks them with the real fonts.
    static let compactTile = (minimumWidth: CGFloat(107), boldMinimumWidth: CGFloat(118), minimumHeight: CGFloat(99))
    /// The narrowest regular tile, in the larger tile font: "understand."
    /// at 22 points with `WordFit.widthSlack` and the label inset (131
    /// points, 146 with Bold Text), and the shortest, the starter library's
    /// tallest phrases in three lines at the narrowest four-column tile
    /// (`HomeLayoutEngineFontTests` checks both with the real fonts).
    static let regularTile = (minimumWidth: CGFloat(131), boldMinimumWidth: CGFloat(146), minimumHeight: CGFloat(100))

    // MARK: Results

    /// The window less its safe areas and Home's margins: where every slot
    /// lies, in the window's coordinates.
    let content: CGRect
    /// Three columns or five, chosen from the width.
    let isRegular: Bool
    let categoryArrangement: CategoryArrangement
    /// Every slot's frame, in the window's coordinates, leading edge first.
    let frames: [Slot: CGRect]
    let grid: Grid
    /// The height of each row of the safety row.
    let quickControlHeight: CGFloat
    /// The height of a category, Stop's well and, outside the band, Settings.
    let categoryHeight: CGFloat
    /// The gap between regions.
    let regionGap: CGFloat
    /// Whether the starter library's largest category fits without
    /// scrolling: invariant 11 holds in this window at this text size.
    let startersFit: Bool
    /// How much taller the content would have to be for it to fit: zero
    /// when it does.
    let shortfall: CGFloat
    /// The room kept for Apple's keyboard (docs/DECISIONS.md, "Typing is a
    /// state of Home").
    let keyboard: KeyboardAllowance
    /// Whether the message, Phrases, Type and the whole safety row end
    /// above the keyboard's room, so typing can leave them reachable.
    let bandClearsKeyboard: Bool
    /// False where Settings has room only for its gear.
    let settingsShowsName: Bool
    /// Whether the message is wide enough for the starter library's widest
    /// word at the default text size (`MinimumWidths.message`): the message
    /// steps down only as far as its widest word needs, never below the
    /// default size (AGENTS.md, *Words never break*). False only on compact
    /// windows narrower than 345 points with Bold Text on, where the
    /// trailing column is as wide as Emergency's bold word.
    let messageHoldsItsWords: Bool
    /// Whether every control above the phrase grid fits in the content,
    /// leaving the grid some height of its own. False only on a window too
    /// short for the safety row and categories at their floors.
    let controlsFit: Bool
    /// The slots a reserved region crosses.
    let slotsInReservedRegions: Set<Slot>

    /// The frame of `slot`. Every slot but `.tile` has one in every layout.
    func frame(_ slot: Slot) -> CGRect {
        frames[slot] ?? .null
    }

    // MARK: The engine

    init(space: Space, profile: Profile = .touch, text: Text, largestCategory: Int = HomeLayout.referencePhraseCount) {
        let spacing = Self.controlSpacing
        let minimum = MinimumWidths.forBoldText(text.boldText)
        let safe = space.safeArea
        let content = CGRect(
            x: safe.leading + Self.margins.horizontal,
            y: safe.top + Self.margins.vertical,
            width: max(0, space.size.width - safe.leading - safe.trailing - 2 * Self.margins.horizontal),
            height: max(0, space.size.height - safe.top - safe.bottom - 2 * Self.margins.vertical)
        )
        self.content = content
        let width = content.width
        keyboard = KeyboardAllowance(windowSize: space.size)

        // Columns. Regular wherever five equal columns each hold the widest
        // word any of them carries; compact otherwise.
        let fifth = (width - 4 * spacing) / 5
        let isRegular = fifth >= minimum.regularColumn
        self.isRegular = isRegular

        // Floors: the profile's, or one line of the words at the person's
        // size with the label's inset, whichever is taller, so no label has
        // to step down to fit a height (Apple's audit reports that as text
        // that does not follow Dynamic Type).
        let insets = 2 * Self.labelInsetVertical
        let quickFloor = max(profile.floor, text.quickControlLine + insets)
        let categoryFloor = max(profile.floor, text.categoryLine + insets)
        let messageBlock = 2 * text.messageLine + Self.statusSpacing + text.statusLine
        // Phrases above Type, beside the message: two controls at their
        // floor, or the message's height if that is taller.
        let messageRegion = max(messageBlock, 2 * quickFloor + spacing)
        let quickRows = isRegular ? 1 : 2

        // The categories region's arrangement and widths.
        let categories = CategoryWidths(contentWidth: width, isRegular: isRegular, fifth: fifth, minimum: minimum)
        categoryArrangement = categories.arrangement
        settingsShowsName = categories.settings >= minimum.settings
        let categoryRows = categories.arrangement == .twoColumns ? 3 : 2

        // The phrase grid: fixed columns from the width.
        let columns: Int
        let tileFloor: CGFloat
        if isRegular {
            let tileMinimum = text.boldText ? Self.regularTile.boldMinimumWidth : Self.regularTile.minimumWidth
            columns = (width - 3 * spacing) / 4 >= tileMinimum ? 4 : 3
            tileFloor = max(profile.floor, Self.regularTile.minimumHeight)
        } else {
            let tileMinimum = text.boldText ? Self.compactTile.boldMinimumWidth : Self.compactTile.minimumWidth
            columns = (width - 2 * spacing) / 3 >= tileMinimum ? 3 : 2
            tileFloor = max(profile.floor, Self.compactTile.minimumHeight)
        }
        let referenceRows = Grid.rows(for: Self.referencePhraseCount, columns: columns)

        func stack(_ rows: Int, of height: CGFloat) -> CGFloat {
            CGFloat(rows) * height + CGFloat(max(0, rows - 1)) * spacing
        }

        // What the starter library needs at every floor.
        let needed = messageRegion + stack(quickRows, of: quickFloor) + stack(categoryRows, of: categoryFloor)
            + stack(referenceRows, of: tileFloor) + 3 * Self.minimumRegionSpacing
        var spare = content.height - needed
        startersFit = spare >= -0.001
        shortfall = max(0, -spare)

        // Growth, in order, where there is room: the gaps between regions,
        // the safety row, the categories. The phrase grid takes the rest.
        var gap = Self.minimumRegionSpacing
        var quick = quickFloor
        var category = categoryFloor
        if spare > 0 {
            let gapGrowth = min(spare, 3 * (Self.regionSpacing - Self.minimumRegionSpacing))
            gap += gapGrowth / 3
            spare -= gapGrowth
            let quickTarget = max(quickFloor, profile.quickControlHeight(isRegular: isRegular))
            let quickGrowth = min(spare, CGFloat(quickRows) * (quickTarget - quickFloor))
            quick += quickGrowth / CGFloat(quickRows)
            spare -= quickGrowth
            let categoryTarget = max(categoryFloor, profile.categoryHeight(isRegular: isRegular))
            let categoryGrowth = min(spare, CGFloat(categoryRows) * (categoryTarget - categoryFloor))
            category += categoryGrowth / CGFloat(categoryRows)
            spare -= categoryGrowth
        }

        // The keyboard's room. Growth never carries the safety row into it:
        // the rows give back what they grew first, then the gaps.
        let limit = keyboard.bandLimit
        var safetyBottom = content.minY + messageRegion + gap + stack(quickRows, of: quick)
        if safetyBottom > limit {
            let quickCut = min(safetyBottom - limit, CGFloat(quickRows) * (quick - quickFloor))
            quick -= quickCut / CGFloat(quickRows)
            safetyBottom -= quickCut
            let gapCut = min(max(0, safetyBottom - limit), gap - Self.minimumRegionSpacing)
            gap -= gapCut
            safetyBottom -= gapCut
        }
        bandClearsKeyboard = safetyBottom <= limit + 0.001
        // A category is never taller than the safety row, which stays the
        // larger target. It also keeps a held look after Stop on the
        // category under the well: were the categories taller, Emergency's
        // centre, above the well on regular widths, would come nearer.
        category = min(category, quick)
        quickControlHeight = quick
        categoryHeight = category
        regionGap = gap

        // Frames, top to bottom.
        var frames: [Slot: CGRect] = [:]
        let x = content.minX
        let top = content.minY

        // A: the message and its status line, then Phrases above Type.
        let messageWidth: CGFloat
        let trailingWidth: CGFloat
        let lead: CGFloat
        if isRegular {
            messageWidth = 3 * fifth + 2 * spacing
            trailingWidth = 2 * fifth + spacing
            lead = fifth
        } else {
            trailingWidth = max((width - 2 * spacing) / 3, minimum.compactTrailingColumn)
            lead = max(0, width - 2 * spacing - trailingWidth) / 2
            messageWidth = 2 * lead + spacing
        }
        messageHoldsItsWords = messageWidth >= minimum.message
        let messageHeight = messageRegion - Self.statusSpacing - text.statusLine
        frames[.message] = CGRect(x: x, y: top, width: messageWidth, height: messageHeight)
        frames[.statusLine] = CGRect(x: x, y: top + messageHeight + Self.statusSpacing, width: messageWidth, height: text.statusLine)
        let modeHeight = (messageRegion - spacing) / 2
        let trailingX = x + messageWidth + spacing
        frames[.phrases] = CGRect(x: trailingX, y: top, width: trailingWidth, height: modeHeight)
        frames[.type] = CGRect(x: trailingX, y: top + modeHeight + spacing, width: trailingWidth, height: modeHeight)

        // C: the safety row.
        let safetyTop = top + messageRegion + gap
        if isRegular {
            let order: [Slot] = [.emergency, .yes, .no, .again, .getAttention]
            for (index, slot) in order.enumerated() {
                frames[slot] = CGRect(x: x + CGFloat(index) * (fifth + spacing), y: safetyTop, width: fifth, height: quick)
            }
        } else {
            let secondRow = safetyTop + quick + spacing
            frames[.yes] = CGRect(x: x, y: safetyTop, width: lead, height: quick)
            frames[.no] = CGRect(x: x + lead + spacing, y: safetyTop, width: lead, height: quick)
            frames[.emergency] = CGRect(x: trailingX, y: safetyTop, width: trailingWidth, height: quick)
            frames[.again] = CGRect(x: x, y: secondRow, width: messageWidth, height: quick)
            frames[.getAttention] = CGRect(x: trailingX, y: secondRow, width: trailingWidth, height: quick)
        }

        // B: Stop's well, the categories and Settings.
        let categoriesTop = safetyTop + stack(quickRows, of: quick) + gap
        for (slot, cell) in categories.cells(rowHeight: category, spacing: spacing) {
            frames[slot] = cell.offsetBy(dx: x, dy: categoriesTop)
        }

        // D: the phrase grid, in what is left.
        let gridTop = categoriesTop + stack(categoryRows, of: category) + gap
        let gridFrame = CGRect(x: x, y: gridTop, width: width, height: max(0, content.maxY - gridTop))
        frames[.phraseGrid] = gridFrame
        grid = Grid(frame: gridFrame, columns: columns, phraseCount: largestCategory, tileFloor: tileFloor, spacing: spacing)

        self.frames = frames
        controlsFit = gridTop <= content.maxY + 0.001
        slotsInReservedRegions = Set(frames.filter { _, frame in
            space.reservedRegions.contains { Self.overlap($0, frame) }
        }.keys)
    }

    /// Whether two rectangles share some area; touching edges do not count.
    private static func overlap(_ a: CGRect, _ b: CGRect) -> Bool {
        a.minX < b.maxX && b.minX < a.maxX && a.minY < b.maxY && b.minY < a.maxY
    }

    // MARK: Slots

    /// A place on Home with a stable identity (docs/DECISIONS.md, "Home's
    /// slot plan"): the same slot whatever it shows. Again's slot shows
    /// Speak while typing; Stop's is a well, empty while no alarm sounds.
    enum Slot: Hashable, Sendable, CustomStringConvertible {
        case message, statusLine, phrases, type
        case yes, no, emergency, again, getAttention
        case stop
        /// An everyday category's cell, from 0 in the library's order.
        case category(Int)
        case settings
        /// Region D's visible frame. Its tiles are in `grid`.
        case phraseGrid

        /// Every slot a layout has.
        static let all: [Slot] = [.message, .statusLine, .phrases, .type, .yes, .no, .emergency, .again, .getAttention, .stop]
            + (0..<HomeLayout.categoryCapacity).map { .category($0) } + [.settings, .phraseGrid]

        /// The slots that are controls a person can activate (or, for Stop,
        /// a well that holds one).
        static let controls: [Slot] = all.filter { ![.message, .statusLine, .phraseGrid].contains($0) }

        var description: String {
            switch self {
            case .message: "message"
            case .statusLine: "statusLine"
            case .phrases: "phrases"
            case .type: "type"
            case .yes: "yes"
            case .no: "no"
            case .emergency: "emergency"
            case .again: "again"
            case .getAttention: "getAttention"
            case .stop: "stop"
            case .category(let index): "category\(index)"
            case .settings: "settings"
            case .phraseGrid: "phraseGrid"
            }
        }
    }

    /// How region B holds Stop's well, the four category cells and
    /// Settings (`HomeShape.CategoryArrangement`). A category is directly
    /// under Stop in each.
    enum CategoryArrangement: Equatable, Sendable {
        /// Regular widths: Stop above the first category in the leading
        /// column, the other three and Settings at the band's full height.
        case band
        /// Stop, two categories; then two categories and Settings.
        case threeColumns
        /// Stop and a category; two categories; a category and Settings.
        case twoColumns
    }

    // MARK: The phrase grid

    /// Region D: fixed columns from the width, rows from the library's
    /// largest category, so a tile keeps its place whichever category
    /// shows (invariant 8). Tiles share the region's height; where they
    /// would be shorter than their floor, they keep the floor and the grid
    /// scrolls.
    struct Grid: Equatable, Sendable {
        let frame: CGRect
        let columns: Int
        let rows: Int
        let tileSize: CGSize
        let scrolls: Bool
        let spacing: CGFloat

        init(frame: CGRect, columns: Int, phraseCount: Int, tileFloor: CGFloat, spacing: CGFloat) {
            self.frame = frame
            self.columns = columns
            self.spacing = spacing
            rows = Self.rows(for: phraseCount, columns: columns)
            let tileWidth = (frame.width - CGFloat(columns - 1) * spacing) / CGFloat(columns)
            // Whole points, as `GridSizing` gives them; the thousandth keeps
            // a window that fits exactly from losing a point to rounding.
            let fitted = ((frame.height - CGFloat(rows - 1) * spacing) / CGFloat(rows) + 0.001).rounded(.down)
            scrolls = fitted < tileFloor
            tileSize = CGSize(width: tileWidth, height: scrolls ? tileFloor : fitted)
        }

        /// Rows for `count` phrases: at least one.
        static func rows(for count: Int, columns: Int) -> Int {
            max(1, (count + columns - 1) / columns)
        }

        /// The tile at `row` and `column`, from 0, in the window's
        /// coordinates. Rows past the region's foot are reached by
        /// scrolling.
        func tile(row: Int, column: Int) -> CGRect {
            CGRect(
                x: frame.minX + CGFloat(column) * (tileSize.width + spacing),
                y: frame.minY + CGFloat(row) * (tileSize.height + spacing),
                width: tileSize.width,
                height: tileSize.height
            )
        }
    }

    // MARK: Widths

    /// The narrowest a control may be: its widest word at the default text
    /// size, with `WordFit.widthSlack` and the label inset, so the word is
    /// drawn whole at every text size; wider with Bold Text on, measured at
    /// the heaviest weight (`LabelFont.boldTextUIFontWeight`). The values
    /// `HomeShape.MinimumWidths` has, measured on CI (`StarterLabelFitTests`),
    /// and four new ones: "Phrases" and "Type" (A's trailing column),
    /// "Speak", which Again's slot shows while typing, and the message, which
    /// has no inset. `HomeLayoutEngineFontTests` checks the new ones with
    /// the real fonts.
    struct MinimumWidths: Equatable, Sendable {
        /// The message: the starter library's widest word in the message
        /// font, "understand.", with `WordFit.widthSlack`.
        let message: CGFloat
        let yesNo: CGFloat
        /// Again's slot: the wider of "Again" and "Speak".
        let again: CGFloat
        let emergency: CGFloat
        let getAttention: CGFloat
        let phrases: CGFloat
        let type: CGFloat
        let category: CGFloat
        let stop: CGFloat
        let settings: CGFloat
        let settingsSymbol: CGFloat

        static let regular = MinimumWidths(
            message: 156, yesNo: 46, again: 70, emergency: 120, getAttention: 100, phrases: 86, type: 58,
            category: 118, stop: 52, settings: 80, settingsSymbol: 44
        )
        static let boldText = MinimumWidths(
            message: 175, yesNo: 48, again: 75, emergency: 130, getAttention: 110, phrases: 94, type: 63,
            category: 128, stop: 56, settings: 86, settingsSymbol: 44
        )

        static func forBoldText(_ boldText: Bool) -> MinimumWidths {
            boldText ? .boldText : .regular
        }

        /// The narrowest a regular column may be: every control that takes
        /// one column there holds its word (Phrases and Type take two).
        var regularColumn: CGFloat {
            max(yesNo, again, emergency, getAttention, category, stop, settings)
        }

        /// The narrowest the compact trailing column may be: it holds
        /// Phrases and Type, and under them Emergency and Get Attention.
        var compactTrailingColumn: CGFloat {
            max(emergency, getAttention, phrases, type)
        }
    }

    /// Region B's widths (`HomeShape`'s rules for the categories): the
    /// band on regular widths, every cell a column; otherwise three columns
    /// with the categories at least their minimum and Stop and Settings
    /// sharing what is left (Settings showing its gear alone where its word
    /// does not fit), or two columns of three rows where that leaves Stop
    /// too little.
    private struct CategoryWidths {
        let arrangement: CategoryArrangement
        let category: CGFloat
        let stop: CGFloat
        let settings: CGFloat

        init(contentWidth: CGFloat, isRegular: Bool, fifth: CGFloat, minimum: MinimumWidths) {
            let spacing = HomeLayout.controlSpacing
            if isRegular {
                (arrangement, category, stop, settings) = (.band, fifth, fifth, fifth)
                return
            }
            let threeColumn = max(minimum.category, (contentWidth - 2 * spacing) / 3)
            let rest = contentWidth - 2 * spacing - 2 * threeColumn
            if rest >= max(minimum.stop, minimum.settingsSymbol) {
                (arrangement, category, stop, settings) = (.threeColumns, threeColumn, rest, rest)
            } else {
                let half = max(0, contentWidth - spacing) / 2
                (arrangement, category, stop, settings) = (.twoColumns, half, half, half)
            }
        }

        /// Each cell, from the region's top leading corner.
        func cells(rowHeight: CGFloat, spacing: CGFloat) -> [(Slot, CGRect)] {
            let row = rowHeight + spacing
            switch arrangement {
            case .band:
                let full = 2 * rowHeight + spacing
                var cells: [(Slot, CGRect)] = [
                    (.stop, CGRect(x: 0, y: 0, width: stop, height: rowHeight)),
                    (.category(0), CGRect(x: 0, y: row, width: category, height: rowHeight)),
                ]
                for index in 1..<HomeLayout.categoryCapacity {
                    cells.append((.category(index), CGRect(x: CGFloat(index) * (category + spacing), y: 0, width: category, height: full)))
                }
                cells.append((.settings, CGRect(x: CGFloat(HomeLayout.categoryCapacity) * (category + spacing), y: 0, width: settings, height: full)))
                return cells
            case .threeColumns:
                return [
                    (.stop, CGRect(x: 0, y: 0, width: stop, height: rowHeight)),
                    (.category(0), CGRect(x: stop + spacing, y: 0, width: category, height: rowHeight)),
                    (.category(1), CGRect(x: stop + category + 2 * spacing, y: 0, width: category, height: rowHeight)),
                    (.category(2), CGRect(x: 0, y: row, width: category, height: rowHeight)),
                    (.category(3), CGRect(x: category + spacing, y: row, width: category, height: rowHeight)),
                    (.settings, CGRect(x: 2 * (category + spacing), y: row, width: settings, height: rowHeight)),
                ]
            case .twoColumns:
                let slots: [Slot] = [.stop, .category(0), .category(1), .category(2), .category(3), .settings]
                return slots.enumerated().map { index, slot in
                    (slot, CGRect(x: CGFloat(index % 2) * (category + spacing), y: CGFloat(index / 2) * row, width: category, height: rowHeight))
                }
            }
        }
    }
}
