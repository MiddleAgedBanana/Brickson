import Foundation

/// Test infrastructure only; never retries a reported accessibility finding.
@MainActor
enum AccessibilityAuditRunner {
    /// Runs `settle` and then `audit`. `settle` waits until nothing on screen
    /// changes by itself: Apple's audit compares a screenshot with the
    /// accessibility tree read a moment later, so text that leaves in
    /// between is reported as text with no element (issue #30). A retry
    /// starts from a settled screen too.
    static func perform(settle: () -> Void, _ audit: () throws -> Void) throws {
        settle()
        do {
            try audit()
        } catch {
            let failure = error as NSError
            guard failure.domain == "com.apple.xcode.xctest.accessibilityAudit",
                  failure.code == -56 else { throw error }
            print("Apple's accessibility audit service timed out; attempting the full audit once more.")
            // A second timeout propagates. XCTest findings already reported
            // by the handler remain failures, even if this attempt completes.
            settle()
            try audit()
        }
    }
}
