import UIKit
import XCTest

/// Settings, opened at launch with `--screen=settings` until Home has its
/// Settings button. These check what a family member and a stray
/// activation meet: the way back and one row on the first screen, Family
/// Setup a screen below, the privacy policy inside the app, the idle reset
/// that returns to the first screen and never closes Settings, and Apple's
/// accessibility audit on each screen.
///
/// Only the idle-reset test uses the 3-second idle limit
/// (`--short-timeouts`): an audit can take longer than that, and a reset in
/// the middle of a test would move it back to the first screen.
///
/// None of this is evidence about Eye Tracking, Switch Control or touch on a
/// real device (docs/HANDOFF.md, "Checks that need a real device").
final class SettingsTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func openSettings(
        textSize: UITestTextSize = .large,
        appearance: UITestAppearance = .light,
        shortTimeouts: Bool = false,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> XCUIApplication {
        let app = launchedApp(
            textSize: textSize,
            appearance: appearance,
            arguments: ["--screen=settings"],
            shortTimeouts: shortTimeouts,
            waitsForHome: false,
            file: file,
            line: line
        )
        XCTAssertTrue(
            app.buttons["backToTalking"].waitForExistence(timeout: 60),
            "Settings did not open at launch",
            file: file, line: line
        )
        return app
    }

    @MainActor
    private func open(_ identifier: String, in app: XCUIApplication, waitingFor title: String) {
        let row = app.buttons[identifier].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), "\(identifier) is missing")
        row.tap()
        XCTAssertTrue(
            app.navigationBars[title].waitForExistence(timeout: 10),
            "\(title) did not open after \(identifier) was chosen"
        )
    }

    /// The first screen holds the way back and one row that only
    /// navigates (docs/DECISIONS.md, "Settings is a cover with a fixed
    /// safety bar").
    @MainActor
    func testSettingsOpensOnTheWayBackAndFamilySetup() {
        continueAfterFailure = true
        for textSize in [UITestTextSize.large, .ax5] {
            let app = openSettings(textSize: textSize)
            let context = "Settings, \(textSize.name)"
            attachCapture(app, name: context)
            assertReachable("backToTalking", in: app, context: context)
            assertReachable("familySetup", in: app, context: context)
            XCTAssertFalse(app.buttons["privacyPolicy"].exists, "the settings are on the first screen (\(context))")
        }
    }

    @MainActor
    func testBackToTalkingReturnsToHome() {
        let app = openSettings()
        app.buttons["backToTalking"].tap()

        XCTAssertTrue(app.buttons["Yes"].waitForExistence(timeout: 10), "Home did not come back")
        XCTAssertFalse(app.buttons["backToTalking"].exists, "Settings is still open")
    }

    /// The way back stays in the same place on every screen.
    @MainActor
    func testTheWayBackKeepsItsFrameOnEveryScreen() {
        let app = openSettings()
        let way = app.buttons["backToTalking"]
        let onRoot = way.frame

        open("familySetup", in: app, waitingFor: "Family Setup")
        XCTAssertEqual(way.frame, onRoot, "Back to Talking moved on Family Setup")

        open("privacyPolicy", in: app, waitingFor: "Privacy Policy")
        XCTAssertEqual(way.frame, onRoot, "Back to Talking moved on the privacy policy")
        assertReachable("backToTalking", in: app, context: "privacy policy")
    }

    /// Family Setup opens on passive text over the whole of the root's
    /// Family Setup row as drawn, its button style's insets included, so a
    /// repeated activation where that row was lands on words (Codex,
    /// PR #23). Fails if the opening is sized from the row's label alone.
    @MainActor
    func testFamilySetupOpensOnTextOverTheWholeRootRow() {
        continueAfterFailure = true
        for textSize in [UITestTextSize.large, .ax5] {
            let app = openSettings(textSize: textSize)
            let context = "Family Setup, \(textSize.name)"
            let row = app.buttons["familySetup"]
            XCTAssertTrue(row.waitForExistence(timeout: 10), "familySetup is missing (\(context))")
            let rowFrame = row.frame

            open("familySetup", in: app, waitingFor: "Family Setup")
            let opening = app.descendants(matching: .any)["familySetupOpening"]
            XCTAssertTrue(opening.waitForExistence(timeout: 10), "the opening text is missing (\(context))")
            attachCapture(app, name: context)
            XCTAssertLessThanOrEqual(
                opening.frame.minY, rowFrame.minY + 0.5,
                "the opening text starts below the root row's top (\(context)): \(opening.frame) against \(rowFrame)"
            )
            XCTAssertGreaterThanOrEqual(
                opening.frame.maxY, rowFrame.maxY - 0.5,
                "the root row's lower edge lands below the opening text (\(context)): \(opening.frame) against \(rowFrame)"
            )
        }
    }

    /// App Review Guideline 5.1.1(i): the policy is inside the app. It is
    /// the public page's own words.
    @MainActor
    func testThePrivacyPolicyIsInsideTheApp() {
        let app = openSettings()
        open("familySetup", in: app, waitingFor: "Family Setup")
        open("privacyPolicy", in: app, waitingFor: "Privacy Policy")

        XCTAssertTrue(app.staticTexts["Who we are"].waitForExistence(timeout: 10), "the policy's text is not showing")
        XCTAssertTrue(app.buttons["Open the Web Version"].exists)
        attachCapture(app, name: "Privacy Policy")
    }

    /// Left alone, Settings goes back to its first screen and stays open
    /// (docs/DECISIONS.md, "Settings resets when idle and never closes").
    /// `--short-timeouts` makes the wait 3 seconds.
    @MainActor
    func testAnIdleSettingsReturnsToItsFirstScreenAndStaysOpen() {
        let app = openSettings(shortTimeouts: true)
        open("familySetup", in: app, waitingFor: "Family Setup")

        let root = app.navigationBars["Settings"]
        XCTAssertEqual(
            XCTWaiter.wait(for: [expectation(for: NSPredicate(format: "exists == true"), evaluatedWith: root)], timeout: 30),
            .completed,
            "Settings did not go back to its first screen when left alone"
        )
        XCTAssertTrue(app.buttons["backToTalking"].exists, "the idle reset closed Settings")
        let yes = app.buttons["Yes"]
        XCTAssertFalse(yes.exists && yes.isHittable, "Home is showing: the idle reset closed Settings")
    }

    // MARK: Apple's accessibility audit

    @MainActor
    func testSettingsScreensPassTheAccessibilityAudit() throws {
        continueAfterFailure = true
        for appearance in [UITestAppearance.light, .dark] {
            let app = openSettings(appearance: appearance)
            try assertPassesAccessibilityAudit(app, context: "Settings, \(appearance.rawValue)")

            open("familySetup", in: app, waitingFor: "Family Setup")
            try assertPassesAccessibilityAudit(app, context: "Family Setup, \(appearance.rawValue)")

            open("privacyPolicy", in: app, waitingFor: "Privacy Policy")
            try assertPassesAccessibilityAudit(app, context: "Privacy Policy, \(appearance.rawValue)")
        }
    }

    @MainActor
    func testVoiceSettingsPassesTheAccessibilityAudit() throws {
        continueAfterFailure = true
        let app = openSettings()
        open("familySetup", in: app, waitingFor: "Family Setup")
        open("voiceSettings", in: app, waitingFor: "Voice Settings")
        attachCapture(app, name: "Voice Settings")
        try assertPassesAccessibilityAudit(app, context: "Voice Settings, light")
    }

    /// A speed is a fixed choice: choosing it again keeps it, so a repeated
    /// activation never walks the speed (docs/DECISIONS.md, "Speed is a set
    /// of fixed choices").
    @MainActor
    func testASpeedChosenTwiceStaysChosen() {
        let app = openSettings()
        open("familySetup", in: app, waitingFor: "Family Setup")
        open("voiceSettings", in: app, waitingFor: "Voice Settings")

        let slower = app.buttons["70% of normal speed"]
        XCTAssertTrue(slower.waitForExistence(timeout: 10), "the 70% speed is missing")
        slower.tap()
        XCTAssertEqual(
            XCTWaiter.wait(for: [expectation(for: NSPredicate(format: "isSelected == true"), evaluatedWith: slower)], timeout: 10),
            .completed,
            "choosing 70% did not choose it"
        )
        slower.tap()
        XCTAssertTrue(slower.isSelected, "choosing 70% again changed the speed")
        XCTAssertFalse(app.buttons["Normal speed"].isSelected, "two speeds show as chosen")
        XCTAssertFalse(app.buttons["60% of normal speed"].isSelected, "choosing 70% again walked the speed")
    }

    /// Choosing a speed changes the sentence above the choices, but moves
    /// none of them, so a repeated activation meets the same choice
    /// (AGENTS.md, "Controls keep their frames across every state of a
    /// screen"). At the largest text size the two sentences wrap to
    /// different heights on a phone. Distances are measured from the Speed
    /// heading, so scrolling the choice into view does not count as a move.
    @MainActor
    func testChoosingASpeedMovesNoSpeedChoice() {
        let app = openSettings(textSize: .ax5)
        open("familySetup", in: app, waitingFor: "Family Setup")
        open("voiceSettings", in: app, waitingFor: "Voice Settings")

        let heading = app.staticTexts["Speed"]
        let normal = app.buttons["Normal speed"]
        let slowest = app.buttons["60% of normal speed"]
        XCTAssertTrue(slowest.waitForExistence(timeout: 10), "the 60% speed is missing")
        XCTAssertTrue(normal.isSelected, "a fresh launch does not speak at normal speed")
        let before = normal.frame.minY - heading.frame.minY

        slowest.tap()
        XCTAssertEqual(
            XCTWaiter.wait(for: [expectation(for: NSPredicate(format: "isSelected == true"), evaluatedWith: slowest)], timeout: 10),
            .completed,
            "choosing 60% did not choose it"
        )
        XCTAssertEqual(
            normal.frame.minY - heading.frame.minY, before, accuracy: 0.5,
            "choosing a speed moved the speed choices"
        )
    }

    /// VoiceOver reads each numbered step with its number, so the order is
    /// clear when focus moves backward or straight to one step.
    @MainActor
    func testNumberedStepsAreReadWithTheirNumbers() {
        let app = openSettings()
        open("familySetup", in: app, waitingFor: "Family Setup")
        // The screen's title carries the app's name, which is not final,
        // so the test waits for the step instead.
        let row = app.buttons["keepOpen"]
        XCTAssertTrue(row.waitForExistence(timeout: 10), "keepOpen is missing")
        row.tap()

        let step = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "Guided Access and turn it on"))
            .firstMatch
        XCTAssertTrue(step.waitForExistence(timeout: 10), "Keep Open did not open, or its first Guided Access step is missing")
        XCTAssertTrue(step.label.hasPrefix("1"), "the first step is read without its number: \(step.label)")
    }

    @MainActor
    func testTheStepByStepSetupWalksToTheEnd() {
        let app = openSettings()
        open("familySetup", in: app, waitingFor: "Family Setup")
        open("guidedSetup", in: app, waitingFor: "Step 1 of 5")

        app.buttons["Eye Tracking"].tap()
        XCTAssertTrue(app.buttons["Eye Tracking"].isSelected, "choosing an answer did not select it")
        // A second activation keeps it chosen: answers only select.
        app.buttons["Eye Tracking"].tap()
        XCTAssertTrue(app.buttons["Eye Tracking"].isSelected, "a repeated activation undid the answer")

        for step in 2...5 {
            app.buttons["guidedSetupNext"].tap()
            XCTAssertTrue(app.navigationBars["Step \(step) of 5"].waitForExistence(timeout: 10), "step \(step) did not open")
        }
        XCTAssertTrue(app.staticTexts["Eye Tracking"].exists, "the summary does not list the answer")

        app.buttons["guidedSetupNext"].tap()
        XCTAssertTrue(app.navigationBars["Family Setup"].waitForExistence(timeout: 10), "Done did not return to Family Setup")
    }
}
