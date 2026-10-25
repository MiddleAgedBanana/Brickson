import Foundation

/// Where Settings' first screen puts its Family Setup row and the note
/// about it, from the width the screen gives them. Plain logic, tested
/// without a screen; `SettingsRootLayout` measures the two views and places
/// them here.
///
/// Where each of two equal columns holds the row's words on one line, the
/// note takes the leading half and the row the trailing half, the side
/// Home's Settings is on. A look resting where Home's Settings was then
/// meets the row, which only navigates, not Back to Talking
/// (docs/DECISIONS.md, "Settings on Home"). Elsewhere, as on a phone, the
/// row spans the width with the note under it, so its words stay whole.
///
/// Each view is laid out once, at every text size. Apple's accessibility
/// audit grows the text and compares each text with itself; an earlier
/// version that chose with `ViewThatFits` and a hidden copy of the row was
/// reported as clipped text belonging to no element on the phone (CI on
/// PR #33), as labels built with `ViewThatFits` had been (`WordFit`).
nonisolated struct SettingsRootColumns: Equatable, Sendable {
    /// Frames from the top leading corner of the content.
    let row: CGRect
    let note: CGRect

    /// - Parameters:
    ///   - width: the width the screen gives its content.
    ///   - spacing: the gap between the columns, and between the row and
    ///     the note: Settings' gap between its rows.
    ///   - rowIdealWidth: the row with its words on one line.
    ///   - rowHeight: the row's height at a width.
    ///   - noteHeight: the note's height at a width.
    init(
        width: CGFloat,
        spacing: CGFloat,
        rowIdealWidth: CGFloat,
        rowHeight: (CGFloat) -> CGFloat,
        noteHeight: (CGFloat) -> CGFloat
    ) {
        let column = (width - spacing) / 2
        if column >= rowIdealWidth {
            row = CGRect(x: column + spacing, y: 0, width: column, height: rowHeight(column))
            note = CGRect(x: 0, y: 0, width: column, height: noteHeight(column))
        } else {
            let rowHeight = rowHeight(width)
            row = CGRect(x: 0, y: 0, width: width, height: rowHeight)
            note = CGRect(x: 0, y: rowHeight + spacing, width: width, height: noteHeight(width))
        }
    }

    /// The row and the note side by side.
    var isTwoColumns: Bool { row.minX > note.minX }

    /// The whole content: the width it was given, as tall as the taller
    /// column, or as both when stacked.
    var size: CGSize {
        CGSize(width: max(row.maxX, note.maxX), height: max(row.maxY, note.maxY))
    }
}
