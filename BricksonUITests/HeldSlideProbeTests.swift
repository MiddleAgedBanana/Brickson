import UIKit
import XCTest

/// What a slow press, and a touch held on one Home control and slid onto
/// another, do at the largest text size, where the large content viewer
/// would show (docs/DECISIONS.md, "Show Borders and the Large Content
/// Viewer on Home"). Opt-in: skipped unless the test runner's environment
/// has BRICKSON_SLIDE_PROBE=1, passed on by xcodebuild with a TEST_RUNNER_
/// prefix:
///
///     TEST_RUNNER_BRICKSON_SLIDE_PROBE=1 scripts/test.sh ui '-only-testing:BricksonUITests/HeldSlideProbeTests'
///
/// Each gesture starts from a fresh launch and prints one line,
/// `SLIDE-PROBE {json}`: where the touch began and ended, and which
/// sentence Home showed after it ("Yes.", "No.", a phrase, or nothing). The
/// line is attached to the result too (xcbeautify hides a passing test's
/// output). The probe asserts nothing about the outcome: it runs on the
/// shipped build and on a test build that adds the viewer, and the record
/// compares the two (docs/log/2026-10-23-large-content-and-iphone-duo.md).
/// These are simulator results, with touches XCTest synthesises; a real
/// finger on a device is the device check in docs/HANDOFF.md. Rerun it
/// after each new major Xcode, in case SwiftUI's viewer changes.
///
/// The viewer follows the app's own text size, which `launchedApp` sets;
/// the probe also prints whether the system reports the viewer on
/// (`UILargeContentViewerInteraction.isEnabled`, read in the test runner,
/// which follows the simulator's setting).
final class HeldSlideProbeTests: XCTestCase {
    private static let isEnabled = ProcessInfo.processInfo.environment["BRICKSON_SLIDE_PROBE"] == "1"
    /// Longer than the viewer's hold, so its large copy shows before the
    /// touch moves.
    private static let hold: TimeInterval = 1.5
    /// What Home's message area says on a fresh launch (`FirstRunHint`).
    private static let firstRunHint = "Family: help with setting up is in Settings."

    override func setUpWithError() throws {
        continueAfterFailure = true
        try XCTSkipUnless(
            Self.isEnabled,
            "An opt-in probe: set TEST_RUNNER_BRICKSON_SLIDE_PROBE=1 to run it"
        )
    }

    /// Yes, No and the phrase tiles.
    @MainActor
    func testHome() throws {
        do {
            let app = launchedApp(textSize: .ax5)
            app.buttons["Yes"].tap()
            report("tap Yes", in: app, from: "Yes.", to: "Yes.")
        }
        // How long a press can last and still speak: a slow tap, as a weak
        // or unsteady hand makes one.
        for duration in [0.1, 0.2, 0.25, 0.5, 0.75, 1.0, Self.hold] {
            let app = launchedApp(textSize: .ax5)
            centre(of: app.buttons["Yes"]).press(forDuration: duration)
            report("press Yes for \(duration) s, lift in place", in: app, from: "Yes.", to: "Yes.")
        }
        // A slow tap on No and on a phrase tile, lifted in place.
        do {
            let app = launchedApp(textSize: .ax5)
            centre(of: app.buttons["No"]).press(forDuration: 0.5)
            report("press No for 0.5 s, lift in place", in: app, from: "No.", to: "No.")
        }
        do {
            let app = launchedApp(textSize: .ax5)
            if let tile = phraseTiles(in: app).first {
                let words = tile.label
                centre(of: tile).press(forDuration: 0.5)
                report("press a tile for 0.5 s, lift in place", in: app, from: words, to: words)
            }
        }
        // The same slow tap at the default text size.
        do {
            let app = launchedApp(textSize: .large)
            centre(of: app.buttons["Yes"]).press(forDuration: 0.5)
            report("press Yes for 0.5 s at the default text size, lift in place", in: app, from: "Yes.", to: "Yes.")
        }
        for (gesture, duration) in [("hold Yes, slide onto No, lift", Self.hold), ("touch Yes, slide onto No at once, lift", 0.1)] {
            let app = launchedApp(textSize: .ax5)
            centre(of: app.buttons["Yes"]).press(
                forDuration: duration,
                thenDragTo: centre(of: app.buttons["No"]),
                withVelocity: .slow,
                thenHoldForDuration: duration == Self.hold ? 0.5 : 0.1
            )
            report(gesture, in: app, from: "Yes.", to: "No.")
        }
        // Issue #36: tiles sit in a grid that scrolls where they do not
        // fit (on an iPhone at this size; not on a 13-inch iPad).
        let neighbours: [(String, (CGRect, CGRect) -> Bool)] = [
            ("the next in its row", { first, other in abs(other.midY - first.midY) < 1 && other.minX > first.maxX }),
            ("the one below", { first, other in abs(other.midX - first.midX) < 1 && other.minY > first.maxY }),
        ]
        for (name, isNeighbour) in neighbours {
            let app = launchedApp(textSize: .ax5)
            let tiles = phraseTiles(in: app)
            guard let first = tiles.first, let next = tiles.first(where: { isNeighbour(first.frame, $0.frame) }) else {
                // Not a failure: on a short window only one row may show.
                keep("hold a tile, slide onto \(name), lift", in: app, ["message shown": "(not run: no phrase tile is \(name) on screen)"])
                continue
            }
            centre(of: first).press(
                forDuration: Self.hold,
                thenDragTo: centre(of: next),
                withVelocity: .slow,
                thenHoldForDuration: 0.5
            )
            report("hold a tile, slide onto \(name), lift", in: app, from: first.label, to: next.label)
        }
    }

    /// Settings' gear, which has the viewer where it shows alone (PR #33):
    /// from 304pt of content up to 332pt, or from 328pt up to 358pt with
    /// Bold Text, as on iPhone Duo's outer display with Bold Text on.
    /// Skipped where the gear shows its word.
    @MainActor
    func testSettingsGearAlone() throws {
        do {
            let app = launchedApp(textSize: .ax5)
            let narrowest = UIAccessibility.isBoldTextEnabled ? 86.0 : 80.0
            let width = app.buttons["settings"].frame.width
            try XCTSkipUnless(width < narrowest, "Settings shows its word here (\(width)pt wide): no window to probe the gear alone")
            let before = homeState(of: app)
            app.buttons["settings"].tap()
            reportGear("tap the gear", in: app, before: before, endedOn: "Settings", width: width)
        }
        do {
            let app = launchedApp(textSize: .ax5)
            let gear = app.buttons["settings"]
            let width = gear.frame.width
            let before = homeState(of: app)
            centre(of: gear).press(forDuration: Self.hold)
            reportGear("hold the gear, lift in place", in: app, before: before, endedOn: "Settings", width: width)
        }
        let neighbours: [(String, (CGRect, CGRect) -> Bool)] = [
            ("beside", { gear, other in abs(other.midY - gear.midY) < 1 && other.maxX <= gear.minX }),
            ("above", { gear, other in other.minX <= gear.midX && other.maxX >= gear.midX && other.maxY <= gear.minY }),
            ("below", { gear, other in other.minX <= gear.midX && other.maxX >= gear.midX && other.minY >= gear.maxY }),
        ]
        for (name, isNeighbour) in neighbours {
            let app = launchedApp(textSize: .ax5)
            let gear = app.buttons["settings"]
            let gearFrame = gear.frame
            let width = gearFrame.width
            // Each frame is read once: every read asks the app again.
            let target = app.buttons.allElementsBoundByIndex
                .filter(\.isHittable)
                .map { ($0, $0.frame) }
                .filter { isNeighbour(gearFrame, $0.1) }
                .min { distance($0.1, gearFrame) < distance($1.1, gearFrame) }?.0
            guard let target else {
                keep("hold the gear, slide \(name), lift", in: app, ["message shown": "(not run: nothing \(name) the gear)"])
                continue
            }
            let label = target.label
            let before = homeState(of: app)
            centre(of: gear).press(
                forDuration: Self.hold,
                thenDragTo: centre(of: target),
                withVelocity: .slow,
                thenHoldForDuration: 0.5
            )
            reportGear("hold the gear, slide onto \(label) (\(name)), lift", in: app, before: before, endedOn: label, width: width)
        }
    }

    // MARK: - Helpers

    @MainActor
    private func centre(of element: XCUIElement) -> XCUICoordinate {
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
    }

    /// Between the centres of two frames.
    private func distance(_ one: CGRect, _ other: CGRect) -> CGFloat {
        hypot(one.midX - other.midX, one.midY - other.midY)
    }

    /// Every phrase tile that can be touched, in reading order.
    @MainActor
    private func phraseTiles(in app: XCUIApplication) -> [XCUIElement] {
        let query = app.buttons.matching(identifier: "phraseTile")
        XCTAssertTrue(query.firstMatch.waitForExistence(timeout: 10), "no phrase tiles")
        return query.allElementsBoundByIndex
            .filter(\.isHittable)
            .map { ($0, $0.frame) }
            .sorted { ($0.1.minY, $0.1.minX) < ($1.1.minY, $1.1.minX) }
            .map(\.0)
    }

    /// Every sentence Home can show here: the phrases on screen, Yes and No.
    @MainActor
    private func sentences(in app: XCUIApplication) -> [String] {
        Array(Set(phraseTiles(in: app).map(\.label) + ["Yes.", "No."]))
    }

    /// The selected category, and the sentence Home shows.
    @MainActor
    private func homeState(of app: XCUIApplication) -> (category: String, message: String) {
        let category = app.buttons.matching(NSPredicate(format: "selected == true")).firstMatch
        let message = sentences(in: app).first { app.staticTexts[$0].exists } ?? "(nothing spoken)"
        return (category.exists ? category.label : "(none)", message)
    }

    /// Waits up to 3 s for Home to show any sentence it can (a phrase on
    /// screen, Yes or No), then prints which one it showed, and whether the
    /// first-run hint, which a fresh launch shows until something is
    /// spoken, is still there. `start` and `end` are the sentences of the
    /// controls where the touch began and ended; a phrase tile speaks its
    /// own label.
    @MainActor
    private func report(_ gesture: String, in app: XCUIApplication, from start: String, to end: String) {
        let candidates = Array(Set(sentences(in: app) + [start, end]))
        _ = app.staticTexts
            .matching(NSPredicate(format: "label IN %@", candidates))
            .firstMatch
            .waitForExistence(timeout: 3)
        let shown = candidates.filter { app.staticTexts[$0].exists }
        keep(gesture, in: app, [
            "began on": start,
            "ended on": end,
            "message shown": shown.isEmpty ? "(nothing spoken)" : shown.sorted().joined(separator: " + "),
            "first-run hint still shown": String(app.staticTexts[Self.firstRunHint].exists),
        ])
    }

    @MainActor
    private func reportGear(
        _ gesture: String,
        in app: XCUIApplication,
        before: (category: String, message: String),
        endedOn end: String,
        width: CGFloat
    ) {
        let opened = app.buttons["Back to Talking"].waitForExistence(timeout: 3)
        let after = opened ? (category: "(Settings covers Home)", message: "(Settings covers Home)") : homeState(of: app)
        keep(gesture, in: app, [
            "began on": "Settings",
            "ended on": end,
            "gear width": String(format: "%.1f", width),
            "Settings opened": String(opened),
            "category before": before.category,
            "category after": after.category,
            "message before": before.message,
            "message shown": after.message,
        ])
    }

    @MainActor
    private func keep(_ gesture: String, in app: XCUIApplication, _ fields: [String: String]) {
        let result = fields.merging([
            "simulator": ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] ?? "device",
            "gesture": gesture,
            "bold text": String(UIAccessibility.isBoldTextEnabled),
            "viewer enabled in the runner": String(UILargeContentViewerInteraction.isEnabled),
        ]) { own, _ in own }
        let json = (try? JSONSerialization.data(withJSONObject: result, options: [.sortedKeys]))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "\(result)"
        print("SLIDE-PROBE \(json)")
        let attachment = XCTAttachment(string: json)
        attachment.name = "SLIDE-PROBE \(gesture)"
        attachment.lifetime = .keepAlways
        add(attachment)
        attachCapture(app, name: "after \(gesture)")
    }
}
