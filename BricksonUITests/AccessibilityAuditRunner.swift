import Foundation

/// Test infrastructure only; never retries a reported accessibility finding.
@MainActor
enum AccessibilityAuditRunner {
    static func perform(_ audit: () throws -> Void) throws {
        do {
            try audit()
        } catch {
            let failure = error as NSError
            guard failure.domain == "com.apple.xcode.xctest.accessibilityAudit",
                  failure.code == -56 else { throw error }
            print("Apple's accessibility audit service timed out; attempting the full audit once more.")
            // A second timeout propagates. XCTest findings already reported
            // by the handler remain failures, even if this attempt completes.
            try audit()
        }
    }
}
