# UI tests turn UIKit's animations off, so the iPad job stops stalling

*2026-11-13. Pull request #107 (`claude/project-thread-jb7g02`). A cloud
thread, asked by the project's coordinator to find why "UI tests on
iPad" kept running into its 90-minute limit and to fix it without
raising the limit or weakening a test.*

## What changed and why

Nothing changes for a person using Brickson. What changes is how the UI
tests launch the app.

**What was wrong.** After every tap, swipe or typed text, XCTest waits
until the app is idle before it does the next thing. Part of that wait
runs inside the app: XCTest waits until each UIKit animation it saw
start has finished. On GitHub's iPad simulators, that wait sometimes
stopped being answered after typing ended on Home, as the keyboard went
away and the message field left the screen. From then on, every wait in
that launch of the app ran out after 60 seconds, logged as "App
animations complete notification not received, will attempt to
continue", and the test went on. The test still passed; it only took
minutes instead of seconds. The next test paid one more 60-second wait
while it set up, before it relaunched the app, and then ran normally.

What the logs show, from pull request #106's stalled run (`8ac952b`):

- The app answered XCTest's question about its main run loop at once,
  every time. It logged "Received request to notify when animations are
  idle" and, from the stall on, never its "Sending animations idle
  reply". So the wait sat inside the code XCTest loads into the app, not
  in the messages between them. SpringBoard's own waits finished in
  about 0.05 seconds.
- The machine was not starved: during the 11 stalled minutes the Mac's
  load fell from about 34 to about 5, Brickson used 0 to 5% of a
  processor, and backboardd, which draws what is on screen, used under
  1% while Home showed no keyboard. An animation left running for ever
  (a text cursor still blinking, say) would show there; nothing did.
- The app kept working: the keyboard opened again, Settings opened and
  closed, and the test passed.
- In 3 of the 10 stalled runs, the wait after leaving typing finished,
  and the next one, a second or two later with no action between, never
  did. Something UIKit started after the app had reported idle was never
  reported finished.

Brickson has no animations of its own (no `withAnimation`, `.animation`,
`.transition` or repeating animation anywhere in `Brickson/`); the
animations XCTest waits for are UIKit's: the keyboard's and the
presentations'.

**How often.** Every Tests run since 2026-11-05 whose results could
still be downloaded was read: 89 iPad and 92 iPhone UI result bundles,
on Xcode 27.2's simulators (iPad Pro 13-inch (M5) and iPhone 17, iOS
27.2). For each, the XCTest session log's 60-second waits were counted,
test by test. That log prints each test's activity a second time after
the next test starts, so each line was counted once. Runs are dated by
when their results were saved (UTC).

| | iPad | iPhone |
|---|---|---|
| Runs that reached the typing tests | 65 | 68 |
| Runs where the app's animation wait ran out | 10 | 0 |
| 2026-11-05 | 0 of 3 | 0 |
| 2026-11-06 and 11-07 | 2 of 17 | 0 |
| 2026-11-08 | 0 of 22 | 0 |
| 2026-11-12 | 8 of 23 | 0 |

The stall began in
`TypingOnHomeTests.testEmergencyPhrasesAndSettingsLeaveTypingAndKeepTheMessage`
(Emergency tapped while typing) in 5 runs, and in
`testSpeakAndReturnSayTheMessageAndKeepIt` (Phrases tapped after
speaking a typed message) in the other 5. A stalled run had 3 to 13
waits of 60 seconds, about 3 to 13 minutes lost. On 2026-11-12, iPad
runs without it took 54 to 81 minutes, and runs with it took up to 88,
or were stopped at 90: `main`'s own run at `2bf98d6` and pull request
#106's first run at `8ac952b`. Home's typing code and the typing tests
did not change after 2026-11-05. In the four job logs read (two clean
and two stalled, on 2026-11-08 and 11-12), GitHub's machine image
(`xcode-27-arm64` 20261104.0337.1) and the simulator's iOS were the
same; the images of the 2026-11-06 and 11-07 stalls were not checked.
Why it came so much more often on 2026-11-12 is not known.

**Others have met it.** Public projects on GitHub describe the same
message:

- FRUS-Explorer (pull request #1320), on iOS 27: XCTest counts a UIKit
  animation's start and its stop, and around the keyboard and sheets one
  start was reported twice, leaving the count one too high for the rest
  of the launch. With UIKit's animations turned off at launch, 0 of 171
  test cases of one suite stalled, against 13 of 221 with them on (2 of
  the 13 on an iPad). It turned them off for that one suite, because its
  keyboard and rotation suites test animated behaviour.
- plusplus (pull request #84, on Xcode Cloud, no iOS version given)
  counted 579 starts against 577 stops, traced the extra starts to
  UIKit's scroll edge effect, and fixed it the same way (1 and 1 after).
  One of its tests had relied on a sheet's slide for time and failed
  2 of 6 runs until the test was fixed.
- xsky-ios (pull request #41), on iOS 18.5, traced it to a text cursor's
  blink left running on a field that lost focus in the same update that
  changed its text, and moved that change to the next turn.

Brickson's logs cannot tell these explanations apart: they show the wait
never answered, not why.

**The change.** `launchedApp` now passes `--uikit-animations=off`. The
app reads it only in a debug build with test storage, like every test
option (`LaunchOptions.activeUIKitAnimations`), and then, first thing in
`BricksonApp.init`, before any view, calls
`UIView.setAnimationsEnabled(false)` (`LaunchOptions.applyUIKitAnimations()`,
in `Brickson/App/LaunchAnimations.swift`). Apple's documentation says it
"affects only those animations that are submitted after it is called",
hence first. With it, a change UIKit would animate happens at once, so
UIKit starts no animation for XCTest to wait for. A person's launch
animates exactly as before: release builds read no launch arguments at
all (`LaunchOptions.readsLaunchArguments`), and in a debug build the
option needs test storage, which `LaunchOptionsTests` and
`LaunchAnimationsTests` check.

The two opt-in probes that record what a person's touch meets
(`HeldSlideProbeTests`, `PhraseDragProbeTests`) keep UIKit's animations
(`keepsUIKitAnimations: true`), so their results stay comparable with
their earlier records. CI skips both.

No test's steps, waits or assertions changed. XCTest waits for UIKit's
animations only after its own actions; elsewhere the tests wait for a
screen to come to rest themselves (Settings' screens sliding in, the
keyboard probe's settled reads), and those waits stay. Every frame the
tests compare is read at rest, so with animations off rest only comes
sooner. One check can become stricter, not weaker:
`TypingOnHomeTests` reads the keyboard's frame as soon as it exists,
which could be mid-rise before; now it is where the keyboard rests. A
new failure there would be a real one: compare it with that run's
`KEYBOARD-PROBE` and `KEYBOARD-BAND` lines first.

The cost: UI tests no longer see UIKit's own animations. A UIKit
animation that never ends, which a person's device would run, could
no longer show up as these 60-second waits. Nothing showed one here,
and a test that needs to see an animation passes
`keepsUIKitAnimations: true`.

**Why not change the app instead.** xsky-ios's kind of change would
leave typing in two steps: focus first, the field a moment later. It
keeps Emergency one activation away, but leaves a frame in which the
emergency phrases show while typing still does, changes code a person
uses to suit XCTest, and nothing shows it addresses Brickson's cause.
Nothing suggests real devices are affected: the wait lives in XCTest's
own code, and the app's processor use shows nothing left running.

The launch arguments `launchedApp` builds now come from one plain
function, `UITestLaunch.arguments`, in
`BricksonUITests/LaunchArguments.swift`, with the text size, appearance,
sizes and storage choices that were in `LaunchHelpers.swift`. That file
is also compiled into the unit tests, where `LaunchArgumentsTests` reads
the arguments with the app's own parser, so every option `launchedApp`
itself passes is one the app understands (one it did not would only be
logged and ignored).

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
settle, and this change does not touch it. The owner's options are
under *Follow-ups*.

## Commits

- `10c80b1` Turn UIKit's animations off in UI-test launches
- `fa3716a` Record why UI tests launch with UIKit's animations off
- `35b6dbf` Apply the independent reviews of the animations change
  (below)
- `3fa40fb` Merge main into the UIKit animations pull request (#105)
- `9aeed72` Merge main into the UIKit animations pull request (#100
  and #106; docs/HANDOFF.md's CI paragraph keeps #106's account and
  gives the cause in place of "not known")
- `a3b9115` AGENTS.md's `launchedApp` gotcha says it turns UIKit's
  animations off, and this record gains the first CI run.
- `7378f5b` An independent check of `a3b9115` and the merge corrected
  these records. docs/HANDOFF.md names all three runs stopped
  at the limit on 2026-11-12 (the merge had kept #106's two, dropping
  `main`'s at `2bf98d6`), and the first CI run's figures above were
  re-derived and set right (3,675 and 3,467 seconds; 1,116 of 1,159
  answers within a millisecond; the overlap with `main`'s run, and the
  waiting the change removed).
- The commit after it: docs/DECISIONS.md records the owner's decision
  to keep animations off in UI tests, cost included, which Codex's
  review of `a3b9115` asked for.

Before pushing, four independent reviews in this thread read the code,
tried to refute the diagnosis, went through every UI test for what
animations off could change, and checked these records against the
evidence. Their corrections are in: the argument list built in plain
steps, a sizes test that catches two names swapped, the probes keeping
animations, the lost minutes counted once (3 to 13, not 6 to 25), the
outside projects described as they are, and the re-check below asking
for enough runs.

## Verified

- In this cloud thread, with no Mac: `scripts/test-docs.py`,
  `scripts/test-hooks.py`, `scripts/test-privacy.py`, and
  `scripts/privacy-check.py --outgoing --no-list` (the private list was
  not checked).
- The evidence above, read from GitHub's result bundles on Linux (the
  AGENTS.md gotcha on reading CI results without a Mac): each bundle's
  XCTest session log (`Session-BricksonUITests-*.log`), the app's own
  output for a stalled test, and `simulator-load-ipad.txt`. Apple's
  pages for `setAnimationsEnabled(_:)` and `areAnimationsEnabled`, read
  2026-11-13: neither is deprecated.
- New tests, and the change that makes each fail:
  - `LaunchOptionsTests.uikitAnimationsAreTurnedOffOnlyWithDebugAndTestStorage`:
    the option reaching a launch without test storage, a misspelt value
    being taken for it, or a typo not being reported.
  - `LaunchAnimationsTests`: reading the option without acting on it, or
    turning UIKit's animations off for a person's launch or a launch
    that did not ask.
  - `LaunchArgumentsTests`: `launchedApp` dropping or misspelling an
    option it passes (the animations one above all), ignoring
    `keepsUIKitAnimations`, or two size names swapped.
- The Swift was not compiled in this thread; GitHub CI was its first
  build (next).
- The pull request's first CI run, at `3fa40fb` (Tests run
  43341979721), passed every job: unit tests, and 81 UI tests on each
  family with none failed (3 skipped on the iPad, 7 on the iPhone, as
  on `main`). The iPad job took 76 minutes. Its result bundle has no
  "App animations complete notification not received" line. The app's
  output holds 1,173 "Received request to notify when animations are
  idle" lines and 1,175 replies; of the 1,159 pairs whose lines were
  not interleaved with another thread's output, 1,116 were answered
  within a millisecond, three took over a tenth of a second and the
  longest 1.1 seconds.
  `TypingOnHomeTests.testEmergencyPhrasesAndSettingsLeaveTypingAndKeepTheMessage`
  took 37 seconds.
- Compared with `main`'s run at `3bb2850` (Tests run 43339016171),
  which partly overlapped it on other machines and had no stall either:
  - The change removed the app's slow answers to XCTest's animation
    question. On `main`, 211 of 1,153 such answers on the iPad and 220
    of 1,216 on the iPhone took over a tenth of a second, about 90 and
    88 seconds of waiting; here, 3 and 2, about 2 seconds and 1.
  - The iPad's tests took 3,675 seconds against 4,078 and the iPhone's
    3,945 against 3,467. Those swings are far larger than the waiting
    removed and run both ways across most tests (52 of 78 faster on
    the iPad, 55 of 74 slower on the iPhone, none slower on both by
    more than 5 seconds), so they come mostly from the machines, not
    the change. This pull request's iPad machine was the slower one
    before the tests (its build took 10 minutes 47 seconds against 7
    minutes 30), so a faster machine does not explain its faster tests
    either.

## Not verified

- That the stall is gone. It came in about one iPad run in six, so one
  green run (above) proves little. Two things will show it. In each iPad result
  bundle: no "App animations complete notification not received" line,
  and every "Received request to notify when animations are idle" in the
  app's output answered at once. (On `main`'s run at `74b7f4f`, the app
  answered 1,131 such requests, 197 of them after more than a tenth of a
  second, 88 seconds in all.) And over time: about 20 iPad runs with no
  such line, at which point a one-in-six fault would almost surely have
  shown.
- Whether turning animations off changes what a UI test sees beyond
  timing. Nothing in the tests reads a frame mid-animation, but only the
  full UI run on both families shows it. If a test turns flaky only
  here, look first at the presentations (Settings' cover, the privacy
  sheet) and at the keyboard appearing at once. Two reads in
  `SettingsTests` follow a dismissal or a push with no wait of their own
  (after Back to Talking, and Family Setup's rest-board choice), relying
  on UIKit finishing a transition with no animation before the tap
  returns.
- Whether the Mac's iPhone simulator's slow Save on New Category
  (docs/HANDOFF.md) is the same fault.
- Anything on a real device: nothing here runs on one.

## Follow-ups

- Watch the iPad result bundles of the next runs for the 60-second line
  in `TypingOnHomeTests`. If it comes back with animations off, the
  lead is UIKit's scroll edge effect, which plusplus traced its extra
  starts to: on the iPad, Home's phrase grid and message lie under the
  keyboard. Check on a Mac whether turning that effect off on Home's
  scroll views changes it. *(any thread whose iPad run shows it)*
- The SpringBoard stall (*A second, rarer stall*). The owner's options,
  with the recommendation first:
  1. Leave it and re-run the job when it happens: one run in 89 so far,
     and GitHub's "Re-run failed jobs" got past it. *(recommended; any
     thread whose CI shows it again records it in docs/HANDOFF.md)*
  2. If it comes back, raise the iPad job's `timeout-minutes` in
     `.github/workflows/tests.yml` from 90 to 120. It stops nothing
     stalling; it only lets a slow run finish. Cloud agents cannot push
     workflows, so the owner, or an agent on the Mac, commits it.
- With each new Xcode, check whether Apple has fixed the wait: run the
  typing tests on a CI iPad with `keepsUIKitAnimations: true` about 20
  times (`-test-iterations 20`, `-only-testing:BricksonUITests/TypingOnHomeTests`).
  If no 60-second line appears and every animations request is answered
  within a second, the option can go (docs/DECISIONS.md, "Tests").
  *(the thread that moves to the new Xcode)*
- Telling Apple, through Feedback Assistant, with the session-log lines
  above, would help it get fixed; only the owner can file one. *(owner,
  optional)*
