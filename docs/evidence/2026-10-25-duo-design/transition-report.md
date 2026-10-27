# Old resting points across changed windows

2026-10-25. **Bounded diagnostic finds added hazards under the stated hypothetical mappings. It does not clear the changed-window resting-point gate or establish actual OS pointer behavior.** The report-only investigation changed no app/test/probe file, Xcode project or simulator.

The existing invariant 10 checks concern repeated activations across Home states in one fixed window. Their committed/native checks pass. This investigation instead relocates an old resting point across a change of window coordinates. The two questions must not be conflated.

## Strongest fully-open example

Default text, before wide 951×669 (safe bottom 34/trailing 84) → after tall 669×951 (safe top 82/bottom 34). The raw divisions/cameras are the recorded inputs. The candidate uses the current outward-enclosing allocator; Legacy is the captured pre-implementation HomeLayout, which ignores interior regions.

Preserve `hasSpoken=false`, Conversation (third everyday category) selected, alarm quiet, browsing, empty draft. A look rests at the **identical numerical window point (454.5,300.5)**, inside both versions' old Conversation region. Assume the window-local point stays numerically unchanged after the window change. No activation is chosen at the transition; each trace starts with `ChainStart.resting`.

| Model | Result at(454.5,300.5) |
|---|---|
| Candidate before | selected category3 does nothing; repeats/settles |
| Legacy before | selected category3 does nothing; repeats/settles |
| Legacy after | Emergency navigates, then does nothing; settles |
| Candidate after | **Get Attention starts an alarm unasked** |

This result occurs under both nearest-centre and nearest-edge rules, and both pointer models, at depth 6. There is no hazardous tie branch or unscored exit in the three benign model outcomes. It does not rely on an unavailable Type transition. The candidate's tall Get Attention frame contains the point; Legacy's Emergency frame contains it instead.

Both endpoint geometries can describe a fully-open inner display. That does **not** establish that the OS keeps these numerical window coordinates during a real rotation. No actual pointer mapping, continued tracking, activation or alarm was observed.

Apple's [Eye Tracking guide](https://support.apple.com/guide/iphone/control-iphone-with-the-movement-of-your-eyes-iph66057d0f6/ios)
and [Head Tracking guide](https://support.apple.com/guide/iphone/iph9c3dc17cf/ios),
read 2026-10-25, describe pointing at a nearby item and the fully-open
Duo restriction. They do not specify a numerical pointer transform across
these window changes. Eye Tracking may recalibrate after the device or
face moves. None of that verifies either diagnostic coordinate map.

## Additional bounded examples

- **Semantic Type centres, tall→wide, held-window mapping:** already typing, written draft, nothing spoken. Candidate's old Type centre(549.5,173.75) meets Speak and speaks unasked after the change; Legacy's own old Type centre(549.5,194) meets inactive Put Back. Both before maps do nothing. All four rule/pointer combinations show this. The source points correspond semantically but are **different numerical old-window points**.
- **Shared old-window Type point, closed→wide, held-window mapping:** at(365.5,60.5), already typing, empty draft, both before maps do nothing. Candidate-after meets No by centre; Legacy-after meets the inert message field. Edge remains inert in both. Closed display/tracking applicability is unverified.
- **Shared old-window Type point, wide→tall, normalized-window mapping:** old(522.3,60.5) scales to(367.4224,86.0022). Candidate-after meets No by centre; Legacy-after meets Phrases. Both before maps have no hazard, although Legacy-before's centre rule meets inactive Again rather than Type. This is a hypothetical whole-window scaling rule, not a measured rotation transform.

The exact paths and all four before/after outcomes are in [the focused traces](transition-focused.json) (four probes). No example above passes through a Type transition where Type is unavailable.

## Scope and method

The host-only diagnostic compiled with `swiftc -parse-as-library -O -warnings-as-errors`, using copied current pure source, the captured Legacy type and unchanged ChainEngine/HomeChains. Source snapshot SHA256 `06a6d97d6c261205756ca0bc41c02d68b9484510b412fbdfe04cbcf0c948f7a4` matches the earlier fixed export. These are macOS executables under `/private/tmp`, not app builds.

- Five scenes: recorded closed 466×678, wide 951×669, tall 669×951, leading/right 469×669 panes. All 20 directed nonidentity pairs, default/AX5, Bold off.
- Two source domains: corresponding relative samples in each version's own old semantic region; and identical old points sampled from the intersection of both versions' old regions.
- Two independent mapping assumptions: retain window-local coordinates while both samples remain inside the destination; or scale by the before/after whole-window width/height. Screen-origin shifts, rotation-coordinate transforms and platform focus retargeting are unverified.
- All 120 Home states preserve typing, draft, selection, speech-history and alarm state at the transition. No chosen activation is inserted. Depth6, both nearest rules and both pointer models, including every hazardous tie branch.
- Fixed controls/tiles use 2×2 steps (9 samples); message/status and empty well 4×4 (25 samples), half a point inside the clipped source region. Unmatched/empty regions and out-of-window mapped pairs are excluded and counted.
- Bundled counts 8/8/6/6 and Emergency 6 trim tile controls in **every reached state**. Offset 0 only; no grown library or scrolled-offset sweep. Targets retain full layout frames when partly visible; source look points are clipped to grid/window. Full partial-target accessibility/Snap behavior is not proved.
- Keyboard visibility is not modeled; typing assumes the keyboard has already been lowered. Key-to-Home exposure when dismissing a keyboard is outside scope.
- HomeChains conservatively retains Type transitions where the current offersTyping policy would disable Type. Such chains are flagged in the broad output, not treated as physical findings. Settings exits and depth-limit endings are unscored, never safety passes. Settings-cover/first-step transitions are outside this Home-only map.
- Activity-only same-geometry comparisons pass in all 10 scene/font cases: occupied cells, allocation cells, grid and Back remain identical after every activity flag flips. This is distinct from resizing/rotating/folding to a different window.
- Apple's fully-open limitation for Eye/Head tracking must be retained. No tracking continuity is inferred for a closed/partially-folded handoff.

The local full 160-comparison output is `/private/tmp/brickson-duo-transitions.json`; its `.md` contains grouped counts. They are repeated sample/state/rule/pointer combinations, **not counts of independent defects or device events**. The output compares candidate semantic paths against Legacy and separately records combinations where both before models and Legacy-after have no hazardous or unscored branch. The focused probes above are the clearest reproducible subset.

## Quarter-turn follow-up

The [bounded quarter-turn supplement](quarter-report.md) tests two rigid
coordinate transforms, distinguishing the matching camera orientation.
Neither makes the original Conversation point start an alarm; that
example depends on retaining numerical window coordinates. Other modeled
new paths remain, including a tall→wide Get Attention point reaching
Clear instead of an inert category. Both the transform and dimmed-target
eligibility remain unverified on a device. This supplement does not
clear the changed-window gate or approve a path.

## Regression proposal for root review

Do not add a passing test that accepts these added paths or a new known-issue exception. A proposed failing diagnostic would construct the first preserved state and point, assert that both before maps and Legacy-after have no hazard/unscored branch, then require candidate-after to add no hazard. It currently fails for all four rule/pointer combinations. A separate semantic-centre diagnostic can preserve the second example while explicitly labeling its different source coordinates.

Before treating either coordinate mapping as an app requirement or declaring a physical regression, determine the platform's actual pointer/focus mapping for the applicable input method and window operation. Any resulting design must retain the current rules; this report chooses no alternative, adds no input guard, and infers no owner approval. The existing same-window checks remain green; changed-window pointer safety remains unverified and these modeled additions remain open for root review.
