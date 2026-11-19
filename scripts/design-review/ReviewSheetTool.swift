import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

// The design review sheet's command-line tool, run by capture.py on the
// Mac. Build it beside the scripts with
//
//     xcrun swiftc -O -parse-as-library ReviewPixels.swift ReviewSheetTool.swift -o review-sheet
//
//   review-sheet measure <png> <scale> <targets.json>
//       Each target ({"name", "x", "y", "w", "h", "inset"?}, points) read
//       from the capture (ReviewMeasure.read), as JSON on standard output.
//   review-sheet locate <png> <scale> <x> <y> <hex>
//       Where the run of <hex> through the point (points) starts, left and
//       up, in points: {"left", "top"}.
//   review-sheet colour <png> <scale> <x> <y>
//       The commonest colour in the point round (x, y): {"colour"}.
//   review-sheet diff <a.png> <b.png> <scale> [<top> <bottom> ...]
//       How many pixels differ between two captures of one size, and the
//       box round them in points; only in the bands of rows given (points),
//       or everywhere.
//   review-sheet compose <layout.json> <out.png>
//       The side-by-side sheet: crops of captures at their own pixels, one
//       column for each appearance, with captions under each.

@main
struct ReviewSheetTool {
    static func main() {
        let arguments = Array(CommandLine.arguments.dropFirst())
        do {
            switch arguments.first {
            case "measure" where arguments.count == 4: try measure(arguments[1], arguments[2], arguments[3])
            case "locate" where arguments.count == 6: try locate(Array(arguments[1...]))
            case "colour" where arguments.count == 5: try colour(Array(arguments[1...]))
            case "diff" where arguments.count >= 4 && arguments.count % 2 == 0:
                try diff(arguments[1], arguments[2], arguments[3], rows: Array(arguments[4...]))
            case "compose" where arguments.count == 3: try compose(arguments[1], arguments[2])
            default: throw ToolError("usage: review-sheet measure|locate|diff|compose … (see the file's first lines)")
            }
        } catch {
            FileHandle.standardError.write(Data("review-sheet: \(error)\n".utf8))
            exit(1)
        }
    }

    struct ToolError: Error, CustomStringConvertible {
        let description: String
        init(_ description: String) { self.description = description }
    }

    static func bitmap(_ path: String) throws -> ReviewBitmap {
        guard let bitmap = ReviewBitmap(contentsOf: URL(fileURLWithPath: path)) else { throw ToolError("cannot read \(path)") }
        return bitmap
    }

    static func number(_ text: String) throws -> Double {
        guard let value = Double(text), value.isFinite else { throw ToolError("not a number: \(text)") }
        return value
    }

    static func printJSON(_ value: some Encodable) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        print(String(decoding: try encoder.encode(value), as: UTF8.self))
    }

    // MARK: - measure

    struct Target: Codable {
        let name: String
        let x, y, w, h: Double
        let inset: Double?
    }

    struct Measured: Codable {
        let name: String
        let frame: ReviewRect
        let reading: ReviewReading?
    }

    static func measure(_ png: String, _ scaleText: String, _ targetsPath: String) throws {
        let image = try bitmap(png)
        let scale = try number(scaleText)
        let targets = try JSONDecoder().decode([Target].self, from: Data(contentsOf: URL(fileURLWithPath: targetsPath)))
        let measured = targets.map { target in
            let frame = ReviewRect(x: target.x, y: target.y, width: target.w, height: target.h)
            return Measured(name: target.name, frame: frame, reading: ReviewMeasure.read(image, frame: frame, scale: scale, inset: target.inset ?? ReviewMeasure.defaultInset))
        }
        try printJSON(measured)
    }

    // MARK: - locate

    static func locate(_ arguments: [String]) throws {
        let image = try bitmap(arguments[0])
        let scale = try number(arguments[1])
        let (x, y) = (try number(arguments[2]), try number(arguments[3]))
        guard let colour = ReviewColour(hex: arguments[4]) else { throw ToolError("not a colour: \(arguments[4])") }
        guard let start = ReviewMeasure.runStart(of: colour, in: image, x: Int((x * scale).rounded()), y: Int((y * scale).rounded())) else {
            throw ToolError("\(arguments[4]) is not at \(arguments[2]),\(arguments[3])")
        }
        try printJSON(["left": Double(start.left) / scale, "top": Double(start.top) / scale])
    }

    // MARK: - colour

    static func colour(_ arguments: [String]) throws {
        let image = try bitmap(arguments[0])
        let scale = try number(arguments[1])
        let (x, y) = (try number(arguments[2]), try number(arguments[3]))
        var counts: [ReviewColour: Int] = [:]
        let (px, py, reach) = (Int((x * scale).rounded()), Int((y * scale).rounded()), max(1, Int(scale / 2)))
        for dy in -reach...reach {
            for dx in -reach...reach {
                if let colour = image.colour(x: px + dx, y: py + dy) { counts[colour, default: 0] += 1 }
            }
        }
        guard let found = ReviewMeasure.commonest(counts) else { throw ToolError("\(arguments[2]),\(arguments[3]) is outside the capture") }
        try printJSON(["colour": found.hex])
    }

    // MARK: - diff

    struct Difference: Codable {
        let pixels: Int
        let box: ReviewRect?
    }

    static func diff(_ first: String, _ second: String, _ scaleText: String, rows: [String]) throws {
        let (a, b) = (try bitmap(first), try bitmap(second))
        let scale = try number(scaleText)
        guard a.width == b.width, a.height == b.height else { throw ToolError("the captures differ in size") }
        let edges = try rows.map { Int((try number($0) * scale).rounded()) }
        let bands = stride(from: 0, to: edges.count, by: 2).map { max(0, edges[$0])..<min(a.height, max(edges[$0], edges[$0 + 1])) }
        let lines = bands.isEmpty ? [0..<a.height] : bands
        var count = 0, minX = Int.max, minY = Int.max, maxX = -1, maxY = -1
        for y in lines.joined() {
            for x in 0..<a.width where a.colour(x: x, y: y) != b.colour(x: x, y: y) {
                count += 1
                minX = min(minX, x); minY = min(minY, y); maxX = max(maxX, x); maxY = max(maxY, y)
            }
        }
        let box = count == 0 ? nil : ReviewRect(
            x: Double(minX) / scale, y: Double(minY) / scale,
            width: Double(maxX - minX + 1) / scale, height: Double(maxY - minY + 1) / scale
        )
        try printJSON(Difference(pixels: count, box: box))
    }

    // MARK: - compose

    struct Layout: Codable {
        let title: String
        let subtitle: String?
        let columns: [String]
        let rows: [Row]
    }

    struct Row: Codable {
        let label: String
        let cells: [Cell?]
    }

    struct Cell: Codable {
        let image: String
        /// The crop, in the capture's pixels.
        let crop: ReviewRect
        let caption: [String]
        /// Whether a caption line reports a pair under its target.
        let fails: Bool
    }

    static let margin: CGFloat = 32
    static let gap: CGFloat = 24
    static let labelWidth: CGFloat = 340
    static let textSize: CGFloat = 24
    static let lineHeight: CGFloat = 32
    static let ink = CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1)
    /// A dark red that reads at 6.5:1 on white, for a pair under its target.
    static let failInk = CGColor(srgbRed: 0.69, green: 0, blue: 0.125, alpha: 1)

    static func font(size: CGFloat = textSize, bold: Bool = false) -> CTFont {
        CTFontCreateUIFontForLanguage(bold ? .emphasizedSystem : .system, size, nil)
            ?? CTFontCreateWithName("Helvetica" as CFString, size, nil)
    }

    static func line(_ string: String, size: CGFloat = textSize, bold: Bool = false, colour: CGColor = ink) -> CTLine {
        let attributes: [CFString: Any] = [kCTFontAttributeName: font(size: size, bold: bold), kCTForegroundColorAttributeName: colour]
        return CTLineCreateWithAttributedString(CFAttributedStringCreate(nil, string as CFString, attributes as CFDictionary))
    }

    /// How wide a line of text draws, with a little room after it.
    static func textWidth(_ string: String, bold: Bool = false) -> CGFloat {
        CGFloat(CTLineGetTypographicBounds(line(string, bold: bold), nil, nil, nil)) + 12
    }

    static func compose(_ layoutPath: String, _ outPath: String) throws {
        let layout = try JSONDecoder().decode(Layout.self, from: Data(contentsOf: URL(fileURLWithPath: layoutPath)))
        var sources: [String: CGImage] = [:]
        func source(_ path: String) throws -> CGImage {
            if let image = sources[path] { return image }
            guard let reader = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
                  let image = CGImageSourceCreateImageAtIndex(reader, 0, nil) else { throw ToolError("cannot read \(path)") }
            sources[path] = image
            return image
        }
        let columnCount = layout.columns.count
        // Wide enough for its heading and every caption, as well as its crops.
        var widths = layout.columns.map { max(200, textWidth($0, bold: true)) }
        var heights: [CGFloat] = []
        for row in layout.rows {
            var tallest: CGFloat = lineHeight
            for (index, cell) in row.cells.enumerated() where index < columnCount {
                guard let cell else {
                    widths[index] = max(widths[index], textWidth("not captured"))
                    continue
                }
                widths[index] = max(widths[index], CGFloat(cell.crop.width), cell.caption.map { textWidth($0) }.max() ?? 0)
                tallest = max(tallest, CGFloat(cell.crop.height) + CGFloat(cell.caption.count) * lineHeight + 8)
            }
            heights.append(tallest)
        }
        let headerHeight = lineHeight * (layout.subtitle == nil ? 3 : 4)
        let width = margin * 2 + labelWidth + widths.reduce(0, +) + gap * CGFloat(columnCount)
        let height = margin * 2 + headerHeight + heights.reduce(0, +) + gap * CGFloat(layout.rows.count)
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil, width: Int(width), height: Int(height), bitsPerComponent: 8, bytesPerRow: 0,
                space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else { throw ToolError("cannot make a \(Int(width))x\(Int(height)) picture") }
        context.interpolationQuality = .none
        context.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        // Top-down coordinates: CoreGraphics counts from the bottom.
        func flip(_ y: CGFloat, _ h: CGFloat) -> CGFloat { height - y - h }
        func text(_ string: String, x: CGFloat, top: CGFloat, size: CGFloat = textSize, bold: Bool = false, colour: CGColor = ink) {
            context.textPosition = CGPoint(x: x, y: flip(top, 0) - size)
            CTLineDraw(line(string, size: size, bold: bold, colour: colour), context)
        }

        text(layout.title, x: margin, top: margin, size: 36, bold: true)
        if let subtitle = layout.subtitle { text(subtitle, x: margin, top: margin + lineHeight * 1.5) }
        var x = margin + labelWidth
        let headerTop = margin + headerHeight - lineHeight
        for (index, column) in layout.columns.enumerated() {
            text(column, x: x, top: headerTop, bold: true)
            x += widths[index] + gap
        }
        var top = margin + headerHeight
        for (rowIndex, row) in layout.rows.enumerated() {
            text(row.label, x: margin, top: top, bold: true)
            x = margin + labelWidth
            for (index, cell) in row.cells.enumerated() where index < columnCount {
                defer { x += widths[index] + gap }
                guard let cell else {
                    text("not captured", x: x, top: top)
                    continue
                }
                let image = try source(cell.image)
                let crop = CGRect(x: cell.crop.x, y: cell.crop.y, width: cell.crop.width, height: cell.crop.height).integral
                guard let piece = image.cropping(to: crop) else { throw ToolError("crop outside \(cell.image)") }
                let size = CGSize(width: piece.width, height: piece.height)
                context.draw(piece, in: CGRect(x: x, y: flip(top, size.height), width: size.width, height: size.height))
                var line = top + size.height + 4
                for caption in cell.caption {
                    let failing = cell.fails && caption.contains("under")
                    text(caption, x: x, top: line, colour: failing ? failInk : ink)
                    line += lineHeight
                }
            }
            top += heights[rowIndex] + gap
        }
        guard let picture = context.makeImage(),
              let destination = CGImageDestinationCreateWithURL(URL(fileURLWithPath: outPath) as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw ToolError("cannot write \(outPath)")
        }
        CGImageDestinationAddImage(destination, picture, nil)
        guard CGImageDestinationFinalize(destination) else { throw ToolError("cannot write \(outPath)") }
    }
}
