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
    /// capture, on a tall capture those read in the band around its drawn
    /// words too (`band(of:)`), and on words of more than one line beside
    /// an icon those read past the icon (`pastItsIcon(of:)`).
    static func read(_ image: CGImage) async throws -> [String] {
        var found = words(in: try await request.perform(on: image, orientation: nil))
        if let band = band(of: image) {
            found += words(in: try await request.perform(on: band, orientation: nil))
        }
        if let crop = pastItsIcon(of: image) {
            found += words(in: try await request.perform(on: crop, orientation: nil))
        }
        return found
    }

    /// The words in the PNG file at `url`, read the same way.
    static func read(contentsOf url: URL) async throws -> [String] {
        var found = words(in: try await request.perform(on: url, orientation: nil))
        if let image = image(contentsOf: url) {
            if let band = band(of: image) {
                found += words(in: try await request.perform(on: band, orientation: nil))
            }
            if let crop = pastItsIcon(of: image) {
                found += words(in: try await request.perform(on: crop, orientation: nil))
            }
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

    /// The capture from midway across the gap between the icon beside its
    /// first line of words and the words, where they take more than one
    /// line; nil where they take one, or where nothing stands apart left
    /// of their leading edge. Settings' rows put their icon at the leading
    /// edge, beside the first line, and on a row several lines tall the
    /// system's capsule cuts the icon at its curve: the fast recognizer
    /// read no "Go" beside the cut icon of Go Through Setup Again at the
    /// largest text size on CI's iPhone 17, while it read each line below
    /// (pull request #103). The words' leading edge is the leftmost mark
    /// in the lines below the first; in the first, the columns left of it
    /// are walked past the first word's own overhang, then across the gap
    /// to the icon. A mark is a pixel far from the capture's commonest
    /// colour, its fill, as in `band(of:)`, between the runs that touch
    /// each row's ends, which are the screen beyond a rounded button or a
    /// border; a line is a run of rows with marks. A crop only leaves
    /// pixels out, so a word clipped in `image` is clipped in it too.
    static func pastItsIcon(of image: CGImage) -> CGImage? {
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
        // The commonest colour, to 16 levels a channel.
        var counts = [Int](repeating: 0, count: 4096)
        for index in stride(from: 0, to: width * height * 4, by: 4) {
            let red = Int(bytes[index]) >> 4
            let green = Int(bytes[index + 1]) >> 4
            let blue = Int(bytes[index + 2]) >> 4
            counts[red << 8 | green << 4 | blue] += 1
        }
        guard let commonest = counts.indices.max(by: { counts[$0] < counts[$1] }) else { return nil }
        let fill = (red: (commonest >> 8) << 4 | 8, green: ((commonest >> 4) & 15) << 4 | 8, blue: (commonest & 15) << 4 | 8)
        func drawn(_ x: Int, _ y: Int) -> Bool {
            let index = (y * width + x) * 4
            let red = abs(Int(bytes[index]) - fill.red)
            let green = abs(Int(bytes[index + 1]) - fill.green)
            let blue = abs(Int(bytes[index + 2]) - fill.blue)
            return red + green + blue > 120
        }
        var marks: [[Int]] = []
        for y in 0..<height {
            var left = 0
            while left < width, drawn(left, y) {
                left += 1
            }
            var right = width - 1
            while right >= left, drawn(right, y) {
                right -= 1
            }
            marks.append(left <= right ? (left...right).filter { drawn($0, y) } : [])
        }
        var lines: [ClosedRange<Int>] = []
        for y in 0..<height where !marks[y].isEmpty {
            if let last = lines.last, last.upperBound == y - 1 {
                lines[lines.count - 1] = last.lowerBound...y
            } else {
                lines.append(y...y)
            }
        }
        guard lines.count > 1, let first = lines.first,
              let leading = lines.dropFirst().flatMap({ line in line.compactMap { marks[$0].first } }).min()
        else { return nil }
        let firstLine = Set(first.flatMap { marks[$0] })
        var x = leading
        while x >= 0, firstLine.contains(x) {
            x -= 1
        }
        let gapEnd = x
        while x >= 0, !firstLine.contains(x) {
            x -= 1
        }
        guard x >= 0 else { return nil }
        let start = (x + 1 + gapEnd + 1) / 2
        return image.cropping(to: CGRect(x: start, y: 0, width: width - start, height: height))
    }

    /// The PNG at `url`, for its band and its crop past the icon.
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
