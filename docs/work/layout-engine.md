# The layout engine

*Roadmap: docs/ROADMAP.md, Wave 3 item 3, "The layout engine, with no
screen change yet" (R0 item 3, and R1's profile layout engine); this
file also covers items 4 (Home on the engine) and 6 (Home on iPhone Duo,
in every pose). Owner: the Layout engine thread. Items 3, 4 and 5 are
built. Item 6 is in design from measured reservations; its earlier
horizontal-scrolling blocker is withdrawn. The owner confirmed keeping
the current rule and investigating another design. The original engine
spec is kept as history; the dated item 6 section is the current
continuation.*

## Intent

- **Problem:** Home's sizes come from a stand-in (`HomeShape`) with
  fixed numbers chosen one window at a time, and it does not hold the
  slot plan the design settled (docs/DECISIONS.md, "Home's slot plan"):
  Phrases and Type beside the message, the safety row in one row on wide
  windows, wells that keep their frames. On several windows the starter
  phrases scroll at the default text size (a 375×667 phone, iPhone Duo's
  outer display, an 11-inch iPad and an iPad mini in landscape), which
  invariant 11 forbids, because scrolling costs a dwell, switch, head or
  gaze user several activations each time. Nothing yet says, for a given
  window and text size, whether the starter library can fit at all, or
  which windows cannot, so every Home change rediscovers it on CI.
- **Proposed outcome:** one plain, tested function turns the space a
  window gives Home (its size, its safe areas, and regions the system
  reserves, such as a fold), the input profile, the text size and the
  library's shape into a frame for every slot on Home. It says whether
  the starter library fits without scrolling, whether the safety row
  stays above Apple's keyboard, and which slots a reserved region
  crosses. Its tests show, before any screen uses it, where the starter
  library fits and where it cannot, with the numbers. Home moves onto it
  in the next pull request (item 4); typing (item 5) and iPhone Duo
  (item 6) build on it. Nothing a person sees changes in this one.
- **Who and what it affects:** every person, on every input method and
  window, once item 4 puts Home on it; today, nobody: it is code and
  tests that nothing on screen calls. `Brickson/Layout` gains the engine;
  `BricksonTests/Layout` its tests. `HomeShape` stays until item 4
  replaces it.
- **Constraints:** invariant 1 (every target at least 44×44pt, larger
  where the profile's floor is higher), 2 and 10 (Yes, No, Emergency and
  Get Attention one activation from every Home state, above the
  keyboard; a held look scored after each control), 8 (positions never
  follow usage, time or Home's state; a well keeps its frame), 11 (no
  scrolling for the starter library; never a target below its floor to
  avoid it), AGENTS.md *Layout on every device and window* (nothing that
  names a device), *Words never break*, and the decisions "Layouts from
  the space available", "Home's slot plan", "Home's stand-in layout",
  "Get Attention and Stop on Home", "Settings on Home", "Typing is a
  state of Home" and "iPhone Duo".
- **Open questions, each answered in the spec:**
  - *What is the touch profile's floor, and what are today's sizes?*
  - *Where does each slot go when the slot plan meets the decisions made
    after it?* Get Attention and Stop on Home put Get Attention directly
    under Emergency, which the slot plan's two-row safety row does not.
  - *Which windows can hold the starter library without scrolling, and
    at which text sizes?* And what happens where none can.
  - *How does the engine take a fold?* The original plan waited for R0
    item 13's look. The 2026-10-25 Mac checks below now provide open and
    partial-pose evidence; the horizontal scrolling case remains open.

## Spec

What the engine decides, and its answers to the open questions above.
Nothing on screen changes in this pull request: `HomeLayout` is a plain
type that nothing calls yet, and Home moves onto its frames in item 4.

- **Inputs:** the window's size, its safe areas and the regions the
  system reserves in it; the input profile (touch is the only one until
  R1, Wave 3 items 8 and 9); one line of each of Home's label styles at
  the person's text size, and whether Bold Text is on; and the library's
  largest category. Never a device, a size class, the orientation or the
  idiom. Home's state is not an input, so every slot has the same frame
  in every state (invariant 8).
- **States:** none added. Again's slot shows Speak while typing (item 5),
  Stop's well is empty until an alarm sounds, and Phrases and Type keep
  their frames once chosen.
- **The arrangements** (*Where does each slot go when the slot plan meets
  the decisions made after it?*), chosen from the width alone:
  - *Compact*, below 664 points (714 with Bold Text). A: the message over
    two columns, Phrases above Type in the trailing column, which is at
    least as wide as Emergency's word. C: Yes, No and Emergency, then
    Again over two columns and Get Attention directly under Emergency:
    "Get Attention and Stop on Home" put it there, and it wins over the
    slot plan's one-row safety row on these widths. B: Stop's well and two
    categories, then two categories and Settings (two columns of three
    rows where three columns leave Stop too little). D: three columns of
    tiles, two where three would break "understand.".
  - *Regular*, from 664 points (714): the slot plan's own. C in one row,
    Emergency, Yes, No, Again, Get Attention; the message over the first
    three columns and Phrases above Type over the last two; Stop's well
    directly under Emergency with the first category under it, the other
    three categories and Settings at the band's full height; four columns
    of tiles.
  - The line between them is where five equal columns each hold the
    widest word one column carries (Emergency's: 120 points, 130 with
    Bold Text). Today's stand-in switches at 592 points, so windows 592
    to 663 points wide (iPad multitasking) move to the compact
    arrangement.
- **Sizes** (*What is the touch profile's floor, and what are today's
  sizes?*):
  - The touch floor is Apple's 44 by 44 points, about 6.9 mm on the
    densest supported screens. A control is also never shorter than one
    line of its words at the person's text size with 6 points above and
    below, so no label steps down a size to fit a height (Apple's audit
    reports that as text that does not follow Dynamic Type).
  - Where the window has room once the starter library's largest
    category (eight phrases) fits at the floors, sizes grow toward
    today's in this order: the gaps between regions from 10 to 12 points,
    the safety row to 64 points (88 on regular widths), the categories to
    48 (72). The phrase grid takes the rest. The gap never goes below 10,
    so it stays more than the 8 points between controls by more than the
    half point the chain checks count as a tie.
  - The safety row never grows into the keyboard's room
    (`KeyboardAllowance`): it gives back its growth, then the gaps. A
    category is never taller than the safety row, which keeps the
    category under Stop's well nearer the well than Emergency above it.
  - The controls are sized for the starter library's largest category. A
    larger library scrolls at the tile floor; a smaller one gets taller
    tiles; no control moves with the library.
  - Tile floors: compact 107 points wide (118 with Bold Text) and 99
    tall, the tallest starter phrase in four lines; regular 131 (146) by
    100, three lines at the narrowest four-column tile (152 points). The
    message is at least as wide as "understand." in its font at the
    default size: 156 points (175).
- **Where the starter library fits** (*Which windows can hold the starter
  library without scrolling, and at which text sizes?*). Predicted from
  Apple's SF Pro measured on Linux; `HomeLayoutEngineTests` pins the
  table and `HomeLayoutEngineFontTests` checks its text sizes against
  `LabelFont` on CI.

  | Window | Fits through | With Bold Text | Safety row above the keyboard through |
  |---|---|---|---|
  | iPhone 17, 402×874 | AX1 | AX1 | AX5 |
  | iPhone 17 Pro Max, 440×956 | AX3 | AX3 | AX5 |
  | iPhone 16e, 390×844 | AX1 | default | AX5 |
  | 375×667 phone | default, every control at its floor | none (27 points short) | AX1 |
  | 375×667 phone with Display Zoom, 320×568 | none (65 points short) | none | default |
  | iPads, 13-inch, 11-inch and mini in portrait, 13-inch and 11-inch in landscape | AX5 | AX5 | AX5 |
  | 13-inch iPad in landscape with Display Zoom, 1032×774 | AX5 | AX5 | AX1 |
  | iPad mini in landscape | AX3 (5 points short at AX5) | AX3 | AX1 |

  Better than today's stand-in: the 375×667 phone fits again at the
  default size, and every iPad fits at every size but the mini in
  landscape at AX5. It cannot fit phones at AX3 and AX5 (the iPhone 17
  is 5 and 38 points short), where every control holding one line of its
  words leaves too little for three rows of tiles, or 320-point windows
  at any size. Those stay the known gap, "the phrase grid scrolls
  (invariant 11)", until an arrangement with fewer tiles to a screen
  (docs/DECISIONS.md, "Layouts from the space available"), never by
  shrinking a target. iPhone Duo's displays are not in the table: their
  windows have not been measured (item 6).
- **Input methods** (invariant 10). Every rule is scored on frames at
  every width from 320 to 1432 points, every 4, at six heights, three
  text sizes, Bold Text off and on, by nearest centre and nearest edge,
  ties within half a point counted, by the chain engine's rules
  (docs/DECISIONS.md, "One chain engine for dwell safety"; since
  2026-10-24, when main brought it in):
  - After Get Attention, never Stop or a control that speaks. After
    Stop, only a category. After Phrases or Type, nothing that speaks,
    raises or ends the alarm (on short windows at large text sizes,
    Emergency, which only shows the emergency phrases). A look on the
    message never meets Get Attention or Stop.
  - *Yes and No border the message* (docs/DECISIONS.md, "Home's slot
    plan"), measured: with Phrases and Type beside the message, Yes and
    No are nearest up to 97% of it by centre and 89% by edge on compact
    widths (phones at the default size 88 to 90% and 75 to 81%), and up
    to 68% and 62% on regular widths (iPads 67% and 54 to 60%), up from
    today's 56% and 50%, where the message spans the width. No placement
    inside the slot plan removes it: something in C must border the
    message, and every control in C must be one activation away. It is
    invariant 10's, so it is the owner's to accept or reject, before the
    slot plan ships in a dwell, switch, head or gaze profile.
  - *The top of Stop's well is nearest Again* on compact widths, as
    today; on windows narrower than 375 points with Bold Text, the well's
    top leading corner ties Yes by centre too. On regular widths
    Emergency is above the well and nothing that speaks is nearest it.
    *2026-10-24, item 4:* Yes is nearest no point of the well in either
    arrangement; where the safety row is short the categories sit lower
    (`HomeLayout.wellDrop`).
  - Whole chains of held activations, by the chain engine on the
    engine's frames (`HomeChains`, with Phrases and Type added), in every
    Home state, at widths every 16 points and both sides of each change
    of arrangement, at a phone's and an iPad's height, three text sizes,
    Bold Text off and on: nothing but the well's hazard above, and that
    only on compact widths.
- **A fold** (*How does the engine take a fold?*): it takes the reserved
  regions and reports which slots they cross, and moves nothing for
  them. How Home keeps clear of a fold waits for R0 item 13's look at
  the open iPhone Duo (docs/DECISIONS.md, "iPhone Duo", *The fold*);
  item 6 builds it on this.
- **Colours, privacy policy, screens:** none. Nothing is drawn, so no
  Figma frame is needed (docs/SDLC.md, *Design*); item 4 checks Home on
  the engine against the Figma file.
- **Concerns**, each recorded in docs/DECISIONS.md, "The layout engine":
  - *The message on the narrowest windows.* Below 345 points with Bold
    Text on, the message beside Phrases and Type is narrower than
    "understand." in its font at the default size, so the word would
    break. Proposed: a known limit, until item 4 gives 320-point windows
    their own arrangement.
  - *Bold Text tiles on 375 and 390-point phones.* Today's Home gives
    their tiles 109 and 114 points, too narrow for "understand." with
    Bold Text (118 needed), so the word can break there today. The engine
    keeps words whole and gives those windows two columns, so with Bold
    Text the starter library scrolls on the 375×667 phone and fits the
    iPhone 16e only at the default size. A tile floor that follows the
    tile's width (two-column tiles need three lines, not four) would win
    some of that back; proposed for item 4.
  - *Compact up to 663 points.* Windows from 592 to 663 points wide lose
    the regular arrangement, because its one-row safety row needs five
    columns of Emergency's width.

## Plan

- **Files that change**, all owned by the Layout engine thread for item
  3:
  - `Brickson/Layout/HomeLayout.swift`: the engine, pure, Foundation
    only, so its tests also run with Swift on Linux.
  - `Brickson/Layout/HomeLayoutText.swift`: one line of each label style
    from `LabelFont`, the engine's only link to the fonts.
  - `BricksonTests/Layout/HomeLayoutEngineTests.swift`: the rules on
    frames, with no fonts. `HomeLayoutTests` is already the UI test that
    checks the running Home, hence the name.
  - `BricksonTests/Layout/HomeLayoutEngineFontTests.swift`: the engine's
    text sizes and widths against the real fonts (CI only).
  - `BricksonTests/Layout/StarterLabelFitTests.swift`: its two fit
    helpers shared with the font tests, unchanged otherwise.
  - docs/DECISIONS.md, docs/HANDOFF.md, docs/ROADMAP.md,
    docs/ACCESSIBILITY.md, docs/PORTING.md, AGENTS.md and a record in
    docs/log/.
- **Order of work:**
  1. Item 3, this pull request: the engine and its tests, no screen
     change.
  2. Item 4: Home reads its frames from the engine and `HomeShape` goes.
     Its spec adds the arrangement for 320-point windows and the message
     there, the tile floor that follows the tile's width, the Bold Text
     tiles, and Back to Talking over Phrases' frame (docs/DESIGN.md);
     its UI tests pin the frames on CI's iPhone and iPad at default and
     AX5; it is checked against the Figma file; and the owner answers
     *Yes and No border the message* before R1's profiles.
     *Built 2026-10-24*
     ([`log/2026-10-24-home-on-the-layout-engine.md`](../log/2026-10-24-home-on-the-layout-engine.md)):
     Home on the engine without Phrases and Type (`HomeLayout.Modes`),
     the tile floor that follows the width, the Bold Text tiles, the
     selected categories' inset, Get Attention's two lines, and Yes
     kept off Stop's well (found by Codex in review). Left
     for later: the arrangement for 320-point windows and phones at
     the largest sizes (a design question); Back to Talking over
     Phrases' frame and the Figma check (item 5, which brings
     Phrases); the UI tests check what the engine predicts on CI's
     windows, not each frame; the owner's answer is still to come.
  3. Item 5, typing on Home, on the engine's frames: Speak in Again's
     slot, the message as the typing field, the keyboard's room.
  4. Item 6, iPhone Duo in every pose, once R0 item 13 has looked at the
     open device: the engine moves slots off reserved regions.
- **Risks:**
  - The text sizes in the pure tests come from Apple's fonts measured on
    Linux, which matched CI to half a point before; one point off at a
    size would move a window in the table. Checked on CI by
    `thePureTestsTextSizesAreTheRealOnes`.
  - The new minimum widths and tile floors are predictions until CI
    draws them; `HomeLayoutEngineFontTests` checks each with UIKit and
    SwiftUI.
  - The sweep scores about ten thousand layouts: 19 seconds in a Linux
    debug build. If CI finds it slow, the sweep's step grows, not its
    range.
- **Proof.** Each test with a change that made it fail when tried
  (docs/LESSONS.md, "A check that cannot fail is not a check"):
  - Categories grow past the safety row after the keyboard cut:
    `aCategoryIsNeverTallerThanTheSafetyRow`,
    `aHeldLookAfterStopMeetsACategory`.
  - The safety row grows into the keyboard's room: `growthStopsAtTheKeyboard`.
  - The gap between regions falls to the 8 points between controls: the
    Stop, Phrases and Type chain tests and
    `roomGoesToTheGapsThenTheSafetyRowThenTheCategories`.
  - Get Attention swaps places with Emergency:
    `compactPutsGetAttentionDirectlyUnderEmergency`.
  - Get Attention swaps places with Again on compact widths: the chain
    test, `noChainOnTheEnginesFramesMeetsAHazardButStopsWell` (Get
    Attention, then Stop).
  - The grid never scrolls, or claims the starter library always fits:
    `onlyTheGridFollowsTheLibrary`, `theShortfallIsReported`.
  - Floors ignore the person's text size:
    `controlsHoldOneLineOfTheirWords`.
  - No device check is added: nothing on screen changes.

## Item 6: fold and camera design, 2026-10-25

### Intent and evidence

PR #56 merged as `6d040d5`, clearing this job's alarm-path prerequisite.
This work starts from its new Settings placement and accepted chain
limits. The first design pass changed no Home or Settings implementation;
the linked Spec/drawings then preceded the local Home implementation below.

[PR #55's dated Mac record](https://github.com/MiddleAgedBanana/Brickson/blob/cb4c965/docs/log/2026-10-25-mac-keyboard-checks.md)
measured app code `8316743`, before PR #56. In Device Hub the closed
window was 466×678; the open inner window was 951×669 wide and 669×951
tall. Open-wide AX5 showed four whole phrases and scrolled 10pt; open
tall fit eight at default/AX4/AX5. The Hub's partial pose reported 130°;
tall default/AX5 fit eight, and wide dark default/AX5 matched the open
wide counts. The rendered wide fold crossed No, Conversation and phrase
tiles. Existing open-Duo Home tests had eight passes, nine failures and
two landscape skips. The record distinguishes frame-API disagreements
from a pre-#56 Settings chain finding. The later item 6 regressions and
native Back checks below use #56's placement; the earlier full-suite
failures are not relabeled as passing.

Follow-up measurements on app code `6d040d5` now record the system's exact
[reserved rectangles and safe areas](../evidence/2026-10-25-duo-design/reservations.json).
The full-screen wide window is 951×669 with an 84pt trailing safe area;
its division is x 455.5–495.5, rather than the centre of the 867pt-wide
reader. The full-screen tall window is 669×951 with top/bottom safe areas
82/34pt; its division is y 455.5–495.5 in window coordinates. Fully-open
and 130° records have the same division rectangle and different activity.
The temporary probe only queried geometry; it changed no layout input.

The inactive camera moves with the supplied geometry, not with a device
branch. The four native rotations reported these window rectangles:

| Window | Camera x, y, width, height (pt) |
|---|---|
| Wide | 677.33, 21, 58, 37 |
| Tall | 611, 677.33, 37, 58 |
| Reversed wide | 215.67, 611, 58, 37 |
| Reversed tall | 21, 215.67, 37, 58 |

Native Split View gives narrower, asymmetric spaces. The measured left
pane is 469×669, bottom safe area 34pt, with a division clipped to its
trailing 13.5pt and no occlusion. The measured reversed right pane is
469×669 but its reader is only 385×635 because of the 84pt trailing and
34pt bottom safe areas; its division is clipped to the leading 13.5pt.
Its active status occlusion already lies inside that trailing safe area.
At AX5 no whole phrase tile is visible in the right-pane sample. Use the
actual rectangles without assuming equal usable panes, adding margins
twice, or centring a fold in the reader.

A tall rotation after each sampled Split View arrangement returned a
full-screen 669×951 window. A same-app second selection produced a brief
blank area and then App Library; second-window behaviour remains
inconclusive. A bounded XCTest attempt skipped while the SpringBoard
icon was unhittable. Native input later worked; the Mac preview could
lag the simulator. None of these is a layout-safety pass.

### Spec: what stays binding

- Keep A → C → B → D, each control's logical order and neighbours,
  Stop's well, target/word floors, first-activation speech and the fixed
  frames across browsing, typing and alarm. Emergency never enters a
  scrolling viewport. No new safety exception is accepted here.
- Keep the owner's fold decision: spacing clears a division; no whole
  region moves into one half. Division presence, including an inactive
  division, selects even columns. Activity alone never changes a count.
- Reserve the inner-camera geometry while inactive too. Starting Eye
  Tracking or Head Tracking must not move targets. A simulator cannot
  establish that this rectangle covers the physical dark area.
- Derive all geometry from the supplied space, through the pure engine
  and standard SwiftUI containers. No model, idiom, orientation or hinge
  angle enters the product layout, and no custom input code is added.

The Apple API, checked in current documentation and the installed SDK,
is `GeometryProxy.reservedRegions(kind:options:layoutDirectionBehavior:)`,
available behind `#available(iOS 27.1, *)`. Query `.division` and
`.occlusion` separately with `.includeInactive`. Returned frames already
include their margins. The shared `HomeLayout.Space(proxy)` adapter
adds the reader's leading/top safe-area offset once to reach the engine's
window coordinates; Home and Settings must use the same conversion.
Empty regions and older systems retain their existing output.

Sources: [Apple's query API](https://developer.apple.com/documentation/swiftui/geometryproxy/reservedregions(kind:options:layoutdirectionbehavior:)),
[ReservedRegion](https://developer.apple.com/documentation/swiftui/reservedregion)
and [Duo layout guidance](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo).

### Proposed lanes and the measured horizontal division

For a vertical division at regular widths, the candidate uses six virtual
lanes. C is `Emergency, Yes, No | Again, Get Attention spanning two`.
A keeps the message above the first three and Phrases/Type above the
last three. B keeps Stop/Basics under Emergency, Needs under Yes,
Conversation under No, Feelings under Again and Settings under Get
Attention. Phrase columns are even, allocated from each side's room.
This is a candidate to score, not a claim that floors or chains pass.

**Correction to the initial draft:** the measured full-screen tall
phrase viewport already begins below the horizontal division: y 502 at
default, 612 at AX4 and 660 at AX5, against a band ending at 495.5.
It therefore does not need a gap moving through scrolling content in
that observed geometry. The earlier owner-blocking conclusion is
withdrawn; it was based on a generic layout before the system's
rectangles were read. Growing the existing gaps between ordered rows
can clear the division while leaving D on the same side it already uses.

The generic counterexample remains a regression case: if a division
intersects a scrolling viewport, a gap inside its content moves with the
scroll and cannot guarantee clearance. First test the existing spacing,
order and neighbour rules against each measured and resized space. A
changed scrolling policy or neighbour relationship would still need a
decision, but none is selected or requested by this correction. Pinned
panes and paging remain unapproved alternatives, not prerequisites
established by the tall measurement.

Camera avoidance must also be local to the affected rows or viewport.
Insetting all of wide Home below the upper camera would disable Type at
default text: its minimum safety bottom would be 216pt, beyond the
171pt keyboard band. Instead, investigate the free interval beside the
camera for A's modes; for the reversed bottom camera, shorten D's fixed
viewport before considering any other band. On tall windows inspect
each affected row, including A and C in the reversed rotation, rather
than assuming the camera occupies a remembered corner. Final floors,
keyboard availability and chain scores must use the resolved frames.

Figma: [the options page](https://www.figma.com/design/zCYdh8hSJ9ZmrVhtealp8f/?node-id=73-3),
[vertical lanes](https://www.figma.com/design/zCYdh8hSJ9ZmrVhtealp8f/?node-id=74-139)
and [horizontal scrolling counterexamples](https://www.figma.com/design/zCYdh8hSJ9ZmrVhtealp8f/?node-id=74-190).
The [saved render](../evidence/2026-10-25-duo-design/duo-fold-options.png)
keeps the first proposed options visible without Figma access. Its bands
were illustrative; the runtime rectangles above supersede its blocking
conclusion. The [measured panel](https://www.figma.com/design/zCYdh8hSJ9ZmrVhtealp8f/?node-id=84-2)
and [updated render](../evidence/2026-10-25-duo-design/duo-measured-regions.png)
show the corrected region maps and identify the old scrolling example
as synthetic. These are observations and unfinished candidates, not a
completed Design gate or approval for pinned panes or paging.

### Resolved geometry for implementation

The local implementation uses typed division and occlusion inputs, keeping
activity as a diagnostic property. Presence of a division selects an
even phrase-column count even when its reported frame is inactive,
zero-width or clipped at a window edge. Only a positive-area intersection
with the content requires an internal gap. A status occlusion already
inside a safe-area stripe adds no second inset. Empty reservations keep
the existing engine's complete output exactly.

The engine returns allocation cells separately from occupied control
frames. Local camera fitting shortens only an affected target or shared
message/status or mode group inside its unchanged allocation. Neighbours
keep their cells. A surrounding standard stack holds the spare room;
padding must not silently enlarge the Button's accessibility target back
over the camera. Widths and word/target floors are resolved before their
heights and all derived placement. The renderer uses standard Buttons,
eager stacks and one ordinary D ScrollView.

The first native UI probe found a pixel-rounding overlap: No and
Conversation ended at 455.6667pt against the API's 455.5pt division
edge. Positive finite divisions are therefore enclosed outward in whole
points for planning (455–496 for the measured 455.5–495.5 band). Raw API
frames stay unchanged for evidence and final overlap checks; zero-area
presence still selects even columns without consuming spacing. This is
an explicit rounding allowance, not the API's margins added again. The
strict native overlap assertion is unchanged. The original
[candidate calculation](../evidence/2026-10-25-duo-design/candidate-geometry.json)
remains the initial design record; its 25pt/13.5pt tall figures are
superseded by the rounded calculation below.

An internal vertical division uses the six-lane recipe above when its
two sides meet the occupied controls' minima. Per-side lane widths may
differ; the right group need not inherit the widest left category's
width six times. Four phrase columns use two on each side where their
words fit; otherwise choose two. Their common row floor is the maximum
required by any actual column, not their average width. Edge-clipped
Split View divisions need no interior gap where the existing margin
already clears them; they still select an even count.

For a horizontal division, preserve logical row membership and enlarge
the existing gap at the intersected boundary. Give back growth, never a
floor, where needed. The final Stop-well geometry constrains that growth:
compare Again with each category/Settings competitor in well-local
coordinates. A centre-distance squared-difference change is affine, so
its minimum occurs at a corner; include a conservative distance/tie
allowance. The edge comparison bounds the gain in Again's distance
against competitor movement. Regular-wide geometry instead has a direct
empty-envelope bound where a nearer category excludes Again everywhere
in the well. These are sizing constraints, not a second chain simulator;
the unchanged ChainEngine remains the independent activation check.

Return A's optional growth in half-point steps until the bound holds,
retaining the current primary/category sizes before consuming their
growth. With outward whole-point division planning, the measured default
tall inputs return 27pt: modes are 50.5pt, the safety row ends at 347pt,
and B's rows occupy 407–455 and 496–544. At AX5, retaining the existing 12pt C-to-B
gap avoids widening the old Again envelope; only B-to-D gives back its
2pt growth. The figure values are expected outputs of that rule, never
device constants in the implementation.

When A's optional height is exhausted, continue the same half-point
search through shared primary-row growth, then category growth, never
through a word/target floor or with categories taller than primary
controls. The five-metric/Bold Text regression exposed this need between
the drawn extremes: xxxLarge returns 21pt from A and 4pt from primary
growth; AX1 returns 6.5pt and 13.5pt. Their mode heights are 53.5/60.75pt
and primary heights 60/50.5pt; both retain B at 407/496 and D at 556.
These are derived outputs of the generic constraint, not text-size
branches. The native unit check also retains the existing message-reading
speaking-share bounds, rather than treating the well check as proof of
the separate reading hazard.

Camera fitting follows the actual rectangles in every rotation. When a
camera intersects D, crop D's fixed rectangular viewport toward that
camera's nearest window edge and resolve its columns/floor again. No
spacer scrolls with the content through an exclusion. Resizing for a
library warning retains the resolved column lanes and camera limits.
Static controls prefer an extra 8pt clearance where their word floor
fits, falling back to the reported boundary if necessary. D uses that
already-margin-inclusive boundary with no extra clearance. These are
explicit layout gaps, never the API's margins added a second time.
Visible tile intersections and the full accessibility frames of partial
tiles are distinct checks; viewport clipping alone is not Snap-to-Item
proof. The physical clipped-target check remains deferred.

Current outputs from the [production pure-geometry export](../evidence/2026-10-25-duo-design/candidate-geometry-enclosed.json)
are below. These use the measured rectangles and the existing
font-validated default/AX5 line metrics with Bold Text off. The export
also records eight intermediate metric cases and 400 comparisons with
the unreserved legacy engine, with no mismatch. The five inner poses in
the native comparison below independently check the full-screen outputs;
the left/right panes still have only pure geometry and drawings for this
revision. Existing no-region phone/iPad outputs and typing drawings remain
the references there.

| Supplied geometry | Default: whole tiles / trailing extent / Type | AX5: whole tiles / trailing extent / Type |
|---|---|---|
| Wide, upper camera | 8 / 0pt / available | 4 / 66pt / unavailable |
| Wide, lower camera | 8 / 0pt / available | 4 / 82pt / unavailable |
| Tall, right camera | 8 / 0pt / available | 4 / 14pt / unavailable |
| Tall, left camera | 8 / 0pt / available | 4 / 14pt / unavailable |
| Left pane | 8 / 0pt / available | 0 / 193pt / unavailable |
| Right pane | 8 / 0pt / available | 0 / 193pt / unavailable |

Trailing extent is full phrase content below fixed D, not a measurement
of maximum scroll distance. The native closed-window observation adds
6 whole tiles / 3pt trailing extent at default and 0 / 249pt at AX5.
Closed has no individual expected-frame export in the comparison; its
native state, appearance, raw-reservation and keyboard checks are
reported separately from pure frame agreement.

The AX5 panes leave a 55pt viewport against a 56pt tile floor: no whole
tile fits. The design preserves that explicit capacity failure; it does
not implement paging, shrink a floor or remove a safety row. Tall AX5's
second safety row starts at 496 and ends at 575, beyond its existing
548pt keyboard band. Type therefore becomes unavailable under the
existing policy. With the full US keyboard and default app text, the measured keyboard top is 405pt in wide inner windows,
601pt in tall inner windows and 374pt in the closed window. In all 12
default typing captures, Emergency, Yes, No, Speak, Get Attention,
Phrases, Clear and Put Back are wholly above it. Clear and Put Back were
captured with an empty draft; their geometric coverage does not establish
physical activation behavior. AX5 Type remains unavailable. Native pane
keyboard clearance and broader keyboard configurations remain pending.

The prototype's 12 cases have no new Stop/well chain paths or sampled
Again-nearest points against their baselines, by centre and edge on a
half-point mesh. Existing hazards remain recorded. This is limited
geometric evidence, not complete activation-chain proof. The production
allocator and intermediate/Bold Text cases now have pure regressions;
the [changed-window diagnostic](../evidence/2026-10-25-duo-design/transition-report.md)
finds added hazards under hypothetical numerical coordinate hold/scaling.
Its wide→tall selected-Conversation example reaches Get Attention where
both old maps were inert and legacy-after settled. Actual OS mapping is
unverified; no physical event or new exception is inferred. Activity-only
geometry stays identical in ten scene/font cases. Keep this PR a draft;
changed-window safety has not passed. Back to Talking and
the unchanged Settings row solver consume the final Home frames;
PR #56's accepted limits and tests remain intact.

The [native frame comparison](../evidence/2026-10-25-duo-design/native-frame-comparison.md)
and [per-capture receipts](../evidence/2026-10-25-duo-design/native-frame-comparison.json)
cover 144 coherent captures across six poses and 24 default/AX5,
requested-light/dark configurations. The five inner pose sets include
both reversed rotations and a partially folded book pose; the sixth is
closed. No current native Split View pane recheck is included.

| Native geometry check | Result and limit |
|---|---|
| Exported occupied Home buttons | PASS: 1,220 comparisons, maximum delta 0.167pt |
| Exported full phrase-tile frames | PASS: 800 comparisons, maximum delta 0.25pt |
| Shared Home frames across state transitions | PASS: 1,884 comparisons exactly equal; baseline self-comparisons excluded |
| Static Home controls | PASS in 120 Home captures: required controls present, within the coherent window and at least 44×44pt |
| Raw fold/camera/status intersections | PASS for static controls and geometrically cropped tiles: zero strict positive-area intersections |
| Full AX phrase-tile camera clearance | FAIL in 32 AX5 wide-reverse/book records; cropped portions stop before the camera, but full AX frames overlap it |
| Default typing coverage | PASS in 12 captures for all eight controls named above |
| Back to Talking | PASS in 24 Settings captures: contained within final native Phrases, with zero raw reservation intersections |
| Open versus partially folded wide reverse | PASS: 412 shared button/tile frames exactly equal at the recorded 180° and 90.074° poses |

Expected-frame agreement checks origins, sizes and far edges with a
0.5pt tolerance. Reservation intersection checks use the unchanged raw
API rectangles with no overlap tolerance. Tile cropping intersects each
full AX frame with fixed browsing D and the coherent window, and while
typing also with the area above the keyboard. The typing AX container
expands, so its reported whole-tile count is not visible capacity. Neither
geometric cropping nor the absence of a static intersection proves
rendered clipping or physical Snap to Item behavior. Active-display
appearance was not reviewed by this JSON comparison; XCUIScreen can
capture the black inactive outer display.

The final native unit gate passed with `CI=true`: 769 test cases,
760 ordinary passes, zero failures, one existing #19 skip and eight
strict expected failures. Coverage is 70.6% (6,898/9,769), catalog current.
The result is `build/TestResults/duo-final-unit/unit-destination.xcresult`;
the [receipt](../evidence/2026-10-25-duo-design/final-unit-results.json)
also lists all seven passing keyboard argument rows, including the three
new Duo measurements. Xcode counts their parent case once, so the
provisional expectation of 772 was incorrect. No temporary probe is in
this source. The complete standard UI suites each fail one Speaking-wait
case, also reproduced on unchanged main on the same iPad. Root inspected
default/AX5 light/dark captures on both families; this is not a full UI
pass. [Combined UI receipt](../evidence/2026-10-25-duo-design/standard-ui-results.json).
Actual pointer mapping across changed windows, final Duo active-display
review, native pane rechecks and mounted-device tests remain open.

### Plan from the measured regions

**Scoped drawing gate, 2026-10-25:** the
[84-state candidate section](https://www.figma.com/design/zCYdh8hSJ9ZmrVhtealp8f/?node-id=89-3)
now draws the revised enclosed default/AX5 frames: 24 browsing, 12 typing, 24
alarm and 24 Settings covers, evenly split light/dark. The
[saved overview](../evidence/2026-10-25-duo-design/candidate-screens.png)
and [screen links and validation](../evidence/2026-10-25-duo-design/candidate-drawings.json)
record the drawing check. All 84 screen links stay unchanged. Separate
guides retain the raw 455.5–495.5pt band and show the allocator's
455–496pt enclosure. The 768 Home/Back targets match the export within
0.000012208pt Figma precision; all 480 tile frames and 24 modeled
Settings rows match exactly, with no Brickson button-label overflow.
Apple kit components supply system chrome and
keyboards; Inter text is an explicitly labeled drawing substitute where
the connector cannot render the system font. These are design frames,
not native UI or keyboard measurements.

Settings keeps its current row solver and PR #56's limits. Its modeled
AX5 full-screen row crosses the fold in four geometries; the
[wide](../evidence/2026-10-25-duo-design/settings-wide-ax5-gap.png) and
[tall](../evidence/2026-10-25-duo-design/settings-tall-ax5-gap.png) drawings
show that modeled gap explicitly. It also exists with the unreserved engine:
wide AX5 moves from y336 to y337, crossing in both; tall AX5 stays at
y467. This closes the drawing gate for item 6's Home scope, including
the cover derived from Home. It does not complete R0-13's broader
Settings/setup audit, approve an exception, or claim Settings fold
clearance. All 20 exported row models compared with native frames differ
by more than 0.5pt: they assume a 64pt navigation bar, 40pt footer and
modeled wrapping. For example, wide default is natively y201 rather than
model y203; tall AX5 is natively (215.667,462,437.333,79.667) rather than
model (211,467,442,79). The native audit records ten AX5 Settings
row/fold intersections. Native Back containment above does not close
these broader R0-13 Settings/setup gaps. Complete Settings chain and
setup checks remain required. The owner confirmed keeping the current
rule and investigating another design; no pinned panes or paging is
selected.

The original drawing gate was saved in `87ddb14`. Revised enclosure
screens, the updated Spec and native receipts were committed in
`8f4a997` before the first implementation commit.

Implementation files: `Brickson/Layout/HomeLayout.swift` owns typed inputs,
allocation/occupied bounds, lanes and final derived outputs;
`HomeReservedLayout.swift` resolves exclusions and ordinary growth;
`HomeWellEnvelope.swift` supplies the geometric well constraint.
`Brickson/Home/HomeView.swift` adapts system regions and renders those
outputs with existing controls and standard stacks. The three reserved-
region test files under `BricksonTests/Layout/` check allocation, Home
chains and the unchanged Settings solver separately. No Settings policy,
project-format or fewer-tiles implementation is part of item 6.

1. The linked Spec and drawings use the recorded full-screen and
   clipped Split View rectangles, both axes and reversed rotations,
   inactive and active reservations, default and AX5, light and dark,
   browsing/typing/alarm and the Settings cover. Keep readers and
   reconstructed windows distinct. The native frame comparison above is
   independent of the pure export; rendered appearance remains separate.
2. Failing pure Swift Testing reproductions precede the local implementation:
   division and camera separately, inactive/active stability, translated
   safe areas, both axes, resized windows and grown libraries at nonzero
   scroll offsets. Removing reservations, querying only active regions,
   double-offsetting a frame or using a content gap where a division
   intersects a scrolling viewport must make its corresponding check
   fail. A viewport wholly on one side needs no scrolling gap.
3. The pure engine returns typed reservation, lane/gap and viewport
   geometry, recalculating floors, fit/shortfall, keyboard availability,
   Back to Talking and Settings placement from the final frames. It reports
   a shortfall rather than shrinking a target or hiding a control.
4. The local renderer uses standard containers and existing controls.
   Complete the independent Home and Settings chain gates, by centre and
   edge, including folding from
   old resting positions; preserve #56's tests and accepted limits.
5. The final unit gate above includes the added keyboard rows. Retain the
   standard iPhone/iPad UI failure and main comparison while investigating
   its cause; complete the remaining Duo pane checks.
   Native full-screen/closed observations above use one coherent accessibility
   snapshot for window and control coordinates; preserve existing test
   strength. Check partially clipped accessibility targets on a device
   before claiming Snap to Item safety. Device comfort, audio, Phone
   handoff and the tracking dark area remain separate physical checks.

The implementation is retained in draft PR #58. No universal fold
clearance, strong changed-window chain safety or physical-input result
is claimed. Tall AX5 adds a capacity shortfall relative to the unreserved
baseline; satisfying the existing rule remains an open design gate,
not a newly accepted scrolling exception. Its record is
[the item 6 design log](../log/2026-10-25-duo-fold-design.md).

### Mode word-floor correction, 2026-10-25

A native app-hosted font measurement found an inset mismatch in the
existing contract: ModeButton uses6pt on each horizontal side, while its
minimum-width test subtracted4pt. Phrases requires89/97pt and Type60/65pt
with Bold Text off/on, including the existing WordFit slack and actual
padding. Retain the prior conservative spare by raising the declared
minimums4pt: Phrases90/98, Type62/67. Again and Speak keep their existing
4pt insets and minimums. This corrects the current word-fit guarantee;
font styles, default-size floors, control order and placement policy do
not change.

The failing native reproduction ran before the four-number correction:
33 cases,30 passed and3 failed, with no skip/expected failure. It includes
the corrected minimum-width font check, camera-fitted native font checks
and an independent pure acceptance check. The camera inputs are synthetic
window positions using a measured58×37 camera size, not observed OS poses.
They exposed accepted86/94pt modes whose Phrases labels lacked the
measured room. The existing camera-boundary fallback can provide94/102pt
after the correction without a new allocation policy.

Before implementation, the old/proposed host exports were compared:
all12primary and8intermediate captured geometries, including state frames,
allocations, D, Back, capacities and sampled chains, are exactly equal.
Both versions also have400 legacy comparisons with zero mismatches.
The existing scoped drawings therefore keep their geometry for those
inputs. Native red/green results, selected family UI checks and final
CI remain separate verification gates; this does not accept any new
Settings, scrolling, camera-target or physical-input exception.

### Reference-capacity growth return: Spec and plan, 2026-10-25

The lower-camera wide space exposes one omitted retry between the drawn
extremes. At the existing measured AX3 line metrics (53/49/59/44pt,
Bold Text off), the unreserved eight-phrase reference fits. The selected
reserved candidate has no allocation issues, but its final lanes raise
the common tile floor to 100pt and the camera crops D to 204pt: two rows
need 208pt. Its category rows still hold 4pt of optional growth above
their 61pt word floor. This is a new 4pt reference-capacity deficit, not
permission to scroll or a reason to change the fixed 8pt internal gaps.

**Spec.** Keep the entire original candidate-selection pass, including
its gap choice and first issue-free acceptance. Compare its final grid
shortfall with the unreserved baseline reflowed for the fixed reference
eight phrases. If it adds no shortfall, return the exact original result.
If it adds shortfall, retry only when that original result is issue-free
and passes the unchanged full `HomeWellEnvelope.preserves` certificate;
otherwise retain the original frames and diagnostics unchanged. This
repair recovers capacity from an already valid selection, not unrelated
allocation or safety failures.

The second pass keeps the selected gap recipe and existing optional
growth budgets, in their present preference order: A, then primary rows,
then category rows, with the existing half-point steps. Select the first
eligible result reaching the reference target within that order. If none
reaches it, retain the eligible result with strictly least remaining
shortfall, keeping the original on ties. Every trial must satisfy normal
allocation issues, final word/target floors and exclusions, and the full
unchanged well certificate for every reservation kind. No runtime chain
scoring, device/text-size branch, floor reduction, changed neighbour or
new gap measure enters this search. Empty reservations retain the exact
legacy output. The objective always uses eight phrases before a family's
actual library is reflowed, so adding words cannot move static controls.

The bounded design returns 2pt from each category row, not the full 4pt
available. Stop and Basics become 63pt high; the spanning B targets
become 134pt. D changes `(16,407,835,204)` to `(16,403,835,208)` and holds
eight 100pt tiles with 8pt row gaps. A, C, message/status/modes, centred
Back `(593.2,8,160.6,79)` and Type's unavailable state stay unchanged.
The [exact before/after geometry](../evidence/2026-10-25-duo-design/ax3-growth-geometry.json)
and [bounded checks](../evidence/2026-10-25-duo-design/ax3-growth-checks.json)
are host evidence, not a native rendering result. The exploratory
second pass leaves 59 of 60 captured space/font/Bold outputs exactly
unchanged; only this AX3 case changes. Repeating all 60 with 24 phrases
changes no static geometry. The compact receipts retain those limits.

[Figma section 122:3874](https://www.figma.com/design/zCYdh8hSJ9ZmrVhtealp8f/?node-id=122-3874)
adds 16 isolated before/after drawings: browsing, alarm, retained typing
with the keyboard lowered, and a scoped Settings Back cover, each in
light/dark. The existing 84 drawings remain unchanged. The
[saved render](../evidence/2026-10-25-duo-design/ax3-growth-comparison.png)
and [manifest/validation](../evidence/2026-10-25-duo-design/ax3-growth-drawings.json)
record 292 exact target/viewport/tile/Back checks within 0.0002pt,
333 editable text layers and no image-filled nodes. These are geometry
drawings using the documented Inter stand-in at default-floor label
sizes, not a native AX3 fitted-type sample. A fresh SF Pro connector
probe measured zero width with `hasMissingFont=true`; no passing SF
typography check is claimed. Apple kit chrome and existing palette
tokens are reused; no global type/style or original Home frame changed.
The scoped cover draws Back only, with no new Settings row geometry or
claim to close broader R0-13 Settings/setup gaps.

This is a partial repair. The [bounded capacity limits](../evidence/2026-10-25-duo-design/ax3-growth-capacity-limits.json)
retain tall AX5's 14pt observed deficit: even minimum region gaps with
fixed 8pt internal gaps leave 12pt missing. The 1pt/1pt B/D-gap hypothesis
changes the binding 8pt measure and is not selected. Wide AX5 has no
optional height in these inputs and retains 66/82pt total shortfalls.
These results do not prove universal impossibility or close any AX5,
changed-window, clipped-target or physical-input gate.

**Plan before the next code commit:**

1. Commit this Spec/plan and the linked isolated drawings before a code
   commit, following SDLC's Design/Build gates. Keep the one item 6 PR;
   no Settings policy or unrelated source changes enter this repair.
2. Add a failing Swift Testing reproduction for the recorded lower-camera
   AX3 input: reference shortfall 0, eight whole tiles, category 63 rather
   than 61, and unchanged 8pt/10pt gaps, A/C/Back and camera boundary. It
   must fail if the retry is removed or consumes all optional growth.
3. Implement only the guarded second pass, retaining the original result
   exactly when no new reference deficit exists or the original is unsafe.
   Preserve finite search order and explicit residual shortfall; no weaker
   certificate, new known issue or hidden invalid-candidate fallback.
4. Test reference-library independence at 8/24 phrases, all captured
   geometries/five metrics/Bold states, exact unaffected choices, no-region
   legacy output, translated/RTL/multiple regions and warning reflow.
   Rerun unchanged well, Home/Settings chain, message-reading and Back
   checks, including retained typing with Clear 2/Put Back 3. The bounded
   host samples do not replace those gates.
5. Verify native SF word/target floors, fixed frames across affected
   states and appearances, camera/division rounding, Type/keyboard policy
   and the scoped Back cover, then the full native unit and applicable UI
   gates. Physical Snap to Item and changed-window pointer mapping remain
   separate; no simulator or design drawing establishes those results.
