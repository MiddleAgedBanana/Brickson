import XCTest

/// Home's layout in the running app: the starter library needs no
/// scrolling, every tile keeps its place whichever category shows, and the
/// safety row and Settings are wholly on screen, at the default text size and the
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

    /// Read every tile from one accessibility snapshot. Asking each live
    /// element for its frame repeats the remote hierarchy query for every
    /// tile; walking a snapshot keeps the same checks with one query.
    @MainActor
    private func tileFrames(in app: XCUIApplication) throws -> [CGRect] {
        var pending: [any XCUIElementSnapshot] = [try app.snapshot()]
        var frames: [CGRect] = []
        while let element = pending.popLast() {
            if element.elementType == .button && element.identifier == "phraseTile" {
                frames.append(element.frame)
            }
            pending.append(contentsOf: element.children)
        }
        return frames.sorted { ($0.minY.rounded(), $0.minX) < ($1.minY.rounded(), $1.minX) }
    }

    /// Whether every tile must lie inside the window. A narrow window at the
    /// largest text size is the recorded exception: its controls grow to hold
    /// their words, and the grid scrolls there (docs/DECISIONS.md, "Home's
    /// stand-in layout", *Where the grid still scrolls*). 592pt is Home's
    /// 560pt regular content width plus its margins.
    private static func gridMustFit(_ textSize: UITestTextSize, in window: CGRect) -> Bool {
        !(textSize == .ax5 && window.width < 592)
    }

    /// Waits up to 10 s for Home to lay itself out in the orientation asked
    /// for: until the window has turned and, where the grid must fit, its
    /// first and last tiles lie inside it. A query straight after a rotation
    /// can read the frames from before the turn. Where the grid may scroll,
    /// only the turn is waited for, so the wait ends as soon as it can. If the
    /// endpoints never fit, the wait fails. This only waits for layout;
    /// the snapshot checks below still verify every tile, including any
    /// middle tile that could extend beyond the window or change its slot.
    @MainActor
    private func waitForLayout(in app: XCUIApplication, landscape: Bool, textSize: UITestTextSize) {
        let tiles = app.buttons.matching(identifier: "phraseTile")
        let count = tiles.count
        guard count > 0 else {
            XCTFail("Home shows no phrase tiles (\(textSize.name))")
            return
        }
        let first = tiles.element(boundBy: 0)
        let last = tiles.element(boundBy: count - 1)
        let settled = NSPredicate { _, _ in
            MainActor.assumeIsolated {
                let window = app.windows.firstMatch.frame
                guard (window.width > window.height) == landscape else { return false }
                guard Self.gridMustFit(textSize, in: window) else { return true }
                return window.contains(first.frame) && window.contains(last.frame)
            }
        }
        XCTAssertEqual(
            XCTWaiter.wait(for: [expectation(for: settled, evaluatedWith: nil)], timeout: 10),
            .completed, "Home did not finish laying out (\(textSize.name), landscape: \(landscape))"
        )
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
    func testTheStarterLibraryFitsWithoutScrolling() throws {
        for textSize in [UITestTextSize.large, .ax5] {
            for orientation in [UIDeviceOrientation.portrait, .landscapeLeft] {
                // The iPhone is portrait-only for now (AppBundleTests,
                // theIPhoneIsPortraitOnly), so it has no landscape to check.
                if orientation.isLandscape && UIDevice.current.userInterfaceIdiom == .phone {
                    continue
                }
                let app = launchedApp(textSize: textSize, orientation: orientation)
                waitForLayout(in: app, landscape: orientation.isLandscape, textSize: textSize)
                let window = app.windows.firstMatch.frame
                let isLandscape = window.width > window.height
                // An iPad that does not turn is a failure, not a skip.
                if orientation.isLandscape && !isLandscape {
                    XCTFail("the iPad did not turn to landscape (\(textSize.name), window \(window.size))")
                    app.terminate()
                    continue
                }
                let context = "\(textSize.name), \(isLandscape ? "landscape" : "portrait"), window \(window.size)"
                // Where the grid may scroll, everything else is still
                // checked, slots included.
                let gridMustFit = Self.gridMustFit(textSize, in: window)

                for name in ["Yes", "No", "Emergency", "Again", "Settings"] {
                    expectWhollyOnScreen(app.buttons[name], name, in: window, context)
                }

                var slots: [CGRect] = []
                for category in Self.everydayCategories + ["Emergency"] {
                    let button = app.buttons[category]
                    expectWhollyOnScreen(button, "the \(category) button", in: window, context)
                    button.tap()
                    // The old category's tiles already fit, so wait for the
                    // new one to be selected before reading its tiles.
                    let selected = expectation(for: NSPredicate(format: "isSelected == true"), evaluatedWith: button)
                    XCTAssertEqual(
                        XCTWaiter.wait(for: [selected], timeout: 10), .completed,
                        "\(category) was not selected (\(context))"
                    )
                    waitForLayout(in: app, landscape: isLandscape, textSize: textSize)
                    let frames = try tileFrames(in: app)
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
