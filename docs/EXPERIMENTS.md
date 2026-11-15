# Experiments: the run sheet

The research of 14 November 2026 read everything public about how
Apple's accessibility features, Apple's design language and other
communication apps work. It left questions that no document answers:
what Snap to Item really does with a dimmed button, how far it jumps,
whether a resting look presses twice, how Switch Control groups a SwiftUI
screen, and many more. This file turns those questions into experiments,
in the order to run them, and says what each possible answer means for
Brickson's design.

Everything here uses Apple's public features and public API only, the
way the owner chose on 2026-11-14 ("the safe way"): no taking Apple's
software apart, no private API. Nothing an experiment builds ships in
Brickson. The test app the device experiments use, **Brickson Probe**,
is a separate app in this repository (*The probe app*, below;
docs/DECISIONS.md, "A probe app for the experiments, kept out of
Brickson").

The questions come from three studies kept outside this repository: the
accessibility study (stage 1: questions A-1 to A-45 and B-1 to B-4, and
its detailed experiments numbered like A1-U3), the design-language study
(stage 2: D-01 to D-26) and the communication-app field study (stage 3:
23 questions between G-01 and G-41, numbered by the study's sections, so
the numbers have gaps). This file carries each question's meaning, so it can be
run without them. Every ID keeps its own name; *Every ID, and where it
runs*, at the end, finds any of them.

## How to read this

**The groups.** Every experiment is in one of five groups, cheapest and
most useful first inside each:

1. **Simulator only** (steps SIM-1 to SIM-14): a Mac session runs them,
   with no person and no device.
2. **On a device, with a person** (DEV-0 to DEV-13): the owner's hands
   and eyes on a real iPhone or iPad, mostly with the probe app. A-1
   comes first.
3. **Needs borrowed hardware** (HW-1 to HW-6): a device or accessory the
   owner does not have.
4. **Ask Apple first** (ASK-1 to ASK-7): questions only Apple can answer,
   drafted ready to send.
5. **Needs the owner's decision before it runs** (OWN-1 to OWN-4).

**Each step says:** the IDs it answers; what it asks; why it matters
(one line); how to run it, with exact settings and taps; what to
record; and what each possible result means for design. "What it
means" never decides a design: it says which choice the result
supports. Changing a rule in AGENTS.md is the owner's decision alone,
recorded in docs/DECISIONS.md first.

**IDs.** A hyphen marks a study question: A-1, B-4, D-01, G-30. A study
experiment that was merged into a question keeps its own name too
(A1-U3 is part of A-2). IDs with no hyphen are procedures already in
docs/DEVICE-CHECKS.md (F1, I5, S2, W1, G3 and so on); this file writes
them as "DEVICE-CHECKS F1" where they could be mistaken for a study ID.
E-01 to E-11 and H-01 to H-10 are inputs for building Brickson's own
components later (stage 5), not experiments; they are listed in the
index only so they can be found.

**Results.** Write each result the way docs/DEVICE-CHECKS.md, *Write
down each result*, says: PASS, FAIL or UNVERIFIED, with the time, the
device's model and iOS version, and every setting as found. Keep its
privacy rules (*Keep the repository's rules*): neutral test words only,
Do Not Disturb on before recording, a device named by its model, and
raw recordings in `private/device-checks/`, which git ignores. A thread
then writes the results into one `docs/log/` record per session and
updates this file's step with what was found.

## Before every session

- **The probe is not for communicating.** It has no Emergency, no Get
  Attention and no safety bar. Never hand it to someone who needs to
  speak; it exists only to measure.
- **Set up a way out first**: the Accessibility Shortcut, as
  docs/DEVICE-CHECKS.md, *Set up a way out first*, says, before turning
  on any input method.
- **Turn off Accessibility Inspector's point-to-inspect mode** before
  judging whether a control works. A published report says that on iOS
  27 the app receives no touches while it is on (study item B3-U11).
- **Never view the device in Xcode's Device Hub** during a session that
  uses the camera or the microphone: Eye Tracking, Head Tracking and
  Voice Control stop working (docs/DEVICE-CHECKS.md, *Mount the
  device*).
- **If the probe stops speaking,** share its log first: the log lives
  only in memory, and closing the probe empties it. Then close the probe
  from the App Switcher, open it again, and write down the time. Unlike
  Brickson, it does not recover its speech after a call, an alarm or a
  reset of the system's audio (docs/DECISIONS.md, "A probe app for the
  experiments, kept out of Brickson").
- **Film the screen.** Start Control Center's Screen Recording; if the
  pointer does not show in the recording, film the screen with a second
  phone. The probe's log gives every activation's time, so the film and
  the log can be matched. **Stop every recording, the screen's and the
  second phone's, before anything speaks in a Personal Voice** (DEV-10,
  step 6): Screen Recording keeps the app's sound, and a second phone
  hears the room. Start them again afterwards.

## The probe app

Brickson Probe is a small app with thirteen test screens ("stations").
Each holds standard SwiftUI controls, spaced well apart, and writes every
activation and change to a log with its time on a steady clock. Its
first screen lists the stations in run order, the log, and every option,
so no option control sits on a station's own screen.

| Station | What it holds | Answers |
|---|---|---|
| Snap | An enabled button (Counter), a dimmed button (Dimmed), plain words, words marked interactive, a hidden button, an empty place, a button with two custom actions, a toggle styled as a button, a segmented picker (Phrases or Type), a button with a round accessibility shape, a button that says it does not respond, and words with only the button trait | A-1, A-1a, A-3, A-7, A-9, A-11, A-21, A-30, D-03, D-04 |
| Rings | One outlined button, exactly 44, 88 or 120 points square (an option; the log records the size it was laid out at), in the middle of rings drawn 25, 50, 100, 150, 200 and 300 points from its centre | A-2, A-3, B-4, G-21 |
| Landing | Wide (160 by 100 points), whose activation point is moved to the centre of its neighbour Landing (100 points square), both outlined at their exact size; three of Apple's bordered buttons with no hover effect, Apple's Highlight and Apple's Lift | A-8, A-28, D-18 |
| Changes | After a five-second countdown, at once: a button becomes available, one appears, one changes its words, one moves to an empty place, one disappears | A-6, A-42, A-44, G-01 |
| Groups | Two regions of three buttons; options contain each region or not, and put the right region first | A-10, A-45 |
| Look | Twelve tiles; options set same or varied sizes, rounded or capsule ends, Apple's hover effects, and a moving dot beside the grid | D-10, D-11, D-18, D-19, G-21 |
| Speech | Speak a sentence, the same in three parts, the same with SSML pauses; say a Voice Control command and a Siri test aloud; post an announcement in 3 seconds; a Counter; Stop speaking, apart. Options choose the voice, a trait on Speak sentence, and pausing VoiceOver or Switch Control while it speaks | A-16, A-17, A-18, A-31, A-40, D-07, D-25, G-30, G-32 |
| Screen | A running clock, Low Power Mode, heat, Shake to Undo and the keep-awake setting; every change and every time the app leaves the screen is logged | A-22, A-23, A-32, A-39, G-25, G-26 |
| Status | Every public value an app can read about the accessibility features in use, refreshed each second; each change is logged | A-27 |
| Typing | A text field and, below it, exactly what it received: a space shows as ·, Return as ⏎ | A-34 (keyboard behaviour) |
| Busy | A button that holds the app busy for three seconds, and a Counter far from it | A-43 |
| Ruler | A grid every 20 points, numbered every 100, from the window's top-left corner, under the bar too, with no controls | A-12, A-29, A-36, B-4 |
| Styles | Apple's button styles and sizes, each enabled and dimmed; glass with border shapes; toggles and segmented pickers at each size; glass panels; rows to scroll under the bar | A-1a, A-33, D-01, D-02, D-13, D-16, D-17, D-20, D-21, D-24 |

The probe also declares Assistive Access's own scene (D-13), which
Brickson never does. The log is on the first screen: **Log**, then
**Share** sends it as text (to Notes, Mail or AirDrop, as the person
chooses), and **Clear the log** empties it. Nothing is saved when the app
closes.

**Installing it on a device.** Device steps need the owner's Apple
Developer Team ID first (an owner step already on the list, docs/DECISIONS.md, "Waiting on the owner"). Then:

- **Agent (Mac session):** the owner connects the device, unlocks it,
  and writes "go" in the thread (docs/DEVICE-CHECKS.md, *For an agent
  run*). The agent builds the `BricksonProbe` scheme in its own worktree
  (*What the Mac session does next*, below) for the device with
  `-allowProvisioningUpdates` and the Team ID given on the command line
  (never committed), then installs it with `xcrun devicectl device
  install app`. Brickson stays installed beside it.
- **Owner, with Xcode, if no agent is running:**
  1. In Terminal: `cd ~/code/brickson && git pull && xcodegen generate`.
     Success: the last line says the project was created.
  2. `open Brickson.xcodeproj`.
  3. In Xcode's toolbar, open the scheme menu (left of the device name)
     and choose **BricksonProbe**; open the device menu beside it and
     choose the connected iPhone or iPad.
  4. Product > Run (Command-R). Success: an app named **Brickson Probe**
     opens on the device, on a list that starts with "Snap".

---

## Group 1. Simulator only

A Mac session runs these, in this order, with no person. The Simulator
has no Eye Tracking, Switch Control or Voice Control, and its sound is
unreliable (AGENTS.md, *Workflow rules*), so these steps measure only
what is drawn and what the accessibility tree says. *What the Mac
session does next*, below, has the commands.

### SIM-1. Inside Assistive Access — D-13, A4-U13

- **Asks.** How does Apple dress standard buttons, toggles and pickers
  inside an Assistive Access scene? Does the Simulator offer Assistive
  Access at all, on iOS 26 and 27?
- **Why.** It is the closest thing to Apple designing large buttons for
  people who need them.
- **How.** (a) In the Simulator for an iPad and an iPhone: Settings >
  Accessibility > Assistive Access. Note whether it is there. If it is,
  set it up with Brickson Probe as an app, start it, open the probe, and
  take screenshots of its list, the Snap station and the Styles station,
  in light and dark. (b) If the Simulator does not offer it, render the
  preview named "Assistive Access" in `BricksonProbe/App/BricksonProbeApp.swift`
  (Xcode's canvas, or the Xcode MCP's preview rendering) and take the same
  pictures. (c) Do the same for Brickson itself, which uses the
  full-screen key instead: note the window size and where the system's
  Back button sits.
- **Record.** Whether each runtime offers Assistive Access; the
  screenshots; for each kind of control, its size, shape, colour and
  label as drawn.
- **What it means.** Apple's dressing is a reference for the state
  style stage 5 builds (E-05), not a design to copy. If the Simulator
  cannot run Assistive Access, DEV-12 does (c) on a device. Brickson
  keeps its full-screen key whatever this shows (docs/DECISIONS.md,
  "Accessibility API coverage").
- **Found, 2026-11-15.** The iOS 27.2 Simulator offers no Assistive
  Access (nor Guided Access, Switch Control, Voice Control, Touch, Eye
  or Head Tracking) on iPhone or iPad; no iOS 26 runtime was installed.
  Part (b) needs the project open in Xcode, which AGENTS.md keeps from
  agents: not done. Parts (a) and (c) move to DEV-12.
  ([record](log/2026-11-15-experiments-simulator.md))

### SIM-2. Control sizes — D-01

- **Asks.** Does `.controlSize(.extraLarge)` draw larger than `.large`
  on iOS and iPadOS 26 and 27, or the same, as Apple's API page says
  ("Resolves to `ControlSize.large` on platforms other than visionOS")?
  How tall is each size?
- **Why.** If no system size reaches Brickson's floors, Home keeps its
  own sizes from the layout engine.
- **How.** Styles station, section "Control sizes", on an iPad and an
  iPhone simulator, at the default text size and at AX5. Read each
  button's frame in Accessibility Inspector, or measure a screenshot
  taken at scale 1.
- **Record.** Width and height of each size, per device and text size.
- **What it means.** Equal: settled, as stage 2 expected; family
  screens may use `.extraLarge` with no gain. Larger: record the sizes
  for stage 5, and check whether any reaches a profile's floor.
- **Found, 2026-11-15.** `.extraLarge` is exactly as tall as `.large` on
  iPhone and iPad (54 points at the default text size, 96 at AX5; drawn
  fills measured too). At the default text size no system size reaches
  the switch, head or eye floors.
  ([record](log/2026-11-15-experiments-simulator.md))
### SIM-3. Shapes, text sizes and the segmented picker — D-24

- **Asks.** Does `buttonBorderShape` shape the glass button styles? How
  do standard styles grow with Dynamic Type and `controlSize`? How tall
  can a segmented `Picker` be?
- **Why.** Decides whether a joined Phrases and Type control can be a
  system segmented picker at Brickson's sizes.
- **How.** Styles station, sections "Large glass with border shapes"
  and "Toggles and pickers", at every text size from the default to
  AX5, on both simulators. Screenshots and frames.
- **Record.** Whether each glass button takes its shape; each picker's
  height per control size and text size.
- **What it means.** A segmented picker that cannot reach a profile's
  floor cannot be the joined control without a custom style, which
  stage 5 would then have to justify; one that can is a candidate.
- **Found, 2026-11-15.** Glass buttons take every border shape. A
  segmented picker is 31 or 48 points tall and does not grow with
  Dynamic Type (its words stayed small at AX5): it reaches touch's
  44-point floor for Phrases and Type, not 88 or 109.
  ([record](log/2026-11-15-experiments-simulator.md))

### SIM-4. Brickson's edit sheets against Apple's sheet guidance — D-22

- **Asks.** Apple's guidance on sheets changed in March 2026 (button
  placement). Do Brickson's edit sheets still match it?
- **Why.** Family screens should look and behave like Apple's.
- **How.** Run Brickson in the Simulator with the starter library. Open
  each sheet in Settings > Library and take screenshots. Read the Human
  Interface Guidelines' Sheets page on developer.apple.com (the `.md`
  form, AGENTS.md, *Apple's current frameworks first*) and compare.
- **Record.** Each difference, with the page's words.
- **What it means.** A difference becomes a roadmap item for the family
  screens. Nothing changes in this stage.
- **Found, 2026-11-15.** Brickson's library edits use no sheets: they
  are screens pushed inside Settings' full-screen cover, with standard
  Back; the only sheet is the privacy policy's web page, and there is no
  confirmation dialog or alert. No roadmap item; Back to Talking sits at
  the trailing edge, where a sheet would put Done.
  ([record](log/2026-11-15-experiments-simulator.md))
### SIM-5. What the system says about each element — A-1a, A3-U8 (Simulator part)

- **Asks.** What does the accessibility tree report for a dimmed
  SwiftUI Button: the button trait and "not enabled", or something
  else? And for the hidden, non-responding, trait-only and interactive
  words, the toggle and the picker?
- **Why.** Every input method decides from this report; it explains
  A-1, A-9 and A-11 before anyone runs them on a device.
- **How.** Snap station and the dimmed buttons in the Styles station.
  In Accessibility Inspector, choose the Simulator, then inspect each
  element: note its label, value, traits and whether it appears at all.
- **Record.** A table: element, what the Inspector shows.
- **What it means.** "Not enabled" reported: the system can tell a
  dimmed button from an available one, so a "real control that is not
  available" (the third answer in stage 1's three cases) is something
  each input method can treat differently; the device steps say how.
  Nothing reported: assistive technologies see a dimmed button as a
  normal one, and A-1's result must be read in that light.
- **Found, 2026-11-15.** A dimmed Button is reported as a button that is
  not enabled by AXe, the UI test's tree and VoiceOver ("dimmed").
  `accessibilityHidden(true)` hides a button from VoiceOver but not from
  either automation tree; the responds-to-interaction modifiers show no
  difference in any tool.
  ([record](log/2026-11-15-experiments-simulator.md))

### SIM-6. The speaking indicator and Reduce Motion — D-07

- **Asks.** How do `speaker.wave.3`'s variable colour, Pulse and Breathe
  effects behave with Reduce Motion on, and how fast do they repeat?
- **Why.** The speaking indicator must not move for a person who asked
  for less motion, and must not flicker at a rate Apple warns about.
- **How.** Speech station. For each indicator effect (an option on the
  list), with Reduce Motion off and then on: tap Speak sentence and
  record the screen (`xcrun simctl io <device> recordVideo`). Count the
  repeats per second from the recording.
- **Record.** Per effect and setting: moves or still; repeats per
  second.
- **What it means.** An effect that still moves under Reduce Motion, or
  repeats close to the rate Apple warns about, cannot be the indicator
  as it is (E-08); one that stops is a candidate.
- **Found, 2026-11-15.** with Reduce Motion on, Variable colour, Pulse
  and Breathe all kept animating in the Simulator: Breathe still
  changing size (74 to 88 points wide), the other two changing
  brightness only; all under three repeats a second. Breathe cannot be
  the indicator as it is; DEV-10 checks a device.
  ([record](log/2026-11-15-experiments-simulator.md))
### SIM-7. Smart Invert on Home — D-14

- **Asks.** What does a person using Smart Invert see on Brickson's
  Home?
- **Why.** Every pair must still pass invariant 6 for that person.
- **How.** Brickson in the Simulator with the starter library; turn on
  Smart Invert (the Simulator's Settings > Accessibility > Display & Text
  Size, or Accessibility Inspector's settings). Screenshots of Home, in
  light and dark; sample each text and edge colour pair and compute its
  ratio.
- **Record.** Each pair and its ratio.
- **What it means.** A pair under 4.5:1 for text or 3:1 for an edge is
  an invariant 6 failure to fix, with the pair pinned in `PaletteTests`.
- **Found, 2026-11-15.** Could not test: the probe is told Smart Invert
  is on, but Simulator screenshots do not show it. Moves to DEV-12.
  ([record](log/2026-11-15-experiments-simulator.md))

### SIM-8. Text under the scroll edge — D-17

- **Asks.** When a list scrolls under the navigation bar, what contrast
  does the scroll edge effect leave at rest?
- **Why.** A family-grown library scrolls, and its rows must stay
  readable.
- **How.** Styles station: scroll until rows sit under the bar, stop,
  wait two seconds, screenshot. Repeat in light, dark, Increase
  Contrast and Reduce Transparency. Sample the text and its background
  under the effect. Then do the same in Brickson's Library with a list
  long enough to scroll (made in the Simulator only).
- **Record.** Each sample and its ratio.
- **What it means.** Below 4.5:1 at rest: every scrolling surface under
  a glass bar needs a fix before it ships (invariant 6).
- **Found, 2026-11-15.** The probe's Styles rows never pass under its
  bar; Brickson's library list does. Over a scrolled row the bar's title
  stays at least 10.6:1 and its Back chevron at least 15.5:1 in light,
  dark, Increase Contrast and Reduce Transparency.
  ([record](log/2026-11-15-experiments-simulator.md))

### SIM-9. An inactive iPad window — D-20

- **Asks.** On iPadOS 27, with Brickson beside another app and not the
  active window, what happens to the contrast of its solid fills, its
  system glass and its text? Does a custom style that ignores
  `appearsActive` stay at full contrast?
- **Why.** The safety controls must pass invariant 6 even in a window
  that is not active.
- **How.** iPad simulator, Windowed Apps on. Put Brickson beside
  Settings and make Settings active; screenshot Home. Do the same with
  the probe's Styles station, whose first line shows `appearsActive`.
- **Record.** Samples of Emergency, Get Attention, a phrase tile and a
  text label, active and inactive, with ratios.
- **What it means.** If an inactive window dims a safety control below
  its ratio, that is an invariant 6 failure in a state Brickson does not
  test today, and needs a pinned pair or a style that keeps its
  contrast.
- **Found, 2026-11-15.** an inactive Brickson window beside Settings
  kept Home's fills and words at their contrast (5.02 to 5.98:1; a few
  tile pixels drawn slightly darker). The probe's system styles were not
  run inactive. ([record](log/2026-11-15-experiments-simulator.md))
### SIM-10. Apple's own components in every appearance — D-21, D-02, A-33 (Simulator part: A4-U17, L1-U22)

- **Asks.** Do standard controls, `Material`, toolbars, sheets and
  alerts keep 4.5:1 text and 3:1 edges under Increase Contrast, Reduce
  Transparency and Show Borders, in light and dark, and at both ends of
  iOS 27's Liquid Glass setting (Clear and Tinted on iOS 26.1 or later)?
  What do the pressed and dimmed looks of `.borderedProminent` measure?
- **Why.** Invariant 6 covers every system component Brickson shows.
- **How.** Styles station and Brickson's family screens (Settings, the
  Library, a delete question), each appearance in turn. A pressed look
  needs the click held while the screenshot is taken; if that cannot be
  captured, mark it UNVERIFIED for DEV-12.
- **Record.** Each component, appearance and pair, with its ratio.
- **What it means.** Any pair below its bar that Brickson shows fails
  invariant 6, and is replaced or fixed and pinned in `PaletteTests`.
- **Found, 2026-11-15.** Apple's `.borderedProminent` and
  `.glassProminent` with the default tint keep under 4.5:1 for their
  white words (3.52 light, 3.23 dark, 2.15 dark with Increase Contrast;
  pressed 2.59 and 2.05), `.bordered` fills stand 1.21 to 1.60:1 from
  the page, and `.glass` stands 1.3:1 in dark. Brickson's fills hold
  except one shipped defect: with Increase Contrast in dark,
  `Color.accentColor` is drawn #1A7BFF and the white words on phrase
  tiles, the selected category and Back to Talking are 3.95:1
  (docs/HANDOFF.md, *Known gaps*). The Simulator offers no Clear or
  Tinted Liquid Glass; opacity 0 and 1 measured the same.
  ([record](log/2026-11-15-experiments-simulator.md))

### SIM-11. The trees each tool sees — A-45 (Simulator part: B3-U8), A2-U13, A3-U17

- **Asks.** Do a UI test, Accessibility Inspector and (where they run)
  Full Keyboard Access and VoiceOver's test service see the same
  elements and groups on one screen?
- **Why.** Brickson's reachability tests read what a UI test sees; this
  says how far they stand for Switch Control's scan.
- **How.** Groups and Snap stations, each with the regions contained
  and not (an option). (a) Accessibility Inspector's hierarchy. (b) A
  temporary UI test, never committed, that prints
  `XCUIApplication(bundleIdentifier:)`'s `debugDescription` for the
  probe. (c) Whether the Simulator offers Full Keyboard Access with the
  Mac's keyboard (Settings > Accessibility > Keyboards); if it does,
  Tab through the Groups station and note the order. (d) Whether
  `XCUIVoiceOverService` runs on the Simulator, and what its
  `currentSpeech()` returns on the Snap station.
- **Record.** The element lists side by side; FKA's order; whether the
  VoiceOver service ran.
- **What it means.** Same tree: the UI tests stand for the scan until a
  device shows otherwise (DEV-7). Different: note each difference;
  reachability claims then need a device check (AGENTS.md, *Workflow
  rules*).
- **Found, 2026-11-15.** AXe and the UI test agree on elements, order
  and frames. Differences: VoiceOver skips an `accessibilityHidden`
  button both trees list; `accessibilitySortPriority` changes
  VoiceOver's order but not the trees' or Full Keyboard Access's (which
  the Simulator offers); on iPad VoiceOver also reaches the window's
  resize handle. `XCUIDevice.voiceOverService` runs in the Simulator.
  ([record](log/2026-11-15-experiments-simulator.md))

### SIM-12. Window sizes and safe areas — B2-U4, B2-U6

- **Asks.** What window size, safe areas and corner radius does the
  newest iPad mini give an app? How do safe-area insets differ between
  iOS 26 and iOS 27 on the same device?
- **Why.** The layout engine's tested windows must match real ones.
- **How.** The Ruler station on each simulator and runtime that exists,
  screenshot at scale 1; Accessibility Inspector for the window frame.
- **Record.** Per device and runtime: window size and each inset.
- **What it means.** A window the layout engine's tests do not hold is
  added to them; a device with no simulator moves to HW-6.
- **Found, 2026-11-15.** Window sizes and insets for all twelve
  simulators; five are not among the layout engine's tested windows
  (iPhone Air 420 by 912; iPad Air 13-inch 1024 by 1366; the 820 by 1180
  iPads; the new iPad mini 756 by 1158, whose insets are 32 and 20).
  Corner radius has no public API; iOS 26 not installed.
  ([record](log/2026-11-15-experiments-simulator.md))

### SIM-13. Checks that need only the compiler — B1-U10, B2-U10, L1-U4

- **Asks.** Does `pointerStyle(_:)` compile for an iPadOS target, and
  does SwiftUI have an `.adjustable` trait in the current SDK? Do any
  iPads report haptic support (Core Haptics' capability check)? When a
  system confirmation dialog opens over the button that opened it, is
  its first or destructive item now nearest the spot just activated?
- **Why.** Each settles a stage 1 claim without a person.
- **How.** A scratch file in the worktree, never committed, for the two
  compile questions. The haptics answer needs each device, so the
  Simulator only shows that the call compiles; DEV-12 reads it on the
  owner's devices. For the dialog: a scratch view with a
  `confirmationDialog`, its frames read in Accessibility Inspector.
- **Record.** Compiles or not, with the SDK's version; the dialog's
  item frames against the button's.
- **What it means.** The compile answers correct stage 1's notes. If a
  dialog's harmful item lands nearest the spot just activated, Brickson
  must never use a system confirmation dialog on a dwell path (it does
  not today; docs/DECISIONS.md, "Editing the library").
- **Found, 2026-11-15.** `pointerStyle(_:)` does not exist for iOS or
  iPadOS in the iOS 27.2 SDK; SwiftUI has no `.adjustable` trait
  (`accessibilityAdjustableAction` is the way); the haptics check
  compiles. A system confirmation dialog opens as a popover with its
  destructive first item nearest the spot just activated, on the iPhone
  directly under it: never on a dwell path.
  ([record](log/2026-11-15-experiments-simulator.md))

### SIM-14. Analysis on the Mac — G-40, G-30 and D-25 (Simulator part)

- **Asks.** (G-40) On each window class, where could a copy of the
  message for a listener sit on Home without a speaking control as the
  nearest neighbour of its text, and without moving any target? (G-30,
  D-25) With system voices, do the synthesizer's word reports stay
  continuous when a message is spoken as several utterances or as SSML?
- **Why.** The listener copy and word-by-word lighting both depend on
  these, and neither needs a person.
- **How.** (G-40) With the chain engine in the unit tests: score
  candidate positions as plain frames, the way `ChainEngineTests` scores
  Home's own; nothing is added to Home. (G-30, D-25) Speech station:
  Speak sentence, Speak in three parts and Speak with SSML pauses, each
  three times with the default voice; Share the log.
- **Record.** (G-40) Each candidate and its chain score. (G-30) Word
  reports per utterance, longest gap, and the order of reports.
- **What it means.** (G-40) A position with no harmful nearest
  neighbour is a candidate for stage 5 (H-02); none is a finding too.
  (G-30) Continuous reports: a message can be shaped into parts without
  losing word lighting; gaps: shaping and lighting conflict, and DEV-10
  checks it with a Personal Voice.
- **Found, 2026-11-15.** (G-40) on every tested window, profile and mode
  Home has no free place of 120 by 24 points outside its slots, and the
  message slot's nearest controls include Yes and No; places inside
  non-control slots (empty grid cells, Stop's well, the status line)
  were not scored. (G-30, D-25) could not test: the Simulator's
  synthesizer drops word reports and never finishes an utterance.
  ([record](log/2026-11-15-experiments-simulator.md))
---

## Group 2. On a device, with a person

The owner runs these on their own iPhone and iPad. Each session is about
an hour. Run DEV-1 first: its first question, A-1, decides more than any
other. Remember that the owner is not a person living with ALS: a
comfort or speed measured here is a baseline, not evidence about the
people Brickson serves.

### DEV-0. Every session starts here

1. Install the probe (*Installing it on a device*, above).
2. Do docs/DEVICE-CHECKS.md, *Before any check*: what to have, the
   repository's rules, writing down each result, mounting the device,
   the way out, and turning on the input method.
3. Note every setting of the input method **as found**, before changing
   anything, with the iOS version. Where a setting was never changed on
   that device, the value found is the default (A1-U6, A2-U1, A2-U2,
   A2-U14, A3-U5); say which values you know were never changed.
4. Turn on Do Not Disturb and start the recording.
5. Open Brickson Probe and choose **Log**, then **Clear the log**, so the
   session's log starts empty.
6. At the end: Log > Share, and save the text with the recording.

### DEV-1. Snap to Item on every kind of element — A-1 first, then A-3, A-7, A-4, A-21, D-03, D-04, B1-U4

- **Asks.** (A-1) Does Snap to Item stop on a dimmed standard Button, or
  skip it as if it were empty? (A-3) Does a dwell on empty space do
  nothing, or tap the nearest item? (A-7) Does it stop on plain words,
  words marked interactive, a hidden button? (A-4) Does a lingering look
  fire the same button again, and after how long? (A-21) What shape does
  the outline take on a round accessibility shape? (D-03, D-04) Does it
  stop on a toggle styled as a button, and on each segment of a
  segmented picker? (B1-U4) Does it honour "does not respond" and the
  button trait on words?
- **Why.** These decide stage 1's three cases (what to put where nothing
  can be done right now) and the safety arguments Brickson already makes
  for dimmed controls.
- **How.**
  1. iPad, mounted. Settings > Accessibility > Eye Tracking: on,
     calibrate, Snap to Item on, Dwell Control on. In AssistiveTouch >
     Dwell Control, set Fallback Action to Tap. Close Settings.
  2. Probe > Snap. Rest your look on **Dimmed** for five seconds. Note
     what the pointer outlines and whether the log at the top shows an
     activation. Do the same for every other element in the grid, then
     for **Empty place**, then for the empty middle of the screen.
  3. Rest your look on **Counter** and keep it there for 20 seconds.
     Count the log lines it adds. Repeat with Fallback Action set to
     Pause Dwell, and with Snap to Item off.
  4. Turn Dwell Control off (Eye Tracking's settings) and repeat step 2
     for Dimmed, Hidden, Plain words and Interactive words: with no
     dwell, only the outline shows what Snap chose.
  5. Repeat steps 1 to 4 on the iPhone.
- **Record.** For each element: outlined or not; if not, which element
  the pointer went to; any activation in the log. For step 3: the number
  of activations and the seconds between them, per setting.
- **What it means.**
  - **Dimmed is outlined and nothing fires:** a dimmed button is a safe
    place to rest a look. Stage 1's third answer (a real control that is
    not available) holds for gaze, and Brickson's dimmed phrase tiles
    while typing are resting places.
  - **Dimmed is skipped and the pointer jumps to a neighbour:** a dimmed
    button acts as empty space. Every dimmed control's nearest neighbour
    must then be harmless, and the chain engine must score dimmed
    controls as empty. A-9 and A-11 then matter more.
  - **A dwell on empty space does nothing:** rest areas can exist (stage
    1's case 2). **It taps the nearest item:** every empty place is a
    press on its neighbour, and Home's empty places must be judged by
    their nearest control.
  - **Hidden is outlined:** `accessibilityHidden` does not hide a button
    from Snap to Item, and no hidden control may ever sit on Home.
  - **Words are outlined:** printed words count as items, so a label
    beside a control can catch a look; not outlined, words are like empty
    space.
  - **Counter fires again** under a held look: the re-arm time is the
    measure invariant 10's exceptions must meet; record it per setting.
  - **Each segment of the picker is outlined on its own:** a joined
    Phrases and Type control can be a system picker for gaze (with
    SIM-3's sizes); **the picker is one item:** it cannot.

### DEV-2. How far it reaches and where a press lands — A-2, A-8, B3-U3, B3-U7

- **Asks.** (A-2) How far does Snap to Item reach, and does it measure
  to an item's centre or its edge? For overlapping elements, which one
  wins? (A-8) Where does a dwell tap land: at the pointer, the element's
  centre, or its activation point?
- **Why.** Decides which of the chain engine's findings are real
  (docs/DECISIONS.md, "One chain engine for dwell safety").
- **How.**
  1. Eye Tracking and Snap to Item as in DEV-1, Dwell Control off.
  2. Probe > Rings, middle button 44 points (an option on the list).
     The log's line "Centre laid out at 44 by 44 points" confirms the
     button's real size; write down the size it gives if it differs.
     Rest your look on each ring, nearest first, for five seconds each,
     on its right, left, top and bottom. Note the farthest ring where
     the pointer still jumps to the button, and the nearest ring beyond
     it where the pointer does not.
  3. Repeat with the button at 88 and at 120 points. A ring whose points
     lie inside the button (the 25-point ring on the 88-point button;
     the 25- and 50-point rings on the 120) puts the look on the button
     itself, so skip it: it says nothing about reach.
  4. Dwell Control on. Probe > Landing. Dwell on **Wide** five times,
     each at a different place on it; then on **Landing** five times.
  5. Repeat on the iPhone. A ring whose left or right points lie past
     the screen's edge cannot be reached there: write it down as off
     screen, not as a ring the pointer does not jump to.
- **Record.** The farthest ring that still snaps and the nearest ring
  beyond it that does not (or "off screen"), for each button size and
  direction; for step 4, which button the log says fired each time.
- **What it means.**
  - **The farthest ring grows from the 44-point to the 120-point
    button:** Snap measures to the edge (an edge reach moves the
    farthest ring out by about half the size change, 38 points, since
    the rings count from the centre). The chain engine then scores only
    that rule, with its reach taken from the nearest ring that did not
    snap, never the farthest that did: the real reach lies somewhere
    between the two. Where every ring on screen snapped, it keeps the
    unlimited range. It still scores chains of activations, not only
    the first. **It stays the same:** not yet an
    answer. Beyond 50 points the rings are 50 or 100 points apart, so
    a 38-point change can fall between two of them, and a centre rule
    gives the same result; the chain engine keeps scoring both rules at
    three ranges, as it does today, and the question stays with Apple
    (ASK-1).
  - **A dwell on Wide fires Landing:** the press is delivered as a touch
    at the activation point, so an activation point must never sit over
    another control. **Wide fires:** the press is an activation or lands
    under the pointer; an activation point is then free to move. If the
    system keeps an activation point inside its element, Wide fires and
    this step cannot tell the two apart: note that.

### DEV-3. Things that change under a still look — A-6, G-01, A-42, A-44, and the pointer after an activation (A-5 starts here, ends in DEVICE-CHECKS F1)

- **Asks.** (A-6) When a control appears, moves, changes or becomes
  available under a pointer that is already still, does a dwell start,
  continue or restart? (G-01) Does a lingering look fire a button whose
  words just changed? (A-42) How long until Snap to Item uses the new
  positions, with and without the app's layout-change notice? (A-44)
  Can a control the app just removed still be activated?
- **Why.** Every mode switch Brickson's chain engine scores assumes the
  pointer sees the new screen at once; a recents zone (H-01) would
  change words in place.
- **How.**
  1. Eye Tracking, Snap to Item and Dwell Control on.
  2. Probe > Changes. Choose **Start countdown** (bottom left), then rest
     your look on **Becomes available** and hold it there through the
     change and for ten seconds after. Choose **Reset** (bottom right).
  3. Repeat step 2 resting on, in turn: the empty place where **Appears**
     will come; **First words**; the empty place where **Mover** will
     come; **Disappears**.
  4. Turn on the option "Changes: post LayoutChanged" and repeat steps 2
     and 3.
- **Record.** For each slot: whether anything fired, when (the log's
  seconds against "The slots changed"), and what the pointer outlined
  before and after.
- **What it means.** A control that fires by itself when it appears or
  becomes available under a still look means nothing that speaks may
  ever appear under a resting place: placement rules tighten. A changed
  label that fires on a held look means a recents zone must never change
  the words of the slot under the look (H-01). A delay before the new
  positions count is a window the chain engine must model; if the
  layout-change notice shortens it, Brickson should post it after every
  mode switch. A removed control that still fires is a hazard for every
  control a mode switch removes.

### DEV-4. Looking at a whole grid — D-10, D-11, D-18, D-19, A-28 (Eye Tracking part)

- **Asks.** (D-10) Does the pointer wander or lock between neighbours
  more on a grid of same-size tiles than on a varied one? (D-11) Does
  motion elsewhere pull the pointer away? (D-18, A-28) Does the Eye
  Tracking pointer show Apple's hover effects? (D-19) Does a capsule
  tile hold a look better than a rounded one?
- **Why.** Shape, sameness and motion on Home are design choices that
  only eyes can judge.
- **How.**
  1. Eye Tracking, Snap to Item and Dwell Control on.
  2. Probe > Look, with the options: same sizes, rounded, no hover
     effect, no motion. Dwell on each tile in turn, One to Twelve, then
     back. Note misses (a tile that fired that you were not looking at).
  3. Repeat with varied sizes; with capsule ends; with motion beside the
     grid; with Highlight, then Lift.
  4. Probe > Landing. Rest your look on **Highlight** and **Lift**, then
     on **No hover**: does either change its look while the pointer
     rests there?
- **Record.** Misses per run; how settled the pointer felt (steady,
  drifts, jumps), in your words; whether hover effects showed.
- **What it means.** More misses on the same-size grid: Apple's warning
  about repeating patterns applies on iPad, and Home's grid needs a cue
  that breaks the pattern without moving anything. Motion that pulls the
  pointer: Home stays still. **Hover effects show under the gaze
  pointer:** Brickson can show where a dwell will land with Apple's own
  effect and no gaze code (D-18); **they do not:** that idea is closed.
  Capsule against rounded: a judgement for stage 6, with this as
  evidence.

### DEV-5. Corners, edges and losing the face — A-12, A-36 (probe part), A-29, A-41, A1-U8, L1-U16, G-21, A1-U15, B-4 (filmed)

- **Asks.** (A-12) How close to a corner must the pointer be before a
  dwell runs the hot corner instead of the app? (A-36) Does a resting
  look at the top edge or past an edge bring up the menu bar, window
  controls, Notification Center, the Dock or Slide Over? (A-29, A1-U8,
  L1-U16) When the face is lost or the eyes close, does the pointer
  freeze, hide or stay, and does a dwell in progress continue? What does
  Show Face Guidance draw? (A-41) Does Eye Tracking keep working while
  FaceTime or Face ID uses the camera? (G-21, A1-U15) With glare on
  glasses or a dim room, which target sizes still work? (B-4) How much
  does the pointer jitter for a steady look?
- **Why.** Corners and edges are where the system's own actions wait;
  bad days and nights are when communication matters most.
- **How.**
  1. Eye Tracking and Dwell Control on, hot corners as found (note
     them). Probe > Ruler.
  2. Move your look slowly from the screen's middle toward the top-left
     corner; note the grid numbers where the corner's action starts.
     Repeat for each corner that has an action.
  3. On the iPad in Windowed Apps: rest your look at the top edge, then
     past the bottom and right edges, ten seconds each. Note anything
     the system shows.
  4. Close your eyes for three seconds, then five, then turn your face
     away; note the pointer each time, and whether a dwell started
     before finished afterwards. Turn on Show Face Guidance and repeat.
  5. Film the pointer for 30 seconds while you look steadily at one
     grid crossing; count how far it moves, in grid squares.
  6. Probe > Rings. Put on glasses with a lamp reflecting in them, or
     dim the room: for each middle-button size, dwell on it ten times
     and count misses.
  7. Start a FaceTime call to the second phone, return to the probe,
     and dwell on Rings' button; then lock and unlock with Face ID.
- **Record.** Corner distances in points; what each edge showed; the
  pointer's behaviour per case; jitter in points; misses per size and
  condition; whether Eye Tracking kept working.
- **What it means.** The corner distance is the area Home must keep
  clear, measured instead of guessed. An edge that opens a system panel
  under a resting look must have nothing of Brickson's near it. A
  pointer that keeps dwelling with eyes closed is a hazard for any
  control under it. The jitter sets target floors from a measurement
  instead of a margin (still one person and one device). The sizes that
  still work in bad conditions are the evidence for a bad-days profile
  (H-07).

### DEV-6. Head Tracking and a mouse with Dwell — A-1, A-3, A-7, A-8 (repeated), A-28 (mouse), A1-U18

- **Asks.** The questions of DEV-1 and DEV-2 again, with Head Tracking
  and with AssistiveTouch, a mouse and Dwell; and how Head Tracking's
  pointer modes, speeds and expressions behave (A1-U18).
- **Why.** One app follows a person from touch to head to eyes, so the
  answers must hold for each.
- **How.** Settings > Accessibility > Head Tracking (Snap to Item and
  Dwell Control on), then DEV-1 steps 2 to 4 and DEV-2 steps 2 to 4.
  Then a mouse with AssistiveTouch and Dwell Control (note whether Snap
  to Item is offered), the same steps, and Landing's hover buttons with
  the mouse resting on them. For A1-U18: map a facial expression to Tap
  and use it on the Snap station's Counter.
- **Record.** As DEV-1 and DEV-2, per input method; whether the mouse
  shows hover effects; what an expression mapped to Tap pressed.
- **What it means.** The same answers as Eye Tracking: one rule serves
  all three. A difference: the chain engine and the profiles must hold
  the difference, input method by input method.

### DEV-7. Switch Control — A-9, A-10, A-14, A-42, A-43, A-44, A1-U16, A2-U9, A2-U11, B1-U7, A-18 (Switch Control's speech: A2-U7, L1-U18), G-24 (screen switch)

- **Asks.** (A-9) Does Switch Control stop on a dimmed button, and what
  does it say about it? (A-10) Does a contained SwiftUI region become one
  scan group, and is sort priority followed? (A-14) After a scan runs
  out and the cursor hides, can the next press activate something? (A-42,
  A-44) Does the scan use new positions at once, and can it press a
  removed control? (A-43) What happens to a press while the app is busy?
  (A1-U16) Does Switch Control's eye-tracking mode behave like Dwell?
  (A2-U9) How many presses does a short word cost on Apple's keyboard?
  (A2-U11) Does the app's status value report Switch Control in every
  mode? (B1-U7) What does the app's pause request do to scanning? (A-18)
  Does Switch Control's own speech cut or duck the app's speech?
- **Why.** Every extra step in a scan is waiting time for a person with
  one switch.
- **How.**
  1. A Screen switch (Settings > Accessibility > Switch Control >
     Switches > Add New Switch > Screen > Full Screen, Select Item), Auto
     Scanning, Group Items on, Loops as found. Turn Switch Control on.
  2. Probe > Snap: let the scan run; note whether it stops on Dimmed and
     what it speaks with Speech on.
  3. Probe > Groups: note the scan order with each combination of the
     two Groups options.
  4. Let the scan run out; press once; note what happens.
  5. Probe > Changes and Busy: as in DEV-3, with the scan highlight on
     the slot; on Busy, choose Busy then press while it is busy.
  6. Probe > Typing: scan to the field, type "test" with the keyboard;
     count presses and seconds.
  7. Probe > Status: switch Switch Control Mode to Gliding Cursor, Head
     Tracking and Eye Tracking in turn; read
     `UIAccessibility.isSwitchControlRunning` each time.
  8. Probe > Speech, option "Pause Switch Control": Speak sentence;
     watch the scan. Then pause nothing, Switch Control's Speech on, and
     Speak sentence while the scan speaks.
- **Record.** Each step's observation, with the log.
- **What it means.** A dimmed button the scan skips is fine for a
  switch user (no wasted step) but must never be the only way to
  something. Regions that become groups: Home can be built so each
  region is one group, the cheapest scan; if not, the scan order needs
  sort priority alone. A press after the scan runs out that activates
  something is a hazard. If pausing Switch Control stops the scan during
  speech, Brickson could use it so a person's message is never talked
  over; if Switch Control's speech cuts the app's, that is a sound
  hazard to design around.

### DEV-8. Voice Control — A-11, A-16, A-30, B1-U13, A3-U3, A3-U4, A3-U7, A3-U14, A3-U16, A3-U18, L1-U19

- **Asks.** (A-11) Does Voice Control give a dimmed button a number or a
  name, and what happens when its name is said? (A-16) Does Voice Control
  hear the app's own speech and act on it? (A-30) Can custom actions be
  reached by voice? (B1-U13) Does "does not respond" remove an element
  from the overlays? (A3-U3, A3-U4) Do flexible names work offline, and
  what happens when a description fits two buttons? (A3-U7) Which pause
  words work? (A3-U14) Can Voice Control and VoiceOver run together?
  (A3-U16) Does a Vocal Shortcut still fire with Voice Control on?
  (A3-U18) Where do Voice Control's banners and numbers appear? (L1-U19)
  Does Attention Aware stop listening when the eyes close?
- **Why.** For a person who speaks to the device and hears Brickson's
  voice, the app's own speech must never become a command.
- **How.**
  1. Voice Control on. Probe > Snap: say "Show numbers", then "Show
     names"; note which elements get one. Say "Tap Dimmed", "Tap Not
     responding", "Tap Hidden". Say "Show actions for Actions" (or the
     action's name); note what happens.
  2. Probe > Speech: choose **Say a Voice Control command**. It says
     "Tap Counter" aloud through the speaker. Watch the Counter's log.
  3. Airplane mode on, flexible names on: say a loose name ("tap the
     counter button"). Probe > Groups: say "Tap one" (Left 1 and Right 1
     both fit).
  4. Try "Stop listening" and "Go to sleep", then their wake words.
  5. Turn VoiceOver on as well; say "Tap Counter".
  6. With a Vocal Shortcut set up, say it with Voice Control on.
  7. Probe > Ruler: note the grid numbers where Voice Control's banner
     and hints appear.
  8. Voice Control's Attention Aware on: close your eyes and give a
     command; then open them and give it again.
- **Record.** Each observation; for step 2, whether Counter fired.
- **What it means.** Counter firing on the app's own speech is a direct
  hazard: Brickson's voice could press its own buttons for a person who
  uses Voice Control, and the family guide must say how to avoid it (and
  the design must decide whether speech should pause Voice Control). A
  dimmed button with no number cannot be pressed by mistake; one with a
  number needs the same care as DEV-1's result. Custom actions that voice
  cannot reach mean nothing important may live in one (stage 1, L-11).

### DEV-9. Full Keyboard Access — A-9 (FKA part), A-10 (FKA part)

- **Asks.** Does Full Keyboard Access focus a dimmed button, and does it
  follow contained regions and sort priority?
- **How.** A hardware keyboard; Settings > Accessibility > Keyboards &
  Typing > Full Keyboard Access on. Probe > Snap: Tab through, note each
  stop. Probe > Groups: Tab through with each combination of the
  options.
- **Record.** The focus order per screen and option.
- **What it means.** As DEV-7, for keyboard users.

### DEV-10. VoiceOver, announcements and voices — A-17, A-18, A-31, A3-U8, A3-U10, A3-U19, D-25, G-30, G-32, D-07 (device)

- **Asks.** (A-17, A3-U10) Does the "starts media session" trait keep
  VoiceOver quiet while the app speaks, and does "plays sound" change
  anything? (A-18) Does pausing VoiceOver stop it talking over the app,
  and does an announcement interrupt the app's speech, or does VoiceOver's
  ducking lower it? (A-31) Are announcements spoken when VoiceOver is off
  but another input method is on? (A3-U8) What exactly does VoiceOver say
  for a dimmed button, a toggle on and off? (A3-U19) What does Magic Tap
  do in an app that defines none? (D-25, G-30) Do word reports arrive as
  often with a Personal Voice, and stay continuous across parts? (G-32)
  Does a Personal Voice honour SSML pauses?
- **Why.** The person's own message must never be talked over or cut.
- **How.**
  1. VoiceOver on. Probe > Snap: swipe through; write down what VoiceOver
     says for each element. Two-finger double-tap anywhere.
  2. Probe > Speech, trait option "No trait": double-tap Speak sentence;
     note whether VoiceOver speaks over it. Repeat with "Starts media
     session", then "Plays sound".
  3. Option "Pause VoiceOver": Speak sentence; note VoiceOver.
  4. Choose Announce in 3 seconds, then at once Speak sentence: note
     whether the announcement waits, overlaps or cuts in, and whether the
     app's speech gets quieter.
  5. VoiceOver off, Switch Control (then Voice Control, then Eye
     Tracking) on: Announce in 3 seconds; listen.
  6. Stop Screen Recording and any second phone's recording first.
     On the list, choose **Ask for Personal Voice**, allow it, then
     **List voices** and choose the Personal Voice. Speak sentence, Speak
     in three parts and Speak with SSML pauses, three times each. Repeat
     with the default voice. Share the log.
  7. Watch the speaking indicator on the device with Reduce Motion on
     and off (D-07 on real hardware).
- **Record.** What was heard, in words (nothing in a Personal Voice is
  recorded: docs/DEVICE-CHECKS.md, *Keep the repository's rules*); the
  log's word-report counts and gaps per voice.
- **What it means.** A trait or pause that keeps VoiceOver quiet is the
  way Brickson can protect its speech for VoiceOver users; none means a
  family guide note. Announcements heard without VoiceOver give Brickson a
  way to say something without its own speaker; none means passive text
  stays the only route (invariant 4). Fewer or broken word reports with a
  Personal Voice mean word lighting (E-07) must cope without them. A
  Personal Voice that ignores SSML means pauses must come from separate
  utterances (G-30).

### DEV-11. The screen, power and heat — A-22, A-23, A-24 (probe part), A-32, A-39, A1-U10, A4-U12, G-25, G-26, L1-U20

- **Asks.** (A-22) With the idle timer off, does Low Power Mode still
  lock the screen? Do dwell taps and switch presses count as touches for
  Auto-Lock? (A-23) Do Attention Aware Features or Guided Access's own
  Display Auto-Lock still dim or lock it? (A-32) Does a jolt bring up
  Shake to Undo while typing? (A-39, A1-U10) How warm does the device
  get and how fast does the battery fall over hours of Eye Tracking with
  the screen on, and how often does recalibration start? (A4-U12) Is
  Guided Access's status true only during a session? (G-25) If the
  screen dims or sleeps anyway, what wakes it for a person who can move
  only their eyes? (G-26) Does Eye Tracking work in a dark room lit only
  by the screen? (L1-U20) Does StandBy start if a charging iPhone on its
  side locks?
- **Why.** The screen must never lock for a person who cannot unlock it
  (invariant 12), all day and all night.
- **How.**
  1. On the probe's first list, "Screen: keep the screen on" on; open
     Probe > Screen. Turn Low Power Mode on. Leave the device untouched
     for five minutes; note whether it dims or locks (the log records
     the app leaving the screen).
  2. Turn "Screen: keep the screen on" off; Auto-Lock 30 seconds. Dwell
     on Snap's Counter every 20 seconds for two minutes; then press a
     switch every 20 seconds. Note whether it locks.
  3. With Attention Aware Features on, look away for a minute; then
     start Guided Access with its own Display Auto-Lock set short.
     Probe > Status: read `isGuidedAccessEnabled` before, during and
     after the session.
  4. Probe > Typing: type "test", then tap the mounted device's mount
     firmly; note any Undo prompt and where it appears.
  5. Probe > Screen, with "Screen: keep the screen on" on, Eye Tracking
     on, plugged in: two hours; note the thermal state lines in the log,
     the battery level at start and end, and each recalibration. Repeat
     unplugged.
  6. With the screen off: try to wake it by looking, by a switch, by
     voice.
  7. A dark room: Eye Tracking on, the screen at normal and at low
     brightness; dwell on Snap's Counter ten times each.
  8. An iPhone on its side on a charger, idle timer off and then on;
     note whether StandBy starts.
- **Record.** Each observation, with the log's times.
- **What it means.** Low Power Mode or another feature locking the
  screen despite the idle timer is a breach of invariant 12 that the app
  cannot fix by itself: the family guide must say which setting to
  change. Heat that throttles or stops the camera limits all-day Eye
  Tracking and is evidence for the guide's advice. Nothing that wakes
  the screen by gaze means a dark screen is a dead end for a person who
  only moves their eyes.

### DEV-12. On Brickson itself — the procedures in docs/DEVICE-CHECKS.md, and A-5, A-13, A-15, A-19, A-20, A-24, A-25, A-33, A-34, A-35, A-36, A-37, A-38, A-40, D-09, D-12, D-26, G-02, G-03, G-05, G-10 to G-15, G-23, A4-U1 to A4-U5, B2-U2, B2-U10 (device), L1-U7, L1-U21

Brickson's own device checks are already written step by step in
docs/DEVICE-CHECKS.md. Run them as they say, and note these study
questions with them:

| Study IDs | Run with | What to add |
|---|---|---|
| A-5 (the pointer after an activation) | F1, step 4 | Already the step |
| A-13 (where the Scanner menu sits), A-15 (where the scan resumes) | I5 | Note what the Scanner menu covers in each orientation, and where the scan resumes with Focused Item After Tap set to Current Item and to First Item |
| A-19 (keyboard height with Dwell or Zoom on Keyboard Keys), A-37 (floating, split and undocked iPad keyboards), A-34 (does a dwell on Return accept an autocorrection, or on Space a grey prediction) | I8 | Also type in the probe's Typing station, which shows the exact text received; record any word you did not type |
| A-20 (where the AssistiveTouch button starts and what it covers) | I6 | A screenshot of Home with the button showing, in each orientation |
| A-24 (Eye Tracking in Guided Access, and whether circled areas also block dwell, switch and voice) | G3 | Circle Home's Settings cell and try to reach it with each input method |
| A-25, A4-U1 to A4-U5 (Assistive Access: Eye Tracking inside it, its Back button, relaunch, the shortcut) | G4 | Note the Back button's position on the probe's Ruler too; whether a typed draft survives entering and leaving |
| A-33 (system sheets and bars, device part) | the Settings checks | Screenshots at both ends of the Liquid Glass setting |
| A-35 (banners over Home) | S2 | Note where each banner lands, how long it stays, and whether Snap to Item stops on it |
| A-36 (edges, window controls, Slide Over), L1-U21 (iPhone Mirroring) | W1 | Also iPhone Mirroring on the Mac: can a portrait-only app's window be resized? |
| A-38 (speech during a call), L1-U7, G-14 (be heard in a call) | S2 | With "Allow Apps to Add Audio in Calls" on and off |
| A-40 (Brickson's speech waking Siri) | S2 | Also the probe's Say a Siri test, beside another Apple device |
| D-09 (an HDR highlight on the message; Reduce Bright Effects) | the display checks | Read `AccessibilitySettings.isReduceHighlightingEffectsEnabled` on the probe's Status station |
| D-12 (Apple's own screens: the Live Speech window, the Phone keypad, Calculator, Music lyrics, Shortcuts tiles, Health) | — | Screenshots on the owner's devices in light, dark and Increase Contrast; a thread samples colours |
| D-26, B2-U2 (which devices can make a Personal Voice) | P1 | Note whether Create a Personal Voice is offered on each device. Apple's website terms forbid automated reading, so a person checks Apple's current pages |
| B2-U10 (do iPads report haptics) | — | A thread adds a one-line check to a temporary build; never committed |
| G-02 (a baseline typing speed by gaze with Apple's keyboard), G-05 (slide-to-type for gaze) | I8 | Type "the quick brown fox" in the probe's Typing station by Eye Tracking, with and without predictions; the log gives the times |
| G-03 (reading the message from across a room) | the display checks | Each message size, from the bedside, the foot of a bed and across a room |
| G-10, G-11, G-13, G-15 (leaving Brickson and coming back), G-12 (a Shortcuts link) | — | Not built in Brickson yet: run with Apple's own apps first (a Messages sheet, a phone link, FaceTime, Safari), counting dwells for each round trip and noting where the way back sits |
| G-23 (practising another input method and turning it off again) | I1 to I6 | Write down the safest routine found, for the family guide |

### DEV-13. The other settings, with the probe — A-26, A4-U7, A4-U15, A4-U16, A4-U18, D-16

- **Asks.** (A-26) Do Touch Accommodations (Hold Duration, Ignore
  Repeat) filter taps made by Dwell, Switch Control or Voice Control?
  (A4-U7) With Tap Assistance and a long delay, does a press on a button
  inside a scrolling list become a scroll? (A4-U15) Does Prefer
  Cross-Fade Transitions still exist, and do the app's values follow
  it? (A4-U16) Does Reduce Bright Effects change a pressed button and
  the app's value? (A4-U18) Do Per-App Settings change the values the
  app reads? (D-16) Does an interactive glass button's frame change as
  Snap to Item and Switch Control see it while it is pressed?
- **How.** Turn each setting on in turn and run: (A-26) Snap station's
  Counter by Dwell, by a switch, by voice; (A4-U7) Styles station's
  buttons by touch; (A4-U15, A4-U16, A4-U18) Probe > Status before and
  after, with Per-App Settings set for Brickson Probe only; (D-16)
  Styles station's Glass buttons, outlined by Snap and by the scan,
  watched while pressing.
- **Record.** Each observation; Status values before and after.
- **What it means.** A Touch Accommodation that filters dwell taps is a
  setting the family guide must warn about. Per-App Settings that reach
  the app's values let a family set Brickson differently from the rest of
  the device. A glass button whose frame moves under a press cannot sit
  on a dwell path.

---

## Group 3. Needs borrowed hardware

Each needs a device or accessory the owner does not have: from a clinic,
a loan library, a manufacturer's trial, or a friend.

| Step | IDs | Hardware | What to do |
|---|---|---|---|
| HW-1 | G-24 | An external switch (Bluetooth or wired; a NeuroNode or similar if possible) | DEV-7's steps 2 and 3 with the external switch; compare the order and groups with the Screen switch |
| HW-2 | G-22, A1-U17 | A dedicated eye tracker that drives an iPad through AssistiveTouch (TD Pilot, VersaEye with Hiru, Skyle) | DEV-1 and DEV-2 with it; Brickson's F1 and F2; note whether the recalibration corner and Snap to Item behave the same, and what happens with built-in Eye Tracking also on |
| HW-3 | G-41, B2-U8 | A small USB-C display | Connect it to the iPad and iPhone; does an external scene that shows only the message work, and does it change Eye Tracking, Snap to Item, Guided Access or the battery? Note which iPads offer Stage Manager on it |
| HW-4 | A1-U14, A2-U12, A4-U19, B2-U5, B2-U11 | An iPhone Duo | The dark camera area with Eye Tracking or Switch Control's eye tracking on, and whether Snap to Item reaches controls under it; the real scale and points per inch in each pose; Guided Access Pose Changes; Eye Tracking on the outer display; folding with the app running |
| HW-5 | A1-U6, A2-U1, A2-U2, A2-U14, A3-U5 | A device whose accessibility settings were never changed (a new device, or one just reset) | Write down every default these settings have on iOS 27: Dwell, Switch Control, Full Keyboard Access, Voice Control and VoiceOver |
| HW-6 | B2-U7, B2-U12, B2-U9 | An iPad with its front camera on the short edge; a 2018 or 2020 iPad Pro; a sound level meter | Eye Tracking held each way on the first; whether Eye Tracking is offered on the second; each device's loudest speech and alarm, at a metre and from the next room |

---

## Group 4. Ask Apple first

These are rules inside Apple's software that experiments can only
sample. Apple offers two routes: the Apple Developer Forums (free and
public; an Apple engineer already answered the Snap to Item question
there in 2024) and code-level support from Apple's engineers, which
members of the Apple Developer Program can request. Feedback Assistant
is how to ask Apple to document a behaviour or add an API.

**Recommended:** the owner posts ASK-1 to ASK-5 on the Developer Forums,
after DEV-1 and DEV-2 have run (so the question can cite what was seen),
and uses code-level support only for one the forums do not answer. Each
draft below says nothing about any person; edit freely.

- **ASK-1 (B-1, and A-1, A-2, A-3, A-7).** "With Eye Tracking or Head
  Tracking and Snap to Item on iOS and iPadOS 27, which accessibility
  elements does Snap to Item consider: only elements with the button
  trait, and does the not-enabled state exclude one? How does it measure
  the closest element (frame centre, frame edge, activation point or
  accessibility path), how far can it jump, and how does it break ties?
  We build an AAC app with standard SwiftUI Buttons and need to know
  where a resting look will land."
- **ASK-2 (B-2, A-4, A-6).** "With Dwell Control on iOS and iPadOS 27,
  after a dwell activates a control, what movement or time must pass
  before another dwell can start at the same place? And what happens to a
  dwell in progress when the element under a still pointer changes,
  appears or becomes enabled?"
- **ASK-3 (B-3, A-10).** "How does Switch Control build scan groups from
  a SwiftUI view hierarchy? Does `accessibilityElement(children:
  .contain)` produce one group, and how does `accessibilitySortPriority`
  interact with grouping, compared with UIKit's
  `accessibilityNavigationStyle`?"
- **ASK-4 (B-4).** "Is there published guidance on how steady the Eye
  Tracking pointer is for a steady look (smoothing, typical movement in
  points) at the recommended distance, so an app can size its targets
  from it?"
- **ASK-5 (A-27, stage 3's question).** "Can an app learn, through
  public API, that the pointer is being driven by Eye Tracking, Head
  Tracking or an external MFi eye tracker, so it can offer a layout sized
  for gaze? If not, would Apple consider such an API?" (A Feedback
  Assistant request too, if the answer is no.)
- **ASK-6 (G-32, only if DEV-10 leaves it unclear).** "Does a Personal
  Voice honour SSML (breaks, emphasis) and per-utterance pitch, rate and
  delays in `AVSpeechSynthesizer`?"
- **ASK-7 (G-20).** "Has Apple published, or can it share, any data on
  how well front-camera Eye Tracking works for people with motor
  neurone disease: with glasses, low light, drooping eyelids or
  vertical-only eye movement?"

---

## Group 5. Needs the owner's decision before it runs

- **OWN-1. Real users (G-20, A3-U15).** How well Eye Tracking works for
  people with ALS, and whether Listen for Atypical Speech helps Voice
  Control, can only be learned with real people: through a clinic, a
  study or a user group. How to reach them, and on what terms, is the
  owner's decision. *Recommended:* ask Apple first (ASK-7), then decide.
- **OWN-2. Code the rules forbid even in the probe.** Two questions need
  code that AGENTS.md forbids in every app target: what kind of touch a
  dwell or switch press delivers, and whether the gaze pointer sends
  hover events (parts of A-28: A1-U13, B1-U2, B1-U3), and a UIKit
  accessibility path (part of A-21 and B3-U3). The probe answers what it
  can without them (DEV-4's hover effects; Snap's round shape). Running
  the rest would need a throwaway project outside the repository, never
  committed. *Recommended:* skip unless DEV-4 leaves hover unclear.
- **OWN-3. Closer inspection of Apple's frameworks (B-1 to B-4).** The
  owner chose the safe way on 2026-11-14: no taking Apple's software
  apart. These questions go to Apple (Group 4) instead, and the
  experiments sample them. Nothing is planned here.
- **OWN-4. Apple's design kit (D-23, then D-15).** D-23 reads the
  kit's values only through the owner's Figma library, the route the
  kit's licence allows, and D-15 (a pressed-in key, rendered at the
  kit's proportions, judged by eye) waits on it. Both wait for the
  owner's answer about the design study's notes on the kit.

A result can also lead to a decision: a public signal that gaze is in
use (A-27) could let Brickson choose its gaze profile by itself; a dimmed
button that is a safe resting place (A-1) could change what fills
Home's empty places. Each such change to a rule is the owner's,
recorded in docs/DECISIONS.md before anything is built.

---

## What the Mac session does next

A Mac session (Remote Control on the owner's Mac) can start from this
section alone. It runs Group 1, in order, and nothing else: no device
steps, no change to Brickson's code.

1. Read AGENTS.md, *Build and test*, for how a session builds a pushed
   branch in its own worktree; never check out, stash or pull in
   `~/code/brickson`.
2. Make the worktree and the probe:

   ```sh
   cd ~/code/brickson && git fetch origin main
   git worktree add --detach ~/code/brickson-experiments origin/main
   cd ~/code/brickson-experiments && xcodegen generate
   xcrun simctl list devices available          # pick one iPad and one iPhone
   xcodebuild -project Brickson.xcodeproj -scheme BricksonProbe \
     -destination 'platform=iOS Simulator,id=<udid>' \
     -derivedDataPath build/probe build
   APP=build/probe/Build/Products/Debug-iphonesimulator/BricksonProbe.app
   xcrun simctl boot <udid>                      # if it is not booted
   xcrun simctl install <udid> "$APP"
   xcrun simctl launch <udid> "$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$APP/Info.plist")"
   xcrun simctl io <udid> screenshot build/probe/<name>.png
   ```

   Before this pull request merges, use its branch in place of `main`.
   Success: the Simulator shows "Brickson Probe" and its list of
   stations. Build Brickson the usual way (`scripts/test.sh`) for the
   steps that use it.
3. Run SIM-1 to SIM-14 in order. SIM-1, SIM-2, SIM-3 and SIM-4 first:
   each takes minutes. Then SIM-5 and the rest.
4. Keep raw captures in `private/device-checks/` in the worktree. A still
   that shows only the probe, or Brickson with the starter library, may
   go in `docs/evidence/<date>-experiments-simulator/`.
5. Write the results in one docs-only pull request: one `docs/log/`
   record (`docs/log/README.md`), each SIM step here updated with what
   was found ("Found, <date>: ..."), and docs/HANDOFF.md's line on the
   experiments. Say which simulator, runtime, text size and appearance
   each result was measured on.
6. Stop at any step that would need a device, a person or a rule change,
   and list it in the record.
7. Remove the worktree when the pull request merges:
   `git -C ~/code/brickson worktree remove ~/code/brickson-experiments`.

---

## Every ID, and where it runs

**Stage 1 questions.** A-1: DEV-1 (first), DEV-6. A-1a: SIM-5. A-2:
DEV-2, DEV-6. A-3: DEV-1, DEV-6. A-4: DEV-1. A-5: DEV-12 (DEVICE-CHECKS
F1 step 4). A-6: DEV-3. A-7: DEV-1, DEV-6. A-8: DEV-2, DEV-6. A-9: DEV-7,
DEV-9. A-10: DEV-7, DEV-9, ASK-3. A-11: DEV-8. A-12: DEV-5. A-13: DEV-12.
A-14: DEV-7. A-15: DEV-12. A-16: DEV-8. A-17: DEV-10. A-18: DEV-10,
DEV-7. A-19: DEV-12. A-20: DEV-12. A-21: DEV-1, OWN-2. A-22: DEV-11.
A-23: DEV-11. A-24: DEV-12, DEV-11. A-25: DEV-12, SIM-1. A-26: DEV-13.
A-27: DEV-7, DEV-10 and the Status station in every session; ASK-5.
A-28: DEV-4, DEV-6, OWN-2. A-29: DEV-5. A-30: DEV-8. A-31: DEV-10. A-32:
DEV-11. A-33: SIM-10, DEV-12. A-34: DEV-12. A-35: DEV-12. A-36: DEV-5,
DEV-12. A-37: DEV-12. A-38: DEV-12. A-39: DEV-11. A-40: DEV-12. A-41:
DEV-5. A-42: DEV-3, DEV-7. A-43: DEV-7. A-44: DEV-3, DEV-7. A-45:
SIM-11, DEV-7.

**Stage 1 closer-inspection questions.** B-1: ASK-1, OWN-3. B-2: ASK-2,
OWN-3. B-3: ASK-3, OWN-3. B-4: ASK-4, DEV-5 (filmed jitter), OWN-3.

**Stage 1 experiments, by area.** Merged into a question: A1-U1 → A-4;
A1-U2 → A-7; A1-U3 → A-2; A1-U4 → A-8; A1-U5 → A-6; A1-U7 → A-20; A1-U9
→ A-29; A1-U11, A1-U13 → A-28; A1-U12 → A-27; A1-U19 → A-12; A1-U20 →
A-3; A1-U21 → A-19. A2-U3, A2-U4 → A-10; A2-U5 → A-9; A2-U6, A2-U10 →
A-13; A2-U7 → A-18; A2-U8 → A-15; A2-U15 → A-14. A3-U1 → A-11; A3-U2 →
A-16; A3-U6 → A-23; A3-U9 → A-17; A3-U11, A3-U12, A3-U13 → A-18. A4-U1,
A4-U2 → A-25; A4-U6 → A-26; A4-U8 → A-24; A4-U9, A4-U11 → A-23; A4-U10
→ A-22; A4-U14 → A-32; A4-U17 → A-33. B1-U1, B1-U9 → A-27; B1-U2, B1-U3
→ A-28; B1-U4 → A-7; B1-U5 → A-8; B1-U6 → A-10; B1-U8 → A-30; B1-U12 →
A-31. B3-U1, B3-U6 → A-27; B3-U2 → A-28; B3-U3, B3-U7 → A-2; B3-U4 →
A-43; B3-U5 → A-42; B3-U8, B3-U9 → A-45; B3-U10 → A-44. L1-U1, L1-U2,
L1-U3, L1-U17 → A-36; L1-U5 → A-35; L1-U6 → A-38; L1-U8 → A-40; L1-U9 →
A-41; L1-U10 → A-39; L1-U11 → A-22; L1-U12, L1-U14 → A-37; L1-U13 →
A-34; L1-U18 → A-18; L1-U22 → A-33.

Placed on their own: A1-U6 → DEV-0, HW-5. A1-U8 → DEV-5. A1-U10 →
DEV-11. A1-U14 → HW-4. A1-U15 → DEV-5. A1-U16 → DEV-7. A1-U17 → HW-2.
A1-U18 → DEV-6. A2-U1, A2-U2, A2-U14 → DEV-0, HW-5. A2-U9 → DEV-7. A2-U11
→ DEV-7. A2-U12 → HW-4. A2-U13 → SIM-11. A3-U3, A3-U4, A3-U7, A3-U14,
A3-U16, A3-U18 → DEV-8. A3-U5 → DEV-0, HW-5. A3-U8 → SIM-5, DEV-10.
A3-U10, A3-U19 → DEV-10. A3-U15 → OWN-1. A3-U17 → SIM-11. A4-U3, A4-U4,
A4-U5 → DEV-12 (with A-25). A4-U7 → DEV-13. A4-U12 → DEV-11. A4-U13 →
SIM-1. A4-U15, A4-U16, A4-U18 → DEV-13. A4-U19 → HW-4. B1-U7 → DEV-7.
B1-U10 → SIM-13. B1-U11 (focus notices for Full Keyboard Access and
Voice Control) and B1-U14 (`accessibilityDefaultFocus` for Switch
Control): not in the probe yet; a later probe change adds them, then
DEV-7 and DEV-9 run them. B1-U13 → DEV-8. B2-U1 (which devices have
Head Tracking), B2-U3 (whether the iPhone 17e has an Action button):
reading Apple's pages, by a person (Apple's website terms forbid
automated reading). B2-U2 → DEV-12. B2-U4, B2-U6 → SIM-12. B2-U5,
B2-U11 → HW-4. B2-U7, B2-U9, B2-U12 → HW-6. B2-U8 → HW-3. B2-U10 →
SIM-13, DEV-12. B3-U11 → *Before every session*. L1-U4 → SIM-13. L1-U7
→ DEV-12. L1-U15 → DEV-1 (rest a look on the Typing station's field
when it holds text: what opens?). L1-U16 → DEV-5. L1-U19 → DEV-8. L1-U20
→ DEV-11. L1-U21 → DEV-12.

**Stage 2 design questions.** D-01: SIM-2. D-02: SIM-10. D-03: DEV-1.
D-04: DEV-1. D-05 (which type reads best at 45 cm) and D-06 (condensed
type for long words): renders of neutral words at Home's sizes, made on
the Mac (a scratch view, never committed), judged by the owner at 45 cm
during any DEV session. D-07: SIM-6, DEV-10. D-08 (dark labels on
coloured buttons in Apple's apps): screenshots of Apple's apps, with
D-12 in DEV-12. D-09: DEV-12. D-10: DEV-4. D-11: DEV-4. D-12: DEV-12.
D-13: SIM-1. D-14: SIM-7. D-15: OWN-4. D-16: DEV-13. D-17: SIM-8. D-18:
DEV-4. D-19: DEV-4. D-20: SIM-9. D-21: SIM-10. D-22: SIM-4. D-23: OWN-4.
D-24: SIM-3. D-25: SIM-14, DEV-10. D-26: DEV-12.

**Stage 3 field questions.** G-01: DEV-3. G-02: DEV-12. G-03: DEV-12.
G-05: DEV-12. G-10, G-11, G-12, G-13, G-15: DEV-12. G-14: DEV-12. G-16
(a hot corner running Brickson's Get Attention from another app): waits
on App Shortcuts (docs/ROADMAP.md, R2), then DEV-12. G-20: ASK-7, OWN-1.
G-21: DEV-5, DEV-4. G-22: HW-2. G-23: DEV-12. G-24: DEV-7 (screen
switch), HW-1. G-25: DEV-11. G-26: DEV-11. G-30: SIM-14, DEV-10. G-31
(do shaped pauses sound natural to listeners): the owner and a listener,
after DEV-10. G-32: DEV-10, ASK-6. G-40: SIM-14. G-41: HW-3. These are
all 23 questions the field study asks; it numbers them by its sections,
so G-04, G-06 to G-09, G-17 to G-19, G-27 to G-29 and G-33 to G-39 are
not used.

**Device checks already written** (docs/DEVICE-CHECKS.md). F1: DEV-12
(with A-2, A-4, A-5, A-7); run DEV-1 and DEV-2 first, which answer the
same questions on the probe's simpler screen. F2, F3, F4 and every other
procedure there: DEV-12, as written.

**Stage 5 inputs, not experiments.** E-01 to E-11 (the design-language
study's components) and H-01 to H-10 (the field study's building
blocks) are built only after these results; each names the questions it
waits on in its study.
