import XCTest

/// Home's sizes follow Family Setup's answer in the running app
/// (docs/DECISIONS.md, "Sizes that follow how the screen is reached"):
/// the largest the window holds until anyone answers, and touch's once
/// Touch alone is chosen and Settings closes. The other UI tests ask for
/// touch's sizes (`launchedApp`); these leave the answer to decide.
///
/// Expected sizes come from the layout engine's table for the windows CI
/// runs (`ProfileChoiceTests.eyeTable`): Eye Tracking's on an iPad in
/// portrait, touch's on a phone, told apart here by the window's width
/// alone, as the engine does (a phone is under 600 points wide). It says
/// nothing about gaze comfort, which needs a device (docs/HANDOFF.md).
final class HomeSizesTests: XCTestCase {
    /// Eye Tracking's floors (`HomeLayout.Profile`): quick controls and
    /// phrase tiles. Touch's quick controls grow to 88 points at most.
    private static let eyeQuickFloor: CGFloat = 109
    private static let eyeTileFloor: CGFloat = 136
    private static let touchQuickMost: CGFloat = 88

    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    @MainActor
    private func quickHeights(in app: XCUIApplication) -> [String: CGRect] {
        Dictionary(uniqueKeysWithValues: ["Yes", "No", "Emergency", "Again", "Get Attention"].map { ($0, app.buttons[$0].frame) })
    }

    /// Fails if, before anyone answers, Home on an iPad in portrait has a
    /// quick control or a phrase tile smaller than Eye Tracking's floors,
    /// or a starter tile outside the window, or if a phone's Home has
    /// larger than touch's sizes; then, once Touch alone is chosen in
    /// Family Setup and Settings closes, if Home's quick controls are not
    /// back to touch's.
    @MainActor
    func testHomeIsLargestUntilAnsweredAndTouchsOnceTouchIsChosen() {
        let app = launchedApp(sizes: .fromTheAnswer)
        let window = app.windows.firstMatch.frame
        let holdsEyeTracking = window.width >= 600 && window.height > window.width
        let context = "window \(window.size)"
        attachCapture(app, name: "Home before an answer, \(context)")
        for (name, frame) in quickHeights(in: app) {
            if holdsEyeTracking {
                XCTAssertGreaterThanOrEqual(frame.height, Self.eyeQuickFloor - 0.5, "\(name) at \(frame) (\(context))")
                XCTAssertGreaterThanOrEqual(frame.width, Self.eyeQuickFloor - 0.5, "\(name) at \(frame) (\(context))")
            } else {
                XCTAssertLessThanOrEqual(frame.height, Self.touchQuickMost + 0.5, "\(name) at \(frame) (\(context))")
            }
        }
        let tiles = app.buttons.matching(identifier: "phraseTile").allElementsBoundByIndex
        XCTAssertFalse(tiles.isEmpty, "Home shows no phrase tiles (\(context))")
        if holdsEyeTracking {
            for tile in tiles {
                let frame = tile.frame
                XCTAssertTrue(window.contains(frame), "a tile at \(frame) is not inside the window (\(context))")
                XCTAssertGreaterThanOrEqual(frame.height, Self.eyeTileFloor - 0.5, "a tile at \(frame) (\(context))")
                XCTAssertGreaterThanOrEqual(frame.width, Self.eyeTileFloor - 0.5, "a tile at \(frame) (\(context))")
            }
        }

        // Touch alone, chosen in Family Setup's first step.
        app.buttons["Settings"].tap()
        let familySetup = app.buttons["familySetup"].firstMatch
        XCTAssertTrue(familySetup.waitForExistence(timeout: 10), "Settings did not open (\(context))")
        familySetup.tap()
        let guided = app.buttons["guidedSetup"].firstMatch
        XCTAssertTrue(guided.waitForExistence(timeout: 10), "Family Setup did not open (\(context))")
        guided.tap()
        let touch = app.buttons["Touch"]
        XCTAssertTrue(touch.waitForExistence(timeout: 10), "the first step did not open (\(context))")
        XCTAssertTrue(app.staticTexts["Home's buttons take the size the answers need, as large as this screen has room for, and are largest until something is chosen. The new size shows when Settings closes."].exists,
            "the first step does not say what the answers do (\(context))")
        touch.tap()
        let chosen = expectation(for: NSPredicate(format: "isSelected == true"), evaluatedWith: touch)
        XCTAssertEqual(XCTWaiter.wait(for: [chosen], timeout: 10), .completed, "Touch was not chosen (\(context))")
        app.buttons["backToTalking"].tap()
        let closed = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: app.buttons["backToTalking"])
        XCTAssertEqual(XCTWaiter.wait(for: [closed], timeout: 10), .completed, "Settings did not close (\(context))")

        let yes = app.buttons["Yes"]
        let touchSized = expectation(for: NSPredicate { _, _ in
            MainActor.assumeIsolated { yes.frame.height <= Self.touchQuickMost + 0.5 }
        }, evaluatedWith: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [touchSized], timeout: 10), .completed, "Yes kept larger sizes after Touch was chosen (\(context))")
        attachCapture(app, name: "Home after Touch, \(context)")
        for (name, frame) in quickHeights(in: app) {
            XCTAssertLessThanOrEqual(frame.height, Self.touchQuickMost + 0.5, "\(name) at \(frame) after Touch (\(context))")
        }
    }
}
