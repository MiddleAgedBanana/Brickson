# The simulator experiments, run (SIM-1 to SIM-14)

*2026-11-15. Pull request #<n> (`claude/experiments-simulator`). A Claude
Code session on the owner's Mac, running Group 1 of
[docs/EXPERIMENTS.md](../EXPERIMENTS.md) as its *What the Mac session
does next* says, with no person and no device.*

## What changed and why

Nothing in Brickson changed, and nobody using it will notice anything.
This records what the simulator could answer of the run sheet's first
group, how each answer was observed, and what it can and cannot say.
Each SIM step in docs/EXPERIMENTS.md now carries a "Found, 2026-11-15"
line pointing here.

**What this record can claim.** Only what was drawn on the screen, what
the accessibility tree reported, and what VoiceOver's test service said,
in the Simulator. Nothing here says how Snap to Item, Switch Control,
Voice Control, Eye Tracking, Head Tracking or Dwell behave or feel: the
Simulator has none of them (SIM-1, below), and AGENTS.md, *Workflow
rules*, says simulators prove nothing about them. Where a tool reported
something, the tool is named. A-1 (does Snap to Item stop on a dimmed
button) is a device question and is not answered here; SIM-5 only says
what the system reports about a dimmed button.

### Where it was measured

- Mac with Xcode 27.2; Simulator runtime iOS 27.2.
- **iPad:** iPad Pro 13-inch (M5), 1032 by 1376 points, portrait. Its
  windows have a system resize handle (Windowed Apps).
- **iPhone:** iPhone 17, 402 by 874 points, portrait.
- Settings as found on both, before any change (read with `axe settings
  show`): Light, text size Large (the default), Increase Contrast,
  Reduce Motion, Reduce Transparency and Show Borders off, Liquid Glass
  opacity 0.5, no colour filter, VoiceOver off; Full Keyboard Access off
  (Settings). Every setting changed for a step was put back after it.
- Unless a step says otherwise: Light, text size Large, portrait.
- Builds: `BricksonProbe` and `Brickson` from `main` at `7cb0299`, in a
  clone beside the owner's checkout (`~/code/brickson-experiments`).

### The tools, and what each stands for

- **AXe** (`axe describe-ui`, the open-source command-line tool on the
  owner's Mac) reads the Simulator's accessibility tree as the Mac sees
  it: element type, label, value, frame, `enabled`, custom actions. It
  shows no trait list. It stood in for Accessibility Inspector, which
  is a window app this session did not drive; the run sheet asked for
  the Inspector, so any difference between the two is unchecked.
- **XCUITest.** A temporary UI test (never committed) printed
  `XCUIApplication(bundleIdentifier:).debugDescription` for the probe,
  and walked the screen with **`XCUIDevice.shared.voiceOverService`**
  (new in the iOS 27 SDK: `enable()`, `moveForward()`,
  `currentSpeech()`), which returns what VoiceOver says at each step.
  This is VoiceOver itself running in the Simulator, not a model of it.
- **Screenshots** (`xcrun simctl io screenshot`) measured in pixels with
  a small script using `PaletteTests`' contrast formula (WCAG's
  coefficients and its 0.04045 threshold).
- Settings were changed with `axe settings set` and checked in the
  probe's Status station or in what was drawn.

## Results, step by step

### SIM-1. Inside Assistive Access (D-13, A4-U13)

- **Done.** Opened Settings > Accessibility in the iPhone and the iPad
  Simulator and read every row from the accessibility tree.
- **Observed.** The page offers VoiceOver, Hover Text, Display & Text
  Size, Motion, Spoken Content, Face ID & Attention, Control Nearby
  Devices, Subtitles & Captioning, Live Speech and Keyboards & Typing
  (which holds Full Keyboard Access). There is no Assistive Access, and
  no Guided Access, Switch Control, Voice Control, Touch
  (AssistiveTouch, Dwell), Eye Tracking or Head Tracking, on either
  device.
- **Answer.** The iOS 27.2 Simulator does not offer Assistive Access.
  iOS 26 could not be tested: no iOS 26 runtime is installed, and this
  session did not download one. Part (b), the probe's "Assistive Access"
  preview, needs the project open in Xcode's canvas or the Xcode MCP's
  preview rendering, and AGENTS.md, *Build and test*, says an agent
  never opens `Brickson.xcodeproj`: not done (UNVERIFIED). Part (c),
  Brickson inside Assistive Access, needs a device.
- **What it means.** Apple's own dressing of controls inside Assistive
  Access waits for DEV-12, or for the owner to render the preview in
  Xcode (*Not verified*, below). The run sheet's (b) conflicts with
  AGENTS.md; the fix proposed is in *Follow-ups*.

### SIM-2. Control sizes (D-01)

- **Done.** Styles station, section "Control sizes, bordered
  prominent", on both devices, at text size Large and at the largest
  accessibility size (AX5). Frames from AXe; at Large on the iPhone the
  drawn fills were also measured in a screenshot down each button's
  middle.
- **Observed (height in points; iPhone and iPad gave the same):**

  | Size | Large text | AX5 |
  |---|---|---|
  | `.mini` | 34 | 76 |
  | `.small` | 34 | 76 |
  | `.regular` | 38 | 80 |
  | `.large` | 54 | 96 |
  | `.extraLarge` | 54 | 96 |

  The drawn fills matched the frames (Regular 38, Large 54, Extra large
  54). Widths follow the words (Extra large is wider only because its
  label is longer).
- **Answer.** `.extraLarge` draws exactly as tall as `.large` on iOS
  27.2, on iPhone and iPad, as Apple's API page says. Sizes grow with
  Dynamic Type.
- **What it means.** Settled, as stage 2 expected: family screens gain
  nothing from `.extraLarge`. No system size reaches Brickson's switch,
  head or eye floors at the default text size (54 against 88, 109 and
  136 points), so Home keeps its own sizes from the layout engine.

### SIM-3. Shapes, text sizes and the segmented picker (D-24)

- **Done.** Styles station, sections "Large glass with border shapes"
  and "Toggles and pickers", on both devices at Large and AX5: frames
  from AXe; screenshots of the iPad at Large and at AX5.
- **Observed.**
  - `.glass` buttons take `buttonBorderShape`: Capsule is a capsule,
    Rounded 12 a rounded rectangle, Circle a circle (54 by 54 points at
    Large, 96 by 96 at AX5). They grow with Dynamic Type like the other
    styles (54 tall at Large, 96 at AX5).
  - A segmented `Picker` is 31 points tall at `.mini`, `.small` and
    `.regular`, and 48 at `.large` and `.extraLarge` (each segment 32 or
    49). **It is the same height at AX5**, on both devices, and in the
    AX5 screenshot its words were drawn at the same small size as at
    Large while the rest of the page grew (seen, not measured). It
    stretches to the width it is given.
- **Answer.** Border shapes: yes. The tallest system segmented picker is
  48 points, and it does not grow with Dynamic Type.
- **What it means.** 48 points reaches the touch profile's 44-point
  floor for Phrases and Type, but not switch and head tracking's 88 or
  Eye Tracking's 109 (`HomeLayout.Profile.modeControlFloor`). A joined
  Phrases and Type control cannot be a system segmented picker in those
  profiles without a custom style, which stage 5 would have to justify;
  and its words would not follow the person's text size.

### SIM-5. What the system says about each element (A-1a, A3-U8 Simulator part)

- **Done.** Snap station on both devices: AXe, the UI test's
  `debugDescription`, and a VoiceOver walk with `voiceOverService`.
  Styles station's seven dimmed buttons: AXe on both devices, VoiceOver
  on the iPhone. The first iPad AXe read, taken 1.5 seconds after
  opening the station, still held the previous screen's list; a read
  after it settled matched the UI test, and only settled reads are used.
- **Observed (the same on iPhone and iPad):**

  | Element | AXe | UI test | VoiceOver says |
  |---|---|---|---|
  | Counter | Button, enabled | Button | "Counter Button" |
  | **Dimmed** (`.disabled(true)`) | **Button, enabled false** | **Button, Disabled** | **"Dimmed dimmed Button"** |
  | Plain words | StaticText | StaticText | "Plain words" |
  | Interactive words (`accessibilityRespondsToUserInteraction(true)`) | StaticText | StaticText | "Interactive words" |
  | **Hidden** (`accessibilityHidden(true)` on a Button) | **Button, present** | **Button, present** | **skipped** |
  | Empty place (a drawing, hidden) | absent | absent | absent |
  | Actions (two named custom actions) | Button, actions listed | Button | "Actions Button Actions available" |
  | Toggle (`.toggleStyle(.button)`) | CheckBox, switch, value 0 | Switch, value 0 | "Toggle Switch button off Double tap to toggle setting." |
  | Picker (segmented) | a tab group of two radio buttons, 90 by 49 each | SegmentedControl of two Buttons, Phrases Selected | "selected Phrases Button 1 of 2", "Type Button 2 of 2" |
  | Round shape (`contentShape(.accessibility, Circle())`) | Button, frame 140 by 140 (the circle's bounds) | same | "Round shape Button" |
  | Not responding (`accessibilityRespondsToUserInteraction(false)`) | Button, enabled | Button | "Not responding Button" |
  | Trait words (`.isButton` on words) | Button, 96.5 by 24 | Button | "Trait words Button" |
  | Styles' dimmed buttons (Automatic, Bordered, Bordered prominent, Borderless, Plain, Glass, Glass prominent) | Button, enabled false, each | (not run) | "<name>, dimmed dimmed Button", each |

- **Answer.** Yes: a dimmed SwiftUI `Button` is reported as a button
  that is not enabled, by all three tools, and VoiceOver says "dimmed".
  No tool showed any difference for "does not respond" or for
  interactive words. A button hidden with `accessibilityHidden(true)`
  stays in both automation trees although VoiceOver never reaches it.
- **What it means.** The system can tell a dimmed button from an
  available one, so a "real control that is not available" (stage 1's
  third case) is something each input method could treat differently;
  whether Snap to Item does is A-1, on a device (DEV-1). The two
  responds-to-interaction modifiers change nothing these tools show, so
  their effect, if any, is a device question too (DEV-1, DEV-7, DEV-8).
  A UI test that sees an element does not prove VoiceOver reaches it
  (SIM-11).

### SIM-11. The trees each tool sees (A-45 Simulator part: B3-U8; A2-U13, A3-U17)

- **Done.** Groups station on the iPhone in all four combinations of
  its options (regions contained or not; right region first or not),
  and the Snap station on both devices: AXe, the UI test's
  `debugDescription`, a VoiceOver walk, and, with Full Keyboard Access
  turned on in the Simulator's Settings, Tab pressed eleven times (HID
  key 43, through AXe), a screenshot after each, and the focus ring
  found by comparing each screenshot with the first.
- **Observed.** (a, b) AXe and the UI test list the same elements, in
  the same order, with the same frames, on every screen tried. (c) The
  Simulator offers Full Keyboard Access, and the Mac's key presses move
  its focus. (d) `voiceOverService` runs in the Simulator: it turned
  VoiceOver on, `currentSpeech()` returned the app's name, and
  `moveForward()` walked every element.

  Order of the six buttons (Left 1 to 3, Right 1 to 3), iPhone:

  | Regions | Right first | AXe and UI test | VoiceOver | Full Keyboard Access (Tab) |
  |---|---|---|---|---|
  | contained | yes | L1 L2 L3 R1 R2 R3 | **R1 R2 R3 L1 L2 L3** | L1 L2 L3 R1 R2 R3, Back |
  | contained | no | L1 L2 L3 R1 R2 R3 | L1 L2 L3 R1 R2 R3 | L1 L2 L3 R1 R2 R3, Back |
  | not contained | yes | L1 R1 L2 R2 L3 R3 | **R1 R2 R3 L1 L2 L3** | L1 R1 L2 R2 L3 R3, Back |
  | not contained | no | L1 R1 L2 R2 L3 R3 | L1 R1 L2 R2 L3 R3 | L1 R1 L2 R2 L3 R3, Back |

  The trees show a contained region as a labelled group ("Left region");
  VoiceOver speaks its name with the first button. The first Full
  Keyboard Access run of the first row started one step late (its first
  Tab landed on Left 2, and one later Tab showed no ring); a second run
  gave the clean order above. On the iPad, VoiceOver also reaches the
  system's window handle ("Resize Brickson Probe Bottom Right") after
  the app's own elements; neither tree lists it.
- **Answer.** Same elements, with three differences: a button hidden
  with `accessibilityHidden(true)` is in both trees but VoiceOver skips
  it (SIM-5); `accessibilitySortPriority` changes VoiceOver's order but
  neither the trees' order nor Full Keyboard Access's; and on iPad
  VoiceOver reaches the system's window handle.
- **What it means.** Brickson uses neither `accessibilitySortPriority`
  nor `accessibilityHidden` on a control today (a search of
  `Brickson/`), so for Home as it is, the order its UI tests read is
  the order VoiceOver and Full Keyboard Access took in the Simulator.
  If Brickson ever sets a sort priority, `HomeAccessibilityOrderTests`
  stops standing for VoiceOver's order. Switch Control's scan is not in
  the Simulator, so whether its groups follow the trees stays DEV-7.
