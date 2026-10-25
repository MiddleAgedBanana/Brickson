# Duo fold design: measured regions and windowing

*2026-10-25. Branch `codex/duo-reserved-regions`. Codex. Design draft;
no implementation.*

## What changed and why

Continued Wave 3 item 6 after PR #56 merged. A temporary geometry-only
probe read the system's division and occlusion regions from the shared
Home/Settings adapter on app code `6d040d5`. It left the layout inputs
unchanged. The [13 region captures](../evidence/2026-10-25-duo-design/reservations.json)
now supply the exact rectangles the first design draft lacked. Native
Device Hub input also reached both Split View panes. No fold-avoidance
implementation or new exception is included.

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

- This design record, the current work-file continuation and affected
  HANDOFF/ROADMAP/DESIGN lines.
- Starting app/test source: main `6d040d5`, including merged PR #56.
- Dated measurement source: [PR #55, `cb4c965`](https://github.com/MiddleAgedBanana/Brickson/commit/cb4c965),
  whose measurements used app code `8316743` before #56.

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
  Design gate stays open.
- GitHub CI at the pushed `23baaf0`, 10:18 a.m. EDT: unit tests passed;
  UI tests still running. This does not verify these later local docs.

## Not verified

- No reserved-region implementation or new fold-layout regression suite.
  The ordinary unit gate is not a fold-layout safety result.
- Universal fold/camera clearance, floors, whole words, keyboard fit and
  complete Home/Settings held-activation chains for the proposed lanes
  and resized windows. The exact rectangles are now recorded; the camera
  dark-area match still needs a real device.
- A successful second Brickson window or the cause of its inconclusive
  attempt; Split View persistence through rotation.
- Live folding/input comfort, sound, Phone handoff and controlled
  on-device input. Physical testing remains deferred until a mounted
  setup is ready.
- The JSON project trial: it still waits for released Xcode 27.2 and its
  first fix release; nothing is converted.

## Follow-ups

- Finish Spec/Figma from the measured full-screen and clipped Split View
  regions, then failing reproductions and implementation/chain/UI gates.
  Keep this as the one item 6 PR.
- Retain the existing fold decision. Reassess a policy decision only if an
  actual supported window requires changed order or neighbours; the
  generic counterexample alone does not establish that need.
- Keep physical-input checks deferred. No new exception is approved by
  these measurements.
