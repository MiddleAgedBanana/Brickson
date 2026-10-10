import XCTest

/// Launches the real app on a simulator and drives it the way a person
/// would. Opt-in: run the Brickson-UI scheme (README, "Run the tests").
///
/// These check that the app opens and its first screen works. They say
/// nothing about how it feels with Eye Tracking, Switch Control or Voice
/// Control on a real device; those checks are listed in docs/HANDOFF.md.
final class LaunchTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func launchedApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["Yes"].waitForExistence(timeout: 15), "Home did not appear")
        return app
    }

    @MainActor
    func testHomeShowsTheQuickControlsAndStarterPhrases() {
        let app = launchedApp()

        for name in ["Yes", "No", "Emergency", "Again"] {
            XCTAssertTrue(app.buttons[name].exists, "\(name) is missing")
        }
        // Home starts on the first everyday category, not on Emergency.
        XCTAssertTrue(app.buttons["Hello."].exists, "the Basics phrases are not showing")
    }

    /// Invariant 2: a phrase speaks on the first activation. Again turns on
    /// once there is something to repeat.
    @MainActor
    func testAPhraseSpeaksOnTheFirstTap() {
        let app = launchedApp()
        let phrase = app.buttons["Hello."]
        XCTAssertTrue(phrase.waitForExistence(timeout: 5))

        phrase.tap()

        XCTAssertTrue(app.buttons["Again"].isEnabled)
    }

    /// Emergency switches straight to the emergency phrases and says nothing
    /// itself.
    @MainActor
    func testEmergencyShowsTheEmergencyPhrases() {
        let app = launchedApp()

        app.buttons["Emergency"].tap()

        XCTAssertTrue(app.buttons["I need help now."].waitForExistence(timeout: 5))
    }

    /// Apple's automated accessibility audit: contrast, element labels, hit
    /// regions, Dynamic Type support and clipped text. Each issue is reported
    /// with the element it names, so the failure says what to fix.
    @MainActor
    func testHomePassesTheAccessibilityAudit() throws {
        let app = launchedApp()
        try app.performAccessibilityAudit { issue in
            MainActor.assumeIsolated {
                let element = issue.element.map {
                    "\"\($0.label)\" (identifier \"\($0.identifier)\", frame \($0.frame))"
                } ?? "no element"
                XCTFail("Accessibility audit: \(issue.compactDescription) on \(element). \(issue.detailedDescription)")
            }
            // Reported above; returning true stops the audit failing a second
            // time with less detail.
            return true
        }
    }
}
