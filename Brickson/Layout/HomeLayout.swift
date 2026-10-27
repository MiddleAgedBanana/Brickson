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
/// Home has its frames from it (docs/ROADMAP.md, Wave 3 items 4 and 5;
/// docs/work/layout-engine.md, docs/work/typing-on-home.md), with both
/// modes, browsing and typing (`Modes.phrasesAndTyping`), and so does
/// Settings' Back to Talking, which takes Phrases' frame.
nonisolated struct HomeLayout: Equatable, Sendable {
    // MARK: Inputs

    /// A system reservation, already including its margins, in the
    /// reconstructed window's coordinates. Activity does not affect
    /// allocation: starting tracking must not move a control.
    struct ReservedRegion: Equatable, Sendable {
        enum Kind: Equatable, Sendable { case division, occlusion }
        var kind: Kind
        var frame: CGRect
        var isActive: Bool

        init(kind: Kind, frame: CGRect, isActive: Bool = true) {
            self.kind = kind
            self.frame = frame
            self.isActive = isActive
        }
    }

    /// The space a window gives Home. No input names a device or pose.
    struct Space: Equatable, Sendable {
        var size: CGSize
        var safeArea: Insets
        var regions: [ReservedRegion]

        /// Compatibility for callers that predate typed reservations.
        /// A rectangle spanning a whole window axis is a division; other
        /// rectangles are occlusions. The live adapter supplies kinds.
        var reservedRegions: [CGRect] {
            get { regions.map(\.frame) }
            set { regions = Self.legacyRegions(newValue, size: size) }
        }

        init(size: CGSize, safeArea: Insets = .zero, reservedRegions: [CGRect] = []) {
            self.size = size
            self.safeArea = safeArea
            regions = Self.legacyRegions(reservedRegions, size: size)
        }

        init(size: CGSize, safeArea: Insets = .zero, regions: [ReservedRegion]) {
            self.size = size
            self.safeArea = safeArea
            self.regions = regions
        }

        private static func legacyRegions(_ frames: [CGRect], size: CGSize) -> [ReservedRegion] {
            frames.map { frame in
                let spansAxis = (frame.minY <= 0 && frame.maxY >= size.height)
                    || (frame.minX <= 0 && frame.maxX >= size.width)
                return ReservedRegion(kind: spansAxis ? .division : .occlusion, frame: frame)
            }
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

    /// Which of the slot plan's two modes Home has: browsing phrases, and
    /// typing (docs/DECISIONS.md, "Home's slot plan", A). Phrases and Type,
    /// the controls that pick a mode, sit in A's trailing column only once
    /// there is a second mode to pick, and the slot plan's one-row safety
    /// row on regular widths needs them there: with the message across the
    /// width above it, Get Attention would border the message, and a look
    /// resting on the message must never meet an alarm.
    enum Modes: Equatable, Sendable {
        /// Home before typing came (docs/ROADMAP.md, Wave 3 item 4), kept
        /// as the comparison for the owner's open question on Yes and No
        /// (*Open hazard, not accepted: Yes and No border the message*): no
        /// trailing column in A, so the message spans the width; the safety
        /// row in two rows of two equal columns on every width, Yes and No
        /// sharing the leading one with Emergency beside them, then Again and
        /// Get Attention, Get Attention directly under Emergency
        /// (docs/DECISIONS.md, "Get Attention and Stop on Home"). Yes and
        /// No border no more of the message than they did before the engine
        /// (*Home's slot plan*, *Open hazard, not accepted: Yes and No
        /// border the message*).
        case phrasesOnly
        /// The slot plan's own, with Phrases above Type beside the message:
        /// the compact and regular arrangements above. Home's
        /// (docs/DECISIONS.md, "Typing on Home").
        case phrasesAndTyping
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
    /// How much farther than Again or the category under Stop's well Yes's
    /// centre stays from every point of the well (`wellDrop`): more than
    /// the half point the chain checks count as a tie, so a look resting in
    /// the empty well never meets Yes.
    static let wellClearance: CGFloat = 1
    /// The room between a label and its control's edges: 4 points at the
    /// sides, 6 above and below (`HomeButtonStyle`). Small on purpose: the
    /// label fits itself to what is left (`FittedLabel`).
    static let labelInset = (horizontal: CGFloat(4), vertical: CGFloat(6))
    /// The room beside the words of a control that shows selected, Emergency
    /// and the categories: as much as above and below them, which no ring
    /// reaches (`HomeButtonLook`). SwiftUI shrinks a word too wide for its
    /// label at the person's size until it fills the label, out to its
    /// inset, and the selection ring runs 2 to 5 points in: at the usual 4
    /// points the ring met Emergency's last letter on a phone at the largest
    /// text sizes, and CI's rendered-label test read "Emergenc"
    /// (docs/DECISIONS.md, "Get Attention and Stop on Home").
    static let selectableSideInset = labelInset.vertical
    /// The shortest safety row in which "Get Attention", too narrow for one
    /// line (`MinimumWidths.getAttentionOneLine`), is drawn whole on two at
    /// the default size: the stand-in Home's compact height, at which CI's
    /// rendered-label test read both words 100 points wide.
    static let twoLineQuickControlHeight: CGFloat = 64
    /// The shortest Phrases may be where Settings' "Back to Talking", which
    /// takes Phrases' frame, is too wide for one line of the categories'
    /// font (`MinimumWidths.backToTalkingOneLine`): two lines at the
    /// default size, on CI 20.5 points for the first and 22 for the second,
    /// with the label's inset, rounded up, plus a point.
    static let twoLineCategoryHeight: CGFloat = 56
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

    /// The narrowest compact tile: the starter library's widest word,
    /// "understand.", at the default size with `WordFit.widthSlack` and the
    /// label inset (107 points; 118 with Bold Text), and the shortest at
    /// each width (`TileFloor`). `HomeLayoutEngineFontTests` checks them
    /// with the real fonts.
    static let compactTile = (minimumWidth: CGFloat(107), boldMinimumWidth: CGFloat(118), floors: TileFloor.compact)
    /// The narrowest regular tile, in the larger tile font: "understand."
    /// at 22 points with `WordFit.widthSlack` and the label inset (131
    /// points, 146 with Bold Text), and the shortest at each width
    /// (`HomeLayoutEngineFontTests` checks both with the real fonts).
    static let regularTile = (minimumWidth: CGFloat(131), boldMinimumWidth: CGFloat(146), floors: TileFloor.regular)

    /// The shortest a phrase tile may be at its width before the grid
    /// scrolls instead: the starter library's tallest phrase at the default
    /// size, set in whole-word lines at that width (`WordFit.lines`), with
    /// the label's inset, and never under the profile's floor. A wider tile
    /// holds the phrases in fewer lines, so it may be shorter: at the
    /// narrowest compact tile "Please ask me yes or no questions." takes
    /// four lines, from 114 points every starter phrase takes three, from
    /// 160 two. Labels step down to the default size and never below it
    /// (`WordFit`), so the default size is the one that sets the floor at
    /// every text size.
    ///
    /// Each width is where Apple's SF Pro, measured on Linux, first sets
    /// every starter phrase in that many lines, plus 2 points; each height
    /// is SwiftUI's height for those lines on CI (headline: 20.5 points for
    /// the first line and 22 for each after it) with the inset, rounded up,
    /// plus a point or more. `HomeLayoutEngineFontTests` draws every starter
    /// phrase at each width and height with the real fonts.
    struct TileFloor: Equatable, Sendable {
        /// The narrowest tile this floor applies to, without and with Bold
        /// Text, whose heavier words need more room for the same lines.
        let width: CGFloat
        let boldWidth: CGFloat
        let height: CGFloat

        /// The compact tile font, headline: four lines, then three and two.
        static let compact = [
            TileFloor(width: 107, boldWidth: 118, height: 99),
            TileFloor(width: 114, boldWidth: 120, height: 78),
            TileFloor(width: 160, boldWidth: 170, height: 56),
        ]
        /// The regular tile font, title 2: four lines at the narrowest
        /// regular tile, three from 139 points (149 with Bold Text), two
        /// from 198 (213).
        static let regular = [
            TileFloor(width: 131, boldWidth: 146, height: 128),
            TileFloor(width: 139, boldWidth: 149, height: 100),
            TileFloor(width: 198, boldWidth: 213, height: 72),
        ]

        /// The floor for a tile `width` wide: the shortest of `floors` that
        /// applies there, and never under `profileFloor`.
        static func height(for width: CGFloat, in floors: [TileFloor], boldText: Bool, profileFloor: CGFloat) -> CGFloat {
            let applies = floors.filter { width >= (boldText ? $0.boldWidth : $0.width) - 0.001 }
            let height = applies.map(\.height).min() ?? floors.map(\.height).max() ?? profileFloor
            return max(profileFloor, height)
        }
    }

    // MARK: Results

    /// The window less its safe areas and Home's margins: where every slot
    /// lies, in the window's coordinates.
    let content: CGRect
    /// Whether Home has Phrases and Type, and with them the slot plan's own
    /// arrangements (`Modes`).
    let modes: Modes
    /// Three columns or five, chosen from the width.
    let isRegular: Bool
    let categoryArrangement: CategoryArrangement
    /// Every slot's frame, in the window's coordinates, leading edge first.
    private(set) var frames: [Slot: CGRect]
    private(set) var grid: Grid
    /// The height of each row of the safety row.
    private(set) var quickControlHeight: CGFloat
    /// The height of a category, Stop's well and, outside the band, Settings.
    private(set) var categoryHeight: CGFloat
    /// The gap between regions.
    let regionGap: CGFloat
    /// How much lower the categories sit than the gap alone would put
    /// them, so that a look resting in Stop's empty well meets Again or the
    /// category under it, never Yes: zero unless the safety row is short
    /// (docs/DECISIONS.md, "Get Attention and Stop on Home").
    private(set) var wellDrop: CGFloat
    /// Whether the starter library's largest category fits without
    /// scrolling: invariant 11 holds in this window at this text size.
    private(set) var startersFit: Bool
    /// How much taller the content would have to be for it to fit: zero
    /// when it does.
    private(set) var shortfall: CGFloat
    /// The room kept for Apple's keyboard (docs/DECISIONS.md, "Typing is a
    /// state of Home").
    let keyboard: KeyboardAllowance
    /// Whether the message, Phrases and Type (where Home has them) and the
    /// whole safety row end above the keyboard's room, so typing can leave
    /// them reachable.
    private(set) var bandClearsKeyboard: Bool
    /// False where Settings has room only for its gear.
    private(set) var settingsShowsName: Bool
    /// Settings' Back to Talking, which closes Settings onto Home, in the
    /// window's coordinates; `.null` without Phrases. It lies inside
    /// Phrases' frame, and every point of it is nearer Phrases, by centre
    /// and by edge, than any other control, so a look still resting on it
    /// once Settings closes meets Phrases, which does nothing while the
    /// phrases show (Settings always closes onto them). On compact widths
    /// it is Phrases' frame. On regular ones, where Phrases spans the two
    /// columns above Again and Get Attention, it is centred over Phrases,
    /// as tall, and at most one column wide, narrower on short windows: on
    /// the whole of Phrases, a look at a lower corner is nearer Get
    /// Attention's centre, or Again's, than Phrases' (docs/DECISIONS.md,
    /// "Typing on Home").
    private(set) var backToTalking: CGRect
    /// Whether the message is wide enough for the starter library's widest
    /// word at the default text size (`MinimumWidths.message`): the message
    /// steps down only as far as its widest word needs, never below the
    /// default size (AGENTS.md, *Words never break*). Where Home has Phrases
    /// and Type, false only on compact windows narrower than 345 points
    /// with Bold Text on, where the trailing column is as wide as
    /// Emergency's bold word; never where the message spans the width.
    private(set) var messageHoldsItsWords: Bool
    /// Whether every control above the phrase grid fits in the content,
    /// leaving the grid some height of its own. False only on a window too
    /// short for the safety row and categories at their floors.
    private(set) var controlsFit: Bool
    /// The slots a reserved region crosses.
    private(set) var slotsInReservedRegions: Set<Slot>

    /// Cells retained by the standard stacks before a local camera cut.
    private(set) var allocationFrames: [Slot: CGRect]
    /// An unsatisfied geometric constraint, never a hidden smaller target.
    private(set) var reservationIssues: [HomeReservedLayout.Issue]

    struct RegionGaps: Equatable, Sendable {
        var aToC: CGFloat
        var cToB: CGFloat
        var bToD: CGFloat
    }

    /// Complete resolved gaps, including the well's ordinary drop.
    var regionGaps: RegionGaps {
        let a = allocatedUnion([.message, .statusLine, .phrases, .type])
        let c = allocatedUnion(Slot.safetyRow)
        let b = allocatedUnion(Slot.categoriesRegion)
        return RegionGaps(aToC: c.minY - a.maxY, cToB: b.minY - c.maxY,
            bToD: allocation(.phraseGrid).minY - b.maxY)
    }

    /// A division through region A can move every row down together.
    /// Relative row gaps retain no record of that initial translation.
    /// Home consumes this inset before its first standard container.
    var firstRegionTopInset: CGFloat {
        allocation(.message).minY - content.minY
    }

    var safetyRowGap: CGFloat { rowGaps(in: Slot.safetyRow).first ?? 0 }
    var categoryRowGaps: [CGFloat] { rowGaps(in: Slot.categoriesRegion) }

    func allocation(_ slot: Slot) -> CGRect { allocationFrames[slot] ?? .null }

    func allocationHeight(of slots: [Slot]) -> CGFloat { allocationBounds(of: slots).height }

    func bounds(of slots: [Slot]) -> CGRect {
        slots.map(frame).filter { !$0.isNull }.reduce(CGRect.null) { $0.union($1) }
    }

    func allocationBounds(of slots: [Slot]) -> CGRect { allocatedUnion(slots) }

    func horizontalGap(from leading: Slot, to trailing: Slot) -> CGFloat {
        allocation(trailing).minX - allocation(leading).maxX
    }

    private func allocatedUnion(_ slots: [Slot]) -> CGRect {
        slots.map(allocation).filter { !$0.isNull }.reduce(CGRect.null) { $0.union($1) }
    }

    private func rowGaps(in slots: [Slot]) -> [CGFloat] {
        let frames = slots.map(allocation).filter { !$0.isNull }
        let tops = Set(frames.map(\.minY)).sorted()
        return zip(tops, tops.dropFirst()).map { top, next in
            next - (frames.filter { abs($0.minY - top) < 0.001 }.map(\.maxY).min() ?? top)
        }
    }

    /// The frame of `slot`, or `.null` for a slot this layout does not
    /// have (`slots`).
    func frame(_ slot: Slot) -> CGRect {
        frames[slot] ?? .null
    }

    /// The slots this layout has: all of them, but Phrases and Type only
    /// where there is typing to pick (`Modes`).
    var slots: [Slot] {
        modes == .phrasesAndTyping ? Slot.all : Slot.all.filter { $0 != .phrases && $0 != .type }
    }

    /// The slots of `slots` that are controls a person can activate, or
    /// Stop's well.
    var controls: [Slot] {
        Slot.controls.filter(slots.contains)
    }

    /// Whether Home offers Type: only where there is typing to pick and
    /// the message, Phrases, Type and the whole safety row end above the
    /// keyboard's room (`bandClearsKeyboard`), because typing never hides
    /// the call for help (AGENTS.md, *Design rules for dwell, switch and
    /// pointer input*). Elsewhere Type stays in its place, dimmed
    /// (docs/DECISIONS.md, "Typing on Home", *The keyboard's room,
    /// measured*).
    var offersTyping: Bool {
        modes == .phrasesAndTyping && bandClearsKeyboard
    }

    /// The category cells that show Clear and Put Back while typing
    /// (`TypingCells`).
    var typingCells: TypingCells {
        TypingCells(categoryArrangement)
    }

    /// How tall the region `slots` make up is, from its top to its foot:
    /// the height Home gives that region's stack.
    func height(of slots: [Slot]) -> CGFloat {
        slots.map(frame).filter { !$0.isNull }.reduce(CGRect.null) { $0.union($1) }.height
    }

    // MARK: The engine

    init(
        space: Space, profile: Profile = .touch, text: Text,
        largestCategory: Int = HomeLayout.referencePhraseCount, modes: Modes
    ) {
        self.init(unreservedSpace: Space(size: space.size, safeArea: space.safeArea),
            profile: profile, text: text, largestCategory: largestCategory, modes: modes)
        // A safe-area-only occlusion changes no interior allocation or
        // baseline diagnostic. Division presence still chooses even lanes,
        // including a zero-area or wholly edge-clipped reported frame.
        guard space.regions.contains(where: { $0.kind == .division || HomeReservedLayout.overlaps($0.frame, content) }) else { return }
        let resolved = HomeReservedLayout(base: self, space: space, profile: profile,
            text: text, largestCategory: largestCategory)
        allocationFrames = resolved.allocations
        frames = resolved.frames
        grid = resolved.grid
        reservationIssues = resolved.issues
        quickControlHeight = frame(.again).height
        categoryHeight = frame(.stop).height
        let safetyBottom = Slot.safetyRow.map(frame).map(\.maxY).max() ?? 0
        let band = [Slot.phrases, .type, .statusLine].map(frame).filter { !$0.isNull }
        bandClearsKeyboard = max(safetyBottom, band.map(\.maxY).max() ?? 0) <= keyboard.bandLimit + 0.001
        settingsShowsName = frame(.settings).width >= MinimumWidths.forBoldText(text.boldText).settings
        messageHoldsItsWords = frame(.message).width >= MinimumWidths.forBoldText(text.boldText).message
        controlsFit = allocation(.phraseGrid).minY <= content.maxY + 0.001 && reservationIssues.isEmpty
        let reference = grid.reflow(in: grid.frame, phraseCount: Self.referencePhraseCount)
        shortfall = reference.shortfall
        startersFit = shortfall <= 0.001
        backToTalking = resolved.backToTalking
        slotsInReservedRegions = Set(frames.filter { _, frame in
            space.reservedRegions.contains { Self.overlap($0, frame) }
        }.keys)
    }

    private init(
        unreservedSpace space: Space, profile: Profile, text: Text,
        largestCategory: Int, modes: Modes
    ) {
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
        self.modes = modes
        let width = content.width
        keyboard = KeyboardAllowance(windowSize: space.size)

        // Columns. Regular wherever five equal columns each hold the widest
        // word any of them carries; compact otherwise. The slot plan's
        // one-row safety row also needs Phrases and Type above Again and
        // Get Attention (`Modes`).
        let fifth = (width - 4 * spacing) / 5
        let isRegular = fifth >= minimum.regularColumn
        self.isRegular = isRegular
        let safetyInOneRow = isRegular && modes == .phrasesAndTyping

        // Widths across the content: the message, and A's trailing column,
        // which Emergency and Get Attention share under Phrases and Type,
        // with Yes and No each as wide as `lead`.
        let messageWidth: CGFloat
        let trailingWidth: CGFloat
        let lead: CGFloat
        if modes == .phrasesOnly {
            messageWidth = width
            trailingWidth = 0
            lead = 0
        } else if isRegular {
            messageWidth = 3 * fifth + 2 * spacing
            trailingWidth = 2 * fifth + spacing
            lead = fifth
        } else {
            // A third of the width, but never narrower than Emergency's word
            // and, where the message keeps its widest word beside it, wide
            // enough for "Get Attention" on one line: two lines would need
            // a taller safety row (`twoLineQuickControlHeight`), and Phrases
            // and Type above it would be as tall.
            let besideTheMessage = width - spacing - minimum.message
            trailingWidth = max(
                (width - 2 * spacing) / 3, minimum.compactTrailingColumn,
                min(minimum.getAttentionOneLine, besideTheMessage)
            )
            lead = max(0, width - 2 * spacing - trailingWidth) / 2
            messageWidth = 2 * lead + spacing
        }
        // Yes's and Again's widths in a two-row safety row: without typing,
        // two equal columns, with Yes and No sharing the leading one.
        let column = max(0, width - spacing) / 2
        let yesWidth = modes == .phrasesOnly ? max(0, column - spacing) / 2 : lead
        let againWidth = modes == .phrasesOnly ? column : messageWidth
        let getAttentionWidth = safetyInOneRow ? fifth
            : modes == .phrasesAndTyping ? trailingWidth : column

        // Floors: the profile's, or one line of the words at the person's
        // size with the label's inset, whichever is taller, so no label has
        // to step down to fit a height (Apple's audit reports that as text
        // that does not follow Dynamic Type). Where Get Attention is too
        // narrow for its words on one line, the safety row is tall enough
        // for two.
        let insets = 2 * Self.labelInset.vertical
        let getAttentionTakesTwoLines = getAttentionWidth < minimum.getAttentionOneLine - 0.001
        let quickFloor = max(
            profile.floor, text.quickControlLine + insets,
            getAttentionTakesTwoLines ? Self.twoLineQuickControlHeight : 0
        )
        let categoryFloor = max(profile.floor, text.categoryLine + insets)
        // Phrases and Type: one line of their words, which fit the trailing
        // column on one line wherever it is. Settings' Back to Talking sits
        // over Phrases (`backToTalking`), in the categories' font, so where
        // it is too narrow for its words on one line, Phrases is tall enough
        // for two.
        let backToTalkingWidth = isRegular ? fifth : trailingWidth
        let backToTalkingTakesTwoLines = backToTalkingWidth < minimum.backToTalkingOneLine - 0.001
        let modeFloor = max(
            profile.floor, text.quickControlLine + insets,
            backToTalkingTakesTwoLines ? Self.twoLineCategoryHeight : 0
        )
        let messageBlock = 2 * text.messageLine + Self.statusSpacing + text.statusLine
        // Phrases above Type, beside the message: two controls at their
        // floor, or the message's height if that is taller.
        let messageRegionFloor = modes == .phrasesAndTyping ? max(messageBlock, 2 * modeFloor + spacing) : messageBlock
        let quickRows = safetyInOneRow ? 1 : 2

        // The categories region's arrangement and widths.
        let categories = CategoryWidths(contentWidth: width, isRegular: isRegular, fifth: fifth, minimum: minimum)
        categoryArrangement = categories.arrangement
        settingsShowsName = categories.settings >= minimum.settings
        let categoryRows = categories.arrangement == .twoColumns ? 3 : 2

        // The phrase grid: fixed columns from the width, and the shortest
        // tile that holds the starter phrases at the tiles' width.
        let columns: Int
        if isRegular {
            let tileMinimum = text.boldText ? Self.regularTile.boldMinimumWidth : Self.regularTile.minimumWidth
            columns = (width - 3 * spacing) / 4 >= tileMinimum ? 4 : 3
        } else {
            let tileMinimum = text.boldText ? Self.compactTile.boldMinimumWidth : Self.compactTile.minimumWidth
            columns = (width - 2 * spacing) / 3 >= tileMinimum ? 3 : 2
        }
        let tileWidth = (width - CGFloat(columns - 1) * spacing) / CGFloat(columns)
        let tileFloor = TileFloor.height(
            for: tileWidth, in: isRegular ? Self.regularTile.floors : Self.compactTile.floors,
            boldText: text.boldText, profileFloor: profile.floor
        )
        let referenceRows = Grid.rows(for: Self.referencePhraseCount, columns: columns)

        func stack(_ rows: Int, of height: CGFloat) -> CGFloat {
            CGFloat(rows) * height + CGFloat(max(0, rows - 1)) * spacing
        }

        // Stop's well. Once Stop has gone, a look resting in the empty well
        // must meet Again above it or the category under it, never Yes, two
        // rows up (docs/DECISIONS.md, "Get Attention and Stop on Home").
        // Where the safety row is short, Yes's centre comes about as near
        // the well's top leading corner as theirs, so the categories sit
        // lower, half a point at a time, until Yes's centre is
        // `wellClearance` farther than theirs from every point of the
        // well's top edge, taken every quarter point. Yes comes nearest
        // there: wherever it is within a point of them, a look lower in
        // the well moves away from Yes faster than from Again, and nearer
        // the category. Between two of those points the margin can be at
        // most a quarter point smaller, still more than the half-point
        // tie. In one row Emergency is above the well, and Yes, beside it,
        // is always farther.
        func dropKeepingYesOffTheWell(quick: CGFloat, gap: CGFloat, category: CGFloat) -> CGFloat {
            guard !safetyInOneRow else { return 0 }
            // Centres from the well's top leading corner: Yes's and Again's
            // above it, the category's under it.
            let yes = CGPoint(x: yesWidth / 2, y: 1.5 * quick + spacing + gap)
            let again = CGPoint(x: againWidth / 2, y: quick / 2 + gap)
            let under = CGPoint(x: categories.category / 2, y: 1.5 * category + spacing)
            let steps = max(1, Int((categories.stop * 4).rounded(.up)))
            func yesIsNear(dropping drop: CGFloat) -> Bool {
                (0...steps).contains { step in
                    let x = categories.stop * CGFloat(step) / CGFloat(steps)
                    let toYes = hypot(x - yes.x, yes.y + drop)
                    let toAgain = hypot(x - again.x, again.y + drop)
                    let toUnder = hypot(x - under.x, under.y)
                    return toYes < min(toAgain, toUnder) + Self.wellClearance
                }
            }
            var drop: CGFloat = 0
            while yesIsNear(dropping: drop) && drop < content.height {
                drop += 0.5
            }
            return drop
        }

        // What the starter library needs at every floor, with the drop the
        // floors need. Growth only makes the drop smaller.
        let floorDrop = dropKeepingYesOffTheWell(quick: quickFloor, gap: Self.minimumRegionSpacing, category: categoryFloor)
        let needed = messageRegionFloor + stack(quickRows, of: quickFloor) + stack(categoryRows, of: categoryFloor)
            + stack(referenceRows, of: tileFloor) + 3 * Self.minimumRegionSpacing + floorDrop
        var spare = content.height - needed
        startersFit = spare >= -0.001
        shortfall = max(0, -spare)

        // Growth, in order, where there is room: the gaps between regions,
        // the safety row, Phrases and Type, the categories. The phrase grid
        // takes the rest.
        var gap = Self.minimumRegionSpacing
        var quick = quickFloor
        var messageRegion = messageRegionFloor
        var category = categoryFloor
        let quickTarget = max(quickFloor, profile.quickControlHeight(isRegular: isRegular))
        if spare > 0 {
            let gapGrowth = min(spare, 3 * (Self.regionSpacing - Self.minimumRegionSpacing))
            gap += gapGrowth / 3
            spare -= gapGrowth
            let quickGrowth = min(spare, CGFloat(quickRows) * (quickTarget - quickFloor))
            quick += quickGrowth / CGFloat(quickRows)
            spare -= quickGrowth
            if modes == .phrasesAndTyping {
                // Phrases and Type grow to the safety row's height, and the
                // message with them.
                let modeTarget = max(messageRegionFloor, 2 * max(modeFloor, quickTarget) + spacing)
                let modeGrowth = min(spare, modeTarget - messageRegionFloor)
                messageRegion += modeGrowth
                spare -= modeGrowth
            }
            let categoryTarget = max(categoryFloor, profile.categoryHeight(isRegular: isRegular))
            let categoryGrowth = min(spare, CGFloat(categoryRows) * (categoryTarget - categoryFloor))
            category += categoryGrowth / CGFloat(categoryRows)
            spare -= categoryGrowth
        }

        // The keyboard's room. Where Home has typing, growth never carries
        // the safety row into it: the rows give back what they grew first,
        // then the gaps. Without typing nothing on Home opens the keyboard,
        // so nothing is given back for it.
        let limit = keyboard.bandLimit
        var safetyBottom = content.minY + messageRegion + gap + stack(quickRows, of: quick)
        if modes == .phrasesAndTyping && safetyBottom > limit {
            // Phrases and Type give back what they grew first: the safety
            // row is the larger need.
            let modeCut = min(safetyBottom - limit, messageRegion - messageRegionFloor)
            messageRegion -= modeCut
            safetyBottom -= modeCut
            let quickCut = min(max(0, safetyBottom - limit), CGFloat(quickRows) * (quick - quickFloor))
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
        let drop = dropKeepingYesOffTheWell(quick: quick, gap: gap, category: category)
        wellDrop = drop

        // Frames, top to bottom.
        var frames: [Slot: CGRect] = [:]
        let x = content.minX
        let top = content.minY

        // A: the message and its status line, then Phrases above Type
        // where Home has them; otherwise the message spans the width.
        messageHoldsItsWords = messageWidth >= minimum.message
        let messageHeight = messageRegion - Self.statusSpacing - text.statusLine
        frames[.message] = CGRect(x: x, y: top, width: messageWidth, height: messageHeight)
        frames[.statusLine] = CGRect(x: x, y: top + messageHeight + Self.statusSpacing, width: messageWidth, height: text.statusLine)
        let trailingX = x + messageWidth + spacing
        if modes == .phrasesAndTyping {
            let modeHeight = (messageRegion - spacing) / 2
            frames[.phrases] = CGRect(x: trailingX, y: top, width: trailingWidth, height: modeHeight)
            frames[.type] = CGRect(x: trailingX, y: top + modeHeight + spacing, width: trailingWidth, height: modeHeight)
        }

        // C: the safety row.
        let safetyTop = top + messageRegion + gap
        let secondRow = safetyTop + quick + spacing
        if safetyInOneRow {
            let order: [Slot] = [.emergency, .yes, .no, .again, .getAttention]
            for (index, slot) in order.enumerated() {
                frames[slot] = CGRect(x: x + CGFloat(index) * (fifth + spacing), y: safetyTop, width: fifth, height: quick)
            }
        } else if modes == .phrasesAndTyping {
            frames[.yes] = CGRect(x: x, y: safetyTop, width: lead, height: quick)
            frames[.no] = CGRect(x: x + lead + spacing, y: safetyTop, width: lead, height: quick)
            frames[.emergency] = CGRect(x: trailingX, y: safetyTop, width: trailingWidth, height: quick)
            frames[.again] = CGRect(x: x, y: secondRow, width: messageWidth, height: quick)
            frames[.getAttention] = CGRect(x: trailingX, y: secondRow, width: trailingWidth, height: quick)
        } else {
            // Two equal columns: Yes and No share the leading one.
            let trailing = x + column + spacing
            frames[.yes] = CGRect(x: x, y: safetyTop, width: yesWidth, height: quick)
            frames[.no] = CGRect(x: x + yesWidth + spacing, y: safetyTop, width: yesWidth, height: quick)
            frames[.emergency] = CGRect(x: trailing, y: safetyTop, width: column, height: quick)
            frames[.again] = CGRect(x: x, y: secondRow, width: column, height: quick)
            frames[.getAttention] = CGRect(x: trailing, y: secondRow, width: column, height: quick)
        }

        // Settings' Back to Talking, over Phrases. On regular widths, a
        // point at its foot `dx` from Phrases' centre is nearer that centre
        // than Get Attention's (or, mirrored, Again's) while
        // dx < (a² + d² - d·h) / 2a, with Get Attention's centre `a` across
        // and `d` down from Phrases' and Phrases `h` tall; on short windows
        // that is narrower than a column. Two points short of it, for the
        // half point that counts as a tie.
        if let phrases = frames[.phrases], let again = frames[.again], let getAttention = frames[.getAttention] {
            if safetyInOneRow {
                let across = getAttention.midX - phrases.midX
                let down = again.midY - phrases.midY
                let reach = (across * across + down * down - down * phrases.height) / (2 * across)
                let width = min(backToTalkingWidth, 2 * (reach - 2))
                backToTalking = CGRect(x: phrases.midX - width / 2, y: phrases.minY, width: width, height: phrases.height)
            } else {
                backToTalking = phrases
            }
        } else {
            backToTalking = .null
        }

        // B: Stop's well, the categories and Settings, lower by the drop
        // that keeps Yes off the well.
        let categoriesTop = safetyTop + stack(quickRows, of: quick) + gap + drop
        for (slot, cell) in categories.cells(rowHeight: category, spacing: spacing) {
            frames[slot] = cell.offsetBy(dx: x, dy: categoriesTop)
        }

        // D: the phrase grid, in what is left.
        let gridTop = categoriesTop + stack(categoryRows, of: category) + gap
        let gridFrame = CGRect(x: x, y: gridTop, width: width, height: max(0, content.maxY - gridTop))
        frames[.phraseGrid] = gridFrame
        grid = Grid(frame: gridFrame, columns: columns, phraseCount: largestCategory, tileFloor: tileFloor, spacing: spacing)

        self.frames = frames
        allocationFrames = frames
        reservationIssues = []
        controlsFit = gridTop <= content.maxY + 0.001
        slotsInReservedRegions = Set(frames.filter { _, frame in
            space.reservedRegions.contains { Self.overlap($0, frame) }
        }.keys)
    }

    /// Whether two rectangles share some area; touching edges do not count.
    private static func overlap(_ a: CGRect, _ b: CGRect) -> Bool {
        !a.isEmpty && !b.isEmpty && a.minX < b.maxX && b.minX < a.maxX && a.minY < b.maxY && b.minY < a.maxY
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

        /// Every slot of the slot plan; a layout has all of them but Phrases
        /// and Type until Home has typing (`HomeLayout.slots`).
        static let all: [Slot] = [.message, .statusLine, .phrases, .type, .yes, .no, .emergency, .again, .getAttention, .stop]
            + (0..<HomeLayout.categoryCapacity).map { .category($0) } + [.settings, .phraseGrid]

        /// The slots that are controls a person can activate (or, for Stop,
        /// a well that holds one).
        static let controls: [Slot] = all.filter { ![.message, .statusLine, .phraseGrid].contains($0) }

        /// Region C, the safety row.
        static let safetyRow: [Slot] = [.yes, .no, .emergency, .again, .getAttention]

        /// Region B: Stop's well, the categories and Settings.
        static let categoriesRegion: [Slot] = [.stop] + (0..<HomeLayout.categoryCapacity).map { .category($0) } + [.settings]

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
    /// Settings. A category is directly under Stop in each.
    enum CategoryArrangement: Equatable, Sendable {
        /// Regular widths: Stop above the first category in the leading
        /// column, the other three and Settings at the band's full height.
        case band
        /// Stop, two categories; then two categories and Settings.
        case threeColumns
        /// Stop and a category; two categories; a category and Settings.
        case twoColumns
    }

    /// The two category cells that show the draft's Clear and Put Back
    /// while typing, by the categories' order (docs/DECISIONS.md, "Typing
    /// on Home"). The slot plan gives them category cells in region B,
    /// apart from each other, from Speak and from the draft. Placed by
    /// scoring held activations in every state (`HomeLayoutEngineTests`):
    /// never the cell under Stop's well, which a look held after Stop
    /// meets, nor the one beside it, which a look resting in the empty well
    /// meets; on three columns, Clear in the top row, away from the
    /// keyboard and the dimmed phrase grid, and Put Back in the bottom row,
    /// beside Settings. Each shows only while typing: browsing, the cell
    /// shows its category, as it always has.
    struct TypingCells: Equatable, Sendable {
        let clear: Int
        let putBack: Int

        init(_ arrangement: CategoryArrangement) {
            switch arrangement {
            // Stop, category 0, category 1; then category 2 (under Stop),
            // category 3, Settings.
            case .threeColumns: (clear, putBack) = (1, 3)
            // Stop, category 0; category 1 (under Stop), category 2;
            // category 3, Settings. The band: Stop above category 0, then
            // categories 1 (beside Stop) to 3 and Settings.
            case .twoColumns, .band: (clear, putBack) = (2, 3)
            }
        }
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
        /// Smallest column width for conservative legacy consumers.
        let tileSize: CGSize
        let scrolls: Bool
        let spacing: CGFloat
        let tileFloor: CGFloat
        /// Resolved, potentially unequal lanes, in `frame`'s coordinates.
        let columnFrames: [CGRect]

        var contentHeight: CGFloat { CGFloat(rows) * tileSize.height + CGFloat(max(0, rows - 1)) * spacing }
        var shortfall: CGFloat { max(0, contentHeight - frame.height) }

        init(frame: CGRect, columns: Int, phraseCount: Int, tileFloor: CGFloat, spacing: CGFloat) {
            let count = max(1, columns)
            let width = max(0, (frame.width - CGFloat(count - 1) * spacing) / CGFloat(count))
            let lanes = (0..<count).map {
                CGRect(x: frame.minX + CGFloat($0) * (width + spacing), y: frame.minY,
                    width: width, height: frame.height)
            }
            self.init(frame: frame, columnFrames: lanes, phraseCount: phraseCount, tileFloor: tileFloor, spacing: spacing)
        }

        init(frame: CGRect, columnFrames: [CGRect], phraseCount: Int, tileFloor: CGFloat, spacing: CGFloat) {
            self.frame = frame
            let lanes = columnFrames.isEmpty ? [CGRect(x: frame.minX, y: frame.minY, width: max(0, frame.width), height: max(0, frame.height))] : columnFrames
            self.columnFrames = lanes
            columns = lanes.count
            self.spacing = spacing
            self.tileFloor = tileFloor
            rows = Self.rows(for: phraseCount, columns: columns)
            let fitted = ((frame.height - CGFloat(rows - 1) * spacing) / CGFloat(rows) + 0.001).rounded(.down)
            scrolls = fitted < tileFloor
            tileSize = CGSize(width: lanes.map(\.width).min() ?? 0, height: scrolls ? tileFloor : fitted)
        }

        /// A warning may take viewport height, never reclaim a reserved
        /// camera strip or choose different column positions. The caller
        /// places the resolved viewport, then supplies its local frame.
        func reflow(in proposed: CGRect, phraseCount: Int) -> Grid {
            let viewport = CGRect(origin: proposed.origin,
                size: CGSize(width: max(0, min(frame.width, proposed.width)), height: max(0, min(frame.height, proposed.height))))
            let lanes = columnFrames.map {
                CGRect(x: viewport.minX + $0.minX - frame.minX, y: viewport.minY,
                    width: $0.width, height: viewport.height)
            }
            return Grid(frame: viewport, columnFrames: lanes, phraseCount: phraseCount, tileFloor: tileFloor, spacing: spacing)
        }

        static func rows(for count: Int, columns: Int) -> Int {
            max(1, (count + columns - 1) / columns)
        }

        func tile(row: Int, column: Int, scrollOffset: CGFloat = 0) -> CGRect {
            let lane = columnFrames[column]
            return CGRect(x: lane.minX, y: frame.minY + CGFloat(row) * (tileSize.height + spacing) - scrollOffset,
                width: lane.width, height: tileSize.height)
        }
    }

    // MARK: Widths

    /// The narrowest a control may be: its widest word at the default text
    /// size, with `WordFit.widthSlack` and the label inset, so the word is
    /// drawn whole at every text size; wider with Bold Text on, measured at
    /// the heaviest weight (`LabelFont.boldTextUIFontWeight`). Emergency and
    /// the categories, which show selected, have the wider side inset
    /// (`selectableSideInset`); the message has none. `StarterLabelFitTests`
    /// and `HomeLayoutEngineFontTests` check every one with the real fonts
    /// on CI, "Phrases" and "Type" (A's trailing column) and "Speak", which
    /// Again's slot shows while typing, among them.
    struct MinimumWidths: Equatable, Sendable {
        /// The message: the starter library's widest word in the message
        /// font, "understand.", with `WordFit.widthSlack`.
        let message: CGFloat
        let yesNo: CGFloat
        /// Again's slot: the wider of "Again" and "Speak".
        let again: CGFloat
        let emergency: CGFloat
        let getAttention: CGFloat
        /// "Get Attention" on one line; narrower, it takes two
        /// (`twoLineQuickControlHeight`).
        let getAttentionOneLine: CGFloat
        let phrases: CGFloat
        let type: CGFloat
        /// Settings' "Back to Talking" on one line, in the categories'
        /// font: it takes Phrases' frame (`backToTalking`).
        let backToTalkingOneLine: CGFloat
        let category: CGFloat
        let stop: CGFloat
        let settings: CGFloat
        let settingsSymbol: CGFloat

        static let regular = MinimumWidths(
            message: 156, yesNo: 46, again: 70, emergency: 120, getAttention: 100, getAttentionOneLine: 134,
            phrases: 90, type: 62, backToTalkingOneLine: 131,
            category: 122, stop: 52, settings: 80, settingsSymbol: 44
        )
        static let boldText = MinimumWidths(
            message: 175, yesNo: 48, again: 75, emergency: 130, getAttention: 110, getAttentionOneLine: 147,
            phrases: 98, type: 67, backToTalkingOneLine: 142,
            category: 132, stop: 56, settings: 86, settingsSymbol: 44
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

    /// Region B's widths: the band on regular widths, every cell a column; otherwise three columns
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
