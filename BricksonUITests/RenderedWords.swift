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
    /// correction, so only what was drawn counts.
    static func read(_ image: CGImage) async throws -> [String] {
        words(in: try await request.perform(on: image, orientation: nil))
    }

    /// The words in the image file at `url`, read the same way.
    static func read(contentsOf url: URL) async throws -> [String] {
        words(in: try await request.perform(on: url, orientation: nil))
    }

    /// Whether `words` hold `label` as a whole word, ignoring case.
    static func show(_ label: String, in words: [String]) -> Bool {
        words.contains { $0.caseInsensitiveCompare(label) == .orderedSame }
    }

    private static var request: RecognizeTextRequest {
        var request = RecognizeTextRequest()
        // The accurate recognizer returned "ON" for a clear upright "No"
        // crop. Use the fast path for these simple UI glyphs; still require
        // whole words.
        request.recognitionLevel = .fast
        request.recognitionLanguages = [Locale.Language(identifier: "en-US")]
        request.usesLanguageCorrection = false
        return request
    }

    private static func words(in observations: [RecognizedTextObservation]) -> [String] {
        observations
            .compactMap { $0.topCandidates(1).first?.string }
            .flatMap { $0.components(separatedBy: .whitespacesAndNewlines) }
    }
}
