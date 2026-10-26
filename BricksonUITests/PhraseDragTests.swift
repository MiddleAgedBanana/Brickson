import XCTest

/// A vertical phrase-grid drag must not speak. The old private probe
/// assumed a gutter was inert and combined recorded geometry with live
/// coordinates. This test rejects a mismatched coordinate before input,
/// then checks both a gutter start and a start inside an actual tile.
final class PhraseDragTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    func testDefaultLight() throws { try checkDrags(textSize: .large, appearance: .light) }

    @MainActor
    func testDefaultDark() throws { try checkDrags(textSize: .large, appearance: .dark) }

    @MainActor
    func testAX5Light() throws { try checkDrags(textSize: .ax5, appearance: .light) }

    @MainActor
    func testAX5Dark() throws { try checkDrags(textSize: .ax5, appearance: .dark) }

    /// Removing the ordinary Button's hold activation, or adding the
    /// large content viewer to tiles, must fail this first-press check.
    @MainActor
    func testAHeldPhraseSpeaksAtAX5() throws {
        let app = launchedApp(textSize: .ax5)
        defer { app.terminate() }
        let tile = try XCTUnwrap(
            app.buttons.matching(identifier: "phraseTile").allElementsBoundByIndex.first { $0.isHittable },
            "No phrase tile can be held at AX5"
        )
        let words = tile.label
        let messageRegion = app.descendants(matching: .any)["homeRegion.message"]
        XCTAssertTrue(messageRegion.exists)
        XCTAssertFalse(messageRegion.staticTexts[words].exists)
        tile.press(forDuration: 1.5)
        XCTAssertTrue(
            messageRegion.staticTexts[words].waitForExistence(timeout: 5),
            "The first 1.5-second hold on a phrase did not speak"
        )
        attachCapture(app, name: "after-held-phrase")
    }

    @MainActor
    private func checkDrags(textSize: UITestTextSize, appearance: UITestAppearance) throws {
        for startsOnTile in [false, true] {
            try checkDrag(textSize: textSize, appearance: appearance, startsOnTile: startsOnTile)
        }
    }

    @MainActor
    private func checkDrag(textSize: UITestTextSize, appearance: UITestAppearance, startsOnTile: Bool) throws {
        let app = launchedApp(textSize: textSize, appearance: appearance)
        defer { app.terminate() }
        try assertPassesAccessibilityAudit(app, context: "before phrase drag")
        let view = app.scrollViews["homeRegion.phrases"]
        XCTAssertTrue(view.waitForExistence(timeout: 10))
        let snapshot = try app.snapshot()
        let beforeFrames = try controlFrames(in: snapshot)
        let located = try SnapshotControlGeometry.locate(
            in: snapshot, frame: { $0.frame }, isWindow: { $0.elementType == .window },
            target: .init(identifier: "homeRegion.phrases", label: ""),
            identity: { $0.elementType == .scrollView ? .init(identifier: $0.identifier, label: $0.label) : nil },
            children: { $0.children }
        )
        let viewport = located.control
        var tiles: [(label: String, frame: CGRect)] = []
        func collect(_ node: any XCUIElementSnapshot) {
            if node.elementType == .button && node.identifier == "phraseTile" {
                tiles.append((node.label, node.frame))
            }
            for child in node.children { collect(child) }
        }
        collect(snapshot)
        tiles = tiles
            .sorted { ($0.frame.minY, $0.frame.minX) < ($1.frame.minY, $1.frame.minX) }
        XCTAssertEqual(tiles.count, 8)
        XCTAssertTrue(located.window.contains(viewport))
        let first = try XCTUnwrap(tiles.first)
        let nextColumn = try XCTUnwrap(tiles.first { abs($0.frame.minY - first.frame.minY) < 1 && $0.frame.minX > first.frame.maxX })
        XCTAssertGreaterThan(viewport.height, 80)
        let gutterX = (first.frame.maxX + nextColumn.frame.minX) / 2
        let x = startsOnTile ? first.frame.midX : gutterX
        let fraction = (x - viewport.minX) / viewport.width
        let start = view.coordinate(withNormalizedOffset: CGVector(dx: fraction, dy: 0.9))
        // A real scroll attempt need not cross an entire row. On a
        // fitting grid, this 80pt drag can end inside its starting tile.
        let endY = startsOnTile ? 0.9 - min(80, viewport.height * 0.8) / viewport.height : 0.1
        let end = view.coordinate(withNormalizedOffset: CGVector(dx: fraction, dy: endY))
        let windows = app.windows.containing(.scrollView, identifier: "homeRegion.phrases")
        XCTAssertEqual(windows.count, 1)
        let liveWindow = windows.element(boundBy: 0).frame
        // A windowed iPad snapshot can use a window-local origin while
        // live queries include the window's position on the display.
        let dx = liveWindow.minX - located.window.minX
        let dy = liveWindow.minY - located.window.minY
        let screenViewport = viewport.offsetBy(dx: dx, dy: dy)
        let receipt = XCTAttachment(string: "tileStart=\(startsOnTile) window=\(located.window) liveWindow=\(liveWindow) viewport=\(viewport) tiles=\(tiles) start=\(start.screenPoint) end=\(end.screenPoint)")
        receipt.name = "phrase-drag-coordinates"
        receipt.lifetime = .keepAlways
        add(receipt)
        attachCapture(app, name: "before-phrase-drag")
        let messages = tiles.map(\.label) + ["Yes.", "No."]
        let messageRegion = app.descendants(matching: .any)["homeRegion.message"]
        XCTAssertTrue(messageRegion.exists)
        let message = messageRegion.staticTexts.matching(NSPredicate(format: "label IN %@", messages)).firstMatch
        XCTAssertFalse(message.exists, "Speech had already changed the fresh Home before input")
        XCTAssertFalse(app.staticTexts["Speaking"].exists)
        // Fail before injecting if a rotated surface remapped coordinates.
        let live = view.frame
        // Native snapshot rounding can differ by a fraction of a point;
        // the same half-point allowance still rejects the 180° mismatch.
        XCTAssertEqual(liveWindow.width, located.window.width, accuracy: 0.5)
        XCTAssertEqual(liveWindow.height, located.window.height, accuracy: 0.5)
        XCTAssertEqual(live.minX, screenViewport.minX, accuracy: 0.5)
        XCTAssertEqual(live.minY, screenViewport.minY, accuracy: 0.5)
        XCTAssertEqual(live.width, viewport.width, accuracy: 0.5)
        XCTAssertEqual(live.height, viewport.height, accuracy: 0.5)
        XCTAssertEqual(start.screenPoint.x, x + dx, accuracy: 0.5)
        XCTAssertEqual(start.screenPoint.y, screenViewport.minY + viewport.height * 0.9, accuracy: 0.5)
        XCTAssertEqual(end.screenPoint.x, x + dx, accuracy: 0.5)
        XCTAssertEqual(end.screenPoint.y, screenViewport.minY + viewport.height * endY, accuracy: 0.5)
        if startsOnTile {
            XCTAssertTrue(tiles.contains { $0.frame.offsetBy(dx: dx, dy: dy).contains(start.screenPoint) }, "Tile-start drag must begin inside a real tile")
        }
        start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.1)
        // A message remains after speech completes, so this detects an
        // activation even when the transient Speaking line has disappeared.
        let spoke = message.waitForExistence(timeout: 3)
        attachCapture(app, name: "after-phrase-drag")
        XCTAssertFalse(spoke, "A vertical phrase-grid drag spoke a phrase")
        XCTAssertFalse(app.staticTexts["Speaking"].exists)
        XCTAssertFalse(app.staticTexts["Sounding"].exists)
        // Compare one coherent snapshot on each side of the completed
        // gesture. Each frame uses its own ancestor window's origin, so
        // moving an iPad window on the display cannot mask a Home reflow.
        let afterSnapshot = try app.snapshot()
        let afterFrames = try controlFrames(in: afterSnapshot)
        XCTAssertGreaterThanOrEqual(beforeFrames.staticButtons.count, 12)
        try assertUnchanged(beforeFrames.staticButtons, afterFrames.staticButtons, context: "static Home controls")
        // An overflowing touch library may scroll. A fitting grid must
        // settle with every tile where it started, at native precision.
        let fittingGrid = tiles.allSatisfy { viewport.insetBy(dx: -0.5, dy: -0.5).contains($0.frame) }
        if fittingGrid {
            try assertUnchanged(beforeFrames.tiles, afterFrames.tiles, context: "fitting phrase grid")
        }

        // Keeping drags quiet must not swallow the next intentional tap.
        // Re-query after any permitted scroll rather than tapping a stale
        // element or resetting the grid's position to make the tap pass.
        let tappedTile = try XCTUnwrap(
            app.buttons.matching(identifier: "phraseTile").allElementsBoundByIndex.first { $0.isHittable },
            "No phrase remains tappable after the drag"
        )
        let words = tappedTile.label
        tappedTile.tap()
        XCTAssertTrue(
            messageRegion.staticTexts[words].waitForExistence(timeout: 5),
            "The first ordinary phrase tap after the drag did not speak"
        )
    }

    private struct ControlKey: Hashable {
        let identifier: String
        let label: String
    }

    private struct ControlFrames {
        var staticButtons: [ControlKey: CGRect] = [:]
        var tiles: [ControlKey: CGRect] = [:]
    }

    /// Window-local frames from a single accessibility snapshot, never
    /// individual live frame queries mixed across an animation.
    @MainActor
    private func controlFrames(in root: any XCUIElementSnapshot) throws -> ControlFrames {
        var result = ControlFrames()
        func collect(_ node: any XCUIElementSnapshot, window: CGRect?) throws {
            let ancestor = node.elementType == .window ? node.frame : window
            if node.elementType == .button {
                let window = try XCTUnwrap(ancestor, "A Home button has no ancestor window")
                let key = ControlKey(identifier: node.identifier, label: node.label)
                let frame = node.frame.offsetBy(dx: -window.minX, dy: -window.minY)
                if node.identifier == "phraseTile" {
                    XCTAssertNil(result.tiles.updateValue(frame, forKey: key), "Duplicate phrase identity in snapshot")
                } else {
                    XCTAssertNil(result.staticButtons.updateValue(frame, forKey: key), "Duplicate Home control identity in snapshot")
                }
            }
            for child in node.children { try collect(child, window: ancestor) }
        }
        try collect(root, window: nil)
        return result
    }

    @MainActor
    private func assertUnchanged(
        _ before: [ControlKey: CGRect], _ after: [ControlKey: CGRect], context: String
    ) throws {
        XCTAssertEqual(Set(before.keys), Set(after.keys), "Control identities changed in \(context)")
        for (key, old) in before {
            let current = try XCTUnwrap(after[key], "A control disappeared from \(context)")
            let name = key.identifier.isEmpty ? key.label : key.identifier
            XCTAssertEqual(current.minX, old.minX, accuracy: 0.5, "\(name) moved horizontally in \(context)")
            XCTAssertEqual(current.minY, old.minY, accuracy: 0.5, "\(name) moved vertically in \(context)")
            XCTAssertEqual(current.width, old.width, accuracy: 0.5, "\(name) changed width in \(context)")
            XCTAssertEqual(current.height, old.height, accuracy: 0.5, "\(name) changed height in \(context)")
        }
    }
}
