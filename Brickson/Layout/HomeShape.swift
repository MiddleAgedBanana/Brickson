import Foundation

/// Where Home's controls go for the space the window gives it. Plain logic,
/// tested without a screen.
///
/// Every decision here comes from the width Home is given, never from which
/// device it runs on, so a phone, an iPad, a window beside another app or a
/// screen nobody has seen yet each get the arrangement that fits them. The
/// arrangement never depends on which category is showing, on what was
/// spoken, or on any warning (docs/LESSONS.md, "Positions are a pure
/// function of their inputs").
///
/// This is the stand-in Home's shape. The layout engine (docs/PORTING.md,
/// step 4) replaces these fixed sizes with each input profile's floors.
nonisolated struct HomeShape: Equatable, Sendable {
    /// The gap between Home's regions: the message, the safety row, the
    /// categories with Settings, and the phrases.
    static let regionSpacing: CGFloat = 12
    /// The gap between controls inside a region. Smaller than the gap
    /// between regions, so each region reads as a group.
    static let controlSpacing: CGFloat = 8
    /// The room between a label and its control's edge (`HomeButtonStyle`).
    static let labelInset = (horizontal: CGFloat(4), vertical: CGFloat(6))
    /// The room beside Emergency's words: as much as above and below them,
    /// which no ring reaches (`HomeButtonLook`). A label SwiftUI shrinks to
    /// fit spreads to its inset, and Emergency's, a column wide, does at the
    /// largest text sizes on a phone, where at the usual inset its last
    /// letter met the selection ring while the emergency phrases showed.
    /// The categories, also selected, keep the usual inset (docs/HANDOFF.md,
    /// *Known gaps*).
    static let emergencyLabelInset = labelInset.vertical

    /// Below this content width the phrase tiles use the smaller tile font
    /// and controls get the touch sizes. From this width up, controls get
    /// the gaze floors and the categories take one band of four, with Stop
    /// above the first, wherever four and Settings fit beside each other
    /// (`HomeShapeTests`).
    static let regularMinimumWidth: CGFloat = 560
    /// Everyday categories with a cell of their own. More than this share
    /// the last cell, which then scrolls; the starter library has exactly
    /// four.
    static let categoryCapacity = 4
    /// The narrowest phrase tile that holds the starter library's widest
    /// word at its default size on a narrow window: "understand." at 17pt is
    /// 97pt wide, plus `WordFit.widthSlack` and the label inset
    /// (`StarterLabelFitTests`). A window too narrow for three such tiles
    /// gets two columns, so no word breaks.
    static let minimumTileWidth: CGFloat = 107

    let isCompact: Bool
    let gridColumns: Int
    /// The height of a quick control (Yes, No, Emergency, Again and Get
    /// Attention): one line of its label at the person's text size, or the
    /// floor if that is taller. On wide windows the floor is AGENTS.md's
    /// quick-control floor for gaze (88pt); on narrow ones, a touch size
    /// that leaves the phrase grid room.
    let quickControlHeight: CGFloat
    /// The height of a category button, Stop and Settings: one line of a
    /// category's label at the person's text size, or the floor: the gaze
    /// floor (72pt) on wide windows, a touch size on narrow ones.
    let categoryHeight: CGFloat

    /// The safety row is two rows of two equal columns on every window:
    /// Yes and No sharing the leading column, then Emergency; under them
    /// Again, then Get Attention, directly under Emergency. The width of
    /// Yes and of No.
    let yesNoWidth: CGFloat
    /// Emergency, Again and Get Attention each take a column.
    let emergencyWidth: CGFloat
    let againWidth: CGFloat
    let getAttentionWidth: CGFloat

    /// Where the categories, Stop's well and Settings go.
    let categoryArrangement: CategoryArrangement
    /// The width of every category button.
    let categoryWidth: CGFloat
    /// The width of Stop's well.
    let stopWidth: CGFloat
    let settingsWidth: CGFloat
    /// False where Settings has room only for its gear. Its name stays its
    /// accessibility label (docs/DECISIONS.md, "Settings on Home").
    let settingsShowsName: Bool

    /// `quickControlLineHeight` and `categoryLineHeight` are the heights of
    /// one line of those labels at the person's text size
    /// (`LabelFont.lineHeight(at:)`). A control grows to hold one line, so a
    /// short word like "No" keeps the person's own size instead of stepping
    /// down to fit a fixed height, which Apple's accessibility audit reports
    /// as text that does not follow Dynamic Type. `boldText` is the person's
    /// Bold Text setting: its heavier words need wider controls
    /// (`MinimumWidths`).
    init(
        contentWidth: CGFloat,
        quickControlLineHeight: CGFloat = 0,
        categoryLineHeight: CGFloat = 0,
        boldText: Bool = false
    ) {
        let spacing = Self.controlSpacing
        let minimum = MinimumWidths.forBoldText(boldText)
        isCompact = contentWidth < Self.regularMinimumWidth
        let threeColumnTileWidth = (contentWidth - 2 * spacing) / 3
        gridColumns = threeColumnTileWidth >= Self.minimumTileWidth ? 3 : 2
        let insets = 2 * Self.labelInset.vertical
        quickControlHeight = max(isCompact ? 64 : 88, quickControlLineHeight + insets)
        categoryHeight = max(isCompact ? 48 : 72, categoryLineHeight + insets)

        // Two equal columns. Get Attention sits in the second row, never in
        // the first: the message spans the full width above the first row,
        // and a look resting on it must never meet an alarm. Emergency, at
        // the first row's trailing end, is under Settings' Back to Talking,
        // and Get Attention directly under Emergency (docs/DECISIONS.md,
        // "Get Attention and Stop on Home").
        let column = max(0, contentWidth - spacing) / 2
        yesNoWidth = max(0, column - spacing) / 2
        emergencyWidth = column
        againWidth = column
        getAttentionWidth = column

        // Wide windows try the slot plan's band first: Stop above the first
        // category, the other three and Settings at the band's full height,
        // every cell the same width where the categories keep their
        // minimum, otherwise Settings at the minimum for its word and the
        // categories sharing the rest. Short of that, three columns: Stop
        // and two categories, then two categories and Settings, the
        // categories at least at their minimum, Stop and Settings taking
        // what is left (Settings showing its gear alone where its word does
        // not fit). Where that leaves Stop too little, two columns of three
        // rows. A category is directly under Stop in every arrangement.
        var chosen: (CategoryArrangement, category: CGFloat, stop: CGFloat, settings: CGFloat)?
        if !isCompact {
            let equal = (contentWidth - 4 * spacing) / 5
            let shared = (contentWidth - 4 * spacing - minimum.settings) / 4
            if equal >= minimum.category {
                chosen = (.band, equal, equal, equal)
            } else if shared >= minimum.category {
                chosen = (.band, shared, shared, minimum.settings)
            }
        }
        if chosen == nil {
            let category = max(minimum.category, (contentWidth - 2 * spacing) / 3)
            let rest = contentWidth - 2 * spacing - 2 * category
            if rest >= max(minimum.stop, minimum.settingsSymbol) {
                chosen = (.threeColumns, category, rest, rest)
            } else {
                let half = max(0, contentWidth - spacing) / 2
                chosen = (.twoColumns, half, half, half)
            }
        }
        let arrangement = chosen ?? (.twoColumns, 0, 0, 0)
        categoryArrangement = arrangement.0
        categoryWidth = arrangement.category
        stopWidth = arrangement.stop
        settingsWidth = arrangement.settings
        settingsShowsName = settingsWidth >= minimum.settings
    }

    /// The shortest phrase tile before the grid scrolls instead of shrinking
    /// it further. On narrow windows, the tallest starter phrase at the
    /// default size in the narrowest three-column tile: four lines of 17pt
    /// text (86.5pt) and the label inset (`StarterLabelFitTests`). On wide
    /// windows, AGENTS.md's phrase-tile floor for gaze (110pt).
    var minimumTileHeight: CGFloat { isCompact ? 99 : 110 }

    /// Two rows of quick controls on every window.
    var safetyRegionHeight: CGFloat {
        2 * quickControlHeight + Self.controlSpacing
    }

    /// The categories, Stop's well and Settings: the same rows whatever the
    /// library holds, so the region's height never follows the library.
    var categoryRegionHeight: CGFloat {
        switch categoryArrangement {
        case .band, .threeColumns: 2 * categoryHeight + Self.controlSpacing
        case .twoColumns: 3 * categoryHeight + 2 * Self.controlSpacing
        }
    }

    /// In the band, every cell but Stop's and the first category's is as
    /// tall as the region; elsewhere, as tall as one category button.
    var fullCellHeight: CGFloat {
        switch categoryArrangement {
        case .band: categoryRegionHeight
        case .threeColumns, .twoColumns: categoryHeight
        }
    }

    /// Rows of phrase tiles: enough for the largest category, so a phrase
    /// tile keeps its place whichever category is showing (invariant 8).
    func gridRows(largestCategoryCount: Int) -> Int {
        max(1, (largestCategoryCount + gridColumns - 1) / gridColumns)
    }

    /// Every slot of the safety row and the categories region, in one
    /// space whose origin is the safety row's top leading corner, with the
    /// categories `regionSpacing` below it. `HomeView` builds the same
    /// arrangement from stacks; the unit tests score what a held look meets
    /// on these frames at every width, and the UI tests on the app's.
    var slotFrames: [Slot: CGRect] {
        let spacing = Self.controlSpacing
        let quick = quickControlHeight
        let secondRow = quick + spacing
        var frames: [Slot: CGRect] = [
            .yes: CGRect(x: 0, y: 0, width: yesNoWidth, height: quick),
            .no: CGRect(x: yesNoWidth + spacing, y: 0, width: yesNoWidth, height: quick),
            .emergency: CGRect(x: againWidth + spacing, y: 0, width: emergencyWidth, height: quick),
            .again: CGRect(x: 0, y: secondRow, width: againWidth, height: quick),
            .getAttention: CGRect(x: againWidth + spacing, y: secondRow, width: getAttentionWidth, height: quick),
        ]
        let top = safetyRegionHeight + Self.regionSpacing
        let row = categoryHeight + spacing
        let category = categoryWidth
        func cell(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> CGRect {
            CGRect(x: x, y: top + y, width: width, height: height)
        }
        switch categoryArrangement {
        case .band:
            frames[.stop] = cell(0, 0, stopWidth, categoryHeight)
            frames[.category(0)] = cell(0, row, category, categoryHeight)
            for index in 1..<Self.categoryCapacity {
                frames[.category(index)] = cell(CGFloat(index) * (category + spacing), 0, category, fullCellHeight)
            }
            frames[.settings] = cell(CGFloat(Self.categoryCapacity) * (category + spacing), 0, settingsWidth, fullCellHeight)
        case .threeColumns:
            frames[.stop] = cell(0, 0, stopWidth, categoryHeight)
            frames[.category(0)] = cell(stopWidth + spacing, 0, category, categoryHeight)
            frames[.category(1)] = cell(stopWidth + category + 2 * spacing, 0, category, categoryHeight)
            frames[.category(2)] = cell(0, row, category, categoryHeight)
            frames[.category(3)] = cell(category + spacing, row, category, categoryHeight)
            frames[.settings] = cell(2 * (category + spacing), row, settingsWidth, categoryHeight)
        case .twoColumns:
            let slots: [Slot] = [.stop, .category(0), .category(1), .category(2), .category(3), .settings]
            for (index, slot) in slots.enumerated() {
                frames[slot] = cell(
                    CGFloat(index % 2) * (category + spacing), CGFloat(index / 2) * row, category, categoryHeight
                )
            }
        }
        return frames
    }

    /// A place on Home with a stable identity (docs/DECISIONS.md, "Home's
    /// slot plan"): the same slot whatever it shows.
    enum Slot: Hashable, Sendable {
        case yes, no, emergency, again, getAttention
        case stop
        /// An everyday category's cell, from 0 in the library's order.
        case category(Int)
        case settings
    }

    /// How the categories region holds Stop's well, the four category
    /// cells and Settings. A category is directly under Stop in each, so a
    /// look still resting where Stop was meets one, which only changes
    /// which phrases show (invariant 10).
    enum CategoryArrangement: Equatable, Sendable {
        /// Wide windows: Stop above the first category, then the other
        /// three and Settings at the band's full height.
        case band
        /// Stop, two categories; then two categories and Settings.
        case threeColumns
        /// Stop and a category; two categories; a category and Settings.
        case twoColumns
    }

    /// The narrowest a control may be: its widest word at the default text
    /// size, with `WordFit.widthSlack` and the label inset (Emergency's own,
    /// `emergencyLabelInset`, for Emergency), so the word is
    /// drawn whole at every text size (labels step down to the default, never
    /// below). Measured on CI with the real fonts (`StarterLabelFitTests`),
    /// and wider with Bold Text on, which is measured at the heaviest weight
    /// (`LabelFont.boldTextUIFontWeight`). "Conversation" is the widest
    /// starter category name, "Yes" the wider of Yes and No, "Attention"
    /// Get Attention's wider word (it takes two lines where both do not
    /// fit on one). Settings' gear alone gets Apple's 44pt minimum target,
    /// which holds the gear at the default size.
    struct MinimumWidths: Equatable, Sendable {
        let yesNo: CGFloat
        let again: CGFloat
        let emergency: CGFloat
        let getAttention: CGFloat
        let category: CGFloat
        let stop: CGFloat
        let settings: CGFloat
        let settingsSymbol: CGFloat

        static let regular = MinimumWidths(
            yesNo: 46, again: 64, emergency: 120, getAttention: 100,
            category: 118, stop: 52, settings: 80, settingsSymbol: 44
        )
        static let boldText = MinimumWidths(
            yesNo: 48, again: 70, emergency: 130, getAttention: 110,
            category: 128, stop: 56, settings: 86, settingsSymbol: 44
        )

        static func forBoldText(_ boldText: Bool) -> MinimumWidths {
            boldText ? .boldText : .regular
        }
    }

    /// The narrowest content width Home plans for: a 320pt window, an iPad
    /// app in Slide Over, less Home's margins.
    static let narrowestContentWidth: CGFloat = 288
}

/// How tall phrase tiles are in the space left for the grid.
nonisolated struct GridSizing: Equatable, Sendable {
    let tileHeight: CGFloat
    /// True when the tiles would be shorter than the minimum: the grid then
    /// scrolls with tiles at the minimum height instead.
    let scrolls: Bool

    init(availableHeight: CGFloat, rows: Int, spacing: CGFloat, minimumTileHeight: CGFloat) {
        let rows = max(1, rows)
        let fitted = (availableHeight - CGFloat(rows - 1) * spacing) / CGFloat(rows)
        if fitted >= minimumTileHeight {
            tileHeight = fitted.rounded(.down)
            scrolls = false
        } else {
            tileHeight = minimumTileHeight
            scrolls = true
        }
    }
}
