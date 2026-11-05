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
/// words go just above it where they fit between the top of the content
/// and the way back, and under it where they do not. The choices that
/// change something start at least a row's height below both, and lower
/// still where a look resting anywhere on the way back or the words would
/// otherwise be nearer the first choice than the way back, by centre or by
/// edge, with `SettingsRowPlace.margin` to spare (`SetupAnswersPlace`).
/// Lower choices are farther still. Where they start below what shows,
/// the family scrolls to them, which costs a dwell user several
/// activations: here that cost protects the person.
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
    ///   - width: the width the screen gives its content.
    ///   - visibleHeight: how much of the content shows without
    ///     scrolling. The way back is kept within it.
    ///   - backHeight: the way back's height at a width.
    ///   - wordsHeight: the words' height at a width.
    ///   - spacing: the gap between the way back and the words, Settings'
    ///     gap between rows.
    ///   - rowHeight: a choice's least height, and the least gap between
    ///     the way back or the words and the first choice.
    init(
        row: CGRect?, width: CGFloat, visibleHeight: CGFloat,
        backHeight: (CGFloat) -> CGFloat, wordsHeight: (CGFloat) -> CGFloat,
        spacing: CGFloat, rowHeight: CGFloat
    ) {
        let backWidth = min(row.map(\.width) ?? width, width)
        let height = max(row?.height ?? 0, backHeight(backWidth))
        let lowestTop = max(0, visibleHeight - height)
        let top = min(max(0, row?.minY ?? 0), lowestTop)
        let minX = min(max(0, row?.minX ?? 0), width - backWidth)
        back = CGRect(x: minX, y: top, width: backWidth, height: height)

        let wordsHeight = wordsHeight(width)
        if wordsHeight + spacing <= back.minY {
            words = CGRect(x: 0, y: back.minY - spacing - wordsHeight, width: width, height: wordsHeight)
        } else {
            words = CGRect(x: 0, y: back.maxY + spacing, width: width, height: wordsHeight)
        }

        choicesTop = SetupAnswersPlace(
            arrivals: [back, words], link: back,
            answersMinX: 0, answersWidth: width, answerHeight: rowHeight,
            earliest: max(back.maxY, words.maxY) + rowHeight
        ).top
    }
}
