import Foundation
import Testing

/// The UI tests' wait limits (`UIWait`) and the words a wait adds when it
/// runs out (`UIWaitReport`). Drives no app; the same file is compiled into
/// the UI tests, whose waits in `Waiting.swift` use it (docs/DECISIONS.md,
/// "Tests").
struct UIWaitTests {
    private static let ended = Date(timeIntervalSince1970: 1_794_895_820)

    // Changing a limit's normal length fails here, so a change to how long
    // a stuck app is given is a change someone made on purpose.
    @Test func eachLimitHasItsNormalLengthAtAScaleOfOne() {
        #expect(UIWait.launch.limit(at: 1) == 30)
        #expect(UIWait.response.limit(at: 1) == 10)
        #expect(UIWait.speechEnd.limit(at: 1) == 30)
        #expect(UIWait.idleReset.limit(at: 1) == 30)
        #expect(UIWait.observation.limit(at: 1) == 3)
        #expect(UIWait.strict(seconds: 5).limit(at: 1) == 5)
    }

    // Making `limit(at:)` ignore the scale fails the stretched lines; letting
    // a strict limit stretch fails the last two, which keep a safety
    // control's first response as tight on CI as anywhere.
    @Test func everyLimitButAStrictOneStretchesWithTheScale() {
        #expect(UIWait.launch.limit(at: 3) == 90)
        #expect(UIWait.response.limit(at: 3) == 30)
        #expect(UIWait.speechEnd.limit(at: 3) == 90)
        #expect(UIWait.idleReset.limit(at: 3) == 90)
        #expect(UIWait.observation.limit(at: 3) == 9)
        #expect(UIWait.strict(seconds: 10).limit(at: 3) == 10)
        #expect(UIWait.strict(seconds: 5).limit(at: UIWait.largestScale) == 5)
    }

    // A scale below 1 would cut a wait short on a slow machine, and one with
    // no ceiling would let a stuck app hold a CI job past its time limit;
    // dropping either bound, or reading a word as a number, fails here.
    @Test func theScaleIsReadFromTheTestRunnersEnvironment() {
        let cases: [(String?, Double)] = [
            (nil, 1), ("3", 3), ("1.5", 1.5), ("1", 1),
            ("0.5", 1), ("0", 1), ("-2", 1),
            ("5", 5), ("100", 5),
            ("", 1), ("three", 1), ("nan", 1), ("inf", 1),
        ]
        for (text, scale) in cases {
            let environment = text.map { [UIWait.scaleVariable: $0] } ?? [:]
            #expect(UIWait.readScale(from: environment) == scale, "for \(text ?? "no value")")
        }
        #expect(UIWait.readScale(from: ["CI": "true"]) == 1)
    }

    // `scripts/test.sh` sets this name for the test runner, and
    // `scripts/test-runner.py` checks that the two still match.
    @Test func theScaleVariableKeepsItsName() {
        #expect(UIWait.scaleVariable == "BRICKSON_UI_WAIT_SCALE")
    }

    // A wait that ran out on an overloaded Mac must say how long it waited,
    // against which limit, and that one look at the app was itself slow;
    // dropping any of these words fails here.
    @Test func aWaitThatRanOutOnASlowMachineSaysSo() {
        let report = UIWaitReport(
            held: false, elapsed: .milliseconds(30_120), limit: 30, scale: 3,
            looks: 21, slowestLook: .seconds(12), ended: Self.ended
        )
        #expect(report.hadASlowLook)
        #expect(report.description == """
            waited 30.1 s (limit 30 s: 10 s times a scale of 3); looked 21 times, \
            the slowest look 12 s; ended at 2026-11-17T06:10:20Z. One look at the \
            app took 12 s: XCTest's query of the app was itself slow, a sign of an \
            overloaded machine.
            """)
    }

    // A wait whose looks were quick does not blame the machine, and an
    // unstretched limit names no scale.
    @Test func aQuickWaitDoesNotBlameTheMachine() {
        let report = UIWaitReport(
            held: true, elapsed: .milliseconds(400), limit: 10, scale: 1,
            looks: 1, slowestLook: .milliseconds(380), ended: Self.ended
        )
        #expect(!report.hadASlowLook)
        #expect(report.description == """
            waited 0.4 s (limit 10 s); looked 1 time, the slowest look 0.4 s; \
            ended at 2026-11-17T06:10:20Z.
            """)
    }

    // Moving the slow-look line, or comparing with > instead of >=, fails here.
    @Test func aLookOfFiveSecondsOrMoreIsSlow() {
        func report(slowest: Duration) -> UIWaitReport {
            UIWaitReport(
                held: true, elapsed: .seconds(6), limit: 10, scale: 1,
                looks: 2, slowestLook: slowest, ended: Self.ended
            )
        }
        #expect(!report(slowest: .milliseconds(4_999)).hadASlowLook)
        #expect(report(slowest: .seconds(5)).hadASlowLook)
    }

    @Test func secondsAreWrittenToOneDecimalPlaceWithoutATrailingZero() {
        #expect(UIWaitReport.seconds(12) == "12")
        #expect(UIWaitReport.seconds(0.44) == "0.4")
        #expect(UIWaitReport.seconds(9.96) == "10")
        #expect(UIWaitReport.seconds(.milliseconds(1_500)) == "1.5")
        #expect(UIWaitReport.seconds(.seconds(90)) == "90")
    }
}
