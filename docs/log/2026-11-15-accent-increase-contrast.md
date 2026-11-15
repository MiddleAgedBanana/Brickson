# Phrase tiles keep their blue under Increase Contrast

*2026-11-15. Pull request #116 (`claude/project-thread-vq1xcn`). A Claude
Code cloud thread in the project, fixing the contrast defect the Simulator
run in pull request #115 found.*

## What changed and why

With Increase Contrast on, the phrase tiles, the selected category and
Settings' Back to Talking were not drawn in the blue their colour set
holds (`#0A60D6` in all four appearances). In dark mode the system drew
them `#1A7BFF`, and their white words fell to 3.95:1, under invariant 6's
4.5:1. In light mode it drew them `#084DAB`, where the words passed
(7.89:1) but the black ring that shows a press came to 2.66:1, under the
3:1 a control's edge needs. The same fill also tints the Library
editors' buttons and the chosen choices in Voice Settings and setup;
those were not measured under Increase Contrast, and now draw the same
colour set too.

The cause: these controls were filled with `Color.accentColor`, the
app's accent, while every other fill is its colour set loaded by name.
The system treats the accent as a colour for words and symbols, and under
Increase Contrast darkens it in light mode and lightens it in dark mode,
on top of whatever the colour set's high-contrast slots hold. Lightening
suits blue words on a black screen; it is wrong for a fill under white
words.

`Palette.phraseFill` is now `Color("AccentColor")`: the same colour set,
loaded by name, which the system draws as the catalog holds it. Without
Increase Contrast nothing looks different. With it, these controls show
the same blue they show without it, in light and in dark; in light that
is a little lighter than the system drew them, with words at 5.74:1 and
the pressed ring at 3.66:1. No colour, outline, position or size changed.
The decision is recorded in docs/DECISIONS.md, "Colour tokens in four
appearances".

**Why `PaletteTests` did not catch it.** Every check there reads the
colour sets through UIKit (`UIColor(named:compatibleWith:)`), which gave
`#0A60D6` in all four appearances, as the catalog holds. Nothing checked
that the colour a view draws is that colour set, and the phrase fill was
the one fill that was not. SwiftUI's environment cannot set Increase
Contrast, so a unit test cannot resolve the drawn colour there either.
The new test, `everyFillIsDrawnFromItsColourSet`, pins the cause instead:
each fill in `Palette.fills`, and the words on fills, must equal its
colour set by name, and it checks that `Color.accentColor` does not, so a
fill drawn with the accent cannot pass. It checks `Palette`, not the
views: a view drawing a colour of its own would still pass, as before.
`Palette.assetNames` now comes
from `Palette.fills`, so the list the other tests measure and the
colours the app draws are one list.

## Commits

One commit on `claude/project-thread-vq1xcn`: the fix, its test and
these documents.

## Verified

- Cloud session: Swift was not built or run here. GitHub CI is the build
  and test evidence; until it passes, the change is untested.
- The new test fails on the base branch: there `Palette.phraseFill` is
  `Color.accentColor`, which is not `Color("AccentColor")`. It fails
  again if any fill or the fill label is built another way, or if the
  comparison stops telling the accent from its colour set.
- The ratios above are WCAG's, computed with `PaletteTests`' formula from
  the values pull request #115 measured in the iOS 27.2 Simulator's
  screenshots: `#1A7BFF` with white 3.95:1, `#084DAB` with white 7.89:1
  and with black 2.66:1, `#0A60D6` with white 5.74:1 and with black
  3.66:1.
- The Python checks in AGENTS.md, *Build and test*, passed on this
  machine.

## Not verified

- That the rendered tiles are `#0A60D6` under Increase Contrast. This
  rests on the Simulator run's finding that fills loaded by name
  (the control, Emergency, Get Attention and Stop fills) keep their
  colour set's value under Increase Contrast; nobody has measured this
  branch's pixels. A Simulator re-run of the Home part of SIM-10, or the
  device check "Buttons under Increase Contrast and Reduce Transparency,
  measured on the rendered pixels" (docs/HANDOFF.md, *Checks that need a
  real device*), confirms it.
- System controls that take the global accent as a tint for their words
  and symbols (none fills a control with it now) were not re-measured.

## Follow-ups

- Once pull request #115 merges, its *Known gaps* line "The accent is
  drawn differently from its asset under Increase Contrast" describes
  the defect this fixes: the next pull request that touches HANDOFF
  removes it or reduces it to the device check. (Coordinator.)
- The website's accessibility page already says Home's text measures at
  least 4.5:1 with Increase Contrast on and off; with this fix that
  sentence is true, so the page is unchanged.
