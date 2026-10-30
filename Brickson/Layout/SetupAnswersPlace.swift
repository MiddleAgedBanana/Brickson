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
        let points = arrivals.filter { !$0.isNull }.flatMap { SettingsRowPlace.points(across: $0, every: 4) }
        func holds(_ top: CGFloat) -> Bool {
            let answer = CGRect(x: answersMinX, y: top, width: answersWidth, height: answerHeight)
            return points.allSatisfy { SettingsRowPlace.isNearer($0, toOneOf: [link], thanAny: [answer], margin: SettingsRowPlace.margin) }
        }
        // An answer holds only below every point, and lower only takes it
        // farther from each: down 8 points at a time to the first top that
        // holds, then back up a point at a time while it holds. Every point
        // holds once the answer's top is farther below it than the link's
        // centre is from it, by more than the margin.
        let deepest = points.map { $0.y + SettingsRowPlace.centreDistance(from: $0, to: link) }.max().map { $0 + SettingsRowPlace.margin + 1 }
            ?? earliest
        var coarse = earliest
        while coarse < deepest, !holds(coarse) {
            coarse += 8
        }
        var found = coarse
        while found - 1 >= earliest, found - 1 > coarse - 8, holds(found - 1) {
            found -= 1
        }
        top = found
    }
}
