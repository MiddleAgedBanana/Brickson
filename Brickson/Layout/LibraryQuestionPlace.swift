import Foundation

/// Where a Library question screen puts its way back, its words and its
/// choices, from the frame of the row that opened it. Plain logic, tested
/// without a screen (docs/DECISIONS.md, "The Library's question screens").
///
/// Delete, Move, Change Picture and a chosen backup each ask on a screen of
/// their own, opened by a row that only opens it. Under AssistiveTouch
/// Dwell, head tracking or Eye Tracking the pointer rests where that row
/// was as the question appears, and a held look can choose whatever is now
/// nearest. So the way back (Keep Phrase, Keep Category, Leave It Here,
/// Keep This Picture, Cancel) takes the row's place, in the window, and is
/// at least as tall: a repeated activation meets it and goes back, and Keep
/// takes the asking control's place (AGENTS.md, invariants 3 and 10). The
/// words go just under it. Above it they reached toward the top of the
/// screen, where Back to Talking closes Settings: on the phone and the
/// iPad a look resting on their top was nearer Back to Talking than the
/// way back, which this type cannot see from the content. The choices that
/// change something start at least a row's height below both, and lower
/// still where a look resting anywhere on the way back, the words or the
/// gap around the row would otherwise be nearer the first choice than the
/// way back, by centre or by edge, with `SettingsRowPlace.margin` to spare
/// (`SetupAnswersPlace`). Lower choices are farther still. Where they
/// start below what shows, the family scrolls to them, which costs a dwell
/// user several activations: here that cost protects the person.
///
/// A row that is the last control of its screen is nearest every point
/// below it, so a look resting anywhere under it opens its question, and
/// any choice under the way back would be nearer some of those points.
/// So its question puts the choices above the way back, a row and a gap
/// clear of it. Where the choices do not fit
/// above, they go below every point down to the foot of what shows.
///
/// Every frame is in the question screen's content, from its top leading
/// corner, as the screen first shows, unscrolled.
nonisolated struct LibraryQuestionPlace: Equatable, Sendable {
    let back: CGRect
    let words: CGRect
    /// The first choice's top. Each choice after it follows the one before.
    let choicesTop: CGFloat

    /// - Parameters:
    ///   - row: the row that opened the screen, in this screen's content;
    ///     nil where it was not measured, which puts the way back at the
    ///     top.
    ///   - rowIsLast: the row is the last control of its screen, with
    ///     nothing under it but words.
    ///   - width: the width the screen gives its content.
    ///   - visibleHeight: how much of the content shows without
    ///     scrolling. The way back is kept within it. Nil before the
    ///     screen has measured where it sits: the way back is then kept
    ///     at the row, and a last row's choices that do not fit above go
    ///     below its words, until the measured height places them.
    ///   - backHeight: the way back's height at a width.
    ///   - wordsHeight: the words' height at a width.
    ///   - choicesHeight: the choices' height, all together, at a width.
    ///   - spacing: the gap between the way back and the words, Settings'
    ///     gap between rows.
    ///   - rowHeight: a choice's least height, and the least gap between
    ///     the way back or the words and the first choice.
    init(
        row: CGRect?, rowIsLast: Bool = false, width: CGFloat, visibleHeight: CGFloat?,
        backHeight: (CGFloat) -> CGFloat, wordsHeight: (CGFloat) -> CGFloat,
        choicesHeight: (CGFloat) -> CGFloat = { _ in 0 },
        spacing: CGFloat, rowHeight: CGFloat
    ) {
        let backWidth = min(row.map(\.width) ?? width, width)
        let height = max(row?.height ?? 0, backHeight(backWidth))
        let lowestTop = visibleHeight.map { max(0, $0 - height) } ?? .infinity
        let top = min(max(0, row?.minY ?? 0), lowestTop)
        let minX = min(max(0, row?.minX ?? 0), width - backWidth)
        let back = CGRect(x: minX, y: top, width: backWidth, height: height)
        self.back = back

        let under = CGRect(x: 0, y: back.maxY + spacing, width: width, height: wordsHeight(width))
        words = under
        // The first top at which every point of `arrivals` is nearer the
        // way back than the first choice.
        let below = { (arrivals: [CGRect]) -> CGFloat in
            SetupAnswersPlace(
                arrivals: arrivals, link: back,
                answersMinX: 0, answersWidth: width, answerHeight: rowHeight,
                earliest: (arrivals.map(\.maxY).max() ?? back.maxY) + rowHeight
            ).top
        }
        if rowIsLast, row != nil {
            let choicesBottom = back.minY - rowHeight - spacing
            let choicesHeight = choicesHeight(width)
            if choicesHeight <= choicesBottom {
                choicesTop = choicesBottom - choicesHeight
            } else {
                // Every point down to the foot of what shows: lower ones
                // are nearest the way back whatever is below them. Before
                // the screen is measured, the words' foot; never a stand-in
                // for an unknown height, whose points could lie so far down
                // that no top below them is ever found.
                let foot = CGRect(x: 0, y: max(visibleHeight ?? 0, under.maxY) - 1, width: width, height: 1)
                choicesTop = below([back, under, foot])
            }
        } else {
            // A look in the gap around the row met the row too.
            choicesTop = below([back.insetBy(dx: 0, dy: -spacing / 2), under])
        }
    }
}
