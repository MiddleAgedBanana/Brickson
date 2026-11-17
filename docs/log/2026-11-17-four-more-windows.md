# Four more windows in the layout engine's tests

*2026-11-17. Pull request #120 (`claude/project-thread-sdy7jz`). A cloud
thread.*

## What changed and why

The layout engine's tests check Home on a list of the windows people use
(`HomeLayoutEngineTests.windows`), each with its own safe areas, and on
a sweep of window sizes with no safe areas. Four window sizes that
current devices give were missing from the list. The sweep covered
their widths, but never with their safe areas, so a layout that broke
only once a device's top and bottom insets were taken away could have
passed every test. They were measured on the iOS 27.2 simulators in
the run of docs/EXPERIMENTS.md's SIM-12 (window sizes and safe areas),
window and insets read from SwiftUI at the app's root in portrait. The
run's own record comes with pull request #115
(`docs/log/2026-11-15-experiments-simulator.md`, not on `main` when this
was written), so the values this change uses are copied here:

| Window | Simulator | Size (points) | Top, bottom |
|---|---|---|---|
| iPhone Air | iPhone Air | 420 by 912 | 68, 34 |
| 13-inch iPad Air | iPad Air 13-inch (M4) | 1024 by 1366 | 32, 20 |
| 820×1180 iPad | iPad Air 11-inch (M4), iPad (A16) | 820 by 1180 | 32, 20 |
| iPad mini (A20 Pro) | iPad mini (A20 Pro) | 756 by 1158 | 32, 20 |

The three iPads are also added turned to landscape (1366 by 1024,
1180 by 820 and 1158 by 756), as every iPad in the list is. Their
landscape insets were not measured: they take the portrait ones, 32 and
20, as every other iPad in the list does. The list keeps the older
744 by 1133 iPad mini, which iOS 26 still runs on.

What the tests now do:

- **The fit table** (`theStarterLibraryFitsWhereTheTableSays`) has the
  seven new windows, with where the starter library fits and where the
  safety row clears the keyboard's room, from the engine.
- **Every check that walks the sweep** (`HomeLayoutEngineTests.everyLayout`:
  every slot inside the content and apart, the floors and words, the
  regions' order, the well, the held looks, the grid's columns and the
  rest) now also walks every window of the list, old and new, with its
  own safe areas, at the sweep's three text sizes, Bold Text off and on,
  in both of Home's modes.
- **The profile and rest-board tables** (`ProfileChoiceTests.eyeTable`,
  `LateStageProfileTests.boardTable`) have the new windows, and the
  sweeps that score chains of held activations at the larger profiles and
  on the rest board (`ProfileChoiceTests.heldWindows`,
  `LateStageProfileTests.boardWindows`) take every window of the list
  too, wherever its profile holds.
- **The well-drop pin** (`theCategoriesSitLowerOnlyWhereYesWouldReachStopsWell`)
  runs on the new windows by itself: the categories sit lower on none.

What the engine gives on them (docs/DECISIONS.md, "The layout engine",
"Sizes that follow how the screen is reached" and "The late-stage
profile", each with a dated line for these windows; the work files'
tables have the rows):

- **iPhone Air:** the starter library fits through AX3, with Bold Text
  too (as on the iPhone 16e); the safety row clears the keyboard's room
  at every size; touch's sizes at every size, with every category and on
  a rest board.
- **13-inch iPad Air and the 820×1180 iPad, portrait:** fit and keyboard
  at every size; Eye Tracking's with every category; the late stage's on
  a rest board.
- **13-inch iPad Air, landscape:** as in portrait.
- **820×1180 iPad, landscape:** fits at every size; the safety row
  clears the keyboard's room through AX3, so at AX5 Home does not offer
  typing; touch's sizes through AX3 and head tracking's at AX5, with
  every category and on a rest board. Head tracking's sizes hold here at
  every size, but through AX3 they leave no room for typing, which
  touch's keep (`ProfileChoice.keepsEverything`); at AX5 touch's leave
  none either. This is the rule the zoomed 13-inch iPad in landscape
  already follows.
- **iPad mini (A20 Pro), portrait:** fit and keyboard at every size; Eye
  Tracking's with every category and on a rest board, with Bold Text too
  (the older iPad mini takes head tracking's with Bold Text: its five
  columns are 130.4 points wide, under the widest bold word's 132; this
  window's are 132.8).
- **iPad mini (A20 Pro), landscape:** as the older iPad mini in
  landscape: the safety row clears the keyboard's room through AX1;
  touch's sizes (head tracking's leave the starter library 18 to 46
  points short).

No check failed on any of the new windows, so no layout changed. Nothing
in the app's code changed, and no window already in the list takes other
sizes or frames.

## Commits

See the pull request.

## Verified

- **The three layout suites on Linux.** `HomeLayoutEngineTests`,
  `ProfileChoiceTests` and `LateStageProfileTests`, built with Swift 6.4.2
  on Ubuntu 24.04 in a scratch package that compiles the engine's
  Foundation-only files and these tests unchanged, with default main-actor
  isolation. On `main` before this change they passed with the same
  known issues CI reports, so the Linux build computes what CI's does.
  With this change all 86 tests in the three suites pass, with 107
  known issues: the 12 new ones are the new windows' strict entries in
  the fit table (the iPhone Air at AX5, the 820×1180 iPad in landscape
  at AX5 with typing, and the iPad mini (A20 Pro) in landscape as the
  older iPad mini in landscape).
- **The new cases depend on the safe areas.** With the safe areas
  taken out of `Window.space`, the three table tests fail on the iPhone
  Air, the 820×1180 iPad in landscape and the iPad mini (A20 Pro) in
  landscape (and on most of the older windows): without its 102 points
  of insets the iPhone Air would fit at AX5, which its strict entry
  says it does not. The new iPads in portrait take the same sizes with
  or without their insets.
- `scripts/test-docs.py`, `test-hooks.py`, `test-privacy.py`,
  `test-forbidden-code.py`, `test-runner.py`, `test-agent-bridge.py`,
  `test-site.py` and `test-select-xcode.py` pass.

## Not verified

- **No Mac run.** This cloud session cannot build the app; CI's unit
  tests on the iPhone and iPad simulators are the build. The pull
  request is untested until they pass.
- **The landscape insets** of the three new iPads are assumed to be the
  portrait ones, as for every iPad in the list; nobody has measured them.
- **Real devices.** The window sizes come from simulators. iOS 26's
  insets on these devices are not measured (no iOS 26 runtime was
  installed for PR #115's run).
- No UI test runs on the new windows: CI's simulators are an iPhone 17
  and a 13-inch iPad.

## Follow-ups

- On the 820×1180 iPads in landscape (iPad Air 11-inch, iPad (A16)), a
  person whose answer asks for Eye Tracking's or head tracking's sizes
  gets touch's through AX3, because the larger sizes would leave no room
  for typing. The rule is the existing one (keep typing wherever touch's
  sizes keep it), and the same happens on the zoomed 13-inch iPad in
  landscape, but these are common iPads. Whether larger targets should
  win over typing there is a design question for the owner, best taken
  up with the new Home design.
