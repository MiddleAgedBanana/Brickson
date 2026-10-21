import XCTest

/// Home's layout in the running app: the starter library needs no
/// scrolling, every tile keeps its place whichever category shows, and the
/// quick controls are wholly on screen, at the default text size and the
/// largest accessibility size, in each orientation the device turns to. The
/// one recorded exception is a narrow window at the largest size, where the
/// grid scrolls; its other checks still run.
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

    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    /// The phrase tiles showing now, in reading order (row by row).
    @MainActor
    private func tileFrames(in app: XCUIApplication) -> [CGRect] {
        app.buttons.matching(identifier: "phraseTile").allElementsBoundByIndex
            .map(\.frame)
            .sorted { ($0.minY.rounded(), $0.minX) < ($1.minY.rounded(), $1.minX) }
    }

    /// Waits up to 10 s for Home to lay itself out in the orientation asked
    /// for: until the window has turned and every phrase tile's frame lies
    /// inside it. A query straight after a rotation can read the frames from
    /// before the turn. If the tiles never fit, this returns after 10 s and the
    /// checks that follow report them.
    @MainActor
    private func waitForLayout(in app: XCUIApplication, landscape: Bool) {
        let settled = NSPredicate { _, _ in
            MainActor.assumeIsolated {
                let window = app.windows.firstMatch.frame
                guard (window.width > window.height) == landscape else { return false }
                return self.tileFrames(in: app).allSatisfy { window.contains($0) }
            }
        }
        _ = XCTWaiter.wait(for: [expectation(for: settled, evaluatedWith: nil)], timeout: 10)
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
        for textSize in [UITestTextSize.large, .ax5] {
            for orientation in [UIDeviceOrientation.portrait, .landscapeLeft] {
                let app = launchedApp(textSize: textSize, orientation: orientation)
                waitForLayout(in: app, landscape: orientation.isLandscape)
                let window = app.windows.firstMatch.frame
                let isLandscape = window.width > window.height
                // The iPhone is portrait-only for now (AppBundleTests,
                // theIPhoneIsPortraitOnly), so it has no landscape to check.
                if orientation == .landscapeLeft && !isLandscape {
                    app.terminate()
                    continue
                }
                let context = "\(textSize.name), \(isLandscape ? "landscape" : "portrait"), window \(window.size)"
                // A narrow window at the largest text size is the recorded
                // exception: its controls grow to hold their words, and the
                // grid scrolls there (docs/DECISIONS.md, "Home's stand-in
                // layout", *Where the grid still scrolls*). Everything else is
                // still checked there, slots included. 592pt is Home's
                // 560pt regular content width plus its margins.
                let gridMustFit = !(textSize == .ax5 && window.width < 592)

                for name in ["Yes", "No", "Emergency", "Again"] {
                    expectWhollyOnScreen(app.buttons[name], name, in: window, context)
                }

                var slots: [CGRect] = []
                for category in Self.everydayCategories + ["Emergency"] {
                    let button = app.buttons[category]
                    expectWhollyOnScreen(button, "the \(category) button", in: window, context)
                    button.tap()
                    waitForLayout(in: app, landscape: isLandscape)
                    let frames = tileFrames(in: app)
                    XCTAssertFalse(frames.isEmpty, "\(category) shows no tiles (\(context))")
                    if frames.count == Self.largestCategoryCount && slots.isEmpty {
                        slots = frames
                    }
                    for (index, frame) in frames.enumerated() {
                        if gridMustFit {
                            XCTAssertTrue(
                                window.contains(frame),
                                "\(category) tile \(index + 1) at \(frame) is cut off or scrolled away (\(context))"
                            )
                        }
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

                attachCapture(app, name: "Home, \(context)")
                app.terminate()
            }
        }
    }
}
