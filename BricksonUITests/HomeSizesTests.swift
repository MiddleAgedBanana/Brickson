import UIKit
import XCTest

/// Home's sizes and Family Setup's answer in the running app
/// (docs/DECISIONS.md, "Sizes that follow how the screen is reached").
/// A person's launch has the largest sizes the window holds until anyone
/// answers, and touch's once Touch alone is chosen and Settings closes;
/// the first step says what the answers do. At those larger sizes Home
/// passes Apple's accessibility audit and draws its words whole. The
/// other UI tests ask for touch's sizes (`launchedApp`).
///
/// Expected sizes come from the layout engine's table for the windows CI
/// runs (`ProfileChoiceTests.eyeTable`): Eye Tracking's on an iPad in
/// portrait at every text size, touch's on a phone, told apart here by the
/// window's width alone, as the engine does (a phone is under 600 points
/// wide). Touch's are the frames a launch at touch's sizes draws in the
/// same window, so a head tracking or Switch Control size, as tall as
/// touch's on some windows, does not pass for them. It says nothing about
/// gaze comfort, which needs a device (docs/HANDOFF.md).
///
/// The flow walks Settings to Family Setup's first step, so it launches
/// without the short idle limits, which could reset Settings part way.
final class HomeSizesTests: XCTestCase {
    /// Eye Tracking's floors (`HomeLayout.Profile`): quick controls and
    /// phrase tiles.
    private static let eyeQuickFloor: CGFloat = 109
    private static let eyeTileFloor: CGFloat = 136
    /// What the first step says about sizes where they follow the answer.
    private static let sizesSentence =
        "Home's buttons take the size the answers need, as large as this screen has room for, and are largest until something is chosen. The new size shows when Settings closes."
    /// The quick controls, whose words every window must draw whole.
    private static let quickControls = ["Yes", "No", "Emergency", "Get Attention", "Again"]
    /// The controls whose words are read too at the larger sizes: Phrases
    /// and Type, and the starter library's everyday categories (Emergency
    /// is a quick control).
    private static let otherWordedControls = ["Phrases", "Type", "Basics", "Needs", "Conversation", "Feelings"]

    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    @MainActor
    private func quickFrames(in app: XCUIApplication) -> [String: CGRect] {
        Dictionary(uniqueKeysWithValues: Self.quickControls.map { ($0, app.buttons[$0].frame) })
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
    /// answer, once it shows. Settings' first screen, Family Setup and the
    /// first step each pass Apple's accessibility audit over Home as it is,
    /// each read once the screen before it has gone, so it is audited where
    /// it rests (`SettingsOnHomeTests` reads them the same way).
    @MainActor
    private func openFirstStep(_ app: XCUIApplication, context: String) throws -> XCUIElement {
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.buttons["backToTalking"].waitForExistence(timeout: 10), "Settings did not open (\(context))")
        let familySetup = app.buttons["familySetup"].firstMatch
        XCTAssertTrue(familySetup.waitForExistence(timeout: 10), "Settings shows no Family Setup (\(context))")
        try assertPassesAccessibilityAudit(app, context: "Settings, \(context)")
        open(familySetup, waitingFor: "Family Setup", in: app, context: context)
        let guided = app.buttons["guidedSetup"].firstMatch
        XCTAssertTrue(guided.waitForExistence(timeout: 10), "Family Setup shows no Set Up Step by Step (\(context))")
        try assertPassesAccessibilityAudit(app, context: "Family Setup, \(context)")
        open(guided, waitingFor: "Step 1 of 5", in: app, context: context)
        let touch = app.buttons["Touch"]
        XCTAssertTrue(touch.waitForExistence(timeout: 10), "the first step shows no Touch (\(context))")
        attachCapture(app, name: "the first step, \(context)")
        try assertPassesAccessibilityAudit(app, context: "Step 1 of 5, \(context)")
        return touch
    }

    /// Chooses `row` and waits for the screen titled `title`, and for `row`
    /// to have gone with the screen it was on.
    @MainActor
    private func open(_ row: XCUIElement, waitingFor title: String, in app: XCUIApplication, context: String) {
        row.tap()
        XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 10), "\(title) did not open (\(context))")
        let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: row)
        XCTAssertEqual(XCTWaiter.wait(for: [gone], timeout: 10), .completed, "\(title) did not finish opening (\(context))")
    }

    /// Whether `window` holds Eye Tracking's sizes at every text size, by
    /// its shape alone: an iPad in portrait (`ProfileChoiceTests.eyeTable`).
    private static func holdsEyeTracking(_ window: CGRect) -> Bool {
        window.width >= 600 && window.height > window.width
    }

    /// A person's launch before anyone answers, at the default and the
    /// largest text size, light and dark. Fails if, on an iPad in portrait,
    /// a quick control is smaller than Eye Tracking's floors, so the checks
    /// below would not be of the larger sizes; if a quick control's words,
    /// and at the larger sizes those of Phrases, Type and the everyday
    /// categories too, are not each drawn whole (`RenderedWords`, without
    /// the expected words or language correction); or if Apple's
    /// accessibility audit finds anything. On a phone Home has touch's
    /// sizes, whose other words this pull request does not change.
    @MainActor
    func testTheLargerSizesPassTheAuditAndDrawTheirWordsWhole() async throws {
        for textSize in [UITestTextSize.large, .ax5] {
            for appearance in [UITestAppearance.light, .dark] {
                let app = launchedApp(textSize: textSize, appearance: appearance, sizes: .asShipped)
                let window = app.windows.firstMatch.frame
                let holdsEyeTracking = Self.holdsEyeTracking(window)
                let context = "as shipped, \(textSize.name), \(appearance.rawValue), window \(window.size)"
                attachCapture(app, name: context)
                if holdsEyeTracking {
                    for (name, frame) in quickFrames(in: app) {
                        XCTAssertGreaterThanOrEqual(frame.height, Self.eyeQuickFloor - 0.5, "\(name) at \(frame) (\(context))")
                        XCTAssertGreaterThanOrEqual(frame.width, Self.eyeQuickFloor - 0.5, "\(name) at \(frame) (\(context))")
                    }
                }
                for label in Self.quickControls + (holdsEyeTracking ? Self.otherWordedControls : []) {
                    let control = app.buttons[label]
                    XCTAssertTrue(control.exists, "\(label) is missing (\(context))")
                    guard control.exists else { continue }
                    let screenshot = control.screenshot()
                    let attachment = XCTAttachment(screenshot: screenshot)
                    attachment.name = "\(context), \(label)"
                    attachment.lifetime = .keepAlways
                    add(attachment)
                    let image = try XCTUnwrap(screenshot.image.cgImage)
                    let words = try await RenderedWords.read(image)
                    // Each word whole: a label may take two lines.
                    XCTAssertTrue(
                        label.split(separator: " ").allSatisfy { RenderedWords.show(String($0), in: words) },
                        "Rendered \(label) is unreadable (\(context)); recognized \(words)"
                    )
                }
                try assertPassesAccessibilityAudit(app, context: context)
            }
        }
    }

    /// A person's launch: fails if, before anyone answers,
    /// Home on an iPad in portrait has a quick control or a phrase tile
    /// smaller than Eye Tracking's floors, or a starter tile outside the
    /// window, or if a phone's quick controls have other frames than
    /// touch's; if Settings' first screen, Family Setup or the first step
    /// over that Home fails Apple's accessibility audit, or the first step
    /// does not say what the answers do; then, once Touch alone is chosen
    /// in Family Setup and Settings closes, if Home's quick controls are
    /// not back to touch's frames.
    @MainActor
    func testHomeIsLargestUntilAnsweredAndTouchsOnceTouchIsChosen() throws {
        let touchFrames = touchFrames()
        let app = launchedApp(sizes: .asShipped, shortTimeouts: false)
        let window = app.windows.firstMatch.frame
        let holdsEyeTracking = Self.holdsEyeTracking(window)
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
        let touch = try openFirstStep(app, context: context)
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
