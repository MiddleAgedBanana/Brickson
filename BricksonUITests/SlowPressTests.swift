import XCTest

/// A slow press on Home speaks, and a touch that slides from one control
/// onto another never speaks the second, at the largest text size
/// (invariant 2; docs/DECISIONS.md, "Show Borders and the Large Content
/// Viewer on Home").
///
/// At that size, SwiftUI's large content viewer on a button
/// (`accessibilityShowsLargeContentViewer`) turned every press of 0.2 s
/// or longer on Yes into nothing: measured on iPhone 17 and iPad Pro
/// 13-inch simulators on 2026-10-23 (`HeldSlideProbeTests`;
/// docs/log/2026-10-23-large-content-and-iphone-duo.md). So the first
/// test fails if Yes or a phrase tile gets the viewer. The second never
/// failed with the viewer: it guards against any change that lets a
/// slide speak the control it ends on.
final class SlowPressTests: XCTestCase {
    override func setUpWithError() throws {
        // Both presses report, so a failure names every control that lost
        // the press.
        continueAfterFailure = true
    }

    /// Half a second, as a weak or unsteady hand can press.
    @MainActor
    func testASlowPressSpeaksAtTheLargestTextSize() throws {
        let app = launchedApp(textSize: .ax5)

        app.buttons["Yes"].press(forDuration: 0.5)
        XCTAssertTrue(
            app.staticTexts["Yes."].waitForExistence(timeout: 5),
            "a half-second press on Yes said nothing at AX5 text"
        )

        // A tile whose words differ from the message already showing.
        let tile = app.buttons.matching(identifier: "phraseTile").allElementsBoundByIndex
            .first { $0.isHittable && $0.label != "Yes." }
        let phrase = try XCTUnwrap(tile, "no phrase tile can be touched at AX5 text")
        let words = phrase.label
        phrase.press(forDuration: 0.5)
        XCTAssertTrue(
            app.staticTexts[words].waitForExistence(timeout: 5),
            "a half-second press on the phrase \"\(words)\" said nothing at AX5 text"
        )
    }

    /// Held long enough for the viewer's large copy, then slid onto No and
    /// lifted. A touch belongs to the control it began on, so this says
    /// Yes (on a phone, probably because No's centre is still within the
    /// area a touch on Yes keeps) or nothing (on an iPad), never No.
    @MainActor
    func testASlideFromYesOntoNoNeverSaysNo() throws {
        let app = launchedApp(textSize: .ax5)
        let yes = app.buttons["Yes"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let no = app.buttons["No"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))

        yes.press(forDuration: 1.5, thenDragTo: no, withVelocity: .slow, thenHoldForDuration: 0.5)

        // Wait for what the slide does say, if anything, before checking
        // what it must not.
        _ = app.staticTexts["Yes."].waitForExistence(timeout: 3)
        XCTAssertFalse(app.staticTexts["No."].exists, "a touch begun on Yes said No after sliding onto it")
    }
}
