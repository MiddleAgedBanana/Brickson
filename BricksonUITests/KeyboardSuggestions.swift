import XCTest

// Apple's keyboard shows a bar of word suggestions above its keys, three
// buttons on a phone. On a simulator whose keyboard has never shown, those
// buttons can stay without words, and so without accessibility labels,
// for as long as that first showing lasts: two minutes and more on the
// Mac, and every audit of the screen then reports each empty button as an
// element with no description. Waiting changes nothing; the next showing
// of the keyboard has its words at once (docs/DECISIONS.md, "Tests",
// 2026-11-17). The bar is Apple's, not Brickson's.

extension XCTestCase {
    /// The words on the keyboard's suggestion buttons, leading to
    /// trailing, or nil when no suggestion bar shows. The bar is the
    /// element Apple labels "Typing Predictions" (in English, which every
    /// UI test runs in); an empty string is a button with no word.
    @MainActor
    func keyboardSuggestions(in app: XCUIApplication) throws -> [String]? {
        let bar = app.otherElements.matching(NSPredicate(format: "label == %@", "Typing Predictions")).firstMatch
        guard bar.exists else { return nil }
        return Self.buttonLabels(in: try bar.snapshot())
    }

    /// Waits until the keyboard's suggestion bar shows a word on every
    /// button, so that an audit of the screen meets the bar as people see
    /// it. If the bar has no words after `firstLook` seconds, calls
    /// `showAgain`, which must put the keyboard away and bring it back on
    /// the same screen, then waits up to `secondLook` seconds more. Fails,
    /// keeping a capture of the screen, if the bar still has an empty
    /// button: an audit then would report Apple's empty buttons, not
    /// Brickson's screen. Returns the words it saw, or no words at once
    /// when the keyboard shows no suggestion buttons for three seconds
    /// (Predictive Text turned off, say), where an audit meets none.
    /// `context` names the screen in the failure.
    @MainActor
    @discardableResult
    func waitForKeyboardSuggestions(
        in app: XCUIApplication,
        context: String,
        firstLook: TimeInterval = 15,
        secondLook: TimeInterval = 30,
        file: StaticString = #filePath,
        line: UInt = #line,
        showAgain: () -> Void
    ) -> [String] {
        for (showing, limit) in [("first", firstLook), ("second", secondLook)] {
            if showing == "second" {
                showAgain()
            }
            switch lookForKeyboardSuggestions(in: app, for: limit) {
            case .words(let words):
                noteKeyboardSuggestions("\(context): \(words) on the \(showing) showing")
                return words
            case .noButtons(let seen):
                noteKeyboardSuggestions("\(context): \(seen) on the \(showing) showing, so none for an audit to meet")
                return []
            case .empty(let seen):
                guard showing == "second" else {
                    noteKeyboardSuggestions("\(context): \(seen) after \(Int(limit)) s; showing the keyboard again")
                    continue
                }
                attachCapture(app, name: "Keyboard suggestions still empty, \(context)")
                XCTFail(
                    "The keyboard's suggestion bar on \(context) still had no words \(Int(limit)) s after the "
                        + "keyboard was shown again (last seen: \(seen)), so an audit would report Apple's empty "
                        + "suggestion buttons rather than this screen (docs/DECISIONS.md, \"Tests\", 2026-11-17)",
                    file: file, line: line
                )
            }
        }
        return []
    }

    /// Prints `line` as `KEYBOARD-SUGGESTIONS <line>` and keeps it in the
    /// test's results, so a passing run on CI also says which showing had
    /// the words.
    @MainActor
    private func noteKeyboardSuggestions(_ line: String) {
        print("KEYBOARD-SUGGESTIONS \(line)")
        let attachment = XCTAttachment(string: line)
        attachment.name = "KEYBOARD-SUGGESTIONS"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Looks at the suggestion bar every half second for up to `seconds`:
    /// `.words` once every button has a word; `.noButtons` when no
    /// suggestion button has shown for the first three seconds; otherwise
    /// `.empty` with what the last look found.
    @MainActor
    private func lookForKeyboardSuggestions(in app: XCUIApplication, for seconds: TimeInterval) -> SuggestionLook {
        let clock = ContinuousClock()
        let start = clock.now
        let end = start + .milliseconds(Int(seconds * 1000))
        var buttonsShown = false
        var lastSeen = "nothing yet"
        while true {
            do {
                let words = try keyboardSuggestions(in: app)
                if let words, !words.isEmpty {
                    buttonsShown = true
                    if words.allSatisfy({ !$0.isEmpty }) { return .words(words) }
                    lastSeen = "\(words)"
                } else {
                    lastSeen = words == nil ? "no suggestion bar" : "a suggestion bar with no buttons"
                    if !buttonsShown, clock.now - start >= .seconds(3) { return .noButtons(lastSeen) }
                }
            } catch {
                lastSeen = "a suggestion bar that could not be read (\(error.localizedDescription))"
            }
            guard clock.now < end else { return .empty(lastSeen) }
            _ = XCTWaiter.wait(
                for: [XCTestExpectation(description: "the pause between two looks at the suggestion bar")],
                timeout: 0.5
            )
        }
    }

    /// The labels of every button in `snapshot`, in the tree's order.
    @MainActor
    private static func buttonLabels(in snapshot: XCUIElementSnapshot) -> [String] {
        (snapshot.elementType == .button ? [snapshot.label] : []) + snapshot.children.flatMap { buttonLabels(in: $0) }
    }
}

/// What one look at the keyboard's suggestion bar found.
private enum SuggestionLook {
    /// Every suggestion button has a word.
    case words([String])
    /// No suggestion button showed: no bar, or a bar with no buttons.
    case noButtons(String)
    /// A suggestion button still had no word when the time ran out.
    case empty(String)
}
