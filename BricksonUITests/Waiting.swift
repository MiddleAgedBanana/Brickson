import XCTest

// Every wait in the UI tests goes through these, with a limit from
// `UIWait` (scripts/ui-test-waits.py refuses any other wait).

extension XCTestCase {
    /// Looks at `condition` until it holds or `wait`'s limit has passed,
    /// about twice a second, and says what it saw. Fails nothing itself;
    /// every wait below goes through it.
    ///
    /// A look that begins before the limit counts even if it ends after
    /// it: on an overloaded Mac one query of the app has taken 12 seconds,
    /// and its answer is still the app's answer. The test makes each look
    /// itself, on the main actor, rather than through XCTest's predicate
    /// expectations, which XCTest documents as evaluated on the main actor
    /// only for `fulfillment(of:)` (`KeyboardProbeTests`). A wait with a
    /// look slower than `UIWaitReport.slowLook` prints its report to the
    /// log even when it ends well, since XCTest may have failed that look
    /// itself ("Timed out while evaluating UI query").
    @MainActor
    func look(_ wait: UIWait, until condition: () -> Bool) -> UIWaitReport {
        let clock = ContinuousClock()
        let limit = wait.seconds
        let start = clock.now
        let deadline = start + wait.duration
        var looks = 0
        var slowest = Duration.zero
        while true {
            let before = clock.now
            let held = condition()
            let after = clock.now
            looks += 1
            slowest = max(slowest, after - before)
            if held || after >= deadline {
                let report = UIWaitReport(
                    held: held,
                    elapsed: after - start,
                    limit: limit,
                    scale: wait.stretches ? UIWait.scale : 1,
                    looks: looks,
                    slowestLook: slowest,
                    ended: .now
                )
                if report.hadASlowLook {
                    print("UI-WAIT \(held ? "held" : "ran out"): \(report.description)")
                }
                return report
            }
            _ = XCTWaiter.wait(
                for: [XCTestExpectation(description: "the pause between two looks")],
                timeout: UIWait.pauseBetweenLooks
            )
        }
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
