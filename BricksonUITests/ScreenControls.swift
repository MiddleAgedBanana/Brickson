import XCTest

/// A button on screen, named by its accessibility identifier where it has
/// one and by its label otherwise.
struct ScreenControl: CustomStringConvertible {
    let name: String
    let frame: CGRect
    /// Whether it shows as selected: the category or Emergency showing.
    let isSelected: Bool

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
                found.append(ScreenControl(name: name, frame: element.frame, isSelected: element.isSelected))
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
/// device*), so both rules are scored. The rules are the chain engine's
/// (`ChainEngine`), which follows whole chains of them.
func nearestControls(to point: CGPoint, among controls: [ScreenControl]) -> (byCentre: Set<String>, byEdge: Set<String>) {
    (
        Set(ChainEngine.nearest(to: point, among: controls, by: .centre, frame: \.frame).map(\.name)),
        Set(ChainEngine.nearest(to: point, among: controls, by: .edge, frame: \.frame).map(\.name))
    )
}
