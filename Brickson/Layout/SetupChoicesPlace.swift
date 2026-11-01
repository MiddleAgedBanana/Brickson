import Foundation

/// Where the second step of Set Up Step by Step starts its choices, in the
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
/// The choices follow the step's words where the whole column holds there.
/// Where it does not, as on a short window or at a large text size, where
/// they would run down to or under the bar, they start at the first top
/// below the bar at which every choice holds, so the step's first
/// screenful shows none and the family scrolls to them.
nonisolated struct SetupChoicesPlace: Equatable, Sendable {
    /// The first choice's top, in the window.
    let top: CGFloat

    /// - Parameters:
    ///   - next: Next's frame, in the window.
    ///   - choicesMinX: the choices' leading edge, in the window.
    ///   - choicesWidth: the choices' width: the content's.
    ///   - heights: each choice's height, in order.
    ///   - spacing: the gap between choices.
    ///   - earliest: the highest top the step's words leave for the
    ///     choices, in the window.
    init(next: CGRect, choicesMinX: CGFloat, choicesWidth: CGFloat, heights: [CGFloat], spacing: CGFloat, earliest: CGFloat) {
        guard !heights.isEmpty, !next.isEmpty else {
            top = earliest
            return
        }
        // Next's edge, every 4 points: a choice lies wholly above or below
        // Next, so the point of Next nearest it, by centre or by edge,
        // lies on Next's edge rather than inside it.
        let points = SettingsRowPlace.points(across: next, every: 4).filter {
            $0.x == next.minX || $0.x == next.maxX || $0.y == next.minY || $0.y == next.maxY
        }
        func holds(_ top: CGFloat) -> Bool {
            var y = top
            for height in heights {
                let choice = CGRect(x: choicesMinX, y: y, width: choicesWidth, height: height)
                guard points.allSatisfy({ SettingsRowPlace.isNearer($0, toOneOf: [next], thanAny: [choice], margin: SettingsRowPlace.margin) })
                else { return false }
                y += height + spacing
            }
            return true
        }
        if holds(earliest) {
            top = earliest
            return
        }
        // Lower, the column first runs into Next and then past it. Every
        // point holds once the first choice's top is farther below it than
        // Next's centre is from it, by more than the margin, and lower
        // choices are farther still: down 8 points at a time to the first
        // top that holds, then back up a point at a time while it holds,
        // never above the bar's foot.
        let deepest = points.map { $0.y + SettingsRowPlace.centreDistance(from: $0, to: next) }.max().map { $0 + SettingsRowPlace.margin + 1 }
            ?? earliest
        var coarse = max(earliest, next.maxY)
        while coarse < deepest, !holds(coarse) {
            coarse += 8
        }
        var found = coarse
        while found - 1 >= max(earliest, next.maxY), found - 1 > coarse - 8, holds(found - 1) {
            found -= 1
        }
        top = found
    }
}
