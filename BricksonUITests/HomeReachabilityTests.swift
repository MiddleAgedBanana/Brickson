import UIKit
import XCTest

/// Invariants 2 and 10: Yes, No, Emergency and Get Attention are one
/// activation away in every Home state, and Again, the way to repeat, and
/// Settings, the family's way in, stay in reach too. The alarm's own
/// states, with Stop, are `GetAttentionOnHomeTests`. Each
/// test walks Home through its states (just opened, the emergency phrases
/// showing, a phrase just spoken) at one text size and orientation, and
/// checks every one of those controls with `assertReachable`: it exists, is
/// hittable, lies wholly inside the window, and is at least 44 points.
///
/// scripts/test.sh runs the UI tests on an iPad and an iPhone, so each test
/// runs on both. The iPhone keeps portrait (docs/DECISIONS.md,
/// "Orientations"); its landscape tests check that turning the phone
/// changes nothing that matters.
///
/// Every state is also captured (`attachCapture`) for layout work. None of
/// this is evidence about Eye Tracking, Switch Control or touch on a real
/// device (docs/HANDOFF.md, "Checks that need a real device").
final class HomeReachabilityTests: XCTestCase {
    /// The controls that must stay in reach in every Home state.
    private static let primaryControls = ["Yes", "No", "Emergency", "Get Attention", "Again", "Settings"]

    @MainActor
    func testEveryHomeStateAtDefaultTextInPortrait() {
        checkEveryHomeState(textSize: .large, orientation: .portrait)
    }

    @MainActor
    func testEveryHomeStateAtDefaultTextInLandscape() {
        checkEveryHomeState(textSize: .large, orientation: .landscapeLeft)
    }

    @MainActor
    func testEveryHomeStateAtTheLargestTextInPortrait() {
        checkEveryHomeState(textSize: .ax5, orientation: .portrait)
    }

    @MainActor
    func testEveryHomeStateAtTheLargestTextInLandscape() {
        checkEveryHomeState(textSize: .ax5, orientation: .landscapeLeft)
    }

    @MainActor
    private func checkEveryHomeState(textSize: UITestTextSize, orientation: UIDeviceOrientation) {
        continueAfterFailure = false
        let app = launchedApp(textSize: textSize, orientation: orientation)
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        if orientation.isLandscape {
            if isPad {
                // Otherwise the landscape tests would quietly check portrait.
                XCTAssertGreaterThan(app.frame.width, app.frame.height, "the iPad did not turn to landscape")
            } else {
                // The iPhone keeps portrait (docs/DECISIONS.md, "Orientations").
                XCTAssertGreaterThan(app.frame.height, app.frame.width, "the iPhone turned to landscape")
            }
        }
        // Report every control that fails, not only the first.
        continueAfterFailure = true
        let configuration = "\(textSize.name), \(orientation.isLandscape ? "landscape" : "portrait"), \(isPad ? "iPad" : "iPhone")"

        check(app, state: "just opened", configuration: configuration)
        let framesAtLaunch = Dictionary(uniqueKeysWithValues: Self.primaryControls.map {
            ($0, app.buttons[$0].firstMatch.frame)
        })

        app.buttons["Emergency"].tap()
        XCTAssertTrue(
            app.buttons.matching(NSPredicate(format: "label == %@", "I need help now.")).firstMatch
                .waitForExistence(timeout: 10),
            "Emergency did not show the emergency phrases (\(configuration))"
        )
        check(app, state: "emergency phrases showing", configuration: configuration, framesAtLaunch: framesAtLaunch)

        // Any phrase will do; the first tile of the emergency phrases is
        // the one most surely on screen.
        app.buttons.matching(identifier: "phraseTile").firstMatch.tap()
        let againTurnsOn = expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: app.buttons["Again"])
        XCTAssertEqual(
            XCTWaiter.wait(for: [againTurnsOn], timeout: 15), .completed,
            "Again was still off 15 s after a phrase was chosen (\(configuration))"
        )
        check(app, state: "a phrase just spoken", configuration: configuration, framesAtLaunch: framesAtLaunch)
    }

    @MainActor
    private func check(
        _ app: XCUIApplication,
        state: String,
        configuration: String,
        framesAtLaunch: [String: CGRect]? = nil
    ) {
        let context = "\(state); \(configuration)"
        for label in Self.primaryControls {
            assertReachable(label, in: app, context: context)
            if let original = framesAtLaunch?[label] {
                // Reachability alone permits controls to move under a
                // resting pointer. State changes must preserve every edge,
                // allowing only one point for layout rounding (invariant 10).
                let frame = app.buttons[label].firstMatch.frame
                for (edge, actual, expected) in [
                    ("left", frame.minX, original.minX),
                    ("top", frame.minY, original.minY),
                    ("right", frame.maxX, original.maxX),
                    ("bottom", frame.maxY, original.maxY),
                ] {
                    XCTAssertEqual(
                        actual, expected, accuracy: 1,
                        "\(label)'s \(edge) edge moved (\(context)): launch \(original), now \(frame)"
                    )
                }
            }
        }
        attachCapture(app, name: "home-\(state)-\(configuration)".replacingOccurrences(of: ", ", with: "-"))
    }
}
