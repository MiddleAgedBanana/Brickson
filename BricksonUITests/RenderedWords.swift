import CoreGraphics
import Foundation
import Vision

/// The words a capture of one control shows. A button's accessibility frame
/// can be correct while its visible label is clipped, so the UI tests read
/// the drawn words too (AGENTS.md, *Gotchas*, "Accessibility frames do not
/// prove visible words fit").
///
/// Test infrastructure only. It is compiled into the UI tests, which read
/// live captures, and into the unit tests, which check it against kept
/// captures (`RenderedWordsTests`), so a recognizer that stopped telling a
/// whole label from a clipped one fails there. It uses Vision's Swift API
/// (docs/DECISIONS.md, "Apple's current frameworks first").
nonisolated enum RenderedWords {
    /// The words in `image`, read without the expected text or language
    /// correction, so only what was drawn counts: those read in the whole
    /// capture, and on a tall capture those read in the band around its
    /// drawn words too (`band(of:)`).
    static func read(_ image: CGImage) async throws -> [String] {
        var found = words(in: try await request.perform(on: image, orientation: nil))
        if let band = band(of: image) {
            found += words(in: try await request.perform(on: band, orientation: nil))
        }
        return found
    }

    /// The words in the PNG file at `url`, read the same way.
    static func read(contentsOf url: URL) async throws -> [String] {
        var found = words(in: try await request.perform(on: url, orientation: nil))
        if let image = image(contentsOf: url), let band = band(of: image) {
            found += words(in: try await request.perform(on: band, orientation: nil))
        }
        return found
    }

    /// Whether `words` hold `label` as a whole word, ignoring case and any
    /// punctuation read around a word. The fast recognizer read a whole
    /// "Attention" on a dark-cornered capture as "Attention," (CI, pull
    /// request #74); a mark beside a word adds no letter to it, so a
    /// clipped word stays unmatched. The labels checked hold no
    /// punctuation of their own.
    static func show(_ label: String, in words: [String]) -> Bool {
        words.contains { $0.trimmingCharacters(in: .punctuationCharacters).caseInsensitiveCompare(label) == .orderedSame }
    }

    /// How many times its drawn words' height a capture is read at most,
    /// besides whole. The fast recognizer read nothing in a capture of a
    /// whole "No" 27 pixels tall on a button 412 pixels tall, the rest
    /// board's on an iPad at the default text size, and read the same
    /// "No" on a button 218 pixels tall (CI, pull request #74).
    static let bandMultiple = 8

    /// The rows of `image` around its drawn words, `bandMultiple` times
    /// their height and centred on them; nil where that is the whole
    /// capture or nothing is drawn. Drawn means far from the capture's
    /// commonest colour, its fill, in the columns clear of its rounded
    /// corners. A row drawn in every one of those columns is not words
    /// but an edge: the border Home draws round every control in dark
    /// mode, with Show Borders on and when a control is off
    /// (`HomeButtonLook`), or the screen beyond a control. Counted as
    /// words, the border made a tall dark "No"'s band the whole capture,
    /// which read "I" (pull request #74, on the owner's Mac). A crop only
    /// leaves pixels out, so a word clipped in `image` is clipped in its
    /// band too, and a capture with words most of its height is never
    /// cut.
    static func band(of image: CGImage) -> CGImage? {
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
        // The first row in memory is the capture's top row.
        let bytes = data.bindMemory(to: UInt8.self, capacity: width * height * 4)
        func colour(_ x: Int, _ y: Int) -> (red: Int, green: Int, blue: Int) {
            let index = (y * width + x) * 4
            return (Int(bytes[index]), Int(bytes[index + 1]), Int(bytes[index + 2]))
        }
        // The commonest colour, to 16 levels a channel.
        var counts = [Int](repeating: 0, count: 4096)
        for y in 0..<height {
            for x in 0..<width {
                let pixel = colour(x, y)
                counts[(pixel.red >> 4) << 8 | (pixel.green >> 4) << 4 | pixel.blue >> 4] += 1
            }
        }
        guard let commonest = counts.indices.max(by: { counts[$0] < counts[$1] }) else { return nil }
        let fill = (red: (commonest >> 8) << 4 | 8, green: ((commonest >> 4) & 15) << 4 | 8, blue: (commonest & 15) << 4 | 8)
        let columns = (width / 8)..<(width - width / 8)
        func holdsWords(_ y: Int) -> Bool {
            var drawn = 0
            for x in columns {
                let pixel = colour(x, y)
                if abs(pixel.red - fill.red) + abs(pixel.green - fill.green) + abs(pixel.blue - fill.blue) > 120 {
                    drawn += 1
                }
            }
            return drawn >= 2 && drawn < columns.count
        }
        guard let top = (0..<height).first(where: holdsWords), let bottom = (0..<height).last(where: holdsWords)
        else { return nil }
        let bandHeight = bandMultiple * (bottom - top + 1)
        guard bandHeight < height else { return nil }
        let bandTop = min(max(0, (top + bottom + 1) / 2 - bandHeight / 2), height - bandHeight)
        return image.cropping(to: CGRect(x: 0, y: bandTop, width: width, height: bandHeight))
    }

    /// The PNG at `url`, for its band.
    private static func image(contentsOf url: URL) -> CGImage? {
        guard let provider = CGDataProvider(url: url as CFURL) else { return nil }
        return CGImage(pngDataProviderSource: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    }

    /// The request both readers use. `RenderedWordsTests` pins each
    /// setting: the kept captures alone would not notice correction or
    /// hints, which cannot rebuild a word from the pieces a clipped label
    /// shows.
    static var request: RecognizeTextRequest {
        var request = RecognizeTextRequest()
        // The accurate recognizer returned "ON" for a clear upright "No"
        // crop. Use the fast path for these simple UI glyphs; still require
        // whole words.
        request.recognitionLevel = .fast
        request.recognitionLanguages = [Locale.Language(identifier: "en-US")]
        request.automaticallyDetectsLanguage = false
        request.usesLanguageCorrection = false
        return request
    }

    private static func words(in observations: [RecognizedTextObservation]) -> [String] {
        observations
            .compactMap { $0.topCandidates(1).first?.string }
            .flatMap { $0.components(separatedBy: .whitespacesAndNewlines) }
    }
}
