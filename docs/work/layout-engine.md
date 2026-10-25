# The layout engine

*Roadmap: docs/ROADMAP.md, Wave 3 item 3, "The layout engine, with no
screen change yet" (R0 item 3, and R1's profile layout engine); this
file also covers items 4 (Home on the engine) and 6 (Home on iPhone Duo,
in every pose). Owner: the Layout engine thread. Items 3, 4 and 5 are
built. Item 6 is in design: the horizontal-fold scrolling choice below
needs the owner before implementation. The original engine spec is kept
as history; the dated item 6 section is the current continuation.*

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
limits. No Home or Settings implementation changes in this design pass.

[PR #55's dated Mac record](https://github.com/MiddleAgedBanana/Brickson/blob/cb4c965/docs/log/2026-10-25-mac-keyboard-checks.md)
measured app code `8316743`, before PR #56. In Device Hub the closed
window was 466×678; the open inner window was 951×669 wide and 669×951
tall. Open-wide AX5 showed four whole phrases and scrolled 10pt; open
tall fit eight at default/AX4/AX5. The Hub's partial pose reported 130°;
tall default/AX5 fit eight, and wide dark default/AX5 matched the open
wide counts. The rendered wide fold crossed No, Conversation and phrase
tiles. Existing open-Duo Home tests had eight passes, nine failures and
two landscape skips. The record distinguishes frame-API disagreements
from a pre-#56 Settings chain finding; none has been rescored on #56.

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

The implementation will use typed division and occlusion inputs, keeping
activity as a diagnostic property. Presence of a division selects an
even phrase-column count even when its reported frame is inactive,
zero-width or clipped at a window edge. Only a positive-area intersection
with the content requires an internal gap. A status occlusion already
inside a safe-area stripe adds no second inset. Empty reservations keep
the existing engine's complete output exactly.

The engine will return allocation cells separately from occupied control
frames. Local camera fitting shortens only an affected target or shared
message/status or mode group inside its unchanged allocation. Neighbours
keep their cells. A surrounding standard stack holds the spare room;
padding must not silently enlarge the Button's accessibility target back
over the camera. Widths and word/target floors are resolved before their
heights and all derived placement. The renderer uses standard Buttons,
eager stacks and one ordinary D ScrollView.

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
growth. For the measured default tall inputs this returns 25pt: modes
are 51.5pt, the safety row ends at 349pt, and B's rows occupy
407.5–455.5 and 495.5–543.5. At AX5, retaining the existing 12pt C-to-B
gap avoids widening the old Again envelope; only B-to-D gives back its
2pt growth. The figure values are expected outputs of that rule, never
device constants in the implementation.

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

Candidate outputs from the [standalone geometry record](../evidence/2026-10-25-duo-design/candidate-geometry.json)
are below. These use the measured rectangles and the existing
font-validated default/AX5 line metrics with Bold Text off. They are
design calculations, not new runtime results. The existing no-region
phone/iPad outputs and typing drawings remain the references there.

| Supplied geometry | Default: whole tiles / scroll / Type | AX5: whole tiles / scroll / Type |
|---|---|---|
| Wide, upper camera | 8 / 0pt / available | 4 / 66pt / unavailable |
| Wide, lower camera | 8 / 0pt / available | 4 / 82pt / unavailable |
| Tall, right camera | 8 / 0pt / available | 4 / 13.5pt / unavailable |
| Tall, left camera | 8 / 0pt / available | 4 / 13.5pt / unavailable |
| Left pane | 8 / 0pt / available | 0 / 193pt / unavailable |
| Right pane | 8 / 0pt / available | 0 / 193pt / unavailable |

The AX5 panes leave a 55pt viewport against a 56pt tile floor: no whole
tile fits. The design preserves that explicit capacity failure; it does
not implement paging, shrink a floor or remove a safety row. Tall AX5's
second safety row starts at 495.5 and ends at 574.5, beyond its existing
548pt keyboard band. Type therefore becomes unavailable under the
existing policy. Inner-display keyboard dimensions still need native
measurement before a broader keyboard-clearance claim.

The prototype's 12 cases have no new Stop/well chain paths or sampled
Again-nearest points against their baselines, by centre and edge on a
half-point mesh. Existing hazards remain recorded. This is limited
planning evidence: the production allocator, Bold Text, intermediate
sizes, typing/Settings chains, changed-window resting points and native
frames all still require their regression gates. Back to Talking and
the existing Settings row solver will consume the final Home frames;
PR #56's accepted limits and tests remain intact.

### Plan from the measured regions

1. Finish the Spec and drawings from the recorded full-screen and clipped
   Split View rectangles, both axes and reversed rotations, inactive and
   active reservations, default and AX5, light and dark,
   browsing/typing/alarm and the Settings cover. Keep readers and
   reconstructed windows distinct. These candidate observations do not
   complete the Design gate.
2. Write failing pure Swift Testing reproductions before implementation:
   division and camera separately, inactive/active stability, translated
   safe areas, both axes, resized windows and grown libraries at nonzero
   scroll offsets. Removing reservations, querying only active regions,
   double-offsetting a frame or using a content gap where a division
   intersects a scrolling viewport must make its corresponding check
   fail. A viewport wholly on one side needs no scrolling gap.
3. Have the pure engine return typed reservation, lane/gap and viewport
   geometry. Recalculate floors, fit/shortfall, keyboard availability,
   Back to Talking and Settings placement from the final frames. Report
   a shortfall rather than shrinking a target or hiding a control.
4. Render with standard containers and existing controls. Score every
   Home and Settings chain, by centre and edge, including folding from
   old resting positions; preserve #56's tests and accepted limits.
5. Run the full unit and standard iPhone/iPad UI gates, then fold-aware
   Duo checks in native Hub orientations. Use one coherent accessibility
   snapshot for window and control coordinates; preserve existing test
   strength. Check partially clipped accessibility targets on a device
   before claiming Snap to Item safety. Device comfort, audio, Phone
   handoff and the tracking dark area remain separate physical checks.

No implementation or universal fold-clearance result is claimed by this
plan. Its record is [the item 6 design log](../log/2026-10-25-duo-fold-design.md).
