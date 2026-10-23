import Foundation
import Testing

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
/// `aWholeLabelIsRead`; one that accepts pieces (language correction, or
/// matching part of a word) fails `aClippedLabelIsRejected`.
struct RenderedWordsTests {
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
