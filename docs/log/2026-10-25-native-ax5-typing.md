# Native AX5 typing and first-launch follow-up

*2026-10-25. Pull request #59 (`codex/ax5-typing-follow-up`). Codex.
Documentation and simulator evidence only.*

## What changed and why

Closed the native-input reproduction left by PR #55. The earlier
[Mac record](2026-10-25-mac-keyboard-checks.md) did not establish iPhone
Return, and asked for a native check of covered Put Back before a fix.
This follow-up records both on unchanged app code `6d040d5`, after PR #56.
Main `37c2e0b` supplies the merged PR #55 notes. No app or test changes.
The same Mac-check follow-up also investigates a new CI startup failure
with recovered visual evidence and three bounded local comparisons.

## Commits

- `7f7b9c5`: record native AX5 Return and covered Put Back.
- `7f9eb2c`: record startup comparisons and the recovered CI frame.
- `edbf6b8`: clarify native iPad observations and retain check provenance.
- Merge current main `a14c709` without rewriting history; documentation only.

## Verified

Mac, Xcode 27.1 (27A9275); iPhone 17 simulator, iOS 27.0,
402×874pt portrait, Full Screen, AX5, light, test-only storage. The
keyboard was the full US English software keyboard with predictions.
No physical iPhone was operated.

| Check | Result |
|---|---|
| Software Return | **Pass for visible app state.** Entered the neutral test message “Blue kites”; restored the full software keyboard after HID entry hid it; pressed its visible Return key in Device Hub. “Speaking” appeared. Phrases then displayed “Blue kites” as the last-spoken message; reopening Type retained the same draft. This is not evidence of sound. |
| Clear | **Pass for empty field.** With the full keyboard showing, activated Clear. The field emptied, Speak and Clear became disabled, and the full keyboard stayed visible. |
| Put Back while the full keyboard shows | **Fail for visual reachability.** Its y 547–624 frame is behind the keyboard, whose prediction region begins at y 546. It was absent from Device Hub's visible control list after Clear. No activation through a command that bypasses the keyboard was used to claim a pass. |

Evidence under `docs/evidence/2026-10-25-native-ax5-typing/`:

- [Full keyboard before entry](../evidence/2026-10-25-native-ax5-typing/full-keyboard.png).
- [Message after software Return and Phrases](../evidence/2026-10-25-native-ax5-typing/after-return.png).
- [Empty field and covered Put Back after Clear](../evidence/2026-10-25-native-ax5-typing/after-clear.png).
- [Observation record and snapshot frames](../evidence/2026-10-25-native-ax5-typing/observations.json).

RocketSim's compact keyboard summary said hidden even while full keys
were rendered. HID entry also hid the keyboard and briefly exposed
off-screen key coordinates. Those summaries are not the keyboard-fit
measurement. Device Hub's **Device → Keyboard → Toggle Software
Keyboard** restored the full keyboard; its rendered image and
prediction-row frame establish the y 546 top. The native Return action
was performed only after that restoration.

The complete native unit gate passed on identical app/test sources
before this documentation commit: 740 ran, 731 passed, 0 failed, one
existing issue #19 skip and eight strict expected failures; coverage
67.7%, String Catalog unchanged. Result:
`build/TestResults/duo-probe-restored-unit/unit-destination.xcresult`;
log: `/private/tmp/brickson-duo-probe-restored-unit.log`.

Hosted Unit and UI checks passed on `7f9eb2c`,
[Tests run 40206848388](https://github.com/MiddleAgedBanana/Brickson/actions/runs/40206848388).
The review corrections clarify the recorded iPad reachability and Return
observations and add this PR's identity and commit provenance. App,
tests, scripts and project are byte-identical to `6d040d5`, so the native
740-test receipt above applies without repeating a build. All five
Python suites and the diff check pass again. Hosted Unit/UI subsequently passed on review-correction head `edbf6b8`,
[Tests run 40214788443](https://github.com/MiddleAgedBanana/Brickson/actions/runs/40214788443).
That result predates the documentation-only main refresh below.

## First-launch follow-up

The [PR #57 UI job](https://github.com/MiddleAgedBanana/Brickson/actions/runs/40195916540/job/121176591223),
head `4231d21`, provides a new occurrence of the startup failure. On its
iPad, the first test was
`GetAttentionOnHomeTests/testTheAlarmStartsAndStopsAtDefaultText`.
The script had reported a successful app warm-up. XCTest then waited
60.034s for the foreground app's automation session, timed out, and
failed inside the first Yes accessibility lookup at
`LaunchHelpers.swift:93` with `kAXErrorServerNotFound`. No alarm
activation occurred in that failed case; the normal Home assertion on
the next line was not reached.

The completed iPad suite had 51 tests: 45 passed, 1 failed, 2 skipped
and 3 expected failures. The later iPhone first default Get Attention
case passed, but the overall job reached its configured 75-minute limit
and was cancelled. That is not a green UI run. Buffered console output
arrived at 13:55 UTC; native session timestamps place the failure around
13:12–13:13 UTC.

The failed test's screen recording had no standalone screenshot. An
[unaltered decoded frame](../evidence/2026-10-25-native-ax5-typing/ci-first-launch-white-frame.png)
shows white content with no Home controls. Its [provenance](../evidence/2026-10-25-native-ax5-typing/ci-frame-provenance.json)
records the last available frame at video PTS 71.078333s; this is not
claimed to be the exact failure instant. The original recording and
native session excerpts remain under `/private/tmp/brickson-pr57-*`.
The retained diagnostics have no stack sample of the failing app during
the stall. Root cause remains unresolved.

Bounded local checks used unchanged current app/test sources, a newly
created disposable iPad Pro 13-inch (M5) simulator, iOS 27.0, default
text, light, Full Screen, full software keyboard and test-only storage.
Each selected exactly the same test above:

| Sample | Preconditions | Result |
|---|---|---|
| First installation | New simulator, completed boot, Brickson absent from pre-run app inventory, no app warm-up | **Pass**, 1 ran, 0 failed, 0 skipped; case 20.834s. |
| Second installation | Shut down and erased only that task-owned simulator; completed fresh boot; no app warm-up | **Pass**, 1 ran, 0 failed, 0 skipped; case 21.736s. |
| CI-shaped warmed control | Independently erased the task-owned simulator; normal `scripts/test.sh ui` boot, keyboard preparation and 21s app warm-up | **Pass**, 1 ran, 0 failed, 0 skipped; case 22.861s. |

The first two used MobileBuildMCP's test command without a preceding
app launch; the control used the repository script with
`-only-testing:BricksonUITests/GetAttentionOnHomeTests/testTheAlarmStartsAndStopsAtDefaultText`.
No test ordering, assertion, wait duration or retry setting changed.
The two cold cases disabled parallel test execution. These are separate
from PR #55's older three cold-phone boots of the historical snapshot
test.

[Saved counts and preconditions](../evidence/2026-10-25-native-ax5-typing/startup-samples.json).
Local result bundles:

- `build/TestResults/fresh-install-first-test.xcresult`.
- `build/TestResults/fresh-install-second-test.xcresult`.
- `build/TestResults/fresh-install-warmed-control/ui-destination.xcresult`.

The framework emitted an audio-session runtime warning during these
passing alarm tests. It is retained in the receipts; this is separate
from compiler diagnostics and does not establish the startup cause.
No startup fix is made because the local runs did not reproduce the
failure and no app-owned blocking path has been established. A future
recurrence needs a sample of the stalled process before another test
terminates it.

## Main refresh, 2026-10-25

Incorporated owner-merged PR #57 through main `a14c709` with a merge
commit, as AGENTS requires when main moves. PR #56 was already an
ancestor of this branch; no app or test implementation was missing.
The merge adds main's fewer-tiles log/proposal and keeps both HANDOFF
updates. App, tests, scripts, workflow and project sources are unchanged
from this PR's previously green head. No paging or product change is
included.

Before the merge commit, a fresh complete native unit run passed on the
script-selected iPad Pro 13-inch (M5) simulator, iOS 27.0, with recorded
Xcode 27.1 (27A9275): **740 total, 731 passed, zero failed, one existing
issue #19 skip and eight strict expected failures**. The String Catalog
is current; coverage is 67.7% (5,950/8,795). The result bundle is
`build/TestResults/pr59-main-refresh/unit-ipad.xcresult`; the retained
private log is `/private/tmp/brickson-pr59-main-refresh-unit.log`.
The run finished normally after the CPU-active font checks; no run was
restarted. A later sampling attempt found the test host had already
exited, so no stack sample or new failure is claimed.

The documentation check and diff check passed after this record was
updated. Hosted checks on the new merge head are still required; the
older green run is not presented as a new-head result. No generated
project or temporary measurement source is committed.

## Not verified

- Put Back's functionality with a covering keyboard, a fix for its
  placement, or a complete AX5 UI-suite pass. The failed reachability
  result remains open.
- Sound, real tracking, Snap to Item, Switch Control, mounting/calibration
  or Phone handoff. The informal earlier handheld observation is not a
  controlled device pass; physical checks remain deferred.
- Hosted CI on the new main-merge head; the two earlier green runs
  above belong to their recorded commits.
- The startup failure's cause or a fix. Three selected-case local passes
  do not establish a full UI-suite pass or reproduce GitHub's machine.

## Follow-ups

Use this native failure to give Put Back a layout answer, with an
automated failing reproduction before a fix. Preserve its fixed frames
and score the resulting held activations. No claim that the current
typing layout is fully accessible follows from the two passing actions
above.
