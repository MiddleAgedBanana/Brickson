# Show Borders on Home, and the Large Content Viewer held back

*2026-10-23. Pull request #35 (`claude/project-thread-xm9rll`). The
"Accessibility pass two" thread, a cloud session that cannot build or run
the app.*

## What changed and why

The next items of R0 item 3's accessibility list
([`2026-10-22-home-scan-order-and-names.md`](2026-10-22-home-scan-order-and-names.md),
*Follow-ups*). Item 1, Bold Text in the narrowest slots, is almost all in
PR #33 ("Settings on Home"), which checks the safety row, the categories
and Settings with Bold Text on; what it leaves is below. Item 3, Show
Borders, is built. Item 2, the Large Content Viewer, was built and then
held back, for the reason below. Decision: docs/DECISIONS.md, "Show
Borders and the Large Content Viewer on Home" (new).

What a person notices:

- **With Show Borders on** (Settings > Accessibility > Display & Text
  Size), every Home control has a 2pt border in primary ink (black in
  light mode, white in dark) inside its edge, so its edge stands out from
  the screen far more than a fill's own edge does (3.5:1 on black). A
  press doubles it to 4pt, and a selected category, or Emergency while
  its phrases show, keeps an inner ring, white in light mode and black in
  dark, so pressed, selected and neither still look different. Nothing
  moves or changes size. With the setting off, Home looks exactly as
  before.
- **Nothing else changes.** Holding a Home control does what it did.

How it is built:

- **`HomeButtonLook`** (new, `Brickson/Home/HomeButtonLook.swift`): a plain
  type that says, for a control's state (on or off, selected, pressed) and
  the Show Borders setting, whether it is filled and which rings it draws
  (ink, inset, width), and which ink shows at any depth inside the edge.
  Each ink is black or white by appearance.
- **`HomeButtonStyle`** reads `accessibilityShowBorders` and the colour
  scheme and draws the look's rings, in order, inside the frame. It drew
  the same rings before without the setting, in `Color.primary` and white;
  they are now plain black and white, which `PaletteTests` checks are the
  system's label and background colours.

### The Large Content Viewer, built and held back

The first version of this pull request (commit `bbafcb4`, never pushed)
put `accessibilityShowsLargeContentViewer { Text(verbatim: title) }` on
every Home button, through a small `View` extension in `FittedLabel.swift`,
with a UI test (`HeldPressTests`) that a held touch at the largest text
size still chooses a category and speaks a phrase. An independent review
before pushing found the risk: for UIKit's own controls, Apple documents
that with the viewer on, a touch held on one control that slides onto
another activates the second when the finger lifts, the default when the
viewer's gesture ends on an item
(`largeContentViewerInteraction(_:didEndOn:at:)`); it is how a tab bar
works. Whether SwiftUI buttons do the same has not been seen. If they do,
on Home a touch begun on Yes that drifts 8pt onto No would say "No.", and
a drift between phrase tiles would speak the next phrase. Without the
viewer, Apple documents that a touch stays with the view it began in, so
today a touch begun on Yes is expected to say Yes or nothing. The viewer
is not in this pull request; docs/HANDOFF.md has the device check that
decides it, and that checks today's build too.

The test build for that check is the commit described above: add
`.accessibilityShowsLargeContentViewer { Text(verbatim: HomeControlNames.yes.visible) }`
after `.accessibilityInputLabels(HomeControlNames.yes.inputLabels)` in
`HomeView.swift`, and the same for No, then run at an accessibility text
size. Never ship that build.

Documents: docs/ACCESSIBILITY.md (the Show Borders and Large Content
Viewer rows), docs/DECISIONS.md (the new entry and its row in *Decided by
default*), docs/HANDOFF.md (the pointer to these follow-ups, a known gap
and two device checks), docs/ROADMAP.md (item 3's status), AGENTS.md
(`HomeButtonLook` in *Workflow rules*).

## Commits

- `f45f845` Show Borders: `HomeButtonLook`, `HomeButtonStyle`,
  `HomeButtonLookTests`, two `PaletteTests`.
- The review's corrections to the ring-depth claim and the colour
  comments, and the records: this file and the documents above.

## Verified

Nothing was built or run on a Mac; GitHub CI is the build (AGENTS.md,
*Build and test*).

- **Linux Swift 6.3.3** (a throwaway package outside the repository, Swift
  6 language mode, main-actor default isolation): `HomeButtonLook`,
  `HomeShape`, `WordFit` and `HomeButtonLookTests` compiled without
  warnings and its 6 tests passed. Each of these changes made at least
  one of them fail: the selection ring left white under Show Borders (a
  selected control in dark mode then looks the same pressed as not); the
  pressed ring under Show Borders as wide as the border; the pressed ring
  under Show Borders 5pt or 6pt deep, past the label inset; no border
  under Show Borders; the plain pressed ring changed; the first ring drawn
  showing instead of the last; a control that is off losing its border
  under Show Borders.
- New tests and what would make them fail: `HomeButtonLookTests` (above);
  `PaletteTests.everyRingInkStandsOutFromEveryFill` (black or white under
  3:1 on any fill in light, dark or Increase Contrast, for example a
  darker emergency fill); `PaletteTests.ringInksAreTheSystemColoursTheyStandFor`
  (the label colour or the system background no longer exactly black or
  white at the base level, or a change to which ink is white in which
  appearance).
- An independent review of the diff (three reviewers: will it compile,
  the safety rules, the tests) found the Large Content Viewer risk
  above, and three smaller points, all taken: the claim that no ring
  covers a word now says where it holds; the screen's colour is named as
  the base level's; and a comment that put the border of a control that
  is off on a fill now puts it on the screen.
- Codex's code and security reviews found nothing. CodeRabbit found two
  points, both taken. docs/ACCESSIBILITY.md said the viewer was held back
  after a device check, when no device check has run; it, docs/DECISIONS.md
  and this record now say the slide is documented for UIKit's controls
  and not yet seen with SwiftUI buttons. And the claim that a touch
  without the viewer stays on Yes now cites Apple's touch model and says
  "expected", and the device check covers it.
- GitHub CI on `4f2a48f`: Unit tests and UI tests passed (iPad and
  iPhone simulators, with the newest released Xcode on GitHub's machine),
  run 39890270661. It ran again after main (PR #14) was merged in.

## Not verified

- **The rendered border.** `accessibilityShowBorders` cannot be set from
  a test, so no test draws Home with Show Borders on; the unit tests
  check what the style is told to draw, not the pixels. Device check,
  with the rendered pixels measured.
- Settings and setup use the system's `.borderedProminent` style, which
  is expected to follow Show Borders itself; not checked.
- **The selection ring at a shrunk label's edge.** A label SwiftUI shrinks
  to fit can spread to the label inset (4pt), and the selection ring, as
  Home already drew it, reaches 5pt: its inner point may touch the outer
  edge of a selected category's widest line. Older than this pull request
  and not measured.

## Follow-ups

For the next accessibility thread, the rest of item 3's list, in this
order:

1. **Bold Text in the narrowest phrase tiles.** After PR #33, the safety
   row, categories and Settings are checked with Bold Text on; the starter
   phrases in their narrowest tiles are checked with Bold Text off only
   (`StarterLabelFitTests`). Extend those three tests to Bold Text on,
   with #33's `expectFits(boldText:)`. If a phrase does not fit, the
   minimum tile width or height grows, measured.
2. **Dark mode's elevated background.** Add `userInterfaceLevel =
   .elevated` to `PaletteTests`' appearances and see what CI measures.
   Against `#1C1C1E` (a commonly reported value, not read from Apple) the
   fills' edges come to 2.84 to 2.96:1, under 3:1; if CI agrees, the
   fills or the screen change, measured, before release
   (docs/HANDOFF.md, *Known gaps*).
3. **`@ScaledMetric` for non-text sizes** on Home (paddings, gaps, corner
   radius, the label inset) and no Dynamic Type cap, kept inside
   `HomeShape`'s floors so nothing scrolls that does not already. The
   rings' widths and `HomeButtonLook.maximumDepth` come from the label
   inset and must scale with it.
4. **The motion policy** (Reduce Motion, and Prefer Cross-Fade
   Transitions behind `#available(iOS 26.4, *)` with UIKit's value before)
   when the first custom transition arrives. Reduce Bright Effects: the
   pressed ring is steady and unanimated already; Get Attention's alarm
   look stays steady too.
5. **After the device checks:** the Large Content Viewer, on the controls
   the slide check allows; labels on the regions if VoiceOver or Switch
   Control needs them; and `accessibilityRespondsToUserInteraction` on
   passive text only if the cursor stops on it.

For the thread that puts Get Attention and Stop on Home (R0 item 4): give
both `HomeButtonStyle`, and check Stop's look under Show Borders, pressed,
in both appearances.
