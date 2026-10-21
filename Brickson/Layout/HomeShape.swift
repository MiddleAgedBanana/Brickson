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
    /// The gap between Home's regions: the message, the quick controls, the
    /// categories and the phrases.
    static let regionSpacing: CGFloat = 12
    /// The gap between controls inside a region. Smaller than the gap
    /// between regions, so each region reads as a group.
    static let controlSpacing: CGFloat = 8
    /// The room between a label and its control's edge (`HomeButtonStyle`).
    static let labelInset = (horizontal: CGFloat(4), vertical: CGFloat(6))

    /// Below this content width the categories sit two by two, the phrase
    /// tiles use the smaller tile font, and controls get the touch sizes.
    /// From this width up, four category buttons fit in one row, each holding
    /// "Conversation" at its default size (`StarterLabelFitTests`).
    static let regularMinimumWidth: CGFloat = 560
    /// Everyday categories with their own button. More than this scroll
    /// inside the category region; the starter library has exactly four.
    static let categoryCapacity = 4
    /// The narrowest phrase tile that holds the starter library's widest
    /// word at its default size on a narrow window: "understand." at 17pt is
    /// 97pt wide, plus `WordFit.widthSlack` and the label inset
    /// (`StarterLabelFitTests`). A window too narrow for three such tiles
    /// gets two columns, so no word breaks.
    static let minimumTileWidth: CGFloat = 107

    let isCompact: Bool
    let categoryColumns: Int
    let gridColumns: Int

    init(contentWidth: CGFloat) {
        isCompact = contentWidth < Self.regularMinimumWidth
        categoryColumns = isCompact ? 2 : 4
        let threeColumnTileWidth = (contentWidth - 2 * Self.controlSpacing) / 3
        gridColumns = threeColumnTileWidth >= Self.minimumTileWidth ? 3 : 2
    }

    /// The height of a quick control (Yes, No, Emergency) and of Again. On
    /// wide windows, AGENTS.md's quick-control floor for gaze (88pt); on
    /// narrow ones, a touch size that leaves the phrase grid room.
    var quickControlHeight: CGFloat { isCompact ? 64 : 88 }

    /// The height of a category button: the gaze floor (72pt) on wide
    /// windows, a touch size on narrow ones.
    var categoryHeight: CGFloat { isCompact ? 48 : 72 }

    /// The shortest phrase tile before the grid scrolls instead of shrinking
    /// it further. On narrow windows, the tallest starter phrase at the
    /// default size in the narrowest three-column tile: four lines of 17pt
    /// text (86.5pt) and the label inset (`StarterLabelFitTests`). On wide
    /// windows, AGENTS.md's phrase-tile floor for gaze (110pt).
    var minimumTileHeight: CGFloat { isCompact ? 99 : 110 }

    /// Rows of category buttons: enough for the capacity, whatever the
    /// library holds, so the region's height never follows the library.
    var categoryRows: Int {
        (Self.categoryCapacity + categoryColumns - 1) / categoryColumns
    }

    var categoryRegionHeight: CGFloat {
        CGFloat(categoryRows) * categoryHeight + CGFloat(categoryRows - 1) * Self.controlSpacing
    }

    /// Rows of phrase tiles: enough for the largest category, so a phrase
    /// tile keeps its place whichever category is showing (invariant 8).
    func gridRows(largestCategoryCount: Int) -> Int {
        max(1, (largestCategoryCount + gridColumns - 1) / gridColumns)
    }

    /// The widths of Yes, No and Emergency, in that order, across
    /// `contentWidth`. Emergency takes two shares: "Emergency" is the longest
    /// quick-control word, and a wide target is easy to find.
    static func quickControlWidths(contentWidth: CGFloat) -> [CGFloat] {
        let share = max(0, contentWidth - 2 * controlSpacing) / 4
        return [share, share, 2 * share]
    }
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
