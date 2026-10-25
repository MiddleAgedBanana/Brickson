import Foundation

/// Where Settings' first screen puts its Family Setup row, in the window,
/// from Home's own frames (`HomeLayout`), the row's words and where the
/// screen's content and navigation bar are. Plain logic, tested without a
/// screen (docs/DECISIONS.md, "Settings' first row, placed from Home's
/// frames").
///
/// Settings covers Home, and under AssistiveTouch Dwell, head tracking or
/// Eye Tracking the pointer rests where the last control was when the next
/// screen appears. A look held on the row opens Family Setup, and a look
/// that reaches Back to Talking from there closes Settings under it, onto
/// whatever Home has at that spot. So the row sits as high as it can while
/// every point of its top edge lies nearer, by centre and by edge, a Home
/// control that only switches what Home shows (a category, Settings,
/// Emergency, Phrases, Type) than one that speaks or sounds. That is
/// `quietTop`.
///
/// Where Home under Settings' Back button only switches what Home shows,
/// as Emergency does on wider windows, the row stands over Home's Settings
/// at the trailing side, as wide as Settings or as its words on one line,
/// so the spot where Home's Settings was meets it, and a look on it that
/// closes Settings meets Settings or a category. Where Home under Back
/// speaks or sounds, as Yes does on a phone, the row spans the width and
/// stays high enough that a look on Back, once the first screen returns,
/// meets the row before Back to Talking, which would close Settings onto
/// Yes. That is `backLimit`, and where both cannot hold it wins: on a
/// phone, Set Up Step by Step, which takes the row's place on Family
/// Setup, then keeps a look on that place away from Back to Talking
/// (docs/work/settings-row-place.md, *Spec*). Where no place keeps Back's
/// spot nearer the row, the row stays at the top of the content.
nonisolated struct SettingsRowPlace: Equatable, Sendable {
    /// How much nearer a point must be to the control meant to be nearest
    /// than to the one it must not meet: more than the half point the chain
    /// checks count as a tie, and room for the row's measured height and
    /// the navigation bar to differ from CI's by a few points.
    static let margin: CGFloat = 8

    /// The gap between the row and the words beside it: Settings' gap
    /// between its rows (`SettingsMetrics.rowSpacing`).
    static let columnSpacing: CGFloat = 16

    /// Home's controls that speak or sound when a look meets them: Yes, No,
    /// Again, Get Attention, Stop (which ends the alarm) and the phrase
    /// tiles. The rest only switch what Home shows.
    static let sounding: Set<HomeLayout.Slot> = [.yes, .no, .again, .getAttention, .stop, .phraseGrid]

    /// The row's frame, in the window's coordinates.
    let row: CGRect
    /// The highest top at which every point of the row's top edge lies
    /// nearer a Home control that only switches what Home shows than any
    /// that speaks or sounds, by centre and by edge, with `margin` to
    /// spare; the lowest top that shows without scrolling where none does.
    let quietTop: CGFloat
    /// The lowest top at which every point of Back's spot lies nearer the
    /// row than Back to Talking, by centre and by edge, with `margin` to
    /// spare; nil where Home under Back's spot only switches what Home
    /// shows, so meeting Back to Talking there is harmless.
    let backLimit: CGFloat?
    /// Where the standard Back button is taken to be on the screens below
    /// the first: the leading end of the navigation bar, as wide as the bar
    /// is tall. CI's Back buttons lie inside it.
    let backSpot: CGRect

    /// - Parameters:
    ///   - home: Home's frames in this window and at this text size.
    ///   - rowIdealWidth: the row with its words on one line.
    ///   - rowHeight: the row's height at a width.
    ///   - content: the screen's content, in the window: from the top of
    ///     its first view to the foot of what shows without scrolling.
    ///   - navigationBar: the navigation bar, in the window.
    init(home: HomeLayout, rowIdealWidth: CGFloat, rowHeight: (CGFloat) -> CGFloat, content: CGRect, navigationBar: CGRect) {
        backSpot = CGRect(x: navigationBar.minX, y: navigationBar.minY, width: navigationBar.height, height: navigationBar.height)
        let backToTalking = home.backToTalking
        let backMeetsTheRow = !backToTalking.isNull && Self.homeSoundsUnder(backSpot, in: home)
        // The narrowest row that serves: over Home's Settings, as wide as it
        // or as the row's words on one line; the trailing half, where a half
        // holds the words; the whole width. Where Back's spot must meet the
        // row, the first it meets at the top of the content.
        let settings = home.frame(.settings)
        let overSettings = min(content.width, max(rowIdealWidth, settings.isNull ? 0 : settings.width))
        let half = (content.width - SettingsRowPlace.columnSpacing) / 2
        let widths = [overSettings] + (half >= rowIdealWidth && half > overSettings ? [half] : []) + [content.width]
        let spot = Self.points(across: backSpot, every: 4)
        let width = widths.first { width in
            guard backMeetsTheRow else { return true }
            let atTheTop = CGRect(x: content.maxX - width, y: content.minY, width: width, height: rowHeight(width))
            return spot.allSatisfy { Self.isNearer($0, toOneOf: [atTheTop], thanAny: [backToTalking], margin: Self.margin) }
        } ?? content.width
        let rowMinX = content.maxX - width
        let height = rowHeight(width)

        let controls = Self.controls(of: home)
        let quiet = controls.filter { !Self.sounding.contains($0.slot) }.map(\.frame)
        let loud = controls.filter { Self.sounding.contains($0.slot) }.map(\.frame)
        let lowest = max(content.minY, content.maxY - height)
        func topIsQuiet(_ top: CGFloat) -> Bool {
            let edge = CGRect(x: rowMinX, y: top, width: width, height: 0)
            return Self.points(across: edge, every: 8).allSatisfy { point in
                Self.isNearer(point, toOneOf: quiet, thanAny: loud, margin: Self.margin)
            }
        }
        // Down from the top of the content 8 points at a time to the first
        // top that holds, then back up a point at a time while it holds.
        var found: CGFloat?
        var coarse = content.minY
        while found == nil, coarse <= lowest {
            if topIsQuiet(coarse) {
                found = coarse
                var fine = coarse - 1
                while fine > coarse - 8, fine >= content.minY, topIsQuiet(fine) {
                    found = fine
                    fine -= 1
                }
            }
            coarse += 8
        }
        quietTop = found ?? lowest

        if backMeetsTheRow {
            func rowIsNearer(atTop top: CGFloat) -> Bool {
                let row = CGRect(x: rowMinX, y: top, width: width, height: height)
                return spot.allSatisfy { Self.isNearer($0, toOneOf: [row], thanAny: [backToTalking], margin: Self.margin) }
            }
            // Lower only takes the row farther from Back's spot, which lies
            // above it, so every top that holds comes before the first that
            // fails: halve the whole points between until it is found.
            var holds = 0
            var fails = Int(max(0, quietTop - content.minY).rounded(.down)) + 1
            while fails - holds > 1 {
                let middle = (holds + fails) / 2
                if rowIsNearer(atTop: content.minY + CGFloat(middle)) {
                    holds = middle
                } else {
                    fails = middle
                }
            }
            backLimit = content.minY + CGFloat(holds)
        } else {
            backLimit = nil
        }

        let top = min(max(min(quietTop, backLimit ?? .infinity), content.minY), lowest)
        row = CGRect(x: rowMinX, y: top, width: width, height: height)
    }

    /// Whether any point of `spot` lies nearest, by centre or by edge, a
    /// Home control that speaks or sounds.
    static func homeSoundsUnder(_ spot: CGRect, in home: HomeLayout) -> Bool {
        let controls = controls(of: home)
        let quiet = controls.filter { !sounding.contains($0.slot) }.map(\.frame)
        let loud = controls.filter { sounding.contains($0.slot) }.map(\.frame)
        guard !loud.isEmpty else { return false }
        return !points(across: spot, every: 4).allSatisfy { isNearer($0, toOneOf: quiet, thanAny: loud, margin: 0) }
    }

    /// Home's controls and its phrase grid, each with its frame.
    private static func controls(of home: HomeLayout) -> [(slot: HomeLayout.Slot, frame: CGRect)] {
        (home.controls + [.phraseGrid]).map { (slot: $0, frame: home.frame($0)) }.filter { !$0.frame.isNull }
    }

    /// Whether `point` is nearer one of `near` than any of `far`, by `margin`
    /// or more, both by centre and by edge.
    static func isNearer(_ point: CGPoint, toOneOf near: [CGRect], thanAny far: [CGRect], margin: CGFloat) -> Bool {
        guard let farCentre = far.map({ centreDistance(from: point, to: $0) }).min(),
              let farEdge = far.map({ edgeDistance(from: point, to: $0) }).min()
        else { return true }
        let nearCentre = near.map { centreDistance(from: point, to: $0) }.min() ?? .infinity
        let nearEdge = near.map { edgeDistance(from: point, to: $0) }.min() ?? .infinity
        return nearCentre + margin < farCentre && nearEdge + margin < farEdge
    }

    /// Points no more than `step` apart across `frame`, its edges and
    /// corners included.
    static func points(across frame: CGRect, every step: CGFloat) -> [CGPoint] {
        let columns = max(1, Int((frame.width / step).rounded(.up)))
        let rows = max(1, Int((frame.height / step).rounded(.up)))
        return (0...rows).flatMap { row in
            (0...columns).map { column in
                CGPoint(
                    x: frame.minX + frame.width * CGFloat(column) / CGFloat(columns),
                    y: frame.minY + frame.height * CGFloat(row) / CGFloat(rows)
                )
            }
        }
    }

    static func centreDistance(from point: CGPoint, to frame: CGRect) -> CGFloat {
        hypot(point.x - frame.midX, point.y - frame.midY)
    }

    static func edgeDistance(from point: CGPoint, to frame: CGRect) -> CGFloat {
        hypot(max(frame.minX - point.x, 0, point.x - frame.maxX), max(frame.minY - point.y, 0, point.y - frame.maxY))
    }
}
