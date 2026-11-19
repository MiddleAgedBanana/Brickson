import CoreGraphics
import Foundation
import ImageIO

// The arithmetic of the design review sheet's measurements, kept apart
// from the command-line tool (`ReviewSheetTool.swift`) so the unit tests
// compile it too and check it on pictures made for them
// (`ReviewPixelsTests`). Plain CoreGraphics and ImageIO; nothing here
// knows a device, a simulator or the app.
//
// A capture is read as sRGB. Contrast is WCAG 2's, with the luminance
// coefficients 0.2126, 0.7152 and 0.0722 and the 0.04045 threshold, as
// `PaletteTests` measures it.

/// One pixel's colour in sRGB.
nonisolated struct ReviewColour: Hashable, Codable, Sendable {
    let r: UInt8
    let g: UInt8
    let b: UInt8

    init(r: UInt8, g: UInt8, b: UInt8) {
        self.r = r
        self.g = g
        self.b = b
    }

    /// `#RRGGBB`, or nil for anything else.
    init?(hex: String) {
        guard hex.count == 7, hex.first == "#", let value = UInt32(hex.dropFirst(), radix: 16) else { return nil }
        r = UInt8((value >> 16) & 0xFF)
        g = UInt8((value >> 8) & 0xFF)
        b = UInt8(value & 0xFF)
    }

    var hex: String { String(format: "#%02X%02X%02X", r, g, b) }

    /// WCAG 2's relative luminance.
    var luminance: Double {
        func linear(_ component: UInt8) -> Double {
            let value = Double(component) / 255
            return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
    }

    /// WCAG 2's contrast ratio, from 1 to 21, whichever is lighter.
    func contrast(with other: ReviewColour) -> Double {
        let (lighter, darker) = (max(luminance, other.luminance), min(luminance, other.luminance))
        return (lighter + 0.05) / (darker + 0.05)
    }
}

/// A capture's pixels, converted to 8-bit sRGB.
nonisolated struct ReviewBitmap: Sendable {
    let width: Int
    let height: Int
    private let bytes: [UInt8]

    init?(_ image: CGImage) {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        let (width, height) = (image.width, image.height)
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: width * 4, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return nil }
        self.width = width
        self.height = height
        self.bytes = bytes
    }

    init?(contentsOf url: URL) {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        self.init(image)
    }

    /// The colour at a pixel, counted from the top left; nil outside.
    func colour(x: Int, y: Int) -> ReviewColour? {
        guard x >= 0, y >= 0, x < width, y < height else { return nil }
        let index = (y * width + x) * 4
        return ReviewColour(r: bytes[index], g: bytes[index + 1], b: bytes[index + 2])
    }
}

/// A rectangle in points, as AXe and XCTest report frames.
nonisolated struct ReviewRect: Codable, Equatable, Sendable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double

    /// The same rectangle moved by `dx`, `dy` points.
    func offsetBy(dx: Double, dy: Double) -> ReviewRect {
        ReviewRect(x: x + dx, y: y + dy, width: width, height: height)
    }
}

/// What one specimen measures in one capture.
nonisolated struct ReviewReading: Codable, Equatable, Sendable {
    /// The commonest colour inside the frame, clear of any ring: the fill,
    /// or the screen for words drawn on it.
    let fill: String
    /// The colour inside the frame that stands out most from the fill: the
    /// words or the symbol.
    let words: String
    let wordsOnFill: Double
    /// How many pixels reach that contrast: solid strokes, not the soft
    /// edges of letters. A handful means the words were too thin to read.
    let wordPixels: Int
    /// The commonest colour in the outermost band inside the frame: the
    /// fill's own edge, or a border drawn over it.
    let edge: String
    /// The commonest colour just outside the frame: the screen.
    let page: String
    let edgeOnPage: Double
    let fillOnPage: Double
    /// The other colours in the band inside the edge (rings), each with
    /// its contrast on the fill.
    let rings: [Ring]

    nonisolated struct Ring: Codable, Equatable, Sendable {
        let colour: String
        let onFill: Double
    }
}

nonisolated enum ReviewMeasure {
    /// How far inside the edge the fill and words are read, in points:
    /// past the deepest ring Home draws (`HomeButtonLook`: 2 + 3).
    static let defaultInset: Double = 6
    /// The outermost band, in points, read as the edge.
    static let edgeBand: Double = 1.5
    /// The ring outside the frame, in points, read as the screen.
    static let pageBand: ClosedRange<Double> = 3...8
    /// The fewest pixels a colour needs to count as the words, so a stray
    /// pixel of a neighbour's colour is never taken for them.
    static let minimumWordPixels = 6

    /// Reads one specimen. `frame` is in points, `scale` pixels per point.
    /// Nil where the frame holds no pixel of the capture.
    static func read(_ bitmap: ReviewBitmap, frame: ReviewRect, scale: Double, inset: Double = defaultInset) -> ReviewReading? {
        let x0 = Int((frame.x * scale).rounded()), y0 = Int((frame.y * scale).rounded())
        let x1 = Int(((frame.x + frame.width) * scale).rounded()), y1 = Int(((frame.y + frame.height) * scale).rounded())
        guard x1 > x0, y1 > y0 else { return nil }
        let innerDepth = Int((inset * scale).rounded()), edgeDepth = max(1, Int((edgeBand * scale).rounded()))
        var inner: [ReviewColour: Int] = [:], edge: [ReviewColour: Int] = [:], band: [ReviewColour: Int] = [:], page: [ReviewColour: Int] = [:]
        for y in y0..<y1 {
            for x in x0..<x1 {
                guard let colour = bitmap.colour(x: x, y: y) else { continue }
                let depth = min(x - x0, x1 - 1 - x, y - y0, y1 - 1 - y)
                if depth < edgeDepth { edge[colour, default: 0] += 1 }
                if depth >= innerDepth {
                    inner[colour, default: 0] += 1
                } else {
                    band[colour, default: 0] += 1
                }
            }
        }
        let near = Int((pageBand.lowerBound * scale).rounded()), far = Int((pageBand.upperBound * scale).rounded())
        for y in (y0 - far)..<(y1 + far) {
            for x in (x0 - far)..<(x1 + far) {
                let distance = max(x0 - x, x - (x1 - 1), y0 - y, y - (y1 - 1), 0)
                if distance >= near, distance < far, let colour = bitmap.colour(x: x, y: y) {
                    page[colour, default: 0] += 1
                }
            }
        }
        guard let fill = commonest(inner) ?? commonest(band), let outermost = commonest(edge) else { return nil }
        let pageColour = commonest(page) ?? outermost
        // What meets the screen at the edge: the commonest colour of the
        // outermost band that is not the screen itself, where it covers at
        // least a tenth of the band. A capsule's round ends leave much of
        // its frame's band showing the screen; the shape's own edge is the
        // rest. A shape no different from the screen has no edge: the screen.
        let edgeTotal = edge.values.reduce(0, +)
        let edgeColour = commonest(edge.filter { $0.key != pageColour })
            .flatMap { colour in (edge[colour] ?? 0) * 10 >= edgeTotal ? colour : nil } ?? pageColour
        let candidates = inner.filter { $0.value >= minimumWordPixels }
        let words = candidates.keys.max { lhs, rhs in
            let (a, b) = (lhs.contrast(with: fill), rhs.contrast(with: fill))
            return a == b ? lhs.hex > rhs.hex : a < b
        } ?? fill
        let wordsRatio = words.contrast(with: fill)
        let wordPixels = inner.filter { $0.key.contrast(with: fill) >= wordsRatio - 0.05 }.values.reduce(0, +)
        let bandTotal = band.values.reduce(0, +)
        let rings = band
            .filter { $0.key != fill && $0.key != pageColour && $0.value * 20 > bandTotal }
            .sorted { $0.value == $1.value ? $0.key.hex < $1.key.hex : $0.value > $1.value }
            .prefix(3)
            .map { ReviewReading.Ring(colour: $0.key.hex, onFill: rounded($0.key.contrast(with: fill))) }
        return ReviewReading(
            fill: fill.hex, words: words.hex, wordsOnFill: rounded(wordsRatio), wordPixels: wordPixels,
            edge: edgeColour.hex, page: pageColour.hex,
            edgeOnPage: rounded(edgeColour.contrast(with: pageColour)), fillOnPage: rounded(fill.contrast(with: pageColour)),
            rings: Array(rings)
        )
    }

    /// The commonest colour, the lowest hex where two tie, so a reading
    /// never depends on the order of a dictionary.
    static func commonest(_ counts: [ReviewColour: Int]) -> ReviewColour? {
        counts.max { $0.value == $1.value ? $0.key.hex > $1.key.hex : $0.value < $1.value }?.key
    }

    /// Two decimals, as the sheet prints them.
    static func rounded(_ ratio: Double) -> Double {
        (ratio * 100).rounded() / 100
    }

    /// The edges of the run of `colour` through the pixel (`x`, `y`): how
    /// far it reaches left and up, in pixels. Used to find where a window
    /// starts, from a specimen whose frame inside the window is known.
    static func runStart(of colour: ReviewColour, in bitmap: ReviewBitmap, x: Int, y: Int) -> (left: Int, top: Int)? {
        guard bitmap.colour(x: x, y: y) == colour else { return nil }
        var left = x, top = y
        while bitmap.colour(x: left - 1, y: y) == colour { left -= 1 }
        while bitmap.colour(x: x, y: top - 1) == colour { top -= 1 }
        return (left, top)
    }
}

/// The rule the sheet's README applies: words at 4.5:1, a control's edge
/// at 3:1 (AGENTS.md, invariant 6).
nonisolated enum ReviewTargets {
    static let words = 4.5
    static let edge = 3.0
}
