# Bounded Home layout queries and enough time for both UI suites

*2026-10-22. Pull request #32 (`codex/ci-home-test`). Codex, from `main` at `2895825`.*

## What changed and why

The UI job now has 75 minutes instead of 50 to complete both simulator
families. Its required check name, permissions, triggers and test matrix
are unchanged. PR #27's first attempt of run
[39829191241](https://github.com/MiddleAgedBanana/Brickson/actions/runs/39829191241)
finished the iPad tests but was cancelled during the iPhone suite after
roughly 50 minutes. Its iPad Home layout test took 165.810 seconds.

`HomeLayoutTests` counts phrase tiles once per layout wait and polls only
the window and first/last tile frames. After selection settles, one
accessibility snapshot supplies every tile's frame for the existing
containment and slot-position assertions. A failed snapshot throws and
fails the test; a layout wait timeout now fails explicitly. No assertion,
category, text size or orientation was removed. The documented narrow
window at AX5 still follows the same scrolling rule.

Apple's Xcode documentation was read for `snapshot()`,
`XCUIElementSnapshot.children` and `element(boundBy:)`. The snapshot owns
the descendant hierarchy, so its traversal does not issue another live
query for each tile. The Swift testing skill guided keeping XCTest for
UI automation and avoiding arbitrary sleeps.

A later CI run reported an accessibility finding without identifying an
element. The audit helper now captures the screen and full accessibility
tree when an unexpected finding is reported, while keeping the contextual
failure and returning the finding to XCTest for its native issue record.
The existing button-frame JSON capture is retained too. This adds evidence;
it does not fix or suppress the unidentified finding. The only permitted
phrase-label exception and the exact audit-service `-56` retry remain
unchanged. Native and contextual records can describe the same finding.

## Commits

The initial change, `bd00e85`, contains the UI job allowance, bounded
layout queries and this record. The pre-push fetch found PR #27 newly
landed as `main` at `5abdd9f`; merge commit `9075a14` incorporated it,
and the complete unit and UI suites passed again on that combination.

Merge commit `431ee14` incorporated `main` at `d79d836`, which landed
PR #20's documentation reconciliation without changing the app or tests,
and added the audit diagnostics. It is committed and pushed, preserving
existing history. Local unit and full UI validation passed on both device
families; subsequent CI outcomes are recorded below.

## Verified

- Apple's releases feed and `scripts/select-xcode.py check` agreed with
  the installed Xcode 27.1 (27A9275) on 2026-10-22; XcodeGen 2.46.0.
- Before the change, the targeted Home test passed on iPad Pro 13-inch
  (M5, 16 GB), iOS 27.0, in 86.767 seconds, and iPhone 17, iOS 27.0,
  in 42.254 seconds. Both used full-screen simulator windows, light
  appearance, default and AX5 text. iPad covered portrait and landscape;
  iPhone remained portrait, as the app requires. No keyboard was shown
  by this Home test; the runner configured the full software keyboard.
- Deliberately moved each category's fourth tile 2,000pt sideways in a
  temporary app mutation. The optimized test reported the interior tile
  outside the window, including Basics and Needs, whose endpoints still
  fit. This proves the endpoint wait did not replace the full containment
  assertion. That mutation was removed before the initial commit; it
  contributed no app code change.
- `scripts/test.sh unit`: all 444 tests passed, with 65.2% app code
  coverage. The String Catalog was already synchronized.
- `scripts/test-runner.py`: all 51 tests passed in 32.416 seconds;
  `scripts/test-site.py`: all four tests passed.
- The optimized Home test passed during the full UI runs in 82.795
  seconds on iPad and 40.892 seconds on iPhone. The local reduction is
  modest. CI had not run at that point; later attempts are recorded
  separately below.
- `scripts/test.sh ui` completed both full suites: 31 passed, no failures
  and four existing opt-in keyboard probe skips on each device. Test
  execution took 477.075 seconds on iPad and 429.110 seconds on iPhone.
  The Home and reachability tests covered default and AX5 text; launch
  audits covered light and dark appearance; Settings used its existing
  default-text checks. All windows were full-screen. The four keyboard
  probes require their existing opt-in launch flag and were not enabled.
- After incorporating `5abdd9f`, all 460 unit tests passed with no skips
  or expected failures; app code coverage was 62.6% (3,540 of 5,659 lines).
  The String Catalog stayed synchronized. Both full UI suites passed:
  33 passed, zero failures and four existing opt-in probe skips per
  device. Test execution took 554.617 seconds on iPad and 511.691 seconds
  on iPhone. The Home test took 81.422 and 40.389 seconds respectively.
  The newly landed Personal Voice Ask-button test passed at default and
  AX5 text, and the new Family Setup placement test passed on both.

## CI attempts and audit investigation

Both attempts below tested head `9075a14`, before the diagnostic change.
GitHub used Xcode 27.1 (27A9275), iPad Pro 13-inch (M5) and iPhone 17
simulators on iOS 27.0. These Home timings are measurements from separate,
incomplete CI attempts, not evidence that either full attempt passed.

- [Attempt 1 UI job](https://github.com/MiddleAgedBanana/Brickson/actions/runs/39846330618/job/120060460012):
  the iPad test runner exited during bootstrapping before a named test
  started. On iPhone, the first app UI test failed obtaining the main
  window's accessibility snapshot (`kAXErrorServerNotFound`), before its
  ordering assertions. iPhone completed with 32 passed, one failed and
  four existing probe skips; the optimized Home test passed in 59.393
  seconds. The unit job passed. The failed UI job was rerun on the same
  commit after examining these startup failures.
- [Attempt 2 UI job](https://github.com/MiddleAgedBanana/Brickson/actions/runs/39846330618/job/120077196612):
  iPad completed with 32 passed, one failed and four existing probe skips.
  The optimized Home test passed in 149.393 seconds. The failure was
  `LaunchTests.testLargestTextKeepsQuickControlWordsVisible`: the AX5,
  light audit reported `elementDetection`, "Potentially inaccessible
  text", without identifying an element. This is an audit finding, not
  the audit-service timeout covered by the retry rule. The run was
  deliberately cancelled at 21:34:49 UTC after observing the iPad failure.
  The browser log view was stale: the downloaded log shows iPhone
  preparation and testing had started, with its warm-up completed at
  21:23:59 UTC. Cancellation interrupted that run, leaving no complete
  iPhone result; it must not be described as passed or as stalled before
  starting the next device.

The failed test's pre-audit screenshot and accessibility tree both include
the spoken message and Speaking status, along with the visible control
labels and emergency phrases. The recording shows the Speaking status
ending and the audit changing text size; the dark audit underwent similar
changes and passed. The capture predates the reported finding by about
3.54 seconds, and the custom failure has no issue-associated element or
rectangle. This evidence establishes no specific missing label or cause.

The unchanged focused test then passed locally in 23.932 seconds on the
iPad Pro 13-inch (M5), iOS 27.0, with Xcode 27.1 (27A9275): one test,
zero failures. It exercised AX5, portrait, full-screen, light and dark,
with no software keyboard shown. A passing reproduction does not dismiss
the CI finding. The new issue-time capture and native issue record aim to
identify the affected text if it recurs.

## Diagnostic negative checks and final local validation

A temporary mutation that hid the rendered message from accessibility did
not trigger the audit: the focused test passed in 8.792 seconds. It did
not reproduce the original `elementDetection` finding, and establishes
neither its cause nor a fix.

A separate temporary low-contrast mutation of the visible Home placeholder
made `testHomePassesTheAccessibilityAudit` fail as intended in 8.765 seconds
on iPad Pro 13-inch (M5), iOS 27.0, with Xcode 27.1 (27A9275), full-screen
portrait, default text and light appearance. One test failed with two
records for the same `contrast` finding: the contextual failure and
XCTest's native "Contrast failed" issue. The result retained the issue-time
screenshot, full accessibility tree and button JSON. It also retained
native issue text, an app screenshot and an element screenshot identifying
the deliberately pale placeholder. This verifies that the diagnostic
change preserves a real failing finding and useful evidence; it does not
reproduce the unidentified CI finding. Both app mutations were removed;
no app source change remains.

After the diagnostic change and mutation removal, `scripts/test.sh unit`
passed all 460 tests with no skips or expected failures. App code coverage
was 62.6% (3,540 of 5,659 lines), and the String Catalog remained unchanged.

The full iPad UI suite then passed on that working tree incorporating
`d79d836`: 37 total, 33 passed, zero failures, four existing opt-in keyboard
probe skips and zero expected failures. Test execution took 556.884
seconds; the optimized Home test took 82.546 seconds. This used iPad Pro
13-inch (M5), iOS 27.0, and Xcode 27.1 (27A9275), full-screen with the
suite's existing portrait/landscape, default/AX5 text and light/dark
coverage. The runner configured the full software keyboard.

The full iPhone 17 UI suite also passed on the same tree: 37 total,
33 passed, zero failures, four existing opt-in keyboard probe skips and
zero expected failures. Test execution took 503.597 seconds, and the
optimized Home test took 40.710 seconds. The app stayed in portrait,
full-screen on iOS 27.0, with the suite's existing default/AX5 and
light/dark coverage and full software keyboard configuration. The AX5
light/dark audit passed in 22.884 seconds. `scripts/test.sh ui` completed
successfully for both families; the original CI finding's cause remains
unestablished.

## CI after adding native diagnostic captures

Head `c311252` (the documentation follow-up to `431ee14`) completed
[run 39863233234](https://github.com/MiddleAgedBanana/Brickson/actions/runs/39863233234)
with the unit job passing and the UI job failing. On iPad, 31 tests passed,
two failed and four existing probes skipped in 870.118 seconds; the Home
test passed in 125.742 seconds. The first app test failed obtaining the
main-window accessibility snapshot (`kAXErrorServerNotFound`). The AX5
light audit separately reported `elementDetection` with no element.
On iPhone, all 33 enabled tests passed, with four existing probe skips,
in 793.617 seconds; Home took 67.456 seconds. No rerun was requested.

The new helper retained both contextual and native records for the audit
finding, plus issue-time screenshots, the full tree and button JSON. The
native attachment supplies the generic issue description and an app
screenshot, but no element or rectangle. The pre-audit capture includes
Speaking; the issue-time tree and both native and issue-time screenshots
show the message with Speaking absent. These observations support checking
a changing status line; they do not establish a different missing label.
This run predates the still-screen waits introduced by PR #31.

## Reconciliation with the still-screen audit fix

After the documentation follow-up `c311252`, `main` advanced to `479175d`
(PR #31), incorporated with a merge commit preserving the existing history.
The merge had no conflicts and retains both changes: the helper waits for
speech before each audit attempt and the AX5 captures,
while unexpected findings still keep the issue-time captures, contextual
failure and native XCTest issue. The existing phrase-label exception and
one retry for audit-service code `-56` are unchanged.

PR #31's [record](2026-10-22-audit-still-screen.md) documents a Speaking-line
timing race from other CI evidence. It does not retroactively identify the
text in this PR's earlier finding or establish that every similar finding
is fixed. Audits now cover the settled, post-speech screen; the Speaking
status coverage gap remains recorded in HANDOFF. The two new audit-runner
tests are retained. On this combined tree, `scripts/test.sh unit` passed
all 460 tests with no skips or failures; app coverage was 62.6%
(3,540 of 5,659 lines), and the String Catalog stayed unchanged. The full
iPad UI suite completed with 39 total tests: 34 passed, one failed and
four existing probe skips, in 679.475 seconds. Home passed in 82.362
seconds. The failing AX5 light/dark test took 143.552 seconds and recorded
four failures: two consecutive 30-second waits per appearance for Speaking
to disappear. The post-timeout captures and live dark screenshot show
Speaking still rendered. The hidden reservation views are explicitly
inaccessible; the two Speaking nodes are the combined visible status and
its text child. No timeout or assertion was weakened.

The full iPhone suite also completed with 39 tests: 34 passed, one failed,
four existing probe skips and no expected failures, in 629.830 seconds.
Home passed in 40.082 seconds; the AX5 light/dark test failed in 143.062
seconds with the same four Speaking-wait failures. Both devices used the
unchanged suite on iOS 27.0 and Xcode 27.1 (27A9275): full-screen,
default/AX5 text and light/dark coverage, iPad portrait/landscape and
iPhone portrait, with the full software keyboard configured. The script
completed with exit status 65. These are failed full UI runs, not green
validation.

Filtered logs for the iPad app processes show repeated CoreAudio server
startup errors when the phrases were requested. The app's callback and
watchdog paths are unchanged; this evidence does not establish the full
cause of the persistent status. A focused check on a newly created
isolated iPad remains pending while hosted CI checks the combined source
independently.

## Not verified

Full local UI validation on the tree incorporating `479175d` has not
passed. The Speaking wait failure still needs diagnosis, and CI on the
resulting pushed commit is pending. The earlier passing full UI results
cover the tree incorporating `d79d836`; they do not validate the later
merge. CI on `c311252` failed as recorded above.

Local simulator timings do not predict GitHub's machines. No physical-device,
sound, gaze comfort, Snap to Item or windowed-iPad claim is made here.

## Follow-ups

1. Verify required CI checks on the pushed commit; the owner merges.
   Re-run the required local checks if the intended tree changes before
   committing.
2. If the audit finding recurs, inspect its native issue, issue-time
   screenshot and full accessibility tree together. Identify the visible
   text and compare its frame and label at that moment, then reproduce
   that state before changing app semantics. Keep the finding failing;
   do not add an exception, blanket retry or known issue to make it green.
3. The layout engine still owns the already recorded small-window
   scrolling gap and profile floors. This test change accepts no new gap.

## Decisions

No product or accessibility decision changed. The owner requested the
75-minute CI allowance. The extra time does not retry or skip a test.


## Completion evidence after publication

CI on `f1f7954` passed (run 39871458458): 460 units, and 35 enabled UI
tests on each device, with four existing opt-in probe skips per device.
iPad UI took 749.156 seconds and Home 103.021 seconds; iPhone UI took
660.616 seconds and Home 54.828 seconds. CodeQL and CodeRabbit passed,
Codex code review completed cleanly, and both review threads were resolved.
The owner merged PR #32 as `313de2c`.

The fresh isolated iPad and Device Hub-connected focused checks reproduced
the local Speaking waits. Host CoreAudio logs also reported the built-in
output driver's startup failure (IOKit kIOReturnDeviceError). This is a
known local audio limitation; no host audio service or setting was changed.
The independent CI result above validates the exact published source on
both device families. It does not establish the cause of the older CI
audit findings or prove physical-device sound or gaze behavior.
