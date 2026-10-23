import UIKit
import XCTest

/// Apple's keyboard against the room Home keeps for it, on every UI run
/// (docs/DECISIONS.md, "Typing is a state of Home"). Each test, for one
/// orientation and text size:
///
/// 1. Opens the probe screen (`KeyboardProbeScreen`, debug builds only),
///    shows the keyboard, and prints one line, `KEYBOARD-PROBE {json}`, to
///    the test log: where SwiftUI sees the keyboard's top, how many keys
///    showed, and the allowance for the window. The JSON, a screenshot and
///    the accessibility tree are attached to the result too.
/// 2. Fails if the live keyboard reaches higher than `KeyboardAllowance`
///    keeps for the window: Apple's keyboard has grown, and the measured
///    rows in `KeyboardAllowanceTests` and the app's references need the
///    new numbers.
/// 3. Opens Home in the same window and fails if any of Yes, No,
///    Emergency, Again or Get Attention reaches below the allowance's
///    limit, so the keyboard would cover it once typing comes to Home.
///
/// The UI tests compile `KeyboardAllowance` too (project.yml), so the rule
/// is the app's own. The simulator must show the full software keyboard,
/// not the bar it shows when it thinks a hardware keyboard is in use;
/// `scripts/test.sh ui` turns the bar off (AGENTS.md, *Gotchas*). A test
/// that finds fewer keys than a full keyboard has prints its numbers and
/// then fails. These are simulator numbers: a real device can differ, and
/// the keyboard changes with the languages and keyboards a person has
/// added (docs/HANDOFF.md).
final class KeyboardProbeTests: XCTestCase {
    /// `LaunchOptions.StartScreen.keyboardProbe` in the app.
    private static let probeArgument = "--screen=keyboard-probe"
    /// Fewer keys than this means the keyboard is minimized to its bar. A
    /// full English keyboard has 26 letter keys before any other.
    private static let fullKeyboardKeys = 26
    /// The probe and the frames read here are rounded to half a point.
    private static let rounding: CGFloat = 0.5

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testPortraitAtDefaultTextSize() throws {
        try measure(.portrait, textSize: .large)
    }

    @MainActor
    func testPortraitAtLargestTextSize() throws {
        try measure(.portrait, textSize: .ax5)
    }

    @MainActor
    func testLandscapeAtDefaultTextSize() throws {
        try measure(.landscapeLeft, textSize: .large)
    }

    @MainActor
    func testLandscapeAtLargestTextSize() throws {
        try measure(.landscapeLeft, textSize: .ax5)
    }

    // MARK: - Measuring

    @MainActor
    private func measure(_ orientation: UIDeviceOrientation, textSize: UITestTextSize) throws {
        if orientation.isLandscape, UIDevice.current.userInterfaceIdiom == .phone {
            throw XCTSkip("iPhone is portrait only (docs/DECISIONS.md, \"Orientations\")")
        }
        let simulator = ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] ?? "device"
        let name = [simulator, orientation.isLandscape ? "landscape" : "portrait", textSize.name].joined(separator: " ")

        let app = launchedApp(
            textSize: textSize,
            orientation: orientation,
            arguments: [Self.probeArgument],
            waitsForHome: false
        )
        let field = app.descendants(matching: .any)["keyboardProbe.field"]
        XCTAssertTrue(
            field.waitForExistence(timeout: 60),
            "The probe screen did not open. It exists only in debug builds."
        )
        let window = waitForWindow(of: app, orientation: orientation)
        let allowance = KeyboardAllowance(windowSize: window.size)
        // The screen focuses its field as it opens; tap only if that failed.
        if !app.keyboards.firstMatch.waitForExistence(timeout: 5) {
            field.tap()
        }
        XCTAssertTrue(
            app.keyboards.firstMatch.waitForExistence(timeout: 10),
            "The keyboard did not appear. If the simulator shows only the keyboard bar, see AGENTS.md, Gotchas."
        )
        field.typeText("Water")

        // SwiftUI's keyboard top is the window's bottom until it leaves room
        // for the keyboard. Checked only after the numbers are printed, so a
        // failure still reports what the keyboard looked like.
        let readout = app.staticTexts["keyboardProbe.readout"]
        let windowHeight = Self.points(window.height)
        let keyboardSeen = NSPredicate(format: "NOT (label CONTAINS %@)", "keyboardTop=\(windowHeight);")
        _ = XCTWaiter.wait(for: [expectation(for: keyboardSeen, evaluatedWith: readout)], timeout: 10)
        let swiftUI = settledReadout(readout)
        let keyboardTop = swiftUI["keyboardTop"].flatMap(Double.init)
        let swiftUILeftRoom = keyboardTop.map { $0 < windowHeight } ?? false

        let tree = try app.snapshot()
        let nodes = all(tree)
        let keys = nodes.filter { $0.elementType == .key && $0.frame.width > 1 && $0.frame.height > 1 }
        let keyboards = nodes.filter { $0.elementType == .keyboard }
        var result: [String: Any] = [
            "name": name,
            "simulator": simulator,
            "system": UIDevice.current.systemVersion,
            "orientation": orientation.isLandscape ? "landscape" : "portrait",
            "textSize": textSize.rawValue,
            "appFrame": Self.rect(window),
            "swiftUI": swiftUI,
            "swiftUILeftRoom": swiftUILeftRoom,
            "keyboardHeight": keyboardTop.map { windowHeight - $0 } as Any,
            "allowance": Double(allowance.height),
            "bandLimit": Double(allowance.bandLimit),
            "keyCount": keys.count,
            "keyboard": keys.count >= Self.fullKeyboardKeys ? "full software keyboard" : "keyboard bar",
            "keyboardFrames": keyboards.map { Self.rect($0.frame) },
        ]
        if let keysTop = keys.map(\.frame.minY).min() {
            result["keysTop"] = Self.points(keysTop)
        }
        try report(result, prefix: "KEYBOARD-PROBE", name: name)
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
        XCTAssertTrue(swiftUILeftRoom, "The keyboard is on screen, but SwiftUI never left room for it")
        let top = try XCTUnwrap(keyboardTop, "The probe did not report the keyboard's top (\(name))")
        XCTAssertGreaterThanOrEqual(
            CGFloat(top) + Self.rounding,
            allowance.bandLimit,
            """
            The keyboard's top is at \(top), above the allowance's limit of \(allowance.bandLimit) for a window \
            of \(window.size) (\(name)): Apple's keyboard is taller than KeyboardAllowance keeps room for. Add \
            this measurement to KeyboardAllowanceTests and raise the reference for this shape of window.
            """
        )
        app.terminate()

        // Home in the same window: its safety row ends above the limit.
        let home = launchedApp(textSize: textSize, orientation: orientation)
        let homeWindow = waitForWindow(of: home, orientation: orientation)
        XCTAssertEqual(homeWindow.size, window.size, "Home opened in another window than the probe (\(name))")
        var safetyRow: [String: Double] = [:]
        for control in ["Yes", "No", "Emergency", "Again", "getAttention"] {
            let frame = home.buttons[control].firstMatch.frame
            XCTAssertFalse(frame.isEmpty, "Home has no \(control) (\(name))")
            let bottom = frame.maxY - homeWindow.minY
            safetyRow[control] = Self.points(bottom)
            XCTAssertLessThanOrEqual(
                bottom,
                allowance.bandLimit + Self.rounding,
                """
                \(control) ends at \(bottom), below the allowance's limit of \(allowance.bandLimit) (\(name)): \
                Apple's keyboard would cover it once typing opens (docs/DECISIONS.md, "Typing is a state of Home")
                """
            )
        }
        try report(
            ["name": name, "bandLimit": Double(allowance.bandLimit), "safetyRowBottoms": safetyRow],
            prefix: "KEYBOARD-BAND",
            name: "\(name) band"
        )
        attachCapture(home, name: "keyboard band, \(name)")
    }

    /// The app's window once it has turned to `orientation`: a query
    /// straight after a rotation can read the frame from before the turn.
    @MainActor
    private func waitForWindow(of app: XCUIApplication, orientation: UIDeviceOrientation) -> CGRect {
        let turned = NSPredicate { _, _ in
            MainActor.assumeIsolated {
                let frame = app.windows.firstMatch.frame
                return !frame.isEmpty && (frame.width > frame.height) == orientation.isLandscape
            }
        }
        XCTAssertEqual(
            XCTWaiter.wait(for: [expectation(for: turned, evaluatedWith: nil)], timeout: 10), .completed,
            "the window did not turn to \(orientation.isLandscape ? "landscape" : "portrait")"
        )
        return app.windows.firstMatch.frame
    }

    /// Prints `prefix {json}` to the test log and attaches the JSON.
    @MainActor
    private func report(_ values: [String: Any], prefix: String, name: String) throws {
        let data = try JSONSerialization.data(withJSONObject: values, options: [.sortedKeys])
        print(prefix + " " + String(decoding: data, as: UTF8.self))
        attach(XCTAttachment(data: data, uniformTypeIdentifier: "public.json"), named: "\(name).json")
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
