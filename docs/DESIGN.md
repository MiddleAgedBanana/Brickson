# Design: tokens, type, slots and screens

The design reference for Brickson's screens. It records the measured
colour pairs, the Dynamic Type ladder the layout follows, the slot plan
every screen keeps, and where the drawings live. Code that sizes or colours
a control points here by section title. Where this file and a decision in
docs/DECISIONS.md differ, the decision wins; tell the next agent by fixing
this file in the same pull request.

Everything here is drawn and computed, not run on a device. The numbers
come from one layout source shared by the Figma file and the Claude
Design prototype, so the two agree with each other; the app's layout
engine must reproduce them and its tests must pin them (AGENTS.md,
invariant 11).

## Where the drawings are

- **Figma file** (the owner's account, Starter plan): Brickson, file key
  `zCYdh8hSJ9ZmrVhtealp8f`. Three pages:
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
| `phrase` | `#0A60D6` | Phrase tiles, categories, Again, Speak, Type, Yes, No, Hear, Use, Save | 5.74:1 | 5.74:1 | 3.66:1 |
| `control` | `#5A6474` | Clear, Settings, Back to Talking, Family Setup rows, Slower, Faster, Move to…, Keep | 5.98:1 | 5.98:1 | 3.51:1 |
| `emergency` | `#C8161E` | Emergency, emergency phrases, Delete Phrase, "Delete … for good" | 5.85:1 | 5.85:1 | 3.59:1 |
| `attention` | `#B45309` | Get Attention | 5.02:1 | 5.02:1 | 4.18:1 |
| `stop` | `#0F766E` | Stop Alert | 5.47:1 | 5.47:1 | 3.84:1 |

Surfaces, in light / dark:

| Token | Light | Dark | Used for |
|---|---|---|---|
| `background` | `#FFFFFF` | `#000000` | The screen |
| `field` | `#F2F2F7` | `#1C1C1E` | The typing field and message block |
| `well` | `#E9E9EC` | `#2C2C2E` | A reserved slot that holds no control in this state |
| `hairline` | `#C6C6C8` | `#38383A` | Field edge, row separators |
| `label` | `#000000` | `#FFFFFF` | Text on the background and on fields |

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

- The message block always shows the full message at Title 1; a message
  longer than its block scrolls inside the block at full size and never
  shrinks (docs/DECISIONS.md, "Home version 0 is a stand-in").
- Control labels are Body semibold with a system symbol above the words
  where the control is tall enough for both.
- **Words never break** (AGENTS.md, *Design rules for dwell, switch and
  pointer input*). When a label does not fit its control, drop the
  symbol first, then step the text down one Dynamic Type size at a time,
  and never below the Large size. On the phone at AX4 and AX5 this still
  leaves a few labels too wide for a one-column slot; the drawings show
  those at Large, which is the floor, so the app will do the same.
- A person's own words (phrase and category names) are shown verbatim and
  never localized (AGENTS.md, *Workflow rules*).

## The slot plan

Home is four regions, top to bottom, in every profile and on every
device: **A** the message, **C** the safety row, **B** the categories with
a pinned utility column, **D** the phrase grid. Each slot has a stable
identifier, used as the layout engine's key, the UI tests' accessibility
identifier and the layer name in Figma, so a test, a drawing and the code
mean the same thing by the same name.

| Identifier | Control | Region | Notes |
|---|---|---|---|
| `messageText` | The message block | A | Passive text, scrolls inside its frame |
| `statusLine` | Speaking / Sounding / audio warnings | A | Passive footnote under the message; always reserved |
| `clear` | Clear | A | Trailing column, top; live only while typing, a well otherwise |
| `type` | Type | A | Trailing column, under Clear; selected while typing |
| `yes`, `no` | Yes, No | C | |
| `again` | Again, or Speak while typing | C | Same frame, label changes |
| `emergency` | Emergency | C | Two columns wide on compact widths |
| `getAttention` | Get Attention | C | Start only; never stops the alarm |
| `stopAlert` | Stop Alert | B | Pinned leading column, top; live only while the alarm sounds, a well otherwise |
| `settings` | Settings | B | Pinned leading column, under Stop Alert |
| `category0`…`category3` | The categories | B | 2×2 on compact widths, one row of four on regular widths |
| `tileR_C` | Phrase tiles, row R column C | D | 3×3 on compact widths, 4×3 on regular widths |

Why this order and these places (the rules are AGENTS.md invariants 2, 8
and 10):

- **Start and stop never share a frame.** Get Attention only starts the
  alarm; Stop Alert sits in the pinned column, two regions away. Type only
  opens typing; the way out is any category (category 0 reads "Phrases"
  while typing) and Clear only empties the draft.
- **Nothing harmful is nearest what people read.** The message text's
  nearest controls are Clear (a well while browsing) and Type; Yes and No
  are next. No phrase tile, Emergency or Get Attention borders the text.
- **Safety first, then navigation, then phrases.** Emergency, Get
  Attention, Yes and No are one activation from every Home state, above
  the software keyboard on every drawn device (*Typing*, below).
- **The frames never move.** Across browse, typing and alarm, and across
  categories, only labels, fills and visibility change. The comparison
  frames in Figma overlay the states of each device to show it; the app's
  layout tests must assert it.
- **Two column counts, not many.** Compact widths (iPhones, narrow iPad
  windows) use three columns everywhere; regular widths use four in C and
  D and one row of four categories. A device never chooses a layout by its
  model, only by the width and height it has (AGENTS.md, *Design rules*;
  docs/DECISIONS.md, "Home's slot plan").

Named exceptions, each measured and recorded (invariant 10 asks for this):

- While browsing, the trailing column's top slot is an empty well, so a
  look that rests on the message text has Type and then Yes nearest. Type
  only opens typing.
- While typing, Clear sits beside the draft field. Clear is recoverable:
  the composer keeps the cleared text, and a restore control (the typing
  thread's `restoreCleared`) needs a fixed place that is not Clear's slot.
- While the alarm sounds, Stop Alert is Settings' upper neighbour.
  Settings only opens the family cover; it never speaks.
- On the Settings root, Family Setup is the only large control, so a held
  look that opened Settings and then rests on it can open Family Setup.
  Family Setup is a list; nothing in it speaks, sounds or deletes.

### Slot sizes per device

Computed by the layout source from the window size, the safe-area insets,
a 16pt margin and the gaps below. Every size clears the 44pt floor; the
iPads clear the reference app's gaze floors (phrase tiles 110pt or more,
quick controls 88pt or more, categories 72pt or more). Widths are per
column; the trailing and pinned columns are one column wide.

| Window | Gap | Column width | Clear / Type / Stop / Settings height | Safety row height | Category height | Tile (w × h) | Grid | Top of grid | Keyboard top (measured in the kit) |
|---|---|---|---|---|---|---|---|---|---|
| iPhone 17, 402×874 | 9 | 117.3 | 67 / 67 / 56 / 56 | 67 | 56 | 117.3 × 108.7 | 3×3 | 496 | 546 |
| iPhone SE class, 375×667 | 8 | 109 | 67 / 67 / 56 / 56 | 67 | 56 | 109 × 105.5 | 3×2 | 448 | not measured |
| iPad Pro 13 portrait, 1032×1376 | 13 | 189.6 | 103 / 103 / 103 / 103 | 135 | 219 | 240.2 × 211.3 | 4×3 | 664 | 973 |
| iPad Pro 13 landscape, 1376×1032 | 13 | 258.4 | 74 / 74 / 74 / 74 | 113 | 161 | 326.2 × 142.7 | 4×3 | 526 | 534 |

Notes on the table:

- On the iPads the trailing column starts 52pt down, so the top-right
  corner, a Dwell hot corner, stays clear; the message block starts at the
  top inset. On phones the status bar already clears the corner.
- The SE-class window fits two grid rows, six starter phrases, at the
  floor. A category with more than six phrases scrolls at the floor on
  that window; it never shrinks tiles (invariant 11 allows a grown
  library to scroll, never a shrunken target).
- The iPhone 17 keeps every frame through AX3. At AX4 and AX5 the Phone
  layout thread proposes letting the grid scroll rather than cutting the
  grid to one row; this file's drawings show AX5 in the same frames with
  labels at the Large floor. The layout engine's tests decide between the
  two by measurement, and this table is updated with the result.
- Keyboard tops are the kit's iPhone (402×332) and iPad (1210×428)
  keyboards placed at the bottom of the frame. On a device the keyboard's
  height varies with its options; the typing thread's probe records the
  real heights.

### Typing

Typing is a Home state, not a screen. The draft field takes the message
block's frame; Clear becomes live; Type shows selected; Again reads Speak
and speaks the whole draft; Return speaks too; category 0 reads "Phrases"
and leaves typing; the grid is under the keyboard and nothing above it
moves. On every drawn window the safety row (Emergency, Get Attention,
Yes, No, Speak) and the way out sit above the keyboard's top. The status
line shows the typing thread's short texts ("Message not saved", "Message
not restored") with the full sentence for VoiceOver.

### Alarm

Get Attention lights Stop Alert in the pinned column and sets the status
line to "Sounding". Phrases still speak while the alarm sounds. Stop Alert
is the only control that stops it.

## Family screens

Settings, Family Setup, Voice and the Library open as a full-screen cover
over Home, so each starts with the same top band at fixed frames: **Back
to Talking** over Home's trailing column (Clear and Type) and a start-only
**Get Attention** over Home's message text on compact widths, or over
Home's Again column on regular widths. Below the band:

- **Settings root**: one large **Family Setup** button that spans from
  the safety row's top to the categories' bottom, and a passive note that
  Settings returns to this screen after 90 seconds idle and never closes
  by itself. There is nothing else to activate, so a stray look that
  opened Settings lands on text or on Family Setup.
- **Family Setup**: a list of rows, each a standard button: Get Started,
  Voice, Phrases, Reaching the Screen, Keep Brickson Open, Privacy Policy
  (opens the policy in an in-app sheet, never Safari), About. No toggles
  anywhere: a toggle turns into its opposite in place.
- **Voice**: a "now speaking" line; the Personal Voice status with one
  button ("Use My Personal Voice", or "Open Personal Voice Settings" when
  the system switch is off); one row per voice with separate **Hear** and
  **Use** (Use shows selected); **Slower**, the rate name, **Faster**,
  with the rate name between them so the two never border each other.
- **Library**: a reserved status line for save results; the Emergency
  category row first with a note that it cannot be deleted; a row per
  category; **Add Category**; a note on backups; **Export** and
  **Restore** (file picker only).
- **Phrase editor**: "In Basics" (the category, as a Move to… row), the
  field, **Save**, **Move to…**, **Delete Phrase**, and a reserved line
  for a failed save. **Delete asks first, in place**: the question
  replaces the field, "Delete “Hello.” for good" takes Save's frame, and
  **Keep Phrase** takes Delete's frame, so a repeated activation on the
  spot that asked only keeps (AGENTS.md, invariant 3).

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
- **System components keep their glass.** The family screens' navigation
  bars, toolbars, sheets, the in-app Safari sheet, alerts and the file
  picker are standard components, and they adopt Liquid Glass by
  themselves. Brickson does not restyle them; where it draws its own text
  over them it uses the system label colour, which the system keeps
  legible on glass. Reduce Transparency and Increase Contrast change
  those components' look by themselves, which is why the app shows them
  as the system draws them.
- **No custom glass buttons.** `glassEffect` on Brickson's own buttons is
  not used: it would be glass in the content layer, and the words on it
  would lose their measured ratio. If a later decision adopts it for the
  family screens' standard button styles, the pairs are measured in each
  appearance first and pinned.
- **Colour follows the HIG rule to use colour for meaning, sparingly:**
  one fill per role (phrase, control, emergency, attention, stop), never
  decorative tints, and every meaning also carried by words.
- **Dynamic Type everywhere**, with the HIG ladder above; the layout
  gives rows fixed heights that fit the largest size, so growth changes
  text, never frames.
- **Standard navigation stays.** Back buttons, Close, the edge swipe and
  the sheet grabber are never hidden to clear a corner (AGENTS.md,
  *Design rules*).

## The app icon

The current icon is a placeholder. The App Store thread's review notes
that it resembles Messages. The release icon is a layered Icon Composer
icon with light, dark, tinted and clear appearances, from artwork the
owner approves; nothing in this file or the Figma file is that artwork.
