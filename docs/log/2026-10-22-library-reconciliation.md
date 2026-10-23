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

### Later invisible-text review

The category-name fixes were pushed as `d241dea`, and both related
CodeRabbit conversations were answered and resolved. A subsequent Codex
review found a further Emergency gap: WORD JOINER and BOM, like other
format-only strings, survive whitespace trimming. The snapshot, last-phrase
delete/move guards and Replace fallback therefore counted a silent imported
phrase as words. The same input was also accepted by the editor despite its
existing nonblank name/phrase rule.

`LibraryText.isBlank` now classifies text as blank only when every scalar
is whitespace, a Unicode control code, or a default-ignorable code point.
The editor's name and phrase guards use this same predicate. It does not
remove any scalar or change import normalization. Letters, combining marks,
meaningful joiners and variation selectors remain intact when the text has
content. The current Xcode documentation for
[`isDefaultIgnorableCodePoint`](https://developer.apple.com/documentation/swift/unicode/scalar/properties-swift.struct/isdefaultignorablecodepoint)
defines those scalars as having no glyph of their own while potentially
affecting nearby characters; Unicode general category `Cc` covers control
codes, including NUL and BEL.

Failing-first verification ran the actual unmodified `d241dea` pure sources
against the expanded tests: 54 tests ran with 99 issues. Nine showed the
snapshot counting invisible text as Emergency words, 18 allowed the final
words to be deleted or moved away, 45 accepted invisible editor names or
phrases, and 27 failed to keep current Emergency words beside a blank-only
backup. After the correction all 54 pure edit/import tests passed with
Swift 6, strict concurrency and default main-actor isolation.

The 11 blank inputs include whitespace, nonbreaking space, WORD JOINER,
BOM, ZWJ, standalone variation selectors, COMBINING GRAPHEME JOINER, NUL,
BEL and a mixed string. Seven nonblank controls include Persian and
Devanagari joiners, joined/variation-selector emoji, a decomposed accent,
and words surrounded by format or control scalars. Their bytes remain
unchanged. Both merge and Replace retain the invisible imported names and
phrases byte for byte; Replace adds the current Emergency words when
necessary instead of deleting the incoming text. Restoring the old blank
predicate or editor guards fails these regressions. A separate bounded
inspection found no additional issue in these paths.

The repeated CodeRabbit concern about recording both contextual and native
audit failures was answered without weakening the diagnostic helper.
Xcode's current header confirms that returning `true` suppresses native
issue recording. A prior deliberate single-contrast failure with the
identical helper on PR #32 retained both reports and continued to four
later phrase-tile callbacks. That probe injected one unexpected finding;
it did not establish behavior for two independent unexpected findings.

The fresh full `scripts/test.sh unit` gate passed: 558 passed, zero
failures, one existing disabled issue #19 crash probe, zero expected failures
(559 total). App line coverage was 66.9% (4,395 of 6,572 lines), and the String
Catalog was unchanged. This used Xcode 27.1 (27A9275), XcodeGen 2.46.0,
iPad Pro 13-inch (M5), iOS 27.0 (24A434). The bundle is
`build/TestResults/unit-ipad.xcresult`. The 554-pass result above belongs
to `d241dea`; full local UI evidence remains the `182df4b` baseline.
Current-head CI and review are still required, and the earlier unexplained
iPhone audit finding remains open evidence.

### Reconciliation with the settled-screen audit

The invisible-text correction is commit `4fbd521`. Before publishing,
`main` advanced to `479175d` with PR #31's settled-screen audit change.
A new merge was prepared with `--no-ff --no-commit` and no conflicts.
It retains this branch's library changes and native audit diagnostics while
adding main's wait for Home's Speaking status to disappear before an audit
and before the single permitted service-timeout retry. The AX5 test also
waits after Again becomes enabled, before its captures and label checks.
The wait is bounded at 30 seconds and records a failure if speech has not
finished. No app code or audit finding filter changes in this merge.

The settled-screen behavior and the native diagnostic handler combine:
unexpected findings still capture the screen/tree, record the contextual
failure and return `false` to preserve XCTest's native report. The runner's
two new ordering tests and its updated call sites are retained. Main's
HANDOFF addition explicitly records the coverage gap: these audits do not
inspect the Speaking status itself; auditing that state deliberately needs
the planned held-speech test seam.

PR #31 records timing evidence from another CI run. This merge does not
retroactively identify the offending element in PR #14's earlier
`596c59a` failure; its sparse video and missing native issue metadata remain
insufficient for that claim. The combined `scripts/test.sh unit` gate
passed with the same Xcode 27.1 (27A9275), XcodeGen 2.46.0, iPad Pro
13-inch (M5) and iOS 27.0 (24A434): 558 passed, zero failures, one existing
issue #19 crash-probe skip, zero expected failures (559 total). App line
coverage was 66.9% (4,395 of 6,572 lines), and the String Catalog was
unchanged. The latest complete local UI evidence is still `182df4b`,
before the pure library follow-ups and this main merge.

The publication sequence changed to let hosted CI validate this combined
head while a local simulator audio failure is investigated. The same
inherited audit wait failed in PR #32's local combined run: Speaking
remained visibly present after its 30-second wait, and the simulator log
contained repeated CoreAudio backend startup errors. Those observations
are correlated evidence, not an established app defect or a diagnosis of
PR #14's older audit finding. No app speech change, arbitrary speech cutoff
or audit suppression was introduced. PR #14's merged UI has not yet been
validated locally; the full iPad/iPhone run remains due after the audio
environment is checked. The successful combined native unit gate above
precedes the merge commit. Fresh hosted CI and review must assess the
published head; results for `d241dea` do not validate these later changes.

### Review after `4808701`: punctuation and invisible name decorations

The punctuation-only P1 was investigated rather than assumed correct.
A temporary pure-library hypothesis test confirmed that `"..."` is accepted
through snapshot validation, editing Emergency's last phrase, deleting or
moving its other words, and Replace without adding current Emergency words.
Six expectations enforcing the proposed new restriction failed. This
establishes existing behavior, not that the resulting utterance is silent.

A separate bounded offline `AVSpeechSynthesizer.write` probe used
macOS 27.0.1, Xcode 27.1 (27A9275), and the compact Samantha en-US voice.
`"..."` generated 11,904 PCM frames, with 11,106 samples above amplitude
0.00001 and a peak of 0.709. The `"Help."` control and `"?!"`, an em dash,
`"@"`, `"#"`, `"&"` and a grinning emoji also generated nonzero audio.
All reached a terminal buffer; this probe used no playback or simulator.
Apple's [write documentation](https://developer.apple.com/documentation/avfaudio/avspeechsynthesizer/write(_:tobuffercallback:)),
read through Xcode, describes receiving synthesized buffers and makes no
punctuation-silence guarantee. These results do not establish pronunciation
or behavior on every iOS or Personal Voice. They contradict the finding's
blanket silence premise, so it was answered and resolved as not actionable
as stated. Neither phrase validation nor the Emergency policy changed.
The temporary hypothesis test was not added to the repository.

The separate duplicate-name finding was partly reproduced. Foundation's
whitespace set already covers U+200B, so its proposed `Needs` plus trailing
U+200B example was already refused. WORD JOINER/BOM decorations, an internal
soft hyphen, NUL and BEL did make duplicate add/rename names pass: the final
failing-first run had ten failed expectations across five cases. The new
comparison drops only standalone blank Swift Characters, retaining every
meaningful grapheme's scalars before the existing punctuation/spacing
comparison. A blanket removal of all default-ignorable scalars was rejected:
it would erase joining distinctions and collapse different emoji tag flags.
Apple's [Character documentation](https://developer.apple.com/documentation/swift/character),
read through Xcode, defines that boundary as an extended grapheme cluster.

All 56 pure library edit/import tests now pass. The new six-case duplicate
regression covers the five actual gaps and the already-safe U+200B case.
The separate six-case storage/import regression confirms that comparison
is not applied to saved or imported bytes; the pre-existing editor edge
trim remains unchanged. Expanded add/rename controls preserve joined versus
unjoined emoji, Persian ZWNJ, Devanagari ZWJ/ZWNJ and distinct England/Scotland
tag flags, alongside existing emoji, meaningful-text and Home-alias cases.
Removing the standalone-blank filter makes the duplicate regression fail;
removing joining/tag scalars would break the composed-name cases.
The fresh full `scripts/test.sh unit` gate for this comparison follow-up
passed: 560 passed, zero failures, one existing issue #19 crash-probe skip,
zero expected failures (561 total). Coverage was 66.9% (4,400/6,577), and
the String Catalog was unchanged. It used the explicit iPad Pro 13-inch
(M5) destination on iOS 27.0 with Xcode 27.1 (27A9275); results are under
`build/TestResultsInvisibleNames`. An independent bounded review found no
additional regression in the name comparison or byte-preservation paths.

Full local UI on this follow-up remains pending. The host audio driver
also failed to start outside the simulator, independently of Brickson;
repair requires approval for a brief host audio restart. This supports
investigating the local environment before changing app speech behavior,
but does not explain the earlier CI AX5 finding. The current published
`4808701` CI unit job passed 558 tests with one existing skip (559 total);
its UI was still running when this batch was prepared. Fresh CI must
validate the new comparison follow-up, and full local UI is still due.

The visible-name intent already motivated duplicate validation, but its
binding list did not include invisible decorations. The precise bounded
comparison rule is therefore recorded beside editing rules as a reversible
default adopted 2026-10-22. No stored text or import rule changes.

The HANDOFF verification bullet now reports current state, with this log
retaining the chronology. Its prior PR #14 technical section is preserved
verbatim in [the archive snapshot](../archive/2026-10-22-before-library-verification-summary/docs/HANDOFF.md).
Only the affected technical section is copied, excluding unrelated sections
and attribution details under the owner's current privacy instruction.
The review's claim that toolchain versions were not requested did not apply:
the owner explicitly requested the Xcode version and measured evidence.
Those details remain here. Auto-merge has been disabled during coordinated
validation; the owner retains the merge click.

## Follow-ups, in order

1. Verify fresh hosted CI and review after publishing the tested
   standalone-blank comparison follow-up and answering its two review
   conversations. Complete full local iPad/iPhone UI once the host audio
   environment is repaired; record that result separately from the
   `182df4b` baseline. PR #14 is not green yet.
2. If the AX5 finding recurs, inspect the new captures and native report to
   identify and fix its cause. The earlier failed run remains evidence;
   local passes do not explain it or authorize suppressing a finding.
3. Continue the existing library follow-ups: safety copies, export and
   import, editing screens, shipped-schema fixtures and issue #19's
   opt-in SwiftData rollback probe.

## Decisions

Category-name comparison now has the explicit bounded default recorded
above and in DECISIONS. Existing phrase, Emergency, import and safety-copy
restrictions remain in force. No new storage or speech policy is adopted;
the owner retains the merge decision.


## Main refresh after PR #32 landed

CI on `7ec516f` passed in run 39872469181: 560 units, zero failures and
one existing issue #19 skip; each UI suite passed all 35 enabled tests,
with four existing opt-in probe skips. iPad UI took 872.179 seconds
(Home 162.168 seconds), iPhone 686.526 seconds (Home 55.060 seconds).
All 21 existing conversations are resolved; Codex's summary still reports
its current-head code review as running, so no completed review is claimed.

Full local UI on that same head completed with 34 passed, one failed and
four existing skips per device. Only the AX5 speech-completion test failed,
with four Speaking waits per device. iPad took 677.953 seconds (Home
83.837 seconds), iPhone 628.687 seconds (Home 41.047 seconds). The known
host audio-driver limitation remains; no Mac audio setting was changed.

The owner merged PR #32 to main as `313de2c`. This follow-up incorporates
it by merge commit, retaining the new 75-minute UI timeout and bounded
Home test; the library implementation is unchanged. Main's briefing and
new log were read. The combined native unit gate passed 560 tests, with zero failures and
the existing issue #19 skip (561 total), using Xcode 27.1 (27A9275),
iPad Pro 13-inch (M5), iOS 27.0. The catalog stayed unchanged; coverage
remained 66.9% (4,400/6,577). The refreshed head requires a new CI run. Replace still refuses every
plan that needs a safety copy. Auto-merge remains off.


## Main refresh after PR #29 landed

Main `cc35c30` adds the record of retained CI test artifacts. Its changed
briefing, handoff and log were read and merged without conflicts; no app
or test source changes in this refresh. The prior head `1ede402` passed
hosted units and all 35 enabled iPhone UI tests. Its first iPad attempt
had two accessibility-window server errors and a Needs-selection timeout;
the saved accessibility snapshots around that timeout contained no child
elements. That suggests runner/accessibility-service trouble but does not
prove its cause. One failed-job rerun on unchanged source was requested;
no assertions or accessibility findings were suppressed.

The fresh local unit gate passed 560 tests, with zero failures and the
existing issue #19 skip (561 total). Xcode 27.1 (27A9275), iPad Pro 13-inch
(M5), iOS 27.0; the String Catalog is unchanged, and app line coverage is
66.9% (4,400/6,577). New-head CI remains required. The owner re-enabled auto-merge on both remaining PRs;
agents leave those settings in place. Replace import remains refused until
safety copies exist. No new binding decision is introduced.
