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
/// - Closing: Back to Talking lies over Home's Phrases, and the spot where
///   it was is nearest Phrases, which does nothing while the phrases show
///   (docs/DECISIONS.md, "Typing on Home"). Before typing came to Home, it
///   was nearest Emergency, and before that Again, which speaks.
/// - Chains: on the way in, it also reads Family Setup and, where its row
///   shows, Set Up Step by Step's first step, the guide that step's Learn
///   About Each Way opens, and the second step, which the first step's
///   Next opens, and has the chain engine follow every chain of held
///   activations from Home's Settings and from each control of those
///   screens, out to Home and back (`SettingsChains`, `ChainEngine`). No
///   chain closes Settings under the look: the first screen's Family Setup
///   row sits where Home's frames say it is safe, Set Up Step by Step takes
///   its place on Family Setup, Learn About Each Way takes that place on
///   the first step, and the guide's one control, Done, lies in Back to
///   Talking's frame (docs/DECISIONS.md, "Settings' first row, placed from
///   Home's frames", "The first step's own rows"). No chain saves an
///   answer: the first step's answers start below every place a look can
///   be resting on the way in, Next only moves on, and the second step's
///   choices lie where a look resting on Next meets Next again
///   (`SetupChoicesPlace`; docs/DECISIONS.md, "The late-stage profile").
///   With a check-in due (`--check-in-due`), it also reads the first step
///   the card's Go Through Setup Again opens, with Learn About Each Way in
///   that button's place, and the one Set Up Step by Step opens once the
///   card is answered, with the answers clear of where the card's rows
///   were, and follows chains through the card's rows into both. Any
///   hazard fails, a check-in answered unasked among them.
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
        "Yes", "No", "Emergency", "Again", "getAttention", "phrases", "type", "settings",
        "Basics", "Needs", "Conversation", "Feelings",
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

    /// With a check-in due, where its card shows without scrolling: on
    /// CI's iPhone and iPad at the default size and on the iPad at the
    /// largest. On the phone at the largest size the card lies below the
    /// first screenful, which the chains do not read (docs/HANDOFF.md,
    /// *Known gaps*).
    @MainActor
    func testOpeningSettingsWithACheckInDueAtDefaultText() throws {
        try checkTheWayInAndOut(textSize: .large, orientation: .portrait, checkInDue: true)
    }

    @MainActor
    func testOpeningSettingsWithACheckInDueAtTheLargestText() throws {
        try checkTheWayInAndOut(textSize: .ax5, orientation: .portrait, checkInDue: true)
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
    private func checkTheWayInAndOut(textSize: UITestTextSize, orientation: UIDeviceOrientation, checkInDue: Bool = false) throws {
        // Settings' full idle limit: reading and capturing three screens can
        // take longer than the 3-second test limit, and a reset part way
        // would put Settings back on its first screen (as in `SettingsTests`).
        let app = launchedApp(
            textSize: textSize, orientation: orientation, arguments: checkInDue ? ["--check-in-due"] : [], shortTimeouts: false
        )
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
            + (checkInDue ? ", check-in due" : "")

        assertReachable("Settings", in: app, context: context)
        let home = try screenControls(in: app)
        let before = Self.fixedFrames(home)
        let settings = try XCTUnwrap(before["settings"], "Home has no Settings button (\(context))")
        let phrases = try XCTUnwrap(before["phrases"], "Home has no Phrases (\(context))")

        // In: where Home's Settings was, Settings' first screen.
        app.buttons["settings"].tap()
        let back = app.buttons["backToTalking"]
        XCTAssertTrue(back.waitForExistence(timeout: 10), "Settings did not open from Home (\(context))")
        XCTAssertTrue(app.buttons["familySetup"].waitForExistence(timeout: 10), "Settings opened without Family Setup (\(context))")
        let cover = try Self.onCover(screenControls(in: app))
        attachCapture(app, name: "settings-opened-\(context)".replacingOccurrences(of: ", ", with: "-"))
        // Back to Talking over Phrases, centred and as tall: Phrases' frame
        // on a phone, a column of it on wider windows (`HomeLayout.backToTalking`).
        let way = back.frame
        XCTAssertTrue(
            phrases.insetBy(dx: -1, dy: -1).contains(way) && abs(way.midX - phrases.midX) <= 1 && abs(way.height - phrases.height) <= 1,
            "Back to Talking at \(way) is not over Phrases at \(phrases) (\(context))"
        )
        let landing = nearestControls(to: settings.center, among: cover)
        XCTAssertEqual(landing.byCentre, ["familySetup"], "Home's Settings at \(settings) is nearest \(landing.byCentre) by centre in Settings (\(context)): \(cover)")
        XCTAssertEqual(landing.byEdge, ["familySetup"], "Home's Settings at \(settings) is nearest \(landing.byEdge) by edge in Settings (\(context)): \(cover)")

        // Further in, for the chains: Family Setup, then the first step of
        // Set Up Step by Step where its row shows without scrolling. Each
        // is read once the screen before it has gone.
        open("familySetup", leaving: "familySetup", in: app, context: context)
        let familySetup = try Self.onCover(screenControls(in: app))
        attachCapture(app, name: "family-setup-opened-\(context)".replacingOccurrences(of: ", ", with: "-"))
        var firstStep: [ScreenControl]?
        var eachWay: [ScreenControl]?
        var secondStep: [ScreenControl]?
        if Self.onScreen(familySetup, in: window).contains(where: { $0.name == SettingsChains.guidedSetupRow }) {
            open("guidedSetup", leaving: "guidedSetup", in: app, context: context)
            let step = try Self.onCover(screenControls(in: app))
            firstStep = step
            attachCapture(app, name: "first-step-opened-\(context)".replacingOccurrences(of: ", ", with: "-"))
            if Self.onScreen(step, in: window).contains(where: { $0.name == SettingsChains.learnAboutEachWay }) {
                eachWay = try readTheGuide(over: step, in: app, backToTalking: way, window: window, context: context)
            }
            // The second step, through Next, in the bar at the foot of
            // every step, read once the first step has gone.
            open(SettingsChains.firstStepNext, leaving: SettingsChains.learnAboutEachWay, in: app, context: context)
            XCTAssertTrue(
                app.navigationBars[SettingsChains.secondStep].waitForExistence(timeout: 10),
                "Next did not open the second step (\(context))"
            )
            secondStep = try Self.onCover(screenControls(in: app))
            attachCapture(app, name: "second-step-opened-\(context)".replacingOccurrences(of: ", ", with: "-"))
        }
        var fromCheckIn: [ScreenControl]?
        var afterCheckIn: [ScreenControl]?
        if checkInDue {
            XCTAssertTrue(
                familySetup.contains { $0.name == SettingsChains.checkInGoThrough }, "Family Setup shows no check-in card (\(context))"
            )
            if let goThrough = Self.onScreen(familySetup, in: window).first(where: { $0.name == SettingsChains.checkInGoThrough }),
               secondStep != nil {
                (fromCheckIn, afterCheckIn) = try readTheCheckIn(
                    goThrough: goThrough.frame, familySetup: familySetup, in: app, window: window, context: context
                )
            }
        }
        checkChains(
            home: home, screens: SettingsChains.Screens(
                root: Self.named(Self.onScreen(cover, in: window)),
                familySetup: Self.named(Self.onScreen(familySetup, in: window)),
                firstStep: firstStep.map { Self.named(Self.onScreen($0, in: window)) },
                eachWay: eachWay.map { Self.named(Self.onScreen($0, in: window)) },
                secondStep: secondStep.map { Self.named(Self.onScreen($0, in: window)) },
                firstStepFromCheckIn: fromCheckIn.map { Self.named(Self.onScreen($0, in: window)) },
                firstStepAfterCheckIn: afterCheckIn.map { Self.named(Self.onScreen($0, in: window)) }
            ),
            window: window, context: context
        )

        // Out: where Back to Talking was, Home.
        back.tap()
        XCTAssertTrue(app.buttons["Yes"].waitForExistence(timeout: 10), "Home did not come back (\(context))")
        let closed = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: back)
        XCTAssertEqual(XCTWaiter.wait(for: [closed], timeout: 10), .completed, "Settings did not close (\(context))")
        let after = try screenControls(in: app)
        attachCapture(app, name: "settings-closed-\(context)".replacingOccurrences(of: ", ", with: "-"))
        let returning = nearestControls(to: way.center, among: after)
        XCTAssertEqual(returning.byCentre, ["phrases"], "Back to Talking at \(way) is nearest \(returning.byCentre) by centre on Home (\(context))")
        XCTAssertEqual(returning.byEdge, ["phrases"], "Back to Talking at \(way) is nearest \(returning.byEdge) by edge on Home (\(context))")

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

    /// Opens the guide with the first step's Learn About Each Way, reads its
    /// controls, checks that Done lies in Back to Talking's frame, and
    /// closes it with Done. The step stays in the accessibility tree beneath
    /// the guide, as Home does beneath Settings, so the step's controls are
    /// left out.
    @MainActor
    private func readTheGuide(
        over step: [ScreenControl], in app: XCUIApplication, backToTalking: CGRect, window: CGRect, context: String
    ) throws -> [ScreenControl] {
        app.buttons[SettingsChains.learnAboutEachWay].tap()
        let done = app.buttons[SettingsChains.eachWayDone]
        XCTAssertTrue(done.waitForExistence(timeout: 10), "Learn About Each Way did not open the guide (\(context))")
        let stepNames = Set(step.map(\.name))
        let guide = try Self.onCover(screenControls(in: app)).filter { !stepNames.contains($0.name) }
        attachCapture(app, name: "each-way-opened-\(context)".replacingOccurrences(of: ", ", with: "-"))
        let frame = done.frame
        for (edge, actual, expected) in [
            ("left", frame.minX, backToTalking.minX),
            ("top", frame.minY, backToTalking.minY),
            ("right", frame.maxX, backToTalking.maxX),
            ("bottom", frame.maxY, backToTalking.maxY),
        ] {
            XCTAssertEqual(actual, expected, accuracy: 1, "Done's \(edge) edge is not Back to Talking's (\(context))")
        }
        done.tap()
        let closed = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: done)
        XCTAssertEqual(XCTWaiter.wait(for: [closed], timeout: 10), .completed, "Done did not close the guide (\(context))")
        XCTAssertTrue(
            app.buttons[SettingsChains.learnAboutEachWay].waitForExistence(timeout: 10), "Done did not return to the first step (\(context))"
        )
        return guide
    }

    /// From the second step, back to Family Setup with the check-in still
    /// due; then the first step its card's Go Through Setup Again opens,
    /// read where it rests, with Learn About Each Way in the button's place;
    /// then back to Family Setup, now with the card answered, read again to
    /// check that only the card's rows went and nothing else moved; then
    /// the first step Set Up Step by Step opens from there, read where it
    /// rests, with its answers clear of where the card's rows were. Returns
    /// the two first steps.
    @MainActor
    private func readTheCheckIn(
        goThrough: CGRect, familySetup: [ScreenControl], in app: XCUIApplication, window: CGRect, context: String
    ) throws -> ([ScreenControl], [ScreenControl]) {
        open(SettingsChains.back, leaving: "restBoardEveryCategory", in: app, context: context)
        open(SettingsChains.back, leaving: SettingsChains.learnAboutEachWay, in: app, context: context)
        XCTAssertTrue(
            app.buttons[SettingsChains.checkInGoThrough].waitForExistence(timeout: 10), "Back did not return to Family Setup (\(context))"
        )

        // The card's rows go as soon as Go Through answers the check-in,
        // before the step has slid in, so wait for Set Up Step by Step.
        open(SettingsChains.checkInGoThrough, leaving: SettingsChains.guidedSetupRow, in: app, context: context)
        let fromCheckIn = try Self.onCover(screenControls(in: app))
        attachCapture(app, name: "first-step-from-the-check-in-\(context)".replacingOccurrences(of: ", ", with: "-"))
        let link = fromCheckIn.first { $0.name == SettingsChains.learnAboutEachWay }?.frame
        XCTAssertNotNil(link, "the first step from the check-in has no Learn About Each Way (\(context))")
        if let link {
            XCTAssertEqual(link.minX, goThrough.minX, accuracy: 1, "Learn About Each Way's leading edge is not Go Through's (\(context))")
            XCTAssertEqual(link.minY, goThrough.minY, accuracy: 1, "Learn About Each Way's top is not Go Through's (\(context))")
            XCTAssertEqual(link.width, goThrough.width, accuracy: 1, "Learn About Each Way is not Go Through's width (\(context))")
            XCTAssertGreaterThanOrEqual(link.height, goThrough.height - 1, "Learn About Each Way is shorter than Go Through (\(context))")
        }

        open(SettingsChains.back, leaving: SettingsChains.learnAboutEachWay, in: app, context: context)
        XCTAssertTrue(
            app.staticTexts["Family Setup will ask again in about three months."].waitForExistence(timeout: 10),
            "Family Setup does not say the check-in was answered (\(context))"
        )
        // Read where it rests: Set Up Step by Step back in its place, not
        // part way through sliding in.
        if let guided = familySetup.first(where: { $0.name == SettingsChains.guidedSetupRow })?.frame {
            let settled = NSPredicate { _, _ in
                MainActor.assumeIsolated {
                    let frame = app.buttons[SettingsChains.guidedSetupRow].frame
                    return abs(frame.minX - guided.minX) < 1 && abs(frame.minY - guided.minY) < 1
                }
            }
            XCTAssertEqual(
                XCTWaiter.wait(for: [expectation(for: settled, evaluatedWith: nil)], timeout: 10), .completed,
                "Set Up Step by Step is not back where it was (\(context))"
            )
        }
        let answered = try Self.onCover(screenControls(in: app))
        attachCapture(app, name: "family-setup-after-the-check-in-\(context)".replacingOccurrences(of: ", ", with: "-"))
        let kept = familySetup.filter { !SettingsChains.checkInRows.contains($0.name) }
        XCTAssertEqual(answered.map(\.name).sorted(), kept.map(\.name).sorted(), "Family Setup's rows changed after the check-in (\(context))")
        for control in answered {
            guard let before = kept.first(where: { $0.name == control.name })?.frame else { continue }
            XCTAssertEqual(control.frame.minY, before.minY, accuracy: 1, "\(control.name) moved after the check-in (\(context))")
            XCTAssertEqual(control.frame.minX, before.minX, accuracy: 1, "\(control.name) moved after the check-in (\(context))")
        }

        open(SettingsChains.guidedSetupRow, leaving: SettingsChains.guidedSetupRow, in: app, context: context)
        let afterCheckIn = try Self.onCover(screenControls(in: app))
        attachCapture(app, name: "first-step-after-the-check-in-\(context)".replacingOccurrences(of: ", ", with: "-"))
        let rows = familySetup.filter { SettingsChains.checkInRows.contains($0.name) }.map(\.frame).reduce(CGRect.null) { $0.union($1) }
        if let touch = afterCheckIn.first(where: { $0.name == "Touch" }) {
            XCTAssertGreaterThan(touch.frame.minY, rows.maxY, "the first answer starts where the card's rows were (\(context))")
        }
        return (fromCheckIn, afterCheckIn)
    }

    /// Follows every chain from Home's Settings and from each control of
    /// Settings' first screens, the guide's cover and the second step
    /// (`SettingsChains`), and attaches what it finds. Fails on any hazard, of the two kinds
    /// the chains sort or any other, and on a control the chains do not
    /// know.
    @MainActor
    private func checkChains(
        home: [ScreenControl], screens: SettingsChains.Screens, window: CGRect, context: String
    ) {
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
        XCTAssertEqual(findings(.closesUnderTheLook), [], "a held look closes Settings under the look (\(context))")
        XCTAssertEqual(findings(.savesAnAnswer), [], "a held look saves an answer in Set Up Step by Step (\(context))")
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
