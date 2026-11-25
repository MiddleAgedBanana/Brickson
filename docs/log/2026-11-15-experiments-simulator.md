# The simulator experiments, run (SIM-1 to SIM-14)

*2026-11-15. Pull request #115 (`claude/experiments-simulator`). A Claude
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

### Overtaken since the run

Main moved on while this pull request waited; on 2026-11-25 the record
was checked against it, and each finding below stands as measured on
2026-11-15 except:

- **The accent under Increase Contrast** (SIM-10) is fixed: pull request
  #116 draws every fill from its colour set by name
  (`Palette.phraseFill` is `Color("AccentColor")`), and
  `PaletteTests.everyFillIsDrawnFromItsColourSet` checks it. Its *Known
  gaps* item and follow-up were dropped from this pull request.
- **The four missing window sizes** (SIM-12) are in
  `HomeLayoutEngineTests.windows` since pull request #120.
- **docs/ACCESSIBILITY.md's `pointerStyle(_:)` row** (SIM-13) and **the
  run sheet's SIM-1 (b)**, now the owner's step in Xcode, were
  corrected by pull request #127.

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
- Stills (the probe, and Brickson with the starter library only) are in
  [`docs/evidence/2026-11-15-experiments-simulator/`](../evidence/2026-11-15-experiments-simulator/):
  Home in dark with and without Increase Contrast (SIM-10), the
  confirmation dialog on the iPhone (SIM-13) and the segmented pickers
  at AX5 on the iPad (SIM-3). Raw captures stay in the ignored
  `private/device-checks/`.
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

## Results at a glance

| Step | IDs | Answer in the Simulator |
|---|---|---|
| SIM-1 | D-13, A4-U13 | No: the Simulator offers no Assistive Access; the preview needs Xcode open (not done) |
| SIM-2 | D-01 | Yes, answered: `.extraLarge` equals `.large` (54 points at the default text size; 96 at AX5) |
| SIM-3 | D-24 | Yes, answered: glass takes border shapes; segmented pickers stop at 48 points and ignore Dynamic Type |
| SIM-4 | D-22 | Yes, answered: Brickson's library has no sheets to compare |
| SIM-5 | A-1a, A3-U8 (Simulator part) | Yes, answered: a dimmed Button is reported "not enabled" ("dimmed" in VoiceOver's test service). This is not A-1 |
| SIM-6 | D-07 | Yes, answered for the Simulator: all three effects keep moving with Reduce Motion on |
| SIM-7 | D-14 | Could not test: Smart Invert does not show in Simulator screenshots |
| SIM-8 | D-17 | Partly: the bar's words stay above 10:1 over scrolled rows; the rows' own words under the bar not measured |
| SIM-9 | D-20 | Partly: Home's fills keep their contrast in an inactive window; system styles not run |
| SIM-10 | D-21, D-02, A-33 (A4-U17, L1-U22) | Yes, answered, with one defect in the app as it was: the accent under Increase Contrast in dark (3.95:1), fixed since by #116 |
| SIM-11 | A-45 (B3-U8), A2-U13, A3-U17 | Mostly: three differences on the probe; on Home the tree and VoiceOver's test service agree; Full Keyboard Access on Home not measured |
| SIM-12 | B2-U4, B2-U6 | Mostly: all windows and insets; corner radius has no public API; no iOS 26 runtime |
| SIM-13 | B1-U10, B2-U10, L1-U4 | Yes, answered (the haptics value itself needs devices) |
| SIM-14 | G-40; G-30, D-25 (Simulator part) | G-40 partly: no free place outside Home's slots (non-control slots not scored); G-30 and D-25 could not test |

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
  Xcode (*Not verified*, below). The run sheet's (b) then asked an
  agent to open the project, which AGENTS.md forbids; it is the owner's
  step since #127 (*Overtaken since the run*).

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
- **What it means.** Settled, as the design research expected: family screens gain
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
  profiles without a custom style, which Brickson's own components
  would have to justify;
  and its words would not follow the person's text size.

### SIM-4. Brickson's edit sheets against Apple's sheet guidance (D-22)

- **Done.** Read the Human Interface Guidelines' Sheets page
  (developer.apple.com, `.md` form; its change log: "March 24, 2026:
  Updated guidance for button placement"). Ran Brickson on the iPhone
  with fresh test storage (the starter library), opened Settings >
  Family Setup > Phrases and Categories > Basics > Edit Phrase >
  Delete Phrase, and took a screenshot and the tree of each screen.
  Searched `Brickson/` for `sheet(`, `fullScreenCover(`,
  `confirmationDialog(` and `alert(`.
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
  backup's share sheet and file picker are the system's. The other
  full-screen cover is guided setup's. There is no `confirmationDialog`
  or `alert` in `Brickson/`.
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
  available one, so a "real control that is not available" (the
  accessibility research's
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
  `accessibilityReduceMotion = true` with Reduce Motion on, in a
  separate launch after the recordings. (In the
  Simulator the speech stalls without finishing, SIM-14, so the
  indicator stayed active through each recording.)
- **Observed.**

  | Effect | Reduce Motion off | Reduce Motion on |
  |---|---|---|
  | Variable colour | changes continuously; about 0.7 brightness cycles a second; width steady (73 to 74 points) | the same |
  | Pulse | changes continuously; about 0.44 cycles a second; width steady (72 to 74) | the same |
  | Breathe | changes continuously; about 0.44 cycles a second; **grows and shrinks, 74 to 88 points wide** | **the same, still growing and shrinking** |

- **Answer.** In the iOS 27.2 Simulator none of the three effects
  stopped or changed with Reduce Motion on. Breathe kept changing size;
  Pulse and Variable colour changed brightness only. All repeat well
  under three times a second.
- **What it means.** By the run sheet's rule Breathe, which still moves,
  cannot be the indicator as it is. Whether a change of brightness
  alone counts as motion for a person who asked for less is a design
  question for Brickson's own components (E-08). Whether a device
  behaves the same is
  DEV-10's D-07 (device) part; until then this is the Simulator's
  answer only.

### SIM-7. Smart Invert on Home (D-14)

- **Done.** iPhone, Brickson with the starter library: a screenshot of
  Home; Smart Invert turned on in the Simulator's Settings >
  Accessibility > Display & Text Size; Brickson opened again and a
  second screenshot taken; the probe's Status station read.
- **Observed.** The probe read `accessibilityInvertColors = true`, so
  apps are told Smart Invert is on. But the two screenshots of Home are
  identical pixel for pixel, and the Settings page itself was still
  drawn light (#F2F2F7) with Smart Invert on.
- **Answer.** Could not test in the Simulator: its screenshots do not
  show Smart Invert (whether the Simulator applies it to the display at
  all could not be told from here).
- **What it means.** Every Home pair under Smart Invert waits for a
  device (DEV-12), measured from the device's own screenshots or a
  photograph. Smart Invert was turned off again afterwards.

### SIM-8. Text under the scroll edge (D-17)

- **Done.** The probe's Styles station does not produce the case: its
  scroll view starts below the station's readout, so its rows never
  pass under the navigation bar. Brickson does: in Settings > Family
  Setup > Phrases and Categories > Basics (the starter library), the
  phrase list scrolls under the bar that holds Back and the title. On
  the iPhone, scrolled so a row sat under the bar, waited three
  seconds, and took a screenshot, in six appearances: light and dark,
  each plain, with Increase Contrast, and with Reduce Transparency.
  Measured the title "Basics" and the Back button's chevron against the
  background around them, taking the worst background pixel beside the
  title.
- **Observed.** The scroll edge effect fades and blurs the row under
  the bar (its words are not meant to be read there). Over it:

  | Appearance | Title, worst / best | Back chevron |
  |---|---|---|
  | Light | 11.32 / 14.21 | 16.82 |
  | Dark | 11.15 / 15.14 | 19.72 |
  | Light, Increase Contrast | 11.30 / 14.38 | 17.61 |
  | Dark, Increase Contrast | 10.60 / 14.78 | 15.53 |
  | Light, Reduce Transparency | 20.82 / 21.00 | 19.03 |
  | Dark, Reduce Transparency | 20.88 / 21.00 | 16.90 |

  With Reduce Transparency the bar is opaque white or black.
- **Answer.** Partly. At rest, the bar's own words stay above 10:1 over
  a scrolled row in every appearance measured. The run sheet also asks
  for the contrast of a row's own words under the effect; they are
  faded there by design and were not measured (*Follow-ups*).
- **What it means.** No fix is needed for the bar over a scrolling
  library (invariant 6 holds for its text). A row's words are readable
  only once scrolled out from under the bar, which is the system's
  behaviour.

### SIM-9. An inactive iPad window (D-20)

- **Done.** iPad Pro 13-inch, Brickson with the starter library: its
  window narrowed by dragging its corner, the Settings app's window
  narrowed and moved to the left, and Settings made active, so
  Brickson showed beside it as the inactive window (the status bar
  named Settings). The colours in Brickson's part of the screen were
  counted, then Brickson made active (by tapping its message words,
  which press nothing) and counted again.
- **Observed.** Inactive and active, Brickson drew its asset colours:
  phrase tiles #0A60D6, Yes, No, Phrases, Type, the categories
  and Settings #5A6474, Emergency #C8161E, Get Attention #B45309, each
  with white words (5.74, 5.98, 5.85 and 5.02:1), and black words on
  white for the message. Inactive, some tile pixels were also drawn one
  to four levels darker (#0A60D5 to #0A5ED2, 5.76 to 5.92:1 with white),
  which were gone once Brickson was active; the cause was not
  established (the Settings window's shadow is one guess). Nothing was
  drawn lighter or with less contrast. The probe's Styles station
  (system styles, with `appearsActive` shown) was not run inactive:
  arranging the windows by dragging was slow, and the time went to
  Brickson.
- **Answer.** An inactive window did not lower the contrast of Home's
  solid fills or their words on iPadOS 27.2 in the Simulator.
- **What it means.** Home's safety controls keep invariant 6 in an
  inactive window. Whether system glass and system buttons (used on
  the family screens) change when inactive is not answered
  (*Not verified*).

### SIM-10. Apple's own components in every appearance (D-21, D-02, A-33 Simulator part: A4-U17, L1-U22)

- **Done.** Measured every on-screen control's words against its fill
  (or the page) and its fill against the page around it, from a
  screenshot and the accessibility tree, with `PaletteTests`' formula:
  - the probe's Styles station on the iPhone in light and dark, each
    plain, with Increase Contrast, with Reduce Transparency and with
    Show Borders (the glass rows sit below the iPhone's screen, so the
    glass buttons were measured on the iPad, in light and dark, at
    Liquid Glass opacity 0 and 1);
  - the pressed look of `.borderedProminent`, a touch held down while
    the screenshot was taken, in light and dark;
  - Brickson's Home in light and dark with and without Increase
    Contrast, and Brickson's family screens (Phrases and Categories in
    all eight appearances; the Delete Phrase question in light and
    dark, with and without Increase Contrast), counting only the
    cover's own controls (the tree also lists Home's, hidden under the
    cover).
  - The Simulator offers neither Clear nor Tinted Liquid Glass ("This
    device does not offer the clear Liquid Glass style"); iOS 27.2's
    setting here is an opacity, so its two ends were used instead.
- **Observed, Apple's components (the probe, Apple's default tint).**
  - `.borderedProminent`: white words on the system blue are **3.52:1
    in light (#0088FF), 3.23:1 in dark (#0091FF) and 2.15:1 in dark
    with Increase Contrast (#5CB8FF)**; with Increase Contrast in light
    they pass. `.glassProminent` (iPad, light and dark only): 3.57:1
    and 3.23:1. **Pressed**, they fall
    to 2.59:1 in light (#40A6FF) and 2.05:1 in dark (#33A7FF, words
    #CCE9FF); the pressed fill's edge is 2.59:1 against white.
  - `.bordered` (and Automatic under Show Borders): blue words on the
    grey fill 2.90:1 in light (3.44 with Increase Contrast); the fill
    stands 1.21:1 from a white page and 1.39 to 1.60:1 from black.
  - Plain blue words (Automatic, Borderless): 3.52:1 on white.
  - `.glass`: words 16 to 21:1; in dark its shape stands 1.27 to 1.29:1
    from the page; in light it shows no fill against white. Opacity 0
    and 1 gave the same numbers over the plain page (glass over other
    content was not measured).
  - Dimmed buttons of every style measure 1.47 to 4.45:1 (WCAG exempts
    controls that are not available; listed in the raw results).
- **Observed, Brickson.** Home and the family screens keep their
  tokens in every appearance measured: words 5.02 to 5.98:1 on the
  fills, fill edges 3.51 to 4.18:1 on black and 5.02 to 5.98:1 on white,
  except where `Color.accentColor` fills a control: **with Increase
  Contrast in dark the phrase tiles, the selected category and Back to
  Talking are drawn #1A7BFF and their white words are 3.95:1** (in
  light with Increase Contrast, #084DAB and 7.89:1), although the asset
  holds #0A60D6 in all four appearances. The system Back button's
  chevron is 15.5 to 19:1; its glass circle stands 1.14 to 1.29:1 from
  the dark page.
- **Answer.** Apple's prominent and bordered buttons with the default
  tint, and their pressed looks, do not keep 4.5:1 words or 3:1 edges;
  `.glass` keeps its words but not a 3:1 edge in dark. Brickson's own
  fills hold, except the accent under Increase Contrast in dark, which
  was an invariant 6 failure in the app as built that day (fixed since
  by pull request #116, *Overtaken since the run*).
- **What it means.** None of the failing Apple styles can carry
  Brickson's words with the system tint; Brickson's solid fills and
  its named colours are right to replace them. Drawing every fill from
  its colour set by name, as #116 now does, is what keeps them.
  Whether a system Back button's 1.3:1 glass circle counts as a control
  edge under invariant 6, when its chevron is 15:1, is a question for
  the owner (*Follow-ups*).

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
- **Brickson's Home, measured after review.** Home sets
  `accessibilitySortPriority` on its regions and on controls inside them
  (`HomeView`, `HomeRegion`), so the probe's result was checked on Home
  itself: iPhone, starter library, a temporary UI test (never
  committed) listing Home's buttons from XCTest's tree, and a walk with
  VoiceOver's test service (`voiceOverService`). The tree lists Yes, No, Emergency, Get Attention, Again,
  Phrases, Type, the categories, Settings, then the tiles, which is
  Home's sort order, not the order its regions are declared in or sit
  on screen; the test service's walk took the same order, with the
  message's words between Again and Phrases. Full Keyboard Access on Home could not be
  measured: after the iPhone simulator had been restarted, Tab presses
  sent through AXe no longer moved focus on Home or on the probe, where
  they had worked before (a tool or Simulator problem, not Brickson's).
- **Answer.** Same elements, with three differences on the probe, all
  seen through VoiceOver's test service in the Simulator: a button
  hidden with `accessibilityHidden(true)` is in both trees but the
  walk skipped it (SIM-5); with the probe's two side-by-side regions,
  `accessibilitySortPriority` changed the walk's order but neither the
  trees' order nor Full Keyboard Access's; and on iPad the walk reached
  the system's window handle. On Brickson's Home, though, the tree and
  the walk both follow the sort priority; what makes Home differ from
  the probe was not established. How VoiceOver itself moves on a device
  is DEV-10's to say.
- **What it means.** For Home as it is, the order
  `HomeAccessibilityOrderTests` reads is the order the Simulator's
  VoiceOver test service took; a device check (DEV-10) still has to
  show that VoiceOver on a device moves the same way. Whether Full Keyboard Access follows it on Home is
  unmeasured: if it behaves as it did on the probe, it would ignore the
  sort priority, and Phrases and Type could come before Yes and No; DEV-9
  checks it on a device. A new screen that relies on sort priority needs
  its own check, since the probe shows the tree does not always follow
  it. Brickson hides one live control with `accessibilityHidden`: a
  voice row in Voice Settings once its voice is gone, which is also
  see-through, disabled and not hit-testable; a UI test still finds it
  there, and the Simulator's VoiceOver walk would not (SIM-5). Two more are invisible copies used
  only to size a layout (`FamilySetupView`, `VoiceSettingsView`). Home's empty Stop well is a
  hidden `Color.clear`, not a control, and the trees do not list it.
  If Home's sort priorities change, the tree's order and the walk's
  need comparing again before `HomeAccessibilityOrderTests` can stand
  for both. Switch Control's scan is not in
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
  | iPhone Duo, closed (outer screen) | 466 by 678 | 0 / 34, **trailing 84** | not compared (the Duo's other poses were not measured) |
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
- **What it means.** Four window sizes that five simulators give were
  not among `HomeLayoutEngineTests.windows` that day (its width sweep,
  with no safe areas, covered their widths but not these windows with
  their insets): iPhone Air, iPad Air 13-inch, the 820 by 1180 iPads
  and the new iPad mini. Pull request #120 has since added them. The
  corner radius and iOS 26's insets move to a
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
- **What it means.** The accessibility research's notes on these two
  APIs should read as above; docs/ACCESSIBILITY.md's row for
  `pointerStyle(_:)` says the same since #127.

**The confirmation dialog (L1-U4).**

- **Done.** A temporary button (never committed) at the top of the
  probe's list opened a system `confirmationDialog` with a title, a
  destructive "Delete" and a plain "Keep"; its frames were read from
  the accessibility tree right after a tap at the button's centre.
- **Observed.** On both devices the dialog opens as a popover beside
  the button, with its title, Delete first and Keep below, and no
  Cancel: a tap anywhere else dismisses it (the tree shows a
  full-screen "dismiss popup" region). On the iPhone the button
  (16, 168, 370 by 52) was tapped at its centre (201, 194), and Delete
  opened at (147, 164, 208 by 48): **the spot just tapped is inside
  Delete** (by centre 50 points away, Keep 71). On the iPad (tap at
  516, 164) Delete is again the nearest item, by centre (238 against
  243 points) and by edge (110 against 113).
- **Answer.** Yes: in iOS 27.2 a system confirmation dialog puts its
  first item, here the destructive one, nearest the spot just
  activated, and on the iPhone directly under it.
- **What it means.** A repeated activation at the same spot (Dwell,
  Snap to Item, a switch's auto-select) would meet the destructive item
  next. Brickson must never use a system confirmation dialog on a dwell
  path; it uses none today (no `confirmationDialog` or `alert` in
  `Brickson/`, SIM-4), and its delete questions are screens of their
  own (docs/DECISIONS.md, "Editing the library").

### SIM-14. Analysis on the Mac (G-40; G-30 and D-25 Simulator part)

**G-40, a copy of the message for a listener.**

- **Done.** A temporary unit test (never committed) built Home's layout
  with the layout engine for each of the twelve windows in
  `HomeLayoutEngineTests.windows` (four phones, the 13-inch, 11-inch and
  mini iPads in both orientations, and the zoomed ones), for the touch,
  head tracking and Eye Tracking profiles, in both modes (phrases only;
  phrases and typing), at the default text size. It searched each
  window's safe area, in 4-point steps, for the largest rectangles that
  touch no slot's frame (every slot counted as taken: the message, the
  status line, Stop's well and the whole phrase grid, its empty cells
  included, as well as every control), keeping any of at least
  120 by 24 points. For each such place, and for the message slot
  itself, it asked the chain engine (`ChainEngine.nearest`, by centre and
  by edge, ties counted) which controls a look anywhere in it meets
  first. Nothing was added to Home.
- **Observed.** No window, profile or mode has a free place of 120 by
  24 points or more outside the layout's slots: the layout gives the
  room that is not a control to its slots. Places inside slots that
  are not controls (an empty grid cell where a category has fewer
  phrases, Stop's well while no alarm sounds, the status line) were
  **not scored**. The message slot's nearest controls are Yes,
  No and Emergency in phrases-only mode, and Yes, No, Phrases and Type
  (with Emergency on iPads) with typing; on the 13-inch iPad in
  landscape, phrases only, also Again and Settings.
- **Answer.** Outside the slots, no place exists for a listener copy
  without moving a target; inside the message slot a speaking control
  (Yes or No) is a nearest neighbour of the text in every window. The
  non-control slots remain to be scored.
- **What it means.** Brickson's own components (H-02) start from this:
  the candidates
  left are the non-control slots, which this run did not score, or room
  taken from another region (a layout change that moves targets, the
  owner's decision).

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

## What waits for a real device

- **A-1 first**, and all of DEV-1 to DEV-13: Snap to Item, Dwell, Eye
  Tracking, Head Tracking, Switch Control and Voice Control do not
  exist in the Simulator, and how any of them feels is the owner's
  judgement on a device.
- From this group: Assistive Access, with the probe and with Brickson
  (SIM-1, to DEV-12); Smart Invert on Home (SIM-7, DEV-12); the speaking
  indicator under Reduce Motion (SIM-6, DEV-10); word reports with the
  default voice and a Personal Voice (SIM-14, DEV-10); the haptics
  capability on each iPad (SIM-13, DEV-12); the corner radius and iOS
  26's insets (SIM-12, HW-6 or DEV-12).

## Commits

On `claude/experiments-simulator`, `dc83b2a` to the last commit of
pull request #115: this record (written step by step as the run went),
the "Found, 2026-11-15" lines in docs/EXPERIMENTS.md, docs/HANDOFF.md's
experiments line, and the stills; then a merge of `main` on 2026-11-25
that dropped the two *Known gaps* items main had made untrue
(*Overtaken since the run*). Nothing in `Brickson/`, `BricksonProbe/` or
the tests changed: every temporary test, probe line and scratch file was
removed before committing.

## Verified

- Every result above, on the Mac with Xcode 27.2, iOS 27.2 Simulator,
  iPhone 17 and iPad Pro 13-inch (M5) in portrait, and for SIM-12 every
  installed iPhone and iPad simulator; text size, appearance and
  settings as each step says.
- `python3 scripts/test-docs.py`, `test-hooks.py`, `test-privacy.py`,
  `test-forbidden-code.py`, `test-runner.py`, `test-agent-bridge.py`,
  `test-site.py` and `test-select-xcode.py` pass on the Mac, and
  `privacy-check.py --outgoing` passes with the private list read.
- The Swift unit and UI tests were not run for this pull request (no
  Swift changed); GitHub CI runs them on it.
- No software keyboard showed in any step: nothing was typed. The only
  key presses were Full Keyboard Access's Tab, sent as hardware keys.

## Not verified

- Anything a device would show (*What waits for a real device*).
- Accessibility Inspector itself: AXe stood in for it (*The tools*).
- The probe's "Assistive Access" preview (SIM-1 b).
- System styles in an inactive window (SIM-9), glass over content
  other than a plain page (SIM-10), and Clear or Tinted Liquid Glass,
  which the Simulator does not offer.
- iOS 26: no runtime installed.
- Only the iPhone was used for SIM-6, SIM-7, SIM-8, SIM-11's Groups
  station and SIM-14's speech; only the iPad for SIM-9.

## Follow-ups

- **The rows' own words under the scroll edge** (SIM-8) were not
  measured; a run that samples them, if the owner wants that number.
  *(a thread)*
- **The run sheet's step 2 makes the worktree from the owner's
  checkout** (`git fetch` there). This session used a separate clone
  instead, so the owner's checkout was not touched at all; the run sheet
  could say either works. *(owner)*
- **A system Back button's glass circle** stands 1.14 to 1.29:1 from a
  dark page while its chevron is 15 to 19:1 (SIM-10): whether
  invariant 6's 3:1 for control edges applies to it is the owner's
  question.
- **Full Keyboard Access's order on Home** (SIM-11): unmeasured here;
  if it ignores Home's sort priority as it did on the probe, Phrases and
  Type would come before Yes and No. DEV-9 on a device, or a simulator
  run whose key presses reach the app. *(owner's device session, or a
  thread)*
- The automation trees list controls hidden with
  `accessibilityHidden(true)` and, under Settings' cover, Home's
  controls too: a UI test that checks a control is unreachable must not
  rely on either (SIM-5, SIM-10).
- The iPad Pro 13-inch simulator was left with Brickson's and the
  Settings app's windows narrowed (SIM-9); dragging them back by hand
  restores them.
