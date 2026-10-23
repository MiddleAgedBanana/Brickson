import UIKit
import XCTest

/// The Get Attention alarm on Home, in the running app (docs/DECISIONS.md,
/// "Get Attention and Stop on Home"). The app plays a silent stand-in tone
/// (`--attention-tone=silent`), so the alarm's state is the real one and
/// nothing depends on the simulator's audio; how loud the real tone is, and
/// whether it plays through the silent switch, is a device check.
///
/// - Get Attention starts the alarm: Stop appears in its own well and the
///   status line says "Sounding" ("Get Attention is sounding." to
///   VoiceOver). Nothing else appears, and nothing moves
///   (invariant 8).
/// - A held look on Get Attention cannot stop the alarm: Stop is never the
///   control nearest Get Attention's spot, by nearest centre or by nearest
///   edge, ties counted (invariant 10).
/// - Stop ends it: its well empties and nothing moves. A held look still
///   resting where Stop was meets a category, which only changes which
///   phrases show, and never Get Attention, which would restart it.
///
/// This reads the frames the app hands to assistive technologies on the
/// simulator CI runs; it is not evidence of what a person's gaze does on a
/// device (docs/HANDOFF.md, *Checks that need a real device*).
final class GetAttentionOnHomeTests: XCTestCase {
    /// Copied from Brickson/Resources/StarterPhrases.json, as in
    /// `HomeLayoutTests`.
    private static let everydayCategories: Set = ["Basics", "Needs", "Conversation", "Feelings"]

    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    @MainActor
    func testTheAlarmStartsAndStopsAtDefaultText() throws {
        try checkTheAlarm(textSize: .large, orientation: .portrait)
    }

    @MainActor
    func testTheAlarmStartsAndStopsAtTheLargestText() throws {
        try checkTheAlarm(textSize: .ax5, orientation: .portrait)
    }

    /// The iPhone keeps portrait (docs/DECISIONS.md, "Orientations"), so
    /// this checks the iPad's other arrangement only.
    @MainActor
    func testTheAlarmStartsAndStopsInLandscape() throws {
        try XCTSkipIf(UIDevice.current.userInterfaceIdiom == .phone, "the iPhone is portrait only")
        try checkTheAlarm(textSize: .large, orientation: .landscapeLeft)
    }

    @MainActor
    private func checkTheAlarm(textSize: UITestTextSize, orientation: UIDeviceOrientation) throws {
        let app = launchedApp(textSize: textSize, orientation: orientation, arguments: ["--attention-tone=silent"])
        let turned = NSPredicate { _, _ in
            MainActor.assumeIsolated {
                let frame = app.windows.firstMatch.frame
                return (frame.width > frame.height) == orientation.isLandscape
            }
        }
        XCTAssertEqual(
            XCTWaiter.wait(for: [expectation(for: turned, evaluatedWith: nil)], timeout: 10), .completed,
            "the window did not turn to \(orientation.isLandscape ? "landscape" : "portrait")"
        )
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        let window = app.windows.firstMatch.frame
        let context = "\(textSize.name), \(orientation.isLandscape ? "landscape" : "portrait"), \(isPad ? "iPad" : "iPhone"), window \(window.size)"

        let getAttention = app.buttons["getAttention"]
        let stop = app.buttons["stopAlert"]
        let sounding = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "Get Attention is sounding.")).firstMatch
        assertReachable("getAttention", in: app, context: context)
        XCTAssertFalse(stop.exists, "Stop shows before the alarm sounds (\(context))")
        let atRest = try screenControls(in: app)
        let getAttentionSpot = try XCTUnwrap(atRest.first { $0.name == "getAttention" }, "Home has no Get Attention (\(context))")

        // Start: Stop appears in its well; nothing else appears or moves.
        getAttention.tap()
        XCTAssertTrue(stop.waitForExistence(timeout: 10), "Stop did not appear after Get Attention (\(context))")
        XCTAssertTrue(sounding.waitForExistence(timeout: 10), "the status line does not say Sounding (\(context))")
        assertReachable("stopAlert", in: app, context: "the alarm sounding; \(context)")
        assertReachable("getAttention", in: app, context: "the alarm sounding; \(context)")
        let whileSounding = try screenControls(in: app)
        attachCapture(app, name: "home-alarm sounding-\(context)".replacingOccurrences(of: ", ", with: "-"))
        expectNothingMoved(from: atRest, to: whileSounding, except: "stopAlert", context: "the alarm sounding; \(context)")
        let stopSpot = try XCTUnwrap(whileSounding.first { $0.name == "stopAlert" }, "Stop is not on screen (\(context))")

        // A held look on Get Attention: the nearest control other than Get
        // Attention itself is never Stop.
        let besideGetAttention = nearestControls(
            to: getAttentionSpot.center,
            among: whileSounding.filter { $0.name != "getAttention" }
        )
        XCTAssertFalse(besideGetAttention.byCentre.contains("stopAlert"), "Stop is nearest Get Attention by centre (\(context))")
        XCTAssertFalse(besideGetAttention.byEdge.contains("stopAlert"), "Stop is nearest Get Attention by edge (\(context))")

        // Choosing Get Attention again leaves the alarm sounding.
        getAttention.tap()
        XCTAssertTrue(stop.waitForExistence(timeout: 5), "a second Get Attention stopped the alarm (\(context))")

        // Stop: its well empties; nothing else moves.
        stop.tap()
        let stopped = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: stop)
        XCTAssertEqual(XCTWaiter.wait(for: [stopped], timeout: 10), .completed, "Stop is still showing after Stop (\(context))")
        XCTAssertFalse(sounding.exists, "the status line still says Sounding after Stop (\(context))")
        let afterStop = try screenControls(in: app)
        attachCapture(app, name: "home-alarm stopped-\(context)".replacingOccurrences(of: ", ", with: "-"))
        expectNothingMoved(from: atRest, to: afterStop, except: nil, context: "the alarm stopped; \(context)")

        // A held look where Stop was meets a category, never Get Attention
        // or a control that speaks.
        let whereStopWas = nearestControls(to: stopSpot.center, among: afterStop)
        for (rule, names) in [("centre", whereStopWas.byCentre), ("edge", whereStopWas.byEdge)] {
            XCTAssertFalse(names.isEmpty, "nothing is near Stop's spot by \(rule) (\(context))")
            XCTAssertTrue(
                names.isSubset(of: Self.everydayCategories),
                "Stop's spot at \(stopSpot.frame) is nearest \(names) by \(rule) after Stop (\(context))"
            )
        }
    }

    /// Fails if a control that was on screen moved, disappeared, or one
    /// other than `except` appeared. Phrase tiles, which share one
    /// identifier, are compared in order.
    private func expectNothingMoved(
        from before: [ScreenControl], to after: [ScreenControl], except added: String?, context: String
    ) {
        func named(_ controls: [ScreenControl]) -> [String: CGRect] {
            Dictionary(
                controls.filter { $0.name != "phraseTile" }.map { ($0.name, $0.frame) },
                uniquingKeysWith: { first, _ in first }
            )
        }
        func tiles(_ controls: [ScreenControl]) -> [CGRect] {
            controls.filter { $0.name == "phraseTile" }.map(\.frame)
                .sorted { ($0.minY.rounded(), $0.minX) < ($1.minY.rounded(), $1.minX) }
        }
        let original = named(before)
        let now = named(after)
        XCTAssertEqual(
            Set(now.keys).subtracting(original.keys), added.map { [$0] } ?? [],
            "controls appeared (\(context))"
        )
        XCTAssertEqual(Set(original.keys).subtracting(now.keys), [], "controls disappeared (\(context))")
        var pairs = original.compactMap { name, frame in now[name].map { (name, frame, $0) } }
        let tilesBefore = tiles(before)
        let tilesAfter = tiles(after)
        XCTAssertEqual(tilesBefore.count, tilesAfter.count, "the phrase tiles changed (\(context))")
        pairs += zip(tilesBefore, tilesAfter).enumerated().map { ("phrase tile \($0.offset + 1)", $0.element.0, $0.element.1) }
        for (name, original, frame) in pairs {
            for (edge, actual, expected) in [
                ("left", frame.minX, original.minX),
                ("top", frame.minY, original.minY),
                ("right", frame.maxX, original.maxX),
                ("bottom", frame.maxY, original.maxY),
            ] {
                XCTAssertEqual(actual, expected, accuracy: 1, "\(name)'s \(edge) edge moved (\(context))")
            }
        }
    }
}
