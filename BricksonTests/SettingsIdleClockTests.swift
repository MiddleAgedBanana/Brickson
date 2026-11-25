import Foundation
import SwiftUI
import Testing
@testable import Brickson

/// A family member can walk away from Settings mid-task. The person using
/// Brickson must not be stranded there, and Settings must never close by
/// itself (that would put Home's controls under a spot nobody chose).
struct SettingsIdleClockTests {
    private let start = ContinuousClock.now

    /// A Settings nobody has used since it opened is already what a reset
    /// would leave, so it never resets: each reset rebuilds every screen,
    /// and an activation that lands while they are replaced does nothing
    /// (docs/log/2026-11-22-settings-reset-only-after-use.md). Fails if an
    /// untouched clock has a deadline again.
    @Test func anUntouchedSettingsNeverResets() {
        let clock = SettingsIdleClock(startedAt: start)

        #expect(clock.deadline == nil)
        #expect(!clock.isDue(at: start + .seconds(90)))
        #expect(!clock.isDue(at: start + .seconds(3600)))
    }

    /// Settings opened, a screen was opened, then nothing for 90 seconds.
    private func usedAtStart(limit: Duration = SettingsIdleClock.standardLimit) -> SettingsIdleClock {
        var clock = SettingsIdleClock(limit: limit, startedAt: start)
        clock.recordActivity(at: start)
        return clock
    }

    @Test func settingsResetsNinetySecondsAfterItWasLastUsed() {
        let clock = usedAtStart()

        #expect(SettingsIdleClock.standardLimit == .seconds(90))
        #expect(!clock.isDue(at: start + .seconds(89.9)))
        #expect(clock.isDue(at: start + .seconds(90)))
    }

    /// After a reset Settings is as it opened, so it waits for use before
    /// the next one. Fails if a reset leaves the clock counting down again:
    /// the first screen would then rebuild itself at every limit.
    @Test func aResetWaitsForUseBeforeTheNextOne() {
        var clock = usedAtStart()
        clock.didReset(at: start + .seconds(90))

        #expect(clock.deadline == nil)
        #expect(!clock.isDue(at: start + .seconds(3600)))

        clock.recordActivity(at: start + .seconds(4000))
        #expect(!clock.isDue(at: start + .seconds(4089)))
        #expect(clock.isDue(at: start + .seconds(4090)))
    }

    /// Coming back to Brickson starts the full wait again, as before, but
    /// is not use: an untouched Settings stays untouched. Fails if
    /// `restartWait` counts as use, or stops moving the deadline.
    @Test func comingBackToBricksonRestartsTheWaitWithoutBeingUse() {
        var untouched = SettingsIdleClock(startedAt: start)
        untouched.restartWait(at: start + .seconds(50))
        #expect(untouched.deadline == nil)

        var used = usedAtStart()
        used.restartWait(at: start + .seconds(80))
        #expect(!used.isDue(at: start + .seconds(169)))
        #expect(used.isDue(at: start + .seconds(170)))
    }

    /// A hold that ends on an untouched Settings (the alarm, sounding from
    /// Home as it opened, say) changes nothing on its screens, so it is not
    /// use either.
    @Test func aHoldEndingOnAnUntouchedSettingsIsNotUse() {
        var clock = SettingsIdleClock(startedAt: start)
        clock.setHold(.alarm, true, at: start)
        clock.setHold(.alarm, false, at: start + .seconds(10))

        #expect(clock.deadline == nil)
    }

    @Test func anyActivityStartsTheWaitAgain() {
        var clock = usedAtStart()
        clock.recordActivity(at: start + .seconds(80))

        #expect(!clock.isDue(at: start + .seconds(169)))
        #expect(clock.isDue(at: start + .seconds(170)))
    }

    /// Activity reported out of order (a late scroll callback) must not pull
    /// the deadline earlier.
    @Test func olderActivityNeverBringsTheResetForward() {
        var clock = usedAtStart()
        clock.recordActivity(at: start + .seconds(60))
        clock.recordActivity(at: start + .seconds(10))

        #expect(clock.deadline == start + .seconds(150))
    }

    @Test func aHoldStopsTheResetForAsLongAsItLasts() {
        var clock = usedAtStart()
        clock.setHold(.alarm, true, at: start + .seconds(5))

        #expect(clock.deadline == nil)
        #expect(!clock.isDue(at: start + .seconds(600)))
    }

    /// One long drag holds the reset for as long as it lasts, and the full
    /// wait starts again when the scroll comes to rest.
    @Test func aScrollHoldsTheResetHoweverLongItLasts() {
        var clock = usedAtStart(limit: .seconds(90))
        let scroll = UUID()
        clock.setHold(.scrolling(scroll), true, at: start + .seconds(5))

        #expect(!clock.isDue(at: start + .seconds(500)))
        clock.setHold(.scrolling(scroll), false, at: start + .seconds(600))
        #expect(!clock.isDue(at: start + .seconds(689)))
        #expect(clock.isDue(at: start + .seconds(690)))
    }

    /// When a task ends, the family gets the whole wait again rather than a
    /// reset the instant the web page or the alarm closes.
    @Test func endingTheLastHoldRestartsTheFullWait() {
        var clock = usedAtStart()
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
        var clock = usedAtStart()
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

    @Test func aResetStartsTheNextWaitFromUseAfterIt() {
        var clock = usedAtStart()
        clock.didReset(at: start + .seconds(90))
        clock.recordActivity(at: start + .seconds(91))

        #expect(clock.deadline == start + .seconds(181))
    }

    @Test func aShortLimitIsHonoured() {
        let clock = usedAtStart(limit: .seconds(3))

        #expect(clock.isDue(at: start + .seconds(3)))
    }

    /// The live side: an untouched Settings never resets, a used one does,
    /// and is untouched again after. Fails if `SettingsActivity` resets
    /// without use, or if `restartWait` counts as use.
    @Test func settingsActivityTracksResetCountAndHolds() {
        let activity = SettingsActivity(limit: .zero)
        #expect(activity.resetCount == 0)
        #expect(!activity.resetIfDue(), "nothing was used")
        activity.restartWait()
        #expect(!activity.resetIfDue(), "coming back to Brickson is not use")
        #expect(activity.resetCount == 0)

        activity.recordActivity()
        #expect(activity.resetIfDue())
        #expect(activity.resetCount == 1)
        #expect(!activity.resetIfDue(), "a reset leaves Settings untouched")
        #expect(activity.resetCount == 1)

        activity.recordActivity()
        activity.setHold(.alarm, true)
        #expect(activity.clock.isHeld)
        #expect(!activity.resetIfDue())
        #expect(activity.resetCount == 1)

        activity.setHold(.alarm, false)
        #expect(!activity.clock.isHeld)
        activity.recordActivity()
        #expect(activity.resetIfDue())
        #expect(activity.resetCount == 2)
    }

    /// A scroll view reports a change from idle to idle as it appears;
    /// that is not a scroll. Fails if it counts: every screen that appears,
    /// the first screen rebuilt by a reset among them, would look used, and
    /// an untouched Settings would reset at every limit again. A touch that
    /// rests without moving the list (tracking) is not use either; fails
    /// if it counts.
    @Test func aScrollViewAppearingIsNotAScroll() {
        #expect(!SettingsScrollUse.counts(from: .idle, to: .idle))
        #expect(!SettingsScrollUse.counts(from: .idle, to: .tracking))
        #expect(!SettingsScrollUse.counts(from: .tracking, to: .idle))
        #expect(SettingsScrollUse.counts(from: .tracking, to: .interacting))
        #expect(SettingsScrollUse.counts(from: .idle, to: .interacting))
        #expect(SettingsScrollUse.counts(from: .interacting, to: .decelerating))
        #expect(SettingsScrollUse.counts(from: .decelerating, to: .idle))
        #expect(SettingsScrollUse.counts(from: .animating, to: .idle))
    }

    /// Fails if a step is lost, moved or numbered wrongly: the rest
    /// board's question comes straight after the first step's answer, which
    /// it builds on (docs/DECISIONS.md, "The late-stage profile").
    @Test func guidedSetupStepOrdersSixStepsAndStopsAtReady() {
        #expect(GuidedSetupStep.count == 6)
        let expected: [(GuidedSetupStep, Int, GuidedSetupStep?)] = [
            (.access, 1, .restBoard),
            (.restBoard, 2, .voice),
            (.voice, 3, .turnOn),
            (.turnOn, 4, .keepOpen),
            (.keepOpen, 5, .ready),
            (.ready, 6, nil),
        ]
        for (step, number, next) in expected {
            #expect(step.number == number)
            #expect(step.next == next)
        }
    }
}
