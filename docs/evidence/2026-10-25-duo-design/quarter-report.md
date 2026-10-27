# Quarter-turn supplement

2026-10-25. Host-only diagnostic; no repository, app, probe, Xcode project or simulator changes. No policy exception or actual pointer mapping is inferred.

**The previous held-coordinate alarm example does not start an alarm under either quarter-turn.** New candidate-versus-Legacy model hazards nevertheless remain under the camera-consistent quarter-turns. These are still hypotheses about pointer coordinates, not physical input findings. The existing same-window invariant 10 tests remain a separate, passing gate.

## Transforms and endpoint consistency

Both formulas were run separately, using the before window's width W and height H:

- Q1: `(x,y) → (y,W−x)`.
- Q2: `(x,y) → (H−y,x)`.

The fixed endpoints remain the recorded wide-upper-camera 951×669 and tall-right-camera 669×951 geometries. Q2 matches the physical camera marker wide→tall-right; Q1 matches it tall-right→wide-upper. The other combinations would correspond to the opposite camera orientation and are explicitly labeled `cameraRotationConsistent:false`. Matching the camera does **not** verify how accessibility pointer/focus coordinates change. System status bars/safe areas are OS layout inputs, not assumed rigid camera features.

## Original focused point

Default wide→tall, Conversation selected, browsing/quiet/empty draft/nothing spoken; same old point (454.5,300.5) in both versions:

| Transform | New point | Candidate-after | Legacy-after |
|---|---|---|---|
| Q1 |(300.5,496.5) | Feelings navigates then settles, by both rules/pointers | Feelings settles by centre; phrase speaks by edge |
| Q2, camera-consistent |(368.5,454.5) | Basics navigates then settles, by both rules/pointers | Feelings navigates then settles, by both rules/pointers |

Both before maps are inert selected Conversation. Thus the earlier unasked Get Attention result depended on the unchanged-window-coordinate assumption; it must not be described as persisting under rigid quarter-turns.

## Added camera-consistent examples

**Default wide→tall, Q2, shared old-window source point (86.5,300.5) →(368.5,86.5).** Preserve Emergency showing, browsing, alarm quiet, empty draft, nothing spoken. Both before maps navigate Basics then settle. Legacy-after meets Phrases, which does nothing. Candidate-after meets **No, which speaks unasked**, by centre under both pointer models. These no-op targets are not the Type-unavailable overapproximation. Edge is not claimed to fail in this example.

**Default tall→wide, Q1, shared old-window source point (446.5,310.5) →(310.5,222.5).** Preserve Emergency showing, typing, written draft, alarm sounding, nothing spoken. Both before maps meet start-only Get Attention, which does nothing while the alarm sounds. Legacy-after meets an inert category. Candidate-after meets **Clear, which changes the draft unasked**, under both nearest rules and both pointer models. All three benign comparison outcomes have no hazardous or unscored branch. This relies on HomeChains' representation of dimmed categories as no-op targets; actual Snap eligibility remains a deferred physical check.

A further AX5 wide→tall Q2 example maps an inert Get Attention point to Put Back while Legacy meets a dimmed phrase tile. It is retained in the curated JSON with the same disabled-target/physical-mapping caveats.

## Bounded matrix

Only wide↔tall was rerun: 2 directions × 2 formulas × 2 text metrics(default/AX5) × 2 source domains = 16 comparisons, Bold off. No 160-case resweep. Each comparison preserves all 120 Home initial states, uses no chosen activation at the transition, follows depth 6, both rules and both pointer models, and retains hazardous tie branches. Only destination-in-bounds pairs are mapped.

The source domains are unchanged: corresponding samples in each version's own old semantic region; or identical old points in the intersection of both regions. Controls/tiles use 9 samples; message/status/well 25. Starter counts 8/8/6/6 and Emergency 6 apply to every reached state. Offset 0 only. Source tile look areas are clipped; targets retain layout frames. Partial AX frames, keyboard dismissal, real focus retargeting and actual display-coordinate mapping are unverified. Settings exits/depth limits are unscored, not safe. The keyboard-lowered assumption and conservative Type-unavailable model remain explicit.

All 8 camera-consistent comparison rows contain added semantic signatures and combinations where both before maps and Legacy-after have no hazard/unscored branch. Counts repeat states/samples/rules/pointers and are not independent device-defect counts. No added path is accepted by this report. The native activity-only stability observations and same-window state-switch tests are distinct from these hypothesized window-change outcomes. Eye/Head tracking's fully-open restriction is retained; no tracking continuity during a fold is assumed.

## Artifacts and reproduction

- [focused traces](quarter-focused.json): curated original-point traces and representative added paths, with all four before/after outcomes.
- `/private/tmp/brickson-duo-quarter-transitions.json` and `.md`: full 16-comparison supplement.
- `/private/tmp/brickson-duo-quarter-transition.swift`: copied-source host executable input. It compiled with `swiftc -parse-as-library -O -warnings-as-errors`, then ran against the checked-in reservations JSON. Snapshot SHA256 remains `06a6d97d6c261205756ca0bc41c02d68b9484510b412fbdfe04cbcf0c948f7a4`.

A permanent no-new-hazard regression under either coordinate transform would currently fail. Do not replace it with a passing assertion that approves these paths. Root must review the model's applicability and obtain actual platform mapping evidence before claiming changed-window pointer safety. No app design or input guard was changed.
