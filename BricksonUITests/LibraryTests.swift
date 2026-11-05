import UIKit
import XCTest

/// The Library in Settings, driven in the running app (docs/DECISIONS.md,
/// "The Library in Settings", "The Library's question screens",
/// "Exporting and restoring a backup"): phrases and categories changed and
/// seen on Home, the everyday categories kept between three and four, a
/// backup restored, Apple's audit on each screen, and the chain engine
/// scoring every screen's frames (`LibraryChains`).
///
/// The system's file picker cannot be driven by a UI test, so the restore
/// test launches with `--restore-sample-backup`, which opens a sample
/// backup in its place (`LaunchOptions.sampleBackup(from:)`). The share
/// sheet is left to the device checks (docs/HANDOFF.md, *Checks that need
/// a real device*).
final class LibraryTests: XCTestCase {
    /// Home's controls that keep their place in every state, as in
    /// `SettingsOnHomeTests`. The category names are copied from
    /// Brickson/Resources/StarterPhrases.json.
    private static let fixedOnHome = [
        "Yes", "No", "Emergency", "Again", "getAttention", "phrases", "type", "settings",
        "Basics", "Needs", "Conversation", "Feelings",
    ]
    private static let everydayCategories = ["Basics", "Needs", "Conversation", "Feelings"]

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: Phrases

    /// Fails if a phrase added in the Library is not saved with its words,
    /// if a change or a move does not reach Home, if Keep Phrase does not
    /// take Delete Phrase's place, if Delete for Good, Edit Phrase's last
    /// row's question, is not above it, if Delete for Good does not dim in
    /// place once it has deleted, or if the deleted phrase is still on Home.
    @MainActor
    func testAPhraseIsAddedChangedMovedAndDeleted() throws {
        // Settings' full idle limit: typing and saving take longer than the
        // 3-second test limit, and a reset part way would lose the screen.
        let app = launchedApp(shortTimeouts: false)
        openLibrary(in: app)
        open("libraryCategory0", leaving: "libraryAddCategory", in: app)
        XCTAssertTrue(app.navigationBars["Basics"].waitForExistence(timeout: 10), "Basics did not open")

        // Add.
        open("libraryAddPhrase", leaving: "libraryAddPhrase", in: app)
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 10), "New Phrase did not open the keyboard")
        app.typeText("Please open the door.")
        app.buttons["librarySave"].tap()
        waitForLine("libraryEditorResult", saying: "Added “Please open the door.” to Basics.", in: app)
        back(to: "Basics", in: app)

        // Change.
        let added = phraseRow("Please open the door.", in: app)
        XCTAssertTrue(added.waitForExistence(timeout: 10), "the added phrase has no row in Basics")
        added.tap()
        XCTAssertTrue(app.navigationBars["Edit Phrase"].waitForExistence(timeout: 10), "the phrase's row did not open its editor")
        replaceWords(in: field("libraryPhraseField", in: app), with: "Please close the door.", deleting: 21, in: app)
        app.buttons["librarySave"].tap()
        waitForLine("libraryEditorResult", saying: "Saved.", in: app)

        // Move it first, from its editor opened again. With the keyboard up
        // after Save, Move Phrase lay under the keyboard on CI's phone, and
        // XCUITest scrolled it into view as it tapped, so its frame read
        // before the tap was not where it was chosen (2026-11-05).
        back(to: "Basics", in: app)
        phraseRow("Please close the door.", in: app).tap()
        XCTAssertTrue(app.navigationBars["Edit Phrase"].waitForExistence(timeout: 10), "the changed phrase's row did not open its editor")
        let moveRow = app.buttons["libraryMovePhrase"]
        XCTAssertTrue(moveRow.waitForExistence(timeout: 10) && moveRow.isHittable, "Move Phrase does not show as Edit Phrase opens")
        let moveFrame = moveRow.frame
        moveRow.tap()
        let wayBack = app.buttons["libraryWayBack"]
        XCTAssertTrue(wayBack.waitForExistence(timeout: 10), "Move Phrase did not ask")
        expectInRowsPlace(wayBack, row: moveFrame, "Leave It Here is not in Move Phrase's place", in: app)
        app.buttons["libraryMovePlace0"].tap()
        waitForLine("libraryQuestionResult", saying: "Moved.", in: app)
        wayBack.tap()
        XCTAssertTrue(app.buttons["libraryDeletePhrase"].waitForExistence(timeout: 10), "Leave It Here did not go back")

        // Delete asks, with Keep Phrase in Delete Phrase's place.
        let deleteRow = app.buttons["libraryDeletePhrase"]
        XCTAssertTrue(deleteRow.isHittable, "Delete Phrase does not show under Move Phrase")
        let deleteFrame = deleteRow.frame
        deleteRow.tap()
        XCTAssertTrue(wayBack.waitForExistence(timeout: 10), "Delete Phrase did not ask")
        expectInRowsPlace(wayBack, row: deleteFrame, "Keep Phrase is not in Delete Phrase's place", in: app)
        let deleteForGood = app.buttons["libraryDeleteForGood"]
        XCTAssertLessThanOrEqual(
            deleteForGood.frame.maxY, wayBack.frame.minY - 64,
            "Delete for Good at \(deleteForGood.frame) is not a row clear above Keep Phrase at \(wayBack.frame)"
        )
        wayBack.tap()
        XCTAssertTrue(app.navigationBars["Edit Phrase"].waitForExistence(timeout: 10), "Keep Phrase did not go back")

        // Home shows the change, first.
        closeSettings(in: app)
        app.buttons["Basics"].tap()
        let tile = app.buttons.matching(NSPredicate(format: "label == %@", "Please close the door.")).firstMatch
        XCTAssertTrue(tile.waitForExistence(timeout: 10), "Home does not show the changed phrase")
        XCTAssertEqual(firstTile(in: app), "Please close the door.", "the moved phrase is not Home's first in Basics")

        // Delete for Good.
        openLibrary(in: app)
        open("libraryCategory0", leaving: "libraryAddCategory", in: app)
        phraseRow("Please close the door.", in: app).tap()
        XCTAssertTrue(app.navigationBars["Edit Phrase"].waitForExistence(timeout: 10), "the phrase's row did not open its editor")
        app.buttons["libraryDeletePhrase"].tap()
        XCTAssertTrue(deleteForGood.waitForExistence(timeout: 10), "Delete Phrase did not ask")
        let place = deleteForGood.frame
        deleteForGood.tap()
        waitForLine("libraryQuestionResult", saying: "Deleted “Please close the door.”.", in: app)
        waitUntil(deleteForGood, "isEnabled == false", "Delete for Good did not dim once it had deleted")
        expectSameFrame(deleteForGood.frame, place, "Delete for Good moved after deleting")
        waitUntil(wayBack, "label == 'Done'", "Keep Phrase did not read Done after the delete")
        wayBack.tap()
        XCTAssertTrue(app.navigationBars["Basics"].waitForExistence(timeout: 10), "Done did not return to Basics")
        waitForLine("libraryResult", saying: "Deleted “Please close the door.”.", in: app)
        XCTAssertFalse(phraseRow("Please close the door.", in: app).exists, "Basics still has the deleted phrase")

        closeSettings(in: app)
        app.buttons["Basics"].tap()
        XCTAssertTrue(app.buttons["Yes"].waitForExistence(timeout: 10), "Home did not come back")
        XCTAssertFalse(
            app.buttons.matching(NSPredicate(format: "label == %@", "Please close the door.")).firstMatch.exists,
            "Home still shows the deleted phrase"
        )
    }

    // MARK: Categories

    /// Fails if Home's room for three or four everyday categories is not
    /// kept (docs/DECISIONS.md, "Three or four everyday categories"), if a
    /// name with a word too wide for Home's category buttons is saved, if
    /// a category added, given a picture and renamed does not reach Home,
    /// or if, with no phrases yet, it is not dimmed there and its screen
    /// does not say how many it needs (docs/DECISIONS.md, "Four phrases in
    /// every category").
    @MainActor
    func testCategoriesStayBetweenThreeAndFour() throws {
        let app = launchedApp(shortTimeouts: false)
        openLibrary(in: app)
        XCTAssertFalse(app.buttons["libraryAddCategory"].isEnabled, "Add a Category is on with four categories")

        // Delete Feelings.
        open("libraryCategory3", leaving: "libraryAddCategory", in: app)
        XCTAssertTrue(app.navigationBars["Feelings"].waitForExistence(timeout: 10), "Feelings did not open")
        app.buttons["libraryDeleteCategory"].tap()
        let deleteForGood = app.buttons["libraryDeleteForGood"]
        XCTAssertTrue(deleteForGood.waitForExistence(timeout: 10), "Delete Category did not ask")
        deleteForGood.tap()
        waitForLine("libraryQuestionResult", saying: "Deleted “Feelings” and every phrase in it.", in: app)
        let wayBack = app.buttons["libraryWayBack"]
        waitUntil(wayBack, "label == 'Done'", "Keep Category did not read Done after the delete")
        wayBack.tap()
        XCTAssertTrue(app.navigationBars["Phrases and Categories"].waitForExistence(timeout: 10), "Done did not return to the Library")
        waitForLine("libraryResult", saying: "Deleted “Feelings” and every phrase in it.", in: app)
        XCTAssertTrue(app.buttons["libraryAddCategory"].isEnabled, "Add a Category is off with three categories")

        // Three is the floor.
        open("libraryCategory0", leaving: "libraryAddCategory", in: app)
        let deleteBasics = app.buttons["libraryDeleteCategory"]
        XCTAssertTrue(deleteBasics.waitForExistence(timeout: 10), "Basics has no Delete Category")
        XCTAssertFalse(deleteBasics.isEnabled, "Delete Category is on with three categories")
        waitForLine("libraryDeleteReason", saying: "Home needs at least three categories besides Emergency", in: app)
        back(to: "Phrases and Categories", in: app)

        // A word too wide for Home's category buttons is refused; a short
        // name opens its new category.
        open("libraryAddCategory", leaving: "libraryAddCategory", in: app)
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 10), "New Category did not open the keyboard")
        app.typeText("Entertainment")
        app.buttons["librarySave"].tap()
        waitForLine("libraryEditorResult", saying: "“Entertainment” is too wide for Home's category buttons.", in: app)
        replaceWords(in: field("libraryNameField", in: app), with: "Outings", deleting: 13, in: app)
        app.buttons["librarySave"].tap()
        XCTAssertTrue(app.navigationBars["Outings"].waitForExistence(timeout: 10), "a saved category did not open its screen")
        waitForLine("libraryResult", saying: "Added “Outings”.", in: app)
        waitForLine("libraryShortNote", saying: "Home shows “Outings” once it has four phrases.", in: app)
        waitForLine("libraryShortNote", saying: "Add 4 more.", in: app)

        // A picture.
        app.buttons["libraryChangePicture"].tap()
        let heart = app.buttons["libraryPicture-heart.fill"]
        XCTAssertTrue(heart.waitForExistence(timeout: 10), "Change Picture did not ask")
        heart.tap()
        waitUntil(heart, "isSelected == true", "the chosen picture is not marked")
        app.buttons["libraryWayBack"].tap()
        XCTAssertTrue(app.navigationBars["Outings"].waitForExistence(timeout: 10), "Keep This Picture did not go back")

        // A new name.
        open("libraryRename", leaving: "libraryRename", in: app)
        XCTAssertTrue(app.navigationBars["Rename Category"].waitForExistence(timeout: 10), "Rename did not open")
        replaceWords(in: field("libraryNameField", in: app), with: "Trips", deleting: 7, in: app)
        app.buttons["librarySave"].tap()
        waitForLine("libraryEditorResult", saying: "Saved.", in: app)
        back(to: "Trips", in: app)

        closeSettings(in: app)
        XCTAssertTrue(app.buttons["Trips"].waitForExistence(timeout: 10), "Home has no button for the new category")
        XCTAssertFalse(app.buttons["Trips"].isEnabled, "Home offers a category with no phrases")
        XCTAssertFalse(app.buttons["Feelings"].exists, "Home still has the deleted category")
    }

    // MARK: Restore

    /// Fails if Cancel does not take Restore from a Backup's place, if the
    /// Library's last row's question does not put its choices above it, if
    /// Add to My Phrases does not bring in exactly the backup's one new
    /// phrase, or if Home does not show it.
    @MainActor
    func testASampleBackupIsAdded() throws {
        let app = launchedApp(arguments: ["--restore-sample-backup"], shortTimeouts: false)
        openLibrary(in: app)
        let restore = app.buttons["libraryRestore"]
        XCTAssertTrue(restore.waitForExistence(timeout: 10), "the Library has no Restore from a Backup")
        for _ in 0..<4 where !restore.isHittable {
            app.swipeUp()
        }
        let restoreFrame = restore.frame
        restore.tap()
        let wayBack = app.buttons["libraryWayBack"]
        XCTAssertTrue(wayBack.waitForExistence(timeout: 10), "Restore from a Backup did not ask")
        expectSameFrame(wayBack.frame, restoreFrame, "Cancel is not in Restore from a Backup's place")
        let add = app.buttons["libraryRestoreAdd"]
        XCTAssertLessThanOrEqual(add.frame.maxY, wayBack.frame.minY - 64, "Add to My Phrases at \(add.frame) is not a row clear above Cancel at \(wayBack.frame)")
        attachCapture(app, name: "restore-question")

        add.tap()
        let line = "Added. New categories: 0. New phrases: 1. Nothing was removed or moved."
        waitForLine("libraryQuestionResult", saying: line, in: app)
        waitUntil(add, "isEnabled == false", "Add to My Phrases did not dim once it had added")
        waitUntil(wayBack, "label == 'Done'", "Cancel did not read Done after the restore")
        wayBack.tap()
        XCTAssertTrue(app.navigationBars["Phrases and Categories"].waitForExistence(timeout: 10), "Done did not return to the Library")
        waitForLine("libraryBackupResult", saying: line, in: app)

        closeSettings(in: app)
        app.buttons["Basics"].tap()
        XCTAssertTrue(
            app.buttons.matching(NSPredicate(format: "label == %@", "Please open the window.")).firstMatch.waitForExistence(timeout: 10),
            "Home does not show the restored phrase"
        )
    }

    // MARK: Audits

    /// Apple's audit on the Library's screens in light: the Library, a
    /// category, the phrase editor, Delete Phrase's question, Change
    /// Picture and the Restore question. Fails on any issue it reports.
    @MainActor
    func testTheLibrarysScreensPassTheAuditInLight() throws {
        continueAfterFailure = true
        let app = launchedApp(arguments: ["--restore-sample-backup"], shortTimeouts: false)
        try auditTheScreens(in: app, appearance: "light", all: true)
    }

    /// The Library, the phrase editor and Delete Phrase's question in dark.
    @MainActor
    func testTheLibrarysScreensPassTheAuditInDark() throws {
        continueAfterFailure = true
        let app = launchedApp(appearance: .dark, shortTimeouts: false)
        try auditTheScreens(in: app, appearance: "dark", all: false)
    }

    @MainActor
    private func auditTheScreens(in app: XCUIApplication, appearance: String, all: Bool) throws {
        openLibrary(in: app)
        try audit(app, "the Library, \(appearance)")
        open("libraryCategory0", leaving: "libraryAddCategory", in: app)
        if all {
            try audit(app, "Basics, \(appearance)")
            app.buttons["libraryChangePicture"].tap()
            XCTAssertTrue(app.buttons["libraryWayBack"].waitForExistence(timeout: 10), "Change Picture did not ask")
            try audit(app, "Change Picture, \(appearance)", oneKindAtATime: true)
            app.buttons["libraryWayBack"].tap()
            XCTAssertTrue(app.navigationBars["Basics"].waitForExistence(timeout: 10), "Keep This Picture did not go back")
        }
        open("libraryPhrase0", leaving: "libraryAddPhrase", in: app)
        XCTAssertTrue(app.navigationBars["Edit Phrase"].waitForExistence(timeout: 10), "the phrase's row did not open its editor")
        try audit(app, "Edit Phrase, \(appearance)")
        app.buttons["libraryDeletePhrase"].tap()
        XCTAssertTrue(app.buttons["libraryDeleteForGood"].waitForExistence(timeout: 10), "Delete Phrase did not ask")
        try audit(app, "Delete Phrase, \(appearance)")
        if all {
            app.buttons["libraryWayBack"].tap()
            back(to: "Basics", in: app)
            back(to: "Phrases and Categories", in: app)
            app.buttons["libraryRestore"].tap()
            XCTAssertTrue(app.buttons["libraryRestoreAdd"].waitForExistence(timeout: 10), "Restore from a Backup did not ask")
            try audit(app, "the Restore question, \(appearance)")
        }
    }

    /// Audits the screen as it is. `oneKindAtATime` audits each kind of
    /// issue on its own, every kind, for a screen the audit service cannot
    /// finish in time at once: Change Picture's 32 rows timed out twice in
    /// a row on CI's phone (2026-11-05), where the iPad finished in 7
    /// seconds.
    @MainActor
    private func audit(_ app: XCUIApplication, _ context: String, oneKindAtATime: Bool = false) throws {
        attachCapture(app, name: "library-\(context)".replacingOccurrences(of: ", ", with: "-"))
        guard oneKindAtATime else {
            try assertPassesAccessibilityAudit(app, context: context)
            return
        }
        for kind in Self.auditKinds {
            try assertPassesAccessibilityAudit(app, context: "\(context), audit kind \(kind.rawValue)", types: kind)
        }
    }

    /// Every kind of issue Apple's audit checks on iOS
    /// (`XCUIAccessibilityAuditType`'s documentation, read 2026-11-05;
    /// `action` and `parentChild` are macOS only).
    private static let auditKinds: [XCUIAccessibilityAuditType] = [
        .contrast, .dynamicType, .elementDetection, .hitRegion, .sufficientElementDescription, .textClipped, .trait,
    ]

    // MARK: Chains

    /// Scores every chain of held activations from every control of the
    /// Library's screens, and from a look resting on each question's words,
    /// on the frames the app draws (invariant 10; `LibraryChains`). Fails on
    /// any hazard, and on a control the chains do not know.
    @MainActor
    func testNoHeldLookChangesTheLibraryAtDefaultText() throws {
        try checkTheChains(textSize: .large)
    }

    @MainActor
    func testNoHeldLookChangesTheLibraryAtTheLargestText() throws {
        try checkTheChains(textSize: .ax5)
    }

    @MainActor
    private func checkTheChains(textSize: UITestTextSize) throws {
        continueAfterFailure = true
        let app = launchedApp(textSize: textSize, shortTimeouts: false)
        let window = app.windows.firstMatch.frame
        let context = "\(textSize.name), \(UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone"), window \(window.size)"
        let home = try Self.onScreen(screenControls(in: app), in: window)

        app.buttons["settings"].tap()
        XCTAssertTrue(app.buttons["familySetup"].waitForExistence(timeout: 10), "Settings did not open (\(context))")
        let root = try read(app, window: window)
        open("familySetup", leaving: "familySetup", in: app)
        XCTAssertTrue(app.buttons["library"].waitForExistence(timeout: 10), "Family Setup has no Phrases and Categories (\(context))")
        let familySetup = try read(app, window: window)
        open("library", leaving: "library", in: app)
        XCTAssertTrue(app.navigationBars["Phrases and Categories"].waitForExistence(timeout: 10), "the Library did not open (\(context))")
        let library = try read(app, window: window)
        attachCapture(app, name: "library-chains-library-\(context)".replacingOccurrences(of: ", ", with: "-"))

        // The last everyday category, the one with fewest phrases.
        open("libraryCategory3", leaving: "libraryAddCategory", in: app)
        XCTAssertTrue(app.navigationBars["Feelings"].waitForExistence(timeout: 10), "Feelings did not open (\(context))")

        // Every phrase opens the same editor: the first one's, opened
        // before the screen scrolls. Its field is not a button, so it is
        // read on its own.
        var words: [String: CGRect] = [:]
        open("libraryPhrase0", leaving: "libraryAddPhrase", in: app)
        XCTAssertTrue(app.navigationBars["Edit Phrase"].waitForExistence(timeout: 10), "a phrase's row did not open its editor (\(context))")
        let field = app.descendants(matching: .any).matching(identifier: LibraryChains.phraseField).firstMatch
        XCTAssertTrue(field.exists, "Edit Phrase has no field (\(context))")
        let editor = try read(app, window: window)
            + (field.exists ? [ScreenControl(name: LibraryChains.phraseField, frame: field.frame, isSelected: false)] : [])
        attachCapture(app, name: "library-chains-editor-\(context)".replacingOccurrences(of: ", ", with: "-"))
        let movePhrase = try ask(
            "libraryMovePhrase", from: editor, returningTo: "librarySave", state: LibraryChains.movePhrase, placesOfOneHeight: true,
            words: &words, in: app, window: window, context: context
        )
        let deletePhrase = try ask("libraryDeletePhrase", from: editor, returningTo: "librarySave", state: LibraryChains.deletePhrase, words: &words, in: app, window: window, context: context)
        back(to: "Feelings", in: app)

        // Feelings read as the family leaves it once they have scrolled to
        // its rows that ask. A row the navigation bar covers wholly is not
        // there to choose, since a tap on it meets the bar, nor is a row
        // wholly past the screen's foot, which does not show.
        let shown = showTheRowsThatAsk(in: app, window: window, context: context)
        let category = try read(app, window: window).filter { control in
            [LibraryChains.backToTalking, LibraryChains.back].contains(control.name)
                || (control.frame.maxY > shown.bar.maxY && control.frame.minY < shown.foot)
        }
        attachCapture(app, name: "library-chains-category-\(context)".replacingOccurrences(of: ", ", with: "-"))
        let picture = try ask("libraryChangePicture", from: category, returningTo: "libraryRename", state: LibraryChains.picture, words: &words, in: app, window: window, context: context)
        let moveCategory = try ask(
            "libraryMoveCategory", from: category, returningTo: "libraryRename", state: LibraryChains.moveCategory, placesOfOneHeight: true,
            words: &words, in: app, window: window, context: context
        )
        let deleteCategory = try ask("libraryDeleteCategory", from: category, returningTo: "libraryRename", state: LibraryChains.deleteCategory, words: &words, in: app, window: window, context: context)

        guard let frames = HomeChains.frames(from: Self.named(home), categories: Self.everydayCategories) else {
            XCTFail("Home is missing a control the chains need (\(context)): \(home)")
            return
        }
        // Launched fresh: nothing spoken, the alarm quiet, and the category
        // showing the one Home shows selected (none while Emergency shows).
        let showing = home.first { $0.isSelected && Self.everydayCategories.contains($0.name) }
        let state = HomeChains.State(
            hasSpoken: false, showing: showing.flatMap { Self.everydayCategories.firstIndex(of: $0.name) }, sounding: false
        )
        let atRest = HomeChains.name(of: state, categories: Self.everydayCategories)
        let settings = SettingsChains.map(
            SettingsChains.Screens(root: Self.named(root), familySetup: Self.named(familySetup), firstStep: nil),
            closingOnto: atRest
        )
        let screens = LibraryChains.map(
            LibraryChains.Screens(
                library: Self.named(library), categoryRow: "libraryCategory3", category: Self.named(category),
                editor: Self.named(editor), deletePhrase: deletePhrase, movePhrase: movePhrase,
                picture: picture, moveCategory: moveCategory, deleteCategory: deleteCategory, words: words
            ),
            closingOnto: atRest
        )
        XCTAssertEqual(settings.unknown, [], "the chains do not know what these controls in Settings do (\(context))")
        XCTAssertEqual(screens.unknown, [], "the chains do not know what these controls in the Library do (\(context))")
        let map = HomeChains.map(frames).merging(settings.map).merging(screens.map)
        let hazards = map.hazards(from: LibraryChains.starts(in: map))
        func findings(_ kind: LibraryChains.Kind) -> [String] {
            ChainFinding.findings(in: hazards.filter { LibraryChains.kind(of: $0) == kind }).map(\.description)
        }
        let report = XCTAttachment(string: LibraryChains.Kind.allCases.map { kind in
            ([kind.rawValue] + findings(kind)).joined(separator: "\n")
        }.joined(separator: "\n\n"))
        report.name = "library-chains-\(context)".replacingOccurrences(of: ", ", with: "-")
        report.lifetime = .keepAlways
        add(report)

        XCTAssertEqual(findings(.changesTheLibrary), [], "a held look changes the library (\(context))")
        XCTAssertEqual(findings(.closesUnderTheLook), [], "a held look closes Settings under the look (\(context))")
        XCTAssertEqual(findings(.unexpected), [], "a chain through the Library meets a new hazard (\(context))")
    }

    /// Scrolls a category to its foot, then back toward its top by held
    /// drags that leave no momentum until Change Picture shows whole under
    /// the navigation bar, so the rows that ask a question can be chosen
    /// where they show: at the largest text on the phone, the foot left
    /// Change Picture under the bar, where a tap met the bar and nothing
    /// asked. There the screen shows about three of these rows at once
    /// (2026-11-05: content from 241 to 705 points in an 874-point
    /// window), so Rename can lie past the foot, and Delete Category
    /// across it. Returns the bar's frame and the screen's foot.
    @MainActor
    private func showTheRowsThatAsk(in app: XCUIApplication, window: CGRect, context: String) -> (bar: CGRect, foot: CGFloat) {
        let rename = app.buttons["libraryRename"]
        for _ in 0..<4 where !(rename.isHittable && window.contains(rename.frame)) {
            app.swipeUp()
        }
        let bar = app.navigationBars.firstMatch.frame
        let changePicture = app.buttons["libraryChangePicture"]
        let middle = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: window.midX, dy: window.midY))
        for _ in 0..<8 where changePicture.frame.minY < bar.maxY + Self.gutter {
            middle.press(forDuration: 0.2, thenDragTo: middle.withOffset(CGVector(dx: 0, dy: 40)), withVelocity: .slow, thenHoldForDuration: 0.5)
        }
        let foot = screenFrame(holding: "libraryChangePicture", in: app).maxY
        for row in ["libraryChangePicture", "libraryMoveCategory", "libraryDeleteCategory"] {
            let element = app.buttons[row]
            XCTAssertTrue(
                element.isHittable && element.frame.minY >= bar.maxY && element.frame.midY < foot,
                "\(row) cannot be chosen where it shows (\(context)): \(element.frame), navigation bar \(bar), foot \(foot)"
            )
        }
        XCTAssertGreaterThanOrEqual(
            changePicture.frame.minY, bar.maxY + Self.gutter,
            "Change Picture does not show whole under the navigation bar (\(context)): \(changePicture.frame), navigation bar \(bar)"
        )
        return (bar, foot)
    }

    /// Opens a question with `row`, read on `screen`; checks that its way
    /// back takes the row's place where the row showed whole, and, for a
    /// move (`placesOfOneHeight`), that its places are one height; reads its
    /// controls and its words; and goes back with the way back, waiting for
    /// `returningTo`, a control of the screen that asked.
    @MainActor
    private func ask(
        _ row: String, from screen: [ScreenControl], returningTo: String, state: String, placesOfOneHeight: Bool = false,
        words: inout [String: CGRect], in app: XCUIApplication, window: CGRect, context: String
    ) throws -> [(name: String, frame: CGRect)] {
        // XCUITest scrolls a row it cannot hit into view before tapping it,
        // and the row is then not where it was read.
        let asked = app.buttons[row].isHittable ? screen.first(where: { $0.name == row }) : nil
        app.buttons[row].tap()
        let wayBack = app.buttons["libraryWayBack"]
        XCTAssertTrue(wayBack.waitForExistence(timeout: 10), "\(row) did not ask (\(context))")
        let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: app.buttons[returningTo])
        XCTAssertEqual(XCTWaiter.wait(for: [gone], timeout: 10), .completed, "\(row)'s question did not settle (\(context))")
        if let asked {
            expectInRowsPlace(wayBack, row: asked.frame, "\(state)'s way back is not in \(row)'s place (\(context))", in: app)
        }
        let tree = try screenControls(in: app)
        if placesOfOneHeight {
            expectPlacesOfOneHeight(tree, in: state, context: context)
        }
        let controls = Self.cover(tree, in: window)
        let text = app.descendants(matching: .any).matching(identifier: LibraryChains.words).firstMatch
        if text.exists {
            words[state] = text.frame
        } else {
            XCTFail("\(state) shows no words (\(context))")
        }
        attachCapture(app, name: "library-chains-\(state)-\(context)".replacingOccurrences(of: ", ", with: "-"))
        wayBack.tap()
        XCTAssertTrue(app.buttons[returningTo].waitForExistence(timeout: 10), "\(state)'s way back did not go back (\(context))")
        return Self.named(controls)
    }

    /// The Settings cover's controls in the window: Home stays in the
    /// accessibility tree beneath it.
    @MainActor
    private func read(_ app: XCUIApplication, window: CGRect) throws -> [ScreenControl] {
        Self.cover(try screenControls(in: app), in: window)
    }

    /// Of every control in the accessibility tree, the Settings cover's in
    /// the window.
    private static func cover(_ controls: [ScreenControl], in window: CGRect) -> [ScreenControl] {
        onScreen(controls, in: window).filter { !fixedOnHome.contains($0.name) && $0.name != "phraseTile" }
    }

    private static func onScreen(_ controls: [ScreenControl], in window: CGRect) -> [ScreenControl] {
        controls.filter { $0.frame.intersects(window) }
    }

    private static func named(_ controls: [ScreenControl]) -> [(name: String, frame: CGRect)] {
        controls.map { ($0.name, $0.frame) }
    }

    // MARK: Getting around

    /// Opens Settings from Home, then Family Setup, then Phrases and
    /// Categories.
    @MainActor
    private func openLibrary(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        app.buttons["settings"].tap()
        XCTAssertTrue(app.buttons["familySetup"].waitForExistence(timeout: 10), "Settings did not open", file: file, line: line)
        open("familySetup", leaving: "familySetup", in: app, file: file, line: line)
        XCTAssertTrue(app.buttons["library"].waitForExistence(timeout: 10), "Family Setup has no Phrases and Categories", file: file, line: line)
        open("library", leaving: "library", in: app, file: file, line: line)
        XCTAssertTrue(
            app.navigationBars["Phrases and Categories"].waitForExistence(timeout: 10), "the Library did not open", file: file, line: line
        )
    }

    /// Opens a screen with the control named `name`, and waits until
    /// `leaving`, a control of the screen it leaves, has gone.
    @MainActor
    private func open(_ name: String, leaving: String, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        app.buttons[name].tap()
        let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: app.buttons[leaving])
        XCTAssertEqual(XCTWaiter.wait(for: [gone], timeout: 10), .completed, "\(name) did not open its screen", file: file, line: line)
    }

    /// Goes back with the standard Back button to the screen titled `title`.
    @MainActor
    private func back(to title: String, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        app.buttons["BackButton"].tap()
        XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 10), "Back did not return to \(title)", file: file, line: line)
    }

    @MainActor
    private func closeSettings(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let backToTalking = app.buttons["backToTalking"]
        backToTalking.tap()
        let closed = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: backToTalking)
        XCTAssertEqual(XCTWaiter.wait(for: [closed], timeout: 10), .completed, "Settings did not close", file: file, line: line)
    }

    /// A phrase's row in a category, by its words: Home's tile under the
    /// cover can have the same words.
    @MainActor
    private func phraseRow(_ words: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label == %@", LibraryChains.phraseRowPrefix, words)).firstMatch
    }

    @MainActor
    private func field(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// Puts the cursor after the field's words, deletes `deleting`
    /// characters, and types `words`.
    @MainActor
    private func replaceWords(in field: XCUIElement, with words: String, deleting: Int, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(field.waitForExistence(timeout: 10), "the field is missing", file: file, line: line)
        // Below the words, so the cursor goes after them.
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.9)).tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 10), "the field did not open the keyboard", file: file, line: line)
        app.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: deleting) + words)
    }

    /// The label of Home's first phrase, top leading.
    @MainActor
    private func firstTile(in app: XCUIApplication) -> String? {
        app.buttons.matching(identifier: "phraseTile").allElementsBoundByIndex
            .map { ($0.label, $0.frame) }
            .min { ($0.1.minY, $0.1.minX) < ($1.1.minY, $1.1.minX) }?.0
    }

    /// Waits up to 10 s for the line `identifier` to hold `words`.
    @MainActor
    private func waitForLine(_ identifier: String, saying words: String, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let element = app.descendants(matching: .any).matching(identifier: identifier).firstMatch
        let says = expectation(for: NSPredicate(format: "label CONTAINS %@", words), evaluatedWith: element)
        XCTAssertEqual(
            XCTWaiter.wait(for: [says], timeout: 10), .completed,
            "\(identifier) does not say “\(words)”: \(element.exists ? element.label : "missing")", file: file, line: line
        )
    }

    /// Waits up to 10 s for `element` to match `format`, after a tap.
    @MainActor
    private func waitUntil(_ element: XCUIElement, _ format: String, _ message: String, file: StaticString = #filePath, line: UInt = #line) {
        let changed = XCTNSPredicateExpectation(predicate: NSPredicate(format: format), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 10), .completed, message, file: file, line: line)
    }

    /// Settings' gutter round each screen's content
    /// (`SettingsMetrics.gutter`, in the app).
    private static let gutter: CGFloat = 16

    /// The frame of the scrolling screen that holds the control `name`:
    /// the Settings screen showing, from its top under the safety bar to
    /// its foot.
    @MainActor
    private func screenFrame(holding name: String, in app: XCUIApplication) -> CGRect {
        app.scrollViews.containing(.button, identifier: name).firstMatch.frame
    }

    /// A move redraws its places in the new order, so their words trade
    /// rows; were the rows of different heights, every row under one that
    /// grew would move, and a held look could rest nearest a place the
    /// person did not choose. Fails if a move question's places are not all
    /// one height (`LibraryEqualRowsLayout`). `controls` is the whole
    /// accessibility tree, not only what the window shows: at the largest
    /// text on the phone every place starts below the window (CI,
    /// 2026-11-05: Move Phrase's first place at 2,192 points in an
    /// 874-point window), and the tree still holds them.
    private func expectPlacesOfOneHeight(_ controls: [ScreenControl], in state: String, context: String) {
        let heights = controls.filter { $0.name.hasPrefix(LibraryChains.movePlacePrefix) }.map { $0.frame.height }
        XCTAssertGreaterThan(heights.count, 1, "\(state) has fewer than two places (\(context))")
        XCTAssertLessThan(
            (heights.max() ?? 0) - (heights.min() ?? 0), 0.5,
            "\(state)'s places are not all one height: \(heights) (\(context))"
        )
    }

    /// Fails unless a question's way back takes the place of the row that
    /// asked, read at `row` as it was chosen: the row's frame, moved the
    /// least that keeps it whole in what the question's content shows,
    /// from a gutter under the navigation bar to a gutter above the
    /// screen's foot (`LibraryQuestionPlace`; `SettingsScreenFrames`). A row
    /// that showed whole there gives exactly its frame; one partly under
    /// the bar or past the foot, a way back a little lower or higher.
    @MainActor
    private func expectInRowsPlace(
        _ wayBack: XCUIElement, row: CGRect, _ message: String, in app: XCUIApplication,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        let top = app.navigationBars.firstMatch.frame.maxY + Self.gutter
        let bottom = screenFrame(holding: "libraryWayBack", in: app).maxY - Self.gutter
        let place = CGRect(x: row.minX, y: min(max(row.minY, top), bottom - row.height), width: row.width, height: row.height)
        expectSameFrame(wayBack.frame, place, "\(message), from the row at \(row) with content showing from \(top) to \(bottom)", file: file, line: line)
    }

    @MainActor
    private func expectSameFrame(_ frame: CGRect, _ original: CGRect, _ message: String, file: StaticString = #filePath, line: UInt = #line) {
        let same = abs(frame.minX - original.minX) <= 1 && abs(frame.minY - original.minY) <= 1
            && abs(frame.maxX - original.maxX) <= 1 && abs(frame.maxY - original.maxY) <= 1
        XCTAssertTrue(same, "\(message): \(frame), not \(original)", file: file, line: line)
    }
}
