// Measures rendered contrast in a Simulator screenshot.
// usage: xcrun swiftc -O measure.swift -o measure, then: ./measure <png> <scale> <targets.json>
// targets.json: [{"name": "...", "x":..,"y":..,"w":..,"h":.., "inset": pt}]  (points)
// For each target: converts the PNG to sRGB, takes the fill as the most
// common colour inside the frame inset by `inset` points (clear of any
// ring), the words as the colour in that inner area with the highest
// contrast against the fill (and how many pixels have it), the rings as the
// colours in the band 0..inset pt inside the edge, and the page as the most
// common colour in a band 3..8 pt outside the frame. WCAG 2 contrast with
// 0.2126/0.7152/0.0722 and the 0.04045 threshold, as PaletteTests.
import CoreGraphics
import Foundation
import ImageIO

struct Target: Codable { let name: String; let x, y, w, h: Double; let inset: Double? }
struct RGB: Hashable { let r, g, b: UInt8
    var hex: String { String(format: "#%02X%02X%02X", r, g, b) }
    var luminance: Double {
        func lin(_ c: UInt8) -> Double { let v = Double(c) / 255; return v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
        return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
    }
}
func ratio(_ a: RGB, _ b: RGB) -> Double { let (l1, l2) = (max(a.luminance, b.luminance), min(a.luminance, b.luminance)); return (l1 + 0.05) / (l2 + 0.05) }

let args = CommandLine.arguments
let url = URL(fileURLWithPath: args[1]); let scale = Double(args[2])!
let targets = try JSONDecoder().decode([Target].self, from: Data(contentsOf: URL(fileURLWithPath: args[3])))
let src = CGImageSourceCreateWithURL(url as CFURL, nil)!
let image = CGImageSourceCreateImageAtIndex(src, 0, nil)!
let srcSpace = image.colorSpace.map { ($0.name as String?) ?? "unnamed" } ?? "none"
let W = image.width, H = image.height
let srgb = CGColorSpace(name: CGColorSpace.sRGB)!
var buf = [UInt8](repeating: 0, count: W * H * 4)
let ctx = CGContext(data: &buf, width: W, height: H, bitsPerComponent: 8, bytesPerRow: W * 4, space: srgb, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
ctx.draw(image, in: CGRect(x: 0, y: 0, width: W, height: H))
func px(_ x: Int, _ y: Int) -> RGB? { guard x >= 0, y >= 0, x < W, y < H else { return nil }; let i = (y * W + x) * 4; return RGB(r: buf[i], g: buf[i+1], b: buf[i+2]) }
func histogram(_ pts: [(Int, Int)]) -> [(RGB, Int)] { var h: [RGB: Int] = [:]; for (x, y) in pts { if let p = px(x, y) { h[p, default: 0] += 1 } }; return h.sorted { $0.value > $1.value } }

var out: [[String: Any]] = []
for t in targets {
    let inset = t.inset ?? 6
    let x0 = Int((t.x * scale).rounded()), y0 = Int((t.y * scale).rounded())
    let x1 = Int(((t.x + t.w) * scale).rounded()), y1 = Int(((t.y + t.h) * scale).rounded())
    let ip = Int((inset * scale).rounded())
    var inner: [(Int, Int)] = [], band: [(Int, Int)] = [], outside: [(Int, Int)] = []
    for y in y0..<y1 { for x in x0..<x1 {
        let d = min(x - x0, x1 - 1 - x, y - y0, y1 - 1 - y)
        if d >= ip { inner.append((x, y)) } else { band.append((x, y)) }
    } }
    let o0 = Int((3 * scale).rounded()), o1 = Int((8 * scale).rounded())
    for y in (y0 - o1)..<(y1 + o1) { for x in (x0 - o1)..<(x1 + o1) {
        let dx = max(x0 - x, x - (x1 - 1), 0), dy = max(y0 - y, y - (y1 - 1), 0)
        let d = max(dx, dy); if d >= o0 && d < o1 { outside.append((x, y)) }
    } }
    let ih = histogram(inner); guard let fill = ih.first?.0 else { continue }
    let words = ih.max { ratio($0.0, fill) < ratio($1.0, fill) }!
    // Pixels at (or within 0.05 of) the extreme: solid glyph cores, not anti-aliasing.
    let solid = ih.filter { ratio($0.0, fill) >= ratio(words.0, fill) - 0.05 }.reduce(0) { $0 + $1.1 }
    let page = histogram(outside).first!.0
    let bandColours = histogram(band).filter { $0.1 * 50 > band.count && $0.0 != fill }.prefix(3)
    out.append([
        "name": t.name,
        "fill": fill.hex, "fillShare": Double(ih.first!.1) / Double(inner.count),
        "words": words.0.hex, "wordsOnFill": ratio(words.0, fill), "solidWordPixels": solid,
        "page": page.hex, "fillOnPage": ratio(fill, page),
        "band": bandColours.map { ["colour": $0.0.hex, "share": Double($0.1) / Double(band.count), "onFill": ratio($0.0, fill), "onPage": ratio($0.0, page)] },
    ])
}
let result: [String: Any] = ["image": args[1], "sourceColourSpace": srcSpace, "pixels": [W, H], "targets": out]
print(String(data: try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys]), encoding: .utf8)!)
