# UI test waits that tell a slow machine from a broken app

*2026-11-17. Pull request #122 (`claude/project-thread-dz2uxv`). A
Claude cloud thread, with no Mac: no UI test was built or run before
CI.*

## What changed and why

UI tests kept failing on GitHub's Macs while the app worked, and each
failure read the same whether the app was stuck or the machine was
overloaded. Every wait was a bare number of seconds handed to XCTest
or a deadline of the test's own (211 of them, from 3 to 60 seconds), so
a wait that ran out said only that it ran out.

**What the failing runs showed.** Pull request #120's run 44015749320
on 2026-11-17, two of its six UI jobs:

- iPad part 1 (job 133813148843):
  `HomeAccessibilityOrderTests.testQuickControlsComeFirstInEveryStateAtTheLargestText`
  launched the app in 26 seconds, then XCTest's first query for Home's
  Yes button took 77 seconds and failed inside XCTest itself ("Failed to
  get matching snapshots: Timed out while evaluating UI query"). The
  test's own 60-second wait never got an answer to judge.
- iPhone part 3 (job 133813148980):
  `LaunchTests.testLargestTextKeepsQuickControlWordsVisible` failed three
  times with `"Speaking" still showed 30 s later`: after one tap on
  Yes at AX5, "Speaking" still showed 64 seconds later, when the test
  moved on, and after the next it ended between 32 and 54 seconds after
  the tap. The app's speech watchdog ends a phrase only when the
  synthesizer goes quiet without saying so, so the simulator's
  synthesizer still reported that it was speaking. `HomeLayoutTests.testTheStarterLibraryFitsWithoutScrolling`
  failed with "Home did not finish laying out", a 10-second wait that
  ran out. In the same job single queries of the app took up to 11.9
  seconds, and one 5-second wait took 11.8.
- Its simulator-load record: the Mac at 300% of its three processors
  from 06:01 on, with a load average of 371 to 649. Part 1 on the
  iPhone, which passed, also spent most of its time with a load average
  between 50 and 650, so load average alone does not tell a failing
  run from a passing one.

The day before, run 43838572035 failed
`FoldOffsetUITests.testTheFirstRowClearsATopDivisionInDarkMode` ("Timed
out while evaluating UI query") and the same layout test, both within
the first 35 minutes of a saturated job
([`2026-11-16-ui-test-parts.md`](2026-11-16-ui-test-parts.md)).

**What changed** (docs/DECISIONS.md, "Tests", 2026-11-17):

1. **One wait helper.** `BricksonUITests/Waiting.swift` adds `look`,
   `waitUntil`, `waitToAppear`, `waitToDisappear` and `appears` to every
   UI test. Each looks at a real condition about twice a second on the
   main actor and ends as soon as it holds. A look that starts before
   the limit counts even if it ends after it, since a slow answer is
   still the app's answer, and no look starts after it: a pause that
   ends late ends the wait, so it cannot pass a strict limit. The loop
   itself is `UIWait.watch`, a plain function the unit tests drive with
   a clock of their own.
2. **Named limits that stretch on CI.** `BricksonUITests/UIWait.swift`
   names each limit: `launch` 30 seconds, `response` 10,
   `quickResponse` 5, `speechEnd` 30, `idleReset` 30, `observation` 3.
   Each wait takes the limit equal to the seconds it had, so on a Mac
   it is as long as before, with the exceptions below.
   `scripts/test.sh` passes a scale to
   the test runner (`TEST_RUNNER_BRICKSON_UI_WAIT_SCALE`, which reaches
   the tests as `BRICKSON_UI_WAIT_SCALE`): 3 when `CI` is `true`, 1
   otherwise, or the value of `BRICKSON_UI_WAIT_SCALE` if set. The tests
   read it as at least 1 and at most 5. Two kinds of wait are shorter
   on a Mac than before. The three that allowed 60 seconds for the
   first screen after a launch allow 30 (90 on CI): `scripts/test.sh`
   launches the app once before the UI tests, so the first test does
   not meet a cold simulator, and a launch that never shows Home fails
   in half the time. Two waits for Again after a phrase, in
   `HomeReachabilityTests` and the AX5 test of `LaunchTests`, allowed
   15 seconds and allow 10 (30 on CI), the limit the first-tap test has
   always held on every machine.
3. **Failures that say what happened.** A wait that runs out fails with
   the test's own words followed by, for example: "waited 30.1 s (limit
   30 s: 10 s times a scale of 3); looked 21 times, the slowest look
   12 s; ended at 2026-11-17T06:10:20Z. One look at the app took 12 s:
   XCTest's query of the app was itself slow, a sign of an overloaded
   machine." The end time is there to find in the job's simulator-load
   record. A wait with a look over 5 seconds prints a `UI-WAIT` line to
   the log even when it ends well, since XCTest may already have failed
   that look on its own, as on iPad part 1 above. `launchedApp` also
   says how long the launch itself took when Home does not appear.
4. **Safety bounds stay strict.** Three tests prove a safety control's
   first response, and each keeps the limit it had, on every machine:
   a phrase speaking on the first tap (Again turning on within 10
   seconds), Emergency showing its phrases (5 seconds) and Get Attention
   sounding (Stop and "Sounding" within 10 seconds). Each says so in the
   test. No UI test wait is the person's own bound: that bound, a
   response within half a second, is a device measurement before
   release (docs/DECISIONS.md, "Every release passes the quality bar"),
   and the app's own time limits are unit-tested with injected time.
5. **Watches for what must not happen stretch too.** A test that
   watches for 3 seconds that a slide does not speak watches for 9 on
   CI, because an overloaded Mac gives the app less of each second.
6. **A check that refuses bare waits.** `scripts/ui-test-waits.py`
   reads every Swift file in `BricksonUITests` except the two helper
   files, ignoring comments and the words inside strings (raw strings
   too), reading each wait across line breaks, and reports a
   number of seconds handed to XCTest, an XCTest waiter or predicate
   expectation, a sleep, a run loop held for a time, or a deadline of
   the test's own. `scripts/test-runner.py` runs it
   (`UITestWaitTests`), so the "Unit tests" check fails on a new bare
   wait. A gesture's own length (`press(forDuration:)`) is not a wait.
   `HomeAccessibilityOrderTests.swift` was left as it is because pull
   request #119 is changing it; the check allows its 7 bare waits and
   no more.

Nothing is retried, skipped or loosened: every assertion is the one it
was, and only the time a stuck app is given changed: longer on CI, the
same on a Mac but for the two shorter kinds above. Where a test's private helper used XCTest's predicate expectation, it
now evaluates the same predicate itself through the helper.

## Commits

The commits on `claude/project-thread-dz2uxv`; the pull request lists
them. After the first, they answer the review: 5-second waits kept at 5
on a Mac, no look after the limit, the check reading across lines, and
the probes' first reads inside their waits.

## Verified

- On this cloud machine (Linux, no Xcode): `scripts/ui-test-waits.py`
  finds no bare wait outside the helpers and exactly 7 in
  `HomeAccessibilityOrderTests.swift`; `scripts/test-runner.py` passes,
  with the new `UITestWaitTests`. Each new Python test was seen to fail
  with a pattern removed from the check, with `scripts/test.sh` giving
  CI a scale of 1, or with the check reading one line at a time,
  counting one wait per line, not reading raw strings or exempting a
  `Waiting.swift` in a subfolder.
- The other Python checks in AGENTS.md, *Build and test*, pass.
- New unit tests (`BricksonTests/UIWaitTests.swift`, Swift Testing),
  each naming the change that fails it: the normal limits; every limit
  but a strict one stretching with the scale; reading the scale (missing,
  below 1, above 5, not a number, infinite); the exact words of a wait
  that ran out on a slow machine and of a quick one; the 5-second line
  for a slow look; how seconds are written; and how a wait looks (it
  ends at the first look that holds, lasts its whole limit when nothing
  holds, counts a slow look that started in time, and starts no look
  after the limit). `UIWait.swift` and these
  tests were compiled and run here with Swift 6.4.2 for Linux, in a
  scratch package with main-actor default isolation and warnings as
  errors: all 12 pass, and comparing with `>` instead of `>=` for a slow
  look, letting a strict limit stretch, looking again after a pause that
  ended past the limit, or pausing past the limit, fails them. That is
  not the app's toolchain: Xcode and iOS Foundation can still differ.

## Not verified

- **The UI tests were not compiled or run.** `Waiting.swift`, the
  converted tests and the changes to `LaunchHelpers.swift` need XCTest's
  UI automation, which only a Mac has: they are untested until CI's UI
  jobs pass, and `UIWaitTests` until the unit job does.
- That xcodebuild hands `TEST_RUNNER_BRICKSON_UI_WAIT_SCALE` to the UI
  test runner on a simulator is Apple's documented behaviour, not seen
  here: a CI failure message reading "times a scale of 3" shows it.
- Whether 90 seconds covers the simulator's slowest speech on CI: one
  phrase above still showed "Speaking" after 64 seconds, and its end was
  not seen.
- XCTest's own query timeout ("Timed out while evaluating UI query")
  is not ours to lengthen; a wait now only reports the slow look around
  it.

## Follow-ups

- After #119 merges, the next pull request to touch the UI tests moves
  `HomeAccessibilityOrderTests.swift`'s 7 waits onto the helpers and
  removes it from `NOT_YET_CONVERTED` in `scripts/ui-test-waits.py`
  (docs/HANDOFF.md, *Repository, CI and website*). Owner: whichever
  thread takes it.
- If a stretched limit runs out on CI with only quick looks, that is a
  stuck app or a step whose limit is too short; read the step before
  changing the limit.
