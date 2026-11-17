import SwiftUI

// SwiftUI's own shapes for `CornerRule`'s three kinds of corner
// (docs/DECISIONS.md, "Concentric corners"). Nothing on screen uses them
// yet: they are the foundation the app's coming look is built from, and
// `CornerShapesTests` measures what they draw against `CornerRule`.

extension CornerRule.Kind {
    /// The shape that draws this kind of corner, each with the continuous
    /// curve of Apple's own rounded shapes: a rounded rectangle with a
    /// fixed radius; a capsule; or SwiftUI's `ConcentricRectangle`, which
    /// takes each corner's radius from the nearest container shape (the
    /// window's corners, or a view's `concentricContainer(radius:)`) and
    /// never goes below the minimum.
    var shape: AnyShape {
        switch self {
        case .fixed(let radius):
            AnyShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        case .capsule:
            AnyShape(Capsule(style: .continuous))
        case .concentric(let minimum):
            AnyShape(ConcentricRectangle(corners: .concentric(minimum: .fixed(minimum)), isUniform: false))
        }
    }
}

extension View {
    /// Makes this view the container that the concentric shapes inside it
    /// measure their corners from: a rounded rectangle of `radius`, with
    /// the continuous curve. A view that draws a rounded background of its
    /// own sets the same radius here, so the shapes inside it follow its
    /// corners as a sheet's follow the screen's.
    func concentricContainer(radius: CGFloat) -> some View {
        containerShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}
