# Duo fold design: measured regions and windowing

*2026-10-25. Pull request #58 (`codex/duo-reserved-regions`). Codex.
Home implementation remains a draft; standard UI gates failed. Physical checks are deferred.*

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

- A green complete ordinary UI run: both local families fail the
  Speaking-wait case, also reproduced on unchanged main. The cause is
  unestablished. Duo active-display captures are separate from the
  inspected standard phone/iPad captures.
- All post-change Split View arrangements, all window sizes,
  verified platform pointer mapping across changed windows and a successful
  second Brickson window. Hypothetical mappings already expose added paths
  in the diagnostic above; that gate has not passed. Native navigation/wrapping for all Settings/setup states is
  broader R0-13 work, with the AX5 intersections above still present.
- Full AX tile camera clearance, rendered clipping and maximum scroll
  travel. Physical Snap to Item, folding/input comfort, sound, Phone
  handoff and the camera dark-area match need a real mounted device.
  The owner deferred physical testing.
- The JSON project trial still waits for released Xcode 27.2 and its
  first fix release; nothing is converted. Rechecked on2026-10-25:
  [Apple releases](https://developer.apple.com/news/releases/) and
  [system requirements](https://developer.apple.com/xcode/system-requirements/)
  list27.2RC and released27.1. The requested trial condition is unmet;
  XcodeGen remains in use.

## Follow-ups

- Retain this as the one draft item 6 PR, with full source provenance
  and exact results, including failures. Complete the open UI, capacity,
  native Settings and changed-window input gates before calling it ready.
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
