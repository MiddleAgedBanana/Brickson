# Settings resets only after use

*2026-11-22. Pull request #133 (`claude/settings-reset-after-use`).
Claude, in a project thread, on the owner's Mac.*

## What changed and why

For a person using Brickson: Settings still goes back to its first
screen 90 seconds after someone last used it, and still never closes.
What changes is that a Settings nobody has touched since it opened, or
since that return, no longer rebuilds itself. Before, it rebuilt every
screen at each 90-second limit for as long as it stayed open, and an
activation (a touch, a dwell, a switch press, a spoken command) that
landed while the screens were being replaced did nothing. The window was
about a tenth of a second in every 90, so a person would rarely meet it,
but when they did, Family Setup simply did not respond
(docs/DECISIONS.md, "Settings resets when idle and never closes",
2026-11-22).

For the people working on it: this was the cause of
`SettingsTests.testAnIdleSettingsReturnsToItsFirstScreenAndStaysOpen`
failing now and then with "Family Setup did not open" (five times from
2026-10-22 to 2026-11-21, on commits that did not touch it). That test
runs with `--short-timeouts`, so the limit is 3 seconds and the
untouched first screen rebuilt every 3 seconds; the test's tap on Family
Setup sometimes landed on a rebuild. The test was right and is
unchanged.

### How it was found

1. **CI's newest failure** (run 44902798573, "UI tests on iPhone, part 1
   of 3", 2026-11-21, after the settle wait, at a load of about 125).
   In the test's own screen recording, Settings first drew 7.2 s in,
   and the screen then updated every 3.1 s (10.215, 13.34, 16.46 s and
   on) with no visible change: the rebuilds. XCTest began synthesizing
   the tap on Family Setup 10.03 s in (touch down, then up 0.05 s later,
   as the event's record says), so the tap began about 0.18 s before the
   first rebuild. No frame ever showed Family Setup. Every one of the
   test's 53 looks took 0.5 s or less, so the machine was not slow at
   that moment.
2. **Reproduced on the Mac, app unchanged**, with a throwaway UI test
   (*The reproduction*, below): launch Settings with `--short-timeouts`,
   wait a set delay after Back to Talking appears, tap Family Setup, one
   launch per tap. Delays from 0.30 to 3.25 s in steps of 0.05 s: 2 of
   60 taps did nothing (0.65 and 0.75 s). In both, the recording shows a
   rebuild 0.09 s after the tap's synthesis began and no push. Delays
   from 0.50 to 0.89 s in steps of 0.01 s, aimed at the first rebuild:
   10 of 40 did nothing. On CI it is rarer because the tap usually comes
   well before the first rebuild: it takes a slow moment of about 3 s
   between Settings opening and the tap.
3. **Which of two possible faults.** Temporary logging in the app
   (removed before the fix) recorded each reset, each change of the
   stack's path and each report of activity. In every lost tap the app
   logged a reset of the first screen with nothing on the path, and no
   attempt to change the path at all: the tap never reached the Family
   Setup row. It was not a push that the reset then undid.
4. The same logging showed two more things the fix needed. A scroll
   view that appears reports a phase change from idle to idle, which
   the scroll modifier counted as activity (the first screen at launch,
   the first screen rebuilt by each reset, every screen pushed). And
   becoming active at launch recorded activity too.

### The fix

- `SettingsIdleClock` has no deadline while it is untouched. Using a
  control, opening or closing a screen, or scrolling (`recordActivity`)
  makes it touched; a reset (`didReset`) makes it untouched again, so
  Settings returns to its root once, 90 seconds after it was last used.
  Coming back to Brickson and a hold ending restart the wait
  (`restartWait`) without being use.
- `SettingsScrollUse.counts(from:to:)`: a scroll phase change counts
  only when the screen's content moves (into or out of interacting,
  decelerating or animating), so a screen appearing (idle to idle) is
  not a scroll, and nor is a touch that rests without moving the list
  (tracking), which Codex's review before the pull request pointed out.
  A touch still holds the reset from the moment it lands
  (`ScrollPhase.isScrolling`).
- `SettingsView` changes screens through one binding, `screens`, given
  to the stack and to every screen, which records use as a change is
  made. The reset sets `path` itself, which is not use. It replaces
  `.onChange(of: path)`, which would have counted the reset's own return
  to the root as use, so that a reset from a pushed screen would rebuild
  the first screen once more, 90 seconds later.

### The other sighting: `HomeSizesTests` on #130's first push

Not the same cause. In run 44586553461 (2026-11-19, before the settle
wait), `testHomeIsLargestUntilAnsweredAndTouchsOnceTouchIsChosen` opened
Family Setup: its title was found 41 s in and the recording shows it.
Then each of XCTest's looks for Set Up Step by Step took about 31 s, and
at 136.8 s the recording shows Settings back on its first screen, before
the tap at 137.5 s. That test runs with the real 90-second limit, so
this is consistent with the reset doing its job after a push at about
40 s on a machine where the app itself was slow to run; the 7 s beyond
90 is not accounted for. The settle wait (#128) is the remedy for that
stall, and this change does not touch it.

### The reproduction

`SettingsIdleTapProbe`, not committed: it fails on purpose at its end so
that XCTest keeps the screen recording, and it takes 6 to 9 minutes.
Its body, in a file of `BricksonUITests`:

```swift
@MainActor
func testTapSweptAcrossTheFirstReset() {
    continueAfterFailure = true
    let environment = ProcessInfo.processInfo.environment
    let start = Double(environment["PROBE_START"] ?? "") ?? 0.5
    let step = Double(environment["PROBE_STEP"] ?? "") ?? 0.05
    let count = Int(environment["PROBE_COUNT"] ?? "") ?? 50
    var lost = 0
    for trial in 0..<count {
        let delay = start + Double(trial) * step
        let app = launchedApp(arguments: ["--screen=settings"], shortTimeouts: true, waitsForHome: false)
        XCTAssertTrue(app.buttons["backToTalking"].waitForExistence(timeout: 60))
        Thread.sleep(forTimeInterval: delay)
        app.buttons["familySetup"].firstMatch.tap()
        let opened = app.navigationBars["Family Setup"].waitForExistence(timeout: 5)
        if !opened { lost += 1 }
        XCTAssertTrue(opened, "trial \(trial): Family Setup did not open (delay \(delay))")
    }
    XCTFail("probe finished: lost \(lost) of \(count)")
}
```

Run it with the delays in the runner's environment, for example
`TEST_RUNNER_PROBE_START=0.5 TEST_RUNNER_PROBE_STEP=0.01
TEST_RUNNER_PROBE_COUNT=40 xcodebuild ... "-only-testing:BricksonUITests/SettingsIdleTapProbe" test-without-building`.
The delay that meets the first rebuild depends on the machine; on the
owner's Mac it was 0.65 to 0.81 s. To time a tap against the rebuilds,
compare the "Synthesize event" activity's start in the result bundle
with the recording's frame times (`ffprobe -show_entries frame=pts_time`):
the recording only adds a frame when the screen changes, so each
rebuild shows as a burst of two or three frames.

## Commits

- `606590c` Reset an idle Settings only after it has been used (the
  fix and its unit tests).
- `37b08a5` Record that Settings resets only after use, and close the
  idle test's gap (docs/DECISIONS.md, docs/HANDOFF.md).
- `d3007db` Merge `main` after #132.
- `106c646` Count a scroll as use only when the list moves.
- This record, and `docs/HANDOFF.md`'s state line brought up to date.

## Verified

On the owner's Mac with Xcode 27.2 (27B52), on simulators of iOS 27.2
made for this work, in portrait, light, at the default text size:

- **The new test failed first.** `anUntouchedSettingsNeverResets` ran
  alone on the unchanged clock and failed all three of its expectations.
  Each new or changed test names the change that would make it fail:
  an untouched clock with a deadline again
  (`anUntouchedSettingsNeverResets`), a reset that leaves the clock
  counting down (`aResetWaitsForUseBeforeTheNextOne`), `restartWait`
  counting as use or no longer moving the deadline
  (`comingBackToBricksonRestartsTheWaitWithoutBeingUse`), a hold's end
  counting as use (`aHoldEndingOnAnUntouchedSettingsIsNotUse`),
  `SettingsActivity` resetting without use
  (`settingsActivityTracksResetCountAndHolds`), and idle to idle or a
  resting touch counting as a scroll (`aScrollViewAppearingIsNotAScroll`).
- **Unit tests**, the whole suite, on an iPhone 17 simulator: 1,117 ran,
  1,104 passed, none failed, 1 skipped and 12 expected failures (known
  issues this change does not touch); no warnings.
- **The reproduction with the fix**, iPhone 17 simulator: 0 of 40 taps
  lost over the delays that lost 10 of 40 before (0.50 to 0.89 s), and
  3 taps after 7 untouched seconds each all opened Family Setup, with no
  screen update at all in those 7 seconds (before the fix, one every
  3.1 s).
- **UI tests**, every class that opens Settings (`SettingsTests`,
  `SettingsOnHomeTests`, `LibraryTests`, `HomeRestBoardTests`,
  `HomeSizesTests`, `TypingOnHomeTests`, `FoldOffsetUITests`) through
  `scripts/test.sh ui`: on an iPhone 17 simulator 46 ran, 45 passed and
  1 skipped (`testOpeningSettingsFromHomeInLandscape`, which skips
  itself on a phone); on an iPad Pro 13-inch (M5) simulator 46 ran and
  46 passed. The idle test passed on both. CI runs the whole UI suite.
- The repository's Python checks pass.

## Not verified

- A real device: touch, dwell, Switch Control and Voice Control on
  Settings' first screen. The lost activation was only ever seen in the
  simulator, with XCTest's taps.
- Whether a rebuild also moved VoiceOver's or Switch Control's focus on
  the first screen: never measured, so this record claims nothing
  about it.
- Under load: the reproduction ran on an otherwise idle Mac. CI runs
  the change under its own load.
- Why the reset in #130's run came 97 s after the push rather than 90.

## Follow-ups

None. If the idle test fails again at "Family Setup did not open", the
thread whose CI shows it reopens the gap in docs/HANDOFF.md and starts
from *The reproduction* above.
