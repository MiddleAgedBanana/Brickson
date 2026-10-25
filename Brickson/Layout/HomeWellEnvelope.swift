import Foundation

/// A conservative sizing constraint for the existing Stop-well hazard.
/// It does not simulate input. The test-only ChainEngine independently
/// scores activations on the final frames. See docs/work/layout-engine.md.
nonisolated enum HomeWellEnvelope {
    typealias Slot = HomeLayout.Slot

    static func preserves(_ original: [Slot: CGRect], _ final: [Slot: CGRect]) -> Bool {
        let oldWell = original[.stop]!, newWell = final[.stop]!
        guard oldWell.width > 0, oldWell.height > 0, newWell.width > 0, newWell.height > 0 else { return false }
        func local(_ rect: CGRect, in well: CGRect) -> CGRect { rect.offsetBy(dx: -well.minX, dy: -well.minY) }
        let oldAgain = local(original[.again]!, in: oldWell), newAgain = local(final[.again]!, in: newWell)
        let spans = oldAgain.maxY <= 0 && newAgain.maxY <= 0
            && oldAgain.minX <= 0 && newAgain.minX <= 0
            && oldAgain.maxX >= oldWell.width && newAgain.maxX >= newWell.width
        if !spans { return excludesAgain(original) && excludesAgain(final) }
        for slot in (0..<HomeLayout.categoryCapacity).map({ Slot.category($0) }) + [.settings] {
            let oldOther = local(original[slot]!, in: oldWell), newOther = local(final[slot]!, in: newWell)
            // F=dAgain²-dOther² is affine in normalized well coordinates.
            // Each distance's change is bounded by centre movement plus
            // point movement. Account for the changing denominator in
            // dAgain-dOther=F/(dAgain+dOther), including the half-point tie.
            let pointMovement = hypot(newWell.width - oldWell.width, newWell.height - oldWell.height)
            let movement = 2 * pointMovement + centreMovement(oldAgain, newAgain) + centreMovement(oldOther, newOther)
            var minimumGain = CGFloat.infinity
            for u: CGFloat in [0, 1] { for v: CGFloat in [0, 1] {
                let before = CGPoint(x: u * oldWell.width, y: v * oldWell.height)
                let after = CGPoint(x: u * newWell.width, y: v * newWell.height)
                let gain = squared(after, newAgain) - squared(after, newOther)
                    - squared(before, oldAgain) + squared(before, oldOther)
                minimumGain = min(minimumGain, gain)
            } }
            if minimumGain < HomeLayout.wellClearance * movement - 0.001 { return false }

            // Again spans the well, so its edge distance has this minimum
            // increase. The competitor's active nearest-edge components
            // are piecewise affine; only their true breakpoints matter.
            let aboveGain = min(oldAgain.maxY - newAgain.maxY,
                oldAgain.maxY - newAgain.maxY + newWell.height - oldWell.height)
            let us = ([CGFloat(0), 1] + [oldOther.minX / oldWell.width, oldOther.maxX / oldWell.width,
                newOther.minX / newWell.width, newOther.maxX / newWell.width]).filter { $0 >= 0 && $0 <= 1 }
            let vs = ([CGFloat(0), 1] + [oldOther.minY / oldWell.height, oldOther.maxY / oldWell.height,
                newOther.minY / newWell.height, newOther.maxY / newWell.height]).filter { $0 >= 0 && $0 <= 1 }
            var edgeMovement: CGFloat = 0
            for u in us { for v in vs {
                let dx = component(u * newWell.width, newOther.minX, newOther.maxX)
                    - component(u * oldWell.width, oldOther.minX, oldOther.maxX)
                let dy = component(v * newWell.height, newOther.minY, newOther.maxY)
                    - component(v * oldWell.height, oldOther.minY, oldOther.maxY)
                edgeMovement = max(edgeMovement, hypot(dx, dy))
            } }
            if aboveGain < edgeMovement - 0.001 { return false }
        }
        return otherControlsAreFarther(original) && otherControlsAreFarther(final)
    }

    /// In a one-row safety arrangement a category under the well can
    /// exclude Again everywhere. This guard avoids imposing compact
    /// pairwise ordering where the original Again envelope is empty.
    private static func excludesAgain(_ frames: [Slot: CGRect]) -> Bool {
        let well = frames[.stop]!, again = frames[.again]!
        guard let under = (0..<HomeLayout.categoryCapacity).map({ frames[.category($0)]! })
            .filter({ $0.minY >= well.maxY && $0.minX <= well.minX + 0.001 && $0.maxX >= well.maxX - 0.001 })
            .min(by: { $0.minY < $1.minY }) else { return false }
        let points = corners(well)
        let difference = points.map { squared($0, again) - squared($0, under) }.min()!
        let sum = points.map { distance($0, again) + distance($0, under) }.max()!
        let dx = max(well.minX - again.maxX, 0, again.minX - well.maxX)
        let dy = max(well.minY - again.maxY, 0, again.minY - well.maxY)
        let edgeDifference = hypot(dx, dy) - points.map { edgeDistance($0, under) }.max()!
        return difference >= HomeLayout.wellClearance * sum && edgeDifference >= HomeLayout.wellClearance
    }

    /// Establish that categories/Again describe the complete nearest set.
    /// A finite intersection of affine half-planes proves every point is
    /// covered by a rival with the existing one-point clearance. This is
    /// not a sampled mesh or a second nearest-control/chain engine.
    private static func otherControlsAreFarther(_ frames: [Slot: CGRect]) -> Bool {
        let well = frames[.stop]!, again = frames[.again]!, points = corners(well)
        let rivals = ([Slot.again] + (0..<HomeLayout.categoryCapacity).map { .category($0) } + [.settings]).compactMap { frames[$0] }
        for slot in [Slot.yes, .no, .emergency, .getAttention, .phrases, .type] {
            guard let other = frames[slot] else { continue }
            var remainder = points
            for rival in rivals {
                let maximumSum = points.map { distance($0, other) + distance($0, rival) }.max()!
                remainder = clip(remainder) { point in
                    2 * point.x * (rival.midX - other.midX) + 2 * point.y * (rival.midY - other.midY)
                        + other.midX * other.midX + other.midY * other.midY
                        - rival.midX * rival.midX - rival.midY * rival.midY
                        - HomeLayout.wellClearance * maximumSum
                }
            }
            if !remainder.isEmpty { return false }
            let across = max(other.minX - well.maxX, 0, well.minX - other.maxX)
            let edgeDifference = hypot(across, well.maxY - other.maxY) - (well.maxY - again.maxY)
            if other.maxY > well.minY || again.maxY > well.minY || again.minX > well.minX
                || again.maxX < well.maxX || edgeDifference < HomeLayout.wellClearance { return false }
        }
        return true
    }

    private static func clip(_ polygon: [CGPoint], value: (CGPoint) -> CGFloat) -> [CGPoint] {
        guard !polygon.isEmpty else { return [] }
        var output: [CGPoint] = []
        for index in polygon.indices {
            let a = polygon[index], b = polygon[(index + 1) % polygon.count]
            let av = value(a), bv = value(b)
            if av <= 0 { output.append(a) }
            if (av < 0 && bv > 0) || (av > 0 && bv < 0) {
                let t = av / (av - bv)
                output.append(CGPoint(x: a.x + t * (b.x - a.x), y: a.y + t * (b.y - a.y)))
            }
        }
        return output
    }

    private static func corners(_ rect: CGRect) -> [CGPoint] {
        [CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY),
         CGPoint(x: rect.maxX, y: rect.maxY), CGPoint(x: rect.minX, y: rect.maxY)]
    }

    private static func centreMovement(_ a: CGRect, _ b: CGRect) -> CGFloat { hypot(a.midX - b.midX, a.midY - b.midY) }
    private static func squared(_ point: CGPoint, _ rect: CGRect) -> CGFloat {
        let dx = point.x - rect.midX, dy = point.y - rect.midY
        return dx * dx + dy * dy
    }
    private static func distance(_ point: CGPoint, _ rect: CGRect) -> CGFloat { sqrt(squared(point, rect)) }
    private static func component(_ point: CGFloat, _ low: CGFloat, _ high: CGFloat) -> CGFloat { max(low - point, 0, point - high) }
    private static func edgeDistance(_ point: CGPoint, _ rect: CGRect) -> CGFloat {
        hypot(component(point.x, rect.minX, rect.maxX), component(point.y, rect.minY, rect.maxY))
    }
}
