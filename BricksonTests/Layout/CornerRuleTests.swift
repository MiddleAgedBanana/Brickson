import Foundation
import Testing
@testable import Brickson

/// The rule for the corners of Brickson's rounded shapes (`CornerRule`;
/// docs/DECISIONS.md, "Concentric corners"), checked as numbers.
/// `CornerShapesTests` checks that what SwiftUI draws agrees with it.
struct CornerRuleTests {
    private typealias Kind = CornerRule.Kind

    // MARK: Concentric corners

    /// A corner 12 points inside a 38-point corner gets 26, so the two
    /// curves share a centre: the inner radius plus the room between them
    /// is the outer radius. Fails if the rule stops subtracting the room,
    /// or subtracts it twice.
    @Test func aConcentricCornerIsItsContainersLessTheRoomBetween() {
        #expect(CornerRule.concentricRadius(containerRadius: 38, inset: 12, minimum: 0) == 26)
        #expect(CornerRule.concentricRadius(containerRadius: 40, inset: 10, minimum: 12) == 30)
        for containerRadius in stride(from: CGFloat(0), through: 60, by: 2) {
            for inset in stride(from: CGFloat(0), through: containerRadius, by: 2) {
                let radius = CornerRule.concentricRadius(containerRadius: containerRadius, inset: inset, minimum: 0)
                #expect(radius + inset == containerRadius, "\(containerRadius) less \(inset) gave \(radius)")
            }
        }
    }

    /// Far from its container's corner, or inside a container with square
    /// corners, the subtraction reaches zero or less, and Apple's
    /// concentric corner would be square. The minimum keeps it round.
    /// Fails if a deep corner can come out square or below its minimum.
    @Test func aDeepCornerTakesItsMinimumAndIsNeverSquare() {
        #expect(CornerRule.concentricRadius(containerRadius: 40, inset: 32, minimum: 12) == 12)
        #expect(CornerRule.concentricRadius(containerRadius: 40, inset: 400, minimum: 12) == 12)
        #expect(CornerRule.concentricRadius(containerRadius: 0, inset: 16, minimum: 12) == 12)
        for containerRadius in stride(from: CGFloat(0), through: 60, by: 5) {
            for inset in stride(from: CGFloat(0), through: 200, by: 5) {
                let radius = CornerRule.concentricRadius(
                    containerRadius: containerRadius, inset: inset, minimum: CornerRule.minimum
                )
                #expect(radius >= CornerRule.minimum, "\(containerRadius) less \(inset) gave \(radius)")
            }
        }
    }

    /// With no minimum, a corner whose room is more than its container's
    /// radius is square, never a negative radius.
    @Test func withNoMinimumADeepCornerIsSquareNotNegative() {
        #expect(CornerRule.concentricRadius(containerRadius: 10, inset: 30, minimum: 0) == 0)
    }

    /// Interactive shapes are never sharp: the minimum a concentric corner
    /// falls back to is round. It is the corner Home's controls draw today
    /// (`CornerShapesTests` pins that link), so a control that adopts the
    /// concentric shape is never sharper than it is now.
    @Test func theMinimumIsRound() {
        #expect(CornerRule.minimum > 0)
        #expect(CornerRule.minimum == 12)
    }

    // MARK: Nesting: window, grid, tile, ring

    /// A ring drawn a few points inside a concentric tile stays concentric
    /// with the tile, both where the tile takes its container's curve and
    /// where it falls back to its minimum: the ring's minimum is the
    /// tile's less the room between them. SwiftUI's own concentric shape
    /// measures every corner from the nearest container, never from the
    /// tile around it, so this is how a ring keeps the tile's centre.
    /// Fails if a ring at the tile's minimum comes out at any other radius
    /// than the tile's less the ring's inset.
    @Test func aRingInsideATileStaysConcentricWithIt() {
        let minimum = CornerRule.minimum
        for containerRadius in stride(from: CGFloat(0), through: 60, by: 2) {
            for tileInset in stride(from: CGFloat(0), through: 80, by: 2) {
                let tile = CornerRule.concentricRadius(
                    containerRadius: containerRadius, inset: tileInset, minimum: minimum
                )
                for ringInset in stride(from: CGFloat(0), through: minimum, by: 1) {
                    let ring = CornerRule.concentricRadius(
                        containerRadius: containerRadius,
                        inset: tileInset + ringInset,
                        minimum: CornerRule.minimum(minimum, insetBy: ringInset)
                    )
                    #expect(
                        ring + ringInset == tile,
                        "tile \(tile) at \(tileInset) in \(containerRadius); ring \(ringInset) in gave \(ring)"
                    )
                }
            }
        }
    }

    /// Window, grid, tile and ring, each inside the one before: each
    /// corner is the one outside it less the room between them, until a
    /// minimum takes over, and from there each is the minimum less its
    /// room. The numbers are an example, not Brickson's look.
    @Test func aWindowGridTileAndRingNestConcentrically() {
        let window: CGFloat = 38
        let grid = CornerRule.concentricRadius(containerRadius: window, inset: 8, minimum: CornerRule.minimum)
        let tile = CornerRule.concentricRadius(containerRadius: window, inset: 8 + 6, minimum: CornerRule.minimum)
        let ring = CornerRule.concentricRadius(
            containerRadius: window, inset: 8 + 6 + 3,
            minimum: CornerRule.minimum(CornerRule.minimum, insetBy: 3)
        )
        #expect([grid, tile, ring] == [30, 24, 21])

        let deepTile = CornerRule.concentricRadius(containerRadius: window, inset: 8 + 40, minimum: CornerRule.minimum)
        let deepRing = CornerRule.concentricRadius(
            containerRadius: window, inset: 8 + 40 + 3,
            minimum: CornerRule.minimum(CornerRule.minimum, insetBy: 3)
        )
        #expect([deepTile, deepRing] == [12, 9])
    }

    /// A minimum less a room larger than it is square, never negative.
    @Test func aMinimumInsetPastItselfIsSquare() {
        #expect(CornerRule.minimum(12, insetBy: 5) == 7)
        #expect(CornerRule.minimum(12, insetBy: 12) == 0)
        #expect(CornerRule.minimum(12, insetBy: 20) == 0)
    }

    /// Every ring a Home control draws ends less deep than the minimum, so
    /// once Home's controls take the concentric shape, each ring drawn
    /// concentric inside one keeps a round corner, even where the control
    /// sits at its minimum. Fails if a deeper ring is added, or the minimum
    /// shrinks below the rings.
    @Test func everyRingOfAHomeControlStaysRoundInsideTheMinimum() {
        #expect(HomeButtonLook.maximumDepth < CornerRule.minimum)
        for isEnabled in [false, true] {
            for isSelected in [false, true] {
                for isPressed in [false, true] {
                    for showsBorders in [false, true] {
                        for darkMode in [false, true] {
                            let look = HomeButtonLook(
                                isEnabled: isEnabled, isSelected: isSelected, isPressed: isPressed,
                                showsBorders: showsBorders, darkMode: darkMode
                            )
                            for ring in look.rings {
                                #expect(
                                    CornerRule.minimum(CornerRule.minimum, insetBy: ring.depth) > 0,
                                    "\(look): a ring ends \(ring.depth) in"
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: The three kinds

    /// A capsule's radius is half its height when it lies across, half its
    /// width when it stands up, and a circle's on a square.
    @Test func aCapsulesRadiusIsHalfItsShorterSide() {
        #expect(CornerRule.capsuleRadius(of: CGSize(width: 200, height: 48)) == 24)
        #expect(CornerRule.capsuleRadius(of: CGSize(width: 48, height: 200)) == 24)
        #expect(CornerRule.capsuleRadius(of: CGSize(width: 50, height: 50)) == 25)
        #expect(CornerRule.capsuleRadius(of: .zero) == 0)
    }

    /// Each kind gives the radius it promises: a fixed corner ignores its
    /// container, a capsule follows its size, and a concentric corner
    /// follows its container until its minimum.
    @Test func eachKindGivesItsOwnRadius() {
        let size = CGSize(width: 220, height: 140)
        #expect(CornerRule.radius(of: .fixed(20), size: size, containerRadius: 40, inset: 10) == 20)
        #expect(CornerRule.radius(of: .fixed(20), size: size, containerRadius: 0, inset: 300) == 20)
        #expect(CornerRule.radius(of: .capsule, size: size, containerRadius: 40, inset: 10) == 70)
        #expect(CornerRule.radius(of: .concentric(minimum: 12), size: size, containerRadius: 40, inset: 10) == 30)
        #expect(CornerRule.radius(of: .concentric(minimum: 12), size: size, containerRadius: 40, inset: 56) == 12)
    }

    /// No corner is rounder than a capsule: a fixed or concentric radius
    /// larger than half the shorter side gives the capsule's, as SwiftUI's
    /// rounded rectangle does, so a short shape inside a very round
    /// container never asks for corners that overlap.
    @Test func noCornerIsRounderThanACapsule() {
        let short = CGSize(width: 200, height: 40)
        #expect(CornerRule.radius(of: .fixed(30), size: short, containerRadius: 0, inset: 0) == 20)
        #expect(CornerRule.radius(of: .concentric(minimum: 12), size: short, containerRadius: 60, inset: 4) == 20)
        #expect(CornerRule.radius(of: .concentric(minimum: 30), size: short, containerRadius: 0, inset: 0) == 20)
    }

    /// No kind of corner gives a square or negative corner on a shape that
    /// has any size, with Brickson's minimum, however deep, however small
    /// its container's corner: interactive shapes are never sharp.
    @Test func noKindIsSquareWithTheMinimum() {
        let kinds: [Kind] = [.fixed(CornerRule.minimum), .capsule, .concentric(minimum: CornerRule.minimum)]
        for kind in kinds {
            for side in stride(from: CGFloat(4), through: 200, by: 12) {
                for inset in stride(from: CGFloat(0), through: 200, by: 20) {
                    let size = CGSize(width: side * 2, height: side)
                    let radius = CornerRule.radius(of: kind, size: size, containerRadius: 38, inset: inset)
                    #expect(radius > 0, "\(kind), \(size), \(inset) in: \(radius)")
                }
            }
        }
    }
}
