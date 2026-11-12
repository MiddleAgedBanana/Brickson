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
/// dark, read as "Attention," (getattention-dark.png). So is a third, from
/// the same test on the owner's Mac: that "No" in dark mode, with the
/// white border every Home control draws there, whose whole capture read
/// "I" (no-tall-edge.png).
///
/// One more comes from the check-in card's UI test on CI (pull request
/// #103): Go Through Setup Again on an iPhone 17 at the largest text size,
/// light, its words drawn whole on four lines with the icon beside "Go" cut
/// by the button's rounded end, where the whole capture read every word
/// but "Go" (gothrough-cut-icon.png).
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

    /// The same, with a border round the button: fails if the border's
    /// rows count as words, so the band is the whole capture again.
    @Test func aShortWordOnATallButtonWithABorderIsRead() async throws {
        let words = try await RenderedWords.read(contentsOf: capture(of: "No", state: "tall-edge"))
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

    /// The band: on each tall "No", with a border or without, rows around
    /// the word, at most `bandMultiple` times its height and at least its
    /// 27 rows; on every other kept capture, whole or clipped, none, so
    /// each is read as it always was. Fails if the band cuts a short
    /// capture or a clipped one, or leaves a tall one whole, as it did
    /// when a button's border counted as words.
    @Test func onlyATallCaptureHasABand() throws {
        for state in ["tall", "tall-edge"] {
            let tall = try #require(image(capture(of: "No", state: state)))
            let band = try #require(RenderedWords.band(of: tall), "\(state)")
            #expect(band.width == tall.width, "\(state)")
            #expect(band.height < tall.height, "\(state)")
            #expect(band.height >= RenderedWords.bandMultiple * 27, "\(state)")
        }
        for label in ["Yes", "No", "Emergency", "Again"] {
            for state in ["whole", "clipped"] {
                let kept = try #require(image(capture(of: label, state: state)))
                #expect(RenderedWords.band(of: kept) == nil, "\(label) \(state)")
            }
        }
        let dark = try #require(image(capture(of: "GetAttention", state: "dark")))
        #expect(RenderedWords.band(of: dark) == nil)
    }

    /// A short first word beside a cut icon is read past the icon: fails
    /// if the crop past it is not read, or not cut between the icon and
    /// the word.
    @Test func aShortWordBesideACutIconIsRead() async throws {
        let words = try await RenderedWords.read(contentsOf: capture(of: "GoThrough", state: "cut-icon"))
        #expect(["Go", "Through", "Setup", "Again"].allSatisfy { RenderedWords.show($0, in: words) }, "recognized \(words)")
    }

    /// The crop past the icon: on Go Through Setup Again, from midway
    /// across the gap between the icon, whose last marked column is 215
    /// pixels in, and "Go", whose first is 262 in; on every other kept
    /// capture, none, so each is read as it was. Fails if the crop cuts
    /// into the word or leaves part of the icon, or crops one of the
    /// others.
    @Test func onlyWordsOfMoreThanOneLineAreCutPastTheirIcon() throws {
        let goThrough = try #require(image(capture(of: "GoThrough", state: "cut-icon")))
        let crop = try #require(RenderedWords.pastItsIcon(of: goThrough))
        #expect(crop.height == goThrough.height)
        #expect((216...261).contains(goThrough.width - crop.width), "cut \(goThrough.width - crop.width) pixels in")
        for label in ["Yes", "No", "Emergency", "Again"] {
            let whole = try #require(image(capture(of: label, state: "whole")))
            #expect(RenderedWords.pastItsIcon(of: whole) == nil, "\(label)")
        }
        for state in ["tall", "tall-edge"] {
            let tall = try #require(image(capture(of: "No", state: state)))
            #expect(RenderedWords.pastItsIcon(of: tall) == nil, "\(state)")
        }
        let dark = try #require(image(capture(of: "GetAttention", state: "dark")))
        #expect(RenderedWords.pastItsIcon(of: dark) == nil)
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
