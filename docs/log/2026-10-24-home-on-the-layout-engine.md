# Home on the layout engine

*2026-10-24. Pull request #52 (`claude/project-thread-2z1cok`). The Move Home
onto the layout engine thread, a cloud session with no Xcode: nothing
here was built or run on a Mac, and CI is the first build.*

## What changed and why

Wave 3 item 4 (docs/ROADMAP.md): Home takes every frame from the layout
engine (`HomeLayout`, PR #48), and the stand-in's sizes (`HomeShape`) are
gone. Home reads the space the window gives it (its size and safe
areas), the person's text size and Bold Text and the library's largest
category, and places each control with standard stacks at the size the
engine gives it, so right-to-left languages still mirror it. Nothing in
it names a device. The decisions are in docs/DECISIONS.md, "The layout
engine", *Home on the engine*, with dated notes in "Home version 0 is a
stand-in", "Home's stand-in layout", *Where the grid still scrolls*,
"Get Attention and Stop on Home" and "One chain engine for dwell
safety".

What a person sees:

- **The same arrangement as before, at the engine's sizes.** Until
  typing comes (item 5), Home has no Phrases or Type, and the slot
  plan's places for them would leave Get Attention bordering the
  message. So the engine has two modes (`HomeLayout.Modes`): Home uses
  `phrasesOnly`, today's arrangement (the message across the width, then
  Yes, No and Emergency over Again and Get Attention in two equal
  columns, then the categories with Stop's well and Settings, then the
  phrases); `phrasesAndTyping` is the slot plan's, for item 5. Both are
  tested.
- **Fewer windows scroll.** The starter library now fits without
  scrolling on every iPad window CI runs at every text size, on the
  11-inch iPad and iPad mini in landscape at the default size (they
  scrolled), on the 375×667 phone at the default size (it scrolled), on
  the iPhone 17 Pro Max at every size, on the iPhone 16e through AX3 and
  on the iPhone 17 through AX3 (AX1 with Bold Text), by the engine's
  model, and on the iPad mini in landscape and a zoomed 13-inch iPad in
  landscape through AX3. It still scrolls on phones smaller than the Pro
  Max at AX5, on the iPhone 17 at AX3 with Bold Text, on the 375×667
  phone above the default size or with Bold Text, on the iPad mini and
  the zoomed 13-inch in landscape at AX5, and on 320-point windows
  (Display Zoom's Larger Text) at every size.
- **Tiles are only as tall as their words need.** A tile's floor follows
  its width (`HomeLayout.TileFloor`): a wider tile holds the starter
  phrases in fewer lines, so it may be shorter before the grid scrolls.
  On the iPhone 17 the floor falls from 99 to 78 points.
- **Bold Text keeps "understand." whole on 375 and 390-point phones.**
  They get two columns of phrases with Bold Text on, where they had
  three tiles too narrow for the word.
- **A selected category keeps its words clear of its ring.** Every
  category now has Emergency's 6-point side inset
  (`HomeLayout.selectableSideInset`), so its narrowest width is 122 points
  (132 with Bold Text). The five-column arrangement then starts at
  674-point windows (724 with Bold Text), not 664 (714); Settings shows
  its gear alone on windows 344 to 371 points wide (368 to 397 with Bold
  Text, so on 375 and 390-point phones with Bold Text).
- **Get Attention never loses half its words.** Found while porting: the
  engine let the safety row fall to 44 points where Get Attention is too
  narrow for "Get Attention" on one line (134 points; 147 with Bold
  Text), which would have cut its second line off. Where it is narrower,
  the safety row is at least 64 points, the height at which CI read both
  words on today's Home (`HomeLayout.twoLineQuickControlHeight`). On
  Home that is only 320-point windows with Bold Text; in the slot plan it
  is every compact window, where Get Attention shares A's narrow trailing
  column, so the slot plan no longer fits the 375×667 phone at the
  default size (item 5 inherits this).
- **Nothing is given back for the keyboard without typing.** The engine
  cut the safety row back to keep it above Apple's keyboard; with
  nothing on Home that opens the keyboard, Home keeps its full height
  (88 points on an iPad in landscape, where the cut took it to 44).
- **Yes stays off Stop's well** (found by Codex in review of this pull
  request). The engine's shorter safety row, 44 points where the
  stand-in kept 64, brought Yes's centre, two rows up, as near the top
  leading corner of Stop's well as Again's: in a 400×568 window at the
  default size, a look resting there after Stop met Yes by nearest
  centre, which the stand-in never allowed. Where Yes would come within
  a point of Again or the category under the well, at any point of the
  well's top edge, the categories now sit lower (`HomeLayout.wellDrop`),
  by at most 18.5 points, in 3% of the layouts measured and on no phone
  in portrait or full-screen iPad. It costs 48 layouts (604 to 720
  points wide, 667 tall, at AX3) up to 7.5 points of scrolling where
  they fitted (docs/DECISIONS.md, "The layout engine", *Home on the
  engine*).

Hazards (invariant 10), measured on the engine's frames for every width
from 320 to 1432 points, both modes, three text sizes, Bold Text off and
on:

- *Yes and No border the message:* on Home, at most 57% of the message is
  nearest a control that speaks by nearest centre and 51% by nearest
  edge, as before (about 56% and 50%). With the slot plan's Phrases and
  Type beside the message it would be up to 97% and 89% on compact
  widths. Still open; the owner decides before R1's profiles.
- *The top of Stop's well is nearest Again:* on Home, on every width,
  as before. Yes never is (below). The chain engine finds this and
  nothing else (`noChainOnTheEnginesFramesMeetsAHazardButStopsWell`).

## Commits

- `3937f12` the engine's modes, tile floors, selected inset and Get
  Attention's two lines; Home on the engine; the stand-in removed; the
  tests ported.
- `5473c99` this record and the documents.
- The commit after those: Yes kept off Stop's well, from Codex's
  review, with its tests and documents.

## Verified

On Linux with Swift 6.4.1 (the engine and `KeyboardAllowance` are
Foundation only): `HomeLayoutEngineTests` and `KeyboardAllowanceTests`,
43 tests, all pass, with 83 strict known issues (the windows and sizes
where the starter library cannot fit, and the hazards above). Each new
or changed check was seen to fail with the change it guards against
undone:

- `everyControlKeepsItsFloorAndItsWords` fails when Get Attention's
  two-line height is taken out of the floor.
- `theStarterLibraryFitsWhereTheTableSays` failed on the 375×667 phone
  and the 320×568 window once that height went in, until the table said
  where the slot plan stops fitting.
- `withoutTypingNothingIsGivenBackForTheKeyboard` fails when the
  keyboard cut also applies without typing, and
  `everyGridKeepsTheFloorItsWidthSets` when the grid takes the floor of
  the narrowest width whatever its tiles' width.

After Codex's review, the same suite, 45 tests, passes with the same
83 known issues. Without the drop, `theTopOfStopsWellIsNearestAgainUnlessEmergencyIsAboveIt`,
`theCategoriesSitLowerOnlyWhereYesWouldReachStopsWell` and
`noChainOnTheEnginesFramesMeetsAHazardButStopsWell` fail; without its
room counted with the floors, the last check of
`theCategoriesSitLowerOnlyWhereYesWouldReachStopsWell` fails (a window
the engine says fits would scroll). `noPointOfTheTopOfStopsWellIsNearestYes`
failed on the fix's first version, which checked a grid of 65 by 9
points across the well (Yes tied at a point of the top edge of a
1336×568 window at AX5, as the review found), and passes on the one
that takes the edge every quarter point. A sweep on Linux of 44,640
layouts (widths every 4 points from 320 to 1432, eight heights from 568
to 1376, five text sizes, Bold Text off and on, both arrangements)
compared the fixed engine with the one before it: Yes nearest some
point of the well, by the chain engine's rules, in 903 layouts before
on its 45 points and 1,197 on the top edge every tenth of a point, and
in none after on those or on 1,105 points; the numbers above come from
it.

On GitHub CI, `5473c99`, the first build of `HomeView`, the font tests
and the UI tests for iOS, passed: the unit tests, and the UI tests on
the iPad and the iPhone CI runs.

`scripts/test-hooks.py` and `scripts/test-docs.py` pass.

## Not verified

- Nothing was compiled here for iOS: CI is the build. The drop's one
  line in `HomeView` (the categories' top padding) is not exercised by
  the UI tests: no window CI runs has a drop, so the running app has
  not been seen with one.
- The new tile floors, Get Attention's one-line width and the message's
  two lines against SwiftUI are predictions from Apple's SF Pro measured
  on Linux; the font tests check them on CI.
- The running app's frames are not compared with the engine's point by
  point. The UI tests check what the engine predicts for CI's iPhone and
  iPad (the starter library fits where it should, every control is on
  screen, tiles keep their places, frames hold across states), not each
  frame.
- Not checked against the Figma file: Figma's Home is the slot plan's,
  with Phrases and Type, which item 5 builds and checks.
- Nothing on a device: gaze comfort, Snap to Item, and how a resting
  pointer meets the hazards above (docs/HANDOFF.md, *Checks that need a
  real device*).

## Follow-ups

- **Phones at the largest text sizes and 320-point windows** still
  scroll: they need an arrangement with fewer tiles to a screen, a
  design question (Figma, then the owner) before R1's dwell, switch,
  head and gaze profiles, where scrolling costs most. Touch may scroll
  there today (invariant 11 binds those profiles). *(a design thread)*
- **Yes and No bordering the message** with the slot plan's Phrases and
  Type (up to 97% by centre on compact widths): the owner's call before
  R1, recorded in docs/HANDOFF.md. *(owner)*
- **Item 5** brings Phrases and Type (`phrasesAndTyping`), Back to
  Talking over Phrases' frame (docs/DESIGN.md), the Figma check, and the
  slot plan's compact Get Attention, which needs its 64-point row.
  *(Wave 3 item 5)*
- **Comparing the running frames with the engine's** in the UI tests,
  by compiling the engine into the UI test target, once a Mac can build
  it first. *(item 5, or a Mac thread)*
