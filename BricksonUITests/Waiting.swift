import XCTest

// Every wait in the UI tests goes through these, with a limit from
// `UIWait` (scripts/ui-test-waits.py refuses any other wait).

extension XCTestCase {
    /// Looks at `condition` until it holds or `wait`'s limit has passed,
    /// about twice a second, and says what it saw (`UIWait.watch`, which
    /// also says which looks count). Fails nothing itself; every wait below
    /// goes through it.
    ///
    /// The test makes each look itself, on the main actor, rather than
    /// through XCTest's predicate expectations, which XCTest documents as
    /// evaluated on the main actor only for `fulfillment(of:)`
    /// (`KeyboardProbeTests`). A wait with a look slower than
    /// `UIWaitReport.slowLook` prints its report to the log even when it
    /// ends well, since XCTest may have failed that look itself ("Timed out
    /// while evaluating UI query").
    @MainActor
    func look(_ wait: UIWait, until condition: () -> Bool) -> UIWaitReport {
        let report = wait.watch(
            at: UIWait.scale,
            now: { ContinuousClock.now },
            pause: { pause in
                _ = XCTWaiter.wait(
                    for: [XCTestExpectation(description: "the pause between two looks")],
                    timeout: UIWait.seconds(in: pause)
                )
            },
            date: { .now },
            until: condition
        )
        if report.hadASlowLook {
            print("UI-WAIT \(report.held ? "held" : "ran out"): \(report.description)")
        }
        return report
    }

    /// Waits until `condition` holds. If it does not within `wait`'s
    /// limit, fails with `message` followed by what the wait saw
    /// (`UIWaitReport`). Returns whether it held.
    @MainActor
    @discardableResult
    func waitUntil(
        within wait: UIWait = .response,
        _ message: @autoclosure () -> String,
        file: StaticString = #filePath,
        line: UInt = #line,
        until condition: () -> Bool
    ) -> Bool {
        let report = look(wait, until: condition)
        if !report.held {
            XCTFail("\(message()); \(report.description)", file: file, line: line)
        }
        return report.held
    }

    /// Waits until `element` exists, failing with `message` if it does not
    /// within `wait`'s limit.
    @MainActor
    @discardableResult
    func waitToAppear(
        _ element: XCUIElement,
        within wait: UIWait = .response,
        _ message: @autoclosure () -> String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> Bool {
        waitUntil(within: wait, message(), file: file, line: line) { element.exists }
    }

    /// Waits until `element` no longer exists, failing with `message` if it
    /// still does after `wait`'s limit.
    @MainActor
    @discardableResult
    func waitToDisappear(
        _ element: XCUIElement,
        within wait: UIWait = .response,
        _ message: @autoclosure () -> String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> Bool {
        waitUntil(within: wait, message(), file: file, line: line) { !element.exists }
    }

    /// Whether `element` exists within `wait`'s limit. Fails nothing: for
    /// a watch over something that must not happen (`UIWait.observation`),
    /// a probe that records what happened, or a step the test takes only
    /// if the app did not already (tapping a field the screen did not
    /// focus). Ends as soon as the element exists.
    @MainActor
    func appears(_ element: XCUIElement, within wait: UIWait) -> Bool {
        look(wait) { element.exists }.held
    }
}
