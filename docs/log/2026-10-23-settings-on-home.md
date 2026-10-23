# Settings on Home

*2026-10-23. Pull request #33 (`claude/project-thread-5fe8vu`). The
Settings on Home thread, a cloud session.*

## What changed and why

Home now has a Settings button, so the Settings built in PR #23 and #27
can be opened at last. It sits where *Home's slot plan* puts it, at the
trailing end of the categories: a column as tall as the category rows
(its gear alone on a 375pt phone with Bold Text), or a row of its own on
the narrowest windows. Until Family Setup has been
opened once, the message area says "Family: help with setting up is in
Settings." instead of its placeholder.

Again moved out of the message's row into the safety row, which now reads
Yes, No, Again, Emergency. That fixes the way out of Settings: Back to
Talking sits over the trailing end of Home's message, and a look still
resting there after Settings closed would have landed nearest Again,
which speaks. It now lands nearest Emergency, which only shows the
emergency phrases. It also reduces the open hazard "Yes and No border the
message", which stays open with a device check. The decisions are in
docs/DECISIONS.md, "Settings on Home"; the intent, spec (with the scoring
table) and plan are in [`work/settings-on-home.md`](../work/settings-on-home.md).

Every control's minimum width now comes from its word, measured with the
real fonts, and wider with Bold Text on (`HomeShape.MinimumWidths`), so
the narrower Again and the categories beside Settings never cut a word.
The Bold Text numbers were worked out from Apple's SF Pro font (the
variable font with its tracking table, through HarfBuzz on Linux), whose
widths matched the ones CI measured earlier within half a point; CI's
`StarterLabelFitTests` is the real check.

**Review round 1.** Codex found that the first draft made a 375pt phone
with Bold Text scroll its starter phrases (invariant 11): the heavier
words took both a second safety row and a row of their own for Settings,
leaving tiles about 64pt against the 99pt minimum, where the base branch
fitted. It was right. Now Yes and No, the shortest words, narrow before
the safety row splits, and Settings shows its gear alone where its word
does not fit beside the categories, so Bold Text never takes height from
a phone's phrases (`HomeShapeTests.boldTextTakesNoHeightFromAPhonesPhrases`).
Only the 320pt window keeps the two-row safety row and Settings on its
own row.

## Commits

- `e61243d` Settings on Home: write the intent
- `e287222` Settings on Home: write the spec and link the Figma frames
- `f607f70` Settings on Home: write the plan
- `63b078f` Test Settings on Home and the new safety row
- `0fe291a` Put Settings on Home and move Again into the safety row
- `82b75b6` Record Settings on Home in the docs
- This record's pull request number and commits.

## Verified

- On Linux, with swift.org's Swift 6.3.3 toolchain and a throwaway
  Swift package outside the repo that links the repo's files:
  `HomeShapeTests`, `ControlNamesTests` and `HomeRegionTests`, 27 tests,
  all passing. Three mutations of `HomeShape` (no Emergency minimum, no
  "Settings at its minimum" step, no two-column try on wide windows)
  each failed the tests the plan names. Unbuilt for iOS: CI is the build.
- Round 1, the same way: 30 tests, all passing, and four mutations each
  failed the tests the plan names (no narrower Yes and No; no gear-only
  Settings; the gear tried before the word; Yes and No with no minimum).
  Two read-only review agents went over the fix before it was pushed,
  one against AGENTS.md's rules and one for the build and CI's tests; the
  Settings button's property pattern was typechecked on the same
  toolchain with Swift 6 and main-actor default isolation.
- CI: PENDING.

## Not verified

- Nothing was built or run for iOS in this session; the views, the UI
  tests and the label-fit tests run first on CI.
- The scoring table's percentages and the Back to Talking result for
  windows CI does not run (a 375pt phone, iPads other than the 13-inch,
  the 320pt window) come from a model of the frames with CI's text
  measurements, not from the running app.
- What Snap to Item or Dwell actually choose, on a device: the new
  device check in docs/HANDOFF.md.
- Bold Text on in a running app: no UI test turns it on; the label-fit
  tests check the widths with Bold Text drawn by SwiftUI.
- Settings' gear alone is never drawn by a test: CI's iPhone has 370pt
  of content, where the word fits with Bold Text off or on. Its label,
  its large content viewer and Apple's audit of it wait for a window
  with 296 to 332pt of content (316 to 358pt with Bold Text), such as a
  375pt phone with Bold Text.

## Follow-ups

1. **Get Attention and Stop on Home** (the next Home thread): until
   Phrases and Type are built, keep a control that says nothing nearest
   under Back to Talking (`SettingsOnHomeTests` fails otherwise). The slot
   plan's regular-width order (Emergency first) comes back with them.
2. **The layout engine:** "Yes and No border the message"
   (docs/DECISIONS.md, "Settings on Home").
4. **Phrase tiles with Bold Text** are not checked: the label-fit tests
   check the starter phrases in their narrowest tiles with Bold Text off
   only (ROADMAP R0-3 in docs/ACCESSIBILITY.md). Heavier words may need a
   line more than the 99pt tile minimum allows.
5. **The Figma frame for a 375pt phone with Bold Text** shows the first
   draft; redraw it from the built arrangement when Figma reads allow.
6. **320pt phone windows** (Display Zoom): the grid already scrolled
   there and now shows less of itself (docs/DECISIONS.md, *Where the grid
   still scrolls*); the layout engine needs another arrangement for them.
3. **Typing:** Again's well shows Speak while typing. "Speak" is a little
   wider than "Again" (about 58 against 53pt at the default size), so the
   typing thread must check it against `MinimumWidths.again` or widen it.
