import Foundation

/// Where the second step of Set Up Step by Step places its choices, in the
/// window, from Next's frame. Plain logic, tested without a screen
/// (docs/DECISIONS.md, "The late-stage profile", *Where the second step's
/// choices start*).
///
/// A look reaches the second step through the first step's Next, which
/// sits in the same bar at the foot of every step, so under AssistiveTouch
/// Dwell, head tracking or Eye Tracking the pointer can be resting anywhere
/// on Next as the step appears, and a held look can choose whatever is now
/// nearest it. A choice is saved the moment it is chosen, so every choice
/// keeps every point of Next nearer Next than itself, by centre and by
/// edge, with `SettingsRowPlace.margin` to spare: then a held look on Next
/// meets Next again, which only moves on.
///
/// Each choice follows the words, or the choice before it, where it holds
/// there. From the first that does not, as on a phone, where a full-width
/// Next's corners reach up into the screen above the bar, the rest start
/// together at the first top below the bar at which every one of them
/// holds: the step's first screenful shows the choices that hold under
/// the words, and the family scrolls to the rest, past a gap where a
/// choice would meet a look on Next.
nonisolated struct SetupChoicesPlace: Equatable, Sendable {
    /// Each choice's top, in the window, in order.
    let tops: [CGFloat]

    /// - Parameters:
    ///   - next: Next's frame, in the window.
    ///   - choicesMinX: the choices' leading edge, in the window.
    ///   - choicesWidth: the choices' width: the content's.
    ///   - heights: each choice's height, in order.
    ///   - spacing: the gap between choices.
    ///   - earliest: the highest top the step's words leave for the
    ///     choices, in the window.
    init(next: CGRect, choicesMinX: CGFloat, choicesWidth: CGFloat, heights: [CGFloat], spacing: CGFloat, earliest: CGFloat) {
        func stacked(from top: CGFloat, _ heights: ArraySlice<CGFloat>) -> [CGFloat] {
            var y = top
            return heights.map { height in
                defer { y += height + spacing }
                return y
            }
        }
        guard !heights.isEmpty, !next.isEmpty else {
            tops = stacked(from: earliest, heights[...])
            return
        }
        // Next's edge, every 4 points: a choice that holds lies wholly
        // above or below Next, so the point of Next nearest it, by centre
        // or by edge, lies on Next's edge rather than inside it.
        let points = SettingsRowPlace.points(across: next, every: 4).filter {
            $0.x == next.minX || $0.x == next.maxX || $0.y == next.minY || $0.y == next.maxY
        }
        func holds(_ top: CGFloat, _ height: CGFloat) -> Bool {
            let choice = CGRect(x: choicesMinX, y: top, width: choicesWidth, height: height)
            return points.allSatisfy { SettingsRowPlace.isNearer($0, toOneOf: [next], thanAny: [choice], margin: SettingsRowPlace.margin) }
        }
        // Under the words, each choice after the one before, while each
        // holds.
        var under: [CGFloat] = []
        var y = earliest
        for height in heights {
            guard holds(y, height) else { break }
            under.append(y)
            y += height + spacing
        }
        let rest = heights[under.count...]
        guard !rest.isEmpty else {
            tops = under
            return
        }
        func restHolds(_ top: CGFloat) -> Bool {
            zip(stacked(from: top, rest), rest).allSatisfy { holds($0, $1) }
        }
        // Below the bar, every point holds once the first of the rest is
        // farther below it than Next's centre is from it, by more than the
        // margin, and the ones after it are farther still: down 8 points
        // at a time to the first top that holds, then back up a point at a
        // time while it holds, never above the bar's foot or the place
        // under the words.
        let highest = max(y, next.maxY)
        let deepest = points.map { $0.y + SettingsRowPlace.centreDistance(from: $0, to: next) }.max().map { $0 + SettingsRowPlace.margin + 1 }
            ?? highest
        var coarse = highest
        while coarse < deepest, !restHolds(coarse) {
            coarse += 8
        }
        var found = coarse
        while found - 1 >= highest, found - 1 > coarse - 8, restHolds(found - 1) {
            found -= 1
        }
        tops = under + stacked(from: found, rest)
    }
}
