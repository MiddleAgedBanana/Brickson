import Foundation
import Testing
@testable import Brickson

/// `EqualGaps`, the rule `HomeLayoutTests` applies to the running app's
/// phrase tiles and safety row, checked here on frames made by hand, and on
/// the layout engine's own frames in every window the engine tests sweep and
/// in every profile (docs/DECISIONS.md, "One spacing scale"). An uneven gap
/// is easy to miss by eye; these fail on one.
struct EqualGapsTests {
    private typealias Profile = HomeLayout.Profile
    private typealias Slot = HomeLayout.Slot

    /// `count` tiles in `columns` columns, `across` apart in a row and
    /// `down` apart between rows, filled row by row.
    private static func grid(
        count: Int, columns: Int, size: CGSize = CGSize(width: 100, height: 80),
        across: CGFloat = 8, down: CGFloat = 8
    ) -> [CGRect] {
        (0..<count).map { index in
            CGRect(
                x: CGFloat(index % columns) * (size.width + across),
                y: CGFloat(index / columns) * (size.height + down),
                width: size.width, height: size.height
            )
        }
    }

    // MARK: The rule, on frames made by hand

    /// Eight tiles in three columns, as a phone shows the largest starter
    /// category: three, three and two. Fails if even gaps are reported, or
    /// the short last row is measured wrongly.
    @Test func evenGapsHaveNoFault() {
        let tiles = Self.grid(count: 8, columns: 3)
        #expect(EqualGaps.faults(in: [(name: "tiles", frames: tiles)]).isEmpty)
        #expect(EqualGaps.gaps(between: tiles) == EqualGaps.Gaps(across: [8, 8, 8, 8, 8], down: [8, 8]))
    }

    /// An uneven grid: one tile 4 points too far across, or a row 4 points
    /// too low, or rows farther apart than tiles. Each is a fault.
    @Test func anUnevenGapIsAFault() {
        var nudged = Self.grid(count: 8, columns: 4)
        nudged[2] = nudged[2].offsetBy(dx: 4, dy: 0)
        #expect(EqualGaps.faults(in: [(name: "tiles", frames: nudged)]).count == 1)

        var lowered = Self.grid(count: 8, columns: 4)
        for index in 4..<8 { lowered[index] = lowered[index].offsetBy(dx: 0, dy: 4) }
        #expect(EqualGaps.faults(in: [(name: "tiles", frames: lowered)]).count == 1)

        let apart = Self.grid(count: 8, columns: 4, across: 8, down: 12)
        let faults = EqualGaps.faults(in: [(name: "tiles", frames: apart)])
        #expect(faults.count == 1)
        #expect(faults.first?.contains("tiles, down 12.0") == true, "\(faults)")
    }

    /// SwiftUI rounds each edge to a pixel, so equal gaps can measure half
    /// a point apart on a 2x screen: that still counts as equal. A little
    /// more does not.
    @Test func gapsHalfAPointApartAreEqualAndMoreAreNot() {
        var pixel = Self.grid(count: 4, columns: 4)
        pixel[3] = pixel[3].offsetBy(dx: 0.5, dy: 0)
        #expect(EqualGaps.faults(in: [(name: "tiles", frames: pixel)]).isEmpty)

        var more = Self.grid(count: 4, columns: 4)
        more[3] = more[3].offsetBy(dx: 0.6, dy: 0)
        #expect(EqualGaps.faults(in: [(name: "tiles", frames: more)]).count == 1)
    }

    /// The grid and the safety row share one gap: each even on its own,
    /// but 8 points apart in one and 12 in the other, is a fault.
    @Test func groupsMustShareTheirGap() {
        let tiles = Self.grid(count: 8, columns: 4, across: 8, down: 8)
        let safety = Self.grid(count: 5, columns: 5, across: 12, down: 12)
        #expect(EqualGaps.faults(in: [(name: "tiles", frames: tiles), (name: "safety row", frames: safety)]).count == 1)
        let matching = Self.grid(count: 5, columns: 3, across: 8, down: 8)
        #expect(EqualGaps.faults(in: [(name: "tiles", frames: tiles), (name: "safety row", frames: matching)]).isEmpty)
    }

    /// A check that read the wrong controls, or none, cannot pass by
    /// measuring nothing: fewer than two frames, or frames that touch or
    /// overlap, are faults even where every gap is the same.
    @Test func nothingToMeasureIsAFault() {
        #expect(EqualGaps.faults(in: [(name: "tiles", frames: [])]).count == 1)
        #expect(EqualGaps.faults(in: [(name: "tiles", frames: Self.grid(count: 1, columns: 4))]).count == 1)
        #expect(!EqualGaps.faults(in: [(name: "tiles", frames: Self.grid(count: 4, columns: 4, across: 0))]).isEmpty)
        #expect(!EqualGaps.faults(in: [(name: "tiles", frames: Self.grid(count: 4, columns: 4, across: -8))]).isEmpty)
    }

    /// Frames read from an accessibility snapshot come in its order, not
    /// the screen's: rows are found by their tops and ordered leading to
    /// trailing, whatever order the frames arrive in.
    @Test func rowsAreFoundWhateverTheOrder() {
        let tiles = Self.grid(count: 8, columns: 3)
        let shuffled = [tiles[7], tiles[0], tiles[4], tiles[2], tiles[6], tiles[1], tiles[5], tiles[3]]
        #expect(EqualGaps.rows(of: shuffled) == [Array(tiles[0..<3]), Array(tiles[3..<6]), Array(tiles[6..<8])])
        #expect(EqualGaps.faults(in: [(name: "tiles", frames: shuffled)]).isEmpty)
    }

    // MARK: The layout engine's frames

    /// The phrase tiles of the starter library's largest category and the
    /// safety row's controls, as the engine places them.
    private static func measured(_ layout: HomeLayout) -> [(name: String, frames: [CGRect])] {
        let grid = layout.grid
        let tiles = (0..<HomeLayout.referencePhraseCount).map {
            grid.tile(row: $0 / grid.columns, column: $0 % grid.columns)
        }
        return [(name: "phrase tiles", frames: tiles), (name: "safety row", frames: Slot.safetyRow.map { layout.frame($0) })]
    }

    /// What is wrong with `layout`'s gaps: any unevenness, and any gap
    /// that is not its profile's gap between controls.
    private static func faults(in layout: HomeLayout, _ context: String) -> [String] {
        let groups = measured(layout)
        var faults = EqualGaps.faults(in: groups).map { "\($0) (\(context))" }
        let gaps = groups.flatMap { EqualGaps.gaps(between: $0.frames).all }
        if let gap = gaps.first(where: { abs($0 - layout.profile.controlSpacing) > 0.01 }) {
            faults.append("a gap of \(gap), not the profile's \(layout.profile.controlSpacing) (\(context))")
        }
        return faults
    }

    /// Fails if the engine puts gaps of different sizes between the phrase
    /// tiles, across or down, or between the safety row's controls, or a
    /// gap other than the profile's, in any window from a 320pt phone to
    /// wider than any iPad at the default, xxxLarge and largest text sizes
    /// with Bold Text off and on (touch, `HomeLayoutEngineTests.everyLayout`),
    /// or in a phone's or an iPad's window in either orientation in every
    /// profile at the default and largest sizes. Windows with no reserved
    /// region: where a fold or camera divides a row, the engine widens that
    /// one gap on purpose (`HomeReservedRegionTests`).
    @Test func theEngineSpacesTilesAndTheSafetyRowEqually() {
        var faults: [String] = []
        for (layout, _, context) in HomeLayoutEngineTests.everyLayout {
            faults += Self.faults(in: layout, context)
        }
        let windows: [CGSize] = [
            CGSize(width: 375, height: 667), CGSize(width: 402, height: 874),
            CGSize(width: 820, height: 1180), CGSize(width: 1180, height: 820),
            CGSize(width: 1032, height: 1376), CGSize(width: 1376, height: 1032),
        ]
        for profile in Profile.allCases {
            for size in windows {
                for (name, text) in [("default", HomeLayoutEngineTests.defaultText), ("AX5", HomeLayoutEngineTests.largestText)] {
                    for modes in HomeLayoutEngineTests.bothModes {
                        let layout = HomeLayout(space: .init(size: size), profile: profile, text: text, modes: modes)
                        faults += Self.faults(in: layout, "\(profile), \(size.width)×\(size.height), \(name), \(modes)")
                    }
                }
            }
        }
        #expect(faults.isEmpty, "\(faults.count) faults, the first: \(faults.prefix(10).joined(separator: "; "))")
    }
}
