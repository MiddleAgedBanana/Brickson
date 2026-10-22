# Design: tokens, type, slots and screens

The design reference for Brickson's screens. It records the measured
colour pairs, the Dynamic Type ladder the layout follows, the slot plan
every screen keeps, and where the drawings live. Code that sizes or colours
a control points here by section title. Where this file and a decision in
docs/DECISIONS.md differ, the decision wins; tell the next agent by fixing
this file in the same pull request.

Everything here is drawn and computed, not run on a device. The numbers
come from one layout source shared by the Figma file and the Claude
Design prototype, so the two agree with each other. They are a design to
build toward, not a measurement: the app's layout engine computes the real
frames from the space available, and its tests pin them (AGENTS.md,
invariant 11).

This file's own decision is "Solid fills on Home, system glass
elsewhere" in docs/DECISIONS.md. The decisions from PRs #21, #22 and
#23 have now landed there: "Typing is a state of Home", "Home's slot
plan" and "Settings is a cover with a fixed safety bar". They bind this
reference. The specification is [work/design-screens.md](work/design-screens.md);
it names the states, input paths, repeated activations and remaining
checks before build work follows a screen.

The slot plan adopted Phrases in every state, Settings at region B's
trailing end, Stop Alert below Emergency, and a three-column message on
regular widths. The drawings still show the earlier placements and are
not corrected by this documentation update. The Yes/No message-border
hazard and access to a fifth category remain open. Back to Talking over
Phrases alone is still a proposal that differs from the landed decision;
*Open in the slot plan* records it without adopting an exception.

## Where the drawings are

- **Figma file** in the owner's account,
  https://www.figma.com/design/zCYdh8hSJ9ZmrVhtealp8f. Three pages:
  - *Foundations*: read me, colour tokens with contrast, the type ladder,
    slot sizes per device.
  - *Home*: iPhone 17, iPhone SE class, iPad Pro 13-inch portrait and
    landscape; browse, typing and alarm; light, dark and the largest
    accessibility text; comparison frames that overlay the states of one
    device to show that no frame moves.
  - *Settings and Library*: Settings root, Family Setup, Voice, the
    Library list, the phrase editor and its delete question, on iPhone 17
    and iPad landscape.
- **Claude Design prototype** (private artifact, shared by the owner when
  they choose): an iPhone 17 Home you can tap through (speak, type, alarm,
  Settings, Family Setup, Voice, Library, editor, delete question), and
  still frames of the other states and the iPads. Same layout source.
  Its taps join the drawn screens so they can be seen in order; where
  this file withdraws a drawing or calls a flow open, the prototype
  is not a reference for it either.

What came from where:

- **From Apple's iOS and iPadOS 27 Figma kit** (a library in the owner's
  account): status bars, home indicators, the iPhone and iPad software
  keyboards, and the system colour variables that switch the frames
  between light and dark. No Apple accessibility kit was found in the
  account; Dynamic Type sizes were taken from the Human Interface
  Guidelines instead (*Type*, below).
- **Drawn by the layout source**: every Brickson control, label, well and
  frame, on both Figma and the prototype.
- **Stand-ins to know about**: the Figma file labels controls in Inter,
  because SF Pro is listed in the account but does not render there. SF
  Symbols are not drawn; each control's layer name carries the symbol
  name the app should use. The prototype uses the system font of the
  browser it runs in. The real app uses San Francisco and SF Symbols, and
  its word-fitting is measured on the device, so label fits here are
  estimates (*Words never break*, below).
- **Figma account limits**: the Starter plan allows three pages per file,
  one variable mode (light and dark are two modes of Apple's kit, which is
  why the dark frames come from the kit's collection) and a small monthly
  budget of read calls through the Figma connector. Agents draw with
  `use_figma` scripts, which do not count against it, and take screenshots
  from inside those scripts.

## Colour

One value in light and dark, so every pair below holds in both
appearances and under Increase Contrast and Reduce Transparency, which
never lighten a solid fill. Ratios are WCAG 2 contrast, computed from the
hex values; `PaletteTests` must pin each pair the app adopts (AGENTS.md,
invariant 6: text 4.5:1 or better, control edges 3:1 or better against
what they sit on).

| Token | Hex | Used for | White label on it | Edge on white | Edge on black |
|---|---|---|---|---|---|
| `phrase` (`AccentColor`) | `#0A60D6` | Phrase tiles, categories, Again, Speak, Type, Yes, No, Hear, Use, Save | 5.74:1 | 5.74:1 | 3.66:1 |
| `control` (`ControlFill`) | `#5A6474` | Clear, Settings, Back to Talking, Family Setup rows, Slower, Faster, Move to…, Keep | 5.98:1 | 5.98:1 | 3.51:1 |
| `emergency` (`EmergencyFill`) | `#C8161E` | Emergency, emergency phrases, Delete Phrase, "Delete … for good" | 5.85:1 | 5.85:1 | 3.59:1 |
| `attention` (not in the code yet) | `#B45309` | Get Attention | 5.02:1 | 5.02:1 | 4.18:1 |
| `stop` (not in the code yet) | `#0F766E` | Stop Alert | 5.47:1 | 5.47:1 | 3.84:1 |

The first three are `Palette`'s fills today, already pinned by
`PaletteTests`. The "Used for" column is the drawings' assignment. Today's
stand-in Home puts Yes, No, Again and the categories not selected on
`control`; which role each control takes on the new Home is settled with
"Home's slot plan", and every role it can take is a pair measured here.

Surfaces, in light / dark:

| Token | Light | Dark | Used for |
|---|---|---|---|
| `background` | `#FFFFFF` | `#000000` | The screen |
| `field` | `#F2F2F7` | `#1C1C1E` | The typing field and message block |
| `fieldEdge` | `#767676` | `#767676` | The typing field's 2pt edge: 4.07:1 on the field and 4.54:1 on the screen in light, 3.75:1 and 4.62:1 in dark |
| `well` | `#E9E9EC` | `#2C2C2E` | A reserved slot that holds no control in this state |
| `hairline` | `#C6C6C8` | `#38383A` | Row separators only; decorative, never a control's edge |
| `label` | `#000000` | `#FFFFFF` | Text on the background and on fields |

The field itself is only 1.12:1 from the screen in light and 1.23:1 in
dark, so the typing field's edge is what shows where the control is, and
it needs 3:1 against both the field and the screen (invariant 6). The
hairline measures 1.53:1 and 1.45:1 against the field, so it never draws
a control's edge. The Figma frames still draw the field with the hairline;
read them with `fieldEdge` (Codex review of PR #20).

Rules the pairs enforce:

- Labels on coloured controls are white; labels on the background, the
  message block and fields are `label`. Nothing else carries text.
- The system's `secondaryLabel` measures about 3.4:1 on the background,
  so it is never used for words people must read, including status lines
  such as "Sounding" or "Message not saved". Status text is `label` at
  footnote size or larger.
- White on system red (3.55:1) and system orange (2.2:1) are forbidden
  (AGENTS.md). `emergency` and `attention` replace them.
- A selected control (Type while typing, the voice in use, the open
  category) shows a 3pt white stroke inside its edge. The fill does not
  change, so the label keeps its ratio.
- A pressed control shows a `label`-coloured ring inside its edge, as
  Again does today (docs/DECISIONS.md, "Home version 0 is a stand-in");
  the fill and label do not change.
- Wells are hidden from accessibility and carry no text; they exist so a
  control that is absent in one state leaves its frame visibly reserved.

## Type

Brickson follows Dynamic Type and never fixes a point size. The ladder is
Apple's, from the Human Interface Guidelines typography page (iOS and
iPadOS, read 2026-10-21), given here for the two sizes the drawings use;
the Foundations page in Figma shows every size between.

| Role | Large (default) size/leading | AX5 size/leading | Where |
|---|---|---|---|
| Title 1 | 28 / 34 | 58 / 68 | The message text; the typing field |
| Body, semibold | 17 / 22 | 53 / 62 | Every control label |
| Footnote | 13 / 18 | 44 / 52 | Status lines, idle notes, the "undeletable" note |

Usage rules:

- The drawings use Title 1 for the message. The landed stand-in reserves
  two lines at the person's text size and scrolls a longer message inside
  them. It shrinks only while its widest word is wider than the row,
  never below the default size (docs/DECISIONS.md, "Home version 0 is a
  stand-in"). That decision supersedes the drawings' never-shrink rule.
- Control labels are Body semibold with a system symbol above the words
  where the control is tall enough for both.
- **Words never break** (AGENTS.md, *Design rules for dwell, switch and
  pointer input*). When a label does not fit its control, drop the
  symbol first, then step the text down one Dynamic Type size at a time,
  and never below its default size, the size it has at Large. On the
  phone at AX4 and AX5 a few labels reach that floor in a one-column
  slot; the drawings show them there. How the code fits labels is the
  Phone layout and word fitting work's, and it wins where it differs.
- A person's own words (phrase and category names) are shown verbatim and
  never localized (AGENTS.md, *Workflow rules*).

## The slot plan

How the drawings lay out Home, reconciled with the binding plan in
docs/DECISIONS.md, "Home's slot plan" (PR #22, landed). The table records
adopted placements beside the historical drawing differences; an item
explicitly called a proposal or open hazard remains unresolved. The
layout engine still has to build the wells and pin their identifiers and
frames in tests.

Home is four regions, top to bottom, in every profile and on every
device: **A** the message, **C** the safety row, **B** the categories
with Stop Alert and Settings, **D** the phrase grid. Each control's layer
in the Figma file is named for its slot, so a drawing can be matched to
the code by name.

Today's Home is still the stand-in (docs/DECISIONS.md, "Home's stand-in
layout"). Since PR #22 its eager rows fit the available space: three
phrase columns wherever three 107pt tiles fit, four visible category
buttons, labels fitted in whole words, and the message with Again beside
it. Main records the small-window scrolling gaps separately. The slot
plan and its wells are still to be built; these drawings are not a
picture of the running app.

| Layer name | Control | Region | Notes |
|---|---|---|---|
| `messageText` | The message block | A | Passive text, scrolls inside its frame. Two of three columns wide on compact widths; three of five on regular widths under the landed plan, where the drawings span four (*What borders the text*, below) |
| `statusLine` | Speaking / Sounding / audio warnings | A | Passive footnote under the message, as wide as it; always reserved |
| `clear` | **Phrases** in every state, the way back to the phrases (*Typing*). The drawings show Clear while typing and a well otherwise | A | Trailing column, top; shown selected while browsing. The trailing column is one column wide on compact widths; two on regular widths under the landed plan, where the drawings use one |
| `type` | Type | A | Trailing column, under the top slot; shown selected while typing |
| `yes`, `no` | Yes, No | C | |
| `again` | Again, or Speak while typing | C | Same frame, label changes |
| `emergency` | Emergency | C | Two columns wide on compact widths |
| `getAttention` | Get Attention | C | Start only; never stops the alarm |
| `stopAlert` | Stop Alert | B | Leading column, top, directly below Emergency; live only while the alarm sounds, a well otherwise. docs/DECISIONS.md, "Get Attention" and "Home's slot plan", both now say below Emergency; the earlier above-Emergency order is superseded |
| `settings` | Settings | B | B's last cell, at the trailing end (*What a held activation meets next*, below). The drawings put it under Stop Alert |
| `category0`…`category3` | The categories | B | Adopted: on compact widths the first two beside Stop Alert and the other two under them, then Settings; on regular widths the first under Stop Alert, the other three full height. The drawings show 2×2 beside the leading column on compact widths and one row of four on regular widths |
| `tileR_C` | Phrase tiles, row R column C | D | 3×3 on compact widths, 4×3 on regular widths |

Why this order and these places (the rules are AGENTS.md invariants 2, 8
and 10):

- **Start and stop never share a frame.** Get Attention only starts the
  alarm, at the trailing end of C; Stop Alert sits at the leading end of
  B, on another row. Type only opens typing, and Phrases only leaves it,
  in a different place (*Typing*, below).
- **What borders the text.** Beside the message, the trailing column
  holds Phrases and Type, which only choose a mode. Below it is C. On
  compact widths the message spans two of three columns, so Yes and No
  are under it and Again is under the trailing column. On regular widths
  the drawings span four of five columns, which puts Again, which
  speaks, under the message's trailing end: from there a resting look
  reaches it (Codex review of PR #20). The landed slot plan narrows the message
  to three columns and widens the trailing column to two, so Emergency,
  Yes and No are under the message, and Again and Get Attention are
  under Phrases and Type, on every width. No phrase tile, Again or Get
  Attention then borders the text, but a look resting on it can snap to
  Yes or No, which speak; that is the open hazard below.
- **Safety first, then navigation, then phrases.** Emergency, Get
  Attention, Yes and No are one activation from every Home state. They
  sit above the software keyboard on the three drawn windows whose
  keyboard top is measured, not on the zoomed iPad window, and the
  SE-class window's keyboard is not measured (*Typing* and *Slot sizes
  per device*, below).
- **The frames never move.** Across browse, typing and alarm, and across
  categories, only labels, fills and visibility change. The comparison
  frames in Figma overlay the states of each device to show it; the app's
  layout tests must assert it.
- **Two column counts, not many.** Compact widths (iPhones, narrow iPad
  windows) use three columns everywhere; regular widths use five in A, B
  and C, and four in D. A device never chooses a layout by its
  model, only by the width and height it has (AGENTS.md, *Layout on every
  device and window*).

Hazards the drawings carry. "Home's slot plan" records the message-border
hazard as open, not as an accepted exception. Invariant 10 requires
measurement and the owner's decision before any exception is adopted;
this reference grants none:

- **A look resting on the message can snap to Yes or No.** Sampled every
  4pt over the whole message block and its status line, not only from
  the text's centre, the nearest control anywhere on it, by either rule
  in *What a held activation meets next*, is Yes, No, Phrases or Type,
  or on the iPads Emergency; each is one gap (10 to 16pt) from the
  block's nearest edge. With the message over four columns on regular
  widths, Again was nearest from the block's trailing end on both iPad
  windows; over three it is nearest nowhere, and Get Attention and the
  phrase tiles are nearest nowhere on any window. So a look that rests
  near the bottom of the message can reach a control that speaks Yes or
  No. The reference app's portrait board had the same; the layout engine must remove the hazard by placement or bring
  its measured cost to the owner before the plan ships in a dwell,
  switch, head or gaze profile.
- While typing, the drawings put Clear beside the draft. **That placement
  is withdrawn** (Codex review of PR #20): a look that rests on the draft
  while reading it can land on Clear, and a recovery control with no
  fixed place does not make that safe. *Typing*, below, records the
  adopted region and the placement work still needed for Clear and its recovery.

Two more are **withdrawn** after the same review, because a held
activation meets a harmful control next:

- **Leaving typing.** The way out proposed after Codex's first review sat
  in the trailing column's top slot and left it empty when typing ended,
  so Type, directly below, was nearest and a repeat reopened typing.
  Phrases now stays in its slot in every state (*Typing*). (The drawings
  themselves put the way out in category 0, whose own name returns when
  typing ends, but region B is under the keyboard on the zoomed window.)
- **Stopping the alarm.** As drawn, Settings sits under Stop Alert, so a
  repeat after Stop opens the family cover, and on the drawn Settings
  root Family Setup covers that spot, so the next repeat opens it. The
  landed placement below moves Settings, and the drawn root is withdrawn
  (*Family screens*).

### What a held activation meets next

Scored on the layout source's frames for the four drawn windows, with
the pointer left at the centre of the control just activated, under two
nearest rules, because Snap to Item's real one is unknown: the nearest
centre, and the nearest edge with ties counted. Simulator checks measure
the implemented frames; physical-device checks establish Snap to Item and
dwell behaviour when the code exists. "Before this review" is the
drawings, except for the way out, which is the first review's proposal.

| After | Before this review | Reconciled placement |
|---|---|---|
| Stop Alert (the alarm stops, its well empties) | Settings by centre on all four windows, Settings or Emergency by edge: a repeat can open the family cover | The category under Stop Alert by centre, it or Emergency by edge: a repeat only shows a category, and a further one changes nothing |
| Phrases (typing ends) | Type on all four, with the way out in the top slot: a repeat reopens typing | Phrases itself, shown selected: a repeat changes nothing |
| Back to Talking (Settings closes) | Type, the only live control under it: a repeat opens typing | Still proposed: Phrases alone, with Back to Talking over Phrases' frame: a repeat changes nothing. Over the whole trailing column, as first proposed, Phrases and Type tied, and a repeat on Type would reopen typing (Codex review of PR #20) |

The placements adopted by "Home's slot plan" (the Back to Talking
proposal in the table remains open):

- **Region B.** Stop Alert keeps its place at B's leading end, directly
  below Emergency. On compact widths B is two rows of three: Stop Alert,
  the first category, the second; then the third, the fourth, Settings.
  On regular widths the first category sits under Stop Alert in the
  leading column, the other three categories take the next three columns
  at full height, and Settings takes the last. Every neighbour of Stop
  Alert then only shows phrases; Settings is the farthest cell of B from
  it, two cells below Get Attention on compact widths and directly below
  it on regular widths. A repeat on Get Attention meets Get Attention
  itself, which stays in place and absorbs it, so Settings is not what it
  meets next.
- **Phrases in every state** (*Typing*).
- **The message over three columns on regular widths** (*What borders
  the text*). The chains in the table above score the same with the
  trailing column two columns wide.

### Open in the slot plan

Three things remain open after PR #22 landed, for the layout engine and
Settings work to settle before the affected flows ship:

- **The Yes and No message-border hazard** (*Hazards the drawings carry*):
  the landed slot plan records it as open, not accepted. The layout engine
  removes it by placement or presents its measured cost to the owner,
  before shipping the plan in a dwell, switch, head or gaze profile.
- **A path to every category in a grown library.** The starter library's
  four categories fill region B's four category cells, and a family can
  add more (Add Category, in the Library). As drawn and as proposed, a
  fifth category has no cell on Home, so its phrases could not be
  reached (Codex review of PR #20). Nothing is unreachable in the code:
  Home on `main`, since PR #22, reserves four category slots and
  scrolls a grown library vertically inside that region ("Home's stand-in
  layout"). Editing or import must not add a fifth everyday category
  until the slot plan has a reachable place for it. The stand-in's scroll
  does not carry over because the adopted order puts categories in an L
  around Stop Alert and
  Settings, which cannot scroll as one standard container. Whatever the
  slot plan chooses keeps every category reachable through standard
  containers; keeps Stop Alert, Settings and their neighbours in place,
  never scrolled away and never moved by the library's size; leaves the
  starter library unscrolled in every profile (invariant 11), with a
  grown library scrolling at the floor at most; and scores the chain
  after every control it adds. This file proposes no answer, and its
  drawings show only the starter library.
- **Back to Talking over Phrases alone.** The landed slot plan still
  puts Back to Talking over the whole trailing column, so it
  closes onto Phrases or Type, tied; a repeat on Type reopens typing.
  Over Phrases' frame alone, Phrases is the only nearest control. This is
  a proposed correction, not an adopted change to that binding decision. The next Home/Settings work must score entry and exit
  together, record its decision and pin the bar's frames before this
  path is treated as safe. PR #23's existing safety bar is unchanged.

### Slot sizes per device

Computed by the layout source from the window size, the safe-area insets,
a 16pt margin and the gaps below; the windows are examples of space, and
the device names only label them. Widths are per column, and the
frames are the drawn ones: the leading and trailing columns one column
wide, the message over four columns on regular widths (the landed plan in
*What borders the text* widens the trailing column there to two and
changes no height). These are touch-profile frames:
every target clears the 44pt floor.

Against the gaze floors held at the densest screen (phrase tiles 136pt,
quick controls 109pt, categories 89pt; docs/DECISIONS.md, "Layouts from
the space available"), both iPad windows' tiles, safety row and
categories clear them, but the trailing and leading columns do not: they
are 103pt tall in portrait and 74pt in landscape, where Phrases, Type and
Stop Alert need 109pt and the category under Stop Alert 89pt. The
phones clear only the touch floor, and no phone window can hold the
gaze floors (*No phone window holds the gaze floors*, below). On the
iPads a gaze profile needs taller columns, taking the height from the
grid's rows or the message block and never moving a slot; the layout
engine decides that, and its tests pin it.

| Window | Gap | Column width | Phrases / Type / Stop Alert height | Safety row height | Category and Settings height | Tile (w × h) | Grid | Top of grid | Keyboard top (measured in the kit) |
|---|---|---|---|---|---|---|---|---|---|
| iPhone 17, 402×874 | 9 | 117.3 | 67 / 67 / 56 | 67 | 56 | 117.3 × 108.7 | 3×3 | 496 | 546 |
| iPhone SE class, 375×667 | 8 | 109 | 67 / 67 / 56 | 67 | 56 | 109 × 67.7 | 3×3 | 448 | not measured |
| iPad Pro 13 portrait, 1032×1376 | 13 | 189.6 | 103 / 103 / 103 | 135 | 219; 103 under Stop Alert | 240.2 × 211.3 | 4×3 | 664 | 973 |
| iPad Pro 13 landscape, 1376×1032 | 13 | 258.4 | 74 / 74 / 74 | 113 | 161; 74 under Stop Alert | 326.2 × 142.7 | 4×3 | 526 | 534 |
| iPad Pro 13 landscape with Display Zoom Larger Text, 1032×774 | 13 | 189.6 | does not fit (see below) | | | | | | 276 (measured on a simulator, typing research) |

Notes on the table:

- On the iPads the trailing column starts 52pt down, so the top-right
  corner, a Dwell hot corner, stays clear; the message block starts at the
  top inset. On phones the status bar already clears the corner.
- The starter library's largest categories, Basics and Needs, hold eight
  phrases, so every window needs nine tile slots (three rows of three on
  compact widths) to show them without scrolling. On the SE-class window
  that leaves tiles 67.7pt tall in the touch profile. The Figma frame for
  this window still draws two rows of 105.5pt, which hold only six, and
  is wrong on that point (Codex review of PR #20). Whether the starter
  words fit 109×67.7pt tiles is measured by the word-fitting work. At
  the gaze floors no phone window fits at all (next note).
- **No phone window holds the gaze floors with the starter library on
  one screen.** Invariant 8 keeps regions A, C, B and D in the same
  order in every profile, so on a phone they stack. At the gaze floors
  (docs/DECISIONS.md, "Layouts from the space available") the stack
  needs at least 1,094pt: the trailing column's two 109pt controls, the
  safety row's two 109pt rows, region B's two 89pt rows, three rows of
  136pt tiles, and the gaps. That counts the floors as heights. If a
  tile's width must reach 136pt too, three columns need 408pt, wider
  than either phone window, and two columns need four rows, 1,239pt in
  all. The iPhone 17 window has 778pt between its safe areas, and the
  SE-class window 647pt. So the "different arrangement, never scrolling
  and never a smaller floor" an earlier version of this note promised
  does not exist on a phone (Codex review of PR #20). Invariant 11 (no
  scrolling for the starter library in a gaze profile), the gaze floors
  (which only the owner changes) and a gaze profile on a phone cannot
  all hold. Which gives way is the owner's decision, put to them with
  these numbers by the layout engine's work (R1). Dwell, switch and head
  profiles have no floors yet; each gets the same check when it does.
- **The worst keyboard window does not hold the drawn plan.** On a 13-inch
  iPad with Display Zoom set to Larger Text, held in landscape (a
  1032×774pt window), Apple's keyboard starts at y 276
  (`docs/recon/2026-10-15/directions/typing.md`, section 2). Laid out as
  drawn, the safety row would span y 226 to 339 and the categories, with
  the way out, start at y 352, so the keyboard would cover all of the way
  out and most of the safety row, against invariants 2 and 10. To hold
  the safety row and the way out above it, that window needs a one-line
  message, the trailing column at its touch-floor heights and the way out
  in region A (*Typing*, below). Even then only one row of quick controls
  fits, touching the keyboard's edge, and at gaze floors (109pt) the
  trailing column and the safety row do not both fit. The typing state is
  therefore not final for this window: the band rule in "Typing is a
  state of Home" (Typing foundation) and the layout engine decide it, and
  the exceptions it needs go to the owner with their numbers.
- **The starter grid never scrolls at large text.** This file's drawings
  show AX5 in the same frames, with labels stepped down no further than
  their default size, and the grid unscrolled. Invariant 11 forbids
  scrolling the starter library in every dwell, switch, head and gaze
  profile, and iPhones run all of them. The landed stand-in checks the
  iPhone 17 window at the default size and AX5; its documented small-window
  scrolling gaps remain (docs/DECISIONS.md, "Where the grid still
  scrolls"). The layout engine must close them without reducing a
  profile's floor; the drawings are not evidence that it has done so.
  At the gaze floors no phone window fits (above). An earlier version of this note said the grid
  would scroll at AX4 and AX5; it is withdrawn (Codex review of PR #20).
- Keyboard tops are the kit's iPhone (402×332) and iPad (1210×428)
  keyboards placed at the bottom of the frame. On a device the keyboard's
  height varies with its options; the typing thread's probe records the
  real heights.

### Typing

Typing is a Home state, not a screen. As drawn: the draft field takes the
message block's frame; Type shows selected; Again reads Speak and speaks
the whole draft; Return speaks too; category 0 reads "Phrases" and leaves
typing; the grid is under the keyboard and nothing above it moves. The
status line shows the typing thread's short texts ("Message not saved",
"Message not restored") with the full sentence for VoiceOver. On the
three drawn windows with a measured keyboard the safety row (Emergency,
Get Attention, Yes, No, Speak) and the way out sit above the keyboard's
top; on the zoomed iPad window they do not (*Slot sizes per device*), and
the SE-class window's keyboard is not measured.

Two parts of the drawn typing state were withdrawn after Codex's review
of PR #20. The landed slot plan adopts Phrases in A and Clear/Put Back in
separate category slots in B. Their exact typing frames and full chains
remain for the typing implementation; the drawings do not prove fit:

- **The way out in region A.** The trailing column's top slot holds
  **Phrases** in every state, above Type: Phrases only leaves typing,
  keeping the draft, and Type only opens it. The two work like the
  segments of a mode switch, each choosing only its own mode: each shows
  selected while its mode is on, and choosing it then changes nothing,
  as Type already does while typing, so a repeat after
  either one meets the same control and stops there (*What a held
  activation meets next*). Both sit at the message's trailing side, so a
  look resting there only chooses a mode, and must stay above the keyboard. The zoomed window's full band
  does not fit as drawn, so that requirement is still unverified there. Category 0 keeps its own name.
- **Clear and its recovery away from the draft.** Clear and **Put Back**
  (which restores what Clear removed) each take a fixed category slot in
  region B while typing, apart from each other, from Speak, from Settings
  and from the draft, with the safety row between them and the text. The
  band rule keeps Clear away from the keys, and a slot beside Stop Alert
  or Settings would leave Clear where a repeat after either could meet
  it; on the compact plan no slot in B's upper row avoids both, so the
  Typing work places the two and scores their chains. On the three
  drawn windows with a measured keyboard (iPhone 17 and both default iPad
  orientations) region B stays above the keyboard, so each is one
  activation away; the SE-class window's keyboard is not measured.
- **Reaching Clear where the keyboard covers region B**, as on the zoomed
  window. Typing stays open when the keyboard is lowered (part of this
  proposal), so on an iPad the keyboard's own hide-keyboard key uncovers
  B with Clear and Put Back in their places: two activations, and nothing
  moves. A phone keyboard
  has no such key; no measured phone covers B, and a window where one
  does needs Clear placed above the keyboard or a named exception from
  the layout engine. Until then the delete key still edits the draft, one
  character at a time, and nothing is lost. (Typing foundation's review
  of this proposal, 2026-10-21.)

### Alarm

Get Attention lights Stop Alert at the leading end of region B and sets
the status line to "Sounding". Phrases still speak while the alarm
sounds. Stop Alert is the only control that stops it.

## Family screens

The binding rules are the landed Settings and first run decisions
(docs/DECISIONS.md, "Settings is a cover with a fixed safety bar" and
the entries beside it, PR #23). The descriptions below distinguish the
current contract from the historical drawings; library flows and the
Back to Talking placement proposal remain open.

Settings, Family Setup, Voice and the Library open as a full-screen cover
over Home, so each starts with the same top band at fixed frames: **Back
to Talking** at the top trailing edge, and a start-only **Get
Attention** at the top leading edge, over the message, its place kept
empty until Home has Stop Alert (the Settings and first run pull
request, PR #23). Proposed: Back to Talking sits over Phrases' frame in
Home's trailing column, not over Type, so closing Settings leaves
Phrases alone nearest, and Phrases only ever chooses the phrases (*What
a held activation meets next*). Below the band:

- **Settings root.** The drawings show one large **Family Setup** button
  spanning the screen under the band, over the spot of Home's Settings
  cell, so a held look that opens Settings would open Family Setup next.
  **That drawing is withdrawn** (Codex review of PR #20). PR #23's root
  holds one Family Setup row and a sentence, and Family Setup opens on
  passive text at least as tall as that row, so a repeat finds nothing
  there. A pointer may snap to another navigation row; main explicitly
  records the full Settings chains as unscored. With Settings at region
  B's trailing end, the Home/Settings work must score the actual chain.
- **Family Setup**: the landed rows are Set Up Step by Step, Voice
  Settings, Reaching the Screen, Keep Brickson Open, Privacy Policy and
  About, each a standard control. The Library row joins them when its
  screen lands; the drawings' Phrases row is not that finished flow. No
  toggles: a toggle turns into its opposite in place.
- **Privacy Policy**: a screen that shows the policy's text bundled in the
  app, so it opens with no network, and on it a separate button that
  opens the web page in an in-app Safari sheet, never in Safari
  (AGENTS.md, *The privacy policy is a promise*; App Review Guideline
  5.1.1(i)). This screen is not drawn in the Figma file yet; it shares
  the family screens' top band.
- **Voice**: the drawings show a "now speaking" line, a Personal Voice
  action, separate Hear/Use controls and Slower/Faster around a rate
  name. The landed Settings contract instead uses the fixed speed choices
  in docs/DECISIONS.md, "Speed is a set of fixed choices". Personal Voice
  permission remains governed by "Personal Voice permission is asked at
  launch, for now" and device check D1. PR #27 has since added the
  explained Ask to Use Personal Voice state under `.fromSettings`, which
  the app does not use yet. While asking, a repeated press asks nothing
  more and Settings holds its idle reset. Answer words reserve their room,
  the button becomes passive text in its existing place, and no new button
  appears on that visit. The landed decisions "Voice Settings keeps its
  places while it is open" and "Asking for Personal Voice from Voice
  Settings" also keep existing voice rows in place and append arrivals.
  The ready-to-turned-off card's longer words and the chain through iOS's
  real question remain recorded gaps. These decisions win over the
  drawings; this reference does not switch the permission policy.
- **Library and phrase editor: drawn for their look only, not as a
  flow.** The drawings show the Library list (a reserved status line for
  save results; the Emergency category row first with a note that it
  cannot be deleted; a row per category; Add Category; a note on
  backups; Export and Restore) and a phrase editor (the field, Save,
  Move to…, Delete Phrase, a reserved line for a failed save, and the
  delete question in the same frames, with Keep Phrase in Delete's
  frame). Use them for row styles, fills, type and spacing. They are not
  a flow to build from, for two reasons (Codex review of PR #20):
  - **No way to a phrase.** Nothing drawn lists a category's phrases or
    offers Add Phrase, so the drawings give no route to write a new
    phrase or to open the editor on an existing one.
  - **The delete chain is not scored.** Keep in Delete's frame only
    covers a repeat on Delete itself. A held activation that opens the
    editor from a phrase row, the question, the confirmation and the
    screen the editor closes onto are one chain. In the reference app a
    resting look went from a phrase tile to the editor, to Delete
    Phrase, to the confirmation (docs/LESSONS.md, "Score chains, not
    single hops").

  The Library screens work designs the flow: a phrase list for each
  category with Add Phrase, the editor, and where delete's confirmation
  sits. It scores the chain from entry to dismissal, from every start
  point, under both pointer models and with a look returning to where it
  started, in one chain engine (docs/LESSONS.md, "One chain engine, not
  five scripts"), under invariants 3 and 10.

## Apple's guidelines and Liquid Glass

Read against the Human Interface Guidelines pages for materials, colour
and typography on 2026-10-21 (developer.apple.com, Markdown versions):

- **Liquid Glass belongs to navigation and controls that float over
  content, never to the content layer**, and Apple asks for it sparingly
  in custom controls. Home's controls are the content: a grid of large,
  solid, measured fills whose contrast must hold in every appearance.
  Glass blurs and adjusts luminosity from whatever sits beneath, so a
  ratio measured once cannot be promised. **Home therefore uses solid
  fills**, and `PaletteTests` pins them.
- **System components keep their glass, once it is measured.** The
  family screens' navigation bars, toolbars, sheets, the in-app Safari
  sheet and the file picker are standard components, and they adopt
  Liquid Glass by themselves; the family screens use no system alerts
  (PR #23). Glass on them is context-dependent, the same reason Home
  avoids it, and invariant 6 covers the system components the app shows.
  So each one Brickson presents is captured in light, dark, Increase
  Contrast and Reduce Transparency, over the content it really floats
  over, and its words and edges are measured from the captures like
  Home's pairs. One that fails gets an opaque backing behind it, or
  Brickson's own measured control in its place, never a guess that the
  system keeps it legible. Words Brickson draws over them are measured
  in the same captures. None of this is measured yet: it is a check for
  the family screens' pull requests and their UI tests' captures.
- **No custom glass buttons.** `glassEffect` on Brickson's own buttons is
  not used: it would be glass in the content layer, and the words on it
  would lose their measured ratio. If a later decision adopts it for the
  family screens' standard button styles, the pairs are measured in each
  appearance first and pinned.
- **Colour follows the HIG rule to use colour for meaning, sparingly:**
  one fill per role (phrase, control, emergency, attention, stop), never
  decorative tints, and every meaning also carried by words.
- **Dynamic Type everywhere**, with the HIG ladder above. Frames may be
  sized from the window, input profile and text size, as "Home's slot
  plan" decides. For that configuration they stay fixed across states,
  including the keyboard appearing; labels fit by the rule in *Type*.
  The drawings' identical frames at Large and AX5 are not a rule that
  prevents controls growing with text.
- **Standard navigation stays.** Back buttons, Close, the edge swipe and
  the sheet grabber are never hidden to clear a corner (AGENTS.md,
  *Design rules for dwell, switch and pointer input*).

## The app icon

The current icon is a placeholder, and the repository review of
2026-10-21 notes that it resembles Messages. The release icon is a
layered Icon Composer icon with light, dark, tinted and clear
appearances, from artwork the owner approves (the logo in `design/brand/`
is the starting point). Nothing in this file or the Figma file is that
artwork, and Icon Composer runs only on a Mac, so the icon is made with
the release chores (docs/ROADMAP.md, R0 item 11).
