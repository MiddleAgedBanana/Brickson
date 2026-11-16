import Foundation

/// Measures the gaps between controls that a layout promises are equal, and
/// says which are not (docs/DECISIONS.md, "One spacing scale"). Plain logic
/// that drives no app: the UI tests give it frames read from the running
/// app, and the unit tests give it the layout engine's frames and frames
/// made by hand (`EqualGapsTests`), so one rule judges all three.
nonisolated enum EqualGaps {
    /// How far apart two gaps may measure and still count as equal: half a
    /// point, the tie the chain checks use. SwiftUI rounds each edge of a
    /// frame to the screen's pixels, so two equal gaps can come out one
    /// pixel apart, half a point on a 2x screen and a third of one on a 3x;
    /// a gap a person can see is uneven differs by a point or more. Frames
    /// whose tops are this close share a row.
    static let tolerance: CGFloat = 0.5

    /// The gaps between neighbouring frames: across each row, from one
    /// frame's trailing edge to the next one's leading edge, and down from
    /// the bottom of one row to the top of the next.
    struct Gaps: Equatable {
        var across: [CGFloat]
        var down: [CGFloat]

        var all: [CGFloat] { across + down }
    }

    /// The frames in rows, top to bottom, each row leading to trailing.
    static func rows(of frames: [CGRect]) -> [[CGRect]] {
        var rows: [[CGRect]] = []
        for frame in frames.sorted(by: { $0.minY < $1.minY }) {
            if let top = rows.last?.first?.minY, abs(frame.minY - top) <= tolerance {
                rows[rows.count - 1].append(frame)
            } else {
                rows.append([frame])
            }
        }
        return rows.map { $0.sorted { $0.minX < $1.minX } }
    }

    static func gaps(between frames: [CGRect]) -> Gaps {
        let lines = rows(of: frames)
        var across: [CGFloat] = []
        for line in lines {
            for (leading, trailing) in zip(line, line.dropFirst()) {
                across.append(trailing.minX - leading.maxX)
            }
        }
        var down: [CGFloat] = []
        for (upper, lower) in zip(lines, lines.dropFirst()) {
            down.append((lower.map(\.minY).min() ?? 0) - (upper.map(\.maxY).max() ?? 0))
        }
        return Gaps(across: across, down: down)
    }

    /// What is wrong with groups of frames whose gaps should all be one
    /// size, in words a failure can show; empty when every gap in every
    /// group measures the same, within `tolerance`. A group with fewer than
    /// two frames has no gap to measure, and frames that touch or overlap
    /// have no gap at all: both are faults, so a check that read the wrong
    /// controls cannot pass by measuring nothing.
    static func faults(in groups: [(name: String, frames: [CGRect])]) -> [String] {
        var faults: [String] = []
        var measured: [(name: String, gap: CGFloat)] = []
        for (name, frames) in groups {
            guard frames.count >= 2 else {
                faults.append("\(name): \(frames.count) frame(s), no gap to measure")
                continue
            }
            let found = gaps(between: frames)
            for gap in found.all where gap <= 0 {
                faults.append("\(name): controls touch or overlap (gap \(gap))")
            }
            for gap in found.across { measured.append((name: "\(name), across", gap: gap)) }
            for gap in found.down { measured.append((name: "\(name), down", gap: gap)) }
        }
        if let smallest = measured.min(by: { $0.gap < $1.gap }),
           let largest = measured.max(by: { $0.gap < $1.gap }),
           largest.gap - smallest.gap > tolerance {
            faults.append(
                "gaps differ: \(smallest.gap) (\(smallest.name)) and \(largest.gap) (\(largest.name)); "
                    + "every gap: " + measured.map { "\($0.name) \($0.gap)" }.joined(separator: ", ")
            )
        }
        return faults
    }
}
