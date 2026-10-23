import XCTest

/// A button on screen, named by its accessibility identifier where it has
/// one and by its label otherwise.
struct ScreenControl: CustomStringConvertible {
    let name: String
    let frame: CGRect

    var center: CGPoint { CGPoint(x: frame.midX, y: frame.midY) }
    var description: String { "\(name) \(frame)" }
}

extension XCTestCase {
    /// Every button on screen, from one accessibility snapshot, so the
    /// frames all come from one moment and one query.
    @MainActor
    func screenControls(in app: XCUIApplication) throws -> [ScreenControl] {
        var pending: [any XCUIElementSnapshot] = [try app.snapshot()]
        var found: [ScreenControl] = []
        while let element = pending.popLast() {
            if element.elementType == .button {
                let name = element.identifier.isEmpty ? element.label : element.identifier
                found.append(ScreenControl(name: name, frame: element.frame))
                continue
            }
            pending.append(contentsOf: element.children)
        }
        return found
    }
}

/// What a held activation meets next (invariant 10): the controls nearest
/// `point` by the distance to their centres and by the distance to their
/// nearest edge (zero inside one), each with every control within half a
/// point of the nearest, so a tie is never hidden. How Snap to Item picks a
/// target is a device check (docs/HANDOFF.md, *Checks that need a real
/// device*), so both rules are scored.
func nearestControls(to point: CGPoint, among controls: [ScreenControl]) -> (byCentre: Set<String>, byEdge: Set<String>) {
    guard !controls.isEmpty else { return ([], []) }
    func centreDistance(_ frame: CGRect) -> CGFloat {
        hypot(point.x - frame.midX, point.y - frame.midY)
    }
    func edgeDistance(_ frame: CGRect) -> CGFloat {
        let dx = max(frame.minX - point.x, 0, point.x - frame.maxX)
        let dy = max(frame.minY - point.y, 0, point.y - frame.maxY)
        return hypot(dx, dy)
    }
    let closestCentre = controls.map { centreDistance($0.frame) }.min() ?? 0
    let closestEdge = controls.map { edgeDistance($0.frame) }.min() ?? 0
    return (
        Set(controls.filter { centreDistance($0.frame) - closestCentre < 0.5 }.map(\.name)),
        Set(controls.filter { edgeDistance($0.frame) - closestEdge < 0.5 }.map(\.name))
    )
}
