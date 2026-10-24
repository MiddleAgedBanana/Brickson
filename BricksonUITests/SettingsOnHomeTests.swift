import UIKit
import XCTest

/// Settings opened with Home's own button, and what a look that stays where
/// it was meets on each side (invariant 10; docs/DECISIONS.md, "Settings on
/// Home"). Under AssistiveTouch Dwell, head tracking or Eye Tracking the
/// pointer is still resting on the control just used when the next screen
/// appears, so a held look can activate whatever is now nearest.
///
/// - Opening: the spot where Home's Settings was is nearest Family Setup,
///   which only opens the next screen.
/// - Closing: the spot where Back to Talking was is nearest Emergency,
///   which only shows the emergency phrases. Before this, it was nearest
///   Again, which speaks.
/// - Chains: on the way in, it also reads Family Setup and, where its row
///   shows, Set Up Step by Step's first step and, where its link shows,
///   the guide that link opens, and has the chain engine follow every
///   chain of held activations from Home's Settings and from each control
///   of those screens, out to Home and back (`SettingsChains`,
///   `ChainEngine`). No chain may save an answer in the first step. One
///   kind of hazard is known and expected, strictly, so it fails once it
///   is gone: Settings closes under a look resting over Yes, No or Get
///   Attention (docs/DECISIONS.md, "One chain engine for dwell safety").
///   Any other hazard fails.
///
/// "Nearest" is scored two ways, because how Snap to Item picks a target is
/// a device check (docs/HANDOFF.md, *Checks that need a real device*): by
/// the nearest centre and by the nearest edge, with ties counted. Both must
/// name the same harmless control. This reads the frames the app hands to
/// assistive technologies on the simulator CI runs; it is not evidence of
/// what a person's gaze does on a device.
final class SettingsOnHomeTests: XCTestCase {
    /// Home's controls that keep their place in every state, by the name
    /// `screenControls(in:)` gives them. The category names are copied from
    /// Brickson/Resources/StarterPhrases.json, as in `HomeLayoutTests`.
    private static let fixedOnHome = [
        "Yes", "No", "Emergency", "Again", "getAttention", "settings", "Basics", "Needs", "Conversation", "Feelings",
    ]
    private static let everydayCategories = ["Basics", "Needs", "Conversation", "Feelings"]
    private static let firstRunHint = "Family: help with setting up is in Settings."

    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    @MainActor
    func testOpeningSettingsFromHomeAtDefaultText() throws {
        try checkTheWayInAndOut(textSize: .large, orientation: .portrait)
    }

    @MainActor
    func testOpeningSettingsFromHomeAtTheLargestText() throws {
        try checkTheWayInAndOut(textSize: .ax5, orientation: .portrait)
    }

    /// The iPhone keeps portrait (docs/DECISIONS.md, "Orientations"), so
    /// this checks the iPad's other arrangement only.
    @MainActor
    func testOpeningSettingsFromHomeInLandscape() throws {
        try XCTSkipIf(UIDevice.current.userInterfaceIdiom == .phone, "the iPhone is portrait only")
        try checkTheWayInAndOut(textSize: .large, orientation: .landscapeLeft)
    }

    /// Fails if a first launch does not tell the family where setup is, or
    /// if the line stays once Family Setup has been opened.
    @MainActor
    func testTheFirstRunHintShowsUntilFamilySetupOpens() {
        let app = launchedApp()
        XCTAssertTrue(app.staticTexts[Self.firstRunHint].waitForExistence(timeout: 10), "a first launch shows no setup hint")

        app.buttons["settings"].tap()
        let familySetup = app.buttons["familySetup"]
        XCTAssertTrue(familySetup.waitForExistence(timeout: 10), "Settings did not open from Home")
        familySetup.tap()
        XCTAssertTrue(app.navigationBars["Family Setup"].waitForExistence(timeout: 10), "Family Setup did not open")
        app.buttons["backToTalking"].tap()

        let placeholder = app.staticTexts["Choose a phrase to speak it."]
        XCTAssertTrue(placeholder.waitForExistence(timeout: 10), "Home did not show its placeholder after Family Setup was opened")
        XCTAssertFalse(app.staticTexts[Self.firstRunHint].exists, "the setup hint is still showing after Family Setup was opened")
    }

    @MainActor
    private func checkTheWayInAndOut(textSize: UITestTextSize, orientation: UIDeviceOrientation) throws {
        // Settings' full idle limit: reading and capturing three screens can
        // take longer than the 3-second test limit, and a reset part way
        // would put Settings back on its first screen (as in `SettingsTests`).
        let app = launchedApp(textSize: textSize, orientation: orientation, shortTimeouts: false)
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        // A query straight after a rotation can read the frames from before
        // the turn, so wait for the window to turn first.
        let turned = NSPredicate { _, _ in
            MainActor.assumeIsolated {
                let frame = app.windows.firstMatch.frame
                return (frame.width > frame.height) == orientation.isLandscape
            }
        }
        XCTAssertEqual(
            XCTWaiter.wait(for: [expectation(for: turned, evaluatedWith: nil)], timeout: 10), .completed,
            "the window did not turn to \(orientation.isLandscape ? "landscape" : "portrait")"
        )
        let window = app.windows.firstMatch.frame
        let context = "\(textSize.name), \(orientation.isLandscape ? "landscape" : "portrait"), \(isPad ? "iPad" : "iPhone"), window \(window.size)"

        assertReachable("Settings", in: app, context: context)
        let home = try screenControls(in: app)
        let before = Self.fixedFrames(home)
        let settings = try XCTUnwrap(before["settings"], "Home has no Settings button (\(context))")

        // In: where Home's Settings was, Settings' first screen.
        app.buttons["settings"].tap()
        let back = app.buttons["backToTalking"]
        XCTAssertTrue(back.waitForExistence(timeout: 10), "Settings did not open from Home (\(context))")
        XCTAssertTrue(app.buttons["familySetup"].waitForExistence(timeout: 10), "Settings opened without Family Setup (\(context))")
        let cover = try Self.onCover(screenControls(in: app))
        attachCapture(app, name: "settings-opened-\(context)".replacingOccurrences(of: ", ", with: "-"))
        let landing = nearestControls(to: settings.center, among: cover)
        XCTAssertEqual(landing.byCentre, ["familySetup"], "Home's Settings at \(settings) is nearest \(landing.byCentre) by centre in Settings (\(context)): \(cover)")
        XCTAssertEqual(landing.byEdge, ["familySetup"], "Home's Settings at \(settings) is nearest \(landing.byEdge) by edge in Settings (\(context)): \(cover)")

        // Further in, for the chains: Family Setup, then the first step of
        // Set Up Step by Step where its row shows without scrolling, then
        // the guide its link opens where the link shows. Each is read once
        // the screen before it has gone.
        open("familySetup", leaving: "familySetup", in: app, context: context)
        let familySetup = try Self.onCover(screenControls(in: app))
        attachCapture(app, name: "family-setup-opened-\(context)".replacingOccurrences(of: ", ", with: "-"))
        var firstStep: [ScreenControl]?
        var firstStepGuide: [ScreenControl]?
        if Self.onScreen(familySetup, in: window).contains(where: { $0.name == SettingsChains.guidedSetupRow }) {
            open("guidedSetup", leaving: "guidedSetup", in: app, context: context)
            let step = try Self.onCover(screenControls(in: app))
            firstStep = step
            attachCapture(app, name: "first-step-opened-\(context)".replacingOccurrences(of: ", ", with: "-"))
            if Self.onScreen(step, in: window).contains(where: { $0.name == SettingsChains.learnAboutEachWay }) {
                open(SettingsChains.learnAboutEachWay, leaving: SettingsChains.learnAboutEachWay, in: app, context: context)
                firstStepGuide = try Self.onCover(screenControls(in: app))
                attachCapture(app, name: "first-step-guide-opened-\(context)".replacingOccurrences(of: ", ", with: "-"))
            }
        }
        checkChains(
            home: home, screens: SettingsChains.Screens(
                root: Self.named(Self.onScreen(cover, in: window)),
                familySetup: Self.named(Self.onScreen(familySetup, in: window)),
                firstStep: firstStep.map { Self.named(Self.onScreen($0, in: window)) },
                firstStepGuide: firstStepGuide.map { Self.named(Self.onScreen($0, in: window)) }
            ),
            window: window, context: context
        )

        // Out: where Back to Talking was, Home.
        let way = back.frame
        back.tap()
        XCTAssertTrue(app.buttons["Yes"].waitForExistence(timeout: 10), "Home did not come back (\(context))")
        let closed = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: back)
        XCTAssertEqual(XCTWaiter.wait(for: [closed], timeout: 10), .completed, "Settings did not close (\(context))")
        let after = try screenControls(in: app)
        attachCapture(app, name: "settings-closed-\(context)".replacingOccurrences(of: ", ", with: "-"))
        let returning = nearestControls(to: way.center, among: after)
        XCTAssertEqual(returning.byCentre, ["Emergency"], "Back to Talking at \(way) is nearest \(returning.byCentre) by centre on Home (\(context))")
        XCTAssertEqual(returning.byEdge, ["Emergency"], "Back to Talking at \(way) is nearest \(returning.byEdge) by edge on Home (\(context))")

        // Opening and closing Settings moves nothing on Home.
        for (name, frame) in Self.fixedFrames(after) {
            guard let original = before[name] else {
                XCTFail("\(name) appeared on Home after Settings closed (\(context))")
                continue
            }
            for (edge, actual, expected) in [
                ("left", frame.minX, original.minX),
                ("top", frame.minY, original.minY),
                ("right", frame.maxX, original.maxX),
                ("bottom", frame.maxY, original.maxY),
            ] {
                XCTAssertEqual(actual, expected, accuracy: 1, "\(name)'s \(edge) edge moved after Settings (\(context))")
            }
        }
        XCTAssertEqual(Set(Self.fixedFrames(after).keys), Set(before.keys), "Home's fixed controls changed after Settings (\(context))")
    }

    // MARK: Chains

    /// Opens a Settings screen with the control named `name`, and waits
    /// until `leaving`, a control of the screen it leaves, has gone, so the
    /// next screen is read where it rests rather than as it slides in.
    @MainActor
    private func open(_ name: String, leaving: String, in app: XCUIApplication, context: String) {
        app.buttons[name].tap()
        let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: app.buttons[leaving])
        XCTAssertEqual(XCTWaiter.wait(for: [gone], timeout: 10), .completed, "\(name) did not open its screen (\(context))")
    }

    /// Follows every chain from Home's Settings and from each control of
    /// Settings' first screens (`SettingsChains`), and attaches what it
    /// finds. Fails on a chain that saves an answer, on a hazard of any
    /// other kind than the one known, on a control the chains do not know,
    /// and, strictly, once the known kind is no longer found.
    @MainActor
    private func checkChains(home: [ScreenControl], screens: SettingsChains.Screens, window: CGRect, context: String) {
        let homeControls = Self.onScreen(home, in: window)
        guard let frames = HomeChains.frames(from: Self.named(homeControls), categories: Self.everydayCategories) else {
            XCTFail("Home is missing a control the chains need (\(context)): \(homeControls)")
            return
        }
        // Launched fresh: nothing spoken, the alarm quiet, and the category
        // showing the one Home shows selected (none while Emergency shows).
        let showing = homeControls.first { $0.isSelected && Self.everydayCategories.contains($0.name) }
        let state = HomeChains.State(
            hasSpoken: false, showing: showing.flatMap { Self.everydayCategories.firstIndex(of: $0.name) }, sounding: false
        )
        let atRest = HomeChains.name(of: state, categories: Self.everydayCategories)
        let settings = SettingsChains.map(screens, closingOnto: atRest)
        XCTAssertEqual(settings.unknown, [], "the chains do not know what these controls do (\(context))")
        let map = HomeChains.map(frames).merging(settings.map)
        let hazards = map.hazards(from: SettingsChains.starts(in: map, home: atRest))
        func findings(_ kind: SettingsChains.Kind) -> [String] {
            ChainFinding.findings(in: hazards.filter { SettingsChains.kind(of: $0) == kind }).map(\.description)
        }
        let report = XCTAttachment(string: SettingsChains.Kind.allCases.map { kind in
            ([kind.rawValue] + findings(kind)).joined(separator: "\n")
        }.joined(separator: "\n\n"))
        report.name = "settings-chains-\(context)".replacingOccurrences(of: ", ", with: "-")
        report.lifetime = .keepAlways
        add(report)

        XCTAssertEqual(findings(.unexpected), [], "a chain through Settings meets a new hazard (\(context))")
        // Closed by Learn About Each Way, where Set Up Step by Step's row
        // was (docs/DECISIONS.md, "One chain engine for dwell safety").
        XCTAssertEqual(findings(.savesAnAnswer), [], "a held look saves an answer in Set Up Step by Step (\(context))")
        let strict = XCTExpectedFailure.Options()
        strict.isStrict = true
        XCTExpectFailure(
            "docs/DECISIONS.md, \"One chain engine for dwell safety\": Settings closes under the look",
            options: strict
        ) {
            XCTAssertEqual(findings(.closesUnderTheLook), [], "Settings closes under the look (\(context))")
        }
    }

    // MARK: Reading the screen

    private static func fixedFrames(_ controls: [ScreenControl]) -> [String: CGRect] {
        Dictionary(
            controls.filter { fixedOnHome.contains($0.name) }.map { ($0.name, $0.frame) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    /// The Settings cover's controls: Home stays in the accessibility tree
    /// beneath it.
    private static func onCover(_ controls: [ScreenControl]) -> [ScreenControl] {
        controls.filter { !fixedOnHome.contains($0.name) && $0.name != "phraseTile" }
    }

    /// The controls in the window: a screen as it first shows, before
    /// anything scrolls.
    private static func onScreen(_ controls: [ScreenControl], in window: CGRect) -> [ScreenControl] {
        controls.filter { $0.frame.intersects(window) }
    }

    private static func named(_ controls: [ScreenControl]) -> [(name: String, frame: CGRect)] {
        controls.map { ($0.name, $0.frame) }
    }
}

private extension CGRect {
    var center: CGPoint { CGPoint(x: midX, y: midY) }
}
