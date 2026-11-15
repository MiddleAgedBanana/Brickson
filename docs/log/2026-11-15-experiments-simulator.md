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

### SIM-4. Brickson's edit sheets against Apple's sheet guidance (D-22)

- **Done.** Read the Human Interface Guidelines' Sheets page
  (developer.apple.com, `.md` form; its change log: "March 24, 2026:
  Updated guidance for button placement"). Ran Brickson on the iPhone
  with fresh test storage (the starter library), opened Settings >
  Family Setup > Phrases and Categories > Basics > Edit Phrase >
  Delete Phrase, and took a screenshot and the tree of each screen.
  Searched `Brickson/` for `.sheet(`, `fullScreenCover(`,
  `confirmationDialog(` and `.alert(`.
- **Observed.** Apple's page, for iOS and iPadOS: "the Cancel button
  belongs on the leading edge of the top toolbar. When present, the
  Done button belongs on the trailing edge"; a Done button is always
  paired with Cancel or Back; Cancel, Done and Back are never shown
  together; swiping down dismisses a sheet, with an action sheet to
  confirm unsaved changes. Brickson's library edits use **no sheets**:
  Settings is a full-screen cover (docs/DECISIONS.md, "Settings is a
  cover with a fixed safety bar"), and Phrases and Categories, a
  category, Edit Phrase, New Phrase and the Delete Phrase question are
  screens pushed inside it. Each has the standard Back button on the
  leading edge, its title, and its action as a large button in the
  content (Save; Delete for Good above, Keep Phrase in the place of the
  row that asked). Back to Talking, the way out of the cover, sits at
  the top trailing corner on every screen. The app's only `.sheet` is
  the privacy policy's web page (Safari's own view controller); the
  backup's share sheet and file picker are the system's. There is no
  `confirmationDialog` or `.alert` in `Brickson/`.
- **Answer.** Apple's sheet placement rules have nothing in Brickson to
  apply to: the edit screens are pushed screens with standard Back,
  not sheets. The one resemblance is the cover's way out: Back to
  Talking is at the trailing edge, where a sheet would put Done; a
  sheet's Cancel or Close goes on the leading edge, which Brickson's
  screens give to the standard Back.
- **What it means.** No roadmap item is needed for sheets. Whether
  the cover's trailing way out still reads as Apple's would is a design
  question for the family screens; the placement is recorded in the
  decision above and nothing changes in this stage.

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

### SIM-6. The speaking indicator and Reduce Motion (D-07)

- **Done.** iPhone, Speech station. For each indicator effect
  (Variable colour, Pulse, Breathe), with Reduce Motion off and then
  on: chose the effect on the probe's list, opened Speech, chose Speak
  sentence, and recorded the screen for 7 seconds (`xcrun simctl io
  recordVideo`). From every frame's own timestamp, measured the
  indicator's region (`speaker.wave.3`, 74 by 54 points): how often its
  look changed, its brightness cycles per second, and the symbol's
  drawn width. The probe's Status station confirmed
  `accessibilityReduceMotion = true` for the "on" runs. (In the
  Simulator the speech stalls without finishing, SIM-14, so the
  indicator stayed active through each recording.)
- **Observed.**

  | Effect | Reduce Motion off | Reduce Motion on |
  |---|---|---|
  | Variable colour | changes continuously; about 0.7 brightness cycles a second; width steady (73 to 74 points) | the same |
  | Pulse | changes continuously; about 0.44 cycles a second; width steady (72 to 74) | the same |
  | Breathe | changes continuously; about 0.44 cycles a second; **grows and shrinks, 74 to 88 points wide** | **the same, still growing and shrinking** |

- **Answer.** In the iOS 27.2 Simulator none of the three effects stops
  or changes with Reduce Motion on, and Breathe keeps changing size.
  All repeat well under three times a second.
- **What it means.** None of the three is a candidate as it stands for
  a person who asked for less motion: the indicator would need to read
  Reduce Motion itself and stop (E-08). Whether a device behaves the
  same is DEV-10's D-07 (device) part; until then, treat this as the
  Simulator's answer only.

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

### SIM-12. Window sizes and safe areas (B2-U4, B2-U6)

- **Done.** Every iPhone and iPad simulator installed (one runtime,
  iOS 27.2; iPhone Duo on its own build of it), portrait: booted each,
  opened the Ruler station, and read the window and its safe-area
  insets from a temporary line in the probe (never committed) that
  logged SwiftUI's `GeometryReader` size and `safeAreaInsets` at the
  root; `axe displays` gave each screen's size. A first version of that
  line read the insets inside an area that ignores the safe area and
  logged zeros everywhere; it was corrected and every device read
  again. The iPad (A16)'s screen never came up on its first boot
  (screenshots failed with "Invalid argument", and Device Hub's live
  view of it failed to connect, error 4002, at 17:21 and 17:24 UTC);
  after a shutdown and a second boot it was measured normally.
- **Observed (window in points; insets top / bottom; leading and
  trailing 0 unless given):**

  | Simulator | Window | Insets | In the layout engine's windows? |
  |---|---|---|---|
  | iPhone 17 | 402 by 874 | 62 / 34 | yes ("iPhone 17") |
  | iPhone 18 Pro | 402 by 874 | 62 / 34 | yes (same as iPhone 17) |
  | iPhone 18 Pro Max | 440 by 956 | 62 / 34 | yes ("iPhone 17 Pro Max") |
  | iPhone 17e | 390 by 844 | 47 / 34 | yes ("iPhone 16e") |
  | **iPhone Air** | **420 by 912** | **68 / 34** | **no** |
  | iPhone Duo, closed (outer screen) | 466 by 678 | 0 / 34, **trailing 84** | handled by "iPhone Duo"'s own tests, not this table |
  | iPad Pro 13-inch (M5) | 1032 by 1376 | 32 / 20 | yes ("13-inch iPad") |
  | **iPad Air 13-inch (M4)** | **1024 by 1366** | 32 / 20 | **no** |
  | iPad Pro 11-inch (M5) | 834 by 1210 | 32 / 20 | yes ("11-inch iPad") |
  | **iPad Air 11-inch (M4)** | **820 by 1180** | 32 / 20 | **no** |
  | **iPad (A16)** | **820 by 1180** | 32 / 20 | **no** |
  | **iPad mini (A20 Pro)** | **756 by 1158** | 32 / 20 | **no: the table's "iPad mini" is 744 by 1133** |

- **Answer.** The newest iPad mini gives an app a 756 by 1158 window
  with 32 points at the top and 20 at the bottom. Its corner radius is
  not readable through any public API, so it was not measured. iOS 26
  against iOS 27 could not be compared: no iOS 26 runtime is installed.
- **What it means.** Five windows real simulators give are not among
  `HomeLayoutEngineTests.windows` (its width sweep, with no safe
  areas, covers their widths but not these windows with their insets):
  iPhone Air, iPad Air 13-inch, the 820 by 1180 iPads and the new iPad
  mini. Adding them is a test change for a later pull request
  (*Follow-ups*). The corner radius and iOS 26's insets move to a
  device (HW-6 or DEV-12).

### SIM-13. Checks that need only the compiler (B1-U10, B2-U10, L1-U4)

- **Done.** Scratch Swift files (never committed) type-checked with
  `swiftc -typecheck` against the iOS 27.2 SDK, for an iOS 27 and an
  iOS 26 simulator target and an iOS 26 device target; the SDK's
  SwiftUI interface files searched for the names.
- **Observed.**
  - `.pointerStyle(_:)` on a `Button`: does not compile for any iOS or
    iPadOS target ("value of type 'Button<Text>' has no member
    'pointerStyle'"); the name is not in the iOS SDK's SwiftUI
    interface at all.
  - `.accessibilityAddTraits(.adjustable)`: does not compile
    ("'AccessibilityTraits' has no member 'adjustable'"). SwiftUI's
    `AccessibilityTraits` in this SDK has `isButton`, `isHeader`,
    `isSelected`, `isLink`, `isSearchField`, `isImage`, `playsSound`,
    `isKeyboardKey`, `isStaticText`, `isSummaryElement`,
    `updatesFrequently`, `startsMediaSession`, `allowsDirectInteraction`,
    `causesPageTurn`, `isModal`, `isToggle` and `isTabBar`.
    `accessibilityAdjustableAction` compiles.
  - `CHHapticEngine.capabilitiesForHardware().supportsHaptics` compiles
    for iOS. What it returns on each iPad needs the device (DEV-12).
- **Answer.** `pointerStyle(_:)` is not available to an iPadOS app in
  this SDK; SwiftUI has no `.adjustable` trait, and an adjustable
  element is made with `accessibilityAdjustableAction`. The haptics
  check compiles; its answer is a device's.
- **What it means.** Stage 1's notes on these two APIs should read as
  above. The confirmation-dialog part of this step is below, with the
  simulator results.

### SIM-14. Analysis on the Mac (G-40; G-30 and D-25 Simulator part)

**G-40, a copy of the message for a listener.**

- **Done.** A temporary unit test (never committed) built Home's layout
  with the layout engine for each of the twelve windows in
  `HomeLayoutEngineTests.windows` (four phones, the 13-inch, 11-inch and
  mini iPads in both orientations, and the zoomed ones), for the touch,
  head tracking and Eye Tracking profiles, in both modes (phrases only;
  phrases and typing), at the default text size. It searched each
  window's safe area, in 4-point steps, for the largest rectangles that
  touch no slot's frame (every slot, the message and status line
  included, and every phrase tile that shows), keeping any of at least
  120 by 24 points. For each such place, and for the message slot
  itself, it asked the chain engine (`ChainEngine.nearest`, by centre and
  by edge, ties counted) which controls a look anywhere in it meets
  first. Nothing was added to Home.
- **Observed.** No window, profile or mode has a free place of 120 by
  24 points or more: the layout gives all the room that is not a
  control to the message. The message slot's nearest controls are Yes,
  No and Emergency in phrases-only mode, and Yes, No, Phrases and Type
  (with Emergency on iPads) with typing; on the 13-inch iPad in
  landscape, phrases only, also Again and Settings.
- **Answer.** No position exists for a separate listener copy without
  moving a target, and inside the message slot a speaking control (Yes
  or No) is a nearest neighbour of the text in every window.
- **What it means.** "None is a finding too": a listener copy needs
  either room taken from another region (a layout change that moves
  targets, the owner's decision) or a place that is not on Home's
  surface (another screen or display); stage 5 (H-02) starts from this.

**G-30 and D-25, word reports when a message is spoken in parts or with
SSML.**

- **Done.** iPhone, Speech station, default voice: Speak sentence,
  Speak in three parts and Speak with SSML pauses, each followed by
  Stop speaking after about 10 seconds; the log shared with the share
  sheet's Copy and read from the Simulator's clipboard.
- **Observed.** No utterance ever finished in the Simulator. Speak
  sentence reported 8 of its 14 words (0, 5, 9, 13, 20, 24, 36 and 55;
  "brown", "jumps", "over", "the" and "dog." were never reported), in
  about 1.4 seconds, then nothing until Stop; the same 8 again on a
  second try. Speak in three parts reported part 1's four words, then
  stalled for 12.8 seconds; parts 2 and 3 never started. The SSML
  version reported 11 of its words and stalled. Stop then logged five
  utterances the probe never queued finishing or being cancelled.
- **Answer.** Could not test in the Simulator: its synthesizer drops
  word reports and never finishes, so continuity cannot be judged.
- **What it means.** G-30 and D-25 need a device: DEV-10 with the
  default voice and a Personal Voice.
