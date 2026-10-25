import Foundation
import Testing

/// Drives no app; the same resolver is compiled into unit and UI test targets.
@MainActor
struct SnapshotControlGeometryTests {
    private struct Node {
        let frame: CGRect
        var isWindow = false
        var name = ""
        var identifier = ""
        var children: [Node] = []
    }

    private func locate(
        _ root: Node, target: SnapshotControlGeometry.Identity = .init(identifier: "", label: "target")
    ) throws -> SnapshotControlGeometry.Located {
        try SnapshotControlGeometry.locate(
            in: root, frame: { $0.frame }, isWindow: { $0.isWindow },
            target: target,
            identity: { $0.name.isEmpty ? nil : .init(identifier: $0.identifier, label: $0.name) },
            children: { $0.children }
        )
    }

    /// Replacing the ancestor with the transposed app/root frame makes the
    /// actually visible control fail the existing one-point containment check.
    @Test func aTransposedRootDoesNotReplaceTheControlsWindow() throws {
        let target = CGRect(x: 690, y: 116, width: 161, height: 55)
        let window = CGRect(x: 0, y: 0, width: 951, height: 669)
        let root = Node(frame: CGRect(x: 0, y: 0, width: 669, height: 951), children: [
            Node(frame: window, isWindow: true, children: [Node(frame: target, name: "target")])
        ])
        let found = try locate(root)
        #expect(found.control == target)
        #expect(found.window == window)
        #expect(found.window.insetBy(dx: -1, dy: -1).contains(found.control))
        #expect(!root.frame.insetBy(dx: -1, dy: -1).contains(target))
    }

    /// First-window selection would use the keyboard window here. It must
    /// neither replace the target's ancestor nor cause buttons to be dropped.
    @Test func anotherWindowBeforeTheTargetDoesNotChangeItsCoordinates() throws {
        let target = CGRect(x: 480, y: 90, width: 80, height: 50)
        let window = CGRect(x: 420, y: 30, width: 469, height: 669)
        let root = Node(frame: CGRect(x: 0, y: 0, width: 951, height: 669), children: [
            Node(frame: CGRect(x: 0, y: 405, width: 951, height: 264), isWindow: true),
            Node(frame: window, isWindow: true, children: [Node(frame: target, name: "target")])
        ])
        #expect(try locate(root) == SnapshotControlGeometry.Located(control: target, window: window))
    }

    /// Broadening identity to identifier OR label incorrectly includes a
    /// different prediction control with the same label. This is a synthetic
    /// different-ID collision, not a claim about current prediction IDs.
    @Test func theSelectedControlsWholeIdentityExcludesADifferentPrediction() throws {
        let window = CGRect(x: 0, y: 0, width: 951, height: 669)
        let home = CGRect(x: 165, y: 116, width: 141, height: 55)
        let root = Node(frame: window, children: [
            Node(frame: window, isWindow: true, children: [Node(frame: home, name: "Yes")]),
            Node(frame: window, isWindow: true, children: [
                Node(frame: CGRect(x: 75, y: 405, width: 267, height: 44), name: "Yes", identifier: "prediction.Yes")
            ])
        ])
        let found = try locate(root, target: .init(identifier: "", label: "Yes"))
        #expect(found.control == home)
        #expect(found.window == window)
    }

    /// Treating an existing root frame as a missing ancestor makes this pass
    /// incorrectly; a target without a window must produce a diagnostic failure.
    @Test func aTargetWithoutAWindowAncestorIsRejected() {
        let root = Node(frame: CGRect(x: 0, y: 0, width: 951, height: 669), children: [
            Node(frame: CGRect(x: 10, y: 10, width: 44, height: 44), name: "target")
        ])
        #expect(throws: SnapshotControlGeometry.Failure.missingAncestorWindow) { try locate(root) }
    }

    /// Falling back to root/another control when the semantic target is absent fails this.
    @Test func aMissingTargetIsRejected() {
        let root = Node(frame: CGRect(x: 0, y: 0, width: 951, height: 669))
        #expect(throws: SnapshotControlGeometry.Failure.missingTarget) { try locate(root) }
    }

    /// Using firstMatch on two semantic matches, even in the same window,
    /// would hide which control was measured and fails this rejection.
    @Test func ambiguousSemanticMatchesAreRejected() {
        let button = Node(frame: CGRect(x: 10, y: 10, width: 44, height: 44), name: "target")
        let root = Node(frame: CGRect(x: 0, y: 0, width: 951, height: 669), isWindow: true,
                        children: [button, button])
        #expect(throws: SnapshotControlGeometry.Failure.ambiguousTarget) { try locate(root) }
    }
}
