# Phrase-library reconciliation with current main

*2026-10-22. Pull request #14; continuation of
[the library-core record](2026-10-21-library-core.md).*

## What changed and why

- Reconciled `main` at `5abdd9f` with the existing library branch,
  retaining the library core and the later Home layout, accessibility
  names, typing and Settings work, including PR #27's Voice Settings.
  The merge is prepared without rebasing.
- Resolved the shared-document conflicts by keeping the landed feature
  records and the library's additions. The status now says PR #14 is
  still open; its earlier claim that it had landed was premature.
- Combined both String Catalogs, preserving the library's refusal and
  recovery messages alongside the newer Settings and typing strings,
  including the Voice Settings additions and removals on current main.
  The full unit script confirmed the resulting catalog was synchronized.
- Adapted `StarterLabelFitTests` to read `LibrarySnapshot` and each
  phrase's `text`. It still measures every starter label with the same
  fonts, slots, text sizes and assertions; only its input representation
  changed.
- Category add and rename now reserve every input label in
  `HomeControlNames.fixed`, including `Repeat`, which current main added
  as an alias for Again. Import still keeps a backup category called
  `Repeat`, byte for byte. Editing screens remain unbuilt.
- `LibraryEditor.apply` still refuses a Replace that needs a safety copy.
  `aReplaceThatNeedsASafetyCopyIsRefused` continues to pin that guard;
  importing never gains permission to drop a person's words.

## Review and verification

Before this reconciliation, all 12 inline review conversations on PR #14
were resolved. The most recent Tests run on `972c5b1`,
[39668503888](https://github.com/MiddleAgedBanana/Brickson/actions/runs/39668503888),
passed unit tests. UI tests passed 17 of 17 on iPhone and 16 of 17 on
an iPad Pro 13-inch simulator: the first iPad reachability test failed
with `kAXErrorServerNotFound`. This is historical evidence, not a result
for this reconciliation.

The conflict resolution and snapshot adaptation have been inspected.
The new `Repeat` and `repeat!` add/rename cases were first run against
unchanged validation in a temporary macOS Swift package using the actual
pure source files and `LibraryEditTests`: both names were incorrectly
accepted, producing four failed expectations. The package uses the
project's Swift 6 mode, strict concurrency and default main-actor
isolation, without substituting Foundation APIs. After the fix, all
44 tests in `LibraryEditTests` and `LibraryImportTests` passed, including
the new alias refusals and the import-preservation cases. This ran on
macOS using Xcode 27.1 (27A9275), Apple Swift 6.4; it does not exercise
SwiftData, UIKit or an iOS simulator.

The full `scripts/test.sh unit` run passed on an iPad Pro 13-inch (M5)
simulator with iOS 27.0 (24A434), using Xcode 27.1 (27A9275) and XcodeGen
2.46.0: 549 tests total, 548 passed, zero failures, one skipped and zero
expected failures. The result bundle is `build/TestResults/unit-ipad.xcresult`.
App line coverage was 66.7% (4,367 of 6,544 lines). The String Catalog
already matched the extracted strings; no synchronization change was needed.

The sole skip, verified in the result bundle, was
`SwiftDataBehaviourTests.s4RollbackAfterDeletingACategoryAndItsPhrases()`.
Its existing disabled reason is "Crashes SwiftData: rollback() after deletes
traps (issue #19)". The same disabled crash reproduction was already present
on the original PR head `972c5b1`; this reconciliation did not add or widen a
skip. Production code never calls rollback. Re-enabling the crash probe stays
an isolated follow-up to [issue #19](https://github.com/MiddleAgedBanana/Brickson/issues/19).

An initial independent review compared the reconciliation with both the original PR
head and `main` at `5abdd9f` and found no actionable defects. It confirmed
that main's Voice Settings code and catalog metadata were retained, no
obsolete catalog keys were restored, the import/applier safety-copy
restriction was unchanged, and the Repeat edit/import tests preserved the
intended distinction.

The full `scripts/test.sh ui` run passed on both device families with
Xcode 27.1 (27A9275) and iOS 27.0 (24A434):

| Simulator | Passed / total | Existing skips | Failures | Suite time | Starter-library layout test |
| --- | --- | --- | --- | --- | --- |
| iPad Pro 13-inch (M5) | 33 / 37 | 4 | 0 | 556.838 s | 84.226 s |
| iPhone 17 | 33 / 37 | 4 | 0 | 498.627 s | 41.735 s |

The result bundles are `build/TestResults/ui-ipad.xcresult` and
`build/TestResults/ui-iphone.xcresult`. Both have zero expected failures.
The four skipped cases on each device are the existing opt-in
`KeyboardProbeTests` measurements: portrait and landscape at default and
largest text sizes. They require `TEST_RUNNER_BRICKSON_KEYBOARD_PROBE=1`;
this run did not enable that measurement. Neither the full software
keyboard nor the hardware-keyboard bar was measured.

Coverage, checked against the test source: Home layout and reachability
run in light appearance at default and AX5 text sizes, in iPad portrait
and landscape and iPhone portrait. The iPhone rotation attempts confirm
that it remains portrait. Home accessibility audits and AX5 quick-control
labels include light and dark appearances; the Settings, Family Setup and
Privacy Policy audits cover light and dark at default text size. Voice
Settings is audited in light at default size. Its Ask-button refusal is
checked at default and AX5 in light using the test stand-in, not the real
iOS permission question. These are ordinary simulator launches; no
multitasking or Display Zoom configuration was measured. No physical-device,
sound, gaze-comfort or Snap to Item validation is claimed.

### Follow-up review on the pushed reconciliation

The later Codex review found two valid issues. The existing branch had
reversed the earlier owner-only restriction on replacing personal words
after a safety copy. The decision now restores that restriction, explicitly
unadopted pending the owner's decision, and corrects the related handoff,
source comments and earlier log claim. `LibraryEditor.apply` continues to
refuse every plan needing a safety copy; its behavior did not change.

Emergency could also hold one phrase with words plus an imported blank.
Deleting or moving the words left nothing Emergency could say. The planner
now requires a remaining nonblank phrase, and the snapshot backstop uses
the same rule. Imported ASCII whitespace and nonbreaking-space bytes stay
unchanged. Removing a blank, editing the words and reordering remain valid.
Two parameterized regressions first failed with six expectations against
the previous source. All 46 pure edit/import tests then passed on macOS
using the real source files, Swift 6 strict concurrency and default
main-actor isolation. Restoring the old count-only guards or snapshot
predicate makes these regressions fail.

The full `scripts/test.sh unit` rerun passed for this follow-up: 550 passed,
zero failures, the same one disabled issue #19 crash probe, zero expected
failures (551 total). App line coverage was 66.8% (4,382 of 6,559 lines),
and the String Catalog remained synchronized. The run used Xcode 27.1
(27A9275), XcodeGen 2.46.0 and iPad Pro 13-inch (M5), iOS 27.0 (24A434).
Its result bundle is `build/TestResultsReview/unit-ipad.xcresult`.
An independent follow-up inspection found no additional defect. In an
already-damaged blank-only Emergency category, removing another blank is
now refused until words are added or edited; other repairs remain possible.
The local UI results above predate this follow-up; it changes the
unexposed editing planner and source comments, with no UI implementation
or UI-test changes in that commit.

### CI on `596c59a` and the diagnostic follow-up

The follow-up was pushed as `596c59a`, and both findings were answered and
resolved. All 14 inline review conversations are resolved. Codex's
[code-review summary](https://github.com/MiddleAgedBanana/Brickson/pull/14#issuecomment-6309731643)
reports completed with no findings for that exact commit. This is separate
from its older PR-opening security summary.

[Tests run 39854568808](https://github.com/MiddleAgedBanana/Brickson/actions/runs/39854568808)
finished with a failed UI job. It used Xcode 27.1 (27A9275), iOS 27.0
(24A434), and the same two simulator models as the local runs. Units passed:
550 passed, zero failures, the same issue #19 crash probe skipped, zero
expected failures (551 total). The UI results were:

| Simulator | Passed / total | Existing skips | Failed tests | Suite time | Starter-library layout test |
| --- | --- | --- | --- | --- | --- |
| iPad Pro 13-inch (M5) | 33 / 37 | 4 | 0 | 797.417 s | 113.083 s |
| iPhone 17 | 32 / 37 | 4 | 1 | 1,042.657 s | 106.053 s |

Both bundles have zero expected failures. The same four opt-in keyboard
measurements were skipped on each device. On iPhone in portrait,
`LaunchTests.testLargestTextKeepsQuickControlWordsVisible` failed two
accessibility findings at AX5, one in light and one in dark: type 2,
"Potentially inaccessible text", with no element identified. That test
took 50.978 seconds; it passed on iPad in 29.505 seconds. This was a finding,
not the known audit-service timeout. It has not been suppressed or retried.

The retained
[UI result artifact](https://github.com/MiddleAgedBanana/Brickson/actions/runs/39854568808/artifacts/12461807161)
was inspected, including both full pre-audit screenshots, their complete
accessibility trees, the activity record and recorded frames. Every visible
app word in those paired screenshots is represented in its tree, including
"Speaking". Later recorded frames show that status disappearing while its
reserved area and nearby controls keep their positions, followed by
text-size changes during the audit. The recording is sparse: it does not
establish the exact instant of the status change. The old helper handled
the native issue after recording its own contextual failure; none of the
53 exported attachments is associated with a failure, and no native element
or rectangle identifies the flagged text. The pre-audit captures therefore
do not establish which text caused the finding. The cause remains unresolved.

This follow-up merges `main` at `d79d836` without rebasing, bringing in
PR #20's documentation without changing app code or tests from main.
The shared audit helper is strengthened: unexpected findings capture a screenshot
and full accessibility tree when reported, retain the contextual `XCTFail`,
and return `false` so XCTest preserves its original issue and available
native diagnostic attachments. The already accepted phrase-label guess
still returns `true`; no new finding is accepted and no assertion is removed.
A bounded iPhone repetition of the same AX5 quick-control test ran with
`-test-iterations 5 -run-tests-until-failure`, stopping on the first failure
if one occurred. All five iterations passed: 23.452, 22.269, 22.262,
22.272 and 22.272 seconds (112.527 seconds total). Each iteration audited
both light and dark appearances. This did not reproduce the CI finding
and does not establish a fix or replace that failed CI result. The bundle
is `build/TestResultsAuditRepetition/ui-iphone.xcresult`.

The fresh full unit gate for the merge and diagnostics passed:
550 passed, zero failures, the same one disabled issue #19 crash probe,
zero expected failures (551 total), with 66.8% app line coverage
(4,382 of 6,559). The String Catalog remains synchronized. This used
Xcode 27.1 (27A9275), XcodeGen 2.46.0, and iPad Pro 13-inch (M5),
iOS 27.0 (24A434).

The fresh full `scripts/test.sh ui` run also passed on both device families,
with Xcode 27.1 (27A9275) and iOS 27.0 (24A434):

| Simulator | Passed / total | Existing skips | Failures | Suite time | Starter-library layout test | AX5 quick-control audit |
| --- | --- | --- | --- | --- | --- | --- |
| iPad Pro 13-inch (M5) | 33 / 37 | 4 | 0 | 549.809 s | 84.882 s | 23.365 s |
| iPhone 17 | 33 / 37 | 4 | 0 | 496.122 s | 41.412 s | 22.362 s |

Both bundles have zero expected failures, with only the four existing
opt-in keyboard measurements skipped on each device. The bundles are
`build/TestResultsDiagnostics/ui-ipad.xcresult` and
`build/TestResultsDiagnostics/ui-iphone.xcresult`. Device orientation,
text-size, appearance and keyboard-coverage limits remain as stated above.
The AX5 quick-control test passed both appearances on each device; this
is additional local non-reproduction, not an identified correction to the
failed CI finding. No app behavior, audit assertions or accepted findings
changed. A read-only inspection found no additional issue in the helper;
the installed Xcode header confirms that returning `true` handles an issue
instead of recording it, so `false` preserves XCTest's native report.
Fresh CI and review for the pushed merge remain pending.

### Later category-name review

Two later CodeRabbit conversations identified a real symbol-name collision
and a wrong enum name in the decisions record. Both remained open after the
14 earlier conversations were resolved. The category comparison stripped
symbols as well as the documented case, accents, width, punctuation and
spaces. This made distinct simple emoji share an empty key, and distinct
composed emoji share a format-only key, so add and rename refused the second
name as a duplicate. Category comparison now preserves symbols. The
punctuation-insensitive rule is unchanged.

Home control reservation remains stricter: it reuses
`HomeControlNames.spokenForm` and ignores spacing, so symbols cannot disguise
Yes, No, Emergency, Again, Repeat or the other fixed control names. This
also closes the existing gap where joiners or variation selectors let a
decorated fixed name through. Import still bypasses editing normalization
and preserves name bytes. The decision's `libraryNeedsACategory` reference
now correctly names `LibraryEditRejection`.

Failing-first verification used the actual pure source files and existing
macOS Swift 6 package with strict concurrency and default main-actor
isolation: 50 tests ran with 42 issues before the fix. Six were add/rename
collisions across simple, joined and variation-selector emoji pairs; 36 were
accepted Home names decorated with joined or variation-selector emoji.
After the fix all 50 edit/import tests passed. The same suite checks
identical symbol-name rejection, keeping a category's own name, existing
case/accent/width/punctuation duplicates, every current Home input label,
and byte-preserving import of spaced symbol names. Restoring symbol
stripping makes the distinct-name regressions fail; using that category
comparison for reservation makes the decorated-control regressions fail.

These are unexposed editing-planner changes. The full UI evidence above
belongs to `182df4b`, before this comparison follow-up. The fresh full
`scripts/test.sh unit` gate passed: 554 passed, zero failures, one existing
disabled issue #19 crash probe, zero expected failures (555 total). App line
coverage was 66.8% (4,384 of 6,561 lines), and the String Catalog was unchanged.
This ran with Xcode 27.1 (27A9275), XcodeGen 2.46.0, on iPad Pro 13-inch (M5),
iOS 27.0 (24A434). The bundle is `build/TestResults/unit-ipad.xcresult`.
A separate inspection found no additional issue in the focused diff. Fresh
CI and review must validate the new head; no fresh full UI run is claimed
for this pure comparison follow-up.

## Follow-ups, in order

1. Answer and resolve the two category-name follow-up conversations with
   the pushed commit and test evidence, then verify fresh CI and review.
   PR #14 is not green until those checks pass.
2. If the AX5 finding recurs, inspect the new captures and native report to
   identify and fix its cause. The earlier failed run remains evidence;
   local passes do not explain it or authorize suppressing a finding.
3. Continue the existing library follow-ups: safety copies, export and
   import, editing screens, shipped-schema fixtures and issue #19's
   opt-in SwiftData rollback probe.

## Decisions

No new product or storage decision. Existing import and safety-copy
restrictions remain in force. The merge only reconciles concurrent work;
the owner retains the merge decision.
