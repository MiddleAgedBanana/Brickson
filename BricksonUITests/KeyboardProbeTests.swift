import UIKit
import XCTest

/// Measures where Apple's keyboard starts on this simulator, so Home's
/// typing state can keep every safety control above it (docs/DECISIONS.md,
/// "Typing is a state of Home"). Opt-in: skipped unless the test runner's
/// environment has BRICKSON_KEYBOARD_PROBE=1. xcodebuild passes it on when
/// it is set with a TEST_RUNNER_ prefix:
///
///     TEST_RUNNER_BRICKSON_KEYBOARD_PROBE=1 scripts/test.sh ui
///
/// Each test opens the probe screen (`KeyboardProbeScreen`, debug builds
/// only) in one orientation at one text size, shows the keyboard, and
/// prints one line, `KEYBOARD-PROBE {json}`, to the test log. The JSON, a
/// screenshot and the accessibility tree are attached to the result too.
///
/// The simulator must show the full software keyboard, not the bar it shows
/// when it thinks a hardware keyboard is in use (AGENTS.md, *Gotchas*). A
/// test that finds fewer keys than a full keyboard has prints its numbers
/// and then fails. These are simulator numbers: a real device can differ,
/// and the keyboard changes with the language and keyboards a person has
/// added (docs/HANDOFF.md).
final class KeyboardProbeTests: XCTestCase {
    private static let isEnabled = true // TEMPORARY: measure on CI, reverted before review
    /// `KeyboardProbeLaunch.argument` in the app.
    private static let probeArgument = "--screen=keyboard-probe"
    /// Fewer keys than this means the keyboard is minimized to its bar. A
    /// full English keyboard has 26 letter keys before any other.
    private static let fullKeyboardKeys = 26

    override func setUpWithError() throws {
        continueAfterFailure = false
        try XCTSkipUnless(
            Self.isEnabled,
            "An opt-in measurement: set TEST_RUNNER_BRICKSON_KEYBOARD_PROBE=1 to measure the keyboard"
        )
    }

    @MainActor
    func testPortraitAtDefaultTextSize() throws {
        try measure(.portrait, textSize: "UICTContentSizeCategoryL")
    }

    @MainActor
    func testPortraitAtLargestTextSize() throws {
        try measure(.portrait, textSize: "UICTContentSizeCategoryAccessibilityXXXL")
    }

    @MainActor
    func testLandscapeAtDefaultTextSize() throws {
        try measure(.landscapeLeft, textSize: "UICTContentSizeCategoryL")
    }

    @MainActor
    func testLandscapeAtLargestTextSize() throws {
        try measure(.landscapeLeft, textSize: "UICTContentSizeCategoryAccessibilityXXXL")
    }

    // MARK: - Measuring

    @MainActor
    private func measure(_ orientation: UIDeviceOrientation, textSize: String) throws {
        if orientation.isLandscape, UIDevice.current.userInterfaceIdiom == .phone {
            throw XCTSkip("iPhone is portrait only (docs/DECISIONS.md, \"Orientations\")")
        }
        let simulator = ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] ?? "device"
        let name = [
            simulator,
            orientation.isLandscape ? "landscape" : "portrait",
            textSize.replacingOccurrences(of: "UICTContentSizeCategory", with: ""),
        ].joined(separator: " ")

        XCUIDevice.shared.orientation = orientation
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = XCUIApplication()
        app.launchArguments = [Self.probeArgument, "-UIPreferredContentSizeCategoryName", textSize]
        app.launch()
        defer { app.terminate() }

        let field = app.descendants(matching: .any)["keyboardProbe.field"]
        XCTAssertTrue(
            field.waitForExistence(timeout: 15),
            "The probe screen did not open. It exists only in debug builds."
        )
        // The screen focuses its field as it opens; tap only if that failed.
        if !app.keyboards.firstMatch.waitForExistence(timeout: 5) {
            field.tap()
        }
        XCTAssertTrue(
            app.keyboards.firstMatch.waitForExistence(timeout: 10),
            "The keyboard did not appear. If the simulator shows only the keyboard bar, see AGENTS.md, Gotchas."
        )
        field.typeText("Water")

        let readout = app.staticTexts["keyboardProbe.readout"]
        let keyboardSeen = NSPredicate(format: "NOT (label CONTAINS 'keyboardHeight=0.0')")
        XCTAssertEqual(
            XCTWaiter.wait(for: [expectation(for: keyboardSeen, evaluatedWith: readout)], timeout: 10),
            .completed,
            "The keyboard is on screen, but SwiftUI never left room for it"
        )
        let swiftUI = settledReadout(readout)

        let tree = try app.snapshot()
        let nodes = all(tree)
        let keys = nodes.filter { $0.elementType == .key && $0.frame.width > 1 && $0.frame.height > 1 }
        let keyboards = nodes.filter { $0.elementType == .keyboard }
        var result: [String: Any] = [
            "name": name,
            "simulator": simulator,
            "system": UIDevice.current.systemVersion,
            "orientation": orientation.isLandscape ? "landscape" : "portrait",
            "textSize": textSize,
            "appFrame": Self.rect(app.frame),
            "swiftUI": swiftUI,
            "keyCount": keys.count,
            "keyboard": keys.count >= Self.fullKeyboardKeys ? "full software keyboard" : "keyboard bar",
            "keyboardFrames": keyboards.map { Self.rect($0.frame) },
        ]
        if let keysTop = keys.map(\.frame.minY).min() {
            result["keysTop"] = Self.points(keysTop)
        }

        let data = try JSONSerialization.data(withJSONObject: result, options: [.sortedKeys])
        let json = String(decoding: data, as: UTF8.self)
        print("KEYBOARD-PROBE " + json)
        XCTFail("KEYBOARD-PROBE " + json) // TEMPORARY: shows the numbers in CI's log
        attach(XCTAttachment(data: data, uniformTypeIdentifier: "public.json"), named: "\(name).json")
        attach(XCTAttachment(screenshot: XCUIScreen.main.screenshot()), named: "\(name).png")
        attach(XCTAttachment(string: app.debugDescription), named: "\(name) tree.txt")

        XCTAssertGreaterThanOrEqual(
            keys.count,
            Self.fullKeyboardKeys,
            """
            Only \(keys.count) keys: the simulator is showing the keyboard bar, not the full keyboard, \
            so these numbers are not the worst case. Show the full keyboard with \
            xcrun simctl spawn <udid> defaults write com.apple.keyboard.preferences \
            AutomaticMinimizationEnabled -bool false, then measure again.
            """
        )
    }

    /// The readout's values once two reads half a second apart agree, so the
    /// keyboard has finished moving. Gives up after ten seconds and returns
    /// the last read, marked unsettled.
    @MainActor
    private func settledReadout(_ readout: XCUIElement) -> [String: String] {
        let deadline = ContinuousClock.now + .seconds(10)
        var last = readout.label
        while ContinuousClock.now < deadline {
            _ = XCTWaiter.wait(for: [XCTestExpectation(description: "pause")], timeout: 0.5)
            let next = readout.label
            if next == last { return Self.values(in: next) }
            last = next
        }
        var values = Self.values(in: last)
        values["settled"] = "no"
        return values
    }

    @MainActor
    private func attach(_ attachment: XCTAttachment, named name: String) {
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private func all(_ node: any XCUIElementSnapshot) -> [any XCUIElementSnapshot] {
        [node] + node.children.flatMap(all)
    }

    /// "a=1;b=2" as ["a": "1", "b": "2"].
    private static func values(in readout: String) -> [String: String] {
        var values: [String: String] = [:]
        for pair in readout.split(separator: ";") {
            let parts = pair.split(separator: "=", maxSplits: 1)
            if parts.count == 2 {
                values[String(parts[0])] = String(parts[1])
            }
        }
        return values
    }

    private static func points(_ value: CGFloat) -> Double {
        (Double(value) * 2).rounded() / 2
    }

    private static func rect(_ frame: CGRect) -> [String: Double] {
        ["x": points(frame.minX), "y": points(frame.minY), "width": points(frame.width), "height": points(frame.height)]
    }
}
