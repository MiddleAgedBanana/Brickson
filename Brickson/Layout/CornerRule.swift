import Foundation

/// The rule for the corners of Brickson's rounded shapes (docs/DECISIONS.md,
/// "Concentric corners"). Apple's design gives every rounded shape one of
/// three kinds of corner: a fixed radius; a capsule, whose radius is half
/// its shorter side; or a concentric corner, whose radius is its
/// container's radius less the room between them, so that the two curves
/// share a centre, as a sheet's corners follow the screen's.
///
/// SwiftUI draws the concentric kind itself, with `ConcentricRectangle`,
/// from the nearest container shape: the window's own corners, or a view's
/// `containerShape(_:)` (`CornerRule.Kind.shape` and
/// `concentricContainer(radius:)`). This type is the same rule written out
/// as numbers, so the layout engine and the tests can know a corner's
/// radius without drawing it, and `CornerShapesTests` checks that what
/// SwiftUI draws agrees with it.
///
/// Brickson's concentric corners always have a minimum: deep inside a
/// grid, far from any rounded corner, the subtraction reaches zero and
/// Apple's concentric corner is square, and interactive shapes are never
/// sharp. The rule is written for the same room across and down, which is
/// how a shape padded evenly sits in its container.
///
/// Nothing here depends on the device, the window or the orientation:
/// the container's radius comes from the space the shape is in.
nonisolated enum CornerRule {
    /// The three kinds of corner Apple's design uses.
    enum Kind: Equatable, Sendable {
        /// The same radius in every container.
        case fixed(CGFloat)
        /// Half the shape's shorter side.
        case capsule
        /// The container's radius less the room between them, never less
        /// than `minimum`.
        case concentric(minimum: CGFloat)
    }

    /// The smallest radius Brickson's concentric corners fall back to: the
    /// corner Home's controls draw today (`HomeButtonStyle.cornerRadius`),
    /// so a control that takes the concentric shape is never sharper than
    /// it is now. A later look may change it, here, in one place.
    static let minimum: CGFloat = 12

    /// The radius of a corner `inset` points inside a container corner of
    /// `containerRadius`, across and down: the container's radius less the
    /// room between them, or `minimum` where that is smaller. Never
    /// negative: with no minimum, a corner farther in than its container's
    /// radius is square.
    static func concentricRadius(containerRadius: CGFloat, inset: CGFloat, minimum: CGFloat) -> CGFloat {
        max(containerRadius - inset, minimum, 0)
    }

    /// A capsule's radius: half the shorter side of `size`.
    static func capsuleRadius(of size: CGSize) -> CGFloat {
        max(min(size.width, size.height), 0) / 2
    }

    /// The radius a shape of `size` with `kind` corners takes, `inset`
    /// points inside a container corner of `containerRadius` (both ignored
    /// unless the corner is concentric). No corner is rounder than a
    /// capsule: a larger radius gives the capsule's, as SwiftUI's rounded
    /// rectangle draws it.
    static func radius(of kind: Kind, size: CGSize, containerRadius: CGFloat, inset: CGFloat) -> CGFloat {
        let roundest = capsuleRadius(of: size)
        switch kind {
        case .fixed(let radius):
            return min(max(radius, 0), roundest)
        case .capsule:
            return roundest
        case .concentric(let minimum):
            return min(concentricRadius(containerRadius: containerRadius, inset: inset, minimum: minimum), roundest)
        }
    }

    /// The minimum for a corner `inset` points inside a concentric shape
    /// whose minimum is `minimum`, such as a ring drawn inside a tile.
    /// SwiftUI measures every concentric corner from the nearest container,
    /// never from the shape around it; with this minimum, the inner corner
    /// keeps the outer one's centre even where the outer one has fallen
    /// back to its own minimum. Never negative.
    static func minimum(_ minimum: CGFloat, insetBy inset: CGFloat) -> CGFloat {
        max(minimum - inset, 0)
    }
}
