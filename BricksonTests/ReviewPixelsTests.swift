import CoreGraphics
import Foundation
import Testing

/// The design review sheet's measurements (`scripts/design-review/ReviewPixels.swift`,
/// compiled here as it is into the capture tool), checked on pictures
/// drawn for the test, whose every colour and edge is known. The capture
/// script prints these numbers under each pair on the sheet, and the owner
/// chooses the new colours from them.
struct ReviewPixelsTests {
    /// A white page `size` points across at `scale`, with what `draw`
    /// adds, measured from the top left as captures are.
    private static func picture(width: Int = 120, height: Int = 80, scale: Int = 2, page: ReviewColour = .init(r: 255, g: 255, b: 255), draw: (CGContext) -> Void) throws -> ReviewBitmap {
        let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try #require(CGContext(
            data: nil, width: width * scale, height: height * scale, bitsPerComponent: 8, bytesPerRow: 0,
            space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        // Top-left points, as AXe reports frames.
        context.translateBy(x: 0, y: CGFloat(height * scale))
        context.scaleBy(x: CGFloat(scale), y: -CGFloat(scale))
        context.setShouldAntialias(false)
        context.setFillColor(page.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        draw(context)
        let image = try #require(context.makeImage())
        return try #require(ReviewBitmap(image))
    }

    private static let blue = ReviewColour(r: 0x0A, g: 0x60, b: 0xD6)
    private static let white = ReviewColour(r: 255, g: 255, b: 255)
    private static let black = ReviewColour(r: 0, g: 0, b: 0)
    private static let frame = ReviewRect(x: 20, y: 20, width: 80, height: 40)

    // The formula is WCAG 2's, the one `PaletteTests` measures with: a
    // different coefficient or threshold moves these in the second decimal.
    @Test func theContrastIsTheOnePaletteTestsMeasures() throws {
        for (words, fill) in [("#FFFFFF", "#0A60D6"), ("#FFFFFF", "#B45309"), ("#000000", "#5A6474"), ("#FFFFFF", "#1C1C1E"), ("#767676", "#F2F2F7")] {
            let review = try #require(ReviewColour(hex: words)).contrast(with: try #require(ReviewColour(hex: fill)))
            let palette = ColourArithmetic.contrast(try #require(ColourArithmetic.SRGB(hex: words)), try #require(ColourArithmetic.SRGB(hex: fill)))
            #expect(abs(review - palette) < 1e-9, "\(words) on \(fill)")
        }
        #expect(ReviewMeasure.rounded(Self.white.contrast(with: Self.blue)) == 5.74)
        #expect(Self.black.contrast(with: Self.white) == 21)
        #expect(Self.blue.contrast(with: Self.blue) == 1)
    }

    @Test func aColourReadsBackAsItsHex() throws {
        #expect(try #require(ReviewColour(hex: "#0A60D6")) == Self.blue)
        #expect(Self.blue.hex == "#0A60D6")
        #expect(ReviewColour(hex: "0A60D6") == nil)
        #expect(ReviewColour(hex: "#0A60D") == nil)
    }

    // A filled control: its fill, its words and its edge against the page.
    // Words taken from anywhere else, or the page taken for the fill,
    // would change every number here.
    @Test func aFilledControlReadsItsFillWordsAndEdge() throws {
        let bitmap = try Self.picture { context in
            context.setFillColor(Self.blue.cgColor)
            context.fill(CGRect(x: 20, y: 20, width: 80, height: 40))
            context.setFillColor(Self.white.cgColor)
            context.fill(CGRect(x: 40, y: 34, width: 40, height: 12))
        }
        let reading = try #require(ReviewMeasure.read(bitmap, frame: Self.frame, scale: 2))
        #expect(reading.fill == "#0A60D6")
        #expect(reading.words == "#FFFFFF")
        #expect(ReviewMeasure.rounded(reading.wordsOnFill) == 5.74)
        #expect(reading.wordPixels == 40 * 12 * 4)
        #expect(reading.page == "#FFFFFF")
        #expect(reading.edge == "#0A60D6")
        #expect(ReviewMeasure.rounded(reading.edgeOnPage) == 5.74)
        #expect(reading.rings.isEmpty)
    }

    // An unfilled control, as Home draws one that is off: its edge is the
    // border, not the page it shares its fill with.
    @Test func aBorderIsTheEdgeOfAControlWithNoFill() throws {
        let bitmap = try Self.picture { context in
            context.setStrokeColor(Self.black.cgColor)
            context.setLineWidth(2)
            context.stroke(CGRect(x: 21, y: 21, width: 78, height: 38))
            context.setFillColor(Self.black.cgColor)
            context.fill(CGRect(x: 40, y: 34, width: 40, height: 12))
        }
        let reading = try #require(ReviewMeasure.read(bitmap, frame: Self.frame, scale: 2))
        #expect(reading.fill == "#FFFFFF")
        #expect(reading.words == "#000000")
        #expect(reading.edge == "#000000")
        #expect(ReviewMeasure.rounded(reading.edgeOnPage) == 21)
    }

    // Gray words beside a black icon: the words are the gray, the one that
    // stands out least, never the icon's 21:1, and both are listed.
    @Test func theWeakerOfTwoMarksIsTakenForTheWords() throws {
        let gray = ReviewColour(r: 0x9A, g: 0x9A, b: 0x9A)
        let bitmap = try Self.picture { context in
            context.setFillColor(Self.black.cgColor)
            context.fill(CGRect(x: 28, y: 32, width: 10, height: 16))
            context.setFillColor(gray.cgColor)
            context.fill(CGRect(x: 44, y: 34, width: 40, height: 12))
        }
        let reading = try #require(ReviewMeasure.read(bitmap, frame: Self.frame, scale: 2))
        #expect(reading.words == "#9A9A9A")
        #expect(reading.wordsOnFill < 4.5)
        #expect(reading.foregrounds.map(\.colour) == ["#9A9A9A", "#000000"])

        // Words so faint they barely show, 1.16:1, are still the words.
        let faint = ReviewColour(r: 0xEE, g: 0xEE, b: 0xEE)
        let pale = try Self.picture { context in
            context.setFillColor(Self.black.cgColor)
            context.fill(CGRect(x: 28, y: 32, width: 10, height: 16))
            context.setFillColor(faint.cgColor)
            context.fill(CGRect(x: 44, y: 34, width: 40, height: 12))
        }
        let paleReading = try #require(ReviewMeasure.read(pale, frame: Self.frame, scale: 2))
        #expect(paleReading.words == "#EEEEEE")
        #expect(ReviewMeasure.rounded(paleReading.wordsOnFill) == 1.16)
    }

    // A ring inside the edge, as a pressed control draws one, is reported
    // with its contrast on the fill.
    @Test func aRingInsideTheEdgeIsReported() throws {
        let bitmap = try Self.picture { context in
            context.setFillColor(Self.blue.cgColor)
            context.fill(CGRect(x: 20, y: 20, width: 80, height: 40))
            context.setStrokeColor(Self.black.cgColor)
            context.setLineWidth(3)
            context.stroke(CGRect(x: 21.5, y: 21.5, width: 77, height: 37))
        }
        let reading = try #require(ReviewMeasure.read(bitmap, frame: Self.frame, scale: 2))
        #expect(reading.edge == "#000000")
        #expect(reading.rings.map(\.colour) == ["#000000"])
        #expect(reading.rings.first.map { ReviewMeasure.rounded($0.onFill) } == 3.66)
    }

    // A round shape leaves the page showing in its frame's corners, so
    // much that the page is the commonest colour round the frame's edge;
    // its edge is still its fill, as on Settings' capsule rows.
    @Test func aRoundShapesEdgeIsItsFill() throws {
        let bitmap = try Self.picture { context in
            context.setShouldAntialias(true)
            context.setFillColor(Self.blue.cgColor)
            context.fillEllipse(in: CGRect(x: 40, y: 20, width: 40, height: 40))
        }
        let reading = try #require(ReviewMeasure.read(bitmap, frame: ReviewRect(x: 40, y: 20, width: 40, height: 40), scale: 2))
        #expect(reading.edge == "#0A60D6")
        #expect(ReviewMeasure.rounded(reading.edgeOnPage) == 5.74)
    }

    // In dark mode a capsule's round ends show the black screen inside its
    // frame; that black is the screen, never the words, though the words
    // could be black too on a lighter fill.
    @Test func theScreenInAShapesCornersIsNotTheWords() throws {
        let bitmap = try Self.picture(page: Self.black) { context in
            context.setFillColor(Self.blue.cgColor)
            context.addPath(CGPath(roundedRect: CGRect(x: 20, y: 20, width: 80, height: 40), cornerWidth: 20, cornerHeight: 20, transform: nil))
            context.fillPath()
            context.setFillColor(Self.white.cgColor)
            context.fill(CGRect(x: 44, y: 34, width: 32, height: 12))
        }
        let reading = try #require(ReviewMeasure.read(bitmap, frame: Self.frame, scale: 2))
        #expect(reading.words == "#FFFFFF")
        #expect(reading.foregrounds.map(\.colour) == ["#FFFFFF"])
        let black = try Self.picture(page: Self.black) { context in
            context.setFillColor(Self.white.cgColor)
            context.addPath(CGPath(roundedRect: CGRect(x: 20, y: 20, width: 80, height: 40), cornerWidth: 20, cornerHeight: 20, transform: nil))
            context.fillPath()
            context.setFillColor(Self.black.cgColor)
            context.fill(CGRect(x: 44, y: 34, width: 32, height: 12))
        }
        let words = try #require(ReviewMeasure.read(black, frame: Self.frame, scale: 2))
        #expect(words.words == "#000000")
        #expect(words.fill == "#FFFFFF")
    }

    // Words drawn on the screen itself, with nothing round them: the
    // screen is their fill, never cut away as the screen round a shape.
    @Test func wordsOnTheScreenKeepTheScreenForTheirFill() throws {
        let bitmap = try Self.picture { context in
            context.setFillColor(Self.black.cgColor)
            context.fill(CGRect(x: 30, y: 34, width: 60, height: 12))
        }
        let reading = try #require(ReviewMeasure.read(bitmap, frame: Self.frame, scale: 2, inset: 0))
        #expect(reading.fill == "#FFFFFF")
        #expect(reading.words == "#000000")
    }

    // Where a shape does not differ from the page, there is no edge: the
    // page against itself, 1:1, never a colour the shape does not have.
    @Test func aShapeLikeThePageHasNoEdge() throws {
        let bitmap = try Self.picture { context in
            context.setFillColor(Self.black.cgColor)
            context.fill(CGRect(x: 40, y: 34, width: 40, height: 12))
        }
        let reading = try #require(ReviewMeasure.read(bitmap, frame: Self.frame, scale: 2))
        #expect(reading.edge == "#FFFFFF")
        #expect(ReviewMeasure.rounded(reading.edgeOnPage) == 1)
        #expect(ReviewMeasure.rounded(reading.wordsOnFill) == 21)
    }

    // A few stray pixels of another colour are never taken for the words.
    @Test func strayPixelsAreNotTheWords() throws {
        let bitmap = try Self.picture { context in
            context.setFillColor(Self.blue.cgColor)
            context.fill(CGRect(x: 20, y: 20, width: 80, height: 40))
            context.setFillColor(Self.white.cgColor)
            context.fill(CGRect(x: 40, y: 34, width: 40, height: 12))
            context.setFillColor(Self.black.cgColor)
            context.fill(CGRect(x: 50, y: 50, width: 0.5, height: 0.5))
        }
        let reading = try #require(ReviewMeasure.read(bitmap, frame: Self.frame, scale: 2))
        #expect(reading.words == "#FFFFFF")
    }

    // The run of a colour through a point starts where the shape does: how
    // the inactive window's place on the screen is found.
    @Test func aRunStartsAtTheShapesEdges() throws {
        let bitmap = try Self.picture { context in
            context.setFillColor(Self.blue.cgColor)
            context.fill(CGRect(x: 20, y: 20, width: 80, height: 40))
        }
        let start = try #require(ReviewMeasure.runStart(of: Self.blue, in: bitmap, x: 100, y: 90))
        #expect(start.left == 40)
        #expect(start.top == 40)
        #expect(ReviewMeasure.runStart(of: Self.blue, in: bitmap, x: 2, y: 2).map(\.left) == nil)
    }
}

private extension ReviewColour {
    var cgColor: CGColor {
        CGColor(srgbRed: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: 1)
    }
}
