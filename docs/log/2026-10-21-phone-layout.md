# Home fits the space it is given, and its slot plan

*2026-10-21. Pull request from `claude/project-thread-odn7pp`. The Phone
layout and word fitting thread (Claude Code on the web).*

## What changed and why

Home's stand-in now lays itself out from the width and height it is
given (`HomeShape`), never from the device, as the owner asked on
2026-10-21. What a person notices:

- **No label breaks a word.** Every label on Home fits itself: at the
  person's own size with its icon if it fits; then without the icon; then
  shrunk only as far as it must, down to the default size (Large) and
  never below it, in lines of whole words (`WordFit`, `FittedLabel`,
  `FittedLine`). The message steps down the same way, only while its
  widest word is wider than the row.
- **Every category is visible.** Four category buttons, two by two on
  narrow windows and one row of four on wide ones, never scrolled
  sideways.
- **Three phrase columns on every iPhone** (wherever three 107pt tiles
  fit), with rows from the largest category, so a tile keeps its place in
  every category. Tiles share the height left and scroll only where they
  would be shorter than 99pt (narrow) or 110pt (wide).
- **One status line** under the message for "Speaking" and the audio
  warnings, always kept at its tallest height, above where the software
  keyboard reaches.
- **Home's own button style** (`HomeButtonStyle`), because
  `.borderedProminent`'s margins left too little width for the starter
  words in three phone columns.

Decisions: docs/DECISIONS.md, "Home's stand-in layout" (new), "Home
version 0 is a stand-in" (edited), "Home's slot plan" (new), and one line
of "Get Attention" corrected (Stop is below Emergency, not above).

This replaces part of PR #13's compact arrangement (Emergency on its own
row, Again below a one-line message, no icons, one phrase column). PR #13
did that because labels could not fit themselves; now they can. Kept from
PR #13: eager rows instead of lazy grids (lazy rows vanish while Apple's
accessibility audit changes the text size), the disabled look, the strict
audits, and the screenshot test that reads the quick-control words back
at AX5. Each of those still has to pass.

## The slot model, for the next Home work

The next speech thread puts Get Attention and Stop on Home, and the
layout engine follows. Both build on this contract (docs/DECISIONS.md,
"Home's slot plan"), which is decided but not built:

1. **Every control on Home has a slot**: a fixed place with a stable
   identifier. Its frame comes from the space, the input profile and the
   text size, never from Home's state, the library or use. A state
   changes what a slot shows, never where it is.
2. **Regions, top to bottom: A, C, B, D.** A: the message and status
   line, with a trailing column of Phrases above Type, both there in
   every state, each only picking its own mode and showing selected while
   it is on. C: the
   safety row; on compact widths Yes, No, Again, then Emergency across two
   columns and Get Attention in the third; on regular widths one row of
   Emergency, Yes, No, Again, Get Attention. Again's well shows Speak while
   typing. B: Stop Alert's well directly below Emergency, a category in
   the cell under it, the other categories (at least 116pt wide), and
   Settings last, at the trailing end; while typing, the draft's Clear and
   Put Back take fixed category slots.
   D: the phrase grid.
3. **Wells keep their frames.** A control that applies only in some
   states (Stop Alert, Speak, the draft's Clear and Put Back) has a well that keeps its frame
   always; while empty it holds no control and is hidden from
   accessibility, and nothing moves into it.
4. **Start and stop apart.** Get Attention at the trailing end of C; Stop
   Alert directly below Emergency. After Stop the nearest control is a
   category or Emergency, never Settings; after Phrases or Type it is the
   same control, now selected (chains scored by the design thread).
5. **Get Attention, Emergency, Yes and No stay in C in every state**,
   above the worst-case software keyboard.
6. **Settings' safety bar sits over Home's frames:** Back to Talking over
   A's trailing column, Get Attention over the message's footprint.
7. **Identifiers name the slot, not the label**, so tests compare frames
   by identifier across states.
8. **On regular widths the message spans three of five columns**, the
   trailing column two, so Again sits under the trailing column, not
   beside the message.
9. **Yes and No border the message** on every window measured, one gap
   (10 to 16pt) away: an open hazard, not an accepted exception. The
   engine removes it by placement or brings its measured cost to the
   owner before the plan ships in a dwell profile.
10. **Open: more than four everyday categories.** Region B's L cannot
    scroll as one standard container; the layout engine's thread decides,
    before editing or import can add a fifth category.

The stand-in already has regions A, C, B and D in that order; what is
missing is the wells and A's trailing column. Again still sits in A.

## Commits

- `cd7042a`, `b5b48fb`: a temporary test that measured SwiftUI's and
  UIKit's text metrics on CI (removed in `e9bb3c7`).
- `e9bb3c7`, `644ba3d`: label fitting by Apple's text sizes (`644ba3d`
  adds the files `e9bb3c7` meant to include; pushed history was not
  rewritten).
- `2b36a07`: Home laid out from the space it is given.
- `ffa7bcd`: the decisions and where the grid still scrolls.
- `6391ec2`: a label at the person's own size is left unpinned.
- `eb07905`: `HomeLayoutTests` waits for the layout after a rotation.
- `813a5a8`: the first CI run recorded.
- `f1456b5`: library warnings under the grid (Codex review).
- `31e48f7`: one-word labels checked by drawn width; no icons on Yes, No
  and Again.
- `7a7fdb6`: quick controls and categories grow to one line of text.
- `1bca96a`: label sizes worked out without `ViewThatFits`, one view
  per label, and the grid always a scroll view.
- `545a44b`: labels drawn at the person's size in set lines, shrunk by
  `minimumScaleFactor`.
- The commit after `545a44b` (Codex review): `HomeLayoutTests` fails when
  an iPad does not turn, instead of skipping, and waits for each category
  to be selected before reading its tiles.
- The merge of `main` (PRs #12, #13, #15, #16, #18): eager rows in a
  plain `FixedColumns` view instead of `LazyVGrid`, `HomeLayoutTests` on
  `launchedApp` and `attachCapture`, the documents fitted to the new
  structure.
- The merges of `main` (PRs #21, #24, #25, then #23).
- The commit after the #23 merge (Codex review): labels measured at the
  heavier weight SwiftUI draws with Bold Text on (`LabelFont.legible`),
  with tests comparing SwiftUI's Bold Text widths and heights to the
  measure; `HomeLayoutTests` skips the iPhone's landscape pass and waits
  only for the turn where the grid may scroll; the message border
  recorded as an open hazard, not an accepted exception.
- `aa64319`'s CI: measuring Bold Text one weight heavier (bold) fell
  short; SwiftUI drew semibold labels up to 4.6% wider ("Conversation" in
  headline at AX5: 342pt drawn, 327pt measured), so set lines wrapped
  again. The commit after it measures Bold Text at black, the heaviest
  weight.

## Verified

- **CI, a manual run on `644ba3d`** (Apple's newest released Xcode on
  GitHub's image, iPad Pro 13-inch simulator, iOS 27.0): the build and
  every unit test passed, `StarterLabelFitTests` included. Two UI
  failures followed, both changed since and not yet re-run: the rotation
  race in `HomeLayoutTests` (`eb07905`) and Apple's audit reporting
  "Dynamic Type font sizes are partially unsupported" and "Text clipped"
  on the Needs button (`6391ec2`; the lazy grid, which PR #13 found loses
  elements during the audit, is gone in the merge too).
- **CI on `b2612d3`** (this pull request's first run): the build and
  every unit test passed. The UI tests failed on the iPad: the audit found
  "Dynamic Type font sizes are partially unsupported" and "Text clipped"
  on the Needs button again, and the text-recognition test read No as
  "g)No", its thumbs-down beside the word. `HomeLayoutTests` and the
  reachability tests passed there. The iPhone run did not start. Fixes,
  not yet re-run: Yes, No and Again lose their icons; a one-word label is
  now also checked by SwiftUI for width as drawn, because the symbol
  SwiftUI draws (Needs has a raised hand) can be wider than the one UIKit
  measured, which would cut the word short at a larger text size.
- **CI on `31e48f7`**: the build and unit tests passed, and the
  text-recognition test now reads every quick-control word on the iPad.
  The audit still reported "Needs" (iPad) and "No" (iPhone) as not
  following Dynamic Type, and `HomeLayoutTests`, the first test to launch
  the app, failed on both devices with "kAXErrorServerNotFound" before
  Home appeared (the cold-simulator failure in AGENTS.md, *Gotchas*; it
  passed on the iPad in the run before). Fix, not yet re-run: quick
  controls and categories grow to hold one line of their words at the
  person's size instead of stepping down to a fixed height. A 402pt phone
  then scrolls at AX5, recorded in *Where the grid still scrolls*.
- **CI on `7a7fdb6`**: the build and unit tests passed, and so did
  `HomeLayoutTests`, the reachability tests and the text-recognition
  test on both devices; iPhone No was no longer reported. Four audit
  tests still failed on each device: "Needs" (iPad) reported as clipped
  and as not following Dynamic Type, and "Text clipped on no element"
  in several audits on both. The likely cause, by elimination (no
  screenshots were kept): Apple's audit grows the text and compares each
  text with itself, and `ViewThatFits` swapped a label for another view
  as it grew (Needs's tall raised-hand icon made it swap at a different
  size from the other categories), while the phrase grid became a scroll
  view, replacing every tile. PR #13 found the same with lazy rows. Fix,
  not yet re-run: each label's size is worked out with UIKit and drawn
  by one view whose size limit is always the same modifier; icons take
  exactly their measured width and never more than a line's height; the
  status line is given its width; the grid is always a scroll view,
  turned off where the tiles fit. A new unit test checks the height
  measure against SwiftUI for every starter label at every size.
- **CI on `1bca96a`**: the build and unit tests passed, the new height
  test included, and every "Text clipped" finding was gone. The audit
  now reported "Dynamic Type font sizes are partially unsupported" on
  each label that had stepped down: Conversation on the iPad, and on the
  iPhone Yes, Again, Emergency, three categories and most tiles. So a
  label drawn at a smaller text size fails the audit however it is
  chosen. Fix, not yet re-run: labels are drawn at the person's own size
  in whole-word lines set for the chosen size, and SwiftUI shrinks them
  only as far as needed (`minimumScaleFactor`, never below the default).
- **CI on `a2ac972`** (that fix plus the two `HomeLayoutTests` changes
  from Codex's review): green. Unit tests: 276 of 276 passed on the iPad
  Pro 13-inch simulator, iOS 27.0, covering 93.0% of the app's lines. UI
  tests: 18 of 18 passed on the iPad Pro 13-inch and 18 of 18 on the
  iPhone 17, iOS 27.0, with no skips or expected failures: the light,
  dark and emergency audits at the default size, the AX5 audits and
  rendered words, `HomeLayoutTests` at default and AX5 in portrait and
  landscape (the iPhone in portrait only), and the reachability tests.
- **Measured on CI** with the temporary calibration test: SwiftUI's text
  widths match UIKit's to within half a point; SwiftUI's line height is
  the first line plus the style's leading per extra line (headline 17pt:
  20.5 then 22 per line), which UIKit's measure leaves out. Heights were
  first left to SwiftUI (`ViewThatFits`); since `1bca96a` UIKit measures
  them with room for that spacing, checked against SwiftUI in
  `StarterLabelFitTests`.
- **Pure tests** (`WordFitTests`, `HomeShapeTests`) also ran with the
  Linux Swift toolchain while writing them.
- New tests and what would make them fail: `WordFitTests` (a choice below
  the default size, or the icon kept when it does not fit);
  `HomeShapeTests` (a column count that depends on content, or a size
  under its floor); `StarterLabelFitTests` (a starter phrase, category or
  quick control that does not fit its narrowest slot at the default
  size); `PaletteTests.pressedRingStandsOutFromEveryFill` (a pressed ring
  under 3:1 on any fill); `HomeLayoutTests` (scrolling or a cut-off tile
  for the starter library, a tile that moves between categories, or a
  quick control off screen, at default and AX5, portrait and landscape
  where the device turns).

## Not verified

- Nothing was built or run on a Mac; CI on GitHub's Mac machines is the
  only build.
- The layout was never seen with Eye Tracking, Switch Control, Snap to
  Item or a real keyboard.
- The windows that still scroll (a 375×667pt phone from AX1) are worked
  out from measurements, not seen running.
- The slot plan is a plan: no well exists yet.
- Bold Text: how much heavier SwiftUI draws is not documented by Apple.
  The measure uses the heaviest weight (black), checked against SwiftUI on
  CI by `StarterLabelFitTests`; the starter labels' fit in their narrowest
  slots is checked with Bold Text off only.

## Follow-ups

- **Get Attention and Stop on Home**, building the wells of "Home's slot
  plan". *(a new speech thread)*
- **The layout engine with input profiles**, closing *Where the grid
  still scrolls* and taking floors per profile, and removing the message
  border hazard by placement or bringing its cost to the owner
  (DECISIONS.md, "Home's slot plan"). *(a new thread)*
- **Phone landscape**, once a layout test shows a sideways phone with no
  scrolling (DECISIONS.md, *Decided by default on 2026-10-21*, "iPhone orientations").
  *(the layout engine's thread)*
