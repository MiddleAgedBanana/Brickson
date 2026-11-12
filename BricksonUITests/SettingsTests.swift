import XCTest

/// Settings, opened at launch with `--screen=settings`, so each test starts
/// there without walking Home; `SettingsOnHomeTests` opens it with Home's
/// own Settings button. These check what a family member and a stray
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
        storage: UITestStorage = .fresh,
        shortTimeouts: Bool = false,
        arguments: [String] = [],
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> XCUIApplication {
        let app = launchedApp(
            textSize: textSize,
            appearance: appearance,
            storage: storage,
            arguments: ["--screen=settings"] + arguments,
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

    /// Family Setup opens with Set Up Step by Step over the whole of the
    /// root's Family Setup row as drawn, its button style's insets
    /// included, so a repeated activation where that row was meets a row
    /// that only opens the next screen, not Back to Talking, which would
    /// close Settings onto Home (docs/DECISIONS.md, "Settings' first row,
    /// placed from Home's frames"). Fails if Set Up Step by Step's leading
    /// edge, top or width differ from the row's by more than a point (a row
    /// across the width would cover the spot and still let a look there
    /// meet Back to Talking by centre), if it is shorter than the row, if
    /// any other button lies within the row's frame, or if the opening
    /// words are gone.
    @MainActor
    func testFamilySetupOpensWithSetUpStepByStepOverTheWholeRootRow() {
        continueAfterFailure = true
        for textSize in [UITestTextSize.large, .ax5] {
            let app = openSettings(textSize: textSize)
            let context = "Family Setup, \(textSize.name)"
            let row = app.buttons["familySetup"]
            XCTAssertTrue(row.waitForExistence(timeout: 10), "familySetup is missing (\(context))")
            let rowFrame = row.frame

            open("familySetup", in: app, waitingFor: "Family Setup")
            let opening = app.descendants(matching: .any)["familySetupOpening"]
            let guided = app.buttons["guidedSetup"]
            XCTAssertTrue(guided.waitForExistence(timeout: 10), "guidedSetup is missing (\(context))")
            XCTAssertTrue(opening.exists, "the opening words are missing (\(context))")
            attachCapture(app, name: context)
            XCTAssertTrue(
                guided.frame.insetBy(dx: -0.5, dy: -0.5).contains(rowFrame),
                "Set Up Step by Step at \(guided.frame) does not cover the root row at \(rowFrame) (\(context))"
            )
            // In the row's own frame, growing only downward.
            XCTAssertEqual(guided.frame.minX, rowFrame.minX, accuracy: 1, "Set Up Step by Step's leading edge moved (\(context))")
            XCTAssertEqual(guided.frame.minY, rowFrame.minY, accuracy: 1, "Set Up Step by Step's top moved (\(context))")
            XCTAssertEqual(guided.frame.width, rowFrame.width, accuracy: 1, "Set Up Step by Step is not the row's width (\(context))")
            // Inset, so a row that only touches its edge does not count.
            let spot = rowFrame.insetBy(dx: 0.5, dy: 0.5)
            for button in app.buttons.allElementsBoundByIndex
            where button.exists && button.identifier != "guidedSetup" && button.frame.intersects(spot) && button.isHittable {
                XCTFail("\(button.label) lies where the root's Family Setup row was (\(context)): \(button.frame) against \(rowFrame)")
            }
        }
    }

    /// The first step of Set Up Step by Step opens on Learn About Each Way,
    /// in Set Up Step by Step's frame as Family Setup drew it, so a repeated
    /// activation where that row was meets a control that only opens the
    /// guide, never an answer, which saves (docs/DECISIONS.md, "The first
    /// step's own rows"). Fails if Learn About Each Way's leading edge, top
    /// or width differ from the row's by more than a point, if it is
    /// shorter than the row, if any other button lies within the row's
    /// frame, if the first answer starts less than a row's gap below it, or
    /// if the question is gone.
    @MainActor
    func testTheFirstStepOpensWithLearnAboutEachWayOverSetUpStepByStep() {
        continueAfterFailure = true
        for textSize in [UITestTextSize.large, .ax5] {
            let app = openSettings(textSize: textSize)
            let context = "Step 1 of 6, \(textSize.name)"
            open("familySetup", in: app, waitingFor: "Family Setup")
            let row = app.buttons["guidedSetup"]
            XCTAssertTrue(row.waitForExistence(timeout: 10), "guidedSetup is missing (\(context))")
            let rowFrame = row.frame

            open("guidedSetup", in: app, waitingFor: "Step 1 of 6")
            let link = app.buttons["learnAboutEachWay"]
            XCTAssertTrue(link.waitForExistence(timeout: 10), "learnAboutEachWay is missing (\(context))")
            // Wait for Family Setup's row to go, so the step is read where it rests.
            let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: row)
            XCTAssertEqual(XCTWaiter.wait(for: [gone], timeout: 10), .completed, "Family Setup did not go (\(context))")
            XCTAssertTrue(app.staticTexts["How is the screen reached?"].exists, "the question is missing (\(context))")
            attachCapture(app, name: context)
            XCTAssertEqual(link.frame.minX, rowFrame.minX, accuracy: 1, "Learn About Each Way's leading edge moved (\(context))")
            XCTAssertEqual(link.frame.minY, rowFrame.minY, accuracy: 1, "Learn About Each Way's top moved (\(context))")
            XCTAssertEqual(link.frame.width, rowFrame.width, accuracy: 1, "Learn About Each Way is not the row's width (\(context))")
            XCTAssertGreaterThanOrEqual(
                link.frame.height, rowFrame.height - 1, "Learn About Each Way is shorter than the row (\(context))"
            )
            let spot = rowFrame.insetBy(dx: 0.5, dy: 0.5)
            for button in app.buttons.allElementsBoundByIndex
            where button.exists && button.identifier != "learnAboutEachWay" && button.frame.intersects(spot) && button.isHittable {
                XCTFail("\(button.label) lies where Set Up Step by Step was (\(context)): \(button.frame) against \(rowFrame)")
            }
            let first = app.buttons["Touch"]
            XCTAssertTrue(first.exists, "the first answer is missing (\(context))")
            XCTAssertGreaterThanOrEqual(
                first.frame.minY, link.frame.maxY + 16 - 1, "the first answer starts too near Learn About Each Way (\(context))"
            )
        }
    }

    // MARK: The check-in card

    /// The check-in card's rows, by identifier, with their words.
    private static let checkInRows = [
        ("checkInGoThrough", "Go Through Setup Again"), ("checkInNotNow", "Not Now"), ("checkInStopAsking", "Stop Asking"),
    ]

    /// Drags Family Setup's content a little at a time, from the gutter
    /// at the trailing side of its rows so no row is touched and the edge
    /// that swipes back is not either, until `element` lies wholly between
    /// the navigation bar and the foot of the content.
    @MainActor
    private func scrollIntoView(_ element: XCUIElement, in app: XCUIApplication, title: String, context: String) {
        let bar = app.navigationBars[title]
        for _ in 0..<40 {
            let frame = element.frame
            let (top, bottom) = (bar.frame.maxY, familySetupScroll(in: app).frame.maxY)
            if frame.minY >= top && frame.maxY <= bottom { return }
            if frame.maxY > bottom {
                dragFamilySetup(in: app, from: 0.75, to: 0.6)
            } else {
                dragFamilySetup(in: app, from: 0.6, to: 0.75)
            }
        }
        XCTFail("\(element.identifier) did not scroll into view at \(element.frame) (\(context))")
    }

    @MainActor
    private func familySetupScroll(in app: XCUIApplication) -> XCUIElement {
        app.scrollViews.containing(.button, identifier: "library").firstMatch
    }

    /// One slow drag of Family Setup's content, held at its end so it does
    /// not glide on, between two heights of the scroll view (0 its top, 1
    /// its foot), in the trailing gutter.
    @MainActor
    private func dragFamilySetup(in app: XCUIApplication, from: CGFloat, to: CGFloat) {
        let scroll = familySetupScroll(in: app)
        let origin = scroll.coordinate(withNormalizedOffset: .zero)
        let x = scroll.frame.width - 6
        origin.withOffset(CGVector(dx: x, dy: scroll.frame.height * from)).press(
            forDuration: 0.1, thenDragTo: origin.withOffset(CGVector(dx: x, dy: scroll.frame.height * to)),
            withVelocity: .slow, thenHoldForDuration: 0.1
        )
    }

    /// Family Setup's check-in card (`--check-in-due`), at the default text
    /// size, light and dark, and at the largest. Fails if a row of the card
    /// is missing, less than 44 points tall, or not across the content as
    /// Phrases and Categories is; if a row's words are not each drawn whole
    /// once the row is scrolled wholly into view (`RenderedWords`, without
    /// the expected words or language correction); or if Apple's
    /// accessibility audit finds anything with the card's rows in view.
    /// When Not Now and Stop Asking shared a row, each had about 111 points
    /// for its words at the largest size on CI's iPhone 17, where "Asking"
    /// is about 170 wide and "Stop" and "Now" about 115 (SF Pro Semibold at
    /// 55 points), so each broke mid-word.
    @MainActor
    func testTheCheckInCardDrawsItsWordsWholeAndPassesTheAudit() async throws {
        continueAfterFailure = true
        for (textSize, appearance) in [(UITestTextSize.large, UITestAppearance.light), (.large, .dark), (.ax5, .light)] {
            let app = openSettings(textSize: textSize, appearance: appearance, arguments: ["--check-in-due"])
            let context = "the check-in card, \(textSize.name), \(appearance.rawValue)"
            open("familySetup", in: app, waitingFor: "Family Setup")
            let library = app.buttons["library"]
            XCTAssertTrue(library.waitForExistence(timeout: 10), "Phrases and Categories is missing (\(context))")
            for (identifier, label) in Self.checkInRows {
                let row = app.buttons[identifier]
                XCTAssertTrue(row.waitForExistence(timeout: 10), "\(identifier) is missing (\(context))")
                guard row.exists else { continue }
                scrollIntoView(row, in: app, title: "Family Setup", context: context)
                XCTAssertGreaterThanOrEqual(row.frame.height, 44, "\(identifier) at \(row.frame) (\(context))")
                XCTAssertEqual(row.frame.minX, library.frame.minX, accuracy: 1, "\(identifier) is not across the content (\(context))")
                XCTAssertEqual(row.frame.width, library.frame.width, accuracy: 1, "\(identifier) is not across the content (\(context))")
                let screenshot = row.screenshot()
                let attachment = XCTAttachment(screenshot: screenshot)
                attachment.name = "\(context), \(identifier)"
                attachment.lifetime = .keepAlways
                add(attachment)
                let image = try XCTUnwrap(screenshot.image.cgImage)
                let words = try await RenderedWords.read(image)
                // Each word whole: a row's words may take several lines.
                XCTAssertTrue(
                    label.split(separator: " ").allSatisfy { RenderedWords.show(String($0), in: words) },
                    "Rendered \(label) is unreadable (\(context)); recognized \(words)"
                )
            }
            attachCapture(app, name: context)
            try assertPassesAccessibilityAudit(app, context: context)
        }
    }

    /// Go Through Setup Again chosen with Family Setup scrolled, at the
    /// default text size and the largest: fails if the first step it opens
    /// does not have Learn About Each Way where the button showed as it was
    /// chosen (the same leading edge, top and width, and at least as tall),
    /// where a look on the button still rests. Placed from the button's
    /// place in Family Setup's content, it lay as far lower as Family Setup
    /// had scrolled, and the chain model found a held look there meeting
    /// Back to Talking (`SettingsChainsTests`).
    @MainActor
    func testGoThroughSetupAgainOpensItsStepWhereItShowed() {
        continueAfterFailure = true
        for textSize in [UITestTextSize.large, .ax5] {
            let app = openSettings(textSize: textSize, arguments: ["--check-in-due"])
            let context = "Go Through Setup Again, Family Setup scrolled, \(textSize.name)"
            open("familySetup", in: app, waitingFor: "Family Setup")
            let goThrough = app.buttons["checkInGoThrough"]
            let guided = app.buttons["guidedSetup"]
            XCTAssertTrue(goThrough.waitForExistence(timeout: 10), "checkInGoThrough is missing (\(context))")
            guard goThrough.exists, guided.exists else { continue }
            let unscrolled = guided.frame
            dragFamilySetup(in: app, from: 0.6, to: 0.45)
            scrollIntoView(goThrough, in: app, title: "Family Setup", context: context)
            // Read where it rests, not while it settles.
            var shown = goThrough.frame
            for _ in 0..<10 {
                let again = goThrough.frame
                if again == shown { break }
                shown = again
            }
            XCTAssertLessThan(guided.frame.minY, unscrolled.minY - 1, "Family Setup did not scroll (\(context))")
            goThrough.tap()
            let link = app.buttons["learnAboutEachWay"]
            XCTAssertTrue(link.waitForExistence(timeout: 10), "Go Through Setup Again did not open the first step (\(context))")
            let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: app.buttons["library"])
            XCTAssertEqual(XCTWaiter.wait(for: [gone], timeout: 10), .completed, "Family Setup did not go (\(context))")
            attachCapture(app, name: context)
            let frame = link.frame
            XCTAssertEqual(frame.minX, shown.minX, accuracy: 1, "Learn About Each Way at \(frame), the button at \(shown) (\(context))")
            XCTAssertEqual(frame.minY, shown.minY, accuracy: 1, "Learn About Each Way at \(frame), the button at \(shown) (\(context))")
            XCTAssertEqual(frame.width, shown.width, accuracy: 1, "Learn About Each Way at \(frame), the button at \(shown) (\(context))")
            XCTAssertGreaterThanOrEqual(frame.height, shown.height - 1, "Learn About Each Way at \(frame), the button at \(shown) (\(context))")
        }
    }

    /// Stop Asking and Not Now, at the default text size. Fails if a row of
    /// the card is still there once it is answered, if the words saying
    /// what happens next do not show, or if any of Family Setup's rows
    /// moves (each measured from Set Up Step by Step, so scrolling to reach
    /// a row does not count): rows moving up under the button just chosen
    /// could be opened by a held look (invariant 10). After Not Now, fails
    /// if the next launch shows the card or its words again.
    @MainActor
    func testAnsweringTheCheckInKeepsItsPlace() {
        continueAfterFailure = true
        let others = ["library", "voiceSettings", "reachingTheScreen", "keepOpen", "about"]
        for (identifier, afterword) in [
            ("checkInStopAsking", "Check-ins are off. Set Up Step by Step is always here."),
            ("checkInNotNow", "Family Setup will ask again in 30 days."),
        ] {
            let app = openSettings(arguments: ["--check-in-due"])
            let context = "\(identifier), default text"
            open("familySetup", in: app, waitingFor: "Family Setup")
            let guided = app.buttons["guidedSetup"]
            XCTAssertTrue(guided.waitForExistence(timeout: 10), "guidedSetup is missing (\(context))")
            func offsets() -> [String: CGFloat] {
                Dictionary(uniqueKeysWithValues: others.map { ($0, app.buttons[$0].frame.minY - guided.frame.minY) })
            }
            let before = offsets()
            app.buttons[identifier].tap()
            XCTAssertTrue(app.staticTexts[afterword].waitForExistence(timeout: 10), "\(afterword) did not show (\(context))")
            attachCapture(app, name: context)
            for (row, _) in Self.checkInRows {
                XCTAssertFalse(app.buttons[row].exists, "\(row) is still there once the check-in was answered (\(context))")
            }
            for (name, offset) in offsets() {
                XCTAssertEqual(offset, before[name] ?? .nan, accuracy: 1, "\(name) moved once the check-in was answered (\(context))")
            }
        }

        // The answer is kept: launched again without making a check-in due.
        let again = openSettings(storage: .kept)
        open("familySetup", in: again, waitingFor: "Family Setup")
        XCTAssertTrue(again.buttons["library"].waitForExistence(timeout: 10), "Family Setup did not open again")
        XCTAssertFalse(again.buttons["checkInGoThrough"].exists, "the check-in card came back the next launch after Not Now")
        XCTAssertFalse(
            again.staticTexts["Family Setup will ask again in 30 days."].exists, "Not Now's words came back the next launch"
        )
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

    /// Every guide in Family Setup, and About, passes the audit. Two titles
    /// carry the app's name, which is not final, so each guide is known by
    /// words of its own instead of its title.
    @MainActor
    func testFamilySetupGuidesPassTheAccessibilityAudit() throws {
        continueAfterFailure = true
        let guides: [(row: String, name: String, words: String)] = [
            ("reachingTheScreen", "Reaching the Screen", "needs no setup of its own"),
            ("keepOpen", "Keep Open", "Guided Access and turn it on"),
            ("callsSiriAndShortcuts", "Calls, Siri and Shortcuts", "Live Speech"),
            ("moreAccessibility", "More Accessibility Settings", "Accessibility Shortcut"),
            ("about", "About", "Version"),
        ]
        let app = openSettings()
        open("familySetup", in: app, waitingFor: "Family Setup")
        for guide in guides {
            let row = app.buttons[guide.row].firstMatch
            XCTAssertTrue(row.waitForExistence(timeout: 10), "\(guide.row) is missing")
            row.tap()
            let words = app.descendants(matching: .any)
                .matching(NSPredicate(format: "label CONTAINS %@", guide.words))
                .firstMatch
            XCTAssertTrue(
                words.waitForExistence(timeout: 10),
                "\(guide.name) did not open, or no longer says \"\(guide.words)\""
            )
            attachCapture(app, name: guide.name)
            try assertPassesAccessibilityAudit(app, context: "\(guide.name), light")

            app.navigationBars.buttons.element(boundBy: 0).tap()
            XCTAssertTrue(
                app.navigationBars["Family Setup"].waitForExistence(timeout: 10),
                "Back from \(guide.name) did not return to Family Setup"
            )
        }
    }

    /// Each step of Set Up Step by Step passes the audit.
    @MainActor
    func testTheStepByStepSetupPassesTheAccessibilityAudit() throws {
        continueAfterFailure = true
        let app = openSettings()
        open("familySetup", in: app, waitingFor: "Family Setup")
        open("guidedSetup", in: app, waitingFor: "Step 1 of 6")
        try assertPassesAccessibilityAudit(app, context: "Step 1 of 6, light")

        // The first step's guide, a cover of its own.
        app.buttons["learnAboutEachWay"].tap()
        let done = app.buttons["eachWayDone"]
        XCTAssertTrue(done.waitForExistence(timeout: 10), "Learn About Each Way did not open the guide")
        attachCapture(app, name: "Each Way guide")
        try assertPassesAccessibilityAudit(app, context: "Each Way guide, light")
        done.tap()
        let closed = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: done)
        XCTAssertEqual(XCTWaiter.wait(for: [closed], timeout: 10), .completed, "Done did not close the guide")

        for step in 2...6 {
            app.buttons["guidedSetupNext"].tap()
            XCTAssertTrue(app.navigationBars["Step \(step) of 6"].waitForExistence(timeout: 10), "step \(step) did not open")
            attachCapture(app, name: "Step \(step) of 6")
            try assertPassesAccessibilityAudit(app, context: "Step \(step) of 6, light")
        }
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

    /// Voice Settings' Ask button for Personal Voice, reached with a
    /// stand-in permission that refuses (`--personal-voice=stand-in-refuses`;
    /// the real one shows iOS's question, which a UI test cannot answer
    /// reliably). After the answer, the button's place holds passive words,
    /// no button is where it was, nothing below the card moves, and Open
    /// Personal Voice Settings waits for the next visit (AGENTS.md,
    /// invariant 10). Fails if any of those changes, or if the button is
    /// missing when the question is left to this screen.
    @MainActor
    func testAnsweringTheAskButtonMovesNothing() throws {
        continueAfterFailure = true
        for textSize in [UITestTextSize.large, .ax5] {
            let app = openSettings(textSize: textSize, arguments: ["--personal-voice=stand-in-refuses"])
            let context = "Voice Settings, Ask, \(textSize.name)"
            open("familySetup", in: app, waitingFor: "Family Setup")
            open("voiceSettings", in: app, waitingFor: "Voice Settings")

            let ask = app.buttons["askPersonalVoice"]
            guard ask.waitForExistence(timeout: 10) else {
                XCTFail("the Ask button is missing (\(context))")
                continue
            }
            if textSize == .large {
                try assertPassesAccessibilityAudit(app, context: context)
            }
            attachCapture(app, name: "\(context), before the answer")
            let heading = app.staticTexts["Speed"]
            let askBefore = ask.frame
            let headingBefore = heading.frame

            ask.tap()

            let answered = app.descendants(matching: .any)["personalVoiceAsked"]
            XCTAssertTrue(answered.waitForExistence(timeout: 10), "the Ask button's place does not hold its words after the answer (\(context))")
            attachCapture(app, name: "\(context), after a refusal")
            XCTAssertFalse(ask.exists, "the Ask button is still offered after the answer (\(context))")
            XCTAssertFalse(
                app.buttons["Open Personal Voice Settings"].exists,
                "a button that leaves the app appeared on the visit that asked (\(context))"
            )
            // Measured from the Speed heading, so a scroll made by the tap
            // does not count as a move.
            XCTAssertEqual(
                heading.frame.minY - answered.frame.minY, headingBefore.minY - askBefore.minY, accuracy: 0.5,
                "the answer moved the Ask button's place or the speeds below it (\(context))"
            )
            let scrolled = heading.frame.minY - headingBefore.minY
            let spot = CGPoint(x: askBefore.midX, y: askBefore.midY + scrolled)
            // Home stays in the tree under the Settings cover, so only a
            // button that can be activated counts (CI on PR #27 found
            // Home's "I don't know." tile under the spot on an iPhone).
            for button in app.buttons.allElementsBoundByIndex
            where button.exists && button.frame.contains(spot) && button.isHittable {
                XCTFail("\(button.label) is where the Ask button was (\(context))")
            }
        }
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
        open("guidedSetup", in: app, waitingFor: "Step 1 of 6")

        // The first answer, which shows without scrolling at the default
        // text size: the answers start below Learn About Each Way.
        app.buttons["Touch"].tap()
        XCTAssertTrue(app.buttons["Touch"].isSelected, "choosing an answer did not select it")
        // A second activation keeps it chosen: answers only select.
        app.buttons["Touch"].tap()
        XCTAssertTrue(app.buttons["Touch"].isSelected, "a repeated activation undid the answer")

        for step in 2...6 {
            app.buttons["guidedSetupNext"].tap()
            XCTAssertTrue(app.navigationBars["Step \(step) of 6"].waitForExistence(timeout: 10), "step \(step) did not open")
            if step == 2 {
                // Until a category is chosen, Home shows every category.
                XCTAssertTrue(app.buttons["restBoardEveryCategory"].isSelected, "Every Category is not chosen before anything is")
            }
        }
        XCTAssertTrue(app.staticTexts["Touch"].exists, "the summary does not list the answer")
        XCTAssertTrue(app.staticTexts["Home shows every category."].exists, "the summary does not say which phrases Home shows")

        app.buttons["guidedSetupNext"].tap()
        XCTAssertTrue(app.navigationBars["Family Setup"].waitForExistence(timeout: 10), "Done did not return to Family Setup")
    }
}
