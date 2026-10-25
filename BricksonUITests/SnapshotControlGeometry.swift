import Foundation

/// Pure test infrastructure: the target and its ancestor window share one
/// supplied snapshot. Never substitutes the application/root frame.
@MainActor
enum SnapshotControlGeometry {
    struct Identity: Equatable {
        let identifier: String
        let label: String
    }

    struct Located: Equatable {
        let control: CGRect
        let window: CGRect
    }

    enum Failure: Error, Equatable {
        case missingTarget
        case ambiguousTarget
        case missingAncestorWindow
    }

    static func locate<Node>(
        in root: Node,
        frame: (Node) -> CGRect,
        isWindow: (Node) -> Bool,
        target: Identity,
        identity: (Node) -> Identity?,
        children: (Node) -> [Node]
    ) throws -> Located {
        var matches: [(control: CGRect, window: CGRect?)] = []
        func walk(_ node: Node, window: CGRect?) {
            let ancestor = isWindow(node) ? frame(node) : window
            if identity(node) == target { matches.append((frame(node), ancestor)) }
            for child in children(node) { walk(child, window: ancestor) }
        }
        walk(root, window: nil)
        guard !matches.isEmpty else { throw Failure.missingTarget }
        guard matches.count == 1 else { throw Failure.ambiguousTarget }
        guard let window = matches[0].window else { throw Failure.missingAncestorWindow }
        return Located(control: matches[0].control, window: window)
    }
}
