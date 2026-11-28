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

    /// The word being spoken has its bar, under that word and as wide as
    /// it, and only while it is spoken. Fails if the bar is not drawn, is
    /// drawn with no word marked, or sits under another stretch of the line
    /// than the word the voice reported.
    @Test(arguments: [0, 2])
    func theBarIsDrawnUnderTheWordBeingSpoken(word index: Int) throws {
        let words = MessageWords(Self.message)
        let style = SpokenWordStyle(increasedContrast: false)
        let lines = try recordLines()
        let first = try #require(lines.first)
        let word = try #require(first.words[index], "word \(index) is not on the first line")
        let barRows = Int(((first.baseline + first.descent + SpokenWordStyle.barGap) * Self.scale).rounded(.up))
            ..< Int(((first.baseline + first.descent + style.roomBelow) * Self.scale).rounded(.down))

        /// The columns, in points, with bar ink in every one of the bar's rows.
        func barColumns(_ image: AlphaImage) -> [CGFloat] {
            (0..<image.width).filter { x in barRows.allSatisfy { image.alpha(x, $0) > 0.5 } }.map { CGFloat($0) / Self.scale }
        }
        let plain = try render(marking: nil, increasedContrast: false)
        let marked = try render(marking: words.marking(reported: words.places[index]), increasedContrast: false)
        let nothingYet = try render(marking: .nothingReported, increasedContrast: false)

        #expect(barColumns(plain).isEmpty)
        #expect(barColumns(nothingYet).isEmpty)
        let bar = barColumns(marked)
        let covered = Double(bar.count) / Double(Self.scale) / Double(word.width)
        #expect(covered > 0.9, "the bar covers \(covered) of the word's width")
        #expect(bar.allSatisfy { $0 >= word.minX - 1 && $0 <= word.maxX + 1 }, "bar ink outside \(word)")
    }

    /// Words still to come are drawn at the style's share of their ink:
    /// with no word reported yet, every glyph of the message is drawn at
    /// `dimOpacity`. Fails if the renderer draws them at full ink, or
    /// fainter than the share that `PaletteTests` measures.
    @Test(arguments: [false, true])
    func wordsToComeAreDrawnAtTheirShareOfTheInk(increasedContrast: Bool) throws {
        let style = SpokenWordStyle(increasedContrast: increasedContrast)
        let plain = try render(marking: nil, increasedContrast: increasedContrast)
        let toCome = try render(marking: .nothingReported, increasedContrast: increasedContrast)
        var solid = 0
        var offShare = 0
        for y in 0..<plain.height {
            for x in 0..<plain.width where plain.alpha(x, y) > 0.95 {
                solid += 1
                if abs(toCome.alpha(x, y) - style.dimOpacity) > 0.05 { offShare += 1 }
            }
        }
        #expect(solid > 100, "too few solid glyph pixels to judge: \(solid)")
        #expect(offShare == 0, "\(offShare) of \(solid) glyph pixels are not at \(style.dimOpacity) of the ink")
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
        /// Where each tagged word on the line is drawn, by its order.
        var words: [Int: CGRect] = [:]
    }

    final class Box: @unchecked Sendable {
        var lines: [Line] = []
    }

    let box: Box

    func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        box.lines = layout.map { line in
            var recorded = Line(baseline: line.typographicBounds.origin.y, descent: line.typographicBounds.descent)
            for run in line {
                if let index = run[SpokenWordIndex.self]?.index {
                    recorded.words[index] = recorded.words[index].map { $0.union(run.typographicBounds.rect) } ?? run.typographicBounds.rect
                }
            }
            return recorded
        }
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
