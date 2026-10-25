import Foundation

/// Where a Settings screen puts the words about its first control, from
/// the control's frame and the width the screen gives them. Plain logic,
/// tested without a screen; `SettingsLeadInLayout` measures the two views
/// and places them here.
///
/// The control's frame comes first, chosen for a look still resting where
/// the last control was (AGENTS.md, invariant 10). On Settings' first
/// screen it is the Family Setup row, where `SettingsRowPlace` puts it from
/// Home's frames; on Family Setup it is Set Up Step by Step, in that row's
/// own frame and at least as tall (`control(inPlaceOf:width:height:)`), so
/// a look still resting where the row was meets a row that only opens the
/// next screen (docs/DECISIONS.md, "Settings' first row, placed from
/// Home's frames").
/// The words go beside the control where the room at its leading side is
/// at least as wide as the control's words on one line, so they read as
/// its label; elsewhere above it where they fit between the top of the
/// content and the control, and under it where they do not.
///
/// Each view is laid out once, at every text size. Apple's accessibility
/// audit grows the text and compares each text with itself; an earlier
/// version that chose with `ViewThatFits` and a hidden copy of the row was
/// reported as clipped text belonging to no element on the phone (CI on
/// PR #33), as labels built with `ViewThatFits` had been (`WordFit`).
nonisolated struct SettingsLeadIn: Equatable, Sendable {
    /// Frames from the top leading corner of the content.
    let control: CGRect
    let words: CGRect

    /// - Parameters:
    ///   - width: the width the screen gives its content.
    ///   - spacing: the gap between the control and the words: Settings'
    ///     gap between its rows.
    ///   - control: the control's frame in the content. Never above it.
    ///   - besideWidth: the least room beside the control for the words.
    ///   - wordsHeight: the words' height at a width.
    init(width: CGFloat, spacing: CGFloat, control: CGRect, besideWidth: CGFloat, wordsHeight: (CGFloat) -> CGFloat) {
        let control = control.offsetBy(dx: 0, dy: max(0, -control.minY))
        self.control = control
        let room = control.minX - spacing
        if room > 0, room >= besideWidth {
            words = CGRect(x: 0, y: control.minY, width: room, height: wordsHeight(room))
        } else {
            let wordsHeight = wordsHeight(width)
            let fitsAbove = wordsHeight + spacing <= control.minY
            words = CGRect(x: 0, y: fitsAbove ? 0 : control.maxY + spacing, width: width, height: wordsHeight)
        }
    }

    /// Family Setup's Set Up Step by Step, in the place of the row that
    /// opened it: the same leading edge, top and width, within `width`, and
    /// at least as tall, growing downward where its own words need more
    /// lines. Both frames are in their screens' content.
    static func control(inPlaceOf row: CGRect, width: CGFloat, height: (CGFloat) -> CGFloat) -> CGRect {
        let controlWidth = min(row.width, width)
        return CGRect(
            x: min(max(0, row.minX), width - controlWidth), y: row.minY,
            width: controlWidth, height: max(row.height, height(controlWidth))
        )
    }

    /// The words beside the control.
    var isTwoColumns: Bool { control.minX > words.minX && words.maxX <= control.minX }

    /// Whether the words come before the control, above it or beside it.
    var wordsLead: Bool { words.minY <= control.minY }

    /// The whole content: the width it was given, down to the lower of the
    /// two.
    var size: CGSize {
        CGSize(width: max(control.maxX, words.maxX), height: max(control.maxY, words.maxY))
    }
}
