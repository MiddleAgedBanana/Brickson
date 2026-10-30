# Sizes that follow how the person reaches the screen

*Roadmap: Wave 3 item 8 (R1, the profile layout engine and who chooses
the profile), started early by the owner on 2026-10-30. Owner: the
item 8 thread (a cloud session; GitHub CI is its build). Status:
built (CI green, merged in #69), then switched on when the owner chose
the largest sizes that fit, both on 2026-10-30.*

## Intent

- **Problem:** Home has one set of sizes, touch's: quick controls,
  categories and phrase tiles of at least 44 points, 8 points apart. A
  person who reaches the screen with their eyes, their head or a switch
  meets targets sized for a fingertip. The reference app, built for Eye
  Tracking, needed phrase tiles of at least 110 points on a 13-inch iPad.
  Family Setup already asks how the screen is reached (`SetupRecord`),
  but nothing reads the answer.
- **Proposed outcome:** Home's sizes and spacing follow Family Setup's
  answer. With no answer, Home has the largest sizes the window holds.
  Nothing on Home changes place relative to anything else when the sizes
  change, so a person who moves from touch to a switch to their eyes
  never relearns where anything is.
- **Who and what it affects:** people at stages 2 to 4 using Switch
  Control, Head Tracking, Eye Tracking or AssistiveTouch's Dwell; their
  families, who choose the answer; people on touch, whose iPad shows the
  larger sizes until someone answers. The layout engine (`HomeLayout`,
  `HomeReservedLayout`), a new plain type (`ProfileChoice`), Home,
  Settings over Home, Family Setup's first step, the app's root.
- **Constraints:** invariant 1 (standard buttons, at least the
  profile's floor), 8 (the arrangement never depends on the profile;
  only sizes and gaps do), 10 (chains of held activations scored at every
  profile), 11 (no scrolling for the starter library in a dwell, switch,
  head or gaze profile, and never a target below its floor to avoid it),
  *Layout on every device and window* (the profile comes from the
  answer and the window, never from the device), "Words never break",
  docs/DECISIONS.md, "Layouts from the space available" (floors held at
  163 points per inch, only the owner changes a floor), "Setup answers
  are kept as offered, never as completed" (the largest sizes when
  nobody answers) and "Accessibility API coverage" (what iOS reports may
  suggest an answer, never change one).
- **Open questions, each answered here:**
  - *How do several answers combine?* The largest sizes any of them
    needs. A person who touches the screen on good days and uses Eye
    Tracking on others needs targets their eyes can hold every day, and
    a larger target costs touch only room. (*Spec*, *The profile asked
    for*.)
  - *What are the switch and head floors?* Proposed below, as defaults
    the owner can overrule (*Spec*, *The floors*).
  - *What happens where a window cannot hold the sizes asked for?* The
    largest smaller sizes it holds, and touch's last. This changes the
    rule "the arrangement changes, never the floor" in docs/DECISIONS.md,
    "Layouts from the space available", so it is the owner's to accept:
    the decision card in the item 8 thread asks, with this as the
    recommendation and the alternatives (scroll at the larger sizes, or
    fewer tiles to a screen) (*Concerns*).
  - *Which answer does Voice Control get?* Touch's sizes. Voice Control
    names a control and needs no larger target; its numbered overlay
    fits touch's sizes.
  - *Is Switch Control's own the same as head tracking's?* Yes, for now.
    Item scanning moves a highlight from item to item, so size does not
    slow it down; point scanning (the gliding cursor) and Switch
    Control's head mode pick a point, as a head pointer does, so a
    switch user can need head tracking's targets. One profile each, so
    either can change on its own later.

## Spec

### The profile asked for

| Family Setup's answer | Sizes asked for |
|---|---|
| Touch, Voice Control, someone else helps | Touch's |
| Switch Control | Switch Control's |
| Head Tracking | Head tracking's |
| Eye Tracking | Eye Tracking's |
| Several of these | The largest any of them asks for |
| No answer, never given or cleared | Eye Tracking's, the largest |

`ProfileChoice.requested(by:)` makes this choice from
`SetupRecord.plannedAccessMethods`, and nothing else. What iOS reports
about VoiceOver and Switch Control never changes it (*Family Setup's
first step*).

### The floors

Floors are physical sizes held at the densest supported screens, about
163 points per inch (docs/DECISIONS.md, "Layouts from the space
available"). Angles are at 46 cm (about 18 inches), the distance Apple's
Eye Tracking and Head Tracking guides give.

| Profile | Phrase tiles | Quick controls | Categories | Gap between controls | Where the sizes come from |
|---|---|---|---|---|---|
| Touch | 44 pt (7 mm) | 44 pt | 44 pt | 8 pt | Home's sizes until now, unchanged |
| Switch Control | 110 pt (17 mm, about 2.1°) | 88 pt (14 mm, 1.7°) | 72 pt (11 mm, 1.4°) | 12 pt | The same as head tracking's, for point scanning and Switch Control's head mode |
| Head tracking | 110 pt (17 mm, about 2.1°) | 88 pt (14 mm, 1.7°) | 72 pt (11 mm, 1.4°) | 12 pt | **Proposed, the owner can overrule.** The reference app's gaze numbers taken as points at the densest screen |
| Eye Tracking | 136 pt (21 mm, about 2.6°) | 109 pt (17 mm, 2.1°) | 89 pt (14 mm, 1.7°) | 15 pt | The reference app's 110, 88 and 72 points on a 13-inch iPad (about 132 points per inch), held at 163 |

Why head tracking's numbers are these, from the research read for this
item (the sources are in the log):

- In a study of head pointing on an iPhone, where one point is 1/163 of
  an inch, the share of correct selections was 0.70 for targets 44
  points wide, 0.83 for 88 and 0.89 for 106 (Roig-Maimó and others,
  2016). The proposal puts phrase tiles at 110 and quick controls at 88,
  the two widths that did well, and nothing at 44.
- With dwell, head pointing's effective target width was about 2 to 2.5
  degrees (Hansen and others, 2018); 110 points at 46 cm is about 2.1.
- A gap of 12 points is the padding Apple's Human Interface Guidelines
  give around controls with a bezel ("about 12 points of padding").
  Eye Tracking's 15 points keeps the reference app's spacing in
  proportion with its targets.
- Apple publishes no target size, dwell time or accuracy for Eye
  Tracking, Head Tracking or Switch Control. So these are proposals, to
  be checked on a device with the person (*Concerns*).

### Where each profile holds

`ProfileChoice.layout(requested:space:text:largestCategory:modes:)` gives
Home's layout: the sizes asked for if the window holds them, else the
largest smaller sizes it holds, Eye Tracking's, then head tracking's
(Switch Control's are the same), and touch's last. A profile holds in a
window (`HomeLayout.holdsProfile`) when every control and every tile is
at least its floor in both directions, every width test that chose the
arrangement at touch's gap still passes at the profile's own gap
(`arrangementHoldsItsWords`: a wider gap narrows the columns, and no
column may be narrower than its words), the starter library fits without
scrolling, and nothing overlaps; and it is taken only where it keeps
everything touch's sizes have there: the same arrangement and columns,
typing, and every word of the message and of Settings' name
(`ProfileChoice.keepsEverything`).

With Eye Tracking's sizes asked for, as they are until anyone answers
(measured by `ProfileChoiceTests.theWindowsPeopleUseTakeTheSizesTheTableSays`,
the same with Bold Text off and on but for the iPad mini in portrait):

| Window | Default | xxxLarge | AX1 | AX3 | AX5 |
|---|---|---|---|---|---|
| Every phone tested (iPhone 17, 17 Pro Max, 16e, 375×667, 320×568) | Touch | Touch | Touch | Touch | Touch |
| 13-inch iPad, portrait and landscape | Eye | Eye | Eye | Eye | Eye |
| 11-inch iPad and iPad mini, portrait | Eye | Eye | Eye | Eye | Eye |
| iPad mini, portrait, Bold Text | Head | Head | Head | Head | Head |
| 11-inch iPad, landscape | Head | Head | Head | Head | Touch |
| 13-inch iPad, landscape, zoomed (1032×774) | Touch | Touch | Touch | Head | Touch |
| iPad mini, landscape | Touch | Touch | Touch | Touch | Touch |

No phone holds even head tracking's sizes: the starter library is 84 to
635 points short there (the iPhone 17 Pro Max least, a zoomed 375×667
phone most), and 304 to 871 at Eye Tracking's. On the iPad mini in
landscape head tracking's are 30 to 58 points short. On the 11-inch
iPad in landscape at AX5, head tracking's hold but leave the safety row
too tall for the keyboard's room, so typing would be lost; touch's keep
it. With head tracking's or Switch Control's asked for, each window
takes the table's sizes, capped at those. With Bold Text on the iPad
mini in portrait, Eye Tracking's 15-point gap leaves five columns of
130.4 points where the widest bold word needs 132, so head tracking's
are taken.

### Home

- **Places.** Every profile has the window's own arrangement, chosen at
  touch's gap: whether Home is regular or compact, how the categories
  sit (a band, three columns or two), and the grid's columns. Only
  sizes and gaps change. Every control stays in the same region, row
  and place in its row (`ProfileChoiceTests.noControlChangesPlaceBetweenProfiles`,
  over 10,000 layouts: every width from 320 to 1432 points in steps of
  8, six heights, three text sizes, Bold Text off and on, both modes).
- **When the sizes change.** Only when Settings closes. Home and
  Settings read the sizes asked for when Settings last closed, so an
  answer chosen in Family Setup moves nothing under the person while
  Settings is open: Settings' places are worked out from Home's frames
  (docs/DECISIONS.md, "Settings' first row, placed from Home's
  frames"). Home then shows the new sizes as Settings closes.
- **Back to Talking** keeps touch's frame at every profile, so a look
  still resting on it after Settings closes onto other sizes meets
  Phrases, which only switches what Home shows (*Changed during the
  build*).
- **A fold or a camera across Home** (iPhone Duo; docs/DECISIONS.md,
  "iPhone Duo") keeps touch's sizes, because no fold check has measured
  larger ones there.
- **Text size** changes the sizes too, through the engine, as before:
  at larger text the controls grow past the floors, and a window can
  fall to smaller sizes (the table).

### Family Setup's first step

- A new sentence after the first line says what the answer does:
  "Home's buttons take the size the answers need, as large as this
  screen has room for, and are largest until something is chosen. The
  new size shows when Settings closes." It shows only once Home follows
  the answer (*Changed during the build*).
- Where iOS reports Switch Control on: "Switch Control is on, so Switch
  Control may be one of the answers." Otherwise, where VoiceOver is on:
  "VoiceOver is on, so Touch may be one of the answers." Nothing is
  chosen or changed by it (`ProfileChoice.suggestion`), and the words
  depend only on what iOS reports, never on the answers, so nothing
  moves as an answer is chosen. Read with SwiftUI's
  `accessibilitySwitchControlEnabled` and `accessibilityVoiceOverEnabled`
  (iOS 15 and later, so no `#available`).
- The answers start below the new words, as they started below the
  question (`SetupAnswersPlace`, whose `earliest` is measured under
  them); the chain model counts the sentence's height once it shows
  (`SettingsChainsTests.SweptFamilySetup`).

### Input methods

- **Touch, Voice Control, Full Keyboard Access, VoiceOver:** the same
  standard buttons in the same order; larger where the sizes are
  larger. Nothing new to reach.
- **Dwell, head, gaze and switch auto-select:** chains of held
  activations are scored on every larger profile's frames, browsing and
  typing, by nearest centre and nearest edge, over the windows where each
  holds, and meet nothing touch's frames do not already meet
  (`ProfileChoiceTests.noChainAtALargerProfileMeetsANewHazard`). Settings
  over a larger Home is scored too, and closes nothing and saves nothing
  under a held look
  (`noSettingsChainOverALargerProfileClosesSettingsOrSavesAnAnswer`).
  The open hazard of Yes and No bordering the message stays within
  touch's worst pinned shares (68% by centre and 62% by edge on regular
  widths, 97% and 89% on compact ones) at the larger sizes, a bound,
  not a window-by-window comparison
  (`yesAndNoBorderNoMoreOfTheMessageAtALargerProfile`); it is not
  removed, and neither are the top of Stop's well nearest Again and the
  dimmed phrases bordering Clear and Put Back by centre (*Concerns*).

### Colours, privacy policy and screens

- **Colours:** none new.
- **Privacy policy:** one sentence changes. *How you control the app*
  said Brickson "only learns which button you chose"; the first step
  now also reads whether VoiceOver or Switch Control is on, to suggest
  an answer, so the sentence says that, and that it stays on the
  device. The answer was already kept on the device; it is now also
  read there.
- **Screens:** see *Screens drawn* below.

### Screens drawn

[Sizes that follow reach (Wave 3 item 8)](https://www.figma.com/design/zCYdh8hSJ9ZmrVhtealp8f/?node-id=170-688), drawn
from the layout engine's frames (`ProfileChoice.layout`), not from a
running app; labels in Inter at the default size, so fits are estimates:

- [13-inch iPad portrait, touch sizes](https://www.figma.com/design/zCYdh8hSJ9ZmrVhtealp8f/?node-id=170-689)
- [13-inch iPad portrait, Eye Tracking sizes](https://www.figma.com/design/zCYdh8hSJ9ZmrVhtealp8f/?node-id=170-744) (no answer
  yet, or Eye Tracking)
- [13-inch iPad portrait, positions never move](https://www.figma.com/design/zCYdh8hSJ9ZmrVhtealp8f/?node-id=171-90): touch's
  frames and Eye Tracking's over each other, with Settings' Back to
  Talking
- [11-inch iPad landscape, touch sizes](https://www.figma.com/design/zCYdh8hSJ9ZmrVhtealp8f/?node-id=170-813)
- [11-inch iPad landscape, head tracking and Switch Control sizes](https://www.figma.com/design/zCYdh8hSJ9ZmrVhtealp8f/?node-id=170-882)
  (where Eye Tracking's are asked for, this window takes these)
- [iPhone 17, touch sizes for every answer](https://www.figma.com/design/zCYdh8hSJ9ZmrVhtealp8f/?node-id=170-951)

The first step's new words are written out on the page, not redrawn.
Not yet accepted by the owner: the owner's merge accepts them.

### Concerns

- **The fallback is the owner's to accept.** "Layouts from the space
  available" said that where a window cannot hold a profile's floors,
  the arrangement changes, never the floor. Taking smaller sizes keeps
  every place and every floor of the sizes taken, but it is a smaller
  target than the answer asked for, on the iPad mini in landscape and
  on every phone. Recommended and built; the alternatives are scrolling
  at the sizes asked for (invariant 11 rules it out for the starter
  library) or fewer tiles to a screen (a new arrangement, which item 9's
  fewer-tiles work would bring). The owner chose it on 2026-10-30
  (*Changed during the build*).
- **Yes and No still border the message.** The open hazard from item 4
  (docs/DECISIONS.md, "Home's slot plan", *Open hazard, not accepted*)
  stays: a look resting on the message is nearest Yes or No over up to
  97% of it by centre on compact windows. At the larger sizes, in every
  window swept where they hold, the share stays within touch's worst
  case (a bound, measured; not window by window: at head tracking's
  sizes it is up to about a point more than touch's in the same window,
  at Eye Tracking's never more), but the roadmap says no dwell, switch,
  head or gaze size ships until it is gone or the owner accepts it. The
  same holds for the other two hazards the chain tests allow at every
  profile: the top of Stop's well nearest Again, and dimmed phrases
  bordering Clear and Put Back by centre. So this pull request adds all
  three to R0's *Release gate*: no build with the larger sizes goes to
  an external TestFlight group or App Review until each is gone or the
  owner has accepted it.
- **An iPad on touch shows larger sizes until someone answers**, once
  the sizes are switched on. That is the existing decision ("the
  largest sizes when nobody answers"); the first step's new sentence
  tells the family.
- **The floors are proposals from studies, not from people with ALS.**
  None of the studies tested Apple's own Eye Tracking or Head Tracking,
  or people with ALS. A device check with a person using each method
  comes before the larger sizes go to App Review (*Proof*).
- **Simulator evidence only.** Comfort, Snap to Item and where a pointer
  rests need a real device (a Codex handoff).
- **The first step's question heights on CI predate the new sentence.**
  `SettingsChainsTests.SweptFamilySetup` models the sentence's height;
  CI's measured frames, pinned in the chain tests, were taken before it.
  From the pull request that switched the sizes on, every Settings UI
  test draws the sentence (it follows the owner's switch, not a test's
  fixed sizes), so the first step's audit and `SettingsOnHomeTests`'
  measured chains include it; the pinned heights in `ModelledWindow`
  are compared with that run's captures in a later pull request.

## Plan

- **Files that change:** `HomeLayout.swift` (each profile's floors and
  gaps; `holdsProfile`; Back to Talking at touch's frame),
  `HomeReservedLayout.swift` (each kind's floor), `ProfileChoice.swift`
  (new), `HomeView.swift`, `SettingsView.swift`, `SetupGuides.swift`,
  `BricksonApp.swift` (the profile asked for, frozen while Settings is
  open), `GuidedSetupView.swift` (the sentence and the suggestion),
  `LaunchOptions.swift` (a debug-only `--home-profile`), the String
  Catalog; tests `ProfileChoiceTests` (new), `SettingsRowPlaceTests`,
  `ChainEngineTests`, `LaunchOptionsTests`, the UI tests'
  `LaunchHelpers` and `HomeSizesTests` (new).
- **Order of work:** one pull request: this file, then the code and
  tests, then the records (docs/DECISIONS.md, docs/ROADMAP.md,
  docs/HANDOFF.md, docs/ACCESSIBILITY.md, AGENTS.md, a `docs/log/`
  file).
- **Risks:** touch's layouts changing by accident (every existing
  engine test runs at touch and passes unchanged); a profile taken where
  it scrolls or loses typing (`aProfileHoldsOnlyWhereEveryFloorIsMet`,
  `theLargestProfileThatHoldsIsTaken`); UI tests written for touch's
  frames failing at the larger default (UI tests launch at touch's
  sizes unless they ask, `--home-profile`, debug and test storage only).
- **Proof:**
  - `ProfileChoiceTests`, each with the change that makes it fail:
    - the profile asked for: no answer, each answer, all 63 sets of
      answers, and the flags (fails if any maps to other sizes, or if a
      flag changes the profile);
    - the floors and gaps (fails if a floor or gap changes);
    - `noControlChangesPlaceBetweenProfiles` (fails if the arrangement
      is chosen at the profile's own gap: first at 680×568 at Switch
      Control's sizes);
    - `aProfileHoldsOnlyWhereEveryFloorIsMet` (fails if the width check
      is dropped: Yes 81 points wide at 392×874);
    - `theLargestProfileThatHoldsIsTaken`, the windows table, the dwell
      chains, Settings closing onto other sizes, the Yes and No share,
      Settings' chains over a larger Home, and a fold or a camera.
  - `HomeSizesTests` (UI, both families): launched as a person launches
    it, fails if an iPad in portrait shows Home smaller than Eye
    Tracking's floors before any answer, a phone shows other frames than
    touch's, the first step does not say what the answers do, or Home
    stays larger after Touch is chosen and Settings closes; and, at the
    default and the largest text size, light and dark, if Apple's
    accessibility audit finds anything or a control's words are not
    drawn whole (the quick controls everywhere, and Phrases, Type and
    the everyday categories at the larger sizes).
  - Device checks (Codex, and the owner's devices): which flags each
    input method turns on; dwell comfort at each profile's floors on an
    iPad with Eye Tracking and Head Tracking, and with Switch Control's
    point scanning; Snap to Item.

## Changed during the build

*2026-10-30.* Each profile first had its own Back to Talking frame in
Settings. Measured, a look resting on it after an answer changed the
sizes met Type at its foot, and on windows 1352 to 1416 points wide, by
nearest centre, Get Attention or Again. Back to Talking now keeps
touch's frame in every profile, and every point of it is nearer Phrases,
by centre and by edge, than any other control on every Home it can
close onto (`closingSettingsOntoOtherSizesMeetsOnlyPhrases`); on
compact widths it reaches a few points past a larger profile's Phrases,
into the gap toward the message.

*2026-10-30, after the first push.* Codex's review of PR #69 found that
taking smaller sizes where a window cannot hold the ones asked for is
an exception to invariant 11's floors, active while the owner has not
accepted it. So the sizes are held: `ProfileChoice.followsTheAnswer` is
off, Home asks for touch's sizes for every answer, the first step's
sentence on sizes is hidden, and only UI tests on test storage follow
the answer (`--home-profile=from-answer`). Everything above is built
and checked on every CI run; one pull request turns the switch on once
the owner chooses the largest sizes that fit (docs/DECISIONS.md, "Sizes
that follow how the screen is reached", *Switched on by the owner*).

*2026-10-30, after #69 merged.* The owner chose the largest sizes that
fit, and the next pull request switched them on
([`log/2026-10-30-sizes-switched-on.md`](../log/2026-10-30-sizes-switched-on.md)).
Whether Back to Talking keeps touch's frame under them was asked
separately, since the card about the fallback did not ask it; it is
built as recommended until the owner answers.

*2026-10-30, after the first push.* CodeRabbit's review, and the
independent review, found that the arrangement chosen at touch's gap
could leave a larger profile's columns narrower than their words: at
680×744 at Switch Control's sizes, categories 120 points wide where the
widest needs 122 (1,042 such cases across the swept windows). A profile
now holds only where every width test that chose the arrangement passes
at its own gap too (`HomeLayout.arrangementHoldsItsWords`), checked
slot by slot against the words' minimums
(`aProfileHoldsOnlyWhereEveryWordFitsAsAtTouchsSizes`). The only window
in the table it changes is the iPad mini in portrait with Bold Text,
which takes head tracking's.
