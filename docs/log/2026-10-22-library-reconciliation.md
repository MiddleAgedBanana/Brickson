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

Independent review compared the reconciliation with both the original PR
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

Local unit and UI verification is complete. CI and final reviews on the
pushed head remain pending.

## Follow-ups, in order

1. Commit and push the tested reconciliation to the existing PR branch,
   then address any new review conversation and verify CI on that commit.
2. Continue the existing library follow-ups: safety copies, export and
   import, editing screens, shipped-schema fixtures and issue #19's
   opt-in SwiftData rollback probe.

## Decisions

No new product or storage decision. Existing import and safety-copy
restrictions remain in force. The merge only reconciles concurrent work;
the owner retains the merge decision.
