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

**UI tests, first run.** `SettingsOnHomeTests` failed on both simulators,
and its captures showed why: Settings' safety bar, built in PR #23, took
about a third of the screen's height, because Get Attention's empty place
was a `Color.clear` with only a minimum height, which takes whatever
height it is offered. Back to Talking sat in the middle of that, over
Home's Settings, so a look resting after Settings opened met Back to
Talking, and after Settings closed met Home's Settings again: open and
close in the same place (invariant 10). `SettingsTests` opens Settings
the same way and never measured where the bar was. Now the bar is only
as tall as its tallest control (`fixedSize`), Settings' sound line sits
at the foot of the cover instead of between the bar and the screens, and
wherever half the width holds its words on one line, the root's Family
Setup row takes the bar's trailing column, under Back to Talking, with
the note beside it. Modelled from
the run's own frames, the bar fix alone left Back to Talking nearest
the spot by centre on the iPad and by edge on the iPhone at AX5; with
all three, Family Setup is nearest by both rules on all five windows
the test runs (iPhone 402×874 at default and AX5, 13-inch iPad portrait
at default and AX5, landscape), and the way out still lands nearest
Emergency.

**Review round 2,** answered in words.
Codex raised three points on `aac1993`. Settings hides Yes, No and
Emergency: by design, since the cover opens on the way back and Get
Attention's place (AGENTS.md, *Family controls stay out of the person's
path*), now named as two activations away in docs/DECISIONS.md. The gear
alone is an exception to *Words never break*: it is, and it is put to
the owner. The known chain through Set Up Step by Step is now reachable
from Home: it is, recorded in docs/HANDOFF.md for the dwell-safety
scoring work, and its last step changes nothing the person sees or
hears yet.

**Before pushing round 2's notes,** two read-only review agents went over
the unbuilt Settings fix, one for the build and layout and one for the
rules and the record. Fixed: the root first chose its columns by size
class, which left compact windows wide enough for Home's regular
arrangement (an iPad's two-thirds Split View) with a full-width row and
Back to Talking nearest by centre; it now chooses them with
`ViewThatFits`, measuring a hidden copy of the row, so the columns come
wherever each half holds the row's words on one line. A code comment
credited CI with a modelled result. Recorded rather than fixed: the
chain's second step (the work file's table; docs/DESIGN.md asked this
work to score the chain), the sound line's new neighbours at the foot,
and the root's note under Get Attention's place on wide windows, which
the thread that adds Get Attention must score.

**Review round 3,** answered in words except for this record. Codex
raised two points on `3103ac5`, both trade-offs this pull request
records in docs/DECISIONS.md, now also put to the owner in the pull
request's description. A 320pt window loses more of its grid (about 240
to 110pt on a zoomed 375×667 phone): at 288pt of content Yes and No get
42pt against their 46pt words and the categories beside Settings' gear
114pt against their 118pt, so keeping both in one row means cutting
words or the spacing between targets, which is the layout engine's
call (follow-up 6). The sound line at the foot can sit nearest a row
that speaks or changes a setting. Under the bar, at the largest text on
CI's iPhone, the line's 125pt put Home's Settings nearest Back to
Talking (modelled from the first run's frames), so a held look would
open Settings and then close it from the same spot (invariant 10;
follow-up 9). CodeRabbit asked for the owner's answer on the gear
alone, which the description asks for, and for this record to say what
CI had and had not shown, fixed below.

**UI tests, second run** (`e285f6c`). `SettingsOnHomeTests` passed on
both simulators, and every UI test passed on the iPad. On the iPhone one
failed: Apple's audit of Settings' first screen, at the default text
size, reported "Text clipped" on no element, twice in light and twice
in dark. Family Setup and the privacy policy, under the same bar and
sound line, passed, and the root had passed on the first run, so the
change was the root's new `ViewThatFits`. This project had met it
before: the audit grows the text and compares each text with itself,
and labels built with `ViewThatFits` failed it (docs/DECISIONS.md,
*Home's stand-in layout*). Now `SettingsRootColumns` works out the
arrangement, and `SettingsRootLayout` places the one row and the one
note, with no hidden copy; AGENTS.md has the gotcha.

## Commits

- `e61243d` Settings on Home: write the intent
- `e287222` Settings on Home: write the spec and link the Figma frames
- `f607f70` Settings on Home: write the plan
- `63b078f` Test Settings on Home and the new safety row
- `0fe291a` Put Settings on Home and move Again into the safety row
- `82b75b6` Record Settings on Home in the docs
- `d6f1235` Fill in the Settings on Home record's pull request and commits
- `0969c1c` Test that Bold Text takes no height from a phone's phrases
- `30a6f4f` Narrow Yes and No, and show Settings' gear alone, before taking a row
- `abe25ad` Record review round 1 of Settings on Home
- `d0b88ba` Keep Settings' bar at the top, over nothing of Home's Settings
- `3e0dd5d` Record the Settings layout fix from the first UI test run
- `aac1993` Merge main into Settings on Home
- `0e512c0` Choose Settings' root columns by the width its row needs
- `5cbc9a6` Record review round 2 and score the chain from Home's Settings
- `3103ac5` Merge main (PR #14) into Settings on Home
- `e285f6c` Record review round 3 of Settings on Home
- `5926afd` Place Settings' root with a layout instead of ViewThatFits
- This record's second UI run, and the gotcha in AGENTS.md.

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
- CI on `d6f1235`: unit tests passed (the unit job runs on the iPad
  simulator). UI tests failed in `SettingsOnHomeTests` only, on both
  simulators: the stretched bar above. The frames, captures and
  screenshots were read from the run's result bundles on Linux (Python's
  `sqlite3` and `zstandard`).
- CI on `aac1993`: unit tests passed, so the bar fix and the root's first
  two-column layout built. Its UI run was cancelled by the next push
  before `SettingsOnHomeTests` started (read from its partial result
  bundle).
- CI on `e285f6c`: unit tests passed. UI tests: on the iPad 39 passed
  and the 4 opt-in keyboard probes were skipped; on the iPhone 37
  passed, the Settings audit above failed, and 5 were skipped (the
  probes, and the landscape check that runs on the iPad). The round 2
  Settings layout held: Family Setup took the trailing column under Back
  to Talking on the iPad at the default size and at AX5 (492pt wide,
  where the estimate was 902 of 1000pt for two columns) and spanned the
  iPhone's width, and `SettingsOnHomeTests` passed on all five windows.
- `SettingsRootColumnsTests`, 4 tests, passed on Linux the same way, with
  the 30 above; four mutations (strict `>`, the row in the leading
  column, the height from the row alone, no gap between the columns)
  each failed them. `SettingsRootLayout` was typechecked there, with
  Swift 6 and main-actor default isolation, against a stand-in of
  SwiftUI's `Layout` API written from Apple's documentation.

## Not verified

- Nothing was built or run for iOS in this session; the views, the UI
  tests and the label-fit tests run first on CI.
- CI on `5926afd` and after had not finished when this record was
  written: the pull request's checks show it, and must pass before it
  merges. `SettingsRootLayout` has not met the real SDK until then.
- The scoring table's percentages and the Back to Talking result for
  windows CI does not run (a 375pt phone, iPads other than the 13-inch,
  the 320pt window) come from a model of the frames with CI's text
  measurements, not from the running app.
- What Snap to Item or Dwell actually choose, on a device: the new
  device check in docs/HANDOFF.md.
- Bold Text on in a running app: no UI test turns it on; the label-fit
  tests check the widths with Bold Text drawn by SwiftUI.
- That the root's layout clears the audit's clipped text is the
  project's earlier lesson applied, not yet a passing run.
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
3. **Typing:** Again's well shows Speak while typing. "Speak" is a little
   wider than "Again" (about 58 against 53pt at the default size), so the
   typing thread must check it against `MinimumWidths.again` or widen it.
4. **Phrase tiles with Bold Text** are not checked: the label-fit tests
   check the starter phrases in their narrowest tiles with Bold Text off
   only (ROADMAP R0-3 in docs/ACCESSIBILITY.md). Heavier words may need a
   line more than the 99pt tile minimum allows.
5. **The Figma frame for a 375pt phone with Bold Text** shows the first
   draft; redraw it from the built arrangement when Figma reads allow.
6. **320pt phone windows** (Display Zoom): the grid already scrolled
   there and now shows less of itself (docs/DECISIONS.md, *Where the grid
   still scrolls*); the layout engine needs another arrangement for them.
7. **Back to Talking breaks "Talking"** ("Talk-", "ing") on CI's iPhone
   at AX5, a break of *Words never break* that the base branch has too
   (docs/HANDOFF.md, *Known gaps*).
8. **Family Setup's rows placed for the chain:** its first row where the
   root's row was, under Back to Talking, on wide windows and at large
   text, so the second held activation meets a row that only navigates
   (the work file's chain table).
9. **Settings' sound line** at the foot of the cover: a place whose
   nearest controls neither speak nor change a setting, when Get
   Attention joins the bar (follow-up 1), keeping Back to Talking off
   Home's Settings (docs/HANDOFF.md, *Known gaps*).
