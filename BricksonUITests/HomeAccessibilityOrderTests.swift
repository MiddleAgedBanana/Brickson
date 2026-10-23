import UIKit
import XCTest

/// The order in which assistive technologies reach Home's controls
/// (docs/ACCESSIBILITY.md, section 1): Yes, No and Emergency first, then
/// Again, all in the safety row; then the categories and Settings; then the
/// phrase tiles, each group inside its own region, the same in every state.
/// With Switch Control's auto scanning, every step before Emergency, Yes and
/// No is time spent waiting, so they come first although the message sits
/// above them on screen, and Again comes after Emergency although it sits
/// between No and Emergency (docs/DECISIONS.md, "Home's scan order and
/// names" and "Settings on Home").
///
/// The order is read from the accessibility tree the app hands to
/// VoiceOver, Switch Control and Full Keyboard Access, as XCTest sees it.
/// Whether each of them steps through it in this order, and whether the
/// regions become Switch Control's scan groups, needs a device
/// (docs/HANDOFF.md, *Checks that need a real device*).
final class HomeAccessibilityOrderTests: XCTestCase {
    /// `HomeRegion.identifier` in the app, in the order the regions are
    /// reached. A UI test cannot read the app's types, so these are copied.
    private static let safety = "homeRegion.safety"
    private static let message = "homeRegion.message"
    private static let categories = "homeRegion.categories"
    private static let phrases = "homeRegion.phrases"
    private static let regions: Set = [safety, message, categories, phrases]

    /// Copied from Brickson/Resources/StarterPhrases.json, as in
    /// `HomeLayoutTests`.
    private static let everydayCategories = ["Basics", "Needs", "Conversation", "Feelings"]

    /// The controls before the phrase tiles, in order, with their regions.
    private static let expectedOrder: [(label: String, region: String)] =
        [
            (label: "Yes", region: safety),
            (label: "No", region: safety),
            (label: "Emergency", region: safety),
            (label: "Get Attention", region: safety),
            (label: "Again", region: safety),
        ] + everydayCategories.map { (label: $0, region: categories) }
        + [(label: "Settings", region: categories)]

    /// Fails if anything comes before Yes, No and Emergency, if the order
    /// changes with the category, the emergency phrases or a phrase being
    /// spoken, or if a control sits outside its region.
    @MainActor
    func testQuickControlsComeFirstInEveryStateAtDefaultText() {
        checkEveryState(textSize: .large)
    }

    /// The same at the largest text size, where controls grow and the
    /// categories may wrap onto two rows.
    @MainActor
    func testQuickControlsComeFirstInEveryStateAtTheLargestText() {
        checkEveryState(textSize: .ax5)
    }

    @MainActor
    private func checkEveryState(textSize: UITestTextSize) {
        continueAfterFailure = true
        let app = launchedApp(textSize: textSize)
        let device = UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone"
        let configuration = "\(textSize.name), portrait, \(device)"

        check(app, state: "just opened", configuration: configuration)

        for category in Self.everydayCategories + ["Emergency"] {
            let button = app.buttons[category]
            button.tap()
            let selected = expectation(for: NSPredicate(format: "isSelected == true"), evaluatedWith: button)
            XCTAssertEqual(
                XCTWaiter.wait(for: [selected], timeout: 10), .completed,
                "\(category) was not selected (\(configuration))"
            )
            check(app, state: "\(category) showing", configuration: configuration)
        }

        app.buttons.matching(identifier: "phraseTile").firstMatch.tap()
        let againTurnsOn = expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: app.buttons["Again"])
        XCTAssertEqual(
            XCTWaiter.wait(for: [againTurnsOn], timeout: 15), .completed,
            "Again was still off 15 s after a phrase was chosen (\(configuration))"
        )
        check(app, state: "a phrase just spoken", configuration: configuration)
    }

    @MainActor
    private func check(_ app: XCUIApplication, state: String, configuration: String) {
        let context = "\(state); \(configuration)"
        let buttons: [OrderedButton]
        do {
            buttons = try orderedButtons(in: app)
        } catch {
            XCTFail("could not read Home's accessibility tree (\(context)): \(error)")
            return
        }
        let order = buttons.map { "\($0.label) [\($0.region ?? "no region")]" }.joined(separator: ", ")
        let attachment = XCTAttachment(string: order)
        attachment.name = "order-\(state)-\(configuration)"
        add(attachment)

        // Buttons outside Home's regions (none today) are listed in the
        // attachment but not checked here; every Home control is checked
        // to be inside its region below.
        let home = buttons.filter { $0.region != nil }
        let expected = Self.expectedOrder
        XCTAssertGreaterThan(home.count, expected.count, "Home shows no phrase tiles in its regions (\(context)): \(order)")
        XCTAssertEqual(
            home.prefix(expected.count).map(\.label), expected.map { $0.label },
            "Home's controls are out of order (\(context)): \(order)"
        )
        for (button, (label, region)) in zip(home, expected) where button.label == label {
            XCTAssertEqual(button.region, region, "\(label) is outside its region (\(context))")
        }
        for (index, tile) in home.dropFirst(expected.count).enumerated() {
            XCTAssertEqual(tile.identifier, "phraseTile", "control \(expected.count + index + 1), \"\(tile.label)\", is not a phrase tile (\(context)): \(order)")
            XCTAssertEqual(tile.region, Self.phrases, "\"\(tile.label)\" is outside the phrase region (\(context))")
        }
        for label in expected.map({ $0.label }) {
            XCTAssertTrue(
                home.contains { $0.label == label },
                "\(label) is not inside any of Home's regions (\(context)): \(order)"
            )
        }
    }

    /// A button as the accessibility tree lists it, and the Home region
    /// (by identifier) that holds it.
    private struct OrderedButton {
        let label: String
        let identifier: String
        let region: String?
    }

    /// Every button on screen, in the order the app's accessibility tree
    /// lists them: depth first, each container's children in their order.
    @MainActor
    private func orderedButtons(in app: XCUIApplication) throws -> [OrderedButton] {
        let root = try app.snapshot()
        var buttons: [OrderedButton] = []
        var pending: [(element: any XCUIElementSnapshot, region: String?)] = [(element: root, region: nil)]
        while let next = pending.popLast() {
            let element = next.element
            let region = Self.regions.contains(element.identifier) ? element.identifier : next.region
            if element.elementType == .button {
                buttons.append(OrderedButton(label: element.label, identifier: element.identifier, region: region))
                continue
            }
            pending.append(contentsOf: element.children.reversed().map { (element: $0, region: region) })
        }
        return buttons
    }
}
