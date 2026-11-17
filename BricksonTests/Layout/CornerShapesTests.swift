import CoreGraphics
import SwiftUI
import Testing
@testable import Brickson

/// What SwiftUI draws for `CornerRule`'s kinds of corner
/// (`CornerShapes.swift`), measured on rendered pixels against the rule's
/// own numbers (docs/DECISIONS.md, "Concentric corners"). SwiftUI works out
/// a concentric corner's radius from the container shape as it draws, and
/// gives no way to read it back, so each test draws the shape black on
/// white, draws rounded rectangles of nearby radii the same way, and takes
/// the radius whose drawing matches it best. A blank drawing fails at
/// once; one that came out square or at another radius matches a radius at
/// the edge of the search, and the test fails.
struct CornerShapesTests {
    private typealias Kind = CornerRule.Kind

    /// The room every drawing fills, in points: the container.
    private static let canvas = CGSize(width: 240, height: 160)
    /// The container's corner radius. The numbers are an example, not
    /// Brickson's look.
    private static let containerRadius: CGFloat = 40
    /// Two pixels to a point, as on a 2x screen: half a point is a pixel.
    private static let scale: CGFloat = 2
    /// How far either side of the rule's radius the measure looks, in
    /// points.
    private static let searchRange: CGFloat = 4

    /// The red value (all three are the same, black on white) of every
    /// pixel of `shape` filled black, `inset` points inside the canvas on
    /// every side, with the canvas as the concentric container.
    private static func drawing(of shape: some Shape, inset: CGFloat) -> [UInt8]? {
        let view = ZStack {
            Color.white
            shape.fill(Color.black).padding(inset)
        }
        .frame(width: canvas.width, height: canvas.height)
        .concentricContainer(radius: containerRadius)
        let renderer = ImageRenderer(content: view)
        renderer.scale = scale
        guard let image = renderer.cgImage else { return nil }
        let width = image.width
        let height = image.height
        guard width > 0, height > 0, let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: space,
                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
              )
        else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let data = context.data else { return nil }
        let bytes = data.bindMemory(to: UInt8.self, capacity: width * height * 4)
        return (0..<(width * height)).map { bytes[$0 * 4] }
    }

    /// The rounded rectangle that draws most like `drawn`.
    private struct Match {
        let radius: CGFloat
        let isContinuous: Bool
        /// The sum, over every pixel, of how far apart the two greys are.
        let difference: Int
    }

    /// Compares `drawn` with rounded rectangles `inset` points in, of radii
    /// every half point within `searchRange` of `radius`, with the
    /// continuous curve and the circular one, and gives the closest. On a
    /// tie, the smaller radius wins, so drawings that do not change with
    /// the radius match the edge of the search.
    private static func closestRoundedRectangle(to drawn: [UInt8], inset: CGFloat, near radius: CGFloat) -> Match? {
        var best: Match?
        for candidate in stride(from: max(radius - searchRange, 0), through: radius + searchRange, by: 0.5) {
            for isContinuous in [true, false] {
                let shape = RoundedRectangle(cornerRadius: candidate, style: isContinuous ? .continuous : .circular)
                guard let pixels = drawing(of: shape, inset: inset), pixels.count == drawn.count else { return nil }
                let difference = zip(drawn, pixels).reduce(0) { $0 + abs(Int($1.0) - Int($1.1)) }
                if best.map({ difference < $0.difference }) ?? true {
                    best = Match(radius: candidate, isContinuous: isContinuous, difference: difference)
                }
            }
        }
        return best
    }

    /// Draws `kind`'s shape `inset` points inside the container and checks
    /// that its corners measure the radius `CornerRule` gives, to half a
    /// point (a pixel at 2x).
    private static func expectDrawnRadius(
        of kind: Kind, inset: CGFloat, _ note: String, sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        let size = CGSize(width: canvas.width - 2 * inset, height: canvas.height - 2 * inset)
        let expected = CornerRule.radius(of: kind, size: size, containerRadius: containerRadius, inset: inset)
        let drawn = try #require(drawing(of: kind.shape, inset: inset), "\(note): nothing drawn", sourceLocation: sourceLocation)
        // A blank drawing is closest to the roundest candidate, and for a
        // capsule every candidate from its own radius up draws the capsule,
        // so a blank drawing would match it: it fails here instead.
        try #require(drawn.contains(where: { $0 < 128 }), "\(note): the drawing is blank", sourceLocation: sourceLocation)
        let match = try #require(
            closestRoundedRectangle(to: drawn, inset: inset, near: expected),
            "\(note): nothing to compare", sourceLocation: sourceLocation
        )
        #expect(
            abs(match.radius - expected) <= 0.5,
            "\(note): the rule gives \(expected); SwiftUI drew \(match.radius) (\(match.isContinuous ? "continuous" : "circular"), off by \(match.difference))",
            sourceLocation: sourceLocation
        )
    }

    /// A concentric shape 10 points inside a 40-point corner draws a
    /// 30-point corner: its container's less the room between them. Fails
    /// if SwiftUI measured the room another way (along the diagonal would
    /// give about 26), or the container shape did not reach it (the
    /// minimum, 12).
    @Test func aConcentricShapeTakesItsContainersCurveLessTheRoom() throws {
        #expect(CornerRule.radius(
            of: .concentric(minimum: CornerRule.minimum), size: CGSize(width: 220, height: 140),
            containerRadius: Self.containerRadius, inset: 10
        ) == 30)
        try Self.expectDrawnRadius(of: .concentric(minimum: CornerRule.minimum), inset: 10, "10 points in")
    }

    /// Farther in, where the container's radius less the room is under the
    /// minimum, or under zero, SwiftUI draws the minimum: a deep tile is
    /// never square. Fails if the minimum is lost on the way to
    /// `ConcentricRectangle`.
    @Test func aConcentricShapeFarFromTheCornerTakesItsMinimum() throws {
        try Self.expectDrawnRadius(of: .concentric(minimum: CornerRule.minimum), inset: 32, "32 points in")
        try Self.expectDrawnRadius(of: .concentric(minimum: CornerRule.minimum), inset: 56, "56 points in")
    }

    /// A ring 6 points inside a concentric tile, drawn with the minimum
    /// `CornerRule.minimum(_:insetBy:)` gives it, keeps the tile's centre:
    /// 6 points less than the tile's corner, both where the tile takes the
    /// container's curve (10 points in: 30, so 24) and where it falls back
    /// to its minimum (32 points in: 12, so 6).
    @Test func aRingStaysConcentricWithItsTile() throws {
        let ring = Kind.concentric(minimum: CornerRule.minimum(CornerRule.minimum, insetBy: 6))
        try Self.expectDrawnRadius(of: ring, inset: 10 + 6, "a ring 6 points inside a tile 10 points in")
        try Self.expectDrawnRadius(of: ring, inset: 32 + 6, "a ring 6 points inside a tile 32 points in")
    }

    /// A fixed corner draws its own radius whatever its container.
    @Test func aFixedShapeIgnoresItsContainer() throws {
        try Self.expectDrawnRadius(of: .fixed(20), inset: 10, "a fixed 20-point corner 10 points in")
    }

    /// A capsule draws half its shorter side, whatever its container: 30
    /// points on a shape 140 by 60. Every rounded rectangle rounder than
    /// that draws the same as it, and a tie goes to the smaller radius, so
    /// the measure finds 30. Fails if the capsule kind draws any other
    /// shape, such as a fixed corner.
    @Test func aCapsuleDrawsHalfItsShorterSide() throws {
        #expect(CornerRule.radius(
            of: .capsule, size: CGSize(width: 140, height: 60), containerRadius: Self.containerRadius, inset: 50
        ) == 30)
        try Self.expectDrawnRadius(of: .capsule, inset: 50, "a capsule 50 points in")
    }

    /// The minimum is the corner Home's controls draw today, so a control
    /// that takes the concentric shape is never sharper than it is now.
    /// Fails if either changes without the other: a decision for the look,
    /// recorded in docs/DECISIONS.md.
    @Test func theMinimumIsTheCornerHomeDrawsToday() {
        #expect(CornerRule.minimum == HomeButtonStyle.cornerRadius)
    }
}
