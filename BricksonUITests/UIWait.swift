import Foundation

/// How long a UI test gives the app, in one place, so that a slow machine
/// and a broken app fail differently (docs/DECISIONS.md, "Tests",
/// 2026-11-17).
///
/// Every wait in the UI tests watches a real condition (a screen opened, a
/// control turned on, speech ended) and ends as soon as it holds, so its
/// limit costs nothing while the app is well: the limit only decides how
/// long a stuck app is given before the test fails. GitHub's Macs are
/// sometimes so overloaded that a working app answers after a limit set
/// for a normal machine has run out, so on CI every limit that stretches is
/// `scale` times its normal length: `scripts/test.sh` passes
/// `BRICKSON_UI_WAIT_SCALE` to the test runner when `CI` is `true`. A wait
/// that runs out says what it waited for, how long, against which limit,
/// how many times it looked and how long its slowest look took
/// (`UIWaitReport`).
///
/// The waits themselves are in `Waiting.swift`; nothing else in the UI
/// tests names a number of seconds to wait (`scripts/ui-test-waits.py`).
/// Never lengthen a limit past what a slow but working machine needs, since
/// that only delays the failure of a stuck app, and never stretch a
/// `strict` one.
///
/// Compiled into the unit tests too, where `UIWaitTests` checks the limits,
/// the scale and the report's words.
nonisolated struct UIWait: Equatable, Sendable {
    /// The limit on a machine that is not overloaded, in seconds.
    let normalSeconds: Double
    /// False for a limit the scale never stretches (`strict`).
    let stretches: Bool

    /// The app's first screen after a launch. Launches took up to about
    /// 12 seconds on GitHub's overloaded Macs, on top of XCTest's own
    /// launch; 30 seconds here, 90 on CI.
    static let launch = UIWait(normalSeconds: 30, stretches: true)

    /// What one action changes: a screen opening or closing, a control
    /// appearing, turning on or being chosen, the keyboard showing, the
    /// window turning, the layout settling.
    static let response = UIWait(normalSeconds: 10, stretches: true)

    /// A response the tests have always given 5 seconds rather than 10:
    /// a tap, press or hold speaking its phrase, Home's first tile or text
    /// showing, a control still being there. Kept at 5 so that on a Mac
    /// these waits are as long as they were; 15 on CI.
    static let quickResponse = UIWait(normalSeconds: 5, stretches: true)

    /// A spoken phrase ending ("Speaking" leaving Home). On an overloaded
    /// Mac the simulator's voice took more than 30 seconds to say "Yes.",
    /// once more than a minute.
    static let speechEnd = UIWait(normalSeconds: 30, stretches: true)

    /// Settings' 3-second idle limit (`--short-timeouts`) passing, and the
    /// first screen it returns to.
    static let idleReset = UIWait(normalSeconds: 30, stretches: true)

    /// How long a test watches for something that must not happen (a
    /// slide that must not speak) or that may happen (what a probe
    /// records). Stretched on CI too: an overloaded Mac gives the app less
    /// of each second, so a short watch would see less of what it does.
    static let observation = UIWait(normalSeconds: 3, stretches: true)

    /// A limit that is the same on CI, for the first response of a safety
    /// control in the test that proves it: a phrase starting on the first
    /// tap, Emergency showing its phrases, Get Attention sounding. Each
    /// keeps the limit it had before the scale existed, so that a delay
    /// before the response (a load before speaking, say) fails there on
    /// every machine. The person's own bound, a response within half a
    /// second, is measured on a device before release, never on a
    /// simulator (docs/DECISIONS.md, "Every release passes the quality
    /// bar").
    static func strict(seconds: Double) -> UIWait {
        UIWait(normalSeconds: seconds, stretches: false)
    }

    /// The limit at `scale`, in seconds.
    func limit(at scale: Double) -> Double {
        stretches ? normalSeconds * scale : normalSeconds
    }

    /// `duration` in seconds, as XCTest counts time.
    static func seconds(in duration: Duration) -> Double {
        let parts = duration.components
        return Double(parts.seconds) + Double(parts.attoseconds) / 1e18
    }

    /// The test runner's variable for the scale, set by `scripts/test.sh`.
    static let scaleVariable = "BRICKSON_UI_WAIT_SCALE"

    /// The largest scale: a stuck app still fails within a few minutes per
    /// wait, well inside a CI job's time limit.
    static let largestScale = 5.0

    /// How much longer than normal this run's limits are.
    static let scale = readScale(from: ProcessInfo.processInfo.environment)

    /// The scale `environment` asks for: 1 when it asks for none or for
    /// something that is not a number, never below 1 (a scale only ever
    /// gives a slow machine more time, never takes time from a wait), and
    /// never above `largestScale`.
    static func readScale(from environment: [String: String]) -> Double {
        guard let text = environment[scaleVariable], let value = Double(text), value.isFinite else {
            return 1
        }
        return min(max(value, 1), largestScale)
    }

    /// How long a wait pauses between two looks at the app, in seconds:
    /// about as often as XCTest's own waits look.
    static let pauseBetweenLooks = 0.5

    /// Looks at `condition` until it holds or this limit at `scale` has
    /// passed, pausing between looks, and says what it saw. Every UI test
    /// wait goes through this (`Waiting.swift`, with the real clock and
    /// XCTest's pause); `UIWaitTests` drives it with a clock of its own.
    ///
    /// A look that starts before the limit counts even if it ends after
    /// it: on an overloaded Mac one query of the app has taken 12 seconds,
    /// and its answer is still the app's answer. No look starts after the
    /// limit: a pause that ends late, as one can on an overloaded Mac, ends
    /// the wait, so no later look can pass a strict limit.
    func watch(
        at scale: Double,
        now: () -> ContinuousClock.Instant,
        pause: (Duration) -> Void,
        date: () -> Date,
        until condition: () -> Bool
    ) -> UIWaitReport {
        let start = now()
        let deadline = start + .seconds(limit(at: scale))
        var held = false
        var looks = 0
        var slowest = Duration.zero
        var end = start
        repeat {
            let before = now()
            held = condition()
            end = now()
            looks += 1
            slowest = max(slowest, end - before)
            if held || end >= deadline {
                break
            }
            pause(min(.seconds(Self.pauseBetweenLooks), deadline - end))
            end = now()
        } while end < deadline
        return UIWaitReport(
            held: held,
            elapsed: end - start,
            limit: limit(at: scale),
            scale: stretches ? scale : 1,
            looks: looks,
            slowestLook: slowest,
            ended: date()
        )
    }
}

/// What one wait saw, for the words its failure adds to the test's own
/// message.
nonisolated struct UIWaitReport: Equatable, Sendable {
    /// Whether a look that started before the limit found the condition
    /// holding.
    let held: Bool
    /// From the start of the first look to the end of the wait.
    let elapsed: Duration
    /// The limit the wait had, in seconds.
    let limit: Double
    /// The scale that stretched it; 1 when it did not stretch.
    let scale: Double
    /// How many times the wait looked at the app.
    let looks: Int
    /// The longest a single look took.
    let slowestLook: Duration
    /// When the wait ended. On CI this is the time to find in the run's
    /// simulator-load record, which says what kept the Mac busy then.
    let ended: Date

    /// A single look at the app slower than this means XCTest's own query
    /// of the app was slow: a normal look takes well under a second, and
    /// on an overloaded Mac single looks took up to 12 seconds.
    static let slowLook: Duration = .seconds(5)

    /// Whether one look took long enough to point at an overloaded machine.
    var hadASlowLook: Bool { slowestLook >= Self.slowLook }

    /// For example: "waited 30.1 s (limit 30 s: 10 s times a scale of 3);
    /// looked 21 times, the slowest look 12 s; ended at
    /// 2026-11-17T06:10:20Z. One look at the app took 12 s: XCTest's query
    /// of the app was itself slow, a sign of an overloaded machine."
    var description: String {
        let limitWords: String
        if scale > 1 {
            limitWords = "limit \(Self.seconds(limit)) s: \(Self.seconds(limit / scale)) s times a scale of \(Self.seconds(scale))"
        } else {
            limitWords = "limit \(Self.seconds(limit)) s"
        }
        var words = "waited \(Self.seconds(elapsed)) s (\(limitWords)); "
            + "looked \(looks) \(looks == 1 ? "time" : "times"), the slowest look \(Self.seconds(slowestLook)) s; "
            + "ended at \(ended.formatted(.iso8601))."
        if hadASlowLook {
            words += " One look at the app took \(Self.seconds(slowestLook)) s: XCTest's query of the app was itself slow, a sign of an overloaded machine."
        }
        return words
    }

    /// Seconds to one decimal place, without a trailing ".0".
    static func seconds(_ value: Double) -> String {
        let text = String(format: "%.1f", value)
        return text.hasSuffix(".0") ? String(text.dropLast(2)) : text
    }

    static func seconds(_ duration: Duration) -> String {
        seconds(UIWait.seconds(in: duration))
    }
}
