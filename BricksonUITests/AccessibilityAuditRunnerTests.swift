import XCTest

@MainActor
final class AccessibilityAuditRunnerTests: XCTestCase {
    private let timeout = NSError(domain: "com.apple.xcode.xctest.accessibilityAudit", code: -56)

    // Removing the retry makes this throw after one call.
    func testAuditServiceTimeoutGetsOneFreshAttempt() throws {
        var calls = 0
        try AccessibilityAuditRunner.perform(settle: {}) {
            calls += 1
            if calls == 1 { throw timeout }
        }
        XCTAssertEqual(calls, 2)
    }

    // Swallowing a persistent timeout or adding unlimited retries fails this.
    func testRepeatedTimeoutStillFails() {
        var calls = 0
        XCTAssertThrowsError(try AccessibilityAuditRunner.perform(settle: {}) {
            calls += 1
            throw timeout
        }) { error in
            XCTAssertEqual((error as NSError).domain, timeout.domain)
            XCTAssertEqual((error as NSError).code, timeout.code)
        }
        XCTAssertEqual(calls, 2)
    }

    // Broadening the retry to other audit errors or other domains fails this.
    func testOtherErrorsFailWithoutRetry() {
        for error in [
            NSError(domain: timeout.domain, code: -1),
            NSError(domain: "another.service", code: -56)
        ] {
            var calls = 0
            XCTAssertThrowsError(try AccessibilityAuditRunner.perform(settle: {}) {
                calls += 1
                throw error
            }) { caught in
                XCTAssertEqual((caught as NSError).domain, error.domain)
                XCTAssertEqual((caught as NSError).code, error.code)
            }
            XCTAssertEqual(calls, 1)
        }
    }

    // Running a successful audit twice fails this.
    func testSuccessfulAuditRunsOnce() throws {
        var calls = 0
        try AccessibilityAuditRunner.perform(settle: {}) { calls += 1 }
        XCTAssertEqual(calls, 1)
    }

    // Issue #30. Dropping the settle step, or running it after the audit,
    // fails this.
    func testTheScreenSettlesBeforeTheAudit() throws {
        var steps: [String] = []
        try AccessibilityAuditRunner.perform(settle: { steps.append("settle") }) {
            steps.append("audit")
        }
        XCTAssertEqual(steps, ["settle", "audit"])
    }

    // Retrying on a screen that may have changed during the timed-out
    // attempt, without settling again, fails this.
    func testARetrySettlesTheScreenAgain() throws {
        var steps: [String] = []
        try AccessibilityAuditRunner.perform(settle: { steps.append("settle") }) {
            steps.append("audit")
            if steps.count == 2 { throw timeout }
        }
        XCTAssertEqual(steps, ["settle", "audit", "settle", "audit"])
    }
}
