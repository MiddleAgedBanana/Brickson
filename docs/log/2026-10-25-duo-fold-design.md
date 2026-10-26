# Duo fold design: measured regions and windowing

*2026-10-25. Pull request #58 (`codex/duo-reserved-regions`). Codex.
Home implementation remains a draft; the capacity retry's full UI rerun fails one speech-wait case per family. Physical checks are deferred.*

## What changed and why

Continued Wave 3 item 6 after PR #56 merged. A temporary geometry-only
probe read the system's division and occlusion regions from the shared
Home/Settings adapter on app code `6d040d5`. It left the layout inputs
unchanged. The [13 region captures](../evidence/2026-10-25-duo-design/reservations.json)
supply the exact rectangles the first design draft lacked. Native
Device Hub input also reached both Split View panes. Home now uses typed
regions to allocate controls and a fixed phrase viewport around them.
Activity changes consume the same space; no hinge angle or device model
drives layout. Standard Buttons/stacks keep the existing logical order,
word floors and controls; no paging or Settings policy is implemented.

**Correction to this draft:** the earlier claim that item 6 needed an
owner decision about horizontal scrolling was premature. The measured
full-screen tall phrase viewport starts below the horizontal division,
so its content does not scroll through that fold. A fixed gap inside
scrolling content remains a counterexample where the division actually
intersects that viewport; it does not establish that this Home needs
pinned panes or earlier paging. That blocking claim is withdrawn. The
existing spacing, order and neighbour rules remain binding.

The initial Figma options and saved render show earlier candidates and a
generic counterexample. They are not measured region maps, a completed
Design gate or approval for a new scrolling policy.

## Commits

- `fab71b2`: initial fold candidates and synthetic scrolling concern.
- `23baaf0`: keep evidence outside the one-record log folder.
- `57a0ef3`: replace assumed blocker with measured system regions.
- `dfabb51`: merge current main and retain dated measurements.
- `1de1333`: specify the measured allocation and camera geometry.
- `8f4a997`: revised whole-point fold guides, Spec and native receipts,
  saved before implementation.
- `8b1365e`: first reserved-region implementation and regression tests.
- `951b193`: merge owner-merged PR #57, main `a14c709`; proposal/docs only,
  with app/test/script/project sources unchanged. R0 touch scrolling remains
  permitted; the R1 fewer-tiles proposal does not authorize paging code.
- `b267881`, `515e913`: retain direct system-speech controls and raw/curated
  trace hashes, without product audio changes.
- `bc72b73`: coherent-snapshot helper, six regression tests and later
  native/hosted receipts; product source remains unchanged.
- Correct the mode-word inset minimums, retain the failing reproduction,
  and record complete/selected UI and actual scroll measurements.
- `a622cec`, `9de5092`: commit the AX3 reference-capacity Spec and Figma
  drawings, then align their labels with shipped Basics, before the
  capacity-retry source commit.
- Starting app/test source: main `6d040d5`, including merged PR #56.
- Dated measurement source: [PR #55, `cb4c965`](https://github.com/MiddleAgedBanana/Brickson/commit/cb4c965),
  whose measurements used app code `8316743` before #56.
- Main `37c2e0b` (merged PR #55) is incorporated with a merge commit,
  preserving its dated QA record and the owner's stricter JSON-trial
  timing. That merge's app/test/script/project sources matched `6d040d5`.
- `87ddb14`: commit the scoped Spec and 84-state drawing gate before the
  first implementation commit. Later drawings explicitly enclose the raw
  fold to account for the native rounding finding below.
- The [initial host prototype](../evidence/2026-10-25-duo-design/candidate-geometry.json)
  remains historical. The [enclosed production export](../evidence/2026-10-25-duo-design/candidate-geometry-enclosed.json)
  uses the current allocator; it is pure geometry, separately compared
  with native snapshots. No generated project or temporary probe is committed.

## Verified

| Check | Result and evidence |
|---|---|
| Runtime region query | **Pass for capture.** Separate `.division` and `.occlusion` queries with `.includeInactive` returned frames, margins and activity. The full-screen division rectangle is the same at 180° and 130°, with different activity. Frames already include margins. This is measured geometry, not fold clearance. |
| Tall baseline and horizontal scrolling premise | **Prior blocking premise rejected.** Full-screen window 669×951; D begins at y 502 default, 612 AX4 and 660 AX5, below the division at y 455.5–495.5. [AX5 capture](../evidence/2026-10-25-duo-design/tall-ax5-baseline.png). |
| Four camera positions | **Captured.** Inactive camera rectangles differ across all four native rotations. The work file lists them. Product code must use those rectangles rather than a remembered camera corner. |
| Native left Split View | **Observed.** Window 469×669, bottom safe area 34pt, division clipped to x 455.5–469; no occlusion returned. Eight whole starter tiles show at default text. [Capture](../evidence/2026-10-25-duo-design/split-left-default.png). No keyboard or chain pass is claimed. |
| Native right Split View, default text | **Partial starter scrolling.** Window 469×669, reader 385×635, bottom/trailing safe areas 34/84pt. Six tiles are whole and the last two are partially clipped. [Capture](../evidence/2026-10-25-duo-design/split-right-default.png). Maximum scroll range was not measured. |
| Native right Split View, AX5 | **Whole-tile visibility fails in this sample.** The first row is partially visible and no whole tile is visible. [Capture](../evidence/2026-10-25-duo-design/split-right-ax5.png). Division x 0–13.5; status occlusion x 385–469, y 0–124 already lies in the trailing safe area. No inactive camera returned in this reversed pane. |
| Tall rotation after Split View | **Observed return to full screen** in both sampled arrangements: 669×951. No claim that Split View persists through rotation. |
| Same-app second-window attempt | **Inconclusive.** Selecting Brickson again produced a brief blank area and then App Library. No second Brickson window was established; neither success nor definitive system refusal is claimed. |
| Temporary XCTest windowing probe | **Skipped, not passed.** The icon existed but remained unhittable, stopping before Split View. Its [AX diagnostic](../evidence/2026-10-25-duo-design/windowing-probe-inconclusive.json) records differing application/window coordinate spaces. Native input subsequently worked. |

The Mac preview sometimes lagged the running simulator. Reopening Device
Hub with **Quit and Keep Simulators Running** refreshed it; separate
active-display captures and geometry confirmed the actual state. This
was a presentation recovery, not an app fix. No conclusion about the
cause of the skipped XCTest follows from it.

- The temporary Home diagnostic was removed byte-for-byte and the
  observation-only UI test was removed before the new ordinary gate.
  Neither diagnostic source is included in this PR.
- The existing native gate passed on identical app/test sources:
  Xcode 27.1 (27A9275), 13-inch iPad simulator, iOS 27.0; 740 tests,
  731 passed, 0 failed, the existing issue #19 skip and 8 strict expected
  failures; coverage 67.7%, String Catalog unchanged. Result:
  `build/TestResults/post-alarm-docs-unit/unit-destination.xcresult`;
  log: `/private/tmp/brickson-post-alarm-docs-unit.log`. That gate preceded
  the temporary diagnostic. The fresh full gate after restoration also
  passed: 740 ran, 731 passed, 0 failed, the existing issue #19 skip and
  8 strict expected failures, coverage 67.7%, String Catalog unchanged.
  Result: `build/TestResults/duo-probe-restored-unit/unit-destination.xcresult`;
  log: `/private/tmp/brickson-duo-probe-restored-unit.log`.
- Documentation checks: 45 tests passed; `git diff --check` passed.
  The five Python suites also passed on the same scripts for the
  preceding docs branch (251 tests); this branch's independent final
  verification is recorded in the PR.
- Figma review: all four option groups were rendered and visually read.
  The labels distinguish measured canvas sizes from unmeasured bands and
  proposed frames. The saved screenshot is
  `docs/evidence/2026-10-25-duo-design/duo-fold-options.png`.
  The new page is `73:2`, wrapper `73:3`, vertical proposal `74:139`,
  counterexamples `74:190`. Existing Figma nodes were untouched.
- Supporting images live in `docs/evidence/`, keeping only this PR's
  one Markdown record under `docs/log/`. The render's bytes are unchanged.
- The [updated measured-region render](../evidence/2026-10-25-duo-design/duo-measured-regions.png)
  was visually read after correcting the Figma page. New panel `84:2`
  maps all four camera positions, clipped Split View divisions and the
  tall baseline D starts; counterexample `74:190` is explicitly
  historical and synthetic. It changes 23 nodes created by this job and
  adds `84:2`–`84:95`; original Home pages remain untouched. The final
  Design gate was still open at that measured-panel step; the later
  scoped candidate drawings below complete it.
- The standalone candidate uses the existing font-validated metrics and
  unmodified ChainEngine. Across its 12 default/AX5 cases, independent
  half-point well samples and chain checks found no new Again points or
  Stop/well paths. The geometric bounds include tie allowance. A
  default-tall candidate that only enlarged B's gap widened the existing
  Again area; it was rejected. Its initial 25pt A return and 13.5pt AX5
  trailing extent were superseded by the outward-rounded production
  calculation: 27pt A return and 14pt AX5 extent. A-to-C and C-to-B retain
  their 12pt gaps at AX5; only B-to-D returns its 2pt growth. No known
  issue is widened or newly accepted by these calculations.
- The scoped Home drawing gate is complete at
  [Figma section 89:3](https://www.figma.com/design/zCYdh8hSJ9ZmrVhtealp8f/?node-id=89-3):
  84 states, 42 light and 42 dark, with the
  [saved overview](../evidence/2026-10-25-duo-design/candidate-screens.png)
  and [per-screen manifest](../evidence/2026-10-25-duo-design/candidate-drawings.json).
  Targets agree with the committed candidate within 0.000013pt; 480
  tile frames and 24 modeled Settings rows match exactly. The four
  AX5 full-screen Settings intersections are explicitly drawn as
  existing broader R0-13 gaps; no Settings clearance is claimed. The
  owner confirmed keeping the current rule and investigating another
  design. No original Home drawing was changed.
- Failing-first native reproductions ran before implementation: two
  expected assertion failures in
  `build/TestResults/duo-reservations-red/unit-destination.xcresult`.
  A later interior zero-width division reproduction also failed before
  its positive-area overlap fix, in
  `build/TestResults/duo-zero-division-red/unit-destination.xcresult`.
- The local implementation candidate's targeted native unit gate then
  passed on Xcode 27.1 (27A9275), iPhone Duo simulator, iOS 27.1:
  25 tests, zero failures/skips/expected failures. It covers all five
  validated font metrics with Bold Text off/on, the 12 drawn extremes,
  Home chains, unchanged Settings chains, final Back frames, the well
  envelope, existing message-reading bounds, grown libraries and
  warning reflow. Result:
  `build/TestResults/duo-reservations-growth-checked/unit-destination.xcresult`;
  log: `/private/tmp/brickson-duo-reservations-growth-checked.log`.
  This is unit evidence, not rendered UI or physical input proof.
- Before committing the completed drawing gate, the complete native unit
  suite also passed on that candidate, Xcode 27.1 (27A9275), iPhone Duo
  simulator, iOS 27.1: 765 ran, 756 passed, zero failed, existing issue
  #19 skip and eight strict expected failures; coverage 70.3%, catalog
  unchanged. Result:
  `build/TestResults/duo-reservations-full-unit/unit-destination.xcresult`;
  log: `/private/tmp/brickson-duo-reservations-full-unit.log`.
  Native rendering and broader generic-input review remain separate.
- The first native wide probe failed a strict reservation assertion:
  No and Conversation ended at x455.6667 against the raw division edge
  x455.5, despite the pure target ending at 455.5. The
  [initial native JSON](../evidence/2026-10-25-duo-design/native-wide-initial.json)
  and [active-display image](../evidence/2026-10-25-duo-design/native-wide-initial.png)
  retain that failure. The image is a later capture on the same initial
  source, not the JSON snapshot's instant. Planning now encloses positive
  divisions in whole points (455–496 here), while evidence and final
  strict overlap checks keep the unmodified API rectangle.
- Four additional reproductions failed before their fixes, then passed
  4/4: simultaneous camera intervals are order-independent; narrowed
  Get Attention recomputes its two-line floor; exterior-only occlusions
  retain the complete legacy result; fractional divisions receive the
  outward allowance. Results:
  `build/TestResults/duo-review-red/unit-destination.xcresult` and
  `build/TestResults/duo-review-focused/unit-destination.xcresult`.
- The post-fix full native unit gate passed: **769 ran, 760 passed,
  zero failed, one existing #19 skip, eight strict expected failures**;
  coverage 70.6% (6,898/9,769), catalog unchanged. Xcode 27.1 (27A9275),
  iPhone Duo simulator, iOS 27.1. Result:
  `build/TestResults/duo-enclosed-full-unit/unit-destination.xcresult`;
  log `/private/tmp/brickson-duo-enclosed-full-unit.log`. Three subsequent
  keyboard rows use the same allowance. The final `CI=true` run also
  passed with exactly the same totals and coverage, catalog current:
  `build/TestResults/duo-final-unit/unit-destination.xcresult`, log
  `/private/tmp/brickson-duo-final-unit.log`. Its result tree confirms all
  seven keyboard argument rows passed, including the three new Duo rows.
  Xcode counts the parent case once, so the provisional 772 expectation
  was incorrect. [Final source and argument receipt](../evidence/2026-10-25-duo-design/final-unit-results.json).
- Six selected native pose probes each passed one test with no failure,
  skip or expected failure: open wide/tall, both reverse rotations,
  reversed wide partially open, and closed. Native Hub rotations
  preserved the live display; RocketSim read the partial angle as
  90.07416534423828° before and after (distinct from the earlier 130°
  baseline). Each probe freshly launched default/AX5 in light/dark and
  retained one coherent ancestor-window snapshot per state. Results:
  `build/TestResults/duo-runtime-{wide-rounded,rotated-probe,wide-reverse,book-probe,tall-reverse,closed-probe}/ui-destination.xcresult`;
  logs `/private/tmp/brickson-duo-runtime-*.log`. These are selected
  diagnostics, not the complete UI suite.
- Independent [native frame audit](../evidence/2026-10-25-duo-design/native-frame-comparison.md)
  and [receipts](../evidence/2026-10-25-duo-design/native-frame-comparison.json):
  **144 captures**; 1,220 occupied button comparisons within 0.167pt and
  800 full tile comparisons within 0.25pt of the pure inner geometry;
  1,884 shared-state frames exactly equal. Strict raw-region checks
  allow no tolerance: no static target or geometrically cropped tile
  intersects a reservation. There are still 32 full AX tile/camera
  intersections beyond the AX5 D viewport; cropped clearance is not
  rendered clipping or Snap proof. Closed has no per-case pure export;
  native state/appearance checks and the separate 400-case complete
  legacy comparison cover different claims.
- All 12 default typing captures place Emergency, Yes, No, Speak,
  Get Attention, Phrases, Clear and Put Back above the full US
  English keyboard (29 keys tall; 32 wide). Tops: wide y405, tall y601, closed y374. AX5 Type
  is unavailable, so no AX5 inner keyboard claim follows. Typing's AX
  ScrollView container grows 42pt in upper-wide, tall and closed captures,
  and 58pt in lower-wide/book captures, while shared controls and full
  tiles stay fixed; its containment count includes covered tiles and is not
  visible capacity. Browsing shows 8 default/4 AX5 tiles open, and
  6 default/0 AX5 closed. The native audit lists trailing content
  extents, not measured maximum scroll distances.
- Settings Back is wholly within final native Phrases in 24/24 captures.
  Ten AX5 Settings row/fold intersection records remain, including the
  duplicate partial pose. All 20 illustrative model rows differ from
  native rows beyond 0.5pt; the drawing's 64pt navigation bar model is
  labeled accordingly. This Home PR preserves the Settings solver and
  PR #56's limits; broader R0-13 Settings/setup work is open.
- A [bounded host diagnostic](../evidence/2026-10-25-duo-design/transition-report.md)
  does **not** clear changed-window resting points. Under hypothetical
  coordinate hold/scaling, it finds added hazards against the captured
  legacy engine. Example: wide→tall, selected Conversation, quiet and
  browsing, point (454.5,300.5); both before maps are inert, legacy-after
  selects Emergency then settles, while candidate-after starts Get
  Attention. All four rule/pointer pairs reproduce this numerical-map
  example. Actual OS pointer mapping is unverified; no physical alarm
  was observed and no passing test accepts the new path. Activity-only
  geometry is stable in all ten scene/font cases. A separate 16-comparison
  [quarter-turn supplement](../evidence/2026-10-25-duo-design/quarter-report.md)
  removes that particular alarm example but still finds modeled additions:
  a tall→wide Get Attention point reaches Clear instead of an inert
  category. These transforms and dimmed-target eligibility are also
  unverified. Same-window Home state regressions remain separately green. Keep this PR a draft;
  this is neither a new policy exception nor completed folding safety.
- The complete standard UI run **failed on both families**, exit 65.
  The iPad case
  `LaunchTests.testLargestTextKeepsQuickControlWordsVisible` has failed:
  four 30-second Speaking waits in portrait AX5 light/dark. The completed
  iPad family reports 51 total: 45 passed, one failed, two existing
  opt-in skips and three strict expected failures. No rendered-word
  assertion failed in that case. Unmodified native
  [light](../evidence/2026-10-25-duo-design/standard-ipad-ax5-light-speaking.png)
  and [dark](../evidence/2026-10-25-duo-design/standard-ipad-ax5-dark-speaking.png)
  captures visibly retain Speaking and draw whole quick-control labels;
  [receipt](../evidence/2026-10-25-duo-design/standard-ipad-failure.json). The seven relevant
  speech/audio/launch-helper files match main `37c2e0b`; the failure is
  not yet attributed to the new layout. The first full-run result is
  retained alongside the bounded selected-case baseline comparison.
  The phone family reports 51 total: 42 passed, one failed, six existing
  skips and two strict expected failures. Its same case has the same four
  waits, with no rendered-word failure. Unmodified
  [phone light](../evidence/2026-10-25-duo-design/standard-iphone-ax5-light-speaking.png)
  and [phone dark](../evidence/2026-10-25-duo-design/standard-iphone-ax5-dark-speaking.png)
  captures also visibly retain Speaking. Root visually inspected both
  families at default/AX5 in light/dark; the quick-control words are whole,
  but that does not make either full suite pass. [Combined receipt](../evidence/2026-10-25-duo-design/standard-ui-results.json).
  The selected comparison on unchanged main `37c2e0b` then reproduced
  all four waits on the same iPad/runtime: one test ran, zero passed,
  one failed, no skip/expected failure. [Baseline receipt and captures](../evidence/2026-10-25-duo-design/speech-baseline-results.json).
  This establishes that the failure exists without the Duo change;
  it does not identify synthesis flags, callback/task state or audible
  output as its cause. No audio behavior or assertion was changed.
- GitHub CI at published `dfabb51`: both jobs passed. This does not
  verify later local design or implementation work.

## Final active-display review and paired pane

The [seven active-display captures and original-byte receipt](../evidence/2026-10-25-duo-design/active-display-results.json)
come from implementation `8b1365e`, using the normal app rather than the
black inactive display sometimes captured by XCTest. Root visually read
all seven. This is representative default/light and AX5/dark evidence,
not every appearance/pose combination.

- **Pass, sampled default open Home:** all eight starter tiles are whole
  in [wide Home](../evidence/2026-10-25-duo-design/active-wide-default.png).
- **Capacity fails at AX5:** [wide](../evidence/2026-10-25-duo-design/active-wide-ax5-dark.png)
  and [tall](../evidence/2026-10-25-duo-design/active-tall-ax5-dark.png)
  show four whole tiles and a clipped second row. Quick-control words are
  whole and Type is unavailable. These are not no-scroll passes.
- **Settings fold/footer failures remain:** the actual Family Setup row
  crosses the reserved band in [wide](../evidence/2026-10-25-duo-design/active-wide-ax5-settings.png)
  and [tall](../evidence/2026-10-25-duo-design/active-tall-ax5-settings.png)
  captures, with clipped explanatory text. Back remains whole. No new
  Settings row policy is introduced here.
- **Native left pane differs from the older pure fixture:**
  [AX5](../evidence/2026-10-25-duo-design/active-left-pane-ax5.png) shows no
  whole tile; [paired default](../evidence/2026-10-25-duo-design/active-left-pane-default.png)
  shows six whole tiles and two partially clipped. Safari is its generic
  Start Page, with no visited page or personal account content.
  A temporary geometry-only print queried the paired scene: 469×669,
  bottom inset34, inactive division x455.5–469 and newly returned inactive
  bottom occlusion (215.667,611,58,37). Earlier fixture8/0 counts excluded
  this occlusion; they are not the current paired pane's native capacity.
  The suspected wider475.5pt paired window was not observed. The print
  source was restored byte-for-byte; all nine final-unit source hashes
  still match, and the restored normal app built and was reinstalled.
  A [selected native pane probe](../evidence/2026-10-25-duo-design/paired-pane-results.json)
  passed one test with zero failures/skips/expected failures, with 24
  coherent snapshots across default/AX5 and light/dark. Every launch
  asserted a pane width below 600pt. Browsing D is (16,371,437,240) at
  default with 8pt trailing extent, and (16,572,437,39) at AX5 with 209pt
  extent. These are content extents, not maximum measured scroll travel.
  Default typing has keyboard top 405 (30 keys light, 34 dark); the core
  controls, Clear and Put Back geometrically clear it and shared frames
  remain fixed within the probe's 0.5pt native tolerance. This is not a
  functional Clear/Put Back action, full UI-suite pass or sound test.
  The summary retains an AVAudioSession runtime warning about synchronous
  activation; no compiler warning was suppressed. The observation-only
  test was removed, and all nine final-unit source hashes match again.

## Original Home checks on the current implementation

Before changing test helpers, the original six Home UI classes ran again
at the closed and full-screen open sizes on product/test source `1322630`.
The classes, portrait requests, idiom guards, floor checks and strict
expected-failure scopes were unchanged.

| Pose | Total | Passed | Failed | Skipped | Expected failures |
| --- | ---: | ---: | ---: | ---: | ---: |
| Closed, 466×678 | 19 | 14 | 1 | 2 | 2 |
| Open, 951×669 | 19 | 8 | 9 | 2 | 0 |

**Closed failed:** the default alarm's Dynamic Type audit reports
“Sounding” as partially unsupported, type65536. It is not the retryable
-56 error and no exception was added. The AX5 alarm case passed.
[Default issue capture](../evidence/2026-10-25-duo-design/closed-home-sounding-audit.png),
[AX5 capture](../evidence/2026-10-25-duo-design/closed-home-ax5-sounding.png),
[closed receipt](../evidence/2026-10-25-duo-design/closed-home-results.json).

**Open failed:** the inner window remains landscape despite the original
portrait requests. Independent live control/app queries also mix
951×669 control coordinates with a transposed669×951 application frame.
Those measurement failures do not clear the independent AX5 clipping of
tiles5–8 or the native Settings chain below. The original failures remain
retained, with no orientation or idiom assertion weakened.
[Active default preflight](../evidence/2026-10-25-duo-design/open-home-before-tests.png),
[open receipt](../evidence/2026-10-25-duo-design/open-home-results.json).

**Native Settings failure is pre-existing:** the standard Back in Family
Setup is actually on the right, centre(903,163), unlike the illustrative
leading-Back model. The existing ChainEngine reports
`Family Setup Back → Back to Talking → Get Attention (alarms)` by
centre/returnsToLook. This direct Family Setup start is outside the
accepted first-step-only scope. The selected comparison on unchanged main
`37c2e0b`, on the same open Duo/runtime, reproduces the exact path:
one test, zero passed, one failed, no skips/expected failures. Its result
summary lists the earlier orientation failure; the complete raw log also
retains the chain failure. This is not introduced by the Home change and
is not a new accepted exception. The [original active AX5/dark image](../evidence/2026-10-25-duo-design/native-family-back-right-ax5.png)
visually confirms the right-hand standard Back; it is a separate launch
from the AX5/light failing case. [Native frames and comparison](../evidence/2026-10-25-duo-design/native-settings-chain-results.json).
No physical alarm or Snap behavior was observed.

## Coherent test geometry

The native open check exposed an obvious helper error: `assertReachable`
compared a separately queried button with `app.frame`, whose orientation
can disagree on the inner display. The correction uniquely matches the
selected button's exact identifier/label pair in one snapshot and uses
its closest ancestor Window from that same tree. Missing/ambiguous
controls or a missing ancestor fail. Live existence/hittability, the44pt
floor, one-point allowance, original orientation checks, timeouts and
strict failure scopes remain unchanged. No product source changed.

A new pure shared resolver has six Swift Testing regressions, including
the transposed root, another keyboard window/nonzero origin, exact
identity and missing/ambiguous ancestor cases. A controlled first run
modeled the existing root-frame substitution in this new seam:
6 total,3 passed/3 failed. Applying ancestor propagation without changing
expectations then passed the full native gate:775 total,766 passed,
zero failed, existing issue#19 skip and8 strict expected failures;
70.5% app-line coverage, current catalog. The six new cases all passed.
This is a staged unit reproduction, not a claim these tests existed on
main. [Source hashes, results and limits](../evidence/2026-10-25-duo-design/coherent-helper-results.json).

Capture JSON schema2 accurately names `rootSnapshotFrame`, retains all
windows, and records each button's ancestor window. All buttons, including
keyboard buttons and genuine duplicates, remain in traversal order.
Old schema1 evidence is untouched. The selected live Duo run reports
3 total:2 passed,1 failed, no skips/expected failures. Default Home
reachability and typing/keyboard frame stability passed. The unchanged
AX5 Settings case still fails its portrait request and direct Family
Back alarm-chain assertion; no new geometry-matching error was reported.
The original-byte [Home](../evidence/2026-10-25-duo-design/coherent-open-default-buttons.json)
and [typing](../evidence/2026-10-25-duo-design/coherent-open-typing-buttons.json)
captures preserve a669×951 root but951×669 ancestor windows. Typing retains
29 button records across two of three windows, including9 keyboard-window
buttons; Key elements are a separate AX type, outside the unchanged
button-only schema. The adjacent text attachment also has29 buttons and
40 keys, not a simultaneous-snapshot claim. An AVAudioSession synchronous
activation warning remains unattributed and unsuppressed. The complete
standard family UI rerun is recorded separately; neither the unit pass
nor the two selected passes clears existing layout or input gates.

## Complete ordinary UI rerun after the helper correction, before the mode-width correction

On source `bc72b73824aae42a1d7dac42b434941ff8ee9e5b`, the complete ordinary UI
run finished on both families:

| Family | Total | Passed | Failed | Skipped | Expected failures |
| --- | ---: | ---: | ---: | ---: | ---: |
| iPad | 51 | 45 | 1 | 2 | 3 |
| iPhone | 51 | 42 | 1 | 6 | 2 |

Each sole failed case was
`LaunchTests.testLargestTextKeepsQuickControlWordsVisible`: four 30-second
Speaking waits at lines 126 and 145 in light and dark. No rendered quick-word,
geometry-matching or startup assertion failure was reported. The iPad's 64
schema2 captures contain 1,008 button records; the phone's 54 contain 845. All
recorded ancestor-window indices and frames are internally consistent. This
does not prove every control's containment or physical safety. The
original-byte AX5 [iPad
light](../evidence/2026-10-25-duo-design/coherent-ipad-ax5-speaking-light.png),
[iPad
dark](../evidence/2026-10-25-duo-design/coherent-ipad-ax5-speaking-dark.png),
[iPhone
light](../evidence/2026-10-25-duo-design/coherent-iphone-ax5-speaking-light.png)
and [iPhone
dark](../evidence/2026-10-25-duo-design/coherent-iphone-ax5-speaking-dark.png)
images show whole quick/mode/category words and emergency phrase labels while
visibly retaining Speaking. The
[iPad](../evidence/2026-10-25-duo-design/coherent-standard-ipad-results.json)
and
[iPhone](../evidence/2026-10-25-duo-design/coherent-standard-iphone-results.json)
receipts retain exact sources and assertions.

The phone's four Speaking assertions occurred at 21:46:41.572–21:48:23.777
UTC, before the separately isolated font build began at about 21:50 UTC. The
later one-worker font diagnostic and its Duo native case overlapped later
portions of the phone family. This chronology makes no attribution of UI
outcomes or cause to that concurrent diagnostic.

## Mode words at their rendered inset

The native app-hosted font probe found that Phrases and Type use 6pt on each
horizontal side, while their existing minimum-width test subtracted 4pt. Under
the existing measurement and WordFit slack, the measured target widths are at
least 89/97pt for Phrases and 60/65pt for Type, with Bold Text off/on. The
four declared minima now retain their prior conservative spare by adding 4pt:
Phrases 90/98pt and Type 62/67pt. Again and Speak keep their existing 4pt
insets. No font, shrink policy, target floor, order or placement rule changed.

Before changing the four minima, the corrected font tests and synthetic
camera-gap reproduction failed: 33 cases, 30 passed and 3 failed, with no
skips or expected failures. The failed cases were the actual-inset minimum
check, the camera-narrowed native word check, and the independent pure
acceptance check. The translated 58×37 camera inputs are synthetic allocator
fixtures, not observed platform poses. After the correction, the fresh full
native unit gate passed: 777 total, 768 passed, zero failed, one existing
issue #19 skip and eight strict expected failures; catalog current and 70.6%
app-line coverage (6,898/9,769).

The old/proposed host comparison is exactly equal for all 12 primary and 8
intermediate recorded geometries, including frames, allocations, Back,
D/capacities and sampled chains; both versions retain 400 legacy comparisons
with zero mismatches. The synthetic camera-gap cases now use the existing
camera-boundary fallback at widths 94/102pt instead of claiming that 86/94pt
fits. These results do not validate unmeasured windows, native Settings chains
or physical input.

The post-correction selected ordinary UI run covered **three cases per
family**. On each, the default light and dark Home accessibility audits
passed; the AX5 quick-word case failed only its four existing Speaking waits.
Each family therefore reports 3 total, 2 passed, 1 failed, no skips or
expected failures. No rendered quick-word or geometry/window-matching
assertion failure was reported. The iPad log retains ignored remote-element
hierarchy `kAXErrorServerNotFound` diagnostics, which are not recorded startup
assertion failures; no cause is inferred. **At this selected run, the complete
51-case suite had not been rerun after the minimum-width correction.**
The later hosted `35bed06` run passed, as recorded below. Capacity, native
Settings, changed-window mapping and physical-input gates remain open.

[Native font and red/green
receipt](../evidence/2026-10-25-duo-design/native-mode-word-results.json) and
[selected UI
receipt](../evidence/2026-10-25-duo-design/mode-inset-selected-ui-results.json)
retain hashes and exact scope. A [targeted chain
comparison](../evidence/2026-10-25-duo-design/mode-minimum-chain-results.json)
for only the two synthetic camera inputs scored 278,640 starts and 550,008
chains per version with the unchanged engine: zero hazards and matching
canonical activation traces. Starts correspond by normalized position within
their old/new controls; this is sampled Home-only evidence, not continuous
fixed-coordinate, Settings, platform mapping or physical-input proof.

## Actual phrase scroll travel in three native samples

A bounded native scroll probe on the isolated `bc72b73` source plus the four
measured Home mode-word minima now establishes actual travel in three
**Basics/light** samples: **82pt** in open wide AX5 (viewport16,485,835×126;
four whole tiles at both ends), **14pt** in open tall AX5 (16,759,637×150;
four whole tiles at both ends), and **8pt** in the paired default pane beside
Safari (16,371,437×240; six whole tiles at both ends). Each selected case
passed after three drags, actual uniform tile movement, aligned endpoints and
two unchanged settled gesture outcomes; the paired measurement interval
was15.655s (its complete test case16.999s). These are measured top-to-bottom
deltas of the same identified tile, not inferred trailing extents. [Complete
original measurement samples and source
hashes](../evidence/2026-10-25-duo-design/measured-scroll-results.json) retain
all96 full AX tile frames across12 settled samples. The frozen temporary
probe's SHA256 begins `8c071063`; the measured four-minimum HomeLayout source
is `93e3453c`. Neither probe is committed product code.

The paired preparation was observed through native UI: hold Brickson's Home
icon1.2s, select the visible Open in Split View action, select Safari, tap the
divider, then make two separately observed Rotate Right turns to the sampled
bottom-camera arrangement. A failed MobileBuild setup launch recovered after
one simulator restart; it does not establish a product cause. The attempted
pretest active screenshot did not produce a valid PNG and is excluded. The
earlier [paired default
image](../evidence/2026-10-25-duo-design/active-left-pane-default.png) is
representative, **not simultaneous measurement evidence**. These three
selected measurements do not cover every partial pose/camera position,
category, appearance or library. All full AX frames remain intact: the
separate audit's32 full tile/camera intersections are not erased or rechecked
by viewport cropping. Camera clearance, rendered clipping and Snap/physical
behavior are not established; original complete UI and capacity failures
remain. Restricted zoomed-phone AX4 is recorded separately below; its zero-height
AX5 grid remains unavailable, never0scroll.

## Restricted zoomed-phone AX4 travel and restoration

The restricted zoomed-phone AX4 range is now measured in one native simulator
sample: **329pt** of actual top-to-bottom travel in the320×693 window, with
the phrase viewport fixed at(16,651,288,7). The same Maybe tile moved from
y651 to322; all eight full AX tile frames translated uniformly, the last row
reached the bottom, and two further settled gestures left positions unchanged.
The selected probe passed one case with no failure/skip/expected failure; its
measurement interval was13.605594s. It used the recorded AX4 launch value
`UICTContentSizeCategoryAccessibilityXXL`, fresh Basics/light and a standard
drag beginning inside the7pt viewport before extending200pt upward within the
ancestor window. [Full original samples, source and evidence
hashes](../evidence/2026-10-25-duo-design/phone-zoom-ax4-scroll-results.json)
retain all32 full tile frames. The source is `bc72b73` plus the four measured
mode-word minima (HomeLayout SHA256 `93e3453c`); the temporary phone probe
hash begins `9952eecd`, with the original Duo probe unchanged.

**Whole-phrase access still fails:** zero complete tiles appear at both
endpoints. Root reviewed the unmodified
[top](../evidence/2026-10-25-duo-design/phone-zoom-ax4-scroll-top.png) and
[bottom](../evidence/2026-10-25-duo-design/phone-zoom-ax4-scroll-bottom.png)
captures: only a tiny blue tile edge is visible and Type remains
white/unavailable. Those images are adjacent state captures, not simultaneous
with the measurement snapshot. Scrolling a7pt viewport does not make it
usable. This is one category/appearance/window and not a complete UI, camera,
physical input or Snap pass; the previously observed zero-height zoomed AX5
grid was not gestured and remains unavailable, never0scroll.

Display Zoom restoration is verified separately. The operator observed the
original Default selection, the Larger Text system apply/restart, then
Default's Use Default confirmation. The existing
`HomeReachabilityTests/testEveryHomeStateAtDefaultTextInPortrait` subsequently
passed one case, zero failures/skips/expected failures. Its just-opened,
emergency-selected and phrase-spoken schema2 captures each independently show
both root and every button's ancestor window at**402×874**, confirming the app
returned to standard Zoom. Curated restoration metadata and original raw
hashes are included in the result JSON. The ordinary shared app and UI-test
runner were reinstalled on both owned simulators, which were then shut down;
these selected passes do not clear the complete UI Speaking-wait failure.

## Latest hosted startup failure

[CI at `1322630`](../evidence/2026-10-25-duo-design/ci-startup-1322630/README.md)
completed with unit769/0 failures, iPhone UI51/0 failures and iPad UI51/1
failure. The iPad's first test fails before alarm activation, after an
automation-session timeout and `kAXErrorServerNotFound`. Reviewed retained
media frames show a blank white Brickson canvas without Home controls.
The video does not span the full81.903-second case; its media samples are
not exact failure-time captures. No app crash/hang stack was recovered,
so the cause remains unresolved. This differs from the local
post-activation Speaking waits. The earlier three passing cold controls
already used the same12GB iPad model/runtime; another matching control
is not missing evidence. No timeout, retry or product audio change is
justified by these results.

## AX3 reference-capacity design addendum, 2026-10-25

The generic capacity audit found one recoverable intermediate-size
deficit: the recorded lower-camera wide input at AX3, Bold Text off,
changes from baseline shortfall 0 to reserved shortfall 4pt while its
category rows retain optional growth. The linked
[Spec and plan](../work/layout-engine.md#reference-capacity-growth-return-spec-and-plan-2026-10-25)
now require a guarded second pass through existing optional growth,
after the unchanged original selection and only from an already
issue-free, fully well-certified candidate. Use the fixed eight-phrase
reference before family-library reflow, preserve the selected gap
recipe, retain the original on ties and keep all residual failures
explicit. This is an existing-rule capacity retry; no gap, floor,
neighbour, status, mode, Back or Settings policy changes.

The smallest return in the existing search preference order is 2pt from
each category row, 65→63pt against a 61pt word floor. B's spanning targets
become 134pt; D moves from `(16,407,835,204)` to `(16,403,835,208)`,
so both 100pt tile rows and their 8pt gap fit. A/C/message/status/modes,
Back `(593.2,8,160.6,79)` and Type unavailability are unchanged.
The [geometry](../evidence/2026-10-25-duo-design/ax3-growth-geometry.json)
is a host drawing input, not a native observation. The
[compact checks](../evidence/2026-10-25-duo-design/ax3-growth-checks.json)
retain the unchanged full production well certificate, zero added
sampled Home-chain signatures versus baseline/current, zero Back-nearest
failures and unchanged message-reading shares. The exploratory generic
retry leaves 59 of 60 recorded space/font/Bold outputs exactly unchanged;
only the intended AX3 case changes. A count 8/24 comparison changes no
static geometry. No proposed host source is published or applied by
this design work.

[Figma section 122:3874](https://www.figma.com/design/zCYdh8hSJ9ZmrVhtealp8f/?node-id=122-3874)
and its [saved render](../evidence/2026-10-25-duo-design/ax3-growth-comparison.png)
add 16 before/after states in light/dark: browsing, alarm, retained
typing with the keyboard lowered, and a scoped Settings Back cover.
All 292 checked control, viewport, tile and Back rectangles agree with
the JSON within 0.0002pt. The
[manifest](../evidence/2026-10-25-duo-design/ax3-growth-drawings.json)
records all created/mutated IDs, 333 editable text nodes and no
image-filled nodes. Original 84 drawings and original Home pages are
unchanged. The first composition exposed black fallback paints for
aliased gray tokens and missing dark chrome context; only these new
nodes were corrected to existing palette fallbacks and Apple chrome
modes, then the revised render was visually inspected.

Before the capacity-retry code commit, a copy review found generic
word-fit fixtures displayed with Basics selected. Only the new section's
96 phrase instances were corrected to Basics' exact shipped order in
`Brickson/Resources/StarterPhrases.json` (source hash and slot order in
the manifest); all 292 bound rectangles remain unchanged. The corrected
composition PNG was visually inspected. Original 84 drawings and global
component sources remain unchanged; no native typography pass is claimed.

SF Pro remains a connector limitation: a fresh Semibold 20 text probe
returned width 0 and `hasMissingFont=true`. The new drawings explicitly
use the existing documented Inter stand-in and default-floor label
sizes. Editable geometry/appearance inspection passed; a native AX3
SF fitted-typography pass is not claimed. Settings body/row geometry is
not reconstructed here. Full native word/frame checks, unchanged
complete safety suites and applicable UI gates remain required.

The [bounded negative results](../evidence/2026-10-25-duo-design/ax3-growth-capacity-limits.json)
remain visible: tall AX5 has a 14pt current deficit and at least 12pt
missing with minimum region gaps and binding 8pt internal spacing.
The 1pt B/1pt D gap hypothesis is outside the current Spec and is not
selected. Wide AX5 has no optional height in the measured inputs and
retains 66/82pt total shortfalls. No universal impossibility, AX5 fix,
new scrolling exception, physical Snap or changed-window proof follows.

This Spec/plan and drawing addition was committed in `a622cec` and
`9de5092` before the capacity-retry source commit. No production/test
source or simulator was changed by the drawing work; root's independent
native unit receipt is a separate pre-commit requirement.

Before this design-only gate commit, root's fresh full native unit run
passed on unchanged `35bed06` app/test sources: **777 total, 768 passed,
zero failed, one existing issue #19 skip and eight strict expected
failures**. The catalog is current; coverage is 70.5% (6,885/9,769).
The script selected a 13-inch iPad Pro (M5), iOS 27.0; recorded Xcode 27.1
(27A9275). Result:
`build/TestResults/pr58-growth-design/unit-ipad.xcresult`; retained raw
log: `/private/tmp/brickson-pr58-growth-design-unit.log`. The script shut
down the simulator it booted. This validates the unchanged source before
the docs commit, not an implementation of the proposed capacity retry.

## AX3 growth retry: native receipts and gates

The guarded capacity retry is implemented after the original selection,
only from an issue-free, fully well-certified layout with new fixed-eight
reference excess. It returns optional growth in the existing half-point
order, preserves the selected gap recipe, retains the original on ties
and uses the best strict improvement if the target cannot be reached.
Family-library reflow follows that choice; no floor, spacing, status,
neighbour, mode, Back or Settings policy changes. The compact
[60-input host comparison](../evidence/2026-10-25-duo-design/ax3-native-host-comparison.json)
retains 59 exact matches and only the intended AX3 change; the
[count 8/24 comparison](../evidence/2026-10-25-duo-design/ax3-native-grown-library-comparison.json)
retains zero static geometry changes. These are private-proposal host
comparisons, separately scoped from production/native proof.

The first unparenthesized Swift Testing filter ran zero tests and was
rejected. The correctly matched
`cameraCapacityReturnsOnlyTheOptionalGrowthItNeeds()` ran **one test and
failed** before implementation. Its camera cases cover 4/5/6pt deficits
and an unattainable case retaining 8pt shortfall. Removing the retry or
returning all growth instead of the minimum would break its expectations.
The fresh full native gate then passed: **778 total, 769 passed, zero
failed, one existing issue #19 skip and eight strict expected failures**;
catalog current, coverage **71.2% (7,027/9,876)**. Recorded Xcode 27.1
(27A9275), 13-inch iPad Pro (M5), iOS 27.0. Result:
`build/TestResults/pr58-growth-green/unit-ipad.xcresult`; raw logs:
`/private/tmp/brickson-pr58-growth-red.log`,
`/private/tmp/brickson-pr58-growth-red-matched.log` and
`/private/tmp/brickson-pr58-growth-green.log`. The
[compact source/gate receipt](../evidence/2026-10-25-duo-design/ax3-native-results.json)
retains full hashes, including HomeReservedLayout `8323e309` and unchanged
HomeView `60c8edd4`. All 251 Python checks passed (45 docs, 124 hooks,
7 site, 54 runner and 21 selector); docs and the diff check were repeated
after this evidence insertion.

Before this retry, [hosted Tests at `35bed06`](https://github.com/MiddleAgedBanana/Brickson/actions/runs/40244703180)
passed: unit 777 total, 768 passed, zero failed, one existing skip and
eight strict expected failures; iPad UI 51 total, 46 passed, zero failed,
two skipped and three expected failures; iPhone UI 51 total, 43 passed,
zero failed, six skipped and two expected failures. Both first default
Get Attention and AX5 word/Speaking-wait cases passed. Earlier failures
remain historical evidence with causes unresolved. **The new full
standard iPad/iPhone UI run on the capacity-retry source completed with
exit 65:** iPad **51 = 45 passed / 1 failed / 2 skipped / 3 expected**;
iPhone **51 = 42 / 1 / 6 / 2**. Each failed only
`LaunchTests/testLargestTextKeepsQuickControlWordsVisible()`, with four
30-second Speaking waits at lines 126/145 in light/dark; case durations
146.055s and 144.969s. No other unexpected assertion failed. First default
Get Attention/startup and ordinary typing cases passed. These results
do not identify the retained speech or intermittent startup cause.

The [complete current UI receipt and original-byte light/dark images](../evidence/2026-10-25-duo-design/ax3-growth-ui-results.json)
keep both families separate from the selected Duo probe. Bundles:
`build/TestResults/pr58-growth-ui/ui-ipad.xcresult` and
`build/TestResults/pr58-growth-ui/ui-iphone.xcresult`; complete script log:
`/private/tmp/brickson-pr58-growth-ui.log`. The failure output retains the
unformatted xcodebuild stream. The script shut down both simulators it
booted; neither a wait nor a test was weakened or retried.

The temporary fullscreen lower-camera wide Duo AX3 native probe passed
**two selected light/dark cases**, iOS 27.1. The unchanged initial probe
failed both because its retained Split View ancestor was 469×669, not
the required 951×669. Root restored fullscreen with the native divider,
then ran the same probe; both failed-pose receipts remain private.
Neither the later pass nor the unit gate validates that smaller pane or
a full Home UI suite.

There are **10 coherent samples: eight Home and two root Settings
Back-only**. The same-snapshot control ancestor is 951×669 while the
root is transposed 669×951. Every Home sample has D `(16,403,835,208)`,
eight whole 100pt Basics tiles, Type unavailable, zero keyboards and no
storage warning. All 64 full tile instances lie within D/window. Native
tile-model differences are at most 0.167pt under the 0.5pt model
comparison. **Strict overlap has no tolerance:** 328 target/raw-region
pairs have zero overlaps. Checks reuse the previously queried division
`(455.5,0,40,669)` and camera `(215.6667,611,58,37)`, not a new API query.
D spans the division; its individual target lanes avoid it and the last
row ends at camera y611. All 120 shared-state and 83 cross-appearance
frame comparisons match exactly; D is unchanged.

Root Back `(593.3333,8,160.3333,79)` is contained in and centred over
Phrases, within 0.267pt of its unchanged model. Back returns Home and
its centre is nearest Phrases under both existing helper rules. This
is not a complete Back-surface, Family Setup or chain proof. Two
AVAudioSession activation warnings remain; the alarm stand-in is silent,
so only app state is checked.

Reviewed active [light](../evidence/2026-10-25-duo-design/ax3-native-light.jpg)
and [dark](../evidence/2026-10-25-duo-design/ax3-native-dark.jpg) images show
whole eight Basics phrases and quick/category/mode labels. They are
optimized 800×562 JPEGs taken separately from coherent AX samples;
their pixels establish no native point-size or target-floor proof.
The [image manifest](../evidence/2026-10-25-duo-design/ax3-native-images.json)
records original-byte equality and capture hashes. All ten original
XCUIScreen PNGs remain byte-identical inactive-display captures, with no
per-state or appearance proof.

Manual typing records a separate **automatic-dismiss failure**. The
confirmed [tall keyboard](../evidence/2026-10-25-duo-design/ax3-native-tall-typing-light.jpg)
partly covers Put Back; after native rotation,
[wide typing](../evidence/2026-10-25-duo-design/ax3-native-wide-typing-light.jpg)
still shows the keyboard. The later
[eight dimmed whole tiles](../evidence/2026-10-25-duo-design/ax3-native-wide-manually-lowered-light.jpg)
follow explicit Device Hub keyboard lowering, never an automatic pass.
An earlier CLI tap reported success without confirmed Type activation
and is not a typing pass.

A fresh app-only build from all **87 app files verified against
`35bed06`** reproduced visible persistence after normal tall Type
activation and native rotation. The
[baseline receipt](../evidence/2026-10-25-duo-design/ax3-native-baseline-results.json)
retains build/product and separate tall/wide image hashes. The
show-keyboard preference was restored before the fresh launch. The
build succeeded with a metadata-extraction warning; it is not a unit/UI
receipt. Visible persistence occurs on both uninstrumented baseline and
candidate, with no causal mechanism established.

The [nine-event boolean trace](../evidence/2026-10-25-duo-design/ax3-native-trace-results.json)
is **baseline `35bed06` only**, using a temporary private HomeView overlay;
the candidate has no binding trace. Availability changes true→false.
The getter immediately after the false write remains true, then the
parent FocusState callback reports true→false with availability false.
No later focus-true event or field task is in the retained markers.
The separate settled wide image still shows the keyboard. This does
not establish a failed setter or an SDK defect: instrumentation can
perturb scheduling and logs/images are not atomic binding/keyboard
proof. No focus or keyboard fix was applied.

The operator's cleanup receipt reports stopping the traced app,
successfully installing the uninstrumented capacity candidate, removing
the temporary runner and shutting down only the task-owned Duo. Shared
and restored-candidate HomeView/Layout hashes match; receipt/product
hashes are retained. No post-cleanup launch check is claimed. Current
ordinary UI testing is separate. AX5 capacity, native Settings chains,
changed-window mapping and deferred physical checks remain open.

A bounded source/design review found no additional supported allocation
within the current contract after checking hybrid C/B rows, asymmetric
or staggered phrase rows, a shaped D and reclaiming disabled-control
space. This is not a universal impossibility proof or a new optimizer
run. The current AX5 78/100pt tile heights are conservative word-fitting
tiers, distinct from the active touch profile's 44pt physical floor;
AX5 is a text size, not a separate physical profile. No floor or row
policy changed. Native tier-tightness calibration is optional evidence,
not a required gate or demonstrated repair; no further sweep was run.

## Not verified

The [later speech-status diagnostic](../evidence/2026-10-25-duo-design/speech-diagnostic/README.md)
reproduced the separate post-activation timeout: 232 watchdog checks over
239 seconds, progress delivered through the matching token, and underlying
speaking/unpaused flags with no finish/cancel callback. Three direct AV
controls reproduced the raw state without Brickson's speech wrapper.
This narrows attribution without establishing an SDK defect, identifying
the cause, explaining the historical blank first launch or making the
full UI gates pass. Both source diagnostics were removed byte-for-byte;
no production audio behavior or wait assertion changed. The control app
was removed and only the owned simulator booted for it was shut down.

- A green complete ordinary UI run on the capacity-retry source: each
  family completed 51 cases with one failed AX5 Speaking-wait case and
  four failed waits. Earlier local failures, also
  reproduced on unchanged main, remain recorded above; later hosted
  `35bed06` passed. No cause or speech fix is established. Duo active
  captures are separate from standard phone/iPad captures.
- Automatic software-keyboard dismissal after tall-to-wide rotation:
  visible persistence reproduces on baseline and candidate. The
  baseline-only binding trace does not identify the cause or validate
  a fix; later manual keyboard lowering is not an automatic pass.
- All post-change Split View arrangements, all window sizes,
  verified platform pointer mapping across changed windows and a successful
  second Brickson window. Hypothetical mappings already expose added paths
  in the diagnostic above; that gate has not passed. Native navigation/wrapping for all Settings/setup states is
  broader R0-13 work, with the AX5 intersections above still present.
- Full AX tile camera clearance, rendered clipping and scroll travel
  outside the three measured Basics/light samples. Physical Snap to Item, folding/input comfort, sound, Phone
  handoff and the camera dark-area match need a real mounted device.
  The owner deferred physical testing.
- The JSON project trial still waits for released Xcode 27.2 and its
  first fix release; nothing is converted. Rechecked on2026-10-25:
  [Apple releases](https://developer.apple.com/news/releases/) and
  [system requirements](https://developer.apple.com/xcode/system-requirements/)
  list27.2RC and released27.1. The requested trial condition is unmet;
  XcodeGen remains in use.

## Follow-ups

- The owner's 2026-10-26 continuation narrows this same PR to fold/camera
  allocation and the measured AX3 capacity correction, with a main merge
  incorporating #59 and the drag investigation/repair below. Marking that scope
  ready requires current-head CI. The broader AX5, native Settings,
  changed-window and physical-input gates remain open release work; no
  exception to a layout or safety invariant is accepted here.
- Retain the existing fold decision. Reassess a policy decision only if
  a measured supported window requires changed order or neighbours.
  The generic counterexample alone did not establish that need.
- A side-by-side status alternative was rejected before implementation:
  docs/DECISIONS.md, "Home version 0 is a stand-in", reserves the line under
  the message and two message lines. Changing that placement is outside
  the owner's keep-the-current-rule direction. AX5 capacity remains an
  explicit failure rather than a silent rule change.
- A [bounded joint-mode narrowing study](../evidence/2026-10-25-duo-design/mode-feasibility.md)
  retains Back centred over Phrases and the existing status position.
  It removes the observed Family Back-centre chain, but one-line word-floor
  widths still fail from Back's top edge. Smaller two-line widths are
  hypotheses without native Back-word/Bold fitting or complete chain proof;
  no guessed minimum or selective device rule was adopted. A Back-only
  leading move also violates the centred-Back decision and exposes Again
  at a lower corner. Neither is a validated replacement design or a new
  rule exception. The current placement rule remains in force.
- Keep controlled physical-input checks deferred and do not present
  simulator geometry as a completed R0-13 release gate.

## PR #58 continuation and drag investigation, 2026-10-26

The continuation stays in its own worktree and updates the existing PR.
Its remote branch was already checked out elsewhere, so the local
`codex/finish-duo-drag` branch tracks it without changing that other
checkout. Main `e568aa7` (#59) is incorporated by a merge, preserving both
sets of HANDOFF observations. No new PR, rebase, main push or PR merge is
part of this continuation.

### Earlier failures and the coordinate defect

The earlier chat's two failed tests used an **unselected private AX5
alternative**, not the shared app at `6b1d4e8`. Both recorded no Speaking
before/after the pristine accessibility audit and Speaking after their
gutter gesture. The light case's persistent message became "I'm not
finished." The opposite dark case failed the same quiet-screen assertion.
Those failures remain failures; later passing long gestures alone did not
explain them.

The [recovered original gesture](../evidence/2026-10-26-pr58-drag/original-gutter-gesture.txt)
pressed for 0.05s at 90% of the live phrase ScrollView's height in the
first column gutter, dragged slowly to 10%, then held for 0.1s. Calling
the gutter "inert" was an unsupported test assumption. The earlier
coordinate controls were separate launches, not the actual post-audit
input, so the opposite control's matching points cannot certify the later
gesture. On the shared app, a new first-pose check rejected an actual
180-degree coordinate disagreement before it could inject input. That is
a real test-coordinate defect, but it does not by itself attribute either
original dispatch.

The private `/private/tmp` folder initially appeared unavailable, so the
first phase recovered only a source excerpt and receipts from the earlier
chat. That source-availability limit is superseded by the exact recovery
and bounded counterfactual below. The original embedded four-model JSON
remains unavailable; no full original flow/suite rerun is claimed.

### Initial checks that did not expose the app bug

The app was unchanged during these checks. The first
[receipt set](../evidence/2026-10-26-pr58-drag/results.json) is a frozen
record of that phase, including its then-unavailable-source status; it is
not the final diagnosis or verification of the later fix.

| Check | Result and meaning |
|---|---|
| Original gutter gesture, unchanged app, iPad default/light | PASS: no speech. |
| Tall Duo, first orientation, default/light | FAIL before input: intended gutter start `(162.667,873.7)` resolved to `(506.333,77.3)` in a `669×951` window. No drag was injected. [Coordinate receipt](../evidence/2026-10-26-pr58-drag/rejected-coordinate.txt). |
| Opposite tall Duo, default/dark, original gesture | PASS: coordinates matched, no speech. |
| Opposite tall Duo, default/dark and AX5/dark, full audit then original gesture | PASS: both cases, no speech. |
| Initial AX5/light and dark cases, gutter and long tile-start paths | PASS: both cases after the full audit, no speech. These did not cover an 80pt drag released inside its starting tile. |
| First expanded default cases | FAIL before input only because exact CGRect equality rejected `556.0000000000001` against `556`. Replaced with the existing half-point native rounding allowance; no speech or coordinate-dispatch assertion was removed. |
| Corrected expanded default/light and dark cases, gutter and long tile-start paths | PASS: both cases after the full audit, no speech. |

Measured with the current released Xcode, recorded as Xcode 27.1
(27A9275), XcodeGen 2.46.0; iPad Pro 13-inch (M5), iOS 27.0; Duo inner
display open/flat, tall `669×951`, iOS 27.1, standard Zoom, English,
default and AX5 text, light/dark as listed. Phrases mode has no keyboard.
XCTest's Duo captures may show the inactive outer display; they are not
rendered Home or blank-canvas evidence. The rejected input has no app
screen defect to photograph; its coordinate receipt is the evidence.
Native bundles and captures are kept under
`build/TestResults/drag-*` and `build/drag-*-attachments`.

### Shared-app failing reproduction and selected repair

A shorter, verified **80pt tile-start drag** exposed the shared-app bug.
The drag began and ended inside the same fitting "Wait a moment, please."
tile, and releasing it spoke that phrase. The test used fresh storage,
no prior speech, the unchanged full accessibility audit and coordinates
checked against the coherent window/viewport before injection. This is
app behavior beyond the separate coordinate problem: an ordinary attempt
to scroll could activate the starting phrase.

| Candidate/check | Result |
|---|---|
| Shared app, verified 80pt tile-start drag before the fix | **FAIL**, 0 passed / 1 failed in `build/TestResults/drag-short-red-window/ui-destination.xcresult`. The [recording's last frame](../evidence/2026-10-26-pr58-drag/drag-spoke-before-fix.png) shows the persistent phrase and Speaking; it is not presented as an exact assertion-time image. |
| Remove `scrollDisabled` only, retaining `.basedOnSize` | **FAIL**, `drag-short-green`: the short-drag case still failed; the two existing slow-press cases passed. Removing the disable alone was insufficient. |
| Empty TapGesture experiments outside/inside the scroll content, with pan disabled/enabled | **FAIL** for the measured drag; all were discarded. No gesture experiment enters the shared app. |
| Remove `scrollDisabled` and change `.basedOnSize` to `.always` | **PASS**, initial selected shared run: the default/light drag case and both existing `SlowPressTests` cases, 3 passed. The final expanded selections below pass all 7 cases on each of Duo/iPad/iPhone; the full final-source unit gate also passes. Complete ordinary local UI/verifier results and new-head hosted CI remain separate. |

The selected app change is only those two phrase-ScrollView modifiers.
It retains the same standard labelled Buttons, eager grid, ScrollView
identity, `.disabled(isTyping)` and fixed viewport cap. It changes no
layout-engine output, static Home frame, floor, column, ordering or
capacity rule. Native pan handling remains available when all tiles fit.
Only phrase content can bounce transiently during a deliberate touch
drag, and fitting content must settle to the original frames. No timer,
custom gesture, pointer handling, input threshold or app input guard was
added. This does not identify an internal framework implementation or
establish physical-input behavior.

Apple's [coordinate documentation](https://developer.apple.com/documentation/xcuiautomation/xcuielement/coordinate(withnormalizedoffset:).md)
defines screenPoint from the element frame and normalized offset. Its
[scrollDisabled](https://developer.apple.com/documentation/swiftui/view/scrolldisabled(_:).md),
[bounce modifier](https://developer.apple.com/documentation/swiftui/view/scrollbouncebehavior(_:axes:).md)
and [always](https://developer.apple.com/documentation/swiftui/scrollbouncebehavior/always.md)
documentation were read before the repair. The independent
[SwiftLee example](https://www.avanderlee.com/swiftui/scrollview-bounce-behavior/)
demonstrates content-size-based and always bounce, but does not prove
Button cancellation. The native red/green experiment establishes that
result. The initial decision against a speculative modifier change is
superseded by this failing reproduction and its isolated repair.

### Recovered original source and counterfactual

All **87 original private App files** were recovered and verified against
their historical hashes: 83 match shared baseline `6b1d4e8`; four contain
the intended private AX5 changes. The recovered original HomeView hash is
`805ab978f65ac6f35f2dfd107b781b46d21ef8e07d1e109a7ac9d230e8dc28cd`.
The [source and result receipt](../evidence/2026-10-26-pr58-drag/original-counterfactual.json)
records the exact before/counterfactual hashes and restoration. After
restoration, the private source was preserved in ignored
`build/recovered-private-source.tar.gz`; every one of the 87 original App
hashes was verified inside that archive. Its SHA256 is
`93a2803015269e312eec44a767c4061d152842641cd5f053f4b877576fcc174c`.
The two result bundles are retained separately at
`build/TestResults/original-drag-red/ui-destination.xcresult` and
`build/TestResults/original-drag-green/ui-destination.xcresult`.
Archiving the duplicate historical tree also removes its old Markdown
and test fixtures from recursive documentation discovery without changing
the checker; the root's post-archive documentation check passes 45 tests.

On that original App source, fresh AX5 direct launch without an orientation
setter, the full audit, a matching tall viewport **164pt high with eight
whole tiles**, and verified coordinates reproduced the original gutter
failure: **0 passed / 1 failed**, the same quiet-screen assertion. Changing
**only** the two scroll modifiers above then passed the light and dark
cases: **2 passed / 0 failed**, each exercising the original gutter and
80pt tile-start paths. All 87 private App hashes were restored afterward.
The repair therefore addresses the reproduced original gesture as well
as the shared-app short drag; the coordinate defect is not the whole
explanation.

This is a bounded matching-geometry reproduction, not a claim that the
unavailable embedded four-model JSON or the original test's whole flow
was rerun. The private alternative is not selected, promoted or verified
by a complete suite. Its capacity/layout design remains outside this PR.

### Regression scope and remaining gates

The five-case `PhraseDragTests` class uses real Home, fresh test-only
storage and no prior speech. Its four text/appearance cases exercise both
the original gutter path and an 80pt tile-start path after the unchanged
full accessibility audit. Geometry comes from one snapshot on each side,
relative to each target's ancestor window; live window origins are
accounted for separately and live-coordinate disagreement fails before
input. The existing half-point native allowance handles rounding, not
misdirected input.

Persistent-message checks are restricted to `homeRegion.message` and
include all eight phrases plus Yes/No, alongside Speaking/Sounding, so
finished speech or a tile's own text cannot hide or imitate activation.
After each silent drag, static Home frames must match; when all eight
tiles fit, their settled frames must match too. A subsequent first tap
must speak, and a separate fresh AX5 1.5s held press must speak through
the ordinary Button action. A regression in cancellation, first tap/hold
or settled fitting frames must fail the corresponding test.

The **final shared-app Duo selected run passes 7/7**, with zero skips or
expected failures: all five `PhraseDragTests` cases and both existing
`SlowPressTests` cases. This includes the fresh AX5 1.5s hold, the first
ordinary tap after each silent drag, static-control frame comparisons and
settled tile-frame comparisons where all eight tiles fit. The run uses
the open/flat tall Duo window, default/AX5 text and light/dark as selected
by the tests, with no software keyboard. Bundle:
`build/TestResults/pr58-final-duo/ui-destination.xcresult`; raw log:
`/private/tmp/brickson-pr58-final-duo.log`. This result is stronger than
the initial three-case selection but is not a complete ordinary UI run.

The same **seven selected regressions also pass on each standard iPad and
iPhone**, with zero failures, skips or expected failures. Their bundles
are `build/TestResults/pr58-final-ipad/ui-destination.xcresult` and
`build/TestResults/pr58-final-iphone/ui-destination.xcresult`. These runs
exercise default/AX5 text and light/dark as selected by the tests; they do
not substitute for the complete ordinary UI suites. Complete ordinary
local UI/verifier results and new-head hosted CI remain **pending** at
this checkpoint. Current-head PR checks are authoritative for the review-
readiness gate.

An auxiliary RocketSim AX bridge probe returned no rows and a zero-sized
canvas on both reads, so AXPress was **not attempted**. This leaves that
activation path unverified; it is not evidence that the app displayed a
blank canvas. The XCTest passes above and physical-input limits below
remain separate from that unavailable bridge observation.

The pre-repair full native unit gate passed **778 total = 769 passed /
0 failed / 1 existing #19 skip / 8 strict expected failures**, catalog
current, **71.2%** app-line coverage. This remains baseline evidence.
The **full final-source unit gate now also passes 778 total = 769 passed /
0 failed / 1 existing #19 skip / 8 strict expected failures**, catalog
current under `CI=true`, with **71.1% (7,026/9,875)** app-line coverage.
Bundle: `build/TestResults/pr58-final-unit/unit-destination.xcresult`.
The selected UI passes above and final unit pass do not pre-empt the
complete ordinary local UI/verifier results or new-head hosted CI.
Current-head hosted CI remains required before marking #58 ready.

The private AX5 alternative, automatic keyboard dismissal, Put Back
placement and startup-flake cause/fix stay open in HANDOFF and are not
implemented by this PR. No new future-profile scrolling exception is
accepted: invariant 11 and the physical target floors remain binding for
dwell, switch, head and gaze profiles. The touch-profile pan check does
not verify those profiles, sound, physical Touch Accommodations, Snap to
Item, every Duo pose, changed-window pointer mapping or release readiness.
The public accessibility page's existing high-level claims remain true;
no physical-input claim or page wording changes with this repair.
