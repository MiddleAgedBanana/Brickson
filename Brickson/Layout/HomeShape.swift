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

    /// Below this content width the categories sit two by two, the phrase
    /// tiles use the smaller tile font, and controls get the touch sizes.
    /// From this width up, controls get the gaze floors and the categories
    /// take one row of four wherever four and Settings fit beside each other
    /// (from 584pt; `HomeShapeTests`).
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
    let gridColumns: Int
    /// The height of a quick control (Yes, No, Again and Emergency): one
    /// line of its label at the person's text size, or the floor if that is
    /// taller. On wide windows the floor is AGENTS.md's quick-control floor
    /// for gaze (88pt); on narrow ones, a touch size that leaves the phrase
    /// grid room.
    let quickControlHeight: CGFloat
    /// The height of a category button: one line of its label at the
    /// person's text size, or the floor: the gaze floor (72pt) on wide
    /// windows, a touch size on narrow ones.
    let categoryHeight: CGFloat

    /// How the safety row holds Yes, No, Again and Emergency.
    let safetyRow: SafetyRow
    /// The width of Yes and of No.
    let yesNoWidth: CGFloat
    let againWidth: CGFloat
    let emergencyWidth: CGFloat

    /// Category buttons in a row: four on wide windows where they and
    /// Settings fit, otherwise two.
    let categoryColumns: Int
    /// The width of every category button.
    let categoryWidth: CGFloat
    /// Where Settings sits in the categories region.
    let settingsPlacement: SettingsPlacement
    let settingsWidth: CGFloat
    /// False where Settings beside the categories has room only for its
    /// gear: from 296pt of content up to 332pt (with Bold Text, 316pt up
    /// to 358pt, which takes in a 375pt phone). Its name stays its
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

        // One row of five columns, Emergency across two, wherever Emergency
        // and Again keep their minimums. Short of that, Again and Emergency
        // at their minimums and Yes and No, the shortest words, sharing the
        // rest, so a second row never takes a phrase row's height while Yes
        // and No still fit. Otherwise Yes, No and Emergency in a row of four
        // columns, Emergency across two, and Again across the row under them.
        let share = max((contentWidth - 4 * spacing) / 5, minimum.again)
        let wideEmergency = contentWidth - 3 * spacing - 3 * share
        let narrowYesNo = (contentWidth - 3 * spacing - minimum.again - minimum.emergency) / 2
        if wideEmergency >= minimum.emergency {
            safetyRow = .oneRow
            yesNoWidth = share
            againWidth = share
            emergencyWidth = wideEmergency
        } else if narrowYesNo >= minimum.yesNo {
            safetyRow = .oneRow
            yesNoWidth = narrowYesNo
            againWidth = minimum.again
            emergencyWidth = minimum.emergency
        } else {
            let quarter = max(0, contentWidth - 3 * spacing) / 4
            safetyRow = .twoRows
            yesNoWidth = quarter
            againWidth = contentWidth
            emergencyWidth = 2 * quarter + spacing
        }

        // Settings in a column after the categories: every cell the same
        // width where the categories keep their minimum, otherwise Settings
        // at its minimum and the categories sharing the rest. Wide windows
        // try four categories in a row first. Where the word does not fit,
        // Settings at the minimum for its gear alone, because a row of its
        // own would take a phrase row's height. Where even that does not
        // fit, Settings takes a row of its own under two columns of
        // categories.
        var band: (columns: Int, category: CGFloat, settings: CGFloat)?
        search: for settingsMinimum in [minimum.settings, minimum.settingsSymbol] {
            for columns in isCompact ? [2] : [4, 2] {
                let count = CGFloat(columns)
                let equal = (contentWidth - count * spacing) / (count + 1)
                let shared = (contentWidth - count * spacing - settingsMinimum) / count
                if equal >= minimum.category {
                    band = (columns, equal, equal)
                } else if shared >= minimum.category {
                    band = (columns, shared, settingsMinimum)
                }
                if band != nil { break search }
            }
        }
        if let band {
            categoryColumns = band.columns
            categoryWidth = band.category
            settingsPlacement = .beside
            settingsWidth = band.settings
        } else {
            categoryColumns = 2
            categoryWidth = max(0, contentWidth - spacing) / 2
            settingsPlacement = .below
            settingsWidth = contentWidth
        }
        settingsShowsName = settingsWidth >= minimum.settings
    }

    /// The shortest phrase tile before the grid scrolls instead of shrinking
    /// it further. On narrow windows, the tallest starter phrase at the
    /// default size in the narrowest three-column tile: four lines of 17pt
    /// text (86.5pt) and the label inset (`StarterLabelFitTests`). On wide
    /// windows, AGENTS.md's phrase-tile floor for gaze (110pt).
    var minimumTileHeight: CGFloat { isCompact ? 99 : 110 }

    var safetyRegionHeight: CGFloat {
        switch safetyRow {
        case .oneRow: quickControlHeight
        case .twoRows: 2 * quickControlHeight + Self.controlSpacing
        }
    }

    /// Rows of category buttons: enough for the capacity, whatever the
    /// library holds, so the region's height never follows the library.
    var categoryRows: Int {
        (Self.categoryCapacity + categoryColumns - 1) / categoryColumns
    }

    /// The category buttons' part of the region: the part that scrolls
    /// when a library has more categories than the capacity.
    var categoryGridHeight: CGFloat {
        CGFloat(categoryRows) * categoryHeight + CGFloat(categoryRows - 1) * Self.controlSpacing
    }

    var categoryGridWidth: CGFloat {
        CGFloat(categoryColumns) * categoryWidth + CGFloat(categoryColumns - 1) * Self.controlSpacing
    }

    /// Beside the categories, Settings is as tall as all their rows; on its
    /// own row, as tall as one category button.
    var settingsHeight: CGFloat {
        switch settingsPlacement {
        case .beside: categoryGridHeight
        case .below: categoryHeight
        }
    }

    /// The categories and Settings.
    var categoryRegionHeight: CGFloat {
        switch settingsPlacement {
        case .beside: categoryGridHeight
        case .below: categoryGridHeight + Self.controlSpacing + categoryHeight
        }
    }

    /// Rows of phrase tiles: enough for the largest category, so a phrase
    /// tile keeps its place whichever category is showing (invariant 8).
    func gridRows(largestCategoryCount: Int) -> Int {
        max(1, (largestCategoryCount + gridColumns - 1) / gridColumns)
    }

    /// How the safety row is arranged. The order on screen is chosen so that
    /// Emergency, which only shows the emergency phrases, is the control at
    /// the row's trailing end, under Settings' Back to Talking: a look still
    /// resting there after Settings closes meets Emergency, never something
    /// that speaks (invariant 10; docs/DECISIONS.md, "Settings on Home").
    enum SafetyRow: Equatable, Sendable {
        /// Yes, No, Again, Emergency.
        case oneRow
        /// Yes, No, Emergency; then Again across the width.
        case twoRows
    }

    enum SettingsPlacement: Equatable, Sendable {
        /// The last column, after the categories, as tall as their rows.
        case beside
        /// A row of its own under the categories.
        case below
    }

    /// The narrowest a control may be: its starter word at the default text
    /// size, with `WordFit.widthSlack` and the label inset, so the word is
    /// drawn whole at every text size (labels step down to the default, never
    /// below). Measured on CI with the real fonts (`StarterLabelFitTests`),
    /// and wider with Bold Text on, which is measured at the heaviest weight
    /// (`LabelFont.boldTextUIFontWeight`). "Conversation" is the widest
    /// starter category name, "Yes" the wider of Yes and No. Settings' gear
    /// alone gets Apple's 44pt minimum target, which holds the gear at the
    /// default size.
    struct MinimumWidths: Equatable, Sendable {
        let yesNo: CGFloat
        let again: CGFloat
        let emergency: CGFloat
        let category: CGFloat
        let settings: CGFloat
        let settingsSymbol: CGFloat

        static let regular = MinimumWidths(
            yesNo: 46, again: 64, emergency: 116, category: 118, settings: 80, settingsSymbol: 44
        )
        static let boldText = MinimumWidths(
            yesNo: 48, again: 70, emergency: 126, category: 128, settings: 86, settingsSymbol: 44
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
