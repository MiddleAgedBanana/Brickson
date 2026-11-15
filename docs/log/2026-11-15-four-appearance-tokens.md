# Colour tokens in four appearances, and a contrast budget

*2026-11-15. Pull request #113 (`claude/project-thread-z3jbgy`). A cloud thread
(Claude Code), from the project's foundations work, items E-01 and E-02.*

## What changed and why

Nothing a person using Brickson can see. Every colour in the asset
catalog now has the four slots Apple asks a custom colour to have (light,
dark, and each with Increase Contrast), each holding the value it always
had, and the words on fills became a colour of their own, `FillLabel`,
white in all four. The point is the plumbing: the design of the app's
look can now give dark mode and Increase Contrast their own colours
without touching a view, and every value it chooses is measured the
moment it lands.

`PaletteTests` now measures, in all four appearances: every slot's value;
that every colour set has exactly the four slots and none goes unpinned;
a **contrast budget** for every place a fill is drawn (its words at 4.5:1,
and its edge, or the border drawn over it, at 3:1 against the screen,
base and lifted); that Increase Contrast never lowers contrast; and that
the five fills never look alike to people with typical colour vision or
any of the three dichromacies (CIEDE2000 15 or more). The arithmetic is
ported from the stage 5 colour search's Python and checked against it.

Where today's values miss, the test records a named, strict known issue
instead of failing, and docs/HANDOFF.md, *Known gaps*, lists each for the
design: 6 edges on iPad multitasking's lifted dark screen (Settings'
system buttons and the typing fields' edge), and 8 pairs of fills that
look alike for one colour vision, in each of the four appearances (32),
Emergency and Get Attention at 2.7 for deuteranopia the closest. Nothing
was recoloured and no test was weakened. Decision: docs/DECISIONS.md,
"Colour tokens in four appearances". Codex's review pointed out that the
six edges are newly recorded breaches of invariant 6, and that a known
issue must not make them look accepted; the documents now say they are
not, and that the owner decides at merge whether they wait for the
design or get the border now.

## Commits

- `b668e2a` Give every colour token four values and measure a contrast
  budget (asset catalog, `Palette.fillLabel` in four views,
  `ColourArithmetic`, `PaletteTests`).
- The documentation commit after it.

## Verified

- **Not built or run on Apple's tools here.** This is a cloud session
  with no Mac: the app and its tests are untested until CI passes.
- `BricksonTests/ColourArithmetic.swift` compiled with Swift 6.2 on Linux
  (Swift 6 mode, complete strict concurrency, main-actor default
  isolation, warnings as errors) and reproduced the colour search's
  Python values to about 13 decimal places, including Sharma's published
  pairs (2.0425, 27.1492, 0.9082).
- `BricksonTests/PaletteTests.swift` type-checked and ran on Linux with
  Swift Testing against small stand-ins for the UIKit and SwiftUI types it
  uses, with Apple's colours taken as white and black screens, `#1C1C1E`
  lifted in dark and `#242426` lifted in dark with Increase Contrast: all
  15 tests passed, with exactly the 6 + 32 known issues listed, and
  `everyTokenHasFourSlots` read the real asset catalog. With the lifted
  gray set to `#1A1A1A`, where the accent fill passes, the budget test
  failed with "Known issue was not recorded", as it should.
- `scripts/forbidden-code.py`: nothing AGENTS.md forbids.
- What would make each new test fail: a slot's value changed in the
  catalog without its table row (`everyTokenHoldsItsValueInEachAppearance`);
  a colour set with three slots, or a new colour set not in the table
  (`everyTokenHasFourSlots`); Home's dark-mode border removed from
  `HomeButtonLook` (`everyFillKeepsItsContrastBudget`, on the lifted
  screen); an Increase Contrast slot darker than its default on a white
  screen (`increasedContrastNeverLowersContrast`); a known issue's value
  fixed without removing its line; a slip in the ported formulas
  (`theArithmeticMatchesTheColourSearch`).

## Not verified

- That Apple's lifted gray with Increase Contrast is `#242426`, as
  commonly reported. If CI's simulator resolves a gray darker than
  `#1B1B1B` there, the accent fill would pass on it and its known issue
  would fail the test; the fix is to remove that line. The CI log prints
  every measured ratio.
- That the simulator lets a hosted unit test read the asset catalog's
  source through `#filePath` (swift-snapshot-testing relies on the same
  access to write next to its tests).
- How the system's bordered prominent buttons draw under Increase
  Contrast: the budget measures the fill they are tinted with, not the
  rendered pixels (docs/ROADMAP.md, Q17).

## Follow-ups

- The owner's design of the app's look chooses each slot's value, using
  the known issues in docs/HANDOFF.md, *Known gaps*, as inputs, and
  removes each known issue's line as its value passes.
- If the design keeps white words on deep fills in dark mode, the
  Settings buttons and typing fields need the border Home's controls
  already draw (docs/HANDOFF.md, *Known gaps*).
