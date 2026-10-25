# Fewer phrase tiles, measured

*2026-10-25. Branch `codex/fewer-phrase-tiles`. Codex.*

## What changed and why

Added a docs-only proposal at `docs/recon/2026-10-25-fewer-home-tiles.md` using the simulator
measurements from PR #55. It follows the fewer-tiles direction in
docs/DECISIONS.md, "Typing on Home": fewer whole phrase-grid rows, with
More fixed in the last slot. The message, safety controls, categories, Settings,
label minimums and target floors stay in their regions. No app code or
R1 implementation work starts here.

The table separates current touch-geometry calculations from unverified
future gaze, head and switch profiles. At standard-phone AX4/AX5, two
three-column rows at the 78pt floor leave five phrase slots plus More.
Duo closed's measured 350pt grid makes 111.33pt-wide tiles, whose current
compact floor is 99pt; three rows need 313pt, exceeding the default 310pt
viewport by the measured 3pt. Two rows would leave five phrases plus More;
its AX4 viewport fits one row, leaving two plus More. The zoomed phone's
default two rows leave three phrases plus More.

Paging alone cannot fix the zoomed phone's 7pt AX4 or zero-height AX5
viewport, nor Duo closed's 64pt AX5 viewport against its 99pt floor.
Those remain unresolved in R0 too. The restricted phone captures do not
establish a scroll range. Zoomed iPad landscape also disables Type at
AX4/AX5 despite fitting all eight phrases. Open-wide Duo at AX5 fits
one four-slot row at its 72pt floor: three phrases plus More. Open tall
fits all eight at default/AX4/AX5. The Hub's 130° partial pose matches
those tall default/AX5 results, and in wide dark matches open wide
(default eight/zero scroll; AX5 four/10pt). Fold/camera safety remains
unverified; these counts describe the eight-phrase starter category,
not a grown library's maximum capacity.

## Commits

- This documentation commit.
- Measurement source: [PR #55 source commit](https://github.com/MiddleAgedBanana/Brickson/commit/dd0aba6a788fa78d973fa389658eff2176a78efc).

## Verified

- Read the saved measurement JSON and checked capacity arithmetic against
  `HomeLayout.TileFloor` and `HomeLayout.Grid`; the table records measured
  windows and viewports rather than selecting layouts by device model.
- Source simulator checks: Xcode 27.1 (27A9275), iPhone 17 and 13-inch
  iPad on iOS 27.0, Duo on iOS 27.1; full-screen, English, Bold Text off.
  Exact orientations, zoom, appearance and test failures are in the source
  record. Its 70 curated measurements have 73 raw local records behind
  them. The keyboard is hidden; text is default/AX4/AX5, with default/AX5
  for partial poses. Dark checks cover zoomed iPad AX5, restricted zoomed
  phone AX4/AX5 and partial-wide Duo default/AX5; other cases are light.
  The proposal preserves the failing fit results.
- Documentation checks: all five Python suites passed: docs45, hooks124, site7, runner54, Xcode selection21 (251 total); diff check passed.
- Full Mac unit suite before this commit: 728 tests:720passed,0failed,1existing issue#19skip,7strict expected failures; String Catalog unchanged. Result: `build/TestResults/fewer-tiles-unit/unit-destination.xcresult`; log: `/private/tmp/brickson-fewer-tiles-unit.log`.
- GitHub CI for this PR: pending after the first push.

## Not verified

- No real-device input or call handoff was checked for this proposal.
- Paging is proposed, not implemented or tested. Current touch floors do
  not establish future gaze, head, dwell or switch capacities.
- Fold/camera clearance and changing poses are not proved by rectangular
  fit measurements. The later implementation needs reserved regions,
  stable even columns where required and complete ChainEngine scoring.
- Zero-row arrangements, clipped restricted-phone category frames and
  Type's unavailable states are unresolved; this PR changes no layout.

## Follow-ups

- Owner: proper mounted-device input checks, including Snap to Item on
  dimmed controls, remain in docs/HANDOFF.md, *Checks that need a real
  device*; the informal handheld observation is not a pass.
- Home layout work, before R1: settle the existing Home chain hazards and arrangements
  where no whole row fits without reducing floors or safety controls.
- R1 profile work, after the first R0 App Review build: use actual physical
  floors to recalculate capacity; settle short/empty pages and score page,
  wraparound, category, typing and fold transitions with the one engine.
