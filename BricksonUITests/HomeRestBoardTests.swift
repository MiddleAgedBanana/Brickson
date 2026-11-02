import UIKit
import XCTest

/// The rest board in the running app (docs/DECISIONS.md, "The late-stage
/// profile"): chosen in Set Up Step by Step's second step, it shows one
/// category's phrases and Emergency's, dims the other categories in their
/// places, and grows Yes, No, Emergency, Again and Get Attention; Every
/// Category puts Home back as it was.
///
/// Expected sizes come from the layout engine's table for the windows CI
/// runs (`LateStageProfileTests.boardTable`): the late stage's on a 13-inch
/// iPad in portrait at every text size, touch's on an iPhone 17, told apart
/// here by the window's shape alone, as `HomeSizesTests` does. It says
/// nothing about gaze comfort, which needs a device (docs/HANDOFF.md).
///
/// The board is Conversation, the starter library's everyday category with
/// six phrases, as many as Emergency, so on the iPhone's three columns the
/// grid shows two rows instead of three; the iPad's four columns hold
/// every category in two rows already. Apple's audit and the drawn words
/// are checked on Needs too, a board of eight phrases, which keeps every
/// category's three rows on the iPhone, so its tiles give Yes and No some
/// of their height and its words sit in other frames than a board of
/// six's (`LateStageProfileTests.boardTableForEight`). The flow walks
/// Settings to the second step, so it launches without the short idle
/// limits, which could reset Settings part way.
final class HomeRestBoardTests: XCTestCase {
    /// The late stage's floors (`HomeLayout.Profile.lateStage`): quick
    /// controls and phrase tiles.
    private static let lateQuickFloor: CGFloat = 136
    private static let lateTileFloor: CGFloat = 136
    /// The starter library's everyday categories, in Home's order, and the
    /// one the board shows, with its number of phrases.
    private static let everyday = ["Basics", "Needs", "Conversation", "Feelings"]
    private static let board = "Conversation"
    private static let boardPhrases = 6
    /// The board of eight phrases whose audit and drawn words are checked
    /// too.
    private static let boardOfEight = "Needs"
    private static let boardOfEightPhrases = 8
    /// The second step's question.
    private static let question = "Which phrases does Home show?"
    /// The quick controls, whose words every window must draw whole.
    private static let quickControls = ["Yes", "No", "Emergency", "Get Attention", "Again"]
    /// The controls that keep their frames between the board's phrases and
    /// Emergency's (invariant 8).
    private static let fixedControls = quickControls + everyday + ["Settings", "Phrases", "Type"]

    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    /// Whether `window` holds the late stage's sizes with the board at
    /// every text size, by its shape alone: an iPad in portrait
    /// (`LateStageProfileTests.boardTable`).
    private static func holdsLateStage(_ window: CGRect) -> Bool {
        window.width >= 600 && window.height > window.width
    }

    @MainActor
    private func frames(of labels: [String], in app: XCUIApplication) -> [String: CGRect] {
        Dictionary(uniqueKeysWithValues: labels.map { ($0, app.buttons[$0].frame) })
    }

    /// Whether two frames are the same, to half a point.
    private static func same(_ a: CGRect, _ b: CGRect?) -> Bool {
        guard let b else { return false }
        return abs(a.minX - b.minX) <= 0.5 && abs(a.minY - b.minY) <= 0.5
            && abs(a.width - b.width) <= 0.5 && abs(a.height - b.height) <= 0.5
    }

    @MainActor
    private func tileLabels(in app: XCUIApplication) -> [String] {
        app.buttons.matching(identifier: "phraseTile").allElementsBoundByIndex.map(\.label)
    }

    /// Waits for `element` to match `format`, and fails with `message` if
    /// it does not within ten seconds.
    @MainActor
    private func waitUntil(_ element: XCUIElement, matches format: String, _ message: String) {
        let matched = expectation(for: NSPredicate(format: format), evaluatedWith: element)
        XCTAssertEqual(XCTWaiter.wait(for: [matched], timeout: 10), .completed, message)
    }

    /// Whether `choice` lies whole above Next, where it can be activated.
    @MainActor
    private func isAboveNext(_ choice: XCUIElement, in app: XCUIApplication) -> Bool {
        choice.isHittable && choice.frame.maxY <= app.buttons["guidedSetupNext"].frame.minY + 0.5
    }

    /// Scrolls the second step until `choice` lies whole above Next, as a
    /// family scrolls to the choices that start below the bar
    /// (`SetupChoicesPlace`), then captures the step. Fails if eight
    /// swipes do not bring it there.
    @MainActor
    private func scrollAboveNext(_ choice: XCUIElement, named name: String, in app: XCUIApplication, context: String) {
        let step = app.scrollViews.containing(NSPredicate(format: "label == %@", Self.question)).firstMatch
        var swipes = 0
        while !isAboveNext(choice, in: app), swipes < 8 {
            step.swipeUp()
            swipes += 1
        }
        XCTAssertTrue(isAboveNext(choice, in: app), "\(name) at \(choice.frame) is not above Next after \(swipes) swipes (\(context))")
        if swipes > 0 {
            attachCapture(app, name: "the second step scrolled to \(name), \(context)")
        }
    }

    /// Opens Set Up Step by Step's second step from Home, chooses the
    /// choice `identifier` labelled `label` (any label where nil), and
    /// closes Settings with Back to Talking. Fails if the step does not
    /// open, Every Category is not on its first screenful, above Next (it
    /// holds under the words on every window CI runs at the default size:
    /// `SetupChoicesPlaceTests`), the choice is not chosen, a second
    /// activation undoes it, or Settings does not close.
    @MainActor
    private func choose(_ identifier: String, label: String?, in app: XCUIApplication, context: String) throws {
        app.buttons["Settings"].tap()
        let backToTalking = app.buttons["backToTalking"]
        XCTAssertTrue(backToTalking.waitForExistence(timeout: 10), "Settings did not open (\(context))")
        for (row, title) in [("familySetup", "Family Setup"), ("guidedSetup", "Step 1 of 6"), ("guidedSetupNext", "Step 2 of 6")] {
            let control = app.buttons[row].firstMatch
            XCTAssertTrue(control.waitForExistence(timeout: 10), "\(row) is missing (\(context))")
            control.tap()
            XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 10), "\(title) did not open (\(context))")
        }
        XCTAssertTrue(
            app.staticTexts[Self.question].waitForExistence(timeout: 10),
            "the second step does not ask which phrases Home shows (\(context))"
        )
        var choices = app.buttons.matching(identifier: identifier)
        if let label {
            choices = choices.matching(NSPredicate(format: "label == %@", label))
        }
        let choice = choices.firstMatch
        XCTAssertTrue(choice.waitForExistence(timeout: 10), "the second step shows no \(label ?? identifier) (\(context))")
        let everyCategory = app.buttons["restBoardEveryCategory"]
        XCTAssertTrue(
            isAboveNext(everyCategory, in: app),
            "Every Category at \(everyCategory.frame) is not on the step's first screenful, above Next (\(context))"
        )
        attachCapture(app, name: "the second step before \(label ?? identifier), \(context)")
        try assertPassesAccessibilityAudit(app, context: "Step 2 of 6, \(context)")
        scrollAboveNext(choice, named: label ?? identifier, in: app, context: context)
        choice.tap()
        waitUntil(choice, matches: "isSelected == true", "\(label ?? identifier) was not chosen (\(context))")
        // Choices only select: a second activation keeps it chosen.
        choice.tap()
        waitUntil(choice, matches: "isSelected == true", "a second activation undid \(label ?? identifier) (\(context))")
        backToTalking.tap()
        waitUntil(backToTalking, matches: "exists == false", "Settings did not close (\(context))")
    }

    /// Fails if Conversation, chosen in the second step, does not become
    /// the board once Settings closes: the other everyday categories still
    /// enabled, Conversation not chosen, other than its six phrases in the
    /// grid, a tile outside the window, or on an iPad in portrait a quick
    /// control or tile under the late stage's floors; on a phone, a quick
    /// control no taller than with every category, or wider, or moved
    /// sideways. Then fails if Emergency does not show its own phrases with
    /// every control where it was, or Conversation does not bring the
    /// board's back; and, once Every Category is chosen and Settings
    /// closes, if a category stays dimmed or a quick control is not back
    /// where it was.
    @MainActor
    func testTheRestBoardShowsOneCategoryAndEveryCategoryPutsHomeBack() throws {
        let app = launchedApp(sizes: .asShipped, shortTimeouts: false)
        let window = app.windows.firstMatch.frame
        let holdsLateStage = Self.holdsLateStage(window)
        let context = "window \(window.size)"
        let everyCategory = frames(of: Self.quickControls, in: app)
        attachCapture(app, name: "Home with every category, \(context)")

        try choose("restBoardCategory", label: Self.board, in: app, context: context)
        let basics = app.buttons["Basics"]
        waitUntil(basics, matches: "isEnabled == false", "Basics was not dimmed once the board was chosen (\(context))")
        attachCapture(app, name: "the rest board, \(context)")
        for name in Self.everyday where name != Self.board {
            XCTAssertFalse(app.buttons[name].isEnabled, "\(name) is not dimmed on the board (\(context))")
        }
        let board = app.buttons[Self.board]
        XCTAssertTrue(board.isEnabled, "\(Self.board) is dimmed on its own board (\(context))")
        XCTAssertTrue(board.isSelected, "\(Self.board) is not chosen on its own board (\(context))")

        let boardTiles = tileLabels(in: app)
        XCTAssertEqual(boardTiles.count, Self.boardPhrases, "the board shows \(boardTiles.count) phrases (\(context))")
        for tile in app.buttons.matching(identifier: "phraseTile").allElementsBoundByIndex {
            let frame = tile.frame
            XCTAssertTrue(window.contains(frame), "a tile at \(frame) is not inside the window (\(context))")
            if holdsLateStage {
                XCTAssertGreaterThanOrEqual(frame.height, Self.lateTileFloor - 0.5, "a tile at \(frame) (\(context))")
                XCTAssertGreaterThanOrEqual(frame.width, Self.lateTileFloor - 0.5, "a tile at \(frame) (\(context))")
            }
        }
        for (name, frame) in frames(of: Self.quickControls, in: app) {
            if holdsLateStage {
                XCTAssertGreaterThanOrEqual(frame.height, Self.lateQuickFloor - 0.5, "\(name) at \(frame) (\(context))")
                XCTAssertGreaterThanOrEqual(frame.width, Self.lateQuickFloor - 0.5, "\(name) at \(frame) (\(context))")
            } else if let before = everyCategory[name] {
                // The same sizes as with every category, touch's, and only
                // the safety row taller (`LateStageProfileTests`).
                XCTAssertGreaterThan(frame.height, before.height + 0.5, "\(name) at \(frame), \(before) with every category (\(context))")
                XCTAssertEqual(frame.minX, before.minX, accuracy: 0.5, "\(name) moved sideways (\(context))")
                XCTAssertEqual(frame.width, before.width, accuracy: 0.5, "\(name) changed width (\(context))")
            }
        }

        // Emergency's phrases, then the board's again, with nothing moved.
        let fixed = frames(of: Self.fixedControls, in: app)
        app.buttons["Emergency"].tap()
        waitUntil(board, matches: "isSelected == false", "Emergency did not leave the board's phrases (\(context))")
        let emergencyTiles = tileLabels(in: app)
        XCTAssertNotEqual(emergencyTiles, boardTiles, "Emergency shows the board's phrases (\(context))")
        XCTAssertFalse(emergencyTiles.isEmpty, "Emergency shows no phrases (\(context))")
        attachCapture(app, name: "Emergency on the rest board, \(context)")
        for (name, frame) in frames(of: Self.fixedControls, in: app) {
            XCTAssertTrue(Self.same(frame, fixed[name]), "\(name) at \(frame) with Emergency, \(String(describing: fixed[name])) on the board (\(context))")
        }
        board.tap()
        waitUntil(board, matches: "isSelected == true", "\(Self.board) did not bring the board's phrases back (\(context))")
        XCTAssertEqual(tileLabels(in: app), boardTiles, "the board's phrases changed after Emergency (\(context))")

        // Every Category puts Home back.
        try choose("restBoardEveryCategory", label: nil, in: app, context: context)
        waitUntil(basics, matches: "isEnabled == true", "Basics stayed dimmed after Every Category (\(context))")
        attachCapture(app, name: "Home after Every Category, \(context)")
        for name in Self.everyday {
            XCTAssertTrue(app.buttons[name].isEnabled, "\(name) stayed dimmed after Every Category (\(context))")
        }
        for (name, frame) in frames(of: Self.quickControls, in: app) {
            XCTAssertTrue(
                Self.same(frame, everyCategory[name]),
                "\(name) at \(frame) after Every Category, \(String(describing: everyCategory[name])) before the board (\(context))"
            )
        }
    }

    /// The board at the default and the largest text size, light and dark.
    /// Fails as `assertPassesTheAuditAndDrawsItsWordsWhole` says.
    @MainActor
    func testTheRestBoardPassesTheAuditAndDrawsItsWordsWhole() async throws {
        try await assertPassesTheAuditAndDrawsItsWordsWhole(board: Self.board, phrases: Self.boardPhrases)
    }

    /// The same on a board of eight phrases, Needs. Fails as
    /// `assertPassesTheAuditAndDrawsItsWordsWhole` says.
    @MainActor
    func testABoardOfEightPassesTheAuditAndDrawsItsWordsWhole() async throws {
        try await assertPassesTheAuditAndDrawsItsWordsWhole(board: Self.boardOfEight, phrases: Self.boardOfEightPhrases)
    }

    /// Chooses `board` in the second step, then launches at the default and
    /// the largest text size, light and dark. Fails if the board does not
    /// show `phrases` phrases once chosen, if a launch does not keep the
    /// board, if the words of a quick control or an everyday category,
    /// dimmed or not, are not each drawn whole (`RenderedWords`, without
    /// the expected words or language correction), or if Apple's
    /// accessibility audit finds anything.
    @MainActor
    private func assertPassesTheAuditAndDrawsItsWordsWhole(board: String, phrases: Int) async throws {
        let first = launchedApp(sizes: .asShipped, shortTimeouts: false)
        try choose("restBoardCategory", label: board, in: first, context: "choosing \(board)")
        let dimmed = try XCTUnwrap(Self.everyday.first(where: { $0 != board }))
        waitUntil(first.buttons[dimmed], matches: "isEnabled == false", "\(dimmed) was not dimmed once \(board) was chosen")
        let chosenTiles = tileLabels(in: first)
        XCTAssertEqual(chosenTiles.count, phrases, "the \(board) board shows \(chosenTiles) after it was chosen")
        for textSize in [UITestTextSize.large, .ax5] {
            for appearance in [UITestAppearance.light, .dark] {
                // The same storage, so the board chosen above is kept.
                let app = launchedApp(textSize: textSize, appearance: appearance, storage: .kept, sizes: .asShipped)
                let window = app.windows.firstMatch.frame
                let context = "the \(board) board, \(textSize.name), \(appearance.rawValue), window \(window.size)"
                attachCapture(app, name: context)
                XCTAssertFalse(app.buttons[dimmed].isEnabled, "the board was not kept across a launch (\(context))")
                for label in Self.quickControls + Self.everyday {
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
}
