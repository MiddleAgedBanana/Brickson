import Foundation
import Testing
@testable import Brickson

/// A family member can walk away from Settings mid-task. The person using
/// Brickson must not be stranded there, and Settings must never close by
/// itself (that would put Home's controls under a spot nobody chose).
struct SettingsIdleClockTests {
    private let start = ContinuousClock.now

    @Test func settingsResetsAfterNinetySecondsWithNothingUsed() {
        let clock = SettingsIdleClock(startedAt: start)

        #expect(SettingsIdleClock.standardLimit == .seconds(90))
        #expect(!clock.isDue(at: start + .seconds(89.9)))
        #expect(clock.isDue(at: start + .seconds(90)))
    }

    @Test func anyActivityStartsTheWaitAgain() {
        var clock = SettingsIdleClock(startedAt: start)
        clock.recordActivity(at: start + .seconds(80))

        #expect(!clock.isDue(at: start + .seconds(169)))
        #expect(clock.isDue(at: start + .seconds(170)))
    }

    /// Activity reported out of order (a late scroll callback) must not pull
    /// the deadline earlier.
    @Test func olderActivityNeverBringsTheResetForward() {
        var clock = SettingsIdleClock(startedAt: start)
        clock.recordActivity(at: start + .seconds(60))
        clock.recordActivity(at: start + .seconds(10))

        #expect(clock.deadline == start + .seconds(150))
    }

    @Test func aHoldStopsTheResetForAsLongAsItLasts() {
        var clock = SettingsIdleClock(startedAt: start)
        clock.setHold(.alarm, true, at: start + .seconds(5))

        #expect(clock.deadline == nil)
        #expect(!clock.isDue(at: start + .seconds(600)))
    }

    /// When a task ends, the family gets the whole wait again rather than a
    /// reset the instant the web page or the alarm closes.
    @Test func endingTheLastHoldRestartsTheFullWait() {
        var clock = SettingsIdleClock(startedAt: start)
        clock.setHold(.webPage, true, at: start)
        clock.setHold(.alarm, true, at: start + .seconds(10))
        clock.setHold(.webPage, false, at: start + .seconds(200))

        #expect(clock.isHeld, "the alarm still holds it")
        clock.setHold(.alarm, false, at: start + .seconds(300))

        #expect(!clock.isDue(at: start + .seconds(389)))
        #expect(clock.isDue(at: start + .seconds(390)))
    }

    /// Releasing a hold that was never taken is not activity: a screen that
    /// reports "not busy" as it appears must not keep Settings from resetting.
    @Test func releasingAHoldThatWasNotHeldChangesNothing() {
        var clock = SettingsIdleClock(startedAt: start)
        clock.setHold(.screen(UUID()), false, at: start + .seconds(85))

        #expect(clock.isDue(at: start + .seconds(90)))
    }

    @Test func eachScreenHoldIsSeparate() {
        let editor = UUID()
        let backup = UUID()
        var clock = SettingsIdleClock(startedAt: start)
        clock.setHold(.screen(editor), true, at: start)
        clock.setHold(.screen(backup), true, at: start)
        clock.setHold(.screen(editor), false, at: start + .seconds(1))

        #expect(clock.isHeld)
    }

    @Test func aResetStartsTheNextWait() {
        var clock = SettingsIdleClock(startedAt: start)
        clock.didReset(at: start + .seconds(90))

        #expect(clock.deadline == start + .seconds(180))
    }

    @Test func aShortLimitIsHonoured() {
        let clock = SettingsIdleClock(limit: .seconds(3), startedAt: start)

        #expect(clock.isDue(at: start + .seconds(3)))
    }
}
