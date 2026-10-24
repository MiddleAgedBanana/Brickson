# Roadmap

What Brickson builds, in what order, and who is building each part. It is
led by what a person living with ALS needs at each stage of the disease,
not by the order of the reference app's files ([`docs/PORTING.md`](PORTING.md)
stays the checklist of what can be reused).

**Status: decided on 2026-10-21, by default.** The releases and their
order come from the research sweep of 2026-10-15
([`docs/recon/2026-10-15/README.md`](recon/2026-10-15/README.md), sections
5 to 7). The owner asked that day to focus on building and leave the
logistics to the project, so they stand unless the owner objects; the few
questions that are the owner's are in [`docs/DECISIONS.md`](DECISIONS.md),
*Waiting on the owner*. Each pull request that starts, lands or moves an
item edits its row here, in place.

## The goal

In the owner's words (2026-10-21): the best option on the App Store for
people with ALS, in every aspect; a highly polished iPhone and iPad app,
ready for the App Store and meeting or exceeding its optimization (ASO)
requirements; using Apple's capabilities and accessibility features so a
person can live as normally as possible as ALS takes more of their
movement; always built with the Xcode Apple currently recommends; and
interfaces built around the space available and the system's own layouts,
with standard SwiftUI containers, never screens made for one device.

Every item below is judged by AGENTS.md's question: does this make
communication faster, clearer or more reliable for the person, on the
input method they actually use?

## Where this goes

*The owner's vision, 2026-10-22.* Over time, Brickson becomes **the one
app a person with ALS keeps open all day** on their iPad or iPhone. It
functionally takes the place of the operating system for them, the way
the leading ALS apps on Windows do. It does not replace iOS, which no app
can: it covers, inside Brickson, everything the person and their
caregivers need, and reaches the rest through Apple's own doors. In the
owner's words, for a person with ALS "it's the only app they need and is
something they just keep on at all times on their iPad."

What that asks of the work:

- **Every stage of the disease.** Speaking, getting attention, typing,
  routines and alarms come first; later the web, the camera, calls and
  messages, on-device AI, and a way for people to extend the app. Each is
  usable with touch, Switch Control, Eye Tracking, a head pointer and
  dwell, and keeps its place as the person moves from one to the next
  (AGENTS.md, invariant 8).
- **Apple's doors, not workarounds.** Guided Access and Assistive Access
  keep the device on Brickson, started by the family: Brickson never
  takes over the device itself (docs/DECISIONS.md, "Accessibility API
  coverage"). App Intents and Shortcuts are the way to extend it. Live
  Caption, Personal Voice, Switch Control and Eye Tracking are its input
  and voice. Where iOS keeps an action for itself, such as sending a text
  or placing a call, Brickson fills it in and hands it to the system; it
  never fakes one.
- **Apple's current frameworks first**, so the app grows on what Apple is
  building next rather than on what it is leaving behind (AGENTS.md,
  *Apple's current frameworks first*).
- **Fully native.** Apple's Human Interface Guidelines, Liquid Glass and
  Apple's accessibility documentation set the standard. Layouts come from
  the space available, with standard SwiftUI containers, never screens
  made for one device (AGENTS.md, *Layout on every device and window*).

**Direction, not a licence to skip steps.** The releases below are how
Brickson gets there, one step at a time, in the order a person meets the
disease. Nothing here moves an item ahead of its release or past its
gate, and every invariant in AGENTS.md still holds. Each part of the
vision starts, when a release takes it, with a work file
([`docs/SDLC.md`](SDLC.md)) that checks it against the invariants and the
privacy policy. Some parts meet a rule today, and the owner decides each
before it is planned:

- A web view inside Brickson is network code, which invariant 9 forbids.
  Safari's own in-app view, which the privacy policy's web version
  already uses, may be the door instead.
- On-device AI must never write a person's words for them: invariant 9
  forbids AI-generated replies, invariant 7 forbids words about a
  person's condition in their mouth, and docs/DECISIONS.md, "Accessibility
  API coverage", lists Foundation Models under *Never*. Using it for
  anything else changes that entry first.
- The camera, calls and messages each need a permission, the words the
  system shows when it asks, and a section of the privacy policy.

**Frameworks to explore later.** Named so that they are not forgotten;
none is scheduled, and each starts with a work file when a release takes
it:

- **Foundation Models** (iOS 26): Apple's on-device language model, to
  "perform tasks with models that specialize in language understanding,
  structured output, and tool calling". Today it is under *Never* (above),
  so any use starts with the owner changing that entry.
- **AlarmKit** (iOS 26): "Schedule prominent alarms and countdowns to help
  people manage their time." Not in 1.0, because Get Attention sounds
  inside Brickson (docs/DECISIONS.md, "Accessibility API coverage"); a
  candidate for routines and alarms that must sound when Brickson is not
  in front.
- **Evaluations** (iOS 27): "Measure the quality of your app's
  intelligence-powered features." Only alongside Foundation Models.
- **RelevanceKit** (watchOS 26): "Provide on-device intelligence with
  contextual clues that increase your widget's visibility on Apple Watch."
  For a helper Apple Watch app (*Waiting, not yet in a release*).
- **StateReporting** (iOS 27): "Communicate your app's state to the system
  to improve diagnostic actionability." What it reports, and to whom, is
  checked against the privacy policy and invariant 9 (no analytics)
  first.

Each quote is from the framework's page on developer.apple.com, read on
2026-10-23.

## How the order was chosen

- **In the order a person meets the disease.** People usually start on
  touch, with working hands, while speech slows; then lose speech; then
  move to a switch, their head or their eyes. Brickson's promise is that
  the app they learn early is the app they keep.
- **A device before each step depends on the one before.** Nothing has run
  on a real iPhone or iPad yet, and sound, dwell and Snap to Item cannot be
  judged on a simulator.
- **Foundations before screens.** Each feature lands first as plain,
  tested logic with no screen change, then on screen once the layout that
  holds it is settled.

## Step zero: a device (owner)

Before R0's features are judged, Brickson runs on the owner's own iPhone
and iPad and the owner works through the table in
[`docs/HANDOFF.md`](HANDOFF.md), *Checks that need a real device*. This
needs the Team ID in `project.yml` (`DEVELOPMENT_TEAM`, from the personal
membership the owner chose on 2026-10-10; docs/DECISIONS.md, *App identity*) and, before anything is uploaded, the
final bundle identifier.

## Wave 3: the next pull requests, in order

*Planned 2026-10-23, as Wave 2 (Settings, Get Attention, Stop and Show
Borders on Home; the website's accessibility page; the iPhone Duo plan)
landed. Default: the owner left the order of work to the project, so it
stands unless the owner objects. The record behind it, with the Apple
pages each item rests on and what they say, is
[`log/2026-10-23-wave-3-plan.md`](log/2026-10-23-wave-3-plan.md).*

A wave is the set of pull requests planned together. Wave 3 comes from
R1 "Follows you" and from the first of Apple's doors in *Where this
goes*: Guided Access and Assistive Access, then App Intents and
Shortcuts. It moves nothing past its release. R1's two engines come
first because R0 needs them too: the layout engine is what R0 item 3
still needs, so it finishes R0's Home before it serves R1's profiles,
and the chain engine scores the chains R0 items 4, 7 and 13 must score.
Typing (R0 item 5) and iPhone Duo (R0 item 13) then take their turns on
Home. R1's own changes to what a person sees, the profiles of items 8
and 9, wait until R0's first build has gone to App Review, because R0
leaves stage profiles out on purpose; until then no profile reaches a
screen.
Siri and Shortcuts stay in R2: their work file (item 10) waits for the
owner, because writing it now would start an R2 item ahead of its
release.

**How it runs.**

- **One Home pull request at a time.** Items 4, 5, 6, 8 and 9 change
  Home's code, so they go in that order, each after the one before has
  merged. The others run beside them.
- **R1's profiles after R0's first App Review build.** Items 8 and 9,
  their work file included, start once R0's first build has passed its
  *Release gate* and gone to App Review, so that build carries no stage
  profile (*Left out of R0 on purpose*). Starting them sooner would move
  an R1 item ahead of its release, which is the owner's call.
- **Cloud first.** Every item can be written in a cloud session, with
  GitHub CI as its build. Item 6 also needs the owner's Mac, because
  folding the iPhone Duo simulator needs Xcode's Device Hub, and CI's
  image has no iPhone Duo simulator yet. The device checks each
  item names wait for the owner's own iPhone and iPad (*Step zero*).
- **Design before code.** An item that changes what a person sees starts
  with a work file and the Figma frames docs/SDLC.md asks for in its
  *Design* stage. Item 3's work file covers items 4 and 6; items 8
  and 9 get their own once R0's first build has gone to App Review.
- **Start now:** items 1, 2 and 3, side by side; none touches Home.
  Then item 7 once 2 has merged, and item 4 once 2 and 3 have. Item 10
  waits for the owner's yes.
- **R0 item 13's look comes first.** Brickson in the iPhone Duo
  simulator on the owner's Mac, open, half-folded and rotated, in Split
  View, and whether a second window opens, as
  docs/log/2026-10-23-iphone-duo-readiness.md, *Follow-ups*, item 1,
  lists (the closed phone ran in PR #43). It changes no code, so it does
  not wait for the Home queue, and item 3 may start beside it; what it
  finds goes into item 3's work file before the engine settles how it
  takes a fold.
- **Alongside, not in this list:** R0's own remaining work keeps its
  place: the library's next pull requests (R0 item 6, from the emergency
  repair record's *Follow-ups*), the screens (R0 item 9) and App Store
  readiness (R0 item 10).

| # | Item | From | Home's code | Needs |
|---|---|---|---|---|
| 1 | Apple's doors in Family Setup | R0 item 7 | No | Cloud |
| 2 | One chain engine for dwell safety | R0 items 4, 7 and 13; R1, dwell-safety scoring | No (tests) | Cloud |
| 3 | The layout engine, with no screen change yet | R0 items 3 and 13; R1, the profile layout engine | No | Cloud |
| 4 | Home on the engine: the starter library never scrolls | R0 item 3 | Yes | Cloud |
| 5 | Typing on Home | R0 item 5 | Yes | Cloud |
| 6 | Home on iPhone Duo, in every pose | R0 item 13 | Yes | The owner's Mac |
| 7 | Settings' chains, and Get Attention in Settings | R0 items 4 and 7 | No | Cloud |
| 8 | Sizes that follow how the person reaches the screen | R1, the profile layout engine and who chooses the profile | Yes | Cloud, after R0's first App Review build |
| 9 | The late-stage profile: Yes and No, and the rest board | R1, the profile layout engine | Yes | Cloud, after R0's first App Review build |
| 10 | Siri and Shortcuts, the work file | R2, Siri and Shortcuts | No (documents) | The owner's yes; otherwise R2 |

**1. Apple's doors in Family Setup.** *Built 2026-10-23
([`log/2026-10-23-apples-doors-in-family-setup.md`](log/2026-10-23-apples-doors-in-family-setup.md));
guide headings were already headers.* Brickson fills the screen inside
Assistive Access, and Family Setup explains each Apple feature that R0
item 7 lists and it does not explain yet. Declare
`UISupportsFullScreenInAssistiveAccess`, so that inside Assistive Access
Brickson keeps its own layout in all the space the system gives it
rather than a smaller frame; `AppBundleTests` pins it, and pins that
`UISupportsAssistiveAccess` stays absent (docs/DECISIONS.md,
"Accessibility API coverage"). Inside Assistive Access, the guides show
written Settings paths where they now show Open … Settings buttons. New
guides, each step checked against Apple's user guides on the day: Vocal
Shortcuts, Listen for Atypical Speech, Live Speech (also on Apple
Watch), Touch Accommodations, Switch Control's timing and switch
sources, external eye trackers (iPad only), the Accessibility Shortcut,
Zoom, Share Accessibility Settings, Auto-Lock with Guided Access's own
Display Auto-Lock, and the Action button (iPhone only). Guide headings
become headers, and every guide, Set Up Step by Step and About get an
accessibility audit.
*Rows in docs/ACCESSIBILITY.md:* section 7's
`UISupportsFullScreenInAssistiveAccess`, `AssistiveAccess` scene and
`accessibilityAssistiveAccessEnabled`; every row whose plan says "Setup
text: R0-7"; section 5's traits; section 9's audit. *Needs:* cloud and
CI; afterwards, the device checks for Assistive Access and Guided Access
already in docs/HANDOFF.md. *Apple:*
[`UISupportsFullScreenInAssistiveAccess`](https://developer.apple.com/documentation/bundleresources/information-property-list/uisupportsfullscreeninassistiveaccess),
[Optimizing your app for Assistive Access](https://developer.apple.com/documentation/accessibility/optimizing-your-app-for-assistive-access),
[`accessibilityAssistiveAccessEnabled`](https://developer.apple.com/documentation/swiftui/environmentvalues/accessibilityassistiveaccessenabled),
and Apple's iPhone and iPad User Guides for the guides' words.

**2. One chain engine for dwell safety.** *Built 2026-10-23
([`log/2026-10-23-chain-engine.md`](log/2026-10-23-chain-engine.md)):
Home's states find only the known hazard at the top of Stop's well;
Settings' first screens find two, a held look saving a setup answer and
Settings closing under the look, for items 7 and 4 to fix
(docs/DECISIONS.md, "One chain engine for dwell safety").* One tested type that takes a
screen's controls in each state, with what each one does (speaks,
alarms, changes data, moves things, only navigates, nothing), and
follows chains of several held activations from every start: the
pointer staying on the control or going back to the look, the nearest
control by centre and by edge, ties counted (docs/LESSONS.md, "Score
chains, not single hops" and "One chain engine, not five scripts"). The
nearest-control helpers then in `HomeShapeTests` (now
`HomeLayoutEngineTests`) and the UI tests' `ScreenControls` move onto it. It scores Home in every state and the
chains through Settings that docs/HANDOFF.md lists under *Known gaps*,
and records what it finds; items 4 and 7 make the fixes. R0 needs it
already: Get Attention in Settings waits for its chain's score (R0
items 4 and 7), and R0 item 13 asks for dwell scoring that covers
folding.
*Rows:* section 2's Eye Tracking and Dwell Control ("dwell-safety
scoring: R1"). *Needs:* cloud (a Linux Swift toolchain can run its own
tests first) and CI; later, the device check of whether Snap to Item
picks by nearest centre or nearest edge says which result binds.
*Apple:* no API; what it models is in Apple's
[Eye Tracking guide](https://support.apple.com/guide/iphone/control-iphone-with-the-movement-of-your-eyes-iph66057d0f6/ios)
("Snap to Item: Have the Eye Tracking pointer automatically move to the
item on the screen that's closest to where you're looking").

**3. The layout engine, with no screen change yet.** The work file
(intent, spec and plan) and one pure function from the space available
(the window's size, its safe areas, and reserved regions such as a
fold), the input profile, the text size and the library's shape to a
frame for every slot. Floors are physical sizes (docs/DECISIONS.md,
"Layouts from the space available"). The profile is an input from the
start, but only today's touch sizes are defined until items 8 and 9.
How the engine takes a fold waits for R0 item 13's look (*How it
runs*). Before Home uses it, its tests show that the starter library
fits without scrolling in every window that scrolls today
(docs/DECISIONS.md, "Home's stand-in layout") and in the rest of the
matrix docs/LESSONS.md asks for; that every control keeps its frame
across Home's states (invariant 8); and that item 2 finds no new
hazard.
*Rows:* section 1's recipes; section 2's AssistiveTouch; section 6's
`ScaledMetric` and Display Zoom; section 10's `ReservedRegion`.
*Needs:* cloud and CI; R0 item 13's look before the fold is settled.
*Built 2026-10-23* (docs/work/layout-engine.md;
[`log/2026-10-23-layout-engine.md`](log/2026-10-23-layout-engine.md)).
Its tests found that the starter library cannot fit everywhere at the
touch floors: it fits every window that scrolls today but the iPad mini
in landscape at AX5, and phones at AX3 and AX5 and 320-point windows
need an arrangement with fewer tiles to a screen (docs/DECISIONS.md,
"The layout engine"). Item 2 landed first (#49); on the engine's
frames it finds no new hazard, only the top of Stop's well on compact
widths (`HomeLayoutEngineTests.noChainOnTheEnginesFramesMeetsAHazardButStopsWell`,
2026-10-24).
*Apple:*
[Layout](https://developer.apple.com/design/human-interface-guidelines/layout)
("Determine layout based on size classes, not device type or
orientation"),
[Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)
(44 by 44 points by default), and
[`reservedRegions(kind:options:layoutDirectionBehavior:)`](https://developer.apple.com/documentation/swiftui/geometryproxy/reservedregions(kind:options:layoutdirectionbehavior:))
(iOS 27.1, so behind `#available`).

**4. Home on the engine: the starter library never scrolls.** Home
takes every frame from the engine, still at today's touch sizes. The
windows that scroll today stop scrolling (invariant 11), the slot plan's
wells are built, a selected category gets the room Emergency has, and
the two open hazards (Yes and No bordering the message; the top of
Stop's well nearest Again) are removed by placement or measured for the
owner (docs/DECISIONS.md, "Get Attention and Stop on Home"). Phrase
tiles are checked with Bold Text on. Item 3's spec lists what this item
adds: an arrangement for 320-point windows and phones at the largest
text sizes, a tile floor that follows the tile's width, and the Bold
Text tiles on 375 and 390-point phones (docs/work/layout-engine.md,
*Plan*).
*Rows:* section 2's AssistiveTouch ("without scrolling: R0-3");
section 6's Larger Text, Bold Text and `ScaledMetric`. *Needs:* cloud
and CI's UI tests on iPad and iPhone; the Snap to Item device check
decides the message hazard. *Owner:* either hazard, if it stays.
*Apple:* the pages item 3 rests on.
*Built 2026-10-24*
([`log/2026-10-24-home-on-the-layout-engine.md`](log/2026-10-24-home-on-the-layout-engine.md);
docs/DECISIONS.md, "The layout engine", *Home on the engine*): Home
takes every frame from the engine, without Phrases and Type until item
5, and `HomeShape` is gone. The 375×667 phone at the default size and
the 11-inch iPad in landscape stop scrolling; a selected category has
Emergency's side inset; tile floors follow the tile's width, checked
with Bold Text; 375 and 390-point phones get two columns with Bold Text.
Not done here: the arrangement with fewer tiles for 320-point windows
and phones at the largest sizes (a design question, then the owner,
before R1), Back to Talking over Phrases' frame and the Figma check
(item 5, which brings Phrases), and a point-by-point check of the
running frames. Both hazards are measured and stay open for the owner
(docs/HANDOFF.md, *Known gaps*).

**5. Typing on Home.** Its brief is written:
[`log/2026-10-21-typing-foundation.md`](log/2026-10-21-typing-foundation.md),
*Follow-ups*. PR #46, open when this was planned, measures the room
Home keeps for Apple's keyboard (`KeyboardAllowance`) and refuses other
apps' keyboards. This item brings the slot plan's own row of quick
controls, with Phrases and Type, in one row wherever two rows would
reach into that room, so that Emergency, Get Attention, Yes, No and
Speak sit above the worst-case keyboard; then the typing state, Return
speaks, and nothing moving when the keyboard shows (docs/DECISIONS.md,
"Typing is a state of Home"). Figma's typing screen (R0 item 9) comes
first, and the privacy policy's words on typing change with it.
*Rows:* section 8's R0-5 rows. *Needs:* cloud and CI (the keyboard
probe runs on CI's iPhone and iPad); the typing record's device checks
afterwards. *Apple:* the pages section 8 of docs/ACCESSIBILITY.md
lists, checked on 2026-10-21.

**6. Home on iPhone Duo, in every pose.**
The owner's two fold choices (docs/DECISIONS.md, "iPhone Duo"): Home's
controls kept off the fold, and an even number of columns on a display
that folds, behind `#available(iOS 27.1, *)`. Apple's Eye Tracking and
Head Tracking guides add one thing to check: on iPhone Duo each works
only fully open, and while either is on, the inner display is dark where
its camera sits. The simulator can show at most where the inner camera's
region lies, inactive included (`.includeInactive`); Apple says you can
leave room for an inactive region so a layout does not jump when the
camera starts; whether that region covers the dark area is checked on a
real iPhone Duo. How Home keeps clear of it is this item's to settle,
with nothing moving when Eye Tracking or Head Tracking starts
(invariant 8).
*Rows:* section 10's `ReservedRegion`. *Needs:* the owner's Mac, to
fold the iPhone Duo simulator in Xcode's Device Hub, the way Apple
documents folding it (PR #43 found no command-line way); an agent
drives Device Hub only with the owner's permission, which PR #43's
thread asked for and did not get, so the owner may fold it by hand. A
real iPhone Duo, when one is at hand. *Apple:*
[Designing for iPhone Duo](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo),
[`ReservedRegion`](https://developer.apple.com/documentation/swiftui/reservedregion)
("If your layout is a grid, use an even number of columns so your
content divides cleanly at the fold"; "An inactive region still has a
frame, so you can leave room for it"), and the
[Eye Tracking](https://support.apple.com/guide/iphone/control-iphone-with-the-movement-of-your-eyes-iph66057d0f6/ios)
and [Head Tracking](https://support.apple.com/guide/iphone/iph9c3dc17cf/ios)
guides.

**7. Settings' chains, and Get Attention in Settings.** With item 2's
scores: Family Setup's rows placed so that a look held after the root's
row meets a row that only navigates, and the chain that follows Family
Setup's first row into Set Up Step by Step and saves an answer broken
by placement (docs/HANDOFF.md, *Known gaps*). Then a start-only Get
Attention in Settings' bar, in its empty place, with the sound line
moved where its neighbours neither speak nor change a setting. This
comes before item 8, because item 8 lets setup answers change sizes.
*Rows:* section 10's Get Attention ("In Settings: later"). *Needs:*
cloud and CI. *Apple:* no new API.

**8. Sizes that follow how the person reaches the screen.** Family
Setup already asks how the screen is reached (`SetupRecord`: touch,
Voice Control, Switch Control, Eye Tracking, Head Tracking, someone else
helps), and Home's sizes and spacing come to follow that answer, with
the largest sizes when nobody has answered (docs/DECISIONS.md, "Setup
answers are kept as offered, never as completed"). How several answers
combine is for this item's work file to decide. No control changes place
relative to the others. What iOS reports about VoiceOver and Switch
Control may suggest an answer in Family Setup, never change one
(docs/DECISIONS.md, "Accessibility API coverage").
*Rows:* section 7's assistive-technology flags; section 1's point
scanning; section 2's Eye Tracking and Head Tracking profiles.
*Needs:* R0's first build gone to App Review; cloud and CI; device
checks afterwards (which flags each input method turns on; comfortable
dwell and target sizes). *Owner:* the gaze floors are the reference
app's (docs/DECISIONS.md, "Layouts from the space available"); floors
for switch and head are new, so this item's work file proposes them,
measured, as defaults the owner can overrule. Any hazard
item 4 left must be gone, or accepted by the owner, before a dwell,
switch, head or gaze size ships. *Apple:*
[`accessibilitySwitchControlEnabled`](https://developer.apple.com/documentation/swiftui/environmentvalues/accessibilityswitchcontrolenabled)
and
[`accessibilityVoiceOverEnabled`](https://developer.apple.com/documentation/swiftui/environmentvalues/accessibilityvoiceoverenabled).
SwiftUI has no AssistiveTouch value, and UIKit's `isAssistiveTouchRunning`
reports correctly only with Guided Access on (Apple: "The user must
enable Guided Access for the correct value to return"), so it is left
out.

**9. The late-stage profile: Yes and No, and the rest board.** The
map's Yes/No mode and rest board as one profile of the engine: Yes, No,
Get Attention and Emergency keep their places relative to each other
and grow, and the phrase area shows fewer, larger tiles from a category
the family chooses (docs/DECISIONS.md, "Accessibility API coverage").
Emergency stays visible (invariant 2).
*Rows:* the map's "Yes/No mode" and "Rest board". *Needs:* R0's
first build gone to App Review; cloud and CI. *Owner:* the late stage's
floors are new, so this item's work file proposes them, measured, as
defaults the owner can overrule. *Apple:* the pages item 3 rests on.

**10. Siri and Shortcuts, the work file.** The intent, spec and plan for
R2's fixed actions ("Get attention in Brickson", "Emergency in
Brickson"), so that, if the owner says yes, the door is designed while
the engine is built. It
settles: each action going through the same resolver as its button;
where Stop is when Get Attention starts from Siri, the Action button,
Back Tap or a Vocal Shortcut while Brickson is not in front; App
Shortcut phrases, titles and parameters that never hold a person's words
(Apple may use App Shortcuts' phrases and titles, anonymized, to train
its models); the privacy policy's Siri and Shortcuts section, which
comes back with the build (AGENTS.md, *The privacy policy is a
promise*); and whether `INAlternativeAppNames` then works. No code.
*Rows:* section 3's `AppIntent`, `AudioPlaybackIntent`,
`AppShortcutsProvider`, Vocal Shortcuts, the Action button and
`INAlternativeAppNames`. *Needs:* the owner's yes, then cloud.
*Owner:* writing this work file, or building it, before R2 takes it
would start an R2 item ahead of its release, which *Where this goes*
rules out without the owner ("Direction, not a licence to skip steps";
docs/SDLC.md: a work file's intent, spec and plan are its first three
stages). The recommendation is to wait for R2. *Apple:*
[`supportedModes`](https://developer.apple.com/documentation/appintents/appintent/supportedmodes)
(`openAppWhenRun` is deprecated since iOS 26),
[`AudioPlaybackIntent`](https://developer.apple.com/documentation/appintents/audioplaybackintent),
[`AppShortcutsProvider`](https://developer.apple.com/documentation/appintents/appshortcutsprovider),
[App Shortcuts](https://developer.apple.com/design/human-interface-guidelines/app-shortcuts)
in the HIG (the app's name in every phrase; at most 10), and
[Hardware interactions](https://developer.apple.com/documentation/appintents/hardware-interactions)
for the Action button.

**After Wave 3.** These are R1's too, so they also wait until R0's first
build has gone to App Review. The phone on its side (the phone as a
first-class device), once the engine's tests show a sideways phone with
no scrolling (docs/DECISIONS.md, "Orientations"); a printable board that
mirrors the screen, once item 4 gives it Home's frames; recorded
phrases, first two stages, once the Library screen (R0 item 6) gives a
phrase somewhere to hold a recording. Guided Access restrictions of
Brickson's own stay a candidate, with a work file first
(docs/DECISIONS.md, "Accessibility API coverage"); Guided Access's APIs
are UIKit's only, so using one also adds its row under "Apple's current
frameworks first" there.

**Folding phones, briefly.** The owner asked how well a folding phone
such as iPhone Duo suits an AAC app. On today's evidence it is a
larger iPhone: good for people who still use touch or a switch, and for
caregivers, while the iPad (or a dedicated eye-gaze device) stays the
main device once a person needs their eyes. Open, its screen is about a
third of a 13-inch iPad's; Apple says Eye Tracking and Head Tracking work
on it only fully open, not in the poses where it stands by itself;
Apple's user guides document external eye trackers for iPad only; and
no mount maker offers a holder for it open yet. No AAC study, clinician
or vendor has said anything about folding phones. Sources and reasoning:
[`recon/2026-10-23/folding-phones-for-aac.md`](recon/2026-10-23/folding-phones-for-aac.md).
Low priority; it changes nothing in R0 item 13.

## R0 "A voice you can rely on"

**For whom:** a person who can still use their hands, and their family.
**Done when:** they could use Brickson every day on their own iPhone and
iPad through TestFlight, and every row of the device-check table that R0
touches has a recorded result.

**Release gate.** No build goes to App Review until: the R0 items below
are complete, including item 11's TestFlight pilot; the device checks they
touch are logged in `docs/log/`; UI tests are green on an iPhone and an
iPad at the default and largest text sizes, light and dark; item 13's
iPhone Duo checks are logged and its screenshots made; and the
privacy policy, README and website say only what the build does. A
stand-in Home would likely fail App Review's completeness and minimum
functionality guidelines (2.1 and 4.2). That pilot is the one external
TestFlight group before the gate passes, and it goes out once items 1 to
10 are complete and the rest of the gate holds.

| # | Item | What it delivers | Owner | Status (2026-10-21) |
|---|---|---|---|---|
| 1 | Current toolchain | CI and the Mac build with Apple's newest released Xcode; the minimum iOS decided | Toolchain and iOS version targets | Landed with PR #12 on 2026-10-21: CI builds with Apple's newest released Xcode, and the minimum iOS is 26.0, decided from two rules |
| 2 | Test seams and CI evidence | Launch options for UI tests (in-memory library, fresh settings, text size, appearance), an iPhone run in the UI tests job, result bundles from CI, the String Catalog synced and checked | Test seams and CI evidence | Launch options, UI tests on iPad then iPhone, kept result bundles and the String Catalog check landed with PR #13 on 2026-10-21; since PR #28 (2026-10-22) each CI job keeps its result bundles as a download for 14 days ([`log/2026-10-22-ci-test-results.md`](log/2026-10-22-ci-test-results.md)) |
| 3 | An honest Home on both devices | Words never break, every category visible, the starter library without scrolling, sized from the space available rather than the device model | Phone layout and word fitting, then a new thread for the wells and the engine | Labels that fit themselves, four categories that never scroll sideways, three phone columns and Home's slot plan in the Phone layout pull request; Home's scan order (quick controls first, regions as containers) and Voice Control names in the accessibility first pass ([`log/2026-10-22-home-scan-order-and-names.md`](log/2026-10-22-home-scan-order-and-names.md)); Show Borders on Home's controls in the second ([`log/2026-10-23-show-borders-and-large-content.md`](log/2026-10-23-show-borders-and-large-content.md)), with the Large Content Viewer kept off Home's controls other than Settings' gear once simulators showed a slow press with it speaks nothing ([`log/2026-10-23-large-content-and-iphone-duo.md`](log/2026-10-23-large-content-and-iphone-duo.md)); Stop's well since item 4 ([`log/2026-10-23-get-attention-on-home.md`](log/2026-10-23-get-attention-on-home.md)); the slot plan's other wells, the rest of item 3's accessibility list, and no scrolling on small phones at large text and on 320-point windows are still to build; the layout engine landed with its work file on 2026-10-23 ([`log/2026-10-23-layout-engine.md`](log/2026-10-23-layout-engine.md)), and Home moved onto it on 2026-10-24, which ends the scrolling at the default size on a 375×667 phone and, by the model, on an 11-inch iPad in landscape ([`log/2026-10-24-home-on-the-layout-engine.md`](log/2026-10-24-home-on-the-layout-engine.md)) |
| 4 | Get Attention and a sturdier speech engine | A start-only alarm with Stop elsewhere; one owner for the audio session; the code audit's speech fixes (M1, L1, L3, L4) | Speech engine and Get Attention | Engine built (PR #16); Get Attention and Stop on Home built 2026-10-23 ([`log/2026-10-23-get-attention-on-home.md`](log/2026-10-23-get-attention-on-home.md); DECISIONS.md, "Get Attention and Stop on Home"). Left: the replacement tone, after a device check; Get Attention in Settings' bar, once its chain is scored; and the R0-4 rows of docs/ACCESSIBILITY.md (`startsMediaSession` after a device check, a test pinning `prefersAssistiveTechnologySettings`, a steady alarm under Dim Flashing Lights and Reduce Bright Effects) |
| 5 | Typing | A composer that does not care which keyboard feeds it, a draft that survives, a probe that measures the real keyboard; then typing on Home under a safety band the keyboard never covers | Typing foundation, then a new thread | Foundation built on 2026-10-21 (`MessageComposer`, `DraftStore`, the keyboard probe; [`log/2026-10-21-typing-foundation.md`](log/2026-10-21-typing-foundation.md)). The room Home keeps for Apple's keyboard (`KeyboardAllowance`), a keyboard check on every UI run and the refusal of other apps' keyboards built on 2026-10-23 ([`log/2026-10-23-keyboard-allowance.md`](log/2026-10-23-keyboard-allowance.md)). The typing state on Home (Phrases and Type, C in one row where two rows do not fit above the keyboard) still waits for items 3 and 9, then gets a fresh thread |
| 6 | Editing and backup | One validated edit applied in one explicit save, a failure test for every save, an emergency category that cannot be deleted, fixed identities for starter phrases, a versioned backup file | Library editing and backup format, then Library follow-ups | The core (editing rules and one-save writer, failure tests, the undeletable emergency category, fixed starter identities, backup format version 1) landed with PR #14 (2026-10-23); the launch repair that gives a damaged library's Emergency its starter phrases back, and a new identity where an earlier category shares its own, is built (2026-10-23, [`log/2026-10-23-emergency-repair.md`](log/2026-10-23-emergency-repair.md)); safety copies, export and import and the Library screen go to a new library thread, the screen after item 7 |
| 7 | Settings and first run | Settings root (a large Back, a start-only Get Attention, Family setup), the voice picker and Personal Voice guidance, the in-app Privacy row, family setup including Guided Access and Assistive Access advice | Settings and first run | Built 2026-10-21 ([`log/2026-10-21-settings-and-first-run.md`](log/2026-10-21-settings-and-first-run.md)), from the first-run design and [`onboarding-and-settings.md`](recon/2026-10-15/directions/onboarding-and-settings.md); its choices are recorded in DECISIONS.md as decided defaults. Home's Settings button is built (2026-10-23, [`log/2026-10-23-settings-on-home.md`](log/2026-10-23-settings-on-home.md)). Left for later: Get Attention in Settings (Home's Stop is built; its place needs scoring). Asking for Personal Voice from Settings is built (2026-10-22, [`log/2026-10-22-voice-screen.md`](log/2026-10-22-voice-screen.md)) and switches on after device check D1. Full screen in Assistive Access and the guides to Apple's features are built (2026-10-23, Wave 3 item 1, [`log/2026-10-23-apples-doors-in-family-setup.md`](log/2026-10-23-apples-doors-in-family-setup.md)); Read & Speak's note and Switch Control's keyboard options are left |
| 8 | Being heard on calls | Speech added to phone and FaceTime calls through Apple's "Add Audio in Calls" path, if a device check passes | None, on purpose | Held until the owner has a device build (see below) |
| 9 | Screens designed in Figma | Home, typing, alarm, Settings, voice and library screens from Apple's iOS 27 UI kit, positions shown not to move, measured colour tokens | Figma and Claude Design screens | Reference drawings and [specification](work/design-screens.md) recorded; corrections and open placement questions remain ([record](log/2026-10-22-design-reconciliation.md)); item 3's landed slot decisions bind |
| 10 | App Store readiness | Apple's current requirements, store text with no price words, accessibility and privacy labels, screenshots, review notes, the privacy policy's unbuilt sections built or deleted | App Store readiness and ASO | In progress (`docs/APP-STORE.md`, `docs/ASO.md`). The website's accessibility page, and the policy without the sections R0 does not ship, landed on 2026-10-23 ([`log/2026-10-23-accessibility-page-and-privacy-trim.md`](log/2026-10-23-accessibility-page-and-privacy-trim.md)); the policy's R0 sentences are marked true or deleted at release |
| 11 | Release chores | The brand icon installed, a license decision, the App Store Connect record (after the name is confirmed), TestFlight to the owner and a small group that includes a person living with ALS and a speech-language pathologist | Owner, with items 9 and 10 | Waiting on decisions |
| 12 | Plan and maintain | This roadmap, the decisions list, the handoff, the way of working ([`docs/SDLC.md`](SDLC.md)) | Roadmap, decisions and repo review | Landed with PR #15; each pull request keeps its own rows current |
| 13 | Ready for iPhone Duo | Home, Settings and setup checked on iPhone Duo's outer and inner displays, open, partially folded and rotated, and in Split View, in the iPhone Duo simulator on the current Xcode; whatever that finds fixed, with the owner's two fold answers built and dwell scoring that covers folding; a Duo family in the UI tests once CI's image has the simulator; the Duo screenshots item 10 submits | A Mac thread for the simulator run, then the layout engine thread, which builds the owner's fold choices (docs/DECISIONS.md, "iPhone Duo", *The fold*) | Planned 2026-10-23: Apple's requirements and an assessment of Brickson against them ([`log/2026-10-23-iphone-duo-readiness.md`](log/2026-10-23-iphone-duo-readiness.md)). Brickson already builds with the iOS 27.1 SDK, so it is already treated as optimized for iPhone Duo. It has run closed, on the outer display, in the simulator on 2026-10-23, where the starter phrases scroll at the default text size ([`log/2026-10-23-large-content-and-iphone-duo.md`](log/2026-10-23-large-content-and-iphone-duo.md)); open and half-folded have not run (no command-line way to fold the simulator was found; Xcode's Device Hub was not tried). Screenshots are required from April 2027. A change it makes to what a person sees starts with a work file ([`docs/SDLC.md`](SDLC.md)) |

**Left out of R0 on purpose:** stage profiles, prediction, recorded
phrases, Siri and Shortcuts, caregiver alerts and the listener display.
Each is better built on R0's foundations than before them.

## R1 "Follows you"

**For whom:** a person moving from touch to a switch, their head or their
eyes. **Done when:** a person can change input method without relearning
where anything is, and the dwell-safety scoring passes for every profile.

- **The profile layout engine.** One pure function from the space
  available, the input profile, the text size and the library's shape to
  a frame for every slot, with standard buttons placed at those frames.
  Profiles (touch, keyboard and Voice Control, switch including
  brain-computer interfaces, head, gaze, and a late-stage profile with
  fewer, larger targets that serves as the map's Yes/No mode and rest
  board) change sizes and spacing only; every control keeps its place. The 2026-10-15 blueprint
  ([`layout-blueprint.md`](recon/2026-10-15/layout-blueprint.md)) is the
  starting design, but it keys some numbers to a table of devices; the
  owner's 2026-10-21 rule asks for layouts from available space instead
  (DECISIONS.md, "Layouts from the space available").
- **Dwell-safety scoring.** Chains of repeated activations scored for every
  state, under both pointer models, with each exception named
  (invariant 10; [`docs/LESSONS.md`](LESSONS.md), "Score chains, not single hops").
- **The phone as a first-class device**, including whether it keeps
  portrait only (iOS 27 and foldable iPhones bring new orientations and
  window shapes; DECISIONS.md, "Orientations"). iPhone Duo's own checks
  come earlier, in R0 item 13, and its inner display ignores the
  portrait-only setting already (DECISIONS.md, "iPhone Duo").
- **Who chooses the profile**: the family, in Settings; accessibility
  features the system reports may suggest a profile, never switch it.
- **Recorded phrases, first two stages**: playing a recording attached to
  a phrase, and importing recordings a person made elsewhere (Voice Memos
  or a message-banking service), through the playback coordinator built
  with the alarm. No microphone yet.
- **A printable board** that mirrors the screen, for partner-assisted
  scanning when the device is not at hand.

## R2 "Your own words, your own voice"

- **The in-app recorder** for message banking, after device checks show
  recording cannot disturb speech or calls.
- **Prediction and history** as fixed strips whose contents change but
  whose places do not (invariant 8).
- **Siri and Shortcuts** with fixed phrases only ("Emergency in Brickson",
  "Get attention in Brickson"); no phrase words in App Shortcuts, as
  AGENTS.md requires (*The privacy policy is a promise*). Built with App Intents and App Shortcuts; a
  SiriKit Intents extension only if the device check shows Siri needs one
  for the app's other names (docs/DECISIONS.md, "Apple's current
  frameworks first").
- **The listener display**: large text turned toward the person listening.
- **Caregiver alerts**, by the owner's decision. The recommended path:
  1.0 makes sound only and the policy's caregiver-alerts section was
  deleted (2026-10-23); later a Shortcuts hand-off; a local-network caregiver station
  only behind a recorded exception to invariant 9, after an experiment
  ([`directions/caregiver-alerts.md`](recon/2026-10-15/directions/caregiver-alerts.md)).

## Waiting, not yet in a release

Worth building, each starting with a work file once R2's foundations are
in: a watch app, a start-only Get Attention control for Control Center and
the Action button, an on-device partner view, custom VoiceOver rotors,
pronunciation of names, and keyboard shortcuts
([`docs/ACCESSIBILITY.md`](ACCESSIBILITY.md); docs/DECISIONS.md,
"Accessibility API coverage"). HomeKit tiles are not on this list: they
would control devices beyond the iPhone or iPad, so they wait on the
owner's decision under invariant 9, as caregiver alerts do.

## All the time

- The test infrastructure list in
  [`tests-ci-audit.md`](recon/2026-10-15/tests-ci-audit.md), section 4.2 of
  the synthesis.
- Moving to each new Xcode release when Apple ships it, through a pull
  request (docs/DECISIONS.md, "Build with Apple's current Xcode"), which
  fixes every warning it adds, since warnings are errors (docs/DECISIONS.md,
  "Warnings are errors").
- Localization through the String Catalog, once its sync check is in CI.
- The device-check log: every result recorded with what it was measured on.
- The documents: each pull request edits the handoff's front page in
  place and adds one file to `docs/log/`.

## Never

AGENTS.md invariant 9's hard stops: accounts or login, servers or network
code, cloud sync (for now), analytics, ads or tracking, third-party
packages or SDKs, AI-generated replies, gesture-only controls, and custom
eye, head or switch tracking. Nothing anywhere states a price for
Brickson until the owner decides one (docs/DECISIONS.md, "Price not
decided").

## Repo review, 2026-10-21

The repository was reviewed against the owner's goal for layouts keyed to
devices, App Store and ASO gaps, and the way of working
([`docs/recon/2026-10-21/repo-review.md`](recon/2026-10-21/repo-review.md):
71 findings, each with an owner, not yet checked by a second reviewer).
Each owning piece of work checks its findings before acting. The biggest:

- The layout blueprint reads the screen and a table of devices; the
  engine must take only the window's space (now a rule: AGENTS.md, *Layout
  on every device and window*). *(the layout engine, a new thread)*
- iPhone Duo and other folding or resizable windows were not planned for,
  and App Store submissions will need iPhone Duo screenshots from April
  2027 (App Store Connect release notes, 2026-10-15). *(Planned since
  2026-10-23 as R0 item 13)*
- Since PR #28 (2026-10-22) each CI job keeps its result bundles for 14
  days, and since PR #31 a cloud agent can read them on Linux (AGENTS.md,
  *Gotchas*), but only by hand: no script yet lists and extracts a
  result's attachments. *(Test seams and CI evidence)*
- No release or TestFlight runbook, and no plan for version and build
  numbers. *(App Store readiness and ASO; Toolchain and iOS version
  targets)*
- The app icon is a placeholder, with no layered Liquid Glass icon.
  *(Release chores, item 11: owner-approved artwork, then Icon Composer on a Mac)*
- Nothing technical stops an agent merging or pushing to `main`; the
  owner's merge is the gate only by rule. *(Project guardrails)*

Accessibility API coverage was checked against Apple's documentation on
2026-10-21: [`docs/ACCESSIBILITY.md`](ACCESSIBILITY.md) gives every API
in the map its release and roadmap item.
Apple's design guidelines and Liquid Glass adoption were reviewed on
2026-10-21 (`docs/DESIGN.md`, *Apple's guidelines and Liquid Glass*).

## Held on purpose

- **R0 item 8, calls.** Held since 2026-10-21 until Brickson runs on the
  owner's own iPhone. Before a thread starts it needs three things: the
  microphone usage text the system shows when Brickson asks, a sentence in
  the privacy policy saying what happens to the call's audio, and a device
  check with a real call heard on both ends.
