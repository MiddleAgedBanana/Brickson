import CoreGraphics
import Foundation
import Testing
import Vision

/// The UI tests read the words each quick control draws (`RenderedWords`,
/// compiled here from BricksonUITests), because an accessibility frame can
/// be right while the label is clipped. That check is only worth having if
/// it can fail, so it is run here on kept captures of Yes, No, Emergency
/// and Again: an iPhone at the largest text size before and after the fix
/// in PR #13 (docs/log/ui-test-evidence/iphone-ax5-before.png and
/// -after.png, each cropped to the button). Before the fix each button drew
/// only pieces of its word.
///
/// A recognizer that no longer reads whole words fails
/// `aWholeLabelIsRead`; matching part of a word fails
/// `aClippedLabelIsRejected`. Language correction and word hints could not
/// rebuild these words from their pieces, so `theRequestReadsOnlyWhatIsDrawn`
/// pins the settings instead.
///
/// Two captures from the rest board's UI test on CI (pull request #74)
/// are kept too, both drawn whole: the iPad's "No" at the default text
/// size, small on a tall button, where the whole capture read nothing
/// (no-tall.png), and the iPhone's "Get Attention" at the largest size in
/// dark, read as "Attention," (getattention-dark.png).
struct RenderedWordsTests {
    // Accurate mode, a second language, language correction or supplied
    // words each fail this.
    @Test func theRequestReadsOnlyWhatIsDrawn() {
        let request = RenderedWords.request
        #expect(request.recognitionLevel == .fast)
        #expect(request.recognitionLanguages == [Locale.Language(identifier: "en-US")])
        #expect(!request.automaticallyDetectsLanguage)
        #expect(!request.usesLanguageCorrection)
        #expect(request.customWords.isEmpty)
    }

    @Test(arguments: ["Yes", "No", "Emergency", "Again"])
    func aWholeLabelIsRead(_ label: String) async throws {
        let words = try await RenderedWords.read(contentsOf: capture(of: label, state: "whole"))
        #expect(RenderedWords.show(label, in: words), "recognized \(words)")
    }

    @Test(arguments: ["Yes", "No", "Emergency", "Again"])
    func aClippedLabelIsRejected(_ label: String) async throws {
        let words = try await RenderedWords.read(contentsOf: capture(of: label, state: "clipped"))
        #expect(!RenderedWords.show(label, in: words), "recognized \(words)")
    }

    /// A short word on a tall button is read in the band around it: fails
    /// if the band is not read, or not cut around the word.
    @Test func aShortWordOnATallButtonIsRead() async throws {
        let words = try await RenderedWords.read(contentsOf: capture(of: "No", state: "tall"))
        #expect(RenderedWords.show("No", in: words), "recognized \(words)")
    }

    /// A mark read beside a word is not part of it: fails if "Attention,"
    /// does not count as Attention.
    @Test func aMarkBesideAWordIsNotPartOfIt() async throws {
        let words = try await RenderedWords.read(contentsOf: capture(of: "GetAttention", state: "dark"))
        #expect(RenderedWords.show("Get", in: words) && RenderedWords.show("Attention", in: words), "recognized \(words)")
    }

    /// Punctuation around a recognized word is dropped, and nothing else:
    /// fails if a word missing a letter, or with letters added, matches.
    @Test func onlyPunctuationAroundAWordIsDropped() {
        #expect(RenderedWords.show("Attention", in: ["Attention,"]))
        #expect(RenderedWords.show("No", in: ["(no."]))
        #expect(!RenderedWords.show("Attention", in: ["Attentio,"]))
        #expect(!RenderedWords.show("No", in: ["N."]))
        #expect(!RenderedWords.show("No", in: ["Not"]))
    }

    /// The band: on the tall "No", rows around the word, at most
    /// `bandMultiple` times its height and at least its 27 rows; on every
    /// other kept capture, whole or clipped, none, so each is read as it
    /// always was. Fails if the band cuts a short capture, a clipped one
    /// or one with a border, or leaves the tall one whole.
    @Test func onlyATallCaptureHasABand() throws {
        let tall = try #require(image(capture(of: "No", state: "tall")))
        let band = try #require(RenderedWords.band(of: tall))
        #expect(band.width == tall.width)
        #expect(band.height < tall.height)
        #expect(band.height >= RenderedWords.bandMultiple * 27)
        for label in ["Yes", "No", "Emergency", "Again"] {
            for state in ["whole", "clipped"] {
                let kept = try #require(image(capture(of: label, state: state)))
                #expect(RenderedWords.band(of: kept) == nil, "\(label) \(state)")
            }
        }
        let dark = try #require(image(capture(of: "GetAttention", state: "dark")))
        #expect(RenderedWords.band(of: dark) == nil)
    }

    private func image(_ url: URL) -> CGImage? {
        CGDataProvider(url: url as CFURL).flatMap {
            CGImage(pngDataProviderSource: $0, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
        }
    }

    /// A kept capture, from BricksonTests/RenderedLabels.
    private func capture(of label: String, state: String) throws -> URL {
        try #require(
            Bundle(for: TestBundle.self).url(forResource: "\(label.lowercased())-\(state)", withExtension: "png"),
            "No kept capture \(label.lowercased())-\(state).png in the test bundle"
        )
    }
}

/// Finds the unit-test bundle, which holds the kept captures; the tests run
/// inside the app, whose bundle is `Bundle.main`.
private final class TestBundle {}
