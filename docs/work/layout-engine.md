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

Those observations establish the need for reserved-region layout. They
do not provide the system's exact region rectangles, prove camera
clearance or settle every window. Windowing and the second-window check
remain open. A normal rectangular viewport is not fold-safe evidence.

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

### Proposed vertical lanes; horizontal scrolling unresolved

For a vertical division at regular widths, the candidate uses six virtual
lanes. C is `Emergency, Yes, No | Again, Get Attention spanning two`.
A keeps the message above the first three and Phrases/Type above the
last three. B keeps Stop/Basics under Emergency, Needs under Yes,
Conversation under No, Feelings under Again and Settings under Get
Attention. Phrase columns are even, allocated from each side's room.
This is a candidate to score, not a claim that floors or chains pass.

A vertical gap stays aligned when a vertical grid scrolls. A horizontal
gap inside one ScrollView does not: scrolling moves the gap away from the
division, letting the next tile cross it. A fixed gap at the viewport
instead needs a different content arrangement. The straightforward
standard-container alternative is a pinned prefix above the division
and a scrolling remainder below. With four columns, tiles 0–3 stay above;
after the lower pane scrolls a row, their visible neighbours below change
from 4–7 to 8–11. Stored order and row ownership survive, but the current
continuous grid and spacing-only behaviour do not.

**Owner choice before code:** keep the current rule while another
spacing-only design is investigated; explicitly accept pinned-prefix
scrolling; or bring whole-row paging forward into this R0 job. Moving all
of D into one half remains rejected by the current decision. Paging is
currently R1 work after the first R0 App Review build; this document
does not move it earlier. Recommendation: retain the current rule until
one alternative is explicitly chosen and scored. The drawings show
candidate failures and trade-offs, not a completed Design gate.

Figma: [the options page](https://www.figma.com/design/zCYdh8hSJ9ZmrVhtealp8f/?node-id=73-3),
[vertical lanes](https://www.figma.com/design/zCYdh8hSJ9ZmrVhtealp8f/?node-id=74-139)
and [horizontal scrolling counterexamples](https://www.figma.com/design/zCYdh8hSJ9ZmrVhtealp8f/?node-id=74-190).
The [saved render](../evidence/2026-10-25-duo-design/duo-fold-options.png)
keeps the proposed options visible without Figma access.

### Plan after that choice

1. Finish the chosen Spec and drawings for both axes, camera inactive and
   active, default and AX5, light and dark, browsing/typing/alarm, and the
   Settings cover. Record exact queried region rectangles in Device Hub;
   illustrative bands in the drawings are not measurements.
2. Write failing pure Swift Testing reproductions before implementation:
   division and camera separately, inactive/active stability, translated
   safe areas, both axes, resized windows and grown libraries at nonzero
   scroll offsets. Removing reservations, querying only active regions,
   double-offsetting a frame or using a single scrolling row gap must
   make the corresponding check fail.
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
