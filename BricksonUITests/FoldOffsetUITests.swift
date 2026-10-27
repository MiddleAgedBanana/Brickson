import XCTest

/// The real Home must consume the allocator's initial downward offset,
/// not only row heights and relative gaps. Omitting that leading space
/// leaves Phrases over the synthetic fold and Settings' Back elsewhere.
final class FoldOffsetUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = true }

    @MainActor
    func testTheFirstRowClearsATopDivisionInLightMode() throws {
        try checkTopDivision(appearance: .light)
    }

    @MainActor
    func testTheFirstRowClearsATopDivisionInDarkMode() throws {
        try checkTopDivision(appearance: .dark)
    }

    @MainActor
    private func checkTopDivision(appearance: UITestAppearance) throws {
        let ordinary = launchedApp(appearance: appearance, shortTimeouts: false)
        let baseline = try button("phrases", in: ordinary.snapshot())
        attachCapture(ordinary, name: "top-division-\(appearance.rawValue)-ordinary")
        ordinary.terminate()

        let app = launchedApp(
            appearance: appearance,
            arguments: ["--layout-fixture=top-division"],
            shortTimeouts: false
        )
        defer { app.terminate() }
        let home = try app.snapshot()
        let phrases = try button("phrases", in: home)
        let type = try button("type", in: home)
        attachCapture(app, name: "top-division-\(appearance.rawValue)-home")
        XCTAssertEqual(phrases.window.width, baseline.window.width, accuracy: 0.5)
        XCTAssertEqual(phrases.window.height, baseline.window.height, accuracy: 0.5)

        let ordinaryFrame = localFrame(baseline)
        let phrasesFrame = localFrame(phrases)
        let typeFrame = localFrame(type)
        // The fixture starts 12pt below the ordinary first-row top and is
        // 10pt high. Its far edge independently determines the expected
        // rendered origin; no frame from the fixture's engine supplies it.
        let division = CGRect(
            x: 0, y: ordinaryFrame.minY + 12,
            width: phrases.window.width, height: 10
        )
        let expectedTop = division.maxY
        try attachMeasurement([
            "appearance": appearance.rawValue,
            "ordinaryPhrases": rect(ordinaryFrame),
            "fixturePhrases": rect(phrasesFrame),
            "fixtureType": rect(typeFrame),
            "syntheticDivision": rect(division),
            "expectedFirstRowTop": expectedTop,
            "actualOSPoseClaimed": false,
        ], name: "top-division-\(appearance.rawValue)-frames")
        XCTAssertEqual(
            phrasesFrame.minY, expectedTop, accuracy: 0.5,
            "Home discarded the allocator's initial fold offset"
        )
        XCTAssertFalse(phrasesFrame.intersects(division), "Phrases crosses the synthetic division")
        XCTAssertFalse(typeFrame.intersects(division), "Type crosses the synthetic division")

        // Settings already applies the engine's absolute Back frame.
        // This measures the actual Home and actual cover independently,
        // each relative to its coherent ancestor window.
        app.buttons["settings"].tap()
        XCTAssertTrue(app.buttons["backToTalking"].waitForExistence(timeout: 10))
        let back = try button("backToTalking", in: app.snapshot())
        let backFrame = localFrame(back)
        attachCapture(app, name: "top-division-\(appearance.rawValue)-settings")
        try attachMeasurement([
            "homePhrases": rect(phrasesFrame),
            "settingsBack": rect(backFrame),
        ], name: "top-division-\(appearance.rawValue)-back-alignment")
        XCTAssertEqual(back.window.width, phrases.window.width, accuracy: 0.5)
        XCTAssertEqual(back.window.height, phrases.window.height, accuracy: 0.5)
        XCTAssertTrue(
            phrasesFrame.insetBy(dx: -0.5, dy: -0.5).contains(backFrame),
            "Settings' Back must close onto the actual rendered Phrases frame"
        )
        XCTAssertEqual(backFrame.minY, phrasesFrame.minY, accuracy: 0.5)
    }

    @MainActor
    private func button(
        _ identifier: String, in snapshot: any XCUIElementSnapshot
    ) throws -> SnapshotControlGeometry.Located {
        try SnapshotControlGeometry.locate(
            in: snapshot,
            frame: { $0.frame },
            isWindow: { $0.elementType == .window },
            target: .init(identifier: identifier, label: ""),
            identity: {
                $0.elementType == .button ? .init(identifier: $0.identifier, label: "") : nil
            },
            children: { $0.children }
        )
    }

    @MainActor
    private func localFrame(_ located: SnapshotControlGeometry.Located) -> CGRect {
        located.control.offsetBy(dx: -located.window.minX, dy: -located.window.minY)
    }

    private func rect(_ frame: CGRect) -> [String: Double] {
        ["x": frame.minX, "y": frame.minY, "width": frame.width, "height": frame.height]
    }

    @MainActor
    private func attachMeasurement(_ value: [String: Any], name: String) throws {
        let data = try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys, .prettyPrinted])
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
