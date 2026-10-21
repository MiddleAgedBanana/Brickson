import XCTest

/// Home's layout in the running app: the starter library needs no
/// scrolling, every tile keeps its place whichever category shows, and the
/// quick controls are wholly on screen, at the default text size and the
/// largest accessibility size, in each orientation the device turns to.
///
/// What it measures is the simulator CI runs on, named in each failure and
/// in the attached screenshots. It says nothing about gaze comfort or Snap to
/// Item; those need a device (docs/HANDOFF.md).
final class HomeLayoutTests: XCTestCase {
    /// The starter library's everyday categories, in order, and the size of
    /// the largest. A test target cannot read the app's bundle, so these are
    /// copied from Brickson/Resources/StarterPhrases.json; a change there that
    /// misses this list fails `testTheStarterLibraryFitsWithoutScrolling`.
    private static let everydayCategories = ["Basics", "Needs", "Conversation", "Feelings"]
    private static let largestCategoryCount = 8

    private static let textSizes = [
        ("default text", nil as String?),
        ("AX5 text", "UICTContentSizeCategoryAccessibilityXXXL"),
    ]

    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    override func tearDown() {
        XCUIDevice.shared.orientation = .portrait
        super.tearDown()
    }

    @MainActor
    private func launchHome(textSize: String?) -> XCUIApplication {
        let app = XCUIApplication()
        if let textSize {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", textSize]
        }
        app.launch()
        XCTAssertTrue(app.buttons["Yes"].waitForExistence(timeout: 15), "Home did not appear")
        return app
    }

    /// The phrase tiles showing now, in reading order (row by row).
    @MainActor
    private func tileFrames(in app: XCUIApplication) -> [CGRect] {
        app.buttons.matching(identifier: "phraseTile").allElementsBoundByIndex
            .map(\.frame)
            .sorted { ($0.minY.rounded(), $0.minX) < ($1.minY.rounded(), $1.minX) }
    }

    @MainActor
    private func expectWhollyOnScreen(
        _ element: XCUIElement, _ name: String, in window: CGRect, _ context: String
    ) {
        XCTAssertTrue(element.exists, "\(name) is missing (\(context))")
        XCTAssertTrue(element.isHittable, "\(name) cannot be reached (\(context))")
        XCTAssertTrue(
            window.contains(element.frame),
            "\(name) at \(element.frame) is not wholly inside the window \(window) (\(context))"
        )
    }

    /// Fails if Home scrolls or cuts off a tile for the starter library
    /// (invariant 11 for the windows CI runs), or if a tile's place depends
    /// on which category shows (invariant 8).
    @MainActor
    func testTheStarterLibraryFitsWithoutScrolling() {
        for (sizeName, textSize) in Self.textSizes {
            let app = launchHome(textSize: textSize)
            for orientation in [UIDeviceOrientation.portrait, .landscapeLeft] {
                XCUIDevice.shared.orientation = orientation
                let window = app.windows.firstMatch.frame
                let isLandscape = window.width > window.height
                // The iPhone is portrait-only for now (AppBundleTests,
                // theIPhoneIsPortraitOnly), so it has no landscape to check.
                if orientation == .landscapeLeft && !isLandscape { continue }
                let context = "\(sizeName), \(isLandscape ? "landscape" : "portrait"), window \(window.size)"

                for name in ["Yes", "No", "Emergency", "Again"] {
                    expectWhollyOnScreen(app.buttons[name], name, in: window, context)
                }

                var slots: [CGRect] = []
                for category in Self.everydayCategories + ["Emergency"] {
                    let button = app.buttons[category]
                    expectWhollyOnScreen(button, "the \(category) button", in: window, context)
                    button.tap()
                    let frames = tileFrames(in: app)
                    XCTAssertFalse(frames.isEmpty, "\(category) shows no tiles (\(context))")
                    if frames.count == Self.largestCategoryCount && slots.isEmpty {
                        slots = frames
                    }
                    for (index, frame) in frames.enumerated() {
                        XCTAssertTrue(
                            window.contains(frame),
                            "\(category) tile \(index + 1) at \(frame) is cut off or scrolled away (\(context))"
                        )
                        if index < slots.count {
                            XCTAssertEqual(
                                frame.origin.x, slots[index].origin.x, accuracy: 0.5,
                                "\(category) tile \(index + 1) moved sideways (\(context))"
                            )
                            XCTAssertEqual(
                                frame.origin.y, slots[index].origin.y, accuracy: 0.5,
                                "\(category) tile \(index + 1) moved up or down (\(context))"
                            )
                        }
                    }
                }
                XCTAssertEqual(slots.count, Self.largestCategoryCount, "no category had the largest count (\(context))")

                let screenshot = XCTAttachment(screenshot: app.screenshot())
                screenshot.name = "Home, \(context)"
                screenshot.lifetime = .keepAlways
                add(screenshot)
            }
            app.terminate()
        }
    }
}
