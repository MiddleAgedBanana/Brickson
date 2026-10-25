import UIKit
import XCTest

/// Typing on Home in the running app (docs/DECISIONS.md, "Typing on Home"):
/// Type opens Apple's keyboard with the cursor in the message's place and
/// nothing moved; Speak, in Again's place, and Return say the message and
/// keep it; Clear empties it and Put Back brings it back; while typing the
/// other categories and the phrase tiles are dimmed in place; Phrases,
/// Emergency and Settings leave typing and the message is kept; and it
/// survives a relaunch.
///
/// Measured on the simulators CI runs, with the full software keyboard
/// (`scripts/test.sh ui` shows it). What a simulator speaks is not checked:
/// the message Home shows after speaking is, since it is the last thing
/// spoken. Nothing here is evidence of sound, gaze or Snap to Item.
final class TypingOnHomeTests: XCTestCase {
    /// Home's controls that keep their place while typing, by the names
    /// `screenControls(in:)` gives them. The categories are copied from
    /// Brickson/Resources/StarterPhrases.json, as in `HomeLayoutTests`.
    private static let fixed = ["Yes", "No", "Emergency", "getAttention", "phrases", "type", "settings"]
    private static let everydayCategories = ["Basics", "Needs", "Conversation", "Feelings"]

    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    /// Fails if choosing Type moves anything, if Speak, Clear and Put Back
    /// do not take Again's and two categories' frames, if a phrase moves,
    /// goes or can be chosen while typing, or another category can be
    /// chosen, or if the field,
    /// Speak, Yes, No, Emergency, Get Attention, Phrases or Type ends below
    /// the keyboard's top.
    @MainActor
    func testTypeOpensTheKeyboardAndMovesNothing() throws {
        let app = launchedApp()
        let context = Self.context(app)
        let controlsBefore = try screenControls(in: app)
        let before = Dictionary(controlsBefore.map { ($0.name, $0.frame) }, uniquingKeysWith: { first, _ in first })

        let keyboard = startTyping(in: app, context: context)
        let controlsTyping = try screenControls(in: app)
        let typing = Dictionary(controlsTyping.map { ($0.name, $0.frame) }, uniquingKeysWith: { first, _ in first })
        attachCapture(app, name: "typing-\(context)")

        for name in Self.fixed {
            guard let original = before[name], let frame = typing[name] else {
                XCTFail("\(name) is missing before or while typing (\(context))")
                continue
            }
            Self.expectSameFrame(frame, original, "\(name)", context)
        }
        if let again = before["Again"], let speak = typing["Speak"] {
            Self.expectSameFrame(speak, again, "Speak, in Again's place,", context)
        } else {
            XCTFail("Again before typing or Speak while typing is missing (\(context))")
        }
        XCTAssertNil(typing["Again"], "Again still shows while typing (\(context))")

        // Clear and Put Back each take a category's cell; the other two
        // categories stay, dimmed.
        let cells = Self.everydayCategories.compactMap { before[$0] }
        XCTAssertEqual(cells.count, Self.everydayCategories.count, "a category is missing before typing (\(context))")
        let clear = try XCTUnwrap(typing["clear"], "Clear is missing while typing (\(context))")
        let putBack = try XCTUnwrap(typing["putBack"], "Put Back is missing while typing (\(context))")
        let clearCell = cells.firstIndex { Self.isSameFrame($0, clear) }
        let putBackCell = cells.firstIndex { Self.isSameFrame($0, putBack) }
        XCTAssertNotNil(clearCell, "Clear at \(clear) is in no category's cell (\(context))")
        XCTAssertNotNil(putBackCell, "Put Back at \(putBack) is in no category's cell (\(context))")
        XCTAssertNotEqual(clearCell, putBackCell, "Clear and Put Back share a cell (\(context))")
        for (index, name) in Self.everydayCategories.enumerated() where index != clearCell && index != putBackCell {
            let category = app.buttons[name]
            XCTAssertTrue(category.exists, "\(name) is missing while typing (\(context))")
            XCTAssertFalse(category.isEnabled, "\(name) can be chosen while typing (\(context))")
            Self.expectSameFrame(category.frame, cells[index], name, context)
        }

        // The phrase tiles stay where they were, dimmed, so no empty space
        // beside Clear and Put Back is left for a look to rest on
        // (docs/DECISIONS.md, "Typing on Home").
        func tiles(_ controls: [ScreenControl]) -> [CGRect] {
            controls.filter { $0.name == HomeChains.phraseTile }.map(\.frame).sorted { ($0.minY, $0.minX) < ($1.minY, $1.minX) }
        }
        let tilesBefore = tiles(controlsBefore)
        let tilesTyping = tiles(controlsTyping)
        XCTAssertFalse(tilesBefore.isEmpty, "no phrases before typing (\(context))")
        XCTAssertEqual(tilesTyping.count, tilesBefore.count, "phrases came or went while typing (\(context))")
        for (frame, original) in zip(tilesTyping, tilesBefore) {
            Self.expectSameFrame(frame, original, "a phrase", context)
        }
        let choosable = app.buttons.matching(identifier: HomeChains.phraseTile).matching(NSPredicate(format: "isEnabled == true"))
        XCTAssertEqual(choosable.count, 0, "a phrase can be chosen while typing (\(context))")
        XCTAssertFalse(app.buttons["Speak"].isEnabled, "Speak is on with nothing typed (\(context))")
        XCTAssertFalse(app.buttons["clear"].isEnabled, "Clear is on with nothing typed (\(context))")
        XCTAssertFalse(app.buttons["putBack"].isEnabled, "Put Back is on with nothing cleared (\(context))")
        XCTAssertTrue(app.buttons["type"].isSelected, "Type does not show selected while typing (\(context))")
        XCTAssertFalse(app.buttons["phrases"].isSelected, "Phrases shows selected while typing (\(context))")

        let field = Self.field(in: app)
        let named: [(String, CGRect?)] = [
            ("the field", field.exists ? field.frame : nil), ("Speak", typing["Speak"]), ("Yes", typing["Yes"]),
            ("No", typing["No"]), ("Emergency", typing["Emergency"]), ("Get Attention", typing["getAttention"]),
            ("Phrases", typing["phrases"]), ("Type", typing["type"]),
        ]
        for (name, frame) in named {
            guard let frame else {
                XCTFail("\(name) is missing while typing (\(context))")
                continue
            }
            XCTAssertLessThanOrEqual(frame.maxY, keyboard.minY + 0.5, "\(name) at \(frame) ends under the keyboard at \(keyboard) (\(context))")
        }
    }

    /// Fails if Speak or Return does not say the typed message, or if
    /// either takes it away: the message Home shows once the phrases are
    /// back is the last thing spoken.
    @MainActor
    func testSpeakAndReturnSayTheMessageAndKeepIt() throws {
        let app = launchedApp()
        let context = Self.context(app)
        startTyping(in: app, context: context)
        app.typeText("Green apples")

        let speak = app.buttons["Speak"]
        Self.waitUntil(speak, "isEnabled == true", "Speak did not turn on once words were typed (\(context))")
        speak.tap()
        showPhrases(in: app, context: context)
        XCTAssertTrue(app.staticTexts["Green apples"].waitForExistence(timeout: 10), "Speak did not say the message (\(context))")
        Self.waitUntil(app.buttons["Again"], "isEnabled == true", "Again is off after Speak (\(context))")

        startTyping(in: app, context: context)
        let field = Self.field(in: app)
        Self.waitForField(field, toHold: "Green apples", "Speak did not keep the message (\(context))")

        app.buttons["clear"].tap()
        Self.waitUntil(app.buttons["Speak"], "isEnabled == false", "Speak is still on after Clear (\(context))")
        app.typeText("Blue kites\n")
        // Return speaks, and is not kept as a line break.
        Self.waitForField(field, toHold: "Blue kites", "Return did not keep the message as typed (\(context))")
        showPhrases(in: app, context: context)
        XCTAssertTrue(app.staticTexts["Blue kites"].waitForExistence(timeout: 10), "Return did not say the message (\(context))")
    }

    /// Fails if Clear does not empty the message, or Put Back does not
    /// bring back what Clear took.
    @MainActor
    func testClearAndPutBack() throws {
        let app = launchedApp()
        let context = Self.context(app)
        startTyping(in: app, context: context)
        app.typeText("Hello")
        let field = Self.field(in: app)
        Self.waitForField(field, toHold: "Hello", "the words did not appear (\(context))")
        let clear = app.buttons["clear"]
        Self.waitUntil(clear, "isEnabled == true", "Clear did not turn on once words were typed (\(context))")

        clear.tap()
        let putBack = app.buttons["putBack"]
        Self.waitUntil(putBack, "isEnabled == true", "Put Back did not turn on after Clear (\(context))")
        XCTAssertNotEqual(field.value as? String, "Hello", "Clear did not empty the message (\(context))")
        XCTAssertFalse(clear.isEnabled, "Clear is still on with nothing typed (\(context))")

        putBack.tap()
        Self.waitUntil(clear, "isEnabled == true", "Clear did not turn on after Put Back (\(context))")
        Self.waitForField(field, toHold: "Hello", "Put Back did not bring the message back (\(context))")
        XCTAssertFalse(putBack.isEnabled, "Put Back is still on once the message is back (\(context))")
    }

    /// Fails if Emergency, Phrases or Settings does not leave typing in one
    /// activation, or if leaving takes the message away.
    @MainActor
    func testEmergencyPhrasesAndSettingsLeaveTypingAndKeepTheMessage() throws {
        let app = launchedApp()
        let context = Self.context(app)
        startTyping(in: app, context: context)
        app.typeText("Hello")
        Self.waitForField(Self.field(in: app), toHold: "Hello", "the words did not appear (\(context))")

        // Emergency: straight to the emergency phrases (invariant 2).
        let emergency = app.buttons["Emergency"]
        emergency.tap()
        Self.waitUntil(emergency, "isSelected == true", "Emergency did not show its phrases from typing (\(context))")
        Self.waitUntil(app.buttons[HomeChains.phraseTile].firstMatch, "isEnabled == true", "the phrases are still dimmed after Emergency (\(context))")
        XCTAssertFalse(Self.field(in: app).exists, "the field is still showing after Emergency (\(context))")
        startTyping(in: app, context: context)
        Self.waitForField(Self.field(in: app), toHold: "Hello", "Emergency did not keep the message (\(context))")

        // Settings closes onto the phrases.
        app.buttons["settings"].tap()
        let back = app.buttons["backToTalking"]
        XCTAssertTrue(back.waitForExistence(timeout: 10), "Settings did not open from typing (\(context))")
        back.tap()
        Self.waitUntil(app.buttons["phrases"], "isSelected == true", "Settings did not close onto the phrases (\(context))")
        XCTAssertFalse(Self.field(in: app).exists, "the field is showing after Settings (\(context))")

        startTyping(in: app, context: context)
        Self.waitForField(Self.field(in: app), toHold: "Hello", "Settings did not keep the message (\(context))")
        showPhrases(in: app, context: context)
        Self.waitUntil(app.buttons[HomeChains.phraseTile].firstMatch, "isEnabled == true", "the phrases are still dimmed after Phrases (\(context))")
    }

    /// Fails if the message is lost when the app closes, or if restoring it
    /// speaks or opens typing (`DraftStore`).
    @MainActor
    func testTheMessageSurvivesARelaunch() throws {
        var app = launchedApp()
        let context = Self.context(app)
        startTyping(in: app, context: context)
        app.typeText("Bring the blanket")
        Self.waitForField(Self.field(in: app), toHold: "Bring the blanket", "the words did not appear (\(context))")
        app.terminate()

        app = launchedApp(storage: .kept)
        XCTAssertFalse(Self.field(in: app).exists, "the app opened typing at launch (\(context))")
        XCTAssertFalse(app.buttons["Again"].isEnabled, "something was spoken at launch (\(context))")
        startTyping(in: app, context: context)
        Self.waitForField(Self.field(in: app), toHold: "Bring the blanket", "the message was lost on relaunch (\(context))")
    }

    // MARK: Helpers

    /// Chooses Type and waits for the keyboard; returns its frame.
    @MainActor
    @discardableResult
    private func startTyping(in app: XCUIApplication, context: String) -> CGRect {
        app.buttons["type"].tap()
        let keyboard = app.keyboards.firstMatch
        XCTAssertTrue(keyboard.waitForExistence(timeout: 10), "Type did not open the keyboard (\(context))")
        XCTAssertTrue(Self.field(in: app).waitForExistence(timeout: 10), "Type did not show the field (\(context))")
        Self.waitUntil(app.buttons["type"], "isSelected == true", "Type does not show selected (\(context))")
        return keyboard.frame
    }

    /// Chooses Phrases and waits for the keyboard to go.
    @MainActor
    private func showPhrases(in app: XCUIApplication, context: String) {
        app.buttons["phrases"].tap()
        Self.waitUntil(app.buttons["phrases"], "isSelected == true", "Phrases did not leave typing (\(context))")
        let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: app.keyboards.firstMatch)
        XCTAssertEqual(XCTWaiter.wait(for: [gone], timeout: 10), .completed, "the keyboard stayed after Phrases (\(context))")
    }

    @MainActor
    private static func field(in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[HomeChains.field]
    }

    @MainActor
    private static func context(_ app: XCUIApplication) -> String {
        let window = app.windows.firstMatch.frame
        return "\(UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone"), window \(window.size)"
    }

    /// Waits up to 10 s for `element` to match `format`, after a tap.
    @MainActor
    private static func waitUntil(_ element: XCUIElement, _ format: String, _ message: String) {
        let changed = XCTNSPredicateExpectation(predicate: NSPredicate(format: format), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 10), .completed, message)
    }

    /// Waits up to 10 s for the field to hold `words`.
    @MainActor
    private static func waitForField(_ field: XCUIElement, toHold words: String, _ message: String) {
        let holds = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in MainActor.assumeIsolated { (field.value as? String) == words } }, object: nil
        )
        XCTAssertEqual(XCTWaiter.wait(for: [holds], timeout: 10), .completed, "\(message): \(String(describing: field.value))")
    }

    private static func isSameFrame(_ a: CGRect, _ b: CGRect) -> Bool {
        abs(a.minX - b.minX) <= 1 && abs(a.minY - b.minY) <= 1 && abs(a.maxX - b.maxX) <= 1 && abs(a.maxY - b.maxY) <= 1
    }

    private static func expectSameFrame(_ frame: CGRect, _ original: CGRect, _ name: String, _ context: String) {
        XCTAssertTrue(isSameFrame(frame, original), "\(name) moved from \(original) to \(frame) while typing (\(context))")
    }
}
