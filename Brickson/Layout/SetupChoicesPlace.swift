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
///
/// A look can also arrive resting elsewhere than on Next
/// (`arrivals(from:checkInRows:)`): once the check-in card was answered
/// and Set Up Step by Step chosen in its place, a look still over where
/// the card's rows were meets Next on the first step, whose answers start
/// below that place, and arrives here still over it, which can lie under
/// the bar and the sound line, beside choices the family scrolls to. Each
/// choice then keeps every point of those frames nearer Next than itself
/// too.
nonisolated struct SetupChoicesPlace: Equatable, Sendable {
    /// Each choice's top, in the window, in order.
    let tops: [CGFloat]

    /// - Parameters:
    ///   - next: Next's frame, in the window.
    ///   - arrivals: where else a look can be resting as the step appears,
    ///     besides Next, in the window (`arrivals(from:checkInRows:)`).
    ///   - choicesMinX: the choices' leading edge, in the window.
    ///   - choicesWidth: the choices' width: the content's.
    ///   - heights: each choice's height, in order.
    ///   - spacing: the gap between choices.
    ///   - earliest: the highest top the step's words leave for the
    ///     choices, in the window.
    init(
        next: CGRect, arrivals: [CGRect] = [], choicesMinX: CGFloat, choicesWidth: CGFloat, heights: [CGFloat], spacing: CGFloat,
        earliest: CGFloat
    ) {
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
        let nextPoints = SettingsRowPlace.points(across: next, every: 4).filter {
            $0.x == next.minX || $0.x == next.maxX || $0.y == next.minY || $0.y == next.maxY
        }
        // Another frame a look can arrive in: within the choices' width,
        // a choice that holds lies wholly above or below it, and then its
        // corners decide for every point of it, as for the first step's
        // arrivals (`SetupAnswersPlace.corners(of:)`); wider, every 4
        // points across it.
        let others = arrivals.filter { !$0.isNull && !$0.isEmpty }
        let choicesMaxX = choicesMinX + choicesWidth
        let points = nextPoints + others.flatMap { frame in
            frame.minX >= choicesMinX && frame.maxX <= choicesMaxX
                ? SetupAnswersPlace.corners(of: frame)
                : SettingsRowPlace.points(across: frame, every: 4)
        }
        func holds(_ top: CGFloat, _ height: CGFloat) -> Bool {
            let choice = CGRect(x: choicesMinX, y: top, width: choicesWidth, height: height)
            // A look inside a choice meets it.
            guard !others.contains(where: { $0.intersects(choice) }) else { return false }
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
        // under the words. A point's depth plus its distance from Next's
        // centre is greatest at a corner of its frame.
        let highest = max(y, next.maxY)
        let deepest = (nextPoints + others.flatMap(SetupAnswersPlace.corners(of:)))
            .map { $0.y + SettingsRowPlace.centreDistance(from: $0, to: next) }.max()
            .map { $0 + SettingsRowPlace.margin + 1 } ?? highest
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

    /// Where else a held look can be resting as the second step appears,
    /// in the window, when the steps were opened from `entry`. Opened with
    /// Set Up Step by Step once the check-in card was answered in its
    /// place, where the card's rows were (`checkInRows`): a look held
    /// after Not Now or Stop Asking rests over the words that keep the
    /// card's place, meets Set Up Step by Step from there, and on the first
    /// step meets Next, since that step's answers start below the place
    /// (`SetupAnswersPlace.arrivals(from:homesSettings:rootRow:opener:checkInRows:)`).
    /// Otherwise none: a look on the way in meets Learn About Each Way on
    /// the first step, in the place of the control that opened it, or Next
    /// with the look on it.
    static func arrivals(from entry: GuidedSetupEntry, checkInRows: CGRect) -> [CGRect] {
        switch entry {
        case .setUpStepByStepAfterTheCheckIn: [checkInRows]
        case .setUpStepByStep, .checkIn: []
        }
    }
}
