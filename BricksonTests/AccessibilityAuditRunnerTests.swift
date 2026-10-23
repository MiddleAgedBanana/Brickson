import Foundation
import Testing

/// `AccessibilityAuditRunner` lives with the UI tests and is compiled here
/// too: these tests drive no app, so they use Swift Testing rather than
/// XCTest (docs/DECISIONS.md, "Apple's current frameworks first").
struct AccessibilityAuditRunnerTests {
    private let timeout = NSError(domain: "com.apple.xcode.xctest.accessibilityAudit", code: -56)

    // Removing the retry makes this throw after one call.
    @Test func anAuditServiceTimeoutGetsOneFreshAttempt() throws {
        var calls = 0
        try AccessibilityAuditRunner.perform(settle: {}) {
            calls += 1
            if calls == 1 { throw timeout }
        }
        #expect(calls == 2)
    }

    // Swallowing a persistent timeout or adding unlimited retries fails this.
    @Test func aRepeatedTimeoutStillFails() {
        var calls = 0
        let error = failure {
            try AccessibilityAuditRunner.perform(settle: {}) {
                calls += 1
                throw timeout
            }
        }
        #expect(error?.domain == timeout.domain)
        #expect(error?.code == timeout.code)
        #expect(calls == 2)
    }

    // Broadening the retry to other audit errors or other domains fails this.
    @Test func otherErrorsFailWithoutRetry() {
        for error in [
            NSError(domain: timeout.domain, code: -1),
            NSError(domain: "another.service", code: -56)
        ] {
            var calls = 0
            let caught = failure {
                try AccessibilityAuditRunner.perform(settle: {}) {
                    calls += 1
                    throw error
                }
            }
            let name = "\(error.domain) \(error.code)"
            #expect(caught?.domain == error.domain, "\(name)")
            #expect(caught?.code == error.code, "\(name)")
            #expect(calls == 1, "\(name)")
        }
    }

    // Running a successful audit twice fails this.
    @Test func aSuccessfulAuditRunsOnce() throws {
        var calls = 0
        try AccessibilityAuditRunner.perform(settle: {}) { calls += 1 }
        #expect(calls == 1)
    }

    // Issue #30. Dropping the settle step, or running it after the audit,
    // fails this.
    @Test func theScreenSettlesBeforeTheAudit() throws {
        var steps: [String] = []
        try AccessibilityAuditRunner.perform(settle: { steps.append("settle") }) {
            steps.append("audit")
        }
        #expect(steps == ["settle", "audit"])
    }

    // Retrying on a screen that may have changed during the timed-out
    // attempt, without settling again, fails this.
    @Test func aRetrySettlesTheScreenAgain() throws {
        var steps: [String] = []
        try AccessibilityAuditRunner.perform(settle: { steps.append("settle") }) {
            steps.append("audit")
            if steps.count == 2 { throw timeout }
        }
        #expect(steps == ["settle", "audit", "settle", "audit"])
    }

    /// The error `body` throws, as an `NSError`, or nil if it throws none.
    private func failure(_ body: () throws -> Void) -> NSError? {
        do {
            try body()
            return nil
        } catch {
            return error as NSError
        }
    }
}
