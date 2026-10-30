import UIKit
import XCTest

/// Dynamic Type sizes the UI tests launch at, by UIKit's names for them.
enum UITestTextSize: String, CaseIterable {
    /// The system's default size.
    case large = "UICTContentSizeCategoryL"
    /// The largest size without Larger Accessibility Sizes turned on.
    case xxxLarge = "UICTContentSizeCategoryXXXL"
    case ax1 = "UICTContentSizeCategoryAccessibilityM"
    case ax3 = "UICTContentSizeCategoryAccessibilityXL"
    /// The largest size of all.
    case ax5 = "UICTContentSizeCategoryAccessibilityXXXL"

    /// How failure messages and capture names say it.
    var name: String {
        switch self {
        case .large: "default text"
        case .xxxLarge: "xxxLarge text"
        case .ax1: "AX1 text"
        case .ax3: "AX3 text"
        case .ax5: "AX5 text"
        }
    }
}

/// A debug launch preference, independently checked against rendered pixels.
enum UITestAppearance: String {
    case light
    case dark
}

/// Home's sizes (`ProfileChoice` in the app). Tests written for touch's
/// sizes ask for them; `fromTheAnswer` leaves Family Setup's answer to
/// decide, as it does for everyone, the largest until anyone answers.
enum UITestSizes: String {
    case touch
    case switchControl = "switch-control"
    case headTracking = "head-tracking"
    case eyeTracking = "eye-tracking"
    case fromTheAnswer
}

/// Where the launched app keeps what it saves (`LaunchOptions` in the app).
enum UITestStorage {
    /// Test-only storage, erased first: the starter phrases, no saved
    /// settings, no draft. Never the person's own data.
    case fresh
    /// The same test-only storage, keeping what an earlier launch in this
    /// test saved, to check that something survives a relaunch.
    case kept
}

extension XCTestCase {
    /// Launches Brickson the way every UI test should: on test-only storage,
    /// with short idle limits (unless `shortTimeouts` is false, for a test
    /// slower than they are), in English, at the given text size,
    /// appearance and orientation, with Home at touch's sizes unless
    /// `sizes` asks for others. It waits for Home (unless
    /// `waitsForHome` is false, for a test that starts on another screen)
    /// and fails if Home says changes won't be kept, which would mean the
    /// test storage did not open.
    ///
    /// Orientation is simulator-wide and is restored to portrait. Appearance
    /// is a debug launch preference because XCUIDevice.appearance can report
    /// success without changing the app in command-line simulator runs.
    @MainActor
    @discardableResult
    func launchedApp(
        textSize: UITestTextSize = .large,
        appearance: UITestAppearance = .light,
        orientation: UIDeviceOrientation = .portrait,
        storage: UITestStorage = .fresh,
        sizes: UITestSizes = .touch,
        arguments: [String] = [],
        shortTimeouts: Bool = true,
        waitsForHome: Bool = true,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> XCUIApplication {
        let device = XCUIDevice.shared
        addTeardownBlock {
            await MainActor.run {
                XCUIDevice.shared.orientation = .portrait
            }
        }
        device.orientation = orientation

        let app = XCUIApplication()
        app.launchArguments = [
            storage == .fresh ? "--fresh-test-storage" : "--test-storage",
        ] + (shortTimeouts ? ["--short-timeouts"] : [])
            + (sizes == .fromTheAnswer ? [] : ["--home-profile=\(sizes.rawValue)"]) + [
            "--appearance=\(appearance.rawValue)",
            "-UIPreferredContentSizeCategoryName", textSize.rawValue,
            // Tests find controls by their English labels.
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
        ] + arguments
        let clock = ContinuousClock()
        let start = clock.now
        app.launch()
        guard waitsForHome else { return app }

        // A simulator that has just started can take most of a minute to
        // show the first launch on GitHub's busy machines (docs/HANDOFF.md).
        let homeAppeared = app.buttons["Yes"].waitForExistence(timeout: 60)
        XCTAssertTrue(homeAppeared, "Home did not appear within \(clock.now - start) of launch", file: file, line: line)
        XCTAssertFalse(
            app.descendants(matching: .any)
                .matching(NSPredicate(format: "label BEGINSWITH %@", "Phrases can't be saved"))
                .firstMatch.exists,
            "Home says changes won't be kept: the test storage did not open",
            file: file, line: line
        )
        return app
    }

    /// Keeps a picture of the screen, its accessibility tree, and every
    /// button's label, identifier and frame (JSON) in the test's results, so
    /// the layout can be measured after the run, also from CI's uploaded
    /// result bundles. `name` says which screen and configuration it is.
    @MainActor
    func attachCapture(_ app: XCUIApplication, name: String) {
        // The app's own screenshot is cropped after a landscape rotation on
        // some simulator runtimes; the screen's keeps everything.
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = name
        screenshot.lifetime = .keepAlways
        add(screenshot)

        let tree = XCTAttachment(string: app.debugDescription)
        tree.name = name + "-accessibility"
        tree.lifetime = .keepAlways
        add(tree)

        if let snapshot = try? app.snapshot() {
            let capture = ControlCapture(root: snapshot)
            if let json = try? JSONEncoder.sortedPretty.encode(capture) {
                let frames = XCTAttachment(data: json, uniformTypeIdentifier: "public.json")
                frames.name = name + "-buttons.json"
                frames.lifetime = .keepAlways
                add(frames)
            }
        }
    }

    /// Checks that a control can be activated: it exists, it is hittable,
    /// it lies wholly inside the window, and it is at least 44 points each
    /// way (invariant 1). `context` names the state and configuration in
    /// the failure message.
    @MainActor
    func assertReachable(
        _ label: String,
        in app: XCUIApplication,
        context: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let control = app.buttons[label].firstMatch
        guard control.waitForExistence(timeout: 5) else {
            XCTFail("\(label) is missing (\(context))", file: file, line: line)
            return
        }
        let identity = SnapshotControlGeometry.Identity(identifier: control.identifier, label: control.label)
        let located: SnapshotControlGeometry.Located
        do {
            located = try SnapshotControlGeometry.locate(
                in: app.snapshot(), frame: { $0.frame }, isWindow: { $0.elementType == .window },
                target: identity,
                identity: { $0.elementType == .button ? .init(identifier: $0.identifier, label: $0.label) : nil },
                children: { $0.children }
            )
        } catch {
            let reason = (error as? SnapshotControlGeometry.Failure).map { String(describing: $0) } ?? "snapshotUnavailable"
            XCTFail("\(label) has no unique coherent control/window geometry (\(context)): \(reason)", file: file, line: line)
            return
        }
        let frame = located.control
        XCTAssertTrue(control.isHittable, "\(label) cannot be activated (\(context)); frame \(frame)", file: file, line: line)
        XCTAssertTrue(
            located.window.insetBy(dx: -1, dy: -1).contains(frame),
            "\(label) is not wholly on screen (\(context)): frame \(frame), window \(located.window)",
            file: file, line: line
        )
        XCTAssertGreaterThanOrEqual(frame.width, 44, "\(label) is narrower than 44pt (\(context))", file: file, line: line)
        XCTAssertGreaterThanOrEqual(frame.height, 44, "\(label) is shorter than 44pt (\(context))", file: file, line: line)
    }

    /// Runs Apple's automated accessibility audit on the screen as it is
    /// (contrast, element labels, hit regions, Dynamic Type support, clipped
    /// text) and reports each issue with the element it names, so the
    /// failure says what to fix. Set `continueAfterFailure = true` first to
    /// see every issue, not only the first.
    ///
    /// One kind of issue is expected and not reported: the audit's guess
    /// that a phrase tile's label is "not human-readable". A tile's label is
    /// the phrase itself, the person's own words, which VoiceOver must read
    /// exactly as written; the audit flagged the starter phrase "Maybe." on
    /// CI. An empty tile label still fails.
    ///
    /// The audit is only evidence about a still screen. It reads a
    /// screenshot and the accessibility tree a moment apart, so text that
    /// leaves the screen in between is reported as "Potentially
    /// inaccessible text" on no element: Home's "Speaking" line did that on
    /// CI when the voice finished just as the audit began (issue #30). So
    /// it first waits for speech to finish (`waitForSpeechToFinish`).
    @MainActor
    func assertPassesAccessibilityAudit(
        _ app: XCUIApplication,
        context: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        try AccessibilityAuditRunner.perform(settle: {
            waitForSpeechToFinish(in: app, context: context, file: file, line: line)
        }) {
            try app.performAccessibilityAudit { issue in
                MainActor.assumeIsolated {
                    if isPhraseTileLabelGuess(issue) { return true }
                    // Some findings identify no element. Keep the screen
                    // and tree at reporting time, not only before the audit
                    // changes Dynamic Type, and retain Apple's native issue.
                    self.attachCapture(app, name: "Audit failure, \(context), type \(issue.auditType.rawValue)")
                    let element = issue.element.map {
                        "\"\($0.label)\" (identifier \"\($0.identifier)\", frame \($0.frame))"
                    } ?? "no element"
                    XCTFail(
                        "Accessibility audit (\(context); type \(issue.auditType.rawValue)): \(issue.compactDescription) on \(element). \(issue.detailedDescription)",
                        file: file, line: line
                    )
                    // The contextual failure above survives a later service
                    // timeout. False also preserves XCTest's original issue
                    // and any diagnostic attachments it can provide.
                    return false
                }
            }
        }
    }

    /// Waits until Home's "Speaking" line has gone: the voice has finished,
    /// or the speech watchdog has ended the phrase (invariant 4). Returns
    /// at once when nothing is speaking. Nothing else on Home changes by
    /// itself, so the screen is then still. Fails if "Speaking" still shows
    /// after `timeout`: speech that never ends is a failure of its own.
    @MainActor
    func waitForSpeechToFinish(
        in app: XCUIApplication,
        context: String,
        timeout: TimeInterval = 30,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        // The status line's English words (StatusLines in HomeView). Its
        // hidden copies, which keep the line's height, carry no label.
        let speaking = app.staticTexts["Speaking"]
        XCTAssertTrue(
            speaking.waitForNonExistence(timeout: timeout),
            "\"Speaking\" still showed \(Int(timeout)) s later (\(context)): the phrase never ended",
            file: file, line: line
        )
    }

    /// Samples the empty gutter between Yes and No, not the coloured
    /// controls (which occupy most of a phone screenshot and have the same
    /// fill in both appearances). The screenshot is independent evidence
    /// that the requested appearance reached the rendered app.
    @MainActor
    func backgroundBrightness(of app: XCUIApplication, name: String) -> Double? {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        let yes = app.buttons["Yes"].frame
        let no = app.buttons["No"].frame
        guard no.minX - yes.maxX > 4,
              let image = screenshot.image.cgImage,
              app.frame.width > 0, app.frame.height > 0 else { return nil }
        let scaleX = Double(image.width) / app.frame.width
        let scaleY = Double(image.height) / app.frame.height
        let point = CGPoint(x: (yes.maxX + no.minX) / 2, y: yes.midY)
        let sampleRect = CGRect(
            x: (point.x - app.frame.minX) * scaleX - 1,
            y: (point.y - app.frame.minY) * scaleY - 1,
            width: 3, height: 3
        )
        guard CGRect(x: 0, y: 0, width: image.width, height: image.height).contains(sampleRect),
              let sample = image.cropping(to: sampleRect) else { return nil }
        var pixels = [UInt8](repeating: 0, count: 3 * 3 * 4)
        let drawn = pixels.withUnsafeMutableBytes { bytes -> Bool in
            guard let context = CGContext(
                data: bytes.baseAddress, width: 3, height: 3, bitsPerComponent: 8,
                bytesPerRow: 3 * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.draw(sample, in: CGRect(x: 0, y: 0, width: 3, height: 3))
            return true
        }
        guard drawn else { return nil }
        let brightness = stride(from: 0, to: pixels.count, by: 4).map { offset in
            (Double(pixels[offset]) + Double(pixels[offset + 1]) + Double(pixels[offset + 2])) / (3 * 255)
        }
        return brightness.reduce(0, +) / Double(brightness.count)
    }

}

/// The audit's guess that a phrase tile's label is "not human-readable"
/// (`assertPassesAccessibilityAudit`). Phrase tiles carry the identifier
/// "phraseTile" (HomeView's PhraseGrid).
@MainActor
private func isPhraseTileLabelGuess(_ issue: XCUIAccessibilityAuditIssue) -> Bool {
    guard issue.auditType == .sufficientElementDescription,
          let element = issue.element,
          element.identifier == "phraseTile" else { return false }
    return !element.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
}

/// The buttons on screen, as `attachCapture` records them.
private struct ControlCapture: Encodable {
    struct Control: Encodable {
        let label: String
        let identifier: String
        let isEnabled: Bool
        let isSelected: Bool
        let x: Double
        let y: Double
        let width: Double
        let height: Double
        let hasAncestorWindow: Bool
        let ancestorWindowIndex: Int?
        let ancestorWindowFrame: [String: Double]?
    }

    let schemaVersion = 2
    let rootSnapshotFrame: [String: Double]
    let windowFrames: [[String: Double]]
    let controls: [Control]

    @MainActor
    init(root: any XCUIElementSnapshot) {
        self.rootSnapshotFrame = Self.rect(root.frame)
        var windows: [[String: Double]] = []
        var controls: [Control] = []
        var pending: [(any XCUIElementSnapshot, Int?)] = [(root, nil)]
        while let (element, inheritedWindow) = pending.popLast() {
            var window = inheritedWindow
            if element.elementType == .window {
                window = windows.count
                windows.append(Self.rect(element.frame))
            }
            if element.elementType == .button {
                controls.append(Control(
                    label: element.label,
                    identifier: element.identifier,
                    isEnabled: element.isEnabled,
                    isSelected: element.isSelected,
                    x: element.frame.minX,
                    y: element.frame.minY,
                    width: element.frame.width,
                    height: element.frame.height,
                    hasAncestorWindow: window != nil,
                    ancestorWindowIndex: window,
                    ancestorWindowFrame: window.map { windows[$0] }
                ))
            }
            pending.append(contentsOf: element.children.reversed().map { ($0, window) })
        }
        self.windowFrames = windows
        self.controls = controls
    }

    private static func rect(_ frame: CGRect) -> [String: Double] {
        ["x": frame.minX, "y": frame.minY, "width": frame.width, "height": frame.height]
    }
}

private extension JSONEncoder {
    static var sortedPretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
