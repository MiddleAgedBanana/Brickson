# UI tests turn UIKit's animations off, so the iPad job stops stalling

*2026-11-13. Pull request #<n> (`claude/project-thread-jb7g02`). A cloud
thread, asked by the project's coordinator to find why "UI tests on
iPad" kept running into its 90-minute limit and to fix it without
raising the limit or weakening a test.*

## What changed and why

Nothing changes for a person using Brickson. What changes is how the UI
tests launch the app.

**What was wrong.** After every tap or swipe, XCTest waits until the app
is idle before it does the next thing. Part of that wait is in the app
itself: XCTest counts each UIKit animation it sees start and waits until
it has seen each one finish. On GitHub's iPad simulators, that count
sometimes stopped being answered after typing ended on Home, as the
keyboard went away and the message field left the screen. From then on,
every wait in that launch of the app ran out after 60 seconds, logged as
"App animations complete notification not received, will attempt to
continue", and the test went on. The test still passed; it only took
minutes instead of seconds. The next test, a new launch, was normal
again.

The app's own log shows the app was not busy: XCTest's question about
the main run loop was answered at once, and its question about
animations was never answered. Brickson has no animations of its own
(no `withAnimation`, `.animation`, `.transition` or repeating animation
anywhere in `Brickson/`); the ones XCTest counted are UIKit's, the
keyboard's and presentations'.

**How often.** Every Tests run since 2026-11-05 whose results could
still be downloaded was read: 89 iPad and 92 iPhone UI result bundles.
For each, the XCTest session log's 60-second runs-out were counted, test
by test.

| | iPad | iPhone |
|---|---|---|
| Runs that reached the typing tests | 65 | 68 |
| Runs where the app's animation wait ran out | 10 | 0 |
| Of those, on 2026-11-06 and 11-07 | 2 (of 18) | 0 |
| Of those, on 2026-11-12 | 8 (of 23) | 0 |

Every one of those runs-out was in `TypingOnHomeTests`: Emergency or
Phrases tapped while typing, then everything after it in that launch
(`testEmergencyPhrasesAndSettingsLeaveTypingAndKeepTheMessage`,
`testSpeakAndReturnSayTheMessageAndKeepIt`,
`testTheMessageSurvivesARelaunch`,
`testTypeOpensTheKeyboardAndMovesNothing`). A stalled run lost 6 to 25
minutes. On 2026-11-12 runs without it took 54 to 81 minutes, and runs
with it took up to 88, or were stopped at 90: `main`'s own run at
`2bf98d6` and pull request #106's first run at `8ac952b`. The runner
image (`xcode-27-arm64` 20261104.0337.1) and the simulator's iOS (27.2)
were the same in clean and stalled runs. Why it happened more often on
2026-11-12 than before is not known.

**Others have met it.** Two public projects describe the same message on
iOS 27 and Xcode 27, explain it from XCTest's own code (a count raised
when a UIKit animation starts and lowered when it stops, which Core
Animation can report twice for one start, as when the keyboard rises or
goes away), and stopped it by turning UIKit's animations off in their
test launches:
[FRUS-Explorer pull request #1320](https://github.com/joshbotts/FRUS-Explorer/pull/1320)
(13 of 221 runs stalled before, 0 of 171 after) and
[plusplus pull request #84](https://github.com/plusplusinc/plusplus/pull/84).
A third ([xsky-ios pull request #41](https://github.com/dennisfriedrichsen/xsky-ios/pull/41))
blamed a text cursor's blink left running on a field that lost focus in
the same update that removed it, and moved the change to the next turn.

**The fix.** `launchedApp` now passes `--uikit-animations=off`. The app
reads it only in a debug build with test storage, like every test
option (`LaunchOptions.activeUIKitAnimations`), and then, first thing in
`BricksonApp.init`, before any view, calls
`UIView.setAnimationsEnabled(false)` (`LaunchOptions.applyUIKitAnimations()`,
in `Brickson/App/LaunchAnimations.swift`). Apple's documentation says it
"affects only those animations that are submitted after it is called",
hence first. With it, a change UIKit would animate happens at once, so
there is no animation for XCTest to count. A person's launch, and every
release build, animates exactly as before. A UI test that needs to see
an animation passes `keepsUIKitAnimations: true`; none does today.

No test, wait or assertion changed. XCTest already waited for every
animation to finish before checking anything, so nothing a test checks
was ever read mid-animation.

The app-side change xsky-ios made (leaving typing in two steps) was not
taken: it would change when Home's controls change after Emergency,
which invariants 2 and 10 hold to one activation, to fix something seen
only under XCTest. Nothing suggests real devices are affected: XCTest's
count lives in XCTest's own code, loaded only into an app under test.

The launch arguments `launchedApp` builds now come from one plain
function, `UITestLaunch.arguments`, in
`BricksonUITests/LaunchArguments.swift` with the text size, appearance,
sizes and storage choices that were in `LaunchHelpers.swift`. That file
is also compiled into the unit tests, where `LaunchArgumentsTests` reads
the arguments with the app's own parser, so a UI test can never ask for
an option the app does not understand (the app would log it and carry on
without it).

docs/DECISIONS.md, "Tests" (2026-11-13), records the decision, and
"Apple's current frameworks first" lists the UIKit call.

**A second, rarer stall, outside the app.** Pull request #103's first
attempt on its final head (`0c53792`) was stopped at 90 minutes for
another reason: from `HomeReachabilityTests.testEveryHomeStateAtDefaultTextInPortrait`
on, right after a turn from landscape back to portrait and a relaunch,
XCTest's wait for the simulator's home screen (SpringBoard, not
Brickson) to settle ran out at 60 seconds on every action, across every
later launch, until the job was stopped; each rest-board test took about
19 minutes. Its re-run passed in 71 minutes. That was one of 89 iPad
runs, never on the iPhone. Nothing in the app can make SpringBoard
settle, and the change here does not touch it. The owner's options are
under *Follow-ups*.

## Commits

<Filled in when pushed.>

## Verified

- In this cloud thread, with no Mac: `scripts/test-docs.py`,
  `scripts/test-hooks.py`, `scripts/test-privacy.py`, and
  `scripts/privacy-check.py --outgoing --no-list` (the private list was
  not checked).
- The evidence above, read from GitHub's result bundles on Linux
  (*Gotchas*, "CI results can be read without a Mac"): each bundle's
  XCTest session log (`Session-BricksonUITests-*.log`), the app's own
  output for a stalled test, and `simulator-load-ipad.txt`.
- New tests, and the change that makes each fail:
  - `LaunchOptionsTests.uikitAnimationsAreTurnedOffOnlyWithDebugAndTestStorage`:
    the option reaching a launch without test storage, a misspelt value
    being taken for it, or a typo not being reported.
  - `LaunchAnimationsTests`: reading the option without acting on it, or
    turning UIKit's animations off for a person's launch or a launch
    that did not ask.
  - `LaunchArgumentsTests`: `launchedApp` dropping or misspelling any
    option it passes, the animations one above all.
- The Swift has not been compiled here; GitHub CI is its first build.
  What the CI run of this pull request showed is added below once it
  has run.

## Not verified

- That the stall is gone. It came in about one iPad run in six, so one
  green run proves little. What will show it: in the iPad result bundle,
  no "App animations complete notification not received" line, and the
  app's waits for animations answered at once. On `main`'s run at
  `74b7f4f`, the app answered 1,131 such waits, 197 of them after more
  than a tenth of a second (88 seconds in all); with UIKit's animations
  off they should all be immediate.
- Whether turning animations off changes what any UI test sees beyond
  timing. Nothing in the tests reads a frame mid-animation, but only the
  full UI run on both families shows it.
- Whether the Mac's iPhone simulator's slow Save on New Category
  (docs/HANDOFF.md) is the same fault.
- Anything on a real device: nothing here runs on one.

## Follow-ups

- The SpringBoard stall (*A second, rarer stall*). The owner's options,
  with the recommendation first:
  1. Leave it and re-run the job when it happens: one run in 89 so far,
     and GitHub's "Re-run failed jobs" got past it. *(recommended; any
     thread whose CI shows it again records it in docs/HANDOFF.md)*
  2. If it comes back, raise the iPad job's `timeout-minutes` in
     `.github/workflows/tests.yml` from 90 to 120. It stops nothing
     stalling; it only lets a slow run finish. Cloud agents cannot push
     workflows, so the owner, or an agent on the Mac, commits it.
- AGENTS.md's *Gotchas* line on `launchedApp` could say it turns UIKit's
  animations off. Left out here because pull request #100 rewrites
  AGENTS.md to within a few hundred bytes of the 32 KiB Codex reads.
  *(the next documents pull request after #100 merges)*
- After each new Xcode, try the typing tests once with
  `keepsUIKitAnimations: true` on a CI iPad; if the wait never runs
  out, Apple has fixed XCTest's count and the option can go
  (docs/DECISIONS.md, "Tests"). *(the thread that moves to the new
  Xcode)*
- Telling Apple, through Feedback Assistant, with the session-log lines
  above, would help it get fixed; only the owner can file one. *(owner,
  optional)*
