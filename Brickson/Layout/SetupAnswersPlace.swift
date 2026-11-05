import Foundation

/// Where the first step of Set Up Step by Step starts its answers, in the
/// window, from the frames a look can be resting in as the step appears.
/// Plain logic, tested without a screen (docs/DECISIONS.md, "The first
/// step's own rows").
///
/// Under AssistiveTouch Dwell, head tracking or Eye Tracking the pointer
/// rests where the last control was when the next screen appears, and a
/// held look can choose whatever is now nearest it. A look reaches the
/// first step through Home's Settings, Settings' Family Setup row and
/// Family Setup's Set Up Step by Step, each of which only opens the next
/// screen, and the step's Learn About Each Way takes Set Up Step by Step's
/// place. An answer is saved the moment it is chosen, so the answers start
/// where every point of those frames lies nearer Learn About Each Way than
/// the first answer, by centre and by edge, with `SettingsRowPlace.margin`
/// to spare. Lower answers are farther still. Where that is below what
/// shows without scrolling, as on a phone at the largest text sizes, the
/// step's first screenful shows no answer.
nonisolated struct SetupAnswersPlace: Equatable, Sendable {
    /// The first answer's top, in the window.
    let top: CGFloat

    /// - Parameters:
    ///   - arrivals: where a held look can be resting as the step appears:
    ///     Home's Settings, the root's Family Setup row and Set Up Step by
    ///     Step, in the window.
    ///   - link: Learn About Each Way, in the window.
    ///   - answersMinX: the answers' leading edge, in the window.
    ///   - answersWidth: the answers' width: the content's.
    ///   - answerHeight: an answer's least height. A taller answer's centre
    ///     is farther from every point above it.
    ///   - earliest: the highest top the step's own layout leaves for the
    ///     answers, under the link.
    init(arrivals: [CGRect], link: CGRect, answersMinX: CGFloat, answersWidth: CGFloat, answerHeight: CGFloat, earliest: CGFloat) {
        let frames = arrivals.filter { !$0.isNull }
        let answersMaxX = answersMinX + answersWidth
        let points = frames.flatMap { frame in
            frame.minX >= answersMinX && frame.maxX <= answersMaxX
                ? Self.corners(of: frame)
                : SettingsRowPlace.points(across: frame, every: 4)
        }
        func holds(_ top: CGFloat) -> Bool {
            let answer = CGRect(x: answersMinX, y: top, width: answersWidth, height: answerHeight)
            return points.allSatisfy { SettingsRowPlace.isNearer($0, toOneOf: [link], thanAny: [answer], margin: SettingsRowPlace.margin) }
        }
        // Every point holds once the answer's top is farther below it than
        // the link's centre is from it, by more than the margin. A point's
        // depth plus its distance from that centre is greatest at a corner
        // of its frame.
        let deepest = frames.flatMap(Self.corners(of:))
            .map { $0.y + SettingsRowPlace.centreDistance(from: $0, to: link) }.max()
            .map { $0 + SettingsRowPlace.margin + 1 } ?? earliest
        top = Self.firstTop(from: earliest, to: deepest, where: holds)
    }

    /// The answers' top that the plain search finds: down 8 points at a
    /// time from `earliest` to the first top that holds, or to the first at
    /// or past `deepest`, then back up a point at a time while it holds.
    /// An answer holds only below every point, and lower only takes it
    /// farther from each, so a top holds at every whole point below the
    /// first that does: this finds that first one by halving, in about 17
    /// tries for a frame 100,000 points tall, where the plain search took a
    /// try for every 8 points (`SetupAnswersPlaceTests` compares the two).
    static func firstTop(from earliest: CGFloat, to deepest: CGFloat, where holds: (CGFloat) -> Bool) -> CGFloat {
        guard deepest > earliest else { return earliest }
        let last = ((deepest - earliest) / 8).rounded(.up) * 8
        guard last.isFinite, holds(earliest + last) else { return earliest + last }
        var low: CGFloat = 0
        var high = last
        while low < high {
            let middle = ((low + high) / 2).rounded(.down)
            if holds(earliest + middle) {
                high = middle
            } else {
                low = middle + 1
            }
        }
        return earliest + low
    }

    /// The corners of a frame that lies across the answers' width, which
    /// decide for every point of it. Above an answer and within its width,
    /// a point's distance from the answer's edge is its height above it,
    /// so the points nearer the link by edge, with the margin, form a
    /// convex region; so do the points nearer the link's centre than the
    /// answer's by more than the margin, inside one branch of a hyperbola
    /// around the link's centre. A frame whose corners lie in both lies
    /// wholly in both. A frame that reaches down to the answer fails at its
    /// lower corners, as every point at or below the answer's top does.
    /// Each corner is the same point the frame's grid of points has there
    /// (`SettingsRowPlace.points(across:every:)`).
    static func corners(of frame: CGRect) -> [CGPoint] {
        SettingsRowPlace.points(across: frame, every: max(frame.width, frame.height, 1))
    }
}
