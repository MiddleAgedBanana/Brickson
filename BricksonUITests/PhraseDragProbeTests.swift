import XCTest

/// What a touch that moves before it lifts does on Home: on Yes, on a
/// phrase tile and in the gutter between two tiles, in each direction and
/// over a range of distances. Opt-in: skipped unless the test runner's
/// environment has BRICKSON_DRAG_PROBE=1, passed on by xcodebuild with a
/// TEST_RUNNER_ prefix:
///
///     TEST_RUNNER_BRICKSON_DRAG_PROBE=1 scripts/test.sh ui '-only-testing:BricksonUITests/PhraseDragProbeTests'
///
/// Each gesture starts from a fresh launch at the default text size and
/// attaches one line, `DRAG-PROBE {json}`: where the touch began and
/// ended, whether the phrase grid fits its viewport, and which sentence
/// Home showed afterwards ("Yes.", "No.", a phrase, or nothing). It asserts
/// nothing about the outcome: the record compares runs with and without
/// the phrase grid's drag cancellation (docs/DECISIONS.md, "Phrase-grid
/// drag cancellation"). A gesture whose synthesised start or end point
/// does not land where it was aimed (XCTest's rotated iPhone Duo surface)
/// is reported as such and not sent. These are simulator touches that
/// XCTest synthesises, never evidence of a real finger, dwell or a head
/// pointer.
final class PhraseDragProbeTests: XCTestCase {
    private static let isEnabled = ProcessInfo.processInfo.environment["BRICKSON_DRAG_PROBE"] == "1"

    override func setUpWithError() throws {
        continueAfterFailure = true
        try XCTSkipUnless(
            Self.isEnabled,
            "An opt-in probe: set TEST_RUNNER_BRICKSON_DRAG_PROBE=1 to run it"
        )
    }

    private enum Start { case yes, tile, gutter }

    @MainActor
    func testDrags() throws {
        // Yes, a standard Button outside any scroll view: the baseline.
        for dx in [20.0, 60.0] { probe(.yes, dx: dx, dy: 0) }
        probe(.yes, dx: 0, dy: 0)
        // A phrase tile: up, sideways and diagonally, short to long.
        for dy in [-5.0, -10.0, -15.0, -20.0, -30.0, -40.0, -80.0] { probe(.tile, dx: 0, dy: dy) }
        for dx in [10.0, 20.0, 40.0, 80.0] { probe(.tile, dx: dx, dy: 0) }
        probe(.tile, dx: 40, dy: -40)
        probe(.tile, dx: 0, dy: 0)
        // The gutter between the first two tiles of the top row.
        probe(.gutter, dx: 0, dy: 0)
        for dy in [-20.0, -80.0] { probe(.gutter, dx: 0, dy: dy) }
    }

    @MainActor
    private func probe(_ start: Start, dx: CGFloat, dy: CGFloat) {
        let app = launchedApp()
        defer { app.terminate() }
        let view = app.scrollViews["homeRegion.phrases"]
        guard view.waitForExistence(timeout: 10) else { return XCTFail("No phrase grid") }
        let viewport = view.frame
        let tiles = app.buttons.matching(identifier: "phraseTile").allElementsBoundByIndex
            .map { (label: $0.label, frame: $0.frame) }
            .sorted { ($0.frame.minY, $0.frame.minX) < ($1.frame.minY, $1.frame.minX) }
        guard tiles.count >= 2 else { return XCTFail("Fewer than two phrase tiles") }
        let fits = tiles.allSatisfy { viewport.insetBy(dx: -0.5, dy: -0.5).contains($0.frame) }
        let from: CGPoint
        switch start {
        case .yes:
            let yes = app.buttons["Yes"].frame
            from = CGPoint(x: yes.minX + 20, y: yes.midY)
        case .tile:
            // The bottom row's first tile, so an upward drag stays on it
            // as long as the tile is tall enough.
            let row = tiles.filter { abs($0.frame.minY - tiles.last!.frame.minY) < 1 }
            let tile = row[0].frame
            from = CGPoint(x: tile.minX + 20, y: tile.maxY - 10)
        case .gutter:
            let first = tiles[0].frame, second = tiles[1].frame
            from = CGPoint(x: (first.maxX + second.minX) / 2, y: first.midY)
        }
        let to = CGPoint(x: from.x + dx, y: from.y + dy)
        // Relative to the element the touch begins on, as PhraseDragTests
        // does: on iPhone Duo's inner display, a point offset from the
        // app's own origin reported the aimed screen point but never
        // reached Home (2026-11-11).
        let anchor = start == .yes ? app.buttons["Yes"] : view
        let anchorFrame = anchor.frame
        let origin = anchor.coordinate(withNormalizedOffset: .zero)
        let a = origin.withOffset(CGVector(dx: from.x - anchorFrame.minX, dy: from.y - anchorFrame.minY))
        let b = origin.withOffset(CGVector(dx: to.x - anchorFrame.minX, dy: to.y - anchorFrame.minY))
        let aimed = abs(a.screenPoint.x - from.x) < 0.5 && abs(a.screenPoint.y - from.y) < 0.5
            && abs(b.screenPoint.x - to.x) < 0.5 && abs(b.screenPoint.y - to.y) < 0.5
        let spoken = tiles.map(\.label) + ["Yes.", "No."]
        let message = app.descendants(matching: .any)["homeRegion.message"]
            .staticTexts.matching(NSPredicate(format: "label IN %@", spoken)).firstMatch
        let before = message.exists
        if aimed {
            if dx == 0 && dy == 0 {
                a.press(forDuration: 0.05)
            } else {
                a.press(forDuration: 0.05, thenDragTo: b, withVelocity: .slow, thenHoldForDuration: 0.1)
            }
        }
        let said = aimed && message.waitForExistence(timeout: 3) ? message.label : ""
        let ended = [tiles.first { $0.frame.contains(to) }?.label, app.buttons["Yes"].frame.contains(to) ? "Yes" : nil]
            .compactMap { $0 }.first ?? "none"
        let fields: [String: Any] = [
            "start": "\(start)", "dx": dx, "dy": dy,
            "from": [from.x, from.y], "to": [to.x, to.y], "endsOn": ended,
            "aimed": aimed, "screenFrom": [a.screenPoint.x, a.screenPoint.y],
            "gridFits": fits, "viewport": [viewport.minX, viewport.minY, viewport.width, viewport.height],
            "spokeBefore": before, "said": said,
        ]
        let json = (try? JSONSerialization.data(withJSONObject: fields, options: [.sortedKeys]))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        let line = "DRAG-PROBE \(json)"
        print(line)
        let attachment = XCTAttachment(string: line)
        attachment.name = "drag-probe-\(start)-\(Int(dx))-\(Int(dy))"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
