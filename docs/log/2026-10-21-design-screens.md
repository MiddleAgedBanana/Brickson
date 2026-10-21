# Screens drawn, design tokens and the Liquid Glass review

*2026-10-21. Pull request from `claude/project-thread-ho952i`. Figma and
Claude Design screens thread.*

## What changed and why

Brickson's screens are drawn, so the build can follow a design (docs/SDLC.md,
*2. Design*), and the measured colours, type ladder and slot sizes are
written down in one place.

- **The Figma file** (in the owner's account,
  https://www.figma.com/design/zCYdh8hSJ9ZmrVhtealp8f) has three pages:
  *Foundations* (colours with contrast, the Dynamic Type ladder, slot
  sizes), *Home* (two iPhone windows and the iPad Pro 13-inch in portrait
  and landscape; browse, typing and alarm; light, dark and AX5; frames
  that overlay the states to show that no control moves) and *Settings
  and Library* (Settings root, Family Setup, Voice, the Library list, the
  phrase editor and its delete question). Status bars, home indicators,
  keyboards and the light and dark colour variables come from Apple's iOS
  and iPadOS 27 kit; Brickson's own controls are drawn by one layout
  source that also drives the prototype.
- **A Claude Design prototype** of the same screens, private to the owner
  until they share it: an iPhone Home to tap through, and still frames of
  the other states and the iPads.
- **`docs/DESIGN.md`**, new: where the drawings are and what came from
  where, the colour tokens with measured contrast, the type ladder and the
  word-fitting rule, the slot plan as drawn, slot sizes for four example
  windows with the gaze floors they do and do not meet, typing and alarm
  states, the family screens, the review against Apple's guidelines for
  materials, colour and typography, and the app icon.
- **`docs/DECISIONS.md`**: one new entry, "Solid fills on Home, system
  glass elsewhere" (a default the owner left to the project), and its row
  in *Decided by default on 2026-10-21*. Home's controls keep solid,
  measured fills; system components on the family screens keep the glass
  the system gives them; and the alarm's two controls get their own
  measured colours, Get Attention `#B45309` and Stop `#0F766E`.
- **The slot plan itself is not decided here.** An earlier local version
  of this change recorded a "Home's slot plan" entry; that entry belongs
  to the Phone layout and word fitting work, which builds the slots, so
  this pull request draws to it and links to it instead of writing it.
  The same holds for "Settings is a cover with a fixed safety bar" and
  "Typing is a state of Home": `docs/DESIGN.md` names all three as being
  written in other pull requests, and calls its own sections on those
  subjects proposals until they merge (Codex's second review).
- **After Codex's review of this pull request**, five corrections to
  `docs/DESIGN.md`. Clear beside the draft is withdrawn, and the way out of
  typing moves to the trailing column's top slot while typing, with Clear
  and a Put Back control proposed for fixed slots in region B. The zoomed
  iPad window (1032×774 in landscape, keyboard at y 276) is added, and
  shown not to hold the drawn typing state. The iPhone SE-class grid
  needs three rows, because Basics and Needs hold eight starter phrases.
  The Privacy Policy row opens a bundled policy screen with a separate
  button for the web page. The typing field gets a `fieldEdge` colour,
  `#767676`, that clears 3:1 against the field and the screen in both
  appearances, where the hairline did not; the decision records it.
- **After Codex's third review**, the drawn plan's held-activation chains
  were scored (`docs/DESIGN.md`, *What a held activation meets next*). As
  drawn, a repeat after Stop Alert meets Settings and then Family Setup;
  with the way out the first review proposed, a repeat after leaving
  typing meets Type and reopens it. The
  proposal now keeps Phrases in its slot in every state, shown selected
  while browsing, and moves Settings to the end of region B, with a
  category under Stop Alert. The drawn Settings root is withdrawn in
  favour of PR #23's. The note that the phone grid would scroll at AX4
  and AX5 is withdrawn, because invariant 11 forbids it in every dwell,
  switch, head and gaze profile. System glass on the family screens is
  adopted only once each component measures, and the decision says so.
  Two errors found on the way are corrected: regular widths have five
  columns in C, not four, and on regular widths Emergency and Again
  border the message, not only Yes and No.
- **After Codex's fourth review**, three more changes to `docs/DESIGN.md`.
  On regular widths the drawn message spans four of five columns, so
  Again, which speaks, sits under its trailing end; sampling the whole
  message block found Again nearest from there on both iPad windows. The
  proposal narrows the message to three columns and widens the trailing
  column to two, which puts Again and Get Attention under Phrases and
  Type; the held-activation chains score the same. The Yes and No
  exception is restated from the whole block, not only its centre. A
  grown library's fifth category has no cell in the drawn or proposed
  region B, and the proposed L-shaped order cannot scroll as one standard
  container, so *Open in the slot plan* hands that to "Home's slot plan"
  with the conditions an answer must meet. The Library and phrase editor
  drawings are kept for their look only: they give no route to a phrase
  or to Add Phrase, and the delete chain from entry to dismissal is not
  scored, so the Library screens work designs that flow.
- `docs/ROADMAP.md` item 9 and its repository-review lines, and the app
  icon's owner in `docs/HANDOFF.md` and `docs/APP-STORE.md`, are brought up
  to date (*Follow-ups*).

## Commits

The design commit, a merge of `main` (PRs #12, #13, #15, #16 and #18),
the commit that moves the decision and this record into the new
documentation structure, and the commits answering Codex's reviews. Hashes
are on the pull request.

## Verified

Documentation only; nothing was built or run, and this thread cannot
build Swift. GitHub CI runs the usual suites on the pull request.

- The contrast ratios were computed from the hex values with the WCAG 2
  formula. The three fills already in the code match `Palette` and its
  `PaletteTests` pins; the two alarm colours are not in the code and need
  their pins when they arrive.
- The slot sizes come from one layout source, written in Python and
  ported to JavaScript, whose outputs were compared; the same source drew
  every Figma frame and the prototype. They are a design, not
  measurements of the app.
- The Figma frames were checked by screenshots taken inside the drawing
  scripts. Keyboard tops are Apple's kit keyboards placed at the bottom of
  each frame, not device measurements.
- Apple's guidelines were read on 2026-10-21 from developer.apple.com's
  Markdown pages for materials, colour and typography.
- The held-activation table was computed from the layout source's frames
  by a short script, not committed (nearest centre, and nearest edge with
  ties), with the pointer at the activated control's centre. It shows
  what each arrangement does under those two rules, not what Snap to
  Item does. The same script sampled every 4pt of the message block and
  its status line for the nearest control under both rules.

## Not verified

- The Figma frames are not redrawn for the reviews' corrections: they
  still show Clear beside the draft, a well where Phrases now stays,
  Settings under Stop Alert, the withdrawn Settings root, two grid rows
  on the SE-class window, the hairline as the field's edge and the
  message over four columns on regular widths.
  `docs/DESIGN.md` says so where each applies, and wins over the frames.

- Label fits: the Figma file uses Inter, because SF Pro is listed in the
  owner's Figma account but does not render there, and SF Symbols are not
  drawn (each layer name carries the symbol's name). The app's own
  word-fitting decides.
- No Apple accessibility kit was found in the owner's Figma account; the
  type ladder comes from the Human Interface Guidelines instead.
- Whether the drawn exceptions to invariant 10 hold under Snap to Item
  and a real dwell: that needs the code, the scoring and a device.
- The trailing and pinned columns are below the gaze floors on both iPad
  windows as drawn (`docs/DESIGN.md`, *Slot sizes per device*).

## Follow-ups

- **"Home's slot plan"** in docs/DECISIONS.md, with the slots' identifiers
  and the named exceptions the drawings carry. *(Phone layout and word
  fitting)* The drawings put Stop directly below Emergency, because the
  safety row sits above the categories; docs/DECISIONS.md, "Get
  Attention", says Stop takes the cell above Emergency, from the earlier
  order. That pull request settles it and corrects whichever is wrong.
  Its version of 2026-10-21 22:17 UTC puts Stop directly below Emergency
  and adopts this pull request's proposals for region B (Settings at its
  end, a category under Stop Alert) and for Phrases in every state. It
  still has to settle the message's width on regular widths, the Yes and
  No exception, and a path to every category in a grown library
  (`docs/DESIGN.md`, *Open in the slot plan*).
- The Library and phrase editor flow: a phrase list for each category
  with Add Phrase, the editor, and where delete's confirmation sits,
  with the chain from entry to dismissal scored in one chain engine.
  *(The Library's screens)*
- Gaze-profile column heights on the iPads, and whether the iPhone grid
  fits at AX4 and AX5 without scrolling. *(R1 layout engine; Phone layout and word
  fitting)*
- Captures and measurements of every system component the family
  screens present, in light, dark, Increase Contrast and Reduce
  Transparency. *(Settings and first run, and the Library's screens)*
- Where Clear and Put Back sit while typing, away from the keys, from
  Stop Alert and from Settings, and their chains. *(Typing, next pull
  request)*
- Pins in `PaletteTests` for Get Attention and Stop when their fills
  enter the code. *(Speech engine and Get Attention, next pull request)*
- The release app icon: owner-approved artwork, then a layered Icon
  Composer icon on a Mac. This thread ends with this pull request without
  making it. *(Release chores, R0 item 11)*
- The Figma account's free plan limits reads through the connector to a
  small number a month; agents draw with write scripts, which are not
  limited, and take screenshots inside them.
