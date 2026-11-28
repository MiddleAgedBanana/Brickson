import CoreGraphics
import SwiftUI
import Testing
@testable import Brickson

/// Marking the word being spoken changes only how the words are drawn:
/// their brightness and a bar under one of them. No word moves, grows or
/// changes weight, so nothing a person reads or points at shifts while the
/// voice speaks. These tests draw Home's message as Home draws it
/// (`SpokenMessageWords`) and compare the pixels with and without the
/// mark.
@MainActor
struct SpokenWordFramesTests {
    private static let message = "Please bring my glasses and the warm blanket now"
    private static let width: CGFloat = 320
    private static let scale: CGFloat = 2

    /// Every glyph of the unmarked message is still drawn where it was
    /// (dimmed or not), and nothing new is drawn anywhere but in the bar's
    /// room under a line. Fails if the marking moves, grows or bolds a
    /// word, or if the Text is built differently while a word is marked.
    @Test(arguments: [false, true])
    func theMarkingMovesNoWord(increasedContrast: Bool) throws {
        let words = MessageWords(Self.message)
        let style = SpokenWordStyle(increasedContrast: increasedContrast)
        let plain = try render(marking: nil, increasedContrast: increasedContrast)
        let lines = try recordLines()
        #expect(lines.count >= 2, "the sample should wrap, so the bar under an upper line is checked")

        let markings: [WordMarking] = [
            .nothingReported,
            words.marking(reported: words.places[0]),
            words.marking(reported: words.places[3]),
            words.marking(reported: words.places[words.places.count - 1]),
        ]
        for marking in markings {
            let marked = try render(marking: marking, increasedContrast: increasedContrast)
            #expect(marked.width == plain.width && marked.height == plain.height)
            var movedInk = 0
            var lostInk = 0
            for y in 0..<plain.height {
                let point = CGFloat(y) / Self.scale
                let inBarRoom = lines.contains { line in
                    let top = line.baseline + line.descent
                    return point >= top - 0.5 && point <= top + style.roomBelow + 0.5
                }
                for x in 0..<plain.width {
                    let before = plain.alpha(x, y)
                    let after = marked.alpha(x, y)
                    if after > 0.25, before < 0.02, !inBarRoom { movedInk += 1 }
                    if before > 0.7, after < 0.7 * style.dimOpacity - 0.15 { lostInk += 1 }
                }
            }
            #expect(movedInk == 0, "ink drawn where no word was, \(marking)")
            #expect(lostInk == 0, "a word's ink went missing, \(marking)")
        }
    }

    /// The word being spoken has its bar, and only while it is spoken.
    /// Fails if the bar is not drawn, or is drawn with no word marked.
    @Test func theBarIsDrawnOnlyUnderTheWordBeingSpoken() throws {
        let words = MessageWords(Self.message)
        let style = SpokenWordStyle(increasedContrast: false)
        let lines = try recordLines()
        let first = try #require(lines.first)
        let barRows = Int(((first.baseline + first.descent + SpokenWordStyle.barGap) * Self.scale).rounded(.up))
            ..< Int(((first.baseline + first.descent + style.roomBelow) * Self.scale).rounded(.down))

        func barInk(_ image: AlphaImage) -> Int {
            barRows.reduce(0) { sum, y in sum + (0..<image.width).filter { image.alpha($0, y) > 0.5 }.count }
        }
        let plain = try render(marking: nil, increasedContrast: false)
        let marked = try render(marking: words.marking(reported: words.places[0]), increasedContrast: false)
        let nothingYet = try render(marking: .nothingReported, increasedContrast: false)

        #expect(barInk(plain) == 0)
        #expect(barInk(nothingYet) == 0)
        #expect(barInk(marked) > 0)
    }

    /// A typed message may be 2,000 characters long (docs/DECISIONS.md,
    /// "The typed message"). Every one of its words reaches the renderer
    /// tagged with its own order, so each can be marked, and the whole
    /// message is drawn. Fails if building the message as one `Text` of
    /// tagged words drops or merges any word at that length. The time it
    /// took is printed to the test log, for a look on the Mac; no limit is
    /// asserted, since CI's machines vary too much for one.
    @Test func everyWordOfTheLongestTypedMessageIsTagged() throws {
        let words = (0..<400).map { "w\($0)" }
        let message = words.joined(separator: " ")
        #expect(message.count <= 2_000)
        let box = IndexRecorder.Box()
        let clock = ContinuousClock()
        let started = clock.now
        let content = SpokenMessageText.text(for: message, setIn: nil)
            .font(LabelFont.message.font)
            .textRenderer(IndexRecorder(box: box))
            .frame(width: Self.width, alignment: .leading)
        let renderer = ImageRenderer(content: content)
        _ = try #require(renderer.cgImage)
        print("A message of \(message.count) characters built and drawn in \(clock.now - started)")

        #expect(box.indices == Set(0..<words.count))
        #expect(MessageWords(message).places.count == words.count)
    }

    // MARK: - Drawing
    // MARK: - Drawing

    private func view(marking: WordMarking?, increasedContrast: Bool) -> some View {
        SpokenMessageWords(
            content: SpokenMessageText.text(for: Self.message, setIn: nil),
            marking: marking,
            style: SpokenWordStyle(increasedContrast: increasedContrast)
        )
        .font(LabelFont.message.font)
        .foregroundStyle(.black)
        .frame(width: Self.width, alignment: .leading)
        .environment(\.colorScheme, .light)
    }

    private func render(marking: WordMarking?, increasedContrast: Bool) throws -> AlphaImage {
        let renderer = ImageRenderer(content: view(marking: marking, increasedContrast: increasedContrast))
        renderer.scale = Self.scale
        let image = try #require(renderer.cgImage, "the message did not render")
        return try #require(AlphaImage(image))
    }

    /// Each line's baseline and descent, from the same Text laid out the
    /// same way, read by a renderer that only records them.
    private func recordLines() throws -> [LineRecorder.Line] {
        let box = LineRecorder.Box()
        let content = SpokenMessageText.text(for: Self.message, setIn: nil)
            .font(LabelFont.message.font)
            .textRenderer(LineRecorder(box: box))
            .frame(width: Self.width, alignment: .leading)
            .environment(\.colorScheme, .light)
        let renderer = ImageRenderer(content: content)
        renderer.scale = Self.scale
        _ = try #require(renderer.cgImage)
        return box.lines
    }
}

/// Records where each line of a text sits and draws it plainly.
private nonisolated struct LineRecorder: TextRenderer {
    struct Line: Sendable {
        let baseline: CGFloat
        let descent: CGFloat
    }

    final class Box: @unchecked Sendable {
        var lines: [Line] = []
    }

    let box: Box

    func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        box.lines = layout.map { Line(baseline: $0.typographicBounds.origin.y, descent: $0.typographicBounds.descent) }
        for line in layout {
            context.draw(line)
        }
    }
}

/// Records the order of every tagged word a text draws.
private nonisolated struct IndexRecorder: TextRenderer {
    final class Box: @unchecked Sendable {
        var indices: Set<Int> = []
    }

    let box: Box

    func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        for line in layout {
            for run in line {
                if let index = run[SpokenWordIndex.self]?.index {
                    box.indices.insert(index)
                }
                context.draw(run)
            }
        }
    }
}

/// A rendered image's coverage, 0 to 1 for each pixel.
private struct AlphaImage {
    let width: Int
    let height: Int
    private let bytes: [UInt8]

    init?(_ image: CGImage) {
        let width = image.width
        let height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return nil }
        self.width = width
        self.height = height
        bytes = pixels
    }

    /// Coverage at column `x`, row `y` counted from the top.
    func alpha(_ x: Int, _ y: Int) -> Double {
        Double(bytes[(y * width + x) * 4 + 3]) / 255
    }
}
