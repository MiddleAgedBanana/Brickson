import XCTest

/// Launches the real app on a simulator and drives it the way a person
/// would. Run them with the Brickson-UI scheme or `scripts/test.sh ui`
/// (README, "First time on your Mac", step 7); GitHub CI runs them on every
/// pull request.
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
        // wasn't established; this test runs first, so its tap is also the
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

    /// Apple's automated accessibility audit: contrast, element labels, hit
    /// regions, Dynamic Type support and clipped text. Each issue is reported
    /// with the element it names, so the failure says what to fix.
    ///
    /// One kind of issue is expected and not reported: the audit's guess that
    /// a phrase tile's label is "not human-readable". A tile's label is the
    /// phrase itself, the person's own words, which VoiceOver must read
    /// exactly as written; the audit flagged the starter phrase "Maybe." on
    /// CI. An empty tile label still fails.
    @MainActor
    func testHomePassesTheAccessibilityAudit() throws {
        // Report every issue the audit finds, not only the first.
        continueAfterFailure = true
        let app = launchedApp()
        try app.performAccessibilityAudit { issue in
            MainActor.assumeIsolated {
                if Self.isPhraseTileLabelGuess(issue) { return }
                let element = issue.element.map {
                    "\"\($0.label)\" (identifier \"\($0.identifier)\", frame \($0.frame))"
                } ?? "no element"
                XCTFail("Accessibility audit (type \(issue.auditType.rawValue)): \(issue.compactDescription) on \(element). \(issue.detailedDescription)")
            }
            // Reported above (or expected); returning true stops the audit
            // failing a second time with less detail.
            return true
        }
    }

    /// Phrase tiles carry the identifier "phraseTile" (HomeView's PhraseGrid).
    @MainActor
    private static func isPhraseTileLabelGuess(_ issue: XCUIAccessibilityAuditIssue) -> Bool {
        guard issue.auditType == .sufficientElementDescription,
              let element = issue.element,
              element.identifier == "phraseTile" else { return false }
        return !element.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
