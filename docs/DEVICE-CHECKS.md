# Device checks: the steps, and what passes

This is the step-by-step procedure for every check that needs a real
iPhone or iPad: every row of docs/HANDOFF.md, *Checks that need a real
device*, and every gate of docs/ROADMAP.md, *The quality bar*, that the
owner checks. Each procedure says what to set up, what to do, what
passes, and what to write down. *Coverage*, at the end, maps every row
and gate to its procedure.

It follows the 2026-10-26 Settings procedure
([`log/2026-10-26-settings-simulator-checks.md`](log/2026-10-26-settings-simulator-checks.md#environment-and-settings-for-the-physical-run)),
which stays the detailed procedure for Settings by a stray dwell (F4).
The Apple setting paths and tool claims listed in
[`evidence/2026-11-04-device-procedures/apple-claims.json`](evidence/2026-11-04-device-procedures/apple-claims.json)
were checked against Apple's own pages on 2026-11-04; the record of
that check, with what Apple does not say, is
[`log/2026-11-04-device-procedures.md`](log/2026-11-04-device-procedures.md).

## Who does each step

Every step is marked with who does it.

- **Owner**: the owner, by hand, on their own iPhone or iPad. Everything
  that goes through Eye Tracking, Head Tracking, Switch Control, Dwell,
  Voice Control, Full Keyboard Access or VoiceOver, everything judged by
  ear, and every judgment.
- **Agent**: a thread, from the owner's Mac over Remote Control, with the
  device on the cable: Brickson's own UI tests through `launchedApp`
  (XCUITest), or Apple's Instruments. These count as evidence (AGENTS.md,
  *Workflow rules*). A Remote Control run needs a fresh message from the
  owner in the thread, the device unlocked on the cable, and the owner at
  hand for the device's passcode.
- **Thread**: a thread with no device, reading what a session produced
  (recordings, traces, logs, the owner's notes) and writing the record.

**Why the split.** No automation tool can drive iOS's own assistive
input. XCTest, and every tool built on it, delivers touches straight to
the app, around Switch Control, Dwell and the rest; Apple gives XCTest
no way to turn those features on, except VoiceOver from iOS 27
(`XCUIVoiceOverService`); and Eye Tracking and Head Tracking use the
front camera and a person's face. Apple also says Switch Control,
VoiceOver and Voice Control "isn't available on Simulator", which is why
these checks need a device at all
([Performing accessibility testing for your app](https://developer.apple.com/documentation/accessibility/performing-accessibility-testing-for-your-app)).
A tap reported by any other automation tool is not evidence (AGENTS.md,
*Gotchas*). The study behind this split, and the tools it rejected, are
in the record.

**Which build.** A gate passes only on the build that ships, from
TestFlight once there is an App Store Connect record (docs/ROADMAP.md,
*The quality bar*). Until then, and for agent runs, the build is a
development build installed from the Mac (docs/GETTING_STARTED.md, *Run
it on your own iPhone or iPad*). A run on a development build answers
the device-check row it was made for and finds problems early; the gate
that row belongs to passes when the same steps pass again on the build
that ships. Every record names its build.

## The order

The checks already waiting come first, because they decide open design
questions before any larger-size build goes to App Review (docs/ROADMAP.md,
*The quality bar*, Q2, Q12 and Q13). Q4 puts sound first; here the dwell
checks run before it because they decide those questions, and Q4
passes only once S1 to S6 have passed. The order of sessions changes no
pass or fail (docs/DECISIONS.md, "The queued dwell checks run before
sound").

| When | What | Who | About how long |
|---|---|---|---|
| Once, before anything | *Before any check* | Owner, with a thread | An hour |
| Any day the device is on the cable | A1, Brickson's UI tests on the device | Agent | One to two hours per device, unattended |
| First session | F1 Snap to Item and Dwell measured, then F2 the three dwell hazards, then F4 Settings by a stray dwell | Owner | Two to three hours with rests |
| Second session | F3 the floors | Owner (the testers repeat its list in the pilot) | About two hours |
| Then, in any order | Sound (S1 to S6), Personal Voice (P1 to P5), every input method (I1 to I7), windows (W1 to W4), Apple's doors (G1 to G5), look (L1 to L4) | Owner, some with an agent | A session each |
| On the release candidate | A2 to A4, M1 to M3 | Agent and owner | A day for M3 |
| Through TestFlight | The long sessions (I7), H1 to H6 | Owner, then the testers | Weeks |

A1 can run before the first session: it needs only the cable and finds
anything that breaks only on hardware before the owner spends time on it.

## Before any check

### What to have

- **Owner:** the iPhone and iPad, each on iOS or iPadOS 26 or later, with
  Brickson's build to check installed. A stand that holds the iPad, and
  one for the iPhone, steady on a table. A second phone (any phone) to
  call the device, for the sound checks. Wired or Bluetooth headphones,
  for S4.
- **Owner:** for every agent run, the Mac with the checkout at
  `~/code/brickson`, your Apple Developer Team ID (docs/GETTING_STARTED.md,
  *Run it on your own iPhone or iPad*, step 1) in `project.yml`'s
  `DEVELOPMENT_TEAM` line (a local change, never committed), the cable,
  and Developer Mode on the device: Settings > Privacy & Security >
  Developer Mode, which appears once pairing with the Mac has started
  (or if the device was paired before). Turning it on asks to restart;
  after the restart, swipe up, tap Enable and enter the passcode.

### Keep the repository's rules

The repository is public. Before anything leaves a device:

- Check with the **starter library**, untouched, and type only neutral
  test words such as "test one two three". Never a personal message.
- Turn on Do Not Disturb before recording the screen, so no notification
  appears in a recording.
- Name a device by its model ("iPad Pro 13-inch (M4)"), never by its name
  in Settings, which often holds a person's name. Never write a device's
  identifier in a committed file.
- Raw recordings and traces stay on the Mac, in `private/device-checks/`
  inside the checkout, which git ignores (`/private/` in `.gitignore`).
  A still that shows only Brickson with the starter library may go in
  `docs/evidence/<date>-<topic>/`. Anything in the owner's own Personal
  Voice stays private: the record says only what was heard.

### Write down each result

- **Owner:** note each step's result as it happens, in the thread or in a
  note: what was done, what happened, and the time. Say PASS only for
  what was actually seen or heard, FAIL for anything that went wrong
  (with what led to it), and UNVERIFIED for a trial that could not show
  the answer. Repeat any unexpected result once, with nothing changed.
- **Owner:** at the start of each session, note: the date; each device's
  model and iOS version (Settings > General > About); the build
  (TestFlight's build number, or the commit the development build was
  made from); the input method and its settings as found; orientation;
  text size; light or dark; Bold Text, Increase Contrast, Reduce
  Transparency and Display Zoom; and, for a mounted device, the distance
  and the light.
- **Both devices.** Unless a step names one device, run it on the iPhone
  and on the iPad. A row whose steps run on both passes, and counts
  toward Q4, only when it passed on both, and the record names each
  device's result. Where a device cannot run a step (no folding iPhone,
  no Create a Personal Voice offered), the step is UNVERIFIED for that
  device, with the reason.
- **Thread:** turns the notes, recordings and traces into a docs pull
  request with one new `docs/log/` record (AGENTS.md, *Workflow rules*;
  the template is `docs/log/README.md`), one section per session when it
  covers several. It edits the row's summary in docs/HANDOFF.md,
  *Checks that need a real device*, and, when a gate's state changes,
  that gate's *Today* line in docs/ROADMAP.md, *The quality bar*.

### Mount the device

**Owner.** Apple's guidance for Eye Tracking: the device "should be on a
stable surface about a foot and a half away from your face", the camera
needs a clear view of the face, and the face should be adequately lit
([iPhone](https://support.apple.com/guide/iphone/iph66057d0f6/ios),
[iPad](https://support.apple.com/guide/ipad/ipad2cd35723/ipados)). Use
the same mount, distance and light for every comparison, and note any
change. Head Tracking uses the same front camera.

**Never view the device in Xcode's Device Hub during a session that uses
the camera or the microphone.** Apple: "You can't access the camera or
microphone while interacting with a physical device in Device Hub"
([Interacting with your app in Device Hub](https://developer.apple.com/documentation/xcode/interacting-with-your-app-in-device-hub)).
Eye Tracking, Head Tracking and Voice Control would stop working.

### Set up a way out first

**Owner.** Before turning on any input method, set up the Accessibility
Shortcut (Settings > Accessibility > Accessibility Shortcut), so a
triple-click turns the feature off again: the side button on an iPhone
with Face ID, the Home button on an iPhone SE or an iPad that has one,
and the top button on other iPads. Apple's pages confirm the shortcut
for Switch Control, VoiceOver, Voice Control, AssistiveTouch, Guided
Access and Assistive Access; whether Eye Tracking, Head Tracking and
Full Keyboard Access are in its list is not documented, so check the
list on the device. With Switch Control on, Apple warns, the
touchscreen's standard gestures cannot turn it off.

### Turn on each input method

**Owner.** Note every setting as found before changing anything, and
put each back afterwards. The paths below are from Apple's iPhone and
iPad guides for iOS 26 and 27.

- **Eye Tracking:** Settings > Accessibility > Eye Tracking. Turn it on
  and follow the dot to calibrate; it calibrates every time it is turned
  on. Its options are Smoothing, Snap to Item ("automatically move to
  the item on the screen that's closest to where you're looking"), Zoom
  on Keyboard Keys, Auto-Hide, Dwell Control (on or off) and Show Face
  Guidance. To recalibrate, look at the top-left corner (a hot corner,
  changeable in Dwell Control's Hot Corners); calibration also starts
  by itself after the face or the device moves, if it is needed.
- **Dwell's timing**, for Eye Tracking, Head Tracking and AssistiveTouch
  alike: Settings > Accessibility > Touch > AssistiveTouch > Dwell
  Control. Fallback Action, Movement Tolerance, Hot Corners, the
  keyboard's Key Dwell Time, and the time a dwell takes, set with
  Decrement and Increment. Apple gives no unit for that time: note the
  value exactly as shown. The pointer's size and colour are in
  Settings > Accessibility > Pointer Control.
- **Head Tracking:** Settings > Accessibility > Head Tracking (iOS and
  iPadOS 26 and later). Options: Actions (facial expressions, with
  Sensitivity), Pointer, Pointer Speed, Snap to Item and Dwell Control.
  Switch Control also has a Head Tracking mode (Settings > Accessibility
  > Switch Control > Switch Control Mode); this file means the first
  unless it says so.
- **AssistiveTouch with Dwell:** connect a mouse or trackpad, then
  Settings > Accessibility > Touch > AssistiveTouch, turn it on, and turn
  on Dwell Control. Apple documents Snap to Item there only for an
  external eye tracker on iPad, not for a mouse: note whether the option
  appears.
- **Switch Control:** Settings > Accessibility > Switch Control >
  Switches > Add New Switch, then choose the source (External, Screen,
  Camera, Back Tap, Sound or AirPod Gestures) and the action (Select Item
  for Auto Scanning, the default). The scanning style is a screen of its
  own, Scanning Style (Auto Scanning, Manual Scanning, Single Switch Step
  Scanning). Switch Control's own screen lists Auto Scanning Time, Pause
  on First Item, Loops, Move Repeat, Group Items ("Group items for faster
  navigation"), Tap Behavior (with Auto Tap), Focused Item After Tap
  ("resumes scanning at an item you tap or from the beginning"), Hold
  Duration and Ignore Repeat; turn Switch Control on at the top of that
  screen, once the Accessibility Shortcut is set up. Point scanning is
  Switch Control Mode > Gliding Cursor. In item
  mode, selecting an item opens the Scanner menu, where Tap activates
  it; with Group Items on, the first selection picks a group. Note Tap
  Behavior and Group Items in every record.
- **Voice Control:** Settings > Accessibility > Voice Control > Set Up
  Voice Control (a one-time download over Wi-Fi). Commands used here:
  "Show names", "Show numbers", "Show grid", "Tap" and an item's name,
  and "Hide names". On iOS and iPadOS 27, Flexible Item Names (in the
  same settings, on by default, with Apple Intelligence) lets a loosely
  worded name succeed: turn it off to test exact names, and note it.
- **Full Keyboard Access:** a hardware keyboard, then Settings >
  Accessibility > Keyboards & Typing > Full Keyboard Access. Tab moves
  forward, Shift-Tab back, Space activates, and Tab-H lists the commands.
- **VoiceOver:** Settings > Accessibility > VoiceOver. Swipe right for
  the next item, double-tap to activate.
- **Touch Accommodations:** Settings > Accessibility > Touch > Touch
  Accommodations on iOS 26; iOS 27 opens a Set Up Touch Accommodations
  flow there first. Hold Duration ignores touches shorter than its time;
  Ignore Repeat and Tap Assistance are on the same screen.

### Choose Home's sizes

**Owner.** Home's sizes follow Family Setup's answer to "How is the
screen reached?" (Brickson's Settings > Family Setup > Set Up Step by
Step): Touch, Voice Control and Someone else helps give touch's sizes;
Switch Control, Head Tracking and Eye Tracking give their own; several
answers give the largest; no answer gives Eye Tracking's. A window takes
the largest sizes it holds, so the same answer can give different sizes
on different windows (docs/DECISIONS.md, "Sizes that follow how the
screen is reached"). The change shows when Settings closes. Note the
answer; a thread works out which sizes the window took from the A1
run's frames or the layout engine. With one category chosen in the
second step ("Which phrases does Home show?"), the rest board, Home asks
for the late stage's sizes whatever the first answer is: keep Every
Category chosen except in F3 step 4, and check it before each session.

### The look-target sheet

Several checks ask the owner to rest a look on exact points.

- **Agent:** from a capture of Home on the same device, orientation,
  text size, answer and library (A1 keeps them), a thread makes a sheet:
  the capture with numbered points, and a table giving, for each point,
  what is under it and which control is nearest by centre and by edge
  on the frames. It picks points where the two rules disagree, points in
  empty space at measured distances from the nearest control, and the
  points each hazard in F2 names. The sheet goes in
  `private/device-checks/` and, as a still of Home with the starter
  library, may also go in `docs/evidence/`.
- **Owner:** prints the sheet or shows it on another screen, and looks at
  the same spot on the device.

### For an agent run

- **Owner:** connects the device, unlocks it, taps Trust if asked, and
  writes "go" in the thread, so Remote Control can start. Stays near for
  the passcode.
- **Agent:** reads the device's identifier with `xcrun devicectl list
  devices` (or Device Hub's Info tab) and never writes it in a committed
  file. Apple: "unlock the device before entering `devicectl` commands."
- **Agent:** if the test runner fails to start on the device, the owner
  turns on Settings > Developer > Enable UI Automation. Apple's pages do
  not name this switch; community reports and Appium's guide do.
- What a run does to the device: it installs a development build of
  Brickson and its test runner in place of the build there; the tests
  use their own storage, never the phrases on the device; and they speak
  aloud.

## The checks already waiting

### F1. Snap to Item and Dwell, measured

*Q12, and the rows on how far Snap to Item jumps, nearest centre or
nearest edge, a lingering look, controls scrolled off screen, and a
comfortable dwell time. These decide which of the chain engine's
findings bind (docs/DECISIONS.md, "One chain engine for dwell safety"),
and so Q2.*

Set-up:

1. **Agent:** makes the look-target sheet for the mounted iPad in
   portrait at the default text size, answer Eye Tracking.
2. **Owner:** mounts the iPad; turns on Eye Tracking, calibrates, turns
   on Snap to Item; notes every Eye Tracking and Dwell Control setting as
   found; sets Fallback Action to Tap (the 2026-10-26 procedure's
   choice); answers Eye Tracking in Family Setup; closes Settings.
3. **Owner:** starts a screen recording (Control Center's Screen
   Recording). Watch it back once: if the Eye Tracking pointer does not
   show in it, film the screen with the second phone instead.

Steps:

1. **Nearest centre or nearest edge. Owner.** In Settings > Accessibility
   > Eye Tracking, turn Dwell Control off, so a resting look selects
   without activating. Rest the look on each numbered point for five
   seconds and note which control the pointer outlines. If nothing snaps
   with Dwell Control off, turn it back on and note what each point
   activates instead (a point there may speak Yes or No).
   *Measured when* every point has a recorded control. The thread
   compares each with the sheet's two answers and records which rule the
   pointer follows (or that it follows neither).
2. **How far it jumps. Owner.** Rest the look on each empty-space point,
   nearest first. Note the farthest point that still snaps to a control,
   and the nearest that does not. *Measured when* both are noted, with
   the sheet's distances.
3. **Which control a look on the message selects. Owner.** Speak a
   phrase, so the message shows it. Rest the look on the message's
   centre, each end, and just inside its top and bottom edges; note the
   control outlined at each.
4. **After an activation: does the pointer stay or follow the look?
   Owner.** Dwell Control on. Dwell on Emergency, which changes the
   phrases, then keep looking at the same spot for ten seconds. Note
   where the pointer is during that time and what it outlines, and
   whether it ever activates again. Repeat on a category, and on a
   phrase tile.
5. **Does a lingering look fire again? Owner.** Dwell on a phrase tile
   and keep looking at it for 20 seconds. Count how many times it
   speaks; a repeat of the phrase still speaking is absorbed by design
   (`SpokenUtteranceTracker`), so also count the phrase starting over
   after it finished.
6. **Controls scrolled off screen. Owner.** On the mounted iPhone, with
   Eye Tracking calibrated there, set the text size to AX5 (Settings >
   Accessibility > Display & Text Size > Larger Text, with Larger
   Accessibility Sizes on). Open Brickson's Settings and scroll
   its first screen until a row is partly, then wholly, off the screen.
   Rest the look at the edge nearest the hidden row. Note whether the
   pointer goes to the hidden row, the screen scrolls, or nothing
   happens. Then, in Family Setup > Phrases and Categories, open a
   category, scroll until a phrase row lies wholly under the navigation
   bar at the top, rest the look on the bar over it, and note the same.
   The chain test leaves out a row the bar covers wholly
   (docs/DECISIONS.md, "The Library's question screens").
7. **A comfortable dwell time and movement tolerance. Owner.** Starting
   from the values found, read the message aloud to yourself for a
   minute with the look on it, then speak five phrases and answer Yes
   and No. Note every activation not meant and every one that felt slow.
   Step the dwell time one Increment or Decrement and repeat, until the
   shortest value at which reading for a minute fires nothing; then do
   the same with Movement Tolerance. Note each value as shown.
8. **Owner:** repeat steps 1 to 5 and step 7 with Head Tracking, and,
   where a mouse is at hand, steps 1 to 5 with AssistiveTouch Dwell
   (noting whether Snap to Item was offered).

*Recorded when* steps 1 to 7 have a result for Eye Tracking, and steps
1 to 5 and 7 for Head Tracking. **Thread:** rescores the chain engine
with the measured rule and pointer, lists which findings bind, and
changes Family Setup's guides to recommend each method's measured dwell
time and tolerance, in a pull request.

### F2. The three dwell hazards

*Q2. Open today: Yes and No border the message; the top of Stop's well
is nearest Again; by centre, dimmed phrases border Clear and Put Back
(docs/DECISIONS.md, "Settings on Home", "Get Attention and Stop on Home"
and "Typing on Home").*

Set-up: as F1, with Dwell Control on, the sheet's points for each
hazard, the volume comfortable for the room, and Stop in reach.
Run each hazard on the iPad in portrait and landscape, and on the
mounted iPhone, where they are largest: on regular widths Emergency sits
above Stop's well, so the second hazard shows only on compact widths.

1. **Yes and No border the message. Owner.** Speak a phrase. Then rest
   the look on the message as a person reading it would, for 30 seconds
   at each of the sheet's message points. Then choose Type, type "test"
   with the keyboard, and do the same.
   *Passes* when nothing activates. *Fails* when Yes, No or anything
   else does: note the point, what fired and how many times in each
   30 seconds.
2. **The top of Stop's well is nearest Again. Owner.** Dwell on Get
   Attention, then on Stop. After Stop, keep looking where it
   was for ten seconds. Then, with nothing sounding, rest the look on
   the top of the empty well for ten seconds. Repeat each five times.
   *Passes* when Again never fires (the look should meet a category or
   nothing). *Fails* when the last message repeats: note how often.
3. **Dimmed phrases border Clear and Put Back. Owner.** Choose Type and
   type "test". Rest the look on the top part of each top-row phrase
   tile, and in the gaps between them, ten seconds each.
   *Passes* when the message never changes. *Fails* when it is cleared
   or put back: note the point.
4. **Thread:** records each hazard's count with F1's rule. Each hazard
   that fails, or that F1's rule says can fail, goes to the owner once,
   on a decision card: remove it by placement (a design job), or accept
   it as a named exception in docs/DECISIONS.md, with how often it
   happened. Q2 passes only when every open hazard is one or the other.

Q2's other items wait: Again nearest Stop's empty well with fewer than
three everyday categories needs editing, which is not built, and the
iPhone Duo items need a folding iPhone (W3).

### F3. The floors

*Q13, and the row on each profile's floors with Eye Tracking, Head
Tracking and Switch Control's point scanning, and the rest board's
late-stage sizes. The switch, head and late-stage floors are proposals
until this passes (docs/DECISIONS.md, "Sizes that follow how the screen
is reached" and "The late-stage profile").*

1. **Agent:** writes a fixed list of activations on the sheet, in a set
   order: every phrase tile of two categories, every category, Yes, No,
   Again, Emergency and back, Type and Phrases, Get Attention and Stop
   twice. With the starter library that is about 31, so the list
   then starts again from the top until it holds exactly 60. The sheet
   is made at AX3 as well as the default text size.
2. **Thread:** before any run counts, confirms from A1's frames or the
   layout engine that the mounted iPad, in portrait with Bold Text off,
   takes the profile under test at each text size (*Choose Home's
   sizes*), and the late stage's sizes for step 4. A run on a window
   that took other sizes does not count: that profile and text size is
   UNVERIFIED on this iPad, and runs again on an iPad or orientation
   that takes it.
3. **Owner:** on the mounted iPad, in portrait with Bold Text off, for
   each of Eye Tracking, Head Tracking, and Switch Control's Gliding
   Cursor: answer that method in Family Setup, close Settings, and make
   the 60 activations, at the default text size and again at AX3. Count
   a **miss** whenever an activation lands on another control, needs a
   second try, or does not happen.
4. **Owner:** on the same iPad, choose the rest board (Set Up Step by
   Step's second step, "Which phrases does Home show?", one everyday
   category) and, with Eye Tracking, make the list's activations that
   the board shows, starting again from the top until there are 60.
   Choose Every Category afterwards.
5. *Passes* for a profile when, in each run of 60 on its own (each
   text size, and the rest board), the misses times 20 are fewer than
   the activations made: at most 2 misses in each 60 (fewer than 1 in
   20). Otherwise the owner changes that profile's floors and it runs
   again.
6. **Owner:** confirms or changes the switch, head and late-stage
   floors, and the late stage's 4-degree growth, in words the thread
   records in docs/DECISIONS.md. The testers run the same list during the
   pilot.

### F4. Settings by a stray dwell

*The row on opening Settings by a stray dwell and leaving it by Back to
Talking (docs/DECISIONS.md, "Settings is a cover with a fixed safety
bar").*

**Owner.** Follow the 2026-10-26 procedure's *Steps and result criteria*
([`log/2026-10-26-settings-simulator-checks.md`](log/2026-10-26-settings-simulator-checks.md#steps-and-result-criteria)):
dwell on Settings and keep looking at the same spot through Settings'
first screen, Family Setup and the first step, on the iPad in both
orientations and the iPhone, then the iPhone at AX5 with Settings'
first screen scrolled. Then two steps it does not have:

1. Leave Settings by Back to Talking and keep looking at the same spot
   for ten seconds.
2. Open Family Setup and rest the look on empty space until Settings
   resets itself (after 90 seconds without an activation), then keep
   looking for ten seconds more.

*Passes* when no step lands on anything that speaks, alarms, saves an
answer or closes Settings unasked. The known hazards (a held chain can
save a setup answer; on the phone at AX5 it can close Settings onto a
Home control) are expected to show: record each as FAIL with its
sequence.

## Agent runs on the device

### A1. Brickson's UI tests on the device

*The row on what the real software keyboard covers, and a first look at
everything else on hardware.*

1. **Owner:** *For an agent run*, above.
2. **Agent:** on the Mac, in the checkout, with only `project.yml`'s
   `DEVELOPMENT_TEAM` changed:
   `TEST_RESULTS_DIR=build/TestResults/<device> DESTINATION='platform=iOS,id=<identifier>' scripts/test.sh ui`,
   with `<device>` a folder per device (`iphone`, `ipad`), since the
   script deletes the bundle at its path before each run. With a device,
   the script starts no simulator and lets `xcodebuild` choose the
   device; the result is `build/TestResults/<device>/ui-destination.xcresult`.
   If signing fails because
   the test runner has no profile yet, add `-allowProvisioningUpdates`
   after `ui` (anything after the mode goes to `xcodebuild`).
3. **Agent:** reads the result: how many tests ran, passed and failed,
   each failure's capture, and the `KEYBOARD-PROBE` and `KEYBOARD-BAND`
   lines attached to `KeyboardProbeTests` (AGENTS.md, *Gotchas*).
4. *Passes* when every UI test passes on the device, or each failure is
   explained: a bug, fixed in a pull request with a test, or a test that
   assumed a simulator, fixed to run on both. Keyboard numbers above the
   room `KeyboardAllowance` keeps go into `KeyboardAllowanceTests` and
   raise that shape's reference.
5. **Agent:** records the model, iOS version, the keyboard that showed,
   and whether Apple's accessibility audit ran on the device (Apple's
   pages do not say). Repeats on the other device when it is at hand.

### A2. Launch time (Q7)

1. **Agent:** on the release candidate's commit, profile Brickson with
   Instruments' App Launch template on the oldest device at hand. Apple:
   "During your launch, Instruments gathers a time profile and
   thread-state trace", and launch time is "the time from the user
   tapping the app icon on their Home screen to the app drawing its
   first frame"
   ([Reducing your app's launch time](https://developer.apple.com/documentation/xcode/reducing-your-app-s-launch-time)).
   From Terminal, `xcrun xctrace record` takes `--template`; read
   `xcrun xctrace help record` on the Mac for its launch option and its
   exact device flag. Apple's pages show only `--device-name` and
   `--attach` (WWDC22).
2. **Owner then Agent:** five cold launches. Before each, the owner
   restarts the device and unlocks it, and the agent then launches
   Brickson under App Launch. Apple calls a launch right after the
   device is switched on and unlocked a cold launch, and one after the
   app was force-quit a warm launch. Launches made
   after only ending Brickson are recorded apart, as warm.
3. *Passes* when every cold launch reaches its first frame within 400 ms
   (the goal from Apple's WWDC19 session "Optimizing App Launch"). The
   record keeps the median and the slowest of each kind as the next
   release's baseline.
4. Apple's pages do not say whether Instruments can attach to a
   TestFlight build. If it cannot, the build profiled is the same commit
   in the Release configuration, signed for development, and the record
   says so.

### A3. Hangs (Q5)

1. **Agent:** records a trace with the Hangs instrument on the oldest
   device at hand, its Reporting Threshold (in the Hangs section of the
   recording options) set to Include Brief Unresponsiveness (more than
   100 ms), not the default, Include Microhangs (more than 250 ms). The
   Hangs instrument is
   part of the Time Profiler, CPU Profiler and Hitches templates and
   reports more than 250 ms by default; Apple's Instruments tutorial
   ("Reducing main thread work by doing less") shows four thresholds:
   more than 500 ms, 250 ms (Include Microhangs), 100 ms (Include Brief
   Unresponsiveness) and 33 ms. The current Xcode release's `xcrun
   xctrace record --show-recording-options` prints each instrument's
   options, which is where the names are read from the command line.
2. **Owner:** makes 100 activations while it records, from a list the
   thread gives (phrases from every category, Yes, No, Again, Emergency
   and back, Type, a typed word, Speak, Phrases). A UI test could make
   them instead; none exists yet.
3. *Passes* when no activation keeps the main thread busy for longer
   than 100 ms. Apple: "100 ms is the maximum delay for discrete user
   interaction before a delay becomes noticeable"
   ([Improving app responsiveness](https://developer.apple.com/documentation/xcode/improving-app-responsiveness)).
   If 100 ms cannot be chosen in the Xcode in use, the record names the
   threshold used and this step is UNVERIFIED, not passed.
4. **Owner:** through the whole TestFlight period, keeps the device's
   own Hang Detection on (Settings > Developer > Hang Detection, Hang
   Threshold at its shortest, 250 ms), which works for development and
   TestFlight builds. **Thread:** reads the hang reports, the crash
   reports in Xcode's Crashes organizer, and the crash feedback testers
   send through TestFlight. Every crash and hang found is fixed, with a
   test where one can reproduce it. The rest of Q5 passes when the build
   sent to App Review has none in its own seven days (H1).

### A4. Memory and heat, attached (Q8)

Both runs start from Xcode, and an agent never opens the project in
Xcode (AGENTS.md, *Build and test*); Allocations' marks are made by
clicking, too. So the steps at the Mac are the owner's, with the device
on the cable, and a thread reads what they save.

1. **Owner:** in Terminal, in the Brickson folder, run
   `xcodegen generate` and `open Brickson.xcodeproj`, choose the device
   in Xcode's device menu (docs/GETTING_STARTED.md, *Run it on your own
   iPhone or iPad*), and choose Product > Run. In the Debug navigator,
   show the debug gauges.
2. **Owner:** speak 100 phrases in five sets of 20 while watching the
   memory gauge, then click Energy Impact, whose timeline Apple says
   shows "the device's thermal condition". Save a screenshot of each into
   `private/device-checks/`. *Passes* when memory never enters the
   gauge's yellow region (Apple: "memory use high enough to trigger a
   warning") and the thermal condition never reaches serious, which
   Apple says "reduces performance".
3. **Owner:** stop the run and choose Product > Profile, which makes a
   release build and opens Instruments. Choose the Allocations
   template, click Record, speak 20 phrases, then click Mark Generation;
   five sets, five marks. Click Stop, save the trace with File > Save
   into `private/device-checks/`, and save a screenshot of the
   Generations view there too.
4. **Thread:** reads the screenshots and writes the record. *Passes*
   when generations 2 to 5 show no memory that persists. Any growth
   fails until it is fixed, or until the owner accepts it as a named
   exception in docs/DECISIONS.md.

## Sound (Q4)

All by ear, so all the owner's. Where a step names the log, the
**Owner**, at the Mac with the device on the cable, starts the log
before the step (Console is worked by clicking, so this is the owner's
unless a thread on the Mac can operate its screen): in the Mac's
Console app, select the device in
the Devices list, choose Action > Include Info Messages, click Start in
the toolbar, and search for Brickson's bundle identifier, its log's
subsystem. Afterwards, select the messages, copy them with Command-C,
and paste them into a plain-text file in `private/device-checks/` (or
a thread on the Mac writes the clipboard there with `pbpaste`). The
**Thread** reads that file. Apple's guide does not say whether Console
shows a device's messages from before Start, so a log not streamed
during the step is UNVERIFIED, not a pass. The log never holds a
person's words.

### S1. Silent mode, and after a call

1. **Owner:** turn Silent mode on (the Ring/Silent switch toward the
   back, or hold the Action button where it is set to Silent Mode, or
   Control Center's Silent mode button). Speak a phrase. *Passes* when
   it is heard at the usual level.
2. **Owner:** call the device from the second phone, answer, hang up,
   and speak a phrase at once. *Passes* when it is heard.

### S2. Calls, Siri and alarms, during a phrase and during Get Attention

1. **Owner:** speak a long phrase and, while it speaks, (a) call the
   device from the second phone, (b) start Siri by voice ("Siri" or
   "Hey Siri"; if by a button instead, note which: the side button on
   an iPhone with Face ID, the Home button where there is one, or the
   top button on an iPad, which Apple names for iPads with Touch ID.
   Apple says Siri started by a button answers silently in Silent mode
   on an iPhone, or when an iPad is muted), and (c) let a Clock timer
   set a minute earlier go off. Then
   do the same while Get Attention sounds.
2. *Passes* when each stops the sound, Home shows "Stopped — Again"
   (a phrase) or "Alert stopped" (Get Attention), Again or Get Attention
   brings it back, and **nothing restarts by itself** when the call,
   Siri or the alarm ends.
3. On iOS 26 and on iOS 27. With only one at hand, the record names
   it, the other is UNVERIFIED and the row stays open. The record also
   says whether Silent mode (on an iPad, mute) was on and how Siri was
   started.
4. **Thread:** from the log during (a): whether the system reported the
   cut-off phrase as finished ("A phrase was reported finished before
   its final word"), for the row on how often the 3-second window is
   relied on.
5. **Owner:** speak several phrases to the end, uninterrupted, in the
   default voice, a Personal Voice and each other voice offered.
   **Thread:** for each voice, reads the log for "A phrase was reported
   finished before its final word", for the row on whether a voice
   reports its final word before finishing.

### S3. Locked

1. **Owner:** speak a long phrase and lock the device at once. Then
   start Get Attention and lock it. *Passes* when both carry on.
   (XCTest has no lock button, so this stays the owner's.)

### S4. Headphones and Bluetooth

1. **Owner:** with headphones in, speak a long phrase and unplug them
   (or switch Bluetooth headphones off). *Passes* when speech carries on
   from the speaker or, if it stops, Home shows "Stopped — Again" and
   Again speaks the phrase; note which happened. Then start Get
   Attention and do the same: *passes* when the alarm stops and Home
   says so.
2. **Owner:** start Get Attention and connect Bluetooth headphones,
   then disconnect them, restarting Get Attention after every
   disconnect; five times. *Passes* when the alarm stops only at a
   disconnect, never on connecting or with no change of output.
   **Thread:** reads the log for "The Get
   Attention tone player stopped by itself" or "went quiet without a
   report", which would mean the health check needs a second look.

### S5. Get Attention's tone

1. **Owner:** at the usual volume, start Get Attention, go to the next
   room, and note whether it is heard with the door open and closed;
   then over a Bluetooth speaker. *Passes* when someone in the next room
   would come.
2. **Owner:** while it sounds, speak a phrase. *Passes* when a listener
   across the room understands the words over the tone (its level while
   speaking is 0.32, `AttentionAlertStatus.toneVolumeWhileSpeaking`).
3. **Owner:** chooses the final tone by listening; the record names it
   (Q4: the tone today is a placeholder).

### S6. Volume

1. **Owner:** put Brickson in the background, turn the volume right
   down, and come back. *Passes* when Home shows the low-volume line at
   once ("Volume low"). Then, with that line showing, put Brickson in
   the background, raise the volume well above a fifth, and come back.
   *Passes* when the line is gone at once.
2. **Owner:** with VoiceOver on, repeat step 1, lowering the volume to
   one or two steps above silent (below a fifth, so "Volume low" shows
   and VoiceOver can still be heard), and cut a phrase off with a call.
   *Passes* when VoiceOver announces each once, in full, without moving
   its focus.

## Speed and stamina

### M1. It speaks at once (Q6)

1. **Owner:** turn on a screen recording, then watch it back once to
   check the phrase can be heard in it (Apple does not say whether a
   recording keeps an app's sound; if it does not, touch and hold Screen
   Recording and turn the Microphone on).
2. **Owner:** activate the same phrase tile ten times by touch, waiting
   for each to finish, with the default voice; then choose the Personal
   Voice in Voice Settings and do it ten more times. Send the recording
   to the Mac by AirDrop, into `private/device-checks/`.
3. **Thread:** reads the recording frame by frame on the Mac: for each
   activation, the frame where the press ends and the first sound of the
   phrase. The record says how each was found.
4. *Passes* when, on the iPhone and on the iPad, the default voice's
   median is within half a second; the record gives a median for each
   device and voice. A Personal Voice's median over half a second goes
   to the owner with
   what the app can change and what iOS's own synthesis takes. No later
   release's median may be more than 50 ms slower than the last.

### M2. It opens as it was, with no flash (Q7)

1. **Owner:** close Brickson in the App Switcher (swipe it up), then
   record the screen while opening it from the Home Screen, once in the
   light appearance and once in the dark. **Thread:** steps through the
   frames and confirms the launch screen appears in them; a recording
   without it is UNVERIFIED. *Passes* when, in each appearance, every
   frame before Home matches that appearance's background: no dark frame
   in light, no bright frame in dark.
2. **Owner:** type "test" on Home and put Brickson in the background.
   **Agent:** ends Brickson's process from the Mac with `devicectl` (its
   `device process` commands, read with `devicectl help device process`),
   standing in for the system ending it. **Owner:** opens Brickson.
   *Passes* when it opens on Home with "test" in the message.
3. Launch time is A2.

### M3. A whole day with the screen on (Q8, unplugged)

1. **Owner:** set up the device's Performance Trace: Settings > Developer
   > Performance Trace, turn it on, choose Power Profiler, and switch on
   Brickson; add the Performance Trace control to Control Center. It
   records up to 10 hours, and starts and stops from that control.
   Power Profiler needs iOS or iPadOS 26.
2. **Owner:** unplug the iPad, open Brickson, start the trace, and start
   Guided Access. Use Brickson now and then for eight hours: the first
   four with touch's answer, the last four with Eye Tracking on and its
   answer (end Guided Access to turn Eye Tracking on, then start it
   again; the trace keeps running). Note the battery level every hour.
   A triple-click and the passcode end Guided Access. Then the iPhone,
   for four hours, at touch's answer, without Guided Access: Apple's
   iPhone guide says emergency calls and Crash Detection are not
   available during it.
3. *Passes* when the screen never dims or locks; at the end every
   control works as at the start (speak a phrase, Yes, No, Emergency
   and back, Get Attention and Stop, type and speak); and
   Settings > Privacy & Security > Analytics & Improvements > Analytics
   Data lists no report for Brickson (crash reports start with the
   app's name), and no JetsamEvent report from the session in which
   Brickson's entry has a `reason` key. Every JetsamEvent report lists
   every running process; Apple: "Only the jettisoned process has the
   reason key." **Owner:** shares each JetsamEvent report from the
   session to the Mac by AirDrop; **Thread:** reads them.
4. **Owner:** stop the trace, then share it from Settings > Developer >
   Performance Trace to the Mac by AirDrop. **Thread:** opens it in
   Instruments and records battery used per hour at each setup. Apple
   notes that while the device charges Instruments shows overall system
   power as zero, which is why this run is unplugged.
5. The attached half of Q8 is A4.

### M4. The screen never dims or locks

*The row on a long session (invariant 12).*

1. **Owner:** set Auto-Lock to its shortest (Settings > Display &
   Brightness > Auto-Lock; Apple does not list the choices, so note the
   one used). Open Brickson, set the device down facing away from
   anyone (Apple says Attention Aware Features keep the screen on while
   someone looks at it), and leave it untouched for 15 minutes.
   *Passes* when it never dims or locks. M3 and G3 repeat this over
   hours and under Guided Access.

## Personal Voice

Personal Voice needs a passcode and a device that supports it: Apple's
iOS 27 guide names iPhone 15 Pro models, iPhone 16 models and later, and
its iPadOS 27 guide names iPad mini (A17 Pro and later) and iPads with M1
and later, while Apple's support article 104993 lists iPhone 12 or
later, iPad Air (5th generation) or later, and iPad Pro 11-inch (3rd
generation), 12.9-inch (5th generation) or 13-inch (M4) or later. What
counts is whether the device offers Create a Personal Voice. A voice is
made in Settings > Accessibility > Personal Voice > Create a Personal
Voice, by reading phrases aloud. Apps may ask to use it
only while Allow Apps to Request to Use is on, on the same screen. All
of this is by ear and in the owner's own voice, so all of it is the
owner's, and nothing in that voice is kept in the repository.

### P1. D1, and iOS's question over Voice Settings

*The two D1 rows (docs/DECISIONS.md, "Personal Voice permission is
asked at launch, for now", and "Asking for Personal Voice from Voice
Settings").*

1. **Owner:** run Brickson from Xcode with `--personal-voice=ask-from-settings`
   added in Product > Scheme > Edit Scheme > Run > Arguments, on a
   device where Brickson has never been answered. If it has been, delete
   Brickson first; that erases its library, so only on a device that
   holds nothing but the starter library.
2. **Owner:** speak a phrase; then in Voice Settings choose Ask to Use
   Personal Voice. Wait more than 90 seconds before answering iOS's
   question. *Passes* when the question appears over Voice Settings,
   Voice Settings is still there after the wait, and after Allow or
   Don't Allow the card shows the answer, "Answered. …" sits where the
   button was, nothing below the card moved, and Open Personal Voice
   Settings appears only after leaving Voice Settings and coming back.
3. **Owner:** after Allow, speak a phrase. Note whether it is in the
   Personal Voice at once, only after the voice list refreshes, only
   after leaving and reopening Voice Settings, or only after Brickson is
   opened again. That answer is what the row decides.

### P2. D4, access turned off while Brickson waits

1. **Owner:** with Brickson allowed and speaking in the Personal Voice,
   put it in the background and turn its access off in the Settings
   app. Brickson's own guide points to a list of apps under Settings >
   Accessibility > Personal Voice > Allow Apps to Request to Use; Apple's
   iPhone and iPad guides do not describe one, so note the path that
   worked (and, if the guide is wrong, it is a G1 finding).
2. *Passes* when, back in Brickson, a phrase speaks in another voice,
   and turning access back on brings the Personal Voice back.

### P3. Restart, then open at once

1. **Owner:** with the Personal Voice allowed and in use (as P2 leaves
   it), or else a voice chosen in Voice Settings that clearly differs
   from the system's default (note which), restart the device, unlock
   it, open Brickson at once and activate a phrase straight away. *Passes* when Home appears without
   waiting and the phrase speaks at once (in the system's voice if the
   voice list has not arrived).
2. **Owner:** keep activating a phrase every few seconds. Note how long
   until it speaks in the chosen voice or the Personal Voice, and
   whether that first phrase itself waits.

### P4. D5, two Personal Voices

1. **Owner:** with two Personal Voices made and one chosen in Voice
   Settings, relaunch Brickson, restore the device from a backup if one
   is planned anyway, and turn on Share Across Devices (same screen; it
   keeps a copy in iCloud). After each, note whether Brickson still
   chose the same voice. Until a restore is done, that part is
   UNVERIFIED and the row stays open.
2. **Thread:** a debug build's log prints the order of the system's
   voice list with each Personal Voice's identifier, and that order is
   the system's (Voice Settings sorts them by name); none logs them
   today, so this step adds one first. This row is the last to run: it
   needs a second voice, made by reading phrases aloud and processed on
   the device (Apple's iOS 26 feature list says under a minute from 10
   phrases on devices with Apple Intelligence). Note how long it took.

### P5. Chosen once allowed, and on after locking

1. **Owner:** on the shipping build, on a device where Brickson has
   never been answered (delete it first if it has, only where it holds
   nothing but the starter library), allow Personal Voice when iOS asks
   at first launch. *Passes* when the Personal Voice is listed in Voice
   Settings, Automatic chooses it, a phrase speaks in it, and a long
   phrase carries on after the device locks.

## Every input method (Q14)

Apple's test, applied to every input method: "A user can perform all
tasks within your app using only Switch Control." The tasks are
docs/APP-STORE.md, section 4's common tasks. Each method below runs the
**task list**: speak a phrase from every category; Yes; No; Again;
Emergency and back; Get Attention and Stop; Type, type "test",
Speak, Clear, Put Back, Phrases; open Settings, Family Setup, Voice
Settings and Privacy Policy (and close it), and leave by Back to
Talking. First launch, with iOS's Personal Voice question, is a common
task too, but it needs Brickson deleted first, which erases its
library: each method does it once, on a device that holds only the
starter library, and where that cannot be done it is UNVERIFIED for
that method. Home's documented order is Yes,
No, Emergency, Get Attention, Again, then the message, Phrases and Type,
Stop while it shows, the categories and Settings, then the phrases
(docs/DECISIONS.md, "Home's scan order and names").

### I1. Touch, slowly

*The row on a slow press and a slide (docs/DECISIONS.md, "Show Borders
and the Large Content Viewer on Home").*

1. **Owner:** at an accessibility text size, on the shipping build,
   follow the row's steps in docs/HANDOFF.md, *Checks that need a real
   device*, in order: press Yes for about half a second and lift, then a
   phrase tile; hold Yes, slide onto No and lift; hold a phrase tile,
   slide onto the next and lift; then the same with Touch Accommodations'
   Hold Duration on, and with AssistiveTouch Dwell. Then, in a window
   where Settings shows its gear alone, the gear steps the row lists.
   **Thread:** names that window first, from A1's frames or the layout
   engine (for example an iPad window narrowed in Stage Manager, or a
   375-point-wide phone with Bold Text); if none is at hand, the gear
   steps are UNVERIFIED.
2. *Passes* when each press speaks, a slide says the control it began on
   or nothing, never the next, and a held press on the gear opens
   Settings or does nothing, never anything else. Record whether
   Settings opened on the held press and whether the large copy showed.
3. **Owner:** the task list by touch, on the iPhone and the iPad.
   *Passes* when every task is done and each control does what its
   words say.

### I2. Voice Control

1. **Owner:** Flexible Item Names off (iOS 27). "Show names" on Home in
   each state: *passes* when each name shown is the control's visible
   words. "Show numbers": every control has one.
2. **Owner:** the task list by "Tap" and each control's visible words,
   then the other names: "Tap Repeat" (Again), "Tap Help" (Get
   Attention) and "Tap Stop Alert" (Stop). *Passes* when each does what
   its words say.
3. **Owner:** "Tap Type", dictate a word into the message, "Tap Speak".
4. **Owner:** in the Library, add the phrases "Help" and "Yes" to a
   category, and read the note under Save. On Home, with that category
   showing, "Tap Help", "Tap Yes" and "Tap Get Attention"; do all three
   with Flexible Item Names off, then on. Then "Tap Type" and say "Tap
   Help" and "Tap Yes" again, with the tiles dimmed. Note each time what
   Voice Control did, how many commands it took and which control it
   pressed. Delete the phrases. *Passes* when Voice Control asks which
   one is meant, or the note's words are changed to say what it does
   instead (docs/DECISIONS.md, "Phrases named like Home's controls"),
   and "Tap Get Attention" sounds the alarm at once. The counts go to
   the owner with that decision's exception to invariant 10.

### I3. Full Keyboard Access

1. **Owner:** from each Home state, press Tab and note the order, and
   whether focus stops on the message or the status line. *Passes* when
   the controls' order matches the documented order (judged on the
   controls only), and Space activates.
2. **Owner:** the task list from the keyboard.

### I4. VoiceOver

1. **Owner:** from each Home state, swipe right from the top and note
   the order, what each control says, what each region says on entering
   it, and whether the cursor stops on the message or the status line.
   *Passes* when the order matches and every control says its visible
   words.
2. **Owner:** the task list with VoiceOver gestures. This is Q23's
   VoiceOver run too, on the iPhone and the iPad.
3. **Agent:** `XCUIVoiceOverService` (iOS 27) can walk VoiceOver's order
   and record what it says from a UI test; Apple's pages do not say
   whether it runs on a device. A thread that writes that walk tries it
   in A1; until it works there, step 1 is the owner's.
4. **Owner:** with a throwaway build in which phrase tiles carry the
   `startsMediaSession` trait (a thread makes it; it never ships),
   activate a phrase with VoiceOver on, then the same with the shipping
   build. Note whether VoiceOver stays quiet while the phrase speaks,
   with and without the trait.

### I5. Switch Control

1. **Owner:** Auto Scanning, Focused Item After Tap set to start from
   the beginning, and Speech on (Switch Control's own screen: "Speak
   items as they're scanned"). From each Home state
   (browsing, after a phrase, Emergency, typing, Get Attention
   sounding), start scanning, with Group Items off and then on. Note the
   whole scan order, whether the scan stops on the message or the status
   line, and what is said on entering each group. *Passes* when Yes, No
   and Emergency come first (the first three items, or the first group
   offered) and the controls follow the documented order. Note whether
   Home's regions become groups.
2. **Owner:** with Tap Behavior's Auto Tap on, the task list. Note where
   the scan goes after Stop disappears.
3. **Owner:** set Focused Item After Tap to resume at the item tapped,
   keep Auto Tap on and Ignore Repeat off, and note the settings. Select a long phrase and, once it is
   tapped, select it again while it speaks. A second press within Auto
   Tap's wait opens the Scanner menu instead (Apple), so wait for the
   tap first. *Passes* when it does not stutter and the **Thread** finds
   "Absorbed repeat activation of the phrase still being spoken" in the
   log, streamed as *Sound (Q4)* describes; with no such line, the trial
   is UNVERIFIED.
4. **Owner:** the task list with Gliding Cursor (point scanning).
5. A Mac's own Switch Control can control the iPhone or iPad on the same
   Wi-Fi and Apple Account (Apple: "Use Other Devices"), which lets the
   owner run Switch Control steps from the Mac's keyboard. It is still
   the owner's input.

### I6. Dwell, Head Tracking and Eye Tracking reach every control

1. **Owner:** the task list with Eye Tracking and Dwell with Snap to
   Item, with Head Tracking and Dwell, and with AssistiveTouch Dwell.
   *Passes* when every control on every screen is reached and does what
   its words say.
2. **Owner:** Get Attention from Home's own control, by touch, Dwell
   with Snap to Item, Switch Control and Voice Control ("Tap Help"):
   *passes* when it sounds with Silent mode on; a look held on Get
   Attention never stops it; and a look still resting where Stop
   was after Stop meets a category (F2 step 2 measures it).
3. **Agent then Owner:** which of the VoiceOver, Switch Control and
   AssistiveTouch flags each input method turns on. A thread writes an
   opt-in probe UI test that reports the system's flags (the test
   runner can read them; not yet tried); the owner turns each input
   method on and the agent runs the probe. If XCTest cannot run with a
   method on, a debug-only readout in the app is the fallback.

### I7. The long sessions (Q11)

*The row on two hours with each input method.*

1. **Owner:** on the mounted iPad, at least two hours each with Eye
   Tracking and Dwell with Snap to Item, Head Tracking with Dwell,
   Switch Control's Auto Scanning, and its Gliding Cursor; on the
   iPhone, at least half an hour each with Switch Control and Eye
   Tracking. Each follows Q11's script: speak from every category; type
   and speak a message; answer Yes and No; open Emergency and come
   back; start and stop Get Attention; open and leave Settings; and rest
   on the message and on empty space for five minutes at a time, as a
   person reads. Once a build has the rest board, it gets a session of
   its own.
2. **Owner:** records every activation not meant, where the pointer
   rested before it and what it met; how many activations each common
   task took; and every recalibration or rest needed. A screen
   recording makes this easier to count afterwards.
3. *Passes* when no reading, resting or held look starts anything that
   speaks, alarms, changes data or moves things, apart from exceptions
   the owner accepted under Q2 (the record says how often each
   happened); every other unmeant activation is removed by placement or
   accepted by name; and no common task takes more activations than in
   the last release (R0's counts are the first baseline). The testers
   run it next.

### I8. Typing and the keyboard

*The rows on what the real keyboard covers, typing on Home by each
method, and typing checks 1 to 8 in
[`log/2026-10-21-typing-foundation.md`](log/2026-10-21-typing-foundation.md).*

1. **Agent:** A1's keyboard probe gives the real keyboard's numbers.
2. **Owner:** for touch, Switch Control, Voice Control ("Tap Type"), Full
   Keyboard Access and Dwell with Snap to Item: Type brings the cursor
   and Apple's keyboard at once; Speak and Return say the message;
   Clear, then Put Back; Phrases puts the keyboard away and keeps the
   message; a look slipping off the keyboard's top row meets nothing
   that speaks or changes the message; and Snap to Item stops on the
   dimmed phrases and categories while typing. *Passes* when each is
   so.
3. **Owner:** where a third-party keyboard is installed, choose it as
   the keyboard and open Type. *Passes* when Apple's keyboard appears
   instead.
4. **Owner:** on an iPhone SE with Display Zoom (Settings > Appearance >
   Display Zoom on iOS 27; Settings > Display & Brightness > Display
   Zoom on iOS 26), and at AX3 without it, where Type is dimmed: note
   whether the real keyboard would cover Speak or Get Attention (open
   Notes' keyboard at the same text size and compare).
5. **Owner:** typing checks 1 to 8, as that record lists them; check 3,
   the Apple-keyboard halves of checks 1 and 4, and the floating-keyboard
   part of check 6 need no Brickson build (Notes or Live Speech). Check 7
   needs Settings > Accessibility > Audio & Visual > Add Audio in Calls.
   **Thread:** makes the throwaway builds checks 2, 4 and 8 need, as
   that record describes them; they never ship.
6. **Owner then Agent:** with another keyboard added and made current,
   one with a candidate bar (Japanese or Chinese), open Type in each
   orientation, or run A1's keyboard probe with it. **Thread:** records
   the keyboard's top against the room `KeyboardAllowance` keeps. Until
   this is done, keyboards in other languages stay unmeasured and the
   row stays open.

## Windows and poses (Q10)

### W1. Every window

1. **Owner:** on the iPad, each of Settings > Multitasking & Gestures'
   Full Screen Apps, Windowed Apps (alone and beside another app) and
   Stage Manager; Slide Over (iPadOS 26.2 or later: touch and hold the
   window controls, then Enter Slide Over); resize each window by its
   bottom-right corner slowly from its narrowest to its widest, stopping
   at every width where Home's arrangement or column count changes;
   turn the device. On the iPhone, Display Zoom on and off. In each, the
   keyboard shown and hidden.
2. *Passes* when, at every width the window allows, nothing that calls
   for help (Yes, No, Emergency, Get Attention and Again, and while
   typing Speak and Phrases) is hidden, covered or split, and no control
   moves between states. A width that fails is a FAIL, not a limit to
   record.

### W2. A resize under a resting pointer

1. **Owner:** Stage Manager, Eye Tracking, then AssistiveTouch Dwell,
   each with Snap to Item. Drag the window's bottom-right corner across
   the width where Home changes between three and five columns. Note where the pointer
   is during and after, whether it stays or follows the look, and what it
   would activate when it comes to rest.
2. *Recorded when* both methods have a result; a thread decides from it
   whether the chain engine needs a surface for changing windows.

### W3. A folding iPhone

1. **Owner:** only with a folding iPhone at hand. Open, partially folded
   and closed, and in Stage Manager, Slide Over and iPhone Mirroring
   windows. Apple says Eye Tracking and Head Tracking work only fully
   open, and the part of the inner display where the camera sits goes
   dark while either is on.
2. *Passes* when nothing safety-critical is hidden or split, nothing a
   person uses sits in the fold, Dwell keeps working as it folds and
   unfolds, Eye Tracking and Head Tracking come back when it opens fully
   with nothing moved, and the inner camera's reserved region covers
   the dark part. Also Q2's iPhone Duo items (docs/DECISIONS.md, "iPhone
   Duo").

### W4. An external display

1. **Owner:** connect the iPad to an external display and try Eye
   Tracking and Dwell there. Apple's pages say nothing about either on
   an external display. *Recorded when* the result says whether the
   gaze profiles hold off the built-in screen.

## Apple's doors

### G1. Family Setup's guides match the device

1. **Owner:** on iOS 26 and iOS 27, iPhone and iPad, follow each Family
   Setup guide's steps exactly as written, and Live Speech's on an Apple
   Watch (watchOS 10 or later: the Watch's Settings app > Accessibility
   > Live Speech). *Passes* when every path and name matches the
   device. Note every difference word for word.

### G2. The buttons that open Settings

1. **Owner:** Open Personal Voice Settings is in Brickson's Settings >
   Family Setup > Voice Settings, and shows only while Brickson's
   Personal Voice access is off (after Don't Allow, or with access
   turned off as in P2 step 1), outside Assistive Access, and not on
   the visit in which Ask to Use Personal Voice was chosen. Open Dwell
   Control Settings is in Family Setup > Reaching the Screen, under Eye
   Tracking and under Head Tracking. Choose each of the three. *Passes*
   when the first opens Personal Voice's page and the others open Dwell
   Control's, in the Settings app.
2. **Agent:** a small UI test could tap each and read the Settings app's
   screen; not tried. Until it is, this is the owner's.

### G3. Guided Access

1. **Owner:** Settings > Accessibility > Guided Access, turn it on, set
   a passcode (Passcode Settings), turn on Accessibility Shortcut there,
   and set Display Auto-Lock (on the same screen) to its shortest. Start
   it in Brickson with a triple-click (Session Settings: leave Touch
   on). Apple's iPhone guide: emergency calls and Crash Detection are
   not available during Guided Access.
2. **Owner:** with each input method in turn (Eye Tracking first),
   run the task list.
3. **Owner:** in a session with Display Auto-Lock at its shortest, set
   the device down facing away from anyone and leave it untouched for
   15 minutes, as in M4.
4. *Passes* when each input method works throughout, the screen never
   dims or locks during step 3's wait while Brickson keeps it awake
   despite the short Display Auto-Lock, and a triple-click and the
   passcode end the session.

### G4. Assistive Access

1. **Owner:** Settings > Accessibility > Assistive Access > Set Up
   Assistive Access, add Brickson. Brickson declares
   `UISupportsFullScreenInAssistiveAccess`, which lets its window
   "expand into all the available space above the Back button" (Apple).
2. **Owner:** Start Assistive Access. Note Brickson's window size (all
   the space above Back?), run the task list with Eye Tracking and with
   Switch Control, and open the guides.
3. *Passes* when the window fills the space above Back, both methods
   work, and the guides show no Open … Settings button and say to leave
   Assistive Access first. Leave by triple-click, Exit Assistive Access
   and its own passcode.

### G5. "Open Brickson"

1. **Owner:** ask a few people to say "Open Brickson" to Siri and to
   Voice Control, and note what each heard; with VoiceOver, note how it
   reads the icon. *Recorded when* the results say whether
   `APP_SPOKEN_NAME` and the other names need to change.

## Look

### L1. Contrast on the rendered pixels

1. **Owner:** take screenshots of Home, Settings and Family Setup, light
   and dark, with Increase Contrast and Reduce Transparency each on and
   off (Settings > Accessibility > Display & Text Size), and with Bold
   Text, Increase Contrast and Reduce Transparency all on. Send them to
   the Mac.
2. **Thread:** measures each control's words and edge on the pixels.
   *Passes* when words are at least 4.5:1 and edges at least 3:1
   (invariant 6), system components included.

### L2. Show Borders

1. **Owner:** Settings > Accessibility > Display & Text Size > Show
   Borders. Screenshots of Home, Settings, and Family Setup with its
   steps, with it on, light and dark, with and without Increase
   Contrast, and off in dark; one with a button held down; one with a
   category selected and one in Emergency.
2. **Thread:** measures them. *Passes* when every Home control shows its
   border, a press thickens it, a selected category and Emergency show
   their inner ring, and Settings' system buttons show theirs.

### L3. Every label earned (Q23)

1. **Owner:** the VoiceOver run (I4) and the Voice Control run (I2) of
   every common task, on the iPhone and the iPad, logged. The VoiceOver
   run is by someone proficient with VoiceOver (the owner if so,
   otherwise a proficient tester), and the record says who, by role.
2. **Owner:** Settings > Accessibility > Display & Text Size > Color
   Filters, on, Grayscale; walk every screen. *Passes* when nothing is
   told by colour alone.
3. **Thread:** the rest of Q23 (labels read back from captures at AX3
   and AX5, colour pairs, dark and motion) from CI's captures.

### L4. The owner's eye (Q21)

1. **Owner:** every screen on both devices, light and dark, at the
   default and largest text sizes. Mark each "designed", or write down
   what feels assembled. *Passes* when every screen is marked designed.

## People, and the owner's answers

### H1. The owner lives with it (Q9)

1. **Owner:** keep the internal TestFlight build on the iPhone and iPad
   and use it every day for at least two weeks before the external
   pilot, with a dated list of anything slow, surprising, cramped or
   unclear. **Thread:** fixes, schedules or dismisses each with a
   reason.
2. **Owner:** the exact build sent to App Review (uploaded as an
   ordinary build) on both devices for at least seven days, with nothing
   new on the list. *Passes* then.

### H2. The first five minutes (Q25)

1. **Owner:** three people who have never seen Brickson, given no help:
   time each to speak a phrase (within a minute), find Emergency, and
   find where setup lives; a family member finishes Family Setup's first
   step without asking. Note every hesitation and where. No names in the
   record. The people are found before the external pilot.
2. *Passes* when each of at least three people speaks a phrase within a
   minute, finds Emergency and finds where setup lives, and the family
   member finishes the first step without asking. The testers' first
   sessions are a further check, not the pass.

### H3. Better than what families use (Q28)

1. **Thread and Owner:** count activations and time for each common
   task by touch, Switch Control and Eye Tracking, in Brickson and in
   the leading AAC apps the owner can try (docs/ASO.md, *Competitors*).
   *Passes* when Brickson takes no more on every task both have, or the
   owner accepts the difference with its reason, and the record says
   where Brickson is better.

### H4. The phrases people reach for

1. **Testers:** during the pilot, which phrases people reach for, and how
   many categories a person can scan by eye. *Recorded when* the
   starter library's review has the answers.

### H5. The owner's written answers

The gates the owner answers in words, not on a device. A thread brings
each, once, with what it measured; the owner's answer goes in
docs/DECISIONS.md.

- **Q2:** each dwell hazard placement does not remove (F2 step 4).
- **Q3:** Settings' floors under the larger profiles, once a thread has
  measured them.
- **Q15:** the Figma frames.
- **Q16** and **Q19:** the screen-by-screen guideline pass and the
  String Catalog, after a thread's pass; the starter phrases.
- **Q20:** the icon's artwork.
- **Q24:** the open owner questions the release touches.

### H6. Would I recommend this to someone? (Q29)

1. **Owner:** last, for the build that will go to App Review: answer
   yes in writing. The release's `docs/log/` record keeps the answer.

## The Library (R0 item 6)

### B1. A backup leaves and comes back

*The row on exporting and restoring a backup; docs/DECISIONS.md,
"Exporting and restoring a backup".*

1. **Owner:** on the iPhone, Settings > Family Setup > Phrases and
   Categories > Export a Backup. *Passes* when the share sheet opens with
   one file, "Brickson Phrases" and the day, ".json", and each of these
   delivers it: Save to Files (On My iPhone), Save to Files (iCloud
   Drive), AirDrop to the iPad, and Mail to yourself.
2. **Owner:** on the iPad, add a phrase of your own first, then Restore
   from a Backup, and choose the iPhone's file from iCloud Drive, then
   the AirDropped copy from the Files app. *Passes* when the question
   says what the backup holds, Replace My Phrases is dimmed with its
   reason (it would remove the phrase you added), and Add to My Phrases
   adds what the iPad did not have, then dims, with Done in Cancel's
   place.
3. **Owner:** Restore from a Backup, and choose a `.json` file that is
   not a Brickson backup. *Passes* when the line under the row says why,
   ending "Nothing was changed.", and the library is as it was.
4. **Owner:** open Export a Backup and leave the share sheet open for
   more than 90 seconds, then close it. Note what shows: Settings'
   first screen behind the sheet is expected (the share sheet cannot
   hold the idle reset). *Passes* when nothing in the library changed.

Write down the device, iOS version, where each file went and what each
step showed.

### B2. Editing with each input method

*The row on editing with each input method; docs/DECISIONS.md, "The
Library's question screens" and "Four phrases in every category".*

1. **Owner:** with Voice Control, then Switch Control, then Full
   Keyboard Access, then AssistiveTouch Dwell with Snap to Item: add a
   phrase to a category, change its words, move it, delete it; delete an
   everyday category so that three remain (Add a Category is dimmed
   while there are four; restore it from B1's backup afterwards); add a
   category, give it a picture (with Voice Control, say the picture's
   name, such as "Tap Heart"), rename it, delete it. *Passes* when every
   control is reached and named, and each way back (Keep, Leave It Here,
   Keep This Picture, Cancel) appears where the row that asked was.
2. **Owner:** with Dwell and Snap to Item, open Delete Phrase and hold
   the look on Delete for Good until it deletes, then keep holding.
   *Passes* when Delete for Good dims in place, nothing else is
   activated, and Done returns to the category. Do the same with the look
   resting just under Edit Phrase's Delete Phrase row and under the
   Library's Restore from a Backup: *passes* when only their questions
   open, never a choice in them.
3. **Owner:** make a category with one phrase; its screen says Home
   shows it once it has four, and to add 3 more. On Home its button is
   dimmed. With Dwell and Snap to Item, rest the look on that dimmed
   button, first while browsing, then after Type. Record which control
   Snap to Item outlines and whether anything activates. *Passes* when
   nothing activates. If Snap to Item skips the dimmed button and selects
   a neighbour, record which: Home's dimming here and while typing
   assumes it stops on a dimmed control (docs/DECISIONS.md, "Four phrases
   in every category"), and the record goes to F2's owner question.

## Coverage

Every row of docs/HANDOFF.md, *Checks that need a real device*, by its
first words:

| Row | Procedure |
|---|---|
| Speech plays with the silent switch on, and after a phone call | S1 |
| A phrase cut off by a call shows "Stopped, Again" | S2 |
| D1: with no question at launch | P1 |
| In the same run: iOS's question appears over Voice Settings | P1 |
| D4: Personal Voice access turned off | P2 |
| Restart the device, then open Brickson at once | P3 |
| D5: with two Personal Voices | P4 |
| Personal Voice appears and is chosen once permission is given | P5 |
| Opening Settings by a stray dwell | F4 |
| Each Family Setup guide's steps match the device | G1, G3, G4 |
| Open Personal Voice Settings and Open Dwell Control Settings | G2 |
| Each input method reaches every control | I1 to I6 |
| A Switch Control double activation | I5 |
| How far Snap to Item jumps | F1 |
| Whether Snap to Item and Dwell pick a target by its nearest centre or its nearest edge | F1, F2 |
| Whether a lingering look re-fires a dwell | F1 |
| Whether Snap to Item ignores controls scrolled off screen, or wholly under the navigation bar | F1 |
| What the real software keyboard covers | A1, I8 |
| Typing on Home by touch, Switch Control | I8 |
| Get Attention heard from the next room | S5 |
| A phrase spoken while Get Attention sounds | S5 |
| A phone call, Siri and another app's alarm | S2 |
| Lock the device during a long phrase | S3 |
| Get Attention from Home's own control | I6, I5, F2 |
| Whether a voice reports its final word before finishing | S2 |
| Unplugging headphones | S4 |
| Whether the tone player ever reads as not playing | S4 |
| Comfortable dwell time and movement tolerance | F1 |
| Each profile's floors on an iPad | F3 |
| Whether Guided Access works together with Eye Tracking | G3 |
| Which phrases people reach for | H4 |
| "Open Brickson" by Siri and Voice Control | G5 |
| With VoiceOver on, a cut-off phrase or very low volume | S6 |
| A volume change made while Brickson was in the background | S6 |
| Buttons under Increase Contrast and Reduce Transparency | L1 |
| The screen never dims or locks during a long session | M4, M3, G3 |
| On a folding iPhone | W3 |
| On an iPad with Brickson in a window you can resize | W2 |
| Eye Tracking and Dwell on an external display | W4 |
| Switch Control with Auto Scanning | I5 |
| With VoiceOver, Switch Control (item and group scanning) and Full Keyboard Access | I2 to I5 |
| With VoiceOver on, a phrase tile with and without the `startsMediaSession` trait | I4 |
| Brickson inside Assistive Access | G4 |
| Guided Access with each input method | G3 |
| Which of the VoiceOver, Switch Control and AssistiveTouch flags | I6 |
| With a real finger at an accessibility text size | I1 |
| Show Borders on, in light and dark | L2 |
| In the build that ships: the time from an activation completing | M1 |
| A cold launch's time to first frame | A2, M2 |
| 100 activations with the Hangs instrument | A3 |
| Eight hours on the iPad | M3, A4 |
| Two hours each on the mounted iPad | I7 |
| Export a Backup to Files, iCloud Drive, AirDrop and Mail | B1 |
| With phrases saved as "Help" and "Yes": what Voice Control does | I2 |
| Editing phrases and categories with Voice Control | B2 |

Every gate of docs/ROADMAP.md, *The quality bar*, that the owner checks
or answers:

| Gate | Procedure |
|---|---|
| Q2 No open dwell hazard | F1, F2, H5 |
| Q3 Every floor named | H5 (a thread measures) |
| Q4 Every device check, sound first | S1 to S6, then every row above |
| Q5 No crash and no hang | A3 |
| Q6 It speaks at once | M1 |
| Q7 It opens fast and comes back as it was | A2, M2 |
| Q8 A whole day with the screen on | M3, A4 |
| Q9 The owner lives with it | H1 |
| Q10 Every window and every pose | W1 to W3 |
| Q11 A long session with each input method | I7 |
| Q12 Snap to Item and Dwell, measured | F1 |
| Q13 The floors are comfortable | F3 |
| Q14 Every input method gets the same app | I1 to I6 |
| Q15, Q16, Q19, Q20, Q24 | H5 |
| Q21 The owner's eye | L4 |
| Q23 Every label earned | L3, I2, I4 |
| Q25 The first five minutes | H2 |
| Q28 Better than what families use today | H3 |
| Q29 "Would I recommend this to someone?" | H6 |

A pull request that adds or changes a device check or an owner gate
edits its procedure here in the same pull request.
