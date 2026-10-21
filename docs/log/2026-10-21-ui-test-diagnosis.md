# PR #13: UI-test failures reproduced on a Mac

Investigation started at `6e6cbccd74382ba3fe8e85f08de8d89b2058f8d6` on
`claude/project-thread-ieeqg5`. PR #12 had already merged as
`6891f0cc8bb1202ad30fff649b79a860a1283758`, and that commit was included in
the branch. The existing automation and repository protections were left
alone.

## Evidence before changing the implementation

- Historical [run 39555887215](https://github.com/MiddleAgedBanana/Brickson/actions/runs/39555887215),
  head `53436bf`, failed its brightness gate on both devices (1.0 in each
  appearance) and its iPhone audits. The app's Home implementation had not
  changed from main: expanding the device coverage exposed existing
  layout and test-harness problems.
- Current-head [run 39594379758](https://github.com/MiddleAgedBanana/Brickson/actions/runs/39594379758)
  passed Unit tests but cancelled UI tests. Its UI job's log was unavailable
  (`BlobNotFound`/`log not found`). The precise cause of that cancellation
  is unknown; do not attribute an old failure to this run.
- Local reproduction: Xcode 27.1 (27A9275), XcodeGen 2.46.0, iPhone 17,
  iOS 27.0 (24A434), full-screen portrait, default Dynamic Type, software
  keyboard configured full-size (no typing screen is implemented).
  Eight launch tests ran: four passed, the appearance gate failed, and
  three audits reported expected failures. Removing the phone audit
  expectation made the existing light audit fail normally, with no skips.
- The saved screenshots named `Home, light` and `Home, dark` were both
  visibly light. Their whole-screen medians were both 0.41830065359477125.
  Reapplying `XCUIDevice.appearance` after Home appeared did not help:
  readback said dark while the screenshot stayed light. This was not
  evidence of an incorrect dark palette.
- After the initial appearance, vertical-sizing and eager-grid repairs,
  the complete UI suite passed all 16 tests on each local device. That was
  insufficient evidence: inspection of the saved AX5 iPhone screenshots
  still showed clipped Yes, No, Emergency and Again words. Their
  accessibility labels were complete and their button frames met the
  reachability checks, so neither those checks nor the audits exposed the
  remaining rendering defect.
- A new rendered-label regression was run before changing the compact
  arrangement. `testLargestTextKeepsQuickControlWordsVisible` failed all
  24 label checks: four controls × three states × light/dark. Vision
  returned no words for Yes, No and Emergency, and fragments such as
  `Ag` / `ain` for Again. Evidence is in
  `/tmp/brickson-words-red.log` and
  `/tmp/brickson-pr13-words-red/ui-destination.xcresult` on this Mac;
  these temporary artifacts are not committed and may later be removed.
- The same test on iPad then found Emergency split as `Emer-` / `gency`
  at AX5, despite the larger screen. The saved screenshot
  `/tmp/brickson-pad-words-captures/4F1F1568-14D2-46A5-90CB-E4AC602CDE36.png`
  shows the inline icon taking width from the word. Compact phrase tiles
  likewise split words such as `Maybe.` at AX5 in two columns.

The committed screenshots retain the visual evidence even after temporary
result bundles are removed: [phone before](ui-test-evidence/iphone-ax5-before.png),
[phone after](ui-test-evidence/iphone-ax5-after.png),
[iPad before](ui-test-evidence/ipad-ax5-before.png), and
[iPad after](ui-test-evidence/ipad-ax5-after.png). All show full-screen
portrait, AX5, light appearance. “Before” means the initial audit-only
repair, before the final word-layout corrections; it is not a capture of
the untouched PR head.

## Causes and corrections

1. **Appearance was requested but never rendered.** Apple's documented
   `XCUIDevice.appearance` usage is valid; its [WWDC example](https://developer.apple.com/videos/play/wwdc2025/344/)
   sets it before launch. A [developer forum report](https://developer.apple.com/forums/thread/812656)
   describes the same command-line-only failure on an earlier runtime;
   it is corroboration, not an Apple-confirmed diagnosis of this runtime.
   Debug launches now accept `--appearance=light|dark` and apply the public
   `preferredColorScheme` presentation API. Normal and release launches
   keep a nil preference and follow the system. The test still checks
   rendered pixels independently. It samples the empty gap between Yes
   and No: a phone's coloured tiles can dominate a whole-screen median.
2. **Labels were vertically compressed.** Allowing the quick-control,
   Speaking and phrase labels their full vertical size removed the
   clipping findings in the first local experiment. This repaired the
   audit result but did not establish that every visible word fit; the
   subsequent screenshot inspection and regression below showed otherwise.
   Fonts, audit types, colour thresholds and minimum target sizes were
   not reduced.
3. **Lazy phrase rows prevented a reliable Dynamic Type comparison.**
   Fixed-height corrections alone left findings on lower lazy rows; the
   existing font already used a Dynamic Type text style. Eager rows made
   the strict audits pass, consistent with lazy elements disappearing as
   enlarged text reduces the visible viewport. The small
   phrase grid now eagerly creates its rows, retaining the stored order
   so the audit can compare the same elements. Column counts remain fixed
   at each width class: one compact, three regular. The compact count was
   subsequently reduced from two to give AX5 words enough width.
   The phone expected-failure helper is removed; all real audit findings
   fail on both device families. Eager creation is appropriate for today's
   small starter library; revisit performance with the eventual layout
   engine, preserving audit coverage. The pre-existing nonempty phrase-label
   heuristic exception remains unchanged.
4. **Controls did not have enough width for their visible words.**
   Keeping Again beside the message and all three quick controls in one
   row left narrow labels at AX5. Their decorative icons competed with the
   words, even though the accessibility frame described a large button.
   Compact widths now reserve one full-width message line with a
   full-width Again below; Yes and No share a row and Emergency takes the
   full row below them. This arrangement is fixed across text sizes and
   Home states. The subsequent iPad finding established that icon width
   also split Emergency on a regular-width screen. Yes, No and Again now
   omit decorative symbols on both width classes. Emergency retains its
   warning/checkmark in a permanent 22pt-high slot above the text on both,
   so the selected cue consumes no word width and does not move the
   control. Regular widths retain two message lines with Again beside
   them and the horizontal quick-control row. Longer messages continue
   to scroll at full size within the reserved viewport. Compact phrase
   tiles use one column at every text size to avoid splitting short words
   such as `Maybe.`; regular widths retain three columns.

   The new test uses Apple's Vision text recognizer on each button's
   screenshot at AX5, in light/dark, immediately after launch, with
   Emergency selected, and after choosing Yes. It supplies neither custom
   words nor language correction, and also performs the accessibility
   audit at AX5 in both appearances. Reverting to the old compact
   arrangement is the demonstrated failing mutation. The four existing
   reachability tests additionally compare all four edges of Yes, No,
   Emergency and Again against their launch frames after Emergency and
   speech, with 1pt rounding tolerance. A state change moving any edge
   farther than that now fails, even if the control remains reachable.

   **Recognizer correction, separate from the app defect:** Vision's
   accurate mode returned `ON` for a visibly clear, upright phone `No`.
   The fast mode read `No`; a macOS Vision check also confirmed that it
   rejected all four old clipped button captures. The test therefore uses
   fast recognition and still requires a complete word, ignoring case
   only, with no language correction or supplied vocabulary. It does not
   accept fragments, hyphenated pieces, or a fuzzy match. Complete final
   validation is pending below.
5. **Speech ignored the selected test settings store.** `LaunchOptions`
   supplied a test-only suite, but `SpeechService` read and wrote
   `UserDefaults.standard`. The app now injects `launch.settings` into
   the service for every preference access. A seeded-suite regression
   failed both its voice and rate assertions before the fix. Tests also
   cover saving, clearing and a fresh-test-storage reset.
6. **The two-device runner left both simulators running.** The script now
   shuts down only devices it successfully booted, after each family and
   on failure/exit. Devices already running are preserved. A failed
   shutdown stops the next family and keeps an earlier test failure.
   Five new fixture tests first failed against the old script; all 51
   runner tests then passed on macOS bash 3.2. This fixes an observed
   contention risk, not a proven explanation of the cancelled CI job.

## Reproduction commands and results

Use dedicated simulators and run one at a time. Substitute their UDIDs;
the local devices were iPhone `21ECABAA-CC10-49CE-AD7A-5B73CBD3CF72` and
iPad Pro 13-inch (M5, 16GB) `86D4AF94-8B4C-43FE-9613-B31E0CEEC517`.

```sh
DESTINATION='platform=iOS Simulator,id=<udid>' \
  DERIVED_DATA_DIR=/tmp/brickson-pr13-derived \
  TEST_RESULTS_DIR=/tmp/brickson-pr13-results \
  scripts/test.sh ui

DESTINATION='platform=iOS Simulator,id=<udid>' \
  DERIVED_DATA_DIR=/tmp/brickson-pr13-derived \
  TEST_RESULTS_DIR=/tmp/brickson-pr13-unit \
  scripts/test.sh unit

python3 scripts/test-runner.py
bash -n scripts/test.sh
```

The focused rendered-label reproduction uses the same script and isolated
directories, with this test filter:

```sh
DESTINATION='platform=iOS Simulator,id=<iphone-udid>' \
  DERIVED_DATA_DIR=/tmp/brickson-pr13-derived \
  TEST_RESULTS_DIR=/tmp/brickson-pr13-words-check \
  scripts/test.sh ui \
  -only-testing:BricksonUITests/LaunchTests/testLargestTextKeepsQuickControlWordsVisible
```

The first local build under the task's Documents directory failed signing
because its app bundle acquired Finder/File Provider metadata. Building
under `/tmp` succeeded without changing signing or removing metadata from
the user's checkout. This was separate from CI and from test assertions.

| Check | Measured result | Scope |
|---|---|---|
| Initial complete UI runs, iPhone and iPad | 16 passed on each device | Before the compact arrangement and rendered-label regression; screenshots subsequently exposed the remaining defect |
| New rendered-label regression on the previous compact arrangement | 1 test failed, 24 failed assertions | iPhone 17, iOS 27.0, portrait, AX5, light/dark, three Home states; red evidence paths above |
| Final candidate, complete iPad UI run | 17 passed, 0 failed/skipped/expected failures | `/tmp/brickson-pr13-pad-final/ui-destination.xcresult`; 188.039s; portrait/landscape reachability and frame stability at default/AX5, light/dark audits and AX5 rendered words |
| Final candidate, complete iPhone UI run | 17 passed, 0 failed/skipped/expected failures | `/tmp/brickson-pr13-phone-final/ui-destination.xcresult`; 183.452s; default/AX5, portrait and attempted landscape (phone stays portrait), light/dark audits and AX5 rendered words |
| Final candidate, complete unit suite | 136 passed, 0 failed/skipped/expected failures | `/tmp/brickson-pr13-unit-final/unit-destination.xcresult`; 87.7% line coverage (1668/1901) |
| Runner fixtures / Xcode selector / website | 51 / 21 / 4 passed | `python3 scripts/test-runner.py`, `python3 scripts/test-select-xcode.py`, `python3 scripts/test-site.py`; `bash -n scripts/test.sh` and `git diff --check` also passed |
| Required CI on the final pushed commit | Pending | Local runs do not establish remote checks or a merge |

These results describe the final source tree before commit/push on
2026-10-21. No source changed after the complete runs. Required CI must
be read on the pushed head; local results do not establish remote success
or a merge. The initial 16-test passes are not verification of this layout.

## Limits

Simulator evidence does not verify sound, gaze comfort, Switch Control,
VoiceOver announcements or physical-device interaction. The stand-in
Home still has its documented layout-engine gaps. Compact widths trade
the former two-line message viewport for one full-width line; longer
messages remain scrollable at full font size. The compact grid's wider
tiles show fewer phrases at once and require more scrolling. The rendered-label test
checks the four English quick-control labels, not every user phrase or
every localized string, and text recognition does not prove legibility or
comfort for a person. Windowed iPad sizes and iPhone Duo poses remain
outside this verification. No audit types or test expectations were
weakened to obtain passing results; focused filters were used only for
diagnosis and do not replace the complete runs. The original cancelled
job's missing log prevents a definitive diagnosis of its duration.

## Remote checkpoint after the fix was pushed

At 15:20–15:22 UTC on 2026-10-21, the signed implementation commit
`db844b10c10b530a0489b3bd79eea4322f8b0d47` was confirmed on the existing
`claude/project-thread-ieeqg5` branch by both `git ls-remote` and GitHub's
Git-reference API. The working tree was clean. This documentation-only
follow-up does not change the tested implementation.

PR #13's API record still reported its previous head
`6e6cbccd74382ba3fe8e85f08de8d89b2058f8d6`, even on an uncached read, and
there were no Actions runs for the new implementation SHA. GitHub's
[official status feed](https://www.githubstatus.com/api/v2/summary.json)
reported the active incident **Delays for Pull Requests and Webhook
deliveries**, started at 14:52 UTC (incident `nms1dpzmh9d9`,
[incident link](https://stspg.io/gnnt0tx9nxmk)). That service incident is
consistent with the observed delay; it is not evidence that the new
commit's CI passed or failed. Final remote CI and merge verification are
blocked pending GitHub processing the push. No check was bypassed or
manually dispatched, and no PR setting was changed.

The PR remained open with its existing merge-method auto-merge enabled.
Three pre-existing review threads were still unresolved in that snapshot:
[test settings injection](https://github.com/MiddleAgedBanana/Brickson/pull/13#discussion_r4333758401),
[the withdrawn audit exception](https://github.com/MiddleAgedBanana/Brickson/pull/13#discussion_r4337694950),
and [the historical test count](https://github.com/MiddleAgedBanana/Brickson/pull/13#discussion_r4337694974).
The implementation/doc changes address their substance; the repository
still requires review-thread resolution. Their state was left to the
existing review/PR process, as requested. The next observer must check the
actual current remote head and required checks, not reuse the old head's
passing Unit result or this local verification as merge evidence.
