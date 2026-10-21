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
- `docs/ROADMAP.md` item 9 and its repository-review lines, and the app
  icon's owner in `docs/HANDOFF.md` and `docs/APP-STORE.md`, are brought up
  to date (*Follow-ups*).

## Commits

The design commit, then a merge of `main` (PRs #12, #13, #15, #16 and #18)
that moves the decision and this record into the new documentation
structure. Hashes are on the pull request.

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

## Not verified

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
- Gaze-profile column heights on the iPads, and whether the iPhone grid
  scrolls at AX4 and AX5. *(R1 layout engine; Phone layout and word
  fitting)*
- Pins in `PaletteTests` for Get Attention and Stop when their fills
  enter the code. *(Speech engine and Get Attention, next pull request)*
- The release app icon: owner-approved artwork, then a layered Icon
  Composer icon on a Mac. This thread ends with this pull request without
  making it. *(Release chores, R0 item 11)*
- The Figma account's free plan limits reads through the connector to a
  small number a month; agents draw with write scripts, which are not
  limited, and take screenshots inside them.
