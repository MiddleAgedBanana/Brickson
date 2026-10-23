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
///
/// "Nearest" is scored two ways, because how Snap to Item picks a target is
/// a device check (docs/HANDOFF.md, *Checks that need a real device*): by
/// the nearest centre and by the nearest edge, with ties counted. Both must
/// name the same harmless control. This reads the frames the app hands to
/// assistive technologies on the simulator CI runs; it is not evidence of
/// what a person's gaze does on a device.
final class SettingsOnHomeTests: XCTestCase {
    /// Home's controls that keep their place in every state, by the name
    /// `controls(in:)` gives them. The category names are copied from
    /// Brickson/Resources/StarterPhrases.json, as in `HomeLayoutTests`.
    private static let fixedOnHome = ["Yes", "No", "Again", "Emergency", "settings", "Basics", "Needs", "Conversation", "Feelings"]
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
        let app = launchedApp(textSize: textSize, orientation: orientation)
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
        let home = try controls(in: app)
        let before = Self.fixedFrames(home)
        let settings = try XCTUnwrap(before["settings"], "Home has no Settings button (\(context))")

        // In: where Home's Settings was, Settings' first screen.
        app.buttons["settings"].tap()
        let back = app.buttons["backToTalking"]
        XCTAssertTrue(back.waitForExistence(timeout: 10), "Settings did not open from Home (\(context))")
        XCTAssertTrue(app.buttons["familySetup"].waitForExistence(timeout: 10), "Settings opened without Family Setup (\(context))")
        let cover = try controls(in: app).filter { !Self.fixedOnHome.contains($0.name) && $0.name != "phraseTile" }
        attachCapture(app, name: "settings-opened-\(context)".replacingOccurrences(of: ", ", with: "-"))
        let landing = Self.nearest(to: settings.center, among: cover)
        XCTAssertEqual(landing.byCentre, ["familySetup"], "Home's Settings at \(settings) is nearest \(landing.byCentre) by centre in Settings (\(context)): \(cover)")
        XCTAssertEqual(landing.byEdge, ["familySetup"], "Home's Settings at \(settings) is nearest \(landing.byEdge) by edge in Settings (\(context)): \(cover)")

        // Out: where Back to Talking was, Home.
        let way = back.frame
        back.tap()
        XCTAssertTrue(app.buttons["Yes"].waitForExistence(timeout: 10), "Home did not come back (\(context))")
        let closed = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: back)
        XCTAssertEqual(XCTWaiter.wait(for: [closed], timeout: 10), .completed, "Settings did not close (\(context))")
        let after = try controls(in: app)
        attachCapture(app, name: "settings-closed-\(context)".replacingOccurrences(of: ", ", with: "-"))
        let returning = Self.nearest(to: way.center, among: after)
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

    // MARK: Reading the screen

    /// A button on screen, named by its identifier where it has one and by
    /// its label otherwise.
    private struct Control: CustomStringConvertible {
        let name: String
        let frame: CGRect

        var description: String { "\(name) \(frame)" }
    }

    /// Every button on screen, from one accessibility snapshot, so the
    /// frames all come from one moment and one query.
    @MainActor
    private func controls(in app: XCUIApplication) throws -> [Control] {
        var pending: [any XCUIElementSnapshot] = [try app.snapshot()]
        var found: [Control] = []
        while let element = pending.popLast() {
            if element.elementType == .button {
                let name = element.identifier.isEmpty ? element.label : element.identifier
                found.append(Control(name: name, frame: element.frame))
                continue
            }
            pending.append(contentsOf: element.children)
        }
        return found
    }

    private static func fixedFrames(_ controls: [Control]) -> [String: CGRect] {
        Dictionary(
            controls.filter { fixedOnHome.contains($0.name) }.map { ($0.name, $0.frame) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    /// The controls nearest `point` by the distance to their centres and
    /// by the distance to their nearest edge (zero inside one), each with
    /// every control within half a point of the nearest, so a tie is never
    /// hidden.
    private static func nearest(to point: CGPoint, among controls: [Control]) -> (byCentre: Set<String>, byEdge: Set<String>) {
        guard !controls.isEmpty else { return ([], []) }
        func centreDistance(_ frame: CGRect) -> CGFloat {
            hypot(point.x - frame.midX, point.y - frame.midY)
        }
        func edgeDistance(_ frame: CGRect) -> CGFloat {
            let dx = max(frame.minX - point.x, 0, point.x - frame.maxX)
            let dy = max(frame.minY - point.y, 0, point.y - frame.maxY)
            return hypot(dx, dy)
        }
        let closestCentre = controls.map { centreDistance($0.frame) }.min() ?? 0
        let closestEdge = controls.map { edgeDistance($0.frame) }.min() ?? 0
        return (
            Set(controls.filter { centreDistance($0.frame) - closestCentre < 0.5 }.map(\.name)),
            Set(controls.filter { edgeDistance($0.frame) - closestEdge < 0.5 }.map(\.name))
        )
    }
}

private extension CGRect {
    var center: CGPoint { CGPoint(x: midX, y: midY) }
}
