# Settings on Home

*Roadmap: R0 item 7 (Settings and first run), the part it left for later:
Home's Settings button. Owner: the Settings on Home thread. Status: building.*

## Intent

- **Problem:** Settings is built (PR #23 and #27) but nobody can open it:
  Home has no Settings button, so only UI tests reach it
  (`--screen=settings`). A family cannot choose a voice, read the setup
  guides or open the privacy policy, and the first-run line that tells
  them where setup is was never shown. Separately, the way out of
  Settings is unsafe once Home has a way in: Back to Talking sits over
  the trailing end of Home's message, where Again is today, so a look
  still resting there after Settings closes would land nearest Again,
  which speaks (invariant 10). The open hazard "Yes and No border the
  message" (docs/DECISIONS.md, "Home's slot plan") is the same kind of
  problem: a look resting on the message meets controls that speak.
- **Proposed outcome:** a family member finds Settings on Home in one
  touch, in the same place every time, and on the way in or out a
  pointer still resting where a control was meets nothing that speaks.
  The first launch shows "Family: help with setting up is in Settings."
  in the message area until Family Setup has been opened once.
- **Who and what it affects:** families and caregivers (touch, mostly);
  the person, by every input method, because Settings and the moved
  Again sit on Home. Home's layout (`HomeShape`, `HomeView`), Home's
  names and scan order (`HomeControlNames`, `HomeRegion`), and the
  Settings button (`SettingsButton`).
- **Constraints:** invariant 1 (a standard `Button` with a label, at
  least 44pt), 2 (every phrase still speaks at once; Emergency, Yes and
  No stay one activation away), 8 (positions never depend on state,
  use or the library), 10 (score what a held activation meets on the way
  in and out, by nearest centre and nearest edge), 11 (no new scrolling
  for the starter library), *Words never break*, *Layout on every device
  and window* (sizes from the space, never the device), "Home's slot
  plan", "Settings is a cover with a fixed safety bar", "Home's scan
  order and names", and Apple's current frameworks only (SwiftUI, no
  UIKit in the app's views).
- **Open questions, each answered here:**
  - *Where does Settings go?* Where the slot plan puts it: the trailing
    end of region B, after the categories.
  - *What does Back to Talking close onto, while A's trailing column
    (Phrases and Type) is not built?* Emergency: Again moves into the
    safety row as the slot plan says, and the row is ordered Yes, No,
    Again, Emergency so Emergency is at the trailing end, under Back to
    Talking. The slot plan's regular order (Emergency first) waits for
    Phrases and Type, which are what Back to Talking is meant to close
    onto. Recorded in docs/DECISIONS.md, "Settings on Home".
  - *Is "Yes and No border the message" closed?* No, it is reduced (Again
    no longer sits beside the message, so less of the message is nearest
    a control that speaks) and stays open with a device check, recorded
    in docs/DECISIONS.md, "Settings on Home".

## Spec

Frames come from `HomeShape`, from the width Home is given and the
person's Bold Text setting, never from the device. Region order is
unchanged: A (the message), C (the safety row), B (the categories and
Settings), D (the phrase grid). Numbers below are content widths (the
window less Home's 16pt margins).

- **States:** Home's states (just opened, a category or the emergency
  phrases showing, a phrase just spoken, an audio warning) change no
  frame, Settings' included. Settings open is a full-screen cover; when
  it closes, every Home frame is where it was.
  - **A, the message,** spans the full width: Again leaves it. Until
    Family Setup has been opened once, the message area shows
    `FirstRunHint.text` in place of its placeholder; the first phrase
    spoken replaces either.
  - **C, the safety row.** One row, Yes, No, Again and Emergency, where
    five columns hold Again at its minimum width and Emergency, across
    two columns, at its own: Yes, No and Again share one width and
    Emergency takes the rest. Short of that, Again and Emergency at their
    minimums and Yes and No sharing the rest, down to their own minimum.
    Otherwise two rows: Yes, No and Emergency (across two of four
    columns), then Again across the width. Emergency is at the trailing
    end of the first row in every arrangement.
  - **B, the categories and Settings.** Settings is the last column,
    as tall as the category rows: every cell the same width where the
    categories keep their minimum, otherwise Settings at its minimum and
    the categories sharing the rest. Wide windows (from 560pt) try one
    row of four categories first, then two rows of two. Where the word
    "Settings" does not fit beside them but its gear does (a 375pt phone
    with Bold Text), Settings shows the gear alone, at Apple's 44pt
    minimum width, and keeps its name for assistive technologies. Where
    not even that fits (the narrowest windows), Settings takes a row of
    its own under two rows of two. A library with
    more than four categories scrolls inside the category rectangle;
    Settings never scrolls.
  - **Minimum widths** (default text size, measured with the real fonts;
    Bold Text measured at the heaviest weight): Yes and No 46 (48 with
    Bold Text, "Yes"), Again 64 (70), Emergency 116 (126), a category
    118 (128, "Conversation"), Settings 80 (86), each a point or a few
    over what its word needs; Settings' gear alone 44. Words step down to
    the default size at larger text sizes, never below, so the default
    size is the binding one.
  - **Where each arrangement applies:** one safety row from 296pt, with
    Yes and No narrower than Again below 332pt; Settings beside the
    categories with its word from 332pt and with its gear alone from
    296pt (Bold Text: one row from 316pt, Yes and No narrower below
    360pt; Settings' word beside from 358pt, its gear from 316pt). Four
    categories in a row from 584pt (Bold Text: 630pt). So every phone at
    its standard Display Zoom, with Bold Text or without, keeps one
    safety row and Settings beside the categories. Only 320pt windows
    (288pt of content: Slide Over on an iPad, and an iPhone with Display
    Zoom set to Larger Text) get the two-row safety row and Settings on
    its own row.
- **Input methods:** Settings is a standard `Button` with the label
  "Settings" (gear icon decorative; where the gear shows alone, the
  label is on the gear), Voice Control name "Settings" only,
  identifier `settings`. VoiceOver, Switch Control and Full Keyboard
  Access reach C first (Yes, No, Emergency, then Again, which is
  reached last in its region though it sits between No and Emergency),
  then A, then B (the categories, then Settings), then D.
  **What a held activation meets** (nearest centre and nearest edge,
  ties counted, on the frames above with the calibrated text sizes):

  | Window | After Back to Talking, today | After Back to Talking, now | Message nearest Yes, No or Again, today | Now |
  |---|---|---|---|---|
  | 402×874 phone | Again, both rules | Emergency, both rules | 94% centre, 89% edge | 66%, 61% |
  | 375×667 phone | Again, both | Emergency, both | 95%, 90% | 67%, 63% |
  | 13-inch iPad portrait | Emergency by centre, Again by edge | Emergency, both | 75%, 75% | 65%, 60% |
  | 13-inch iPad landscape | Emergency by centre, Again by edge | Emergency, both | 71%, 73% | 64%, 60% |
  | 320pt window | Again, both | Emergency, both | 97%, 92% | 56%, 51% |
  | 375×667 phone, Bold Text | Again, both | Emergency, both | 95%, 90% | 66%, 63% |

  After Settings opens, the spot where Home's Settings was is over
  Family Setup's row, which only opens the next screen. The first CI
  run showed this was not yet so: Settings' bar had stretched to about
  a third of the screen, putting Back to Talking over that spot. Round
  2 fixed the bar, moved Settings' sound line to the foot of the cover
  and put the root's row in the bar's trailing column wherever half the
  width holds its words (docs/DECISIONS.md, "Settings on Home").

  **The chain, two steps** (modelled from the first CI run's frames,
  with the bar at its natural height; the pointer at the centre of the
  control just activated, as in docs/DESIGN.md):

  | Window | After Home's Settings | After the root's Family Setup row |
  |---|---|---|
  | 402×874 phone, default | Family Setup, both rules | Set Up Step by Step, both; its first answer, Touch, is next (docs/HANDOFF.md) |
  | 402×874 phone, AX5 | Family Setup, both | Back to Talking by edge, the navigation bar's back button by centre (its frame is estimated); Set Up Step by Step is below the screen, under Family Setup's long opening |
  | 13-inch iPad portrait, default | Family Setup, both | Back to Talking by centre, Set Up Step by Step by edge |
  | 13-inch iPad portrait, AX5 | Family Setup, both | Back to Talking, both: Settings closes, and its spot is nearest Emergency |
  | 13-inch iPad landscape, default | Family Setup, both | Back to Talking by centre, Set Up Step by Step by edge |

  None of these speaks, alarms, deletes or changes a size. Where Back
  to Talking comes next, Settings closes and the look meets Emergency,
  which only shows the emergency phrases. With the root's row full
  width instead, the first step met Back to Talking on the iPads by
  centre. Breaking the second step needs Family Setup's first row
  where the root's row was, under Back to Talking, which is the
  Settings chain scoring in docs/HANDOFF.md.
- **Colours:** none new. Settings uses `HomeButtonStyle` with
  `Palette.controlFill`, pinned in `PaletteTests` like Home's other
  controls.
- **Privacy policy:** no sentence changes; Settings already holds the
  in-app Privacy row.
- **Screens:** Figma, page *Home*, section [Settings on Home (interim,
  2026-10-23)](https://www.figma.com/design/zCYdh8hSJ9ZmrVhtealp8f/?node-id=18-977):
  [iPhone 17](https://www.figma.com/design/zCYdh8hSJ9ZmrVhtealp8f/?node-id=18-980),
  [375×667 phone](https://www.figma.com/design/zCYdh8hSJ9ZmrVhtealp8f/?node-id=18-1022),
  [375×667 phone with Bold Text](https://www.figma.com/design/zCYdh8hSJ9ZmrVhtealp8f/?node-id=18-1063)
  (the first draft, with two safety rows and Settings on its own row;
  the built arrangement matches the 375×667 frame with narrower Yes
  and No and the gear alone in Settings' column),
  [13-inch iPad portrait](https://www.figma.com/design/zCYdh8hSJ9ZmrVhtealp8f/?node-id=18-1106)
  and [landscape](https://www.figma.com/design/zCYdh8hSJ9ZmrVhtealp8f/?node-id=18-1148),
  and Settings open over
  [the iPhone 17](https://www.figma.com/design/zCYdh8hSJ9ZmrVhtealp8f/?node-id=18-1190)
  and [the iPad](https://www.figma.com/design/zCYdh8hSJ9ZmrVhtealp8f/?node-id=18-1241),
  with the line from Back to Talking to Emergency. Wireframes in Inter
  (SF Pro does not render in the account), light mode only, drawn from
  the frames above by a model of the layout, not captured from the app.
  The owner accepts them by merging.
- **Concerns:**
  - *Yes and No still border the message.* Reduced, not removed: see
    the table. Recorded as open in docs/DECISIONS.md, "Settings on
    Home", with what decides it.
  - *A 320pt phone window loses more of its phrase grid.* An iPhone with
    Display Zoom set to Larger Text gives Home 288pt of content, where
    the safety row's words need two rows and Settings a row of its own:
    the grid, which already scrolled there (two columns, four rows of at
    least 99pt), drops from about 240 to 110pt on a zoomed 375×667 phone
    (320×568) and from about 315 to 190pt on a zoomed 6.1-inch one
    (320×693, safe areas estimated). Listed in docs/DECISIONS.md, *Where
    the grid still scrolls*, for the layout engine.
  - *Settings shows its gear alone on a 375pt phone with Bold Text.*
    The first draft kept its word and gave it a row of its own there,
    with a second safety row, and the phrase grid scrolled (tiles about
    64pt against a 99pt minimum); Codex's review caught it. Breaking a
    word would be worse than either, and the phrases outrank a family
    control's word. Now Bold Text takes no height from any phone's
    phrases (`HomeShapeTests`).
  - *The slot plan's own order in C* (Emergency first on wide windows,
    Get Attention at the trailing end) needs Phrases and Type in A's
    trailing column, where Back to Talking closes. Until they are
    built, the control nearest under Back to Talking must say nothing;
    `SettingsOnHomeTests` fails if it does not.

## Plan

- **Files that change** (all in this one pull request, by the Settings on
  Home thread):
  - `Brickson/Layout/HomeShape.swift`: the safety row's one- or two-row
    arrangement, Settings beside or below the categories, and the
    minimum widths, regular and Bold Text.
  - `Brickson/Home/HomeView.swift`: the message across the width with the
    first-run hint, `SafetyRow` (Yes, No, Again, Emergency) and
    `CategoriesAndSettings`; Home takes a binding to Settings' cover.
  - `Brickson/Settings/SettingsView.swift`: `SettingsButton` draws a
    fitted label in Home's button style, with its Voice Control name.
  - `Brickson/App/BricksonApp.swift`: one `showsSettings` state, opened by
    Home's button or at launch by `--screen=settings`.
  - `Brickson/Home/ControlNames.swift`, `Brickson/Home/HomeRegion.swift`:
    Settings' name; Again and Settings reached last in their regions.
  - Tests: `HomeShapeTests`, `StarterLabelFitTests`, `ControlNamesTests`,
    `HomeRegionTests`; UI: the new `SettingsOnHomeTests`, and
    `HomeAccessibilityOrderTests`, `HomeReachabilityTests`,
    `HomeLayoutTests`, `LaunchTests` (it measured the placeholder, which a
    first launch now replaces with the hint), `SettingsTests` (comment).
  - Docs: DECISIONS ("Settings on Home", notes in the Home sections),
    HANDOFF, ROADMAP item 7, ACCESSIBILITY (two rows), the log record.
- **Order of work:** the unit tests first (they fail against today's
  `HomeShape`, which has no safety-row or Settings arrangement), then the
  code, then the UI tests and the docs.
- **Risks, and how each is checked:**
  - *A word cut off in a narrower slot,* above all with Bold Text: the
    minimums come from measured words, `StarterLabelFitTests` checks each
    against SwiftUI's drawing with Bold Text off and on, and
    `HomeShapeTests` checks no width from 288 to 1400pt goes below them.
  - *New scrolling for the starter library:* `HomeLayoutTests` on CI's
    iPad (both orientations) and iPhone, default and largest text; the
    model's heights for other windows are in the Spec.
  - *Back to Talking or the Settings button landing on something that
    speaks:* `SettingsOnHomeTests`, both rules, on both devices, default
    and largest text, and every Home frame unchanged after the round trip.
  - *Scan order:* `HomeAccessibilityOrderTests` reads the order from the
    accessibility tree in every Home state.
  - *Cloud session:* nothing here was built for iOS before CI; the pure
    `HomeShape` and names tests ran on a Linux Swift toolchain first.
- **Proof** (each test, and the change that makes it fail):
  - `HomeShapeTests.everyControlKeepsItsMinimumWidth`: dropping the
    one-row condition (Emergency's minimum) fails it.
  - `HomeShapeTests.settingsSharesTheRowEquallyWhereTheCategoriesHaveRoom`
    and `phonesKeepOneSafetyRowAndSettingsBesideTheCategories`: removing
    the "Settings at its minimum" step puts Settings below on a 375pt
    phone and fails both.
  - `HomeShapeTests.wideWindowsShowTheFourCategoriesInOneRow` and
    `roomIsOnlyGivenUpAsTheWindowNarrows`: not trying two columns on wide
    windows fails both.
  - `HomeShapeTests.theRegionsFillTheWidthExactly`: a row that overflows
    by a gap (the two-row Emergency's first draft did) fails it.
  - `HomeShapeTests.boldTextTakesNoHeightFromAPhonesPhrases` and
    `phonesKeepOneSafetyRowAndSettingsBesideTheCategories`: removing the
    narrower Yes and No, or Settings' gear-only step, puts a row back
    on a 375pt phone with Bold Text and fails both;
    `yesAndNoNarrowBeforeTheSafetyRowSplits` fails without the first,
    `settingsShowsItsNameWhereItFits` without the second or with the
    gear tried before the word.
  - `StarterLabelFitTests.theFixedControlsFitTheirNarrowestWidths` and
    `everyStarterCategoryNameFitsTheNarrowestButton`: lowering a minimum
    below its word fails them.
  - `ControlNamesTests`: Settings left out of `fixed` fails
    `homeListsEveryControlOnTheScreen` and the pinned list.
  - `SettingsOnHomeTests`: Emergency anywhere but the safety row's
    trailing end, or Again back beside the message, fails the way out;
    a first launch without the hint, or a hint that stays after Family
    Setup, fails `testTheFirstRunHintShowsUntilFamilySetupOpens`.
  - `HomeAccessibilityOrderTests`: dropping `lastInRegion` from Again or
    Settings fails the order.
  - Device check added to docs/HANDOFF.md: whether Snap to Item and Dwell
    pick the nearest centre or the nearest edge, which decides the rest of
    "Yes and No border the message".
