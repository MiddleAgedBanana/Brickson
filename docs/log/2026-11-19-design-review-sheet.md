# A design review sheet, captured in every appearance

*2026-11-19. Pull request #PR (`claude/design-review-sheet`). A Claude
Code thread in the project, on the owner's Mac.*

## What changed and why

Nothing a person using Brickson sees changed: everything new is in debug
builds or on the Mac.

The app's new design will be judged from a picture of every visual
building block Brickson has today, in each appearance a person can
choose, and the owner will pick colours from it by eye. This adds that
picture, made from the app's own drawing and measured from its own
pixels, and the means to make it again whenever the design changes
(docs/DECISIONS.md, "A design review sheet in debug builds").

- **The sheet** (`Brickson/DesignReview/`, debug builds only, opened by
  `--screen=design-review`): every fill with the words drawn on it,
  primary ink on the screen, the spacing scale, the three kinds of
  corner, Home's controls in each fill on, selected, off and pressed,
  two phrase tiles and Settings' rows on and off, each built from the
  app's own lists. Its top line says which settings the app received.
- **The capture script** (`scripts/design-review/`): sets each appearance
  on a simulator (light, dark, Increase Contrast in each, Reduce
  Transparency, Show Borders, Differentiate Without Colour, Bold Text,
  the largest text size; and on an iPad an inactive window, light and
  dark), refuses a capture whose top line does not name it, holds a
  touch on each pressed specimen, measures every specimen and every
  control on Home, Home while typing, Home with the alarm sounding and
  Settings from the pixels, and lays the appearances side by side at
  their own pixels with the ratios under each.

What the sheet showed on `main`, measured from the pixels on both
simulators in every appearance:

- **Increase Contrast, Reduce Transparency and Differentiate Without
  Colour change nothing Brickson draws.** All 43 specimens measure the
  same fill, words and edge with each on as without; only Apple's
  keyboard, status bar and system controls change. Every colour token's
  four slots still hold one value (docs/DECISIONS.md, "Colour tokens in
  four appearances"), so the new design has the Increase Contrast slots
  to fill.
- **Dark mode is where the margins are thin.** The fills stand 3.51:1
  (`ControlFill`) to 4.18:1 (`AttentionFill`) from the black screen.
  Home's controls carry a white border there (`HomeButtonLook`);
  Settings' rows, the system's bordered prominent button, carry none and
  measure 3.51:1 and 3.66:1 on black: passing, with nothing to spare,
  and failing on the lifted gray already recorded in docs/HANDOFF.md,
  *Known gaps*.
- **Every pair of words passes, the lowest Get Attention's white on
  `#B45309` at 5.02:1**, in every appearance on both devices.
- **An inactive window changes nothing Brickson draws.** Behind a focused
  Settings window, every fill and word measured as in the active window;
  only Apple's window controls and the readout's own word changed. The
  focused window's shadow darkens what lies within about 140 points of
  it.
- Bold Text and the largest text size behave as the rules ask: labels
  drop their icons and fit their words, and no word Brickson draws breaks
  mid-word.

## Commits

- `3a3ec01`: Add a debug-only design review sheet and its capture script (work in progress)
- `5ce6944`: Capture each page only once the screen is still, and read a capsule's edge
- `dcb0f79`: Test the review sheet's measurements and script, and record the decision
- `128a3f6`: Measure each screen's controls once each, leave covered ones out, and report the keyboard's keys apart
- `e72527a`: Fit the swatches' words as controls do, type a message for the typing capture, and measure the field's own edge
- `98cc699`: Show Settings' rows at Settings' width, and put the typed message in as a kept draft
- `a8caf4f`: Capture the inactive iPad window clear of the focused window's shadow, and Settings over Home at the sizes Home was captured at
- `d5e46e2`: Answer Codex's review before opening: verdicts on full ratios, the weaker of two marks as the words, the scale read from the capture, safe reruns, and the keyboard required
- `d07540a`: Leave the screen in a shape's corners out of its words, read keys for their letters, and record what the sheet showed
- The commit that adds this list.

## Verified

- **Where:** the owner's Mac, Xcode 27.2 (27B52); my own clone of `main`
  at `606a26b`; simulators made for this run, an iPhone 17 and a 13-inch
  iPad Pro (M5), iOS 27.2, portrait, Debug build, fresh test storage.
  One simulator booted at a time.
- **The settings reach the app.** For each appearance the script set the
  simulator's settings (`xcrun devicectl device settings appearance`, and
  `com.apple.Accessibility`'s `EnhancedTextLegibilityEnabled` and
  `DifferentiateWithoutColor` for Bold Text and Differentiate Without
  Colour, found by switching each in the simulator's Settings app and
  reading which preference changed) and refused any capture whose readout
  did not name it. All 22 captures were accepted: 9 appearances on each
  device, and the inactive window in light and dark on the iPad, whose
  readout said `window=inactive`.
- **Every specimen was captured and measured:** 43 of 43 in each of the
  18 full appearances; in the inactive window, the 7 that sit above the
  Settings window and its shadow. Each pressed specimen was captured
  with a touch held on it (`axe touch --down`). Home, Home while typing
  with Apple's keyboard up, Home with Get Attention sounding (the silent
  test tone) and Settings were captured in each appearance, their
  controls measured, controls the keyboard or Settings' cover hides left
  out.
- **The measurement can see a failure.** `ReviewPixelsTests` draws
  pictures whose colours and edges are known and checks the readings:
  a border taken for the edge, a ring reported on its fill, a round
  shape whose frame's corners show the screen, the screen in a shape's
  corners never taken for its words, gray words beside a black icon
  taken as the gray, and stray pixels never taken for words. Two were
  run against the rule they guard, put back for the run and never
  committed: with the edge as the plain commonest colour,
  `aRoundShapesEdgeIsItsFill` fails (it read the screen, as the first
  run did on Settings' rows); with the words as the strongest colour,
  `theWeakerOfTwoMarksIsTakenForTheWords` fails. Verdicts are taken on
  full ratios (Codex measured `#76767F` on white at 4.4986:1 printed as
  4.50 before), and `theContrastIsTheOnePaletteTestsMeasures` pins the
  formula to `ColourArithmetic`'s.
- **The sheet holds every building block.** `DesignReviewTests` fails if
  the catalogue's roles leave out a fill in `Palette.fills` or a kind of
  corner, if two specimens share an identifier, or if the readout misses a
  setting; the capture script refuses a sheet that never showed one of the
  43 specimens it expects; `LaunchOptionsTests` reads
  `--screen=design-review`.
- `python3 -I scripts/design-review/test_review.py` (12 tests), the unit
  suite (`CI=true scripts/test.sh unit` on the iPhone 17 simulator: all
  passed, the String Catalog unchanged) and every Python check in
  AGENTS.md, *Build and test*, passed on this Mac before the push;
  `scripts/forbidden-code.py` finds nothing. `codex review --base
  origin/main` ran before the pull request opened; its eleven findings
  are answered in the last commits.

## Not verified

- **The lifted dark gray of iPad multitasking.** In the inactive capture
  Brickson's window filled the screen, so its screen was black; the
  failures recorded on the lifted gray were not photographed here.
- **A real device.** Every picture is the Simulator's rendering.
- **Liquid Glass.** Brickson draws none, and no system glass showed on
  these screens over content.
- **Home and Settings in the inactive window** are pictures with the
  count of changed pixels in the rows above the Settings window, not
  measurements of each control.
- **The script's own run in CI.** It needs AXe, `devicectl` and
  simulators whose settings it changes; CI runs its unit tests only.

## Follow-ups

- The owner's design of the app's look picks new values from the sheet,
  then runs the script again to see them in every appearance. *(owner;
  any thread on the Mac runs it)*
- A capture on the lifted dark gray: an iPad window smaller than the
  screen behind a focused one. *(a later run of the script)*
