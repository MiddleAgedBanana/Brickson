# Phrase tiles' contrast measured on the rendered pixels, and the Home order flake

*2026-11-16. Pull request #119 (`claude/project-thread-5ulks4`). A
Claude Code thread in the project, on the owner's Mac.*

## What changed and why

Nothing a person sees changed. This pull request records two checks.

**1. The phrase fill under Increase Contrast, measured on the screen.**
Pull request #116 made the phrase tiles, the selected category, Back to
Talking and the system buttons tinted with the same blue draw
`Color("AccentColor")` instead of `Color.accentColor`, because the system
re-tinted the accent under Increase Contrast and the tiles' white words
fell to 3.95:1 in dark. Its numbers were worked out, not measured on the
pixels the app draws. They are now: on an iPhone and an iPad, in light and
dark, with Increase Contrast on and off, every control measured that
this fill draws (all but two, named in *Not verified*) is `#0A60D6`,
its white words 5.74:1, as `PaletteTests` predicts. Every target the
repository sets holds (invariant 6: words at 4.5:1, a control's edge at
3:1).

| What was measured | Light | Light, Increase Contrast | Dark | Dark, Increase Contrast |
|---|---|---|---|---|
| Phrase tiles: fill, white words | `#0A60D6`, 5.74 | `#0A60D6`, 5.74 | `#0A60D6`, 5.74 | `#0A60D6`, 5.74 |
| Tile fill against the screen | 5.74 | 5.74 | 3.66, inside a white border (21) | 3.66, inside a white border (21) |
| Pressed tile: the ring against the fill | black, 3.66 | black, 3.66 | white, 5.74 | white, 5.74 |
| Selected category (Basics): words; selection ring | 5.74; white 5.74 | 5.74; white 5.74 | 5.74; black 3.66 | 5.74; black 3.66 |
| Back to Talking | 5.74 | 5.74 | 5.74 | 5.74 |
| Setup's first step: the chosen answer and Next | 5.74 | 5.74 | 5.74 | 5.74 |
| Voice Settings: the chosen speed | 5.74 | 5.74 | 5.74 | 5.74 |
| The phrase editor's Save (iPhone only) | 5.74 | 5.74 | 5.74 | 5.74 |

Each cell holds on both devices unless it says otherwise. The selected
category's rings are the ones `HomeButtonLook` draws: white inside the
edge in light, the screen's black inside a white border in dark.

**The method can see the defect.** The same scripts on a build with
`Palette.phraseFill` put back to `Color.accentColor` (never committed),
on the iPhone only, on Home, a pressed tile and Settings, in three
appearances (dark with and without Increase Contrast, light with it),
measured what pull request #115 found: with Increase Contrast in dark,
the tiles, the pressed tile and Back to Talking `#1A7BFF` with white
words at 3.95:1, and the selected category the same `#1A7BFF` (there
the method took its black selection ring, 5.32:1, as the words, so the
white words' 3.95:1 follows from the fill rather than from a measured
word pixel); in light with Increase Contrast, `#084DAB` with the pressed
ring at 2.66:1; in dark without it, `#0A60D6`. So Increase Contrast did
reach the app, and the measurement tells the fixed fill from the broken
one. This control matters because on `main`, in dark, the screenshots of
Home, a pressed tile and Settings with Increase Contrast on and off are
identical pixel for pixel (nothing there changes with it in dark); in
light they differ only in the system's own status bar and home
indicator. The system controls on the setup and Voice Settings screens
do draw differently with it on, on both simulators. `xcrun simctl ui`
read the setting back as `enabled` once, after the iPhone's last "on"
capture; it was not read back for each capture.

**2. The Home order test that fails now and then on CI's iPhone.**
`HomeAccessibilityOrderTests` checks the order in which VoiceOver, Switch
Control and Full Keyboard Access reach Home's controls: Yes, No,
Emergency, Get Attention, Again, then Phrases and Type, then the
categories (docs/DECISIONS.md, "Home's scan order and names"). It has
failed three times on CI's iPhone: once on pull request #82's run
(2026-11-06) and twice on 2026-11-15, on pull request #114's branch,
which changes no app code. All three failed in the same place and the
same way:

- Always the first state, "just opened", read right after Home appears
  (the default text size twice, AX5 once). In both runs of 2026-11-15,
  every later state, after a category was tapped, read the right order.
- The wrong read is Home in plain screen order: Phrases, Type (the
  message region, which sits at the top), then Yes, No, Emergency, Again,
  Get Attention (the safety row read row by row), then the categories.
  So no `accessibilitySortPriority` had taken effect, neither between the
  regions nor inside the safety row, although every region container and
  its identifier was there.
- The run's screen recording (run 43748510592), from about three
  seconds before that read to about a second and a half after, shows
  Home fully drawn and still. Nothing on screen moved; only the order the accessibility tree
  gave was wrong.
- CI's iPhone machine was heavily loaded then
  (`simulator-load-iphone.txt`: the simulator at 200 to 250% of the
  machine's 300%).

It does not happen on the Mac. On an iPhone 17 simulator with iOS 27.2,
the test passed 15 times in a row, and a temporary probe (never
committed) that launches Home with `launchedApp`'s arguments and reads
the order again and again for six seconds without touching anything
read the right order from the first read in all of 46 more launches: 8
with no other load, 28 with every one of the Mac's 14 processors kept
busy, and 10 with the app itself paused for 60 ms of every 80 ms (the
last 28 also waited for Yes first, as `launchedApp` does). A heavier
load stopped the app from launching before it changed the order.

Whether this is a weakness of the test or a defect in the app turns on
one thing the CI runs cannot show, because the next read always came
after a tap: whether the order comes right by itself, or stays wrong
until something on Home changes. If it comes right by itself, the test
read the tree before SwiftUI had settled it, which a person would not
meet in practice. If it stays wrong, a person whose first Switch Control
scan starts before they touch anything would be offered Phrases and Type
before Yes and No: an app defect, and a safety one, since the scan order
puts Yes, No, Emergency and Get Attention first so no step is spent
waiting before them.

So the test now finds out. When a read finds the order wrong, it reads
again for up to five seconds without touching anything, attaches each
order it saw with the time it first saw it
(`order-read-again-without-input-…`), and still fails, saying "read
again with no input, it was right … later", "read again with no input
for 5 s, it stayed wrong in … reads", or, if the tree could not be read
again at all, that whether it comes right is unknown; each failed read
is kept with its error and counted (Codex's review of this pull request,
before it opened). Nothing about what passes changed: the first read
must still be right. The next CI failure answers the question.

**Proposal for the owner, not made here.** If the next failure says the
order came right with no input, the test could accept an order that
settles within a few seconds of Home appearing, on the first state only.
That would make it pass where it now fails, so it is a weaker test and
the owner's decision. If it says the order stayed wrong, it is an app
defect to fix, with this test as its reproduction.

## Commits

- The measurement record: this file, `docs/evidence/2026-11-16-tile-contrast-pixels/`,
  and the in-place lines in docs/DECISIONS.md ("Colour tokens in four
  appearances") and docs/ACCESSIBILITY.md (the Increase Contrast row).
- The order test's second read, and its line in docs/HANDOFF.md,
  *Known gaps*.
- Codex's review of that commit, before the pull request opened: a
  failed re-read is counted and never reported as "stayed wrong".
- The first review round: this record's claims narrowed to what was
  measured, after the report-only verifier compared them with the raw
  results, and `starve.sh` added to the evidence.

## Verified

- **Where:** the owner's Mac, Xcode 27.2 (27B52), Swift 6.4.2; my own
  clone of `main` at `dc11030`; simulators made for this run, an iPhone
  17 and an iPad Pro 13-inch (M5), iOS 27.2 (24B8117), portrait, text
  size Large (the default), Home at touch's sizes, fresh test storage
  (the starter library), Debug build.
- **How the contrast was measured** (scripts in
  `docs/evidence/2026-11-16-tile-contrast-pixels/`: compile
  `measure.swift` with `xcrun swiftc -O measure.swift -o measure` beside
  them; `capture.py` takes Home, a pressed tile and Settings, `nav.py`
  any screen reached by taps, `summarise.py` gathers the results): `xcrun simctl ui`
  set the appearance and Increase Contrast; the app followed the system
  appearance (no `--appearance` argument). AXe's accessibility tree gave
  each control's frame. `xcrun simctl io … screenshot` took the screen,
  converted to sRGB by Core Graphics. Inside each frame, inset 6 points
  (4 for system buttons) to clear any ring, the fill is the most common
  colour and the words are the colour with the highest contrast against
  it, counted where it reaches that extreme (hundreds to thousands of
  pixels for each control; for setup's Next in light, whose frame takes
  in the white bar around the button, the count includes that white
  too). The rings are the colours in the band
  inside the edge, and the screen is the most common colour 3 to 8
  points outside. Ratios use WCAG's formula as `PaletteTests` does
  (0.2126, 0.7152, 0.0722; 0.04045). A press was held with AXe's touch
  down while the screenshot was taken. In dark, where border and pressed
  ring are both white, the press shows as the white share of the edge
  band doubling, from 0.31 to 0.64 on the iPhone and 0.32 to 0.65 on
  the iPad (the 2-point border becoming the 4-point ring).
- **Results:** `measurements.json` there: 99 measurements on `main`,
  every one `#0A60D6` with words at 5.74:1; 18 from the control build.
  Three stills: Home in dark with Increase Contrast on the iPhone and the
  iPad, and the control build's iPhone Home in the same appearance.
- **The order test:** the changed test passed both of its cases on the
  iPhone 17 simulator. With its expected order deliberately wrong (Again
  before Get Attention, never committed) it failed in all nine states,
  each saying "read again with no input for 5 s, it stayed wrong in"
  about 300 reads, with nine `order-read-again-without-input`
  attachments, so the new path runs and reports. That change to the
  expectation is what makes it fail. The path for a tree that cannot be
  read again was not forced.
- The unit suite and the Python checks in AGENTS.md, *Build and test*,
  ran on this Mac before the commit (see the pull request).

## Not verified

- A real device. The Simulator's pixels are what the app asks the
  renderer for; a real screen's are not measured. The device check
  "Buttons under Increase Contrast and Reduce Transparency, measured on
  the rendered pixels" (docs/HANDOFF.md, *Checks that need a real
  device*) stays.
- Reduce Transparency, Show Borders on, text sizes other than Large,
  landscape, and the iPad's lifted dark screen in multitasking (a known
  gap of its own in docs/HANDOFF.md).
- Two controls this fill draws were not reached: the category editor's
  Save (the second `settingsRowStyle(fill: Palette.phraseFill)` in
  `LibraryEditors.swift`) and setup's later rest-board choice (the
  chosen answer in `GuidedSetupView.swift`'s third use of the fill).
  Each is the same style as one that was measured (the phrase editor's
  Save, setup's first-step answer). The Library's Save was measured on
  the iPhone only. `nav.py` reaches them on both simulators.
- The control build ran on the iPhone only, in three appearances, on
  Home, a pressed tile and Settings.
- The probe runs' load commands were not saved with their logs: 16
  `yes` processes for the first 10 busy launches, 22 for the other 18,
  and `starve.sh` with 0.06 s stopped and 0.02 s running for the paused
  ones.
- Of the test's new messages, only "stayed wrong in … reads" was
  forced, at the default text size on the iPhone. The changed test was
  not run on an iPad here; CI's UI jobs run it on both.
- Why CI's first read is in screen order. No reproduction here; the
  test's new second read is how the next failure will say more.

## Follow-ups

- When CI next shows the order failure, read its message and its
  `order-read-again-without-input` attachment, and follow the proposal
  above: the owner decides on a test that accepts a settling order, or
  the app's order gets a fix. *(the next thread whose CI shows it)*
- The device check on a real screen. *(owner, with a device build)*
