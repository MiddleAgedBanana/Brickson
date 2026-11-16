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
Two values stay off the scale on purpose: Eye Tracking's 15-point gap (a
physical size held at the densest screen, like the floors) and a dimmed
Settings row's 14-point word inset (the system button's own). The
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
Tracking's, which must be the 12-point gaze gap held at 163 points per
inch from about 132.

No check flags a new spacing number written into a view yet. It belongs
beside the look rules and known exceptions that pull request #114 adds to
`scripts/forbidden-code.py`, so it waits for that to merge rather than
building on an open pull request (docs/HANDOFF.md, *Known gaps*).

## Commits

One commit: the scale, the views and engine moved onto it, the tests and
these documents.

## Verified

- Cloud session: Swift was not built or run here. GitHub CI is the build
  and test evidence; until it passes, the change is untested.
- No value changed: each replaced number was read beside the step that
  replaced it, and every step equals the number it replaced.
  `SpacingTests` fails if a step, a fixed measure or a profile's gap
  changes.
- `EqualGapsTests`' hand-made cases were worked through in a copy of the
  rule written in Python on this machine: even gaps pass, a tile 4
  points out, a row 4 points low and rows 12 apart with tiles 8 apart
  each fail once, half a point passes and 0.6 fails, and empty, single
  and touching groups fail.
- What would make the new tests fail: in the app, any spacer or stack in
  Home's grid or safety row that drew a gap other than the engine's; in
  the engine, a column, row or safety-row control placed with a gap other
  than the profile's; in the rule, a tolerance wider than half a point
  or a group with nothing to measure counted as a pass.
- SwiftUI declares no type named `Spacing` (Apple's documentation index
  has no such page, while it has `ViewSpacing`), so the name cannot clash
  with an import.
- The Python checks in AGENTS.md, *Build and test*, passed on this
  machine.

## Not verified

- That the rendered gaps are equal: the new check in `HomeLayoutTests`
  has not run until CI runs it. Its half-point tolerance assumes SwiftUI
  rounds the two edges of an integral gap the same way, as it should;
  a one-pixel difference on a 3x iPhone is a third of a point.
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
- Merge order: this touches none of #114's, #115's or #116's files but
  docs/DECISIONS.md and docs/HANDOFF.md, at lines none of them change,
  so any order is safe.
