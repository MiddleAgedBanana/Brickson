import XCTest

/// Home's sizes and Family Setup's answer in the running app
/// (docs/DECISIONS.md, "Sizes that follow how the screen is reached").
/// Until the owner switches it on, a person's launch keeps touch's sizes
/// whatever the answer, and the first step says nothing about sizes. A
/// launch that asks Home to follow the answer, as it will for everyone
/// once switched on, has the largest the window holds until anyone
/// answers, and touch's once Touch alone is chosen and Settings closes.
/// The other UI tests ask for touch's sizes (`launchedApp`).
///
/// Expected sizes come from the layout engine's table for the windows CI
/// runs (`ProfileChoiceTests.eyeTable`): Eye Tracking's on an iPad in
/// portrait, touch's on a phone, told apart here by the window's width
/// alone, as the engine does (a phone is under 600 points wide). Touch's
/// are the frames a launch at touch's sizes draws in the same window, so
/// a head tracking or Switch Control size, as tall as touch's on some
/// windows, does not pass for them. It says nothing about gaze comfort,
/// which needs a device (docs/HANDOFF.md).
///
/// Each test walks Settings to Family Setup's first step, so it launches
/// without the short idle limits, which could reset Settings part way.
final class HomeSizesTests: XCTestCase {
    /// Eye Tracking's floors (`HomeLayout.Profile`): quick controls and
    /// phrase tiles.
    private static let eyeQuickFloor: CGFloat = 109
    private static let eyeTileFloor: CGFloat = 136
    /// What the first step says about sizes, only once they follow the
    /// answer.
    private static let sizesSentence =
        "Home's buttons take the size the answers need, as large as this screen has room for, and are largest until something is chosen. The new size shows when Settings closes."
    /// The first step's sentence before it, shown whatever the sizes do.
    private static let leadSentence =
        "Choose every way that is used now. Each answer is saved as soon as it is chosen."

    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    @MainActor
    private func quickFrames(in app: XCUIApplication) -> [String: CGRect] {
        Dictionary(uniqueKeysWithValues: ["Yes", "No", "Emergency", "Again", "Get Attention"].map { ($0, app.buttons[$0].frame) })
    }

    /// The quick controls' frames at touch's sizes in this window, from a
    /// launch that asks for them.
    @MainActor
    private func touchFrames() -> [String: CGRect] {
        quickFrames(in: launchedApp(sizes: .touch, shortTimeouts: false))
    }

    /// Whether two frames are the same, to half a point.
    private static func same(_ a: CGRect, _ b: CGRect?) -> Bool {
        guard let b else { return false }
        return abs(a.minX - b.minX) <= 0.5 && abs(a.minY - b.minY) <= 0.5
            && abs(a.width - b.width) <= 0.5 && abs(a.height - b.height) <= 0.5
    }

    /// Whatever element carries these words in its label. A query by
    /// identifier, such as `app.staticTexts["…"]`, throws for a string
    /// longer than 128 characters, as the sizes sentence is.
    @MainActor
    private func text(_ words: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", words)).firstMatch
    }

    /// Opens Family Setup's first step from Home and returns its Touch
    /// answer, once it shows.
    @MainActor
    private func openFirstStep(_ app: XCUIApplication, context: String) -> XCUIElement {
        app.buttons["Settings"].tap()
        let familySetup = app.buttons["familySetup"].firstMatch
        XCTAssertTrue(familySetup.waitForExistence(timeout: 10), "Settings did not open (\(context))")
        familySetup.tap()
        let guided = app.buttons["guidedSetup"].firstMatch
        XCTAssertTrue(guided.waitForExistence(timeout: 10), "Family Setup did not open (\(context))")
        guided.tap()
        let touch = app.buttons["Touch"]
        XCTAssertTrue(touch.waitForExistence(timeout: 10), "the first step did not open (\(context))")
        return touch
    }

    /// Fails if a person's launch, before anyone answers, gives Home's
    /// quick controls other frames than touch's while the owner's switch is
    /// off (`ProfileChoice.followsTheAnswer`): on an iPad in portrait they
    /// would have Eye Tracking's. Fails too if the first step then says
    /// that Home's sizes follow the answers.
    @MainActor
    func testHomeKeepsTouchsSizesUntilTheOwnerSwitchesThemOn() {
        let touch = touchFrames()
        let app = launchedApp(sizes: .asShipped, shortTimeouts: false)
        let window = app.windows.firstMatch.frame
        let context = "window \(window.size)"
        attachCapture(app, name: "Home as shipped, \(context)")
        for (name, frame) in quickFrames(in: app) {
            XCTAssertTrue(Self.same(frame, touch[name]), "\(name) at \(frame), touch's \(String(describing: touch[name])) (\(context))")
        }
        _ = openFirstStep(app, context: context)
        XCTAssertTrue(text(Self.leadSentence, in: app).exists, "the first step's words did not show (\(context))")
        XCTAssertFalse(text(Self.sizesSentence, in: app).exists, "the first step says sizes follow the answers (\(context))")
    }

    /// With Home following the answer: fails if, before anyone answers,
    /// Home on an iPad in portrait has a quick control or a phrase tile
    /// smaller than Eye Tracking's floors, or a starter tile outside the
    /// window, or if a phone's quick controls have other frames than
    /// touch's, or if the first step does not say what the answers do;
    /// then, once Touch alone is chosen in Family Setup and Settings
    /// closes, if Home's quick controls are not back to touch's frames.
    @MainActor
    func testHomeIsLargestUntilAnsweredAndTouchsOnceTouchIsChosen() {
        let touchFrames = touchFrames()
        let app = launchedApp(sizes: .fromTheAnswer, shortTimeouts: false)
        let window = app.windows.firstMatch.frame
        let holdsEyeTracking = window.width >= 600 && window.height > window.width
        let context = "window \(window.size)"
        attachCapture(app, name: "Home before an answer, \(context)")
        for (name, frame) in quickFrames(in: app) {
            if holdsEyeTracking {
                XCTAssertGreaterThanOrEqual(frame.height, Self.eyeQuickFloor - 0.5, "\(name) at \(frame) (\(context))")
                XCTAssertGreaterThanOrEqual(frame.width, Self.eyeQuickFloor - 0.5, "\(name) at \(frame) (\(context))")
            } else {
                XCTAssertTrue(Self.same(frame, touchFrames[name]), "\(name) at \(frame), touch's \(String(describing: touchFrames[name])) (\(context))")
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
        let touch = openFirstStep(app, context: context)
        XCTAssertTrue(text(Self.sizesSentence, in: app).exists, "the first step does not say what the answers do (\(context))")
        touch.tap()
        let chosen = expectation(for: NSPredicate(format: "isSelected == true"), evaluatedWith: touch)
        XCTAssertEqual(XCTWaiter.wait(for: [chosen], timeout: 10), .completed, "Touch was not chosen (\(context))")
        app.buttons["backToTalking"].tap()
        let closed = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: app.buttons["backToTalking"])
        XCTAssertEqual(XCTWaiter.wait(for: [closed], timeout: 10), .completed, "Settings did not close (\(context))")

        let yes = app.buttons["Yes"]
        let touchYes = touchFrames["Yes"]
        let touchSized = expectation(for: NSPredicate { _, _ in
            MainActor.assumeIsolated { Self.same(yes.frame, touchYes) }
        }, evaluatedWith: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [touchSized], timeout: 10), .completed, "Yes kept other sizes than touch's after Touch was chosen (\(context))")
        attachCapture(app, name: "Home after Touch, \(context)")
        for (name, frame) in quickFrames(in: app) {
            XCTAssertTrue(Self.same(frame, touchFrames[name]), "\(name) at \(frame) after Touch, touch's \(String(describing: touchFrames[name])) (\(context))")
        }
    }
}
