# Typing on Home

*Roadmap: Wave 3 item 5 (R0 items 5 and 9). Owner: the Typing on Home
thread (a cloud session; GitHub CI is its build). Status: built
2026-10-24, untested until CI passes
([`log/2026-10-24-typing-on-home.md`](../log/2026-10-24-typing-on-home.md);
docs/DECISIONS.md, "Typing on Home").*

## Intent

- **Problem:** Home can only speak what the library holds. Someone who
  wants to say anything else (a name, a question, a correction) has no
  way to do it in Brickson: the typing foundation is built and tested
  (`MessageComposer`, `DraftStore`, the keyboard's measured room), but
  nothing on Home opens it. Three things wait on it too. Settings' Back
  to Talking closes the cover onto whatever lies under its spot, and a
  look resting near its edge closes it over No or Get Attention
  (docs/DECISIONS.md, "One chain engine for dwell safety", *Open:
  Settings closes under the look*); the slot plan puts it over Phrases,
  which only arrives with typing. The guide link held on PR #50 (commit
  `1de50f5`) waits for that. And Home still scrolls at the largest text
  sizes and with Display Zoom on phones, a design question (fewer tiles
  to a screen) left for this item.
- **Proposed outcome:** Type, beside the message, opens Apple's keyboard
  with the field in the message's place; the person types and chooses
  Speak, in Again's place, or Return; Phrases goes back to the phrases,
  keeping the message. Clear empties the message and Put Back brings it
  back, each in a fixed place. Nothing on Home moves when the keyboard
  shows, and Emergency, Get Attention, Yes, No, Speak and the way back
  stay above it. Settings' Back to Talking sits over Phrases, so closing
  Settings lands on a control that only chooses what Home shows.
- **Who and what it affects:** everyone who can still use a keyboard,
  by touch, Switch Control, Full Keyboard Access, Voice Control or a
  pointer, and their listeners. Home (`HomeView`), the layout engine
  (`HomeLayout`), Settings' bar (`SettingsSafetyBar`), the app's start
  (`BricksonApp`, which keeps the draft), the chain maps (`HomeChains`,
  `SettingsChains`) and the UI tests that read Home.
- **Constraints:** invariant 1 (standard `Button`s and Apple's own
  `TextField` and keyboard), 2 (every phrase still speaks at once;
  Emergency is one activation away while typing and leaves typing), 3
  (speaking never changes the library; the draft is not the library), 4
  and 5 (a draft that cannot be saved or restored says so in the status
  line, and the words stay on screen), 6 (no new colours without a pinned
  pair), 7 (the draft is the person's own words: never rewritten, never
  dropped by a repair), 8 (a state changes what a slot shows, never where
  it is), 10 (chains scored on every state, typing included), 11
  (nothing reflows when the keyboard shows), 12 (unchanged). The privacy
  policy already promises the draft ("The message you are typing, so it
  is still there if the app closes. It stays until you clear it."), and
  the app must keep that sentence true. docs/DECISIONS.md: *Home's slot
  plan*, *Typing is a state of Home*, *Typing uses Apple's keyboard*,
  *Writing Tools off while typing*, *Return speaks*, *The typed message*,
  *Settings on Home*.
- **Open questions:**
  - Where Clear and Put Back sit, and what the phrase grid shows while
    typing: decided by scoring, below (*Spec*).
  - How Back to Talking fits Phrases' frame on a small phone: decided
    below.
  - Fewer tiles to a screen: a direction for R1, drawn here, not built
    (*Spec*, *Fewer tiles*).
  - Not this item's: whether Yes and No may border the message, which
    the owner decides before R1 (docs/DECISIONS.md, "The layout
    engine"). Typing keeps the frames the owner is deciding on.

## Spec

*2026-10-24.* What the person sees, hears and can reach. Every frame is
the layout engine's (`HomeLayout`, `Modes.phrasesAndTyping`, the slot
plan's own); every state change below changes what a slot shows, never
where it is (invariant 8).

### Screens

Drawn in the Figma design file, page [*Typing on Home (Wave 3 item
5)*](https://www.figma.com/design/zCYdh8hSJ9ZmrVhtealp8f/?node-id=54-2),
from the engine's own frames (exported on the Linux harness with the real
fonts; *Measured on* below), in Apple's iOS 27 kit's keyboard, with the
code's corner radius, fonts and selected and off looks:

- iPhone 17 at the default size,
  [browsing](https://www.figma.com/design/zCYdh8hSJ9ZmrVhtealp8f/?node-id=54-692),
  [typing](https://www.figma.com/design/zCYdh8hSJ9ZmrVhtealp8f/?node-id=54-762),
  and [the positions, which never
  move](https://www.figma.com/design/zCYdh8hSJ9ZmrVhtealp8f/?node-id=54-941).
- [A 375×667 phone,
  typing](https://www.figma.com/design/zCYdh8hSJ9ZmrVhtealp8f/?node-id=54-1022).
- The 13-inch iPad in portrait,
  [browsing](https://www.figma.com/design/zCYdh8hSJ9ZmrVhtealp8f/?node-id=56-542)
  and [typing](https://www.figma.com/design/zCYdh8hSJ9ZmrVhtealp8f/?node-id=56-620).
- [Settings over Home on the iPhone
  17](https://www.figma.com/design/zCYdh8hSJ9ZmrVhtealp8f/?node-id=55-257),
  with Back to Talking over Phrases.
- Fewer tiles at AX5 on the iPhone 17 (R1's direction, not built),
  [page 1 of 2](https://www.figma.com/design/zCYdh8hSJ9ZmrVhtealp8f/?node-id=55-281)
  and [page 2 of 2](https://www.figma.com/design/zCYdh8hSJ9ZmrVhtealp8f/?node-id=55-341).

The drawings' labels are set in Inter, since the connector has no SF Pro,
so how a word fits is the engine's measurement, not the drawing's; SF
Symbols are named in layer names, not drawn.

### Home, browsing

Home as it is today, with A's trailing column added: **Phrases** above
**Type**, beside the message, as wide as Emergency's column on compact
widths and over the last two of five columns on regular ones. The
regular-width safety row becomes the slot plan's one row: Emergency, Yes,
No, Again, Get Attention, with Stop's well under Emergency. Compact
widths keep today's two rows (Yes, No, Emergency; Again, Get Attention).

- Phrases and Type work like the two segments of a segmented control,
  each a standard `Button`: the one whose mode is on shows selected (a
  check mark, a ring and the Selected trait, as a category does), and
  choosing it again does nothing. Phrases is selected while browsing.
- Assistive technologies reach Phrases and Type after the message
  (`HomeRegion`, region A), so the safety row still comes first.

### Home, typing

Choosing **Type** turns typing on and puts the cursor in the field, so
Apple's keyboard opens (*Typing uses Apple's keyboard*). Nothing moves.
Type is offered only where the whole safety row ends above the room kept
for the keyboard (`HomeLayout.offersTyping`); elsewhere it is dimmed, with
a VoiceOver hint saying why, and if the room goes while typing the
keyboard is put away and the field dimmed, typing staying on (added after
Codex's review of PR #53; docs/DECISIONS.md, "Typing on Home", *The
keyboard's room, measured*).

- **The field** takes the message's frame: a standard `TextField`
  (`axis: .vertical`, `typingFieldTraits()`), showing the draft, named
  "Message" to assistive technologies. Its edge is drawn in the control
  fill (`Palette.controlFill`, already pinned at 3:1 against the screen)
  and its words in primary ink, so no new colour pair is needed
  (invariant 6). It shows no placeholder: the system draws one in a grey
  that is not pinned and is lighter than 4.5:1 allows, and a cursor in an
  empty field framed beside Type already says what it is for. The status
  line stays under it.
- **Speak** takes Again's slot, and **Return** speaks too (*Return
  speaks*). Both say the whole draft and keep it (*The typed message*).
  Speak is disabled while there is nothing to say, as Again is before
  anything has been spoken.
- **Clear** and **Put Back** each take a category cell, away from the
  message and from Speak (`HomeLayout.typingCells`, chosen by scoring;
  *Where Clear and Put Back go*). Clear empties the draft; Put Back brings
  back what Clear took, once. Each is disabled while it cannot act.
- **The other categories are dimmed** while typing (disabled, in their
  own cells, none shown selected). Scoring found that choosing one would
  leave typing and fill the empty grid with phrases right under a look
  resting there, so the next activation would speak unasked. Phrases,
  then the category, is two activations instead of one; Emergency stays
  one.
- **The phrase grid is empty** while typing, so nothing that speaks sits
  under the keyboard and lowering the keyboard reveals nothing that
  speaks (*Typing is a state of Home*). Its frame stays.
- **Phrases** leaves typing: the keyboard goes, the phrases come back and
  the message shows the last thing spoken again; the draft is kept for
  the next Type. **Emergency** leaves typing for the emergency phrases
  (invariant 2), and **Settings** leaves typing before it opens.
- **Yes, No, Get Attention and Stop** work as always, and typing stays.
- **Lowering the keyboard** (the iPad's hide key, or a hardware keyboard)
  keeps typing; Type brings the keyboard back.
- **The status line** shows, in this order: an audio problem; the alarm
  sounding; speaking; and a draft that cannot be saved or was not
  restored ("Message not saved", "Message not restored"). Each draft
  problem is announced to VoiceOver when it appears, like the audio ones
  (invariants 4 and 5). While typing, a phrase cut off mid-sentence names
  Phrases, then Again ("Stopped: Phrases"), since Again's slot shows
  Speak.
- **The draft** is kept in Application Support/Typing (`DraftStore`),
  saved after every change, restored at launch without speaking or
  opening typing, and saved again when the app goes to the background
  after a failed save (`retrySave()`). UI tests keep theirs in their own
  test storage.

### Where Clear and Put Back go

Scored with the chain engine on the engine's frames, every pair of
category cells, every typing state (draft empty, written or cleared), by
both rules and both pointers, the empty phrase grid sampled densely along
its top edge as a place a look rests on:

- **Compact, three columns** (phones): Clear in the second category's
  cell (top row, trailing), Put Back in the fourth's (second row,
  middle). The cells under and beside Stop's well stay categories, so a
  look still resting where Stop was meets a category.
- **Regular, the band, and two columns:** Clear in the third category's
  cell and Put Back in the fourth's.
- **What is left, measured:** every cell of the band, and the second row
  of three columns, borders the empty phrase grid, so a look resting on
  the grid's top edge can meet Put Back or Clear. No pair of cells removes
  it. Put Back can only refill an empty draft with the words just cleared,
  and Clear can be undone once by Put Back, so neither loses words, but
  each changes data unasked: it is an open, measured hazard for the owner
  (docs/DECISIONS.md, "Typing on Home"), pinned as a strict known issue so
  it fails when it goes.

### Settings over Home

Settings' **Back to Talking takes Phrases' frame**, worked out by the
same engine from the same window and text size, so closing Settings
lands on Phrases, which only picks a mode and does nothing while browsing
(Settings always closes onto browsing, since opening it left typing).
*Built:* exactly Phrases' frame on compact widths; on regular ones,
where Phrases spans two columns and a look at its lower corners is
nearer Again's or Get Attention's centre, centred over Phrases, as tall,
and at most a column wide (`HomeLayout.backToTalking`; docs/DECISIONS.md,
"Typing on Home").
Its words are in the category font, on one line where the column holds
them (131pt, 142pt with Bold Text) and on two where it does not, which is
why Phrases is at least 56pt tall on those windows. Get Attention's
empty place keeps the bar's leading side. Settings' screens start under
the bar.

- **Rescored:** *Open: Settings closes under the look* (docs/DECISIONS.md,
  "One chain engine for dwell safety") is scored again on the moved
  frames, in the unit tests' model and by `SettingsOnHomeTests` on CI.
  What remains is recorded there with numbers. *Result:* choosing Back
  to Talking meets only Phrases; on the phone one closing nobody chose
  remains, through Family Setup, over No.
- **The held guide link** (Learn About Each Way, commit `1de50f5`) comes
  back only if its chains clear on the moved frames; otherwise it stays
  held, with the reason recorded (step 4 of *Plan*). *Result:* held: its
  guide's Back to Talking closes Settings over Get Attention in three
  chains on the phone model.

### Fewer tiles to a screen (R1, drawn, not built)

At the largest text sizes, and with Display Zoom on phones, the starter
library's largest category does not fit at the floors and the phrase
grid scrolls. Touch may scroll (invariant 11 applies to dwell, switch,
head and gaze profiles). For those profiles, R1 brings **pages of whole
rows**: the grid shows as many whole rows as fit, and its last slot
becomes **More, 1 of 2**, a standard `Button` that shows the next page
(and from the last page, the first). It only ever navigates, so it never
turns into its opposite, and it stays in one slot on every page. Drawn
here so the profile work starts from it; not built now, because touch is
the only profile 1.0 ships and scrolling is its cheaper path.

### The layout engine

- **Get Attention on one line beside the message.** On compact widths
  the trailing column is at least as wide as Get Attention's word on one
  line wherever the message keeps its own minimum width, so Get Attention
  and Emergency no longer take two lines on a phone at the default size.
- **Room for Phrases and Type.** Each is at least the profile's floor and
  one line of the quick controls' words, and 56pt where Back to Talking
  needs two lines at that width; region A is at least two of them and a
  gap. They grow toward the quick controls' height after the safety row
  grows, and give that growth back first where the keyboard's room is
  short.
- **Fit, re-measured** (the largest text size at which the starter
  library fits without scrolling; *Measured on* below): unchanged on
  every window measured except the 375×667 phone at the default size,
  which is 0.5pt short, so its grid scrolls by under a point (touch only;
  the gap and well rules are not weakened to win it back). The iPad mini
  and the 13-inch iPad with Display Zoom, both in landscape, now keep the
  safety row above the keyboard to the second text size, where they did
  not before. Recorded in docs/DECISIONS.md, "Typing on Home".
- **Unchanged and not decided here:** whether Yes and No may border the
  message (docs/DECISIONS.md, "The layout engine"), which the owner
  decides before R1. Typing keeps the frames that question measured;
  `Modes.phrasesOnly` stays in the engine as the comparison.

### Measured on

The engine's frames on the Linux harness (Swift 6.4.1, the real SF Pro
fonts through HarfBuzz, which matched CI within half a point): an iPhone
17 (402×874), a 375×667 phone and the 13-inch iPad in both orientations,
at the default size and AX5. No simulator, no device. What a person sees
is checked by CI's UI tests on its iPad and iPhone simulators; gaze
comfort, Snap to Item and sound are device checks.

## Plan

One pull request, built test first. This session is a cloud one: it
compiles the pure-Swift engine, the chain engine and their tests on a
Linux harness, and nothing else; GitHub CI is the build for the rest.

1. **The engine** (`HomeLayout`), tests first in
   `HomeLayoutEngineTests`: one-line Get Attention beside the message;
   Phrases' and Type's floor, with 56pt where Back to Talking takes two
   lines; their growth after the safety row and their give-back first
   under the keyboard's room; `typingCells`; the fit table re-measured.
   Each new test is run against the old engine first and fails there.
2. **The chain maps** (`HomeChains`): typing states, the draft's three
   states, Phrases and Type, Speak, Clear and Put Back, the empty grid as
   a resting place. `HomeChainsTests` pins what each control does;
   `HomeLayoutEngineTests` scores typing on the engine's frames, with the
   grid's top edge sampled densely, and pins the known Clear and Put Back
   finding as a strict known issue.
3. **Home** (`HomeView`): Home lays out with `.phrasesAndTyping`; A gains
   Phrases and Type; the regular safety row becomes one row; the field,
   Speak, Clear and Put Back; the empty grid while typing; the draft's
   problems on the status line; `HomeControlNames` and `HomeRegion` for
   the new controls, with their collision tests. `BricksonApp` keeps the
   draft (`DraftStore`, test storage under UI tests).
4. **Settings** (`SettingsSafetyBar`): Back to Talking at Phrases' frame,
   from the engine; `SettingsOnHomeTests` expects Phrases under it and
   rescored hazards; `SettingsChainsTests`' model moves with it. Then the
   guide link's chains, modelled on the moved frames, decide whether
   commit `1de50f5` comes back.
5. **UI tests:** typing on Home on CI's iPad and iPhone: Type opens the
   keyboard with nothing moved; Return and Speak speak; Clear and Put
   Back; Phrases and Emergency leave typing and the categories are dimmed; Emergency, Get
   Attention, Yes, No and Speak above the keyboard
   (`KeyboardProbeTests`' band, now read on Home while typing); the
   typing chains scored on the running app's frames; the draft survives
   a relaunch.
6. **Words and records:** the String Catalog by hand (this session cannot
   run `xcstringstool`; the tool in the project files checks it), the
   log, HANDOFF, ROADMAP, DECISIONS ("Typing on Home"), DESIGN.md,
   ACCESSIBILITY.md and the site's accessibility page where their words
   change, and the Mac, simulator and device checks this cannot do,
   listed for Codex.
