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
    /// with short idle limits, in English, at the given text size,
    /// appearance and orientation. It waits for Home (unless
    /// `waitsForHome` is false, for a test that starts on another screen)
    /// and fails if Home says changes won't be kept, which would mean the
    /// test storage did not open.
    ///
    /// Orientation and appearance are simulator-wide, so they are put back
    /// (portrait, the earlier appearance) when the test ends.
    @MainActor
    @discardableResult
    func launchedApp(
        textSize: UITestTextSize = .large,
        appearance: XCUIDevice.Appearance = .light,
        orientation: UIDeviceOrientation = .portrait,
        storage: UITestStorage = .fresh,
        arguments: [String] = [],
        waitsForHome: Bool = true,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> XCUIApplication {
        let device = XCUIDevice.shared
        let earlierAppearance = device.appearance
        addTeardownBlock {
            await MainActor.run {
                XCUIDevice.shared.orientation = .portrait
                XCUIDevice.shared.appearance = earlierAppearance
            }
        }
        device.appearance = appearance
        device.orientation = orientation

        let app = XCUIApplication()
        app.launchArguments = [
            storage == .fresh ? "--fresh-test-storage" : "--test-storage",
            "--short-timeouts",
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
            let capture = ControlCapture(window: app.frame, root: snapshot)
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
        let frame = control.frame
        XCTAssertTrue(control.isHittable, "\(label) cannot be activated (\(context)); frame \(frame)", file: file, line: line)
        XCTAssertTrue(
            app.frame.insetBy(dx: -1, dy: -1).contains(frame),
            "\(label) is not wholly on screen (\(context)): frame \(frame), window \(app.frame)",
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
    @MainActor
    func assertPassesAccessibilityAudit(
        _ app: XCUIApplication,
        context: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        try AccessibilityAuditRunner.perform {
            try app.performAccessibilityAudit { issue in
                MainActor.assumeIsolated {
                    if isPhraseTileLabelGuess(issue) { return }
                    let element = issue.element.map {
                        "\"\($0.label)\" (identifier \"\($0.identifier)\", frame \($0.frame))"
                    } ?? "no element"
                    XCTFail(
                        "Accessibility audit (\(context); type \(issue.auditType.rawValue)): \(issue.compactDescription) on \(element). \(issue.detailedDescription)",
                        file: file, line: line
                    )
                }
                // Reported above (or expected); returning true stops the
                // audit failing a second time with less detail.
                return true
            }
        }
    }

    /// On the iPhone, today's stand-in Home fails two kinds of audit
    /// finding: "Dynamic Type font sizes are partially unsupported" on
    /// phrase tiles, and "Text clipped" on Yes, Emergency, phrase tiles and
    /// the Speaking label (first seen on CI on 2026-10-21, when the UI
    /// tests began running on an iPhone too). They are real and still
    /// reported, as expected failures; the phone layout work fixes them
    /// (docs/DECISIONS.md, "Home version 0 is a stand-in"). The expectation
    /// is strict: once the iPhone passes, the test fails until this call is
    /// removed. Only those pairs of kind and element are expected: the same
    /// kind on any other element, any other kind, and any finding on the
    /// iPad still fail the test.
    @MainActor
    func expectKnownPhoneHomeAuditFindings() {
        guard UIDevice.current.userInterfaceIdiom == .phone else { return }
        // How assertPassesAccessibilityAudit names a kind and an element.
        func kind(_ type: XCUIAccessibilityAuditType) -> String { "; type \(type.rawValue)):" }
        let tile = "(identifier \"phraseTile\""
        func control(_ label: String) -> String { "on \"\(label)\" (identifier \"\"" }
        let known = [
            (kind(.dynamicType), tile),
            (kind(.textClipped), tile),
            (kind(.textClipped), control("Yes")),
            (kind(.textClipped), control("Emergency")),
            (kind(.textClipped), control("Speaking")),
        ]
        let options = XCTExpectedFailure.Options()
        options.issueMatcher = { issue in
            let text = issue.compactDescription
            return text.contains("Accessibility audit (")
                && known.contains { text.contains($0.0) && text.contains($0.1) }
        }
        XCTExpectFailure(
            "Known iPhone audit findings on the stand-in Home (docs/DECISIONS.md, \"Home version 0 is a stand-in\")",
            options: options
        )
    }

    /// How bright most of the screen is: the median brightness of a 24×24
    /// grid of points spread over the app's screenshot, where 0 is black
    /// and 1 is white. Most points land on the background, so the median
    /// follows it, whatever the tiles in between are coloured. Nil if the
    /// screenshot cannot be read. The screenshot is kept in the results,
    /// named by `name`, so a surprising number can be checked by eye.
    @MainActor
    func backgroundBrightness(of app: XCUIApplication, name: String) -> Double? {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        guard let image = screenshot.image.cgImage else { return nil }
        let width = image.width
        let height = image.height
        guard width > 0, height > 0 else { return nil }
        // Draw the whole screenshot once into plain 8-bit RGBA, top row
        // first, whatever format the screenshot itself uses.
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = pixels.withUnsafeMutableBytes { bytes -> Bool in
            guard let context = CGContext(
                data: bytes.baseAddress, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return nil }
        let steps = 24
        var samples: [Double] = []
        for row in 0..<steps {
            for column in 0..<steps {
                let x = (2 * column + 1) * width / (2 * steps)
                let y = (2 * row + 1) * height / (2 * steps)
                let offset = (y * width + x) * 4
                samples.append(
                    (Double(pixels[offset]) + Double(pixels[offset + 1]) + Double(pixels[offset + 2])) / (3 * 255)
                )
            }
        }
        samples.sort()
        return samples[samples.count / 2]
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
    }

    let window: [String: Double]
    let controls: [Control]

    @MainActor
    init(window: CGRect, root: any XCUIElementSnapshot) {
        self.window = ["x": window.minX, "y": window.minY, "width": window.width, "height": window.height]
        var controls: [Control] = []
        var pending: [any XCUIElementSnapshot] = [root]
        while let element = pending.popLast() {
            if element.elementType == .button {
                controls.append(Control(
                    label: element.label,
                    identifier: element.identifier,
                    isEnabled: element.isEnabled,
                    isSelected: element.isSelected,
                    x: element.frame.minX,
                    y: element.frame.minY,
                    width: element.frame.width,
                    height: element.frame.height
                ))
            }
            pending.append(contentsOf: element.children.reversed())
        }
        self.controls = controls
    }
}

private extension JSONEncoder {
    static var sortedPretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
