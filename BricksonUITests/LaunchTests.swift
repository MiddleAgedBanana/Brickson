import XCTest

/// Launches the real app on a simulator and drives it the way a person
/// would. Run them with the Brickson-UI scheme or `scripts/test.sh ui`
/// (README, "First time on your Mac", step 7); GitHub CI runs them on every
/// pull request, on an iPad and an iPhone.
///
/// These check that the app opens and its first screen works. They say
/// nothing about how it feels with Eye Tracking, Switch Control or Voice
/// Control on a real device; those checks are listed in docs/HANDOFF.md.
/// Every launch goes through `launchedApp` (LaunchHelpers.swift), which
/// starts from fresh test-only storage.
final class LaunchTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// The phrase tile showing `text`, found by its label. (Tiles all share
    /// the identifier "phraseTile", so they are not looked up by identifier.)
    @MainActor
    private func phraseTile(_ text: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label == %@", text)).firstMatch
    }

    @MainActor
    func testHomeShowsTheQuickControlsAndStarterPhrases() {
        let app = launchedApp()

        for name in ["Yes", "No", "Emergency", "Again"] {
            XCTAssertTrue(app.buttons[name].exists, "\(name) is missing")
        }
        // Home starts on the first everyday category, not on Emergency.
        XCTAssertTrue(phraseTile("Hello.", in: app).exists, "the Basics phrases are not showing")
    }

    /// Invariant 2: a phrase speaks on the first activation. Again turns on
    /// once there is something to repeat.
    @MainActor
    func testAPhraseSpeaksOnTheFirstTap() {
        let app = launchedApp()
        let phrase = phraseTile("Hello.", in: app)
        XCTAssertTrue(phrase.waitForExistence(timeout: 5))

        phrase.tap()

        // Wait for Again to turn on rather than reading it once. On a busy
        // CI machine a single read straight after tap() once found Again
        // still off, with the same code green elsewhere (PR #4). The cause
        // wasn't established; the first test to tap a phrase is also the
        // first to start the audio session and the speech engine. The app
        // still speaks on the first tap; only the test waits.
        let turnsOn = NSPredicate(format: "isEnabled == true")
        XCTAssertEqual(
            XCTWaiter.wait(for: [expectation(for: turnsOn, evaluatedWith: app.buttons["Again"])], timeout: 10),
            .completed,
            "Again was still off 10 s after \"Hello.\" was tapped: the tap did not reach the tile, or the phrase did not start"
        )
    }

    /// Emergency switches straight to the emergency phrases and says nothing
    /// itself: Again stays off because nothing has been spoken.
    @MainActor
    func testEmergencyShowsTheEmergencyPhrases() {
        let app = launchedApp()
        XCTAssertFalse(app.buttons["Again"].isEnabled, "something was spoken at launch")

        app.buttons["Emergency"].tap()

        XCTAssertTrue(phraseTile("I need help now.", in: app).waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Again"].isEnabled, "Emergency spoke")
    }

    // MARK: Apple's accessibility audit

    @MainActor
    func testHomePassesTheAccessibilityAudit() throws {
        // Report every issue the audit finds, not only the first.
        continueAfterFailure = true
        let app = launchedApp()
        expectKnownPhoneHomeAuditFindings()
        try assertPassesAccessibilityAudit(app, context: "Home, light")
    }

    /// Dark mode changes every colour on screen, system components' too
    /// (invariant 6).
    @MainActor
    func testHomeInDarkModePassesTheAccessibilityAudit() throws {
        continueAfterFailure = true
        let app = launchedApp(appearance: .dark)
        expectKnownPhoneHomeAuditFindings()
        try assertPassesAccessibilityAudit(app, context: "Home, dark")
    }

    /// The emergency phrases have their own colour and the Emergency
    /// control its selected look.
    @MainActor
    func testTheEmergencyPhrasesPassTheAccessibilityAudit() throws {
        let app = launchedApp()
        app.buttons["Emergency"].tap()
        XCTAssertTrue(phraseTile("I need help now.", in: app).waitForExistence(timeout: 5))
        continueAfterFailure = true
        expectKnownPhoneHomeAuditFindings()
        try assertPassesAccessibilityAudit(app, context: "Home with the emergency phrases, light")
    }

    // MARK: The test settings take effect

    // The UI tests at the largest text size (HomeReachabilityTests) are only
    // evidence if the size really changed. If the launch argument stopped
    // working, they would quietly test the default size; this fails first.
    @MainActor
    func testTheTextSizeSettingTakesEffect() {
        let defaultHeight = placeholderHeight(in: launchedApp(textSize: .large))
        let largestHeight = placeholderHeight(in: launchedApp(textSize: .ax5))
        XCTAssertGreaterThan(
            largestHeight, defaultHeight * 1.5,
            "The message placeholder is \(largestHeight)pt tall at AX5 and \(defaultHeight)pt at the default size: the text size did not change"
        )
    }

    // Likewise for the dark-mode audit: if the appearance did not change,
    // it would audit light mode twice. (Its first version read one pixel
    // in the left margin and found it white in dark mode on CI, on the
    // iPad and the iPhone; the median of the whole screen does not depend
    // on where the margin is.)
    @MainActor
    func testTheAppearanceSettingTakesEffect() throws {
        let light = try XCTUnwrap(
            backgroundBrightness(of: launchedApp(appearance: .light), name: "Home, light"),
            "Could not read the light-mode screenshot"
        )
        let dark = try XCTUnwrap(
            backgroundBrightness(of: launchedApp(appearance: .dark), name: "Home, dark"),
            "Could not read the dark-mode screenshot"
        )
        XCTAssertGreaterThan(
            light - dark, 0.5,
            "Home is \(light) bright in light mode and \(dark) in dark mode (median of the screen; 0 black, 1 white): the appearance did not change"
        )
    }

    /// The height of the message row's placeholder, which follows Dynamic
    /// Type. If Home's wording changes, measure another text that follows
    /// Dynamic Type instead.
    @MainActor
    private func placeholderHeight(in app: XCUIApplication) -> Double {
        let text = app.staticTexts["Choose a phrase to speak it."]
        guard text.waitForExistence(timeout: 5) else {
            XCTFail("Home has no \"Choose a phrase to speak it.\" text to measure")
            return 0
        }
        return text.frame.height
    }
}
