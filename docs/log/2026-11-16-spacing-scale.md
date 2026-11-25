# One spacing scale, and a test that equal gaps measure equal

*2026-11-16. Pull request #117 (`claude/project-thread-m56qki`). A Claude
Code cloud thread in the project.*

## What changed and why

Nothing a person sees changed. The app's gaps, margins and insets were
numbers written into each view, the same values repeated in about
thirty-five places. They now come from one spacing scale, `Spacing`
(`Brickson/Layout/Spacing.swift`): seven steps on a two-point grid,
`xxxSmall` 2, `xxSmall` 4, `xSmall` 6, `small` 8, `medium` 12, `large` 16
and `xLarge` 24 points. Each is a value the app already drew, and every
number moved onto the step of its own value, so no frame moved. Home's
fixed measures, the touch, switch and head gaps between controls, the
region gaps made from them, Settings' gutter and row gap, and the stacks
and paddings of Settings, Voice Settings, the Library's editor field, the
privacy policy, setup and the keyboard probe screen all name a step now.
Two values stay off the scale on purpose: Eye Tracking's and the late
stage's 15-point gap (a physical size held at the densest screen, like
the floors) and a dimmed Settings row's 14-point word inset (the system
button's own). The
decision, with what counts as spacing and why steps do not grow with the
text size, is docs/DECISIONS.md, "One spacing scale".

Where the layout promises one gap, it is now measured. `EqualGaps` groups
frames into rows, measures every gap across and down, and fails when two
differ by more than half a point (one pixel on a 2x screen), or when
there is nothing to measure or controls touch:

- `EqualGapsTests` checks the rule on frames made by hand, and on the
  layout engine's phrase tiles and safety row in every window the engine
  tests sweep and in every profile on a phone's and an iPad's windows,
  where each gap must also be the profile's own.
- `HomeLayoutTests` now applies it to the running app: the largest starter
  category's eight tiles and the safety row's five controls, on CI's iPad
  and iPhone simulators, at the default and largest text sizes, in
  portrait and, on the iPad, landscape. It runs inside the test that
  already launches Home in each of those, so it adds no launch.

`SpacingTests` pins the steps, Home's fixed measures and Settings' gaps to
the scale, and checks that every profile's gap is a step but Eye
Tracking's and the late stage's, which must be the 12-point gaze gap held
at 163 points per inch from about 132.

No check flags a new spacing number written into a view yet. It belongs
beside the look rules and known exceptions that pull request #114 adds to
`scripts/forbidden-code.py`, so it waits for that to merge rather than
building on an open pull request (docs/HANDOFF.md, *Known gaps*).

## Commits

1. The scale, the views and engine moved onto it, the tests and these
   documents.
2. Review fixes: the new *Known gaps* entries moved out of the middle of
   another; the late stage named beside Eye Tracking, and the scale's two
   exceptions named in the handoff; gaps down measured from each control
   to the one under it, so a short tile cannot hide a wider gap below it,
   with a test that fails on one.
3. A merge of `main`, so the UI tests run in their new parts (#118).

## Verified

- Cloud session: Swift was not built or run here. GitHub CI is the build
  and test evidence.
- CI on the first commit passed: the unit tests, and the UI tests on CI's
  iPad and iPhone simulators, where the Home test that now holds the
  rendered equal-gaps check passed at the default and largest text
  sizes. CI on the review fixes (632d793) passed too, after re-runs for
  three faults of the machines that no test caused: a simulator already
  shut down at clean-up, the iPhone simulator losing contact in the
  middle of a test, and a slow machine that stopped the iPhone job at its
  time limit with no test failing.
- No value changed: each replaced number was read beside the step that
  replaced it, and every step equals the number it replaced.
  `SpacingTests` fails if a step, a fixed measure or a profile's gap
  changes.
- `EqualGapsTests`' hand-made cases were worked through in a copy of the
  rule written in Python on this machine: even gaps pass, a tile 4
  points out, a row 4 points low, rows 12 apart with tiles 8 apart and
  a tile 4 points shorter than its neighbour each fail once, half a
  point passes and 0.6 fails, empty, single and touching groups fail,
  and the engine's two-row safety row (Again under Yes and No) passes.
- What would make the new tests fail: in the app, any spacer or stack in
  Home's grid or safety row that drew a gap other than the engine's; in
  the engine, a column, row or safety-row control placed with a gap other
  than the profile's; in the rule, a tolerance wider than half a point,
  a group with nothing to measure counted as a pass, or a gap down
  measured from a row's lowest edge instead of from each control to the
  one under it.
- SwiftUI declares no type named `Spacing` (Apple's documentation index
  has no such page, while it has `ViewSpacing`), so the name cannot clash
  with an import.
- The Python checks in AGENTS.md, *Build and test*, passed on this
  machine.

## Not verified

- That SwiftUI rounds the two edges of an integral gap the same way on
  every screen, which the check's half-point tolerance assumes. It did on
  CI's iPad and iPhone simulators; a one-pixel difference on a 3x iPhone
  is a third of a point.
- Rendered gaps under profiles other than touch's (the UI tests ask for
  touch's), and in windows with a fold or camera region, where one gap is
  wider on purpose. The engine's are checked in every profile.
- The gaps of Settings and setup are on the scale but not measured.

## Follow-ups

- After pull request #114 merges: a forbidden-code rule that flags a
  spacing number written into a view (padding, stack spacing, gaps),
  with the off-scale values above as its known exceptions, and a line in
  AGENTS.md naming the scale. *(coordinator)*
- The three nearly equal pairs in docs/HANDOFF.md, *Known gaps*, for the
  design of the app's look. *(owner, with the design)*
- Merge order: this changes no file the other open pull requests change
  but docs/DECISIONS.md and docs/HANDOFF.md, and git merges each of them
  with this one cleanly, so any order is safe.
