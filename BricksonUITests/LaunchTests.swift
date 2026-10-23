import UIKit
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

        for name in ["Yes", "No", "Emergency", "Get Attention", "Again"] {
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
        try assertPassesAccessibilityAudit(app, context: "Home, light")
    }

    /// Dark mode changes every colour on screen, system components' too
    /// (invariant 6).
    @MainActor
    func testHomeInDarkModePassesTheAccessibilityAudit() throws {
        continueAfterFailure = true
        let app = launchedApp(appearance: .dark)
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
        try assertPassesAccessibilityAudit(app, context: "Home with the emergency phrases, light")
    }

    /// A button's accessibility frame can be correct while its visible
    /// label is clipped. Read the rendered words too, without supplying
    /// the recognizer with the expected text or language correction
    /// (`RenderedWords`).
    @MainActor
    func testLargestTextKeepsQuickControlWordsVisible() async throws {
        continueAfterFailure = true
        for appearance in [UITestAppearance.light, .dark] {
            let app = launchedApp(textSize: .ax5, appearance: appearance)
            for state in ["just opened", "emergency selected", "phrase spoken"] {
                if state == "emergency selected" {
                    app.buttons["Emergency"].tap()
                    XCTAssertTrue(phraseTile("I need help now.", in: app).waitForExistence(timeout: 10))
                } else if state == "phrase spoken" {
                    app.buttons["Yes"].tap()
                    let againTurnsOn = expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: app.buttons["Again"])
                    let againResult = await XCTWaiter.fulfillment(of: [againTurnsOn], timeout: 15, enforceOrder: false)
                    XCTAssertEqual(againResult, .completed)
                    // The audit after this state waits for speech to end
                    // too. Waiting here as well keeps the captures and word
                    // checks below, over a second of work, between the last
                    // change on screen and the audit (issue #30).
                    waitForSpeechToFinish(in: app, context: "AX5, \(appearance.rawValue), phrase spoken")
                }
                let context = "AX5, \(appearance.rawValue), \(state)"
                attachCapture(app, name: context)
                for label in ["Yes", "No", "Emergency", "Get Attention", "Again"] {
                    let screenshot = app.buttons[label].screenshot()
                    let attachment = XCTAttachment(screenshot: screenshot)
                    attachment.name = "\(context), \(label)"
                    attachment.lifetime = .keepAlways
                    add(attachment)
                    let image = try XCTUnwrap(screenshot.image.cgImage)
                    let words = try await RenderedWords.read(image)
                    // Each word whole: Get Attention may take two lines.
                    XCTAssertTrue(
                        label.split(separator: " ").allSatisfy { RenderedWords.show(String($0), in: words) },
                        "Rendered \(label) is unreadable (\(context)); recognized \(words)"
                    )
                }
            }
            try assertPassesAccessibilityAudit(app, context: "AX5, \(appearance.rawValue)")
        }
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
            "The first-run hint is \(largestHeight)pt tall at AX5 and \(defaultHeight)pt at the default size: the text size did not change"
        )
    }

    // Independently check the rendered appearance: reading back the
    // requested flag alone would let a broken launch setup pass.
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
        print("Rendered background brightness: light=\(light), dark=\(dark)")
        XCTAssertGreaterThan(
            light - dark, 0.5,
            "Home is \(light) bright in light mode and \(dark) in dark mode (background gutter; 0 black, 1 white): the appearance did not change"
        )
    }

    /// The height of the line the message row shows on a first launch, the
    /// first-run hint, which follows Dynamic Type. Every launch here starts
    /// on fresh storage, so Family Setup has never been opened. If Home's
    /// wording changes, measure another text that follows Dynamic Type
    /// instead.
    @MainActor
    private func placeholderHeight(in app: XCUIApplication) -> Double {
        let hint = "Family: help with setting up is in Settings."
        let text = app.staticTexts[hint]
        guard text.waitForExistence(timeout: 5) else {
            XCTFail("Home has no \"\(hint)\" text to measure")
            return 0
        }
        return text.frame.height
    }
}
