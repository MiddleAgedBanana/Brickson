# Accessibility API coverage

Every Apple accessibility feature and API that Brickson uses, will use, or
has decided not to use, with the ALS stage it serves, the iOS version it
needs, where it stands in Brickson, and how it is checked.

**Why this list exists.** The owner's goal is for Brickson to use every
accessibility API in the project's map of Apple features by ALS stage
(2026-10-10, kept outside the repository). This page is that map turned
into a checklist: every row of the map appears in *The map, row by row*,
and sections 1 to 10 list each API behind it. Apple's own features (Eye
Tracking, Switch Control, Voice Control and the rest) do most of the work.
Brickson's part is to be easy for them to use: standard buttons with good
labels (AGENTS.md, invariant 1), controls that never move (invariant 8),
and a family setup guide that explains the settings.

**Checked on 2026-10-27** against Apple's developer documentation (each
symbol page read in its Markdown form, which carries the availability
data), Apple's framework update pages
(`https://developer.apple.com/documentation/updates/{accessibility,swiftui,uikit,avfaudio,appintents,xcuiautomation}.md`),
Apple's user guides and the 2026-10-15 research
([`docs/recon/`](recon/README.md)). Brickson's status was checked against
`main` on that date; each pull request since edits the rows it changes
and says so in its record in [`docs/log/`](log/README.md). How the initial
check was done is in
[`log/2026-10-21-accessibility-coverage.md`](log/2026-10-21-accessibility-coverage.md),
and the 2026-10-27 reference audit is in
[`log/2026-10-27-accessibility-reference-audit.md`](log/2026-10-27-accessibility-reference-audit.md).

## How to read this

**Stage**, from the map:

| Stage | Who |
|---|---|
| 1 | Early: speech and hands mostly working |
| 2 | Middle: speech fading, hands weakening |
| 3 | Advanced: no speech, little movement |
| 4 | Late: yes or no, a partner reading choices aloud |

Stages overlap and ALS takes a different course in each person, so a
person may need a stage 3 feature while still at stage 1 in other ways.

**iOS** is the first iOS (and iPadOS) version Apple's page lists. Brickson
runs on iOS 26.0 and later (docs/DECISIONS.md, "Minimum iOS, iPhone and
iPad"), so anything listed at 26.0 or earlier can be used anywhere. A
version marked **`#available`** is newer than 26.0: code using it sits
behind `if #available(iOS …, *)`, with a path for older systems. "System"
means an Apple feature with no app API; the version given is the first one
known to have it.

**Status in Brickson:**

| Word | Meaning |
|---|---|
| **In place** | On `main` now, with the test named under *Checked by* |
| **R0-*n*** | Planned in R0, item *n* of [`ROADMAP.md`](ROADMAP.md); the item names its owner |
| **R1**, **R2** | Planned in that release, under the roadmap bullet named |
| **Later** | Worth building but not scheduled; it starts with a work file ([`docs/work/`](work/README.md)) |
| **System** | Apple runs it; Brickson's part is standard controls and, where named, setup text |
| **N/A** | Not applicable, for the reason given |
| **Never** | A hard stop (invariant 9) or a recorded decision |

**Checked by:** *Unit* (a unit test), *UI* (a UI test), *Audit* (Apple's
accessibility audit, run inside the UI tests), *Device* (a check on a real
iPhone or iPad, listed in [`HANDOFF.md`](HANDOFF.md), *Checks that need a
real device*), *Review* (a code review rule in AGENTS.md), *Store* (an
App Store Connect answer, from [`APP-STORE.md`](APP-STORE.md)). A planned
test is named for what would make it fail.

## The map, row by row

| Map row (stage; the map's verdict) | Brickson today | Plan | Section |
|---|---|---|---|
| Personal Voice (1; has it) | Speaks in the person's Personal Voice when allowed; asks at launch. Voice Settings explains each state, links to "Allow Apps to Request to Use", and has an explained Ask button that shows once the app asks from Settings | Asking from Settings instead of at launch, after device check D1: R0-7 | 4 |
| Message banking (1; partly) | Nothing yet | Import and play recordings: R1. An in-app recorder: R2 | 10 |
| Listen for Atypical Speech (1; system) | System, with a guide in Family Setup's Calls, Siri and Shortcuts | Device check of the guide's steps | 3 |
| Siri and App Intents (1; add) | Nothing yet | R2 "Siri and Shortcuts", fixed phrases only | 3 |
| Vocal Shortcuts (1; system) | System, with a guide in Family Setup's Calls, Siri and Shortcuts | A Get Attention shortcut to point it at: R2 | 3 |
| Dynamic Type, Bold Text, Reduce Motion (1; has it) | Text styles on Home; UI tests at the largest size; with Bold Text off and on every starter label keeps its words whole, dropping its icon first (`WordFit`, `StarterLabelFitTests`, `HomeLayoutEngineFontTests`) | — | 6 |
| Phrase board and typing (2; has it) | The board is on Home, and typing since 2026-10-24 (Wave 3 item 5; docs/DECISIONS.md, "Typing on Home") | Typing: R0-5. A touch profile: R1 | 8 |
| Live Speech (2; system) | System, with a guide in Family Setup's Calls, Siri and Shortcuts | Being heard on calls: R0-8, held | 4 |
| Voice Control (2; has it) | Every Home control is a labelled standard button; the fixed controls' names start with their visible words, Again also answers to "Repeat", Get Attention to "Help" and Stop to "Stop Alert", and no two controls on Home share a name in any state of the starter library, the alarm sounding included (`HomeControlNames`) | Collisions in a library a family has grown: R0-6 | 3 |
| AssistiveTouch, Touch Accommodations (2; system) | Standard buttons; Touch Accommodations' guide in Reaching the Screen | Device check of the guide's steps | 2 |
| Word prediction (2; add) | Apple's keyboard suggestions while typing on Home (2026-10-24) | A prediction strip: R2 | 8 |
| HomeKit (2; add, needs a decision) | Nothing yet | Not in 1.0; controlling devices beyond the iPhone or iPad is the owner's decision under invariant 9 | 10 |
| Apple Watch (2; system, a watch app later) | System; Live Speech on the watch has a guide in Calls, Siri and Shortcuts | A watch app: Later | 10 |
| Text size, contrast (2; has it) | Contrast measured in `PaletteTests` | Kept | 6 |
| Eye Tracking and Dwell (3; has it) | Standard buttons; repeats of a phrase absorbed; chains of held activations scored on Home and Settings' first screens (`ChainEngine`), with two open hazards in Settings | Gaze profile and dwell-safety scoring per profile: R1 | 2 |
| Head Tracking (3; system) | System, with a guide in Reaching the Screen | Head profile: R1 | 2 |
| Switch Control (3; system) | Standard buttons; Home's regions are containers, reached in a fixed order with Yes, No, Emergency and Get Attention first (`HomeRegion`) | Device check of the scan order and groups. Switch profile: R1 | 1 |
| Guided Access (3; system) | System, with a guide in Keep Brickson Open | A device check with Eye Tracking | 7 |
| Assistive Access (3; add) | Full screen inside it, in Brickson's own layout; a guide in Keep Brickson Open, and written Settings paths instead of links while inside it | A device check of the window and the guides | 7 |
| Get Attention and Emergency (3; has it) | Emergency and a start-only Get Attention on Home in every state, with Stop in its own well while the alarm sounds (docs/DECISIONS.md, "Get Attention and Stop on Home") | Get Attention in Settings: scored, not added, the owner decides (docs/DECISIONS.md, "Get Attention in Settings' bar: the owner decides"); the replacement tone after a device check | 4, 5 |
| Alert someone in another room (3; add, needs a decision) | Sound in the room only | Not in 1.0; anything that reaches another device is the owner's decision | 10 |
| Screen never locks (3; has it) | In place | Kept | 7 |
| Audio safety (3; has it) | In place | Device checks | 4 |
| Brain-computer interfaces through Switch Control (4; system) | Standard buttons, in Home's fixed scan order | Covered by the scan-order work (R1) | 1 |
| Yes/No mode (4; add) | Yes and No are on Home in every state | A late-stage profile: R1 (docs/DECISIONS.md, "Accessibility API coverage") | 1, 2 |
| Partner-assisted mode (4; add) | Nothing yet | A printable board: R1. An on-device partner view: Later | 10 |
| Rest board (4; add) | Nothing yet | The late-stage profile with a small, family-chosen category: R1 | 1, 2 |
| Legacy messages: Personal Voice saved as audio (4; add, verify first) | Not built | N/A: Personal Voice is never written to a file (docs/DECISIONS.md) | 4 |
| An input profile chosen by the family (all; add) | Nothing yet | R1, chosen by the family; system settings may suggest one, never switch it | 1, 2, 7 |
| Neutral starter phrases (all; partly) | In place (`StarterLibrary`, `StarterPhrasesTests`) | Kept (invariant 7) | — |
| Localization (all; add) | Every app string goes through the String Catalog; English only | More languages later | 5 |
| Accessibility Nutrition Labels (all; add) | Nothing yet | R0-10 | 9 |
| Privacy manifest (all; partly) | In place, no data collected, pinned by `AppBundleTests` | Kept | — |
| Sync between a person's devices (all; skip) | None | No iCloud sync in 1.0 (docs/DECISIONS.md) | — |
| The reference app's two safety bugs: the keyboard covering Get Attention, and a crash deleting a category (all; must fix) | Not ported; each became a rule | Typing never hides the call for help (R0-5: in place on Home since 2026-10-24; where the keyboard's room would reach the safety row, Type is dimmed, docs/DECISIONS.md, "Typing on Home"); never roll back a cascade delete (R0-6; docs/LESSONS.md) | 8 |

## 1. Switch Control, Full Keyboard Access and scan order

Switch Control moves a highlight through the screen and a switch press
chooses; Full Keyboard Access does the same with Tab and Space. Both
follow the accessibility tree, so every standard button is reachable. What
Brickson adds is order: with auto scanning, every item before Emergency,
Get Attention, Yes and No is waiting time, so they come first and stay in
the same place in the order in every state.

| API or feature | What it is for | Stage | iOS | Status in Brickson | Checked by |
|---|---|---|---|---|---|
| Switch Control: item scanning, auto scanning, timing | Running the device with one or two switches | 2–4 | System, since iOS 8 or earlier | **System.** Standard buttons: in place. Quick controls first in the scan order, the same in every state: **in place** (`HomeRegion`). Setup advice (scanning style, Auto Scanning Time, Hold Duration, Ignore Repeat, Auto Tap): **in place**, in Reaching the Screen's *Switch Control timing* (2026-10-23) | UI: `HomeAccessibilityOrderTests` (Home's elements in order in every category and state, default and largest text). Audit of the guide. Device: scan steps to each quick control; the guide's steps |
| Scanning groups (Group Items) | Choosing a region first, then an item in it | 3–4 | System | **In place**: Home's regions are containers, in the order C, A, B, D of "Home's slot plan" (`HomeRegion`). Whether a SwiftUI container becomes a scan group is not documented by Apple | UI: `HomeAccessibilityOrderTests` (each control inside its region, regions in order). Device: the groups Switch Control forms |
| Point scanning (Gliding Cursor), head and eye modes inside Switch Control | Picking a point instead of an item | 3–4 | System; the eye mode since iOS 26 | **R1** profile layout engine: switch, head and gaze floors | Unit: each profile's floors. Device: presses per control |
| Switch sources (external switch, screen, camera, sound, Back Tap, AirPods nod) | What counts as a switch | 2–4 | System | **System.** Setup text: **in place**, in Reaching the Screen's Switch Control steps (Apple's six sources: External, Screen, Camera, Back Tap, Sound, AirPod Gestures). Brickson never reads switch hardware (invariant 9) | Device: Brickson's own speech does not fire a sound switch |
| Recipes, switch sets, saved gestures | A switch press that taps a fixed spot | 3–4 | System | **System.** Works because controls never move (invariant 8) | Unit: Home's state is not an input to the layout engine, so every slot keeps its frame, and `HomeLayoutEngineTests` checks no control follows the library (2026-10-23; on screen with R0-3, Wave 3 item 4). Device: a saved tap on Yes still lands on Yes |
| Switch Control typing options (Scan Same Key After Tap, Always Tap Keyboard Keys, Extended Predictions) | Fewer presses per letter on Apple's keyboard | 2–3 | System, on the iOS 26 and 27 setup pages | **R0-5** keeps Apple's keyboard; setup text **R0-7** | UI: quick controls stay above the keyboard. Device: presses per letter |
| Brain-computer interface protocol | A brain implant acting as a switch | 4 | 26.0 | **System**, through Switch Control. Nothing beyond the scan-order work | Device: no hardware available; Switch Control item mode stands in |
| Full Keyboard Access | Running the device from a physical keyboard | 1–2 | System, since 13.4.1 | **System.** Standard buttons: in place. Focus order test: **R1** (keyboard and Voice Control profile) | UI: Tab order with `typeKey`. Device |
| Full Keyboard Access status | Knowing whether it is on | 1–2 | — | **N/A**: Apple offers no flag; the family chooses the profile | — |
| `accessibilityElement(children:)` | `.contain` makes a region; `.combine` merges passive text | 1–4 | 13.0 | **In place**: `.combine` on passive text only (Speaking indicator, warnings); `.contain` on Home's four regions (`HomeRegion`). Never `.combine` or `.ignore` over buttons | UI: every control is its own button, inside its region (`HomeAccessibilityOrderTests`). Review |
| `accessibilitySortPriority(_:)` | Order among elements at the same level | 2–4 | 14.0 | **In place** on Home's regions: SwiftUI orders elements of equal priority by where they are, which puts the message above the quick controls first, so each region has a fixed priority (`HomeRegion.sortPriority`). Never from usage (invariant 8); inside a region, Again comes after Emergency and Settings after the categories (`HomeRegion.lastInRegion`, 2026-10-23); Phrases and Type after the message, and while typing Speak, Clear and Put Back in their slots' places (2026-10-24) | Unit: `HomeRegionTests`. UI: `HomeAccessibilityOrderTests`. Device: whether Switch Control and Full Keyboard Access follow it (Apple does not say) |
| `accessibilityRespondsToUserInteraction(_:)` | Telling the switch and keyboard cursor to skip passive text | 2–4 | 15.0 | **Not used yet**: only if a device check finds the cursor stopping on the message, the Speaking indicator or a warning (the next item 3 work). Never on a button | Device. Review |
| `focusable(_:interactions:)` | Making a non-button view take keyboard focus | 1–2 | 17.0 | **N/A** while every control is a button | Review |
| `focusSection()` | Guiding focus movement | — | macOS 13 only | **N/A**: Apple lists no iOS version | — |
| `keyboardShortcut(_:modifiers:)` | A key that presses a control | 1–2 | 14.0 | **Later** (a candidate for R1's keyboard profile). Never on a destructive or position-changing action | UI: `typeKey` presses the control |
| Custom actions: `accessibilityAction(named:_:)`, `accessibilityActions(_:)` | Extra actions listed by VoiceOver and the Switch Control menu | 2–3 | 16.0 (older forms from 13.0) | **Later**, with edit mode (R0-6). Never an action that changes data outside edit mode (invariant 3) | Unit: the tile action resolver. Device |
| UIKit `accessibilityNavigationStyle` | Grouping in a UIKit container | 3–4 | 8.0 | **N/A**, unless a device check shows SwiftUI containers do not form scan groups | Device |

## 2. Eye, head and pointer input

Eye Tracking, Head Tracking, external eye trackers, mice and joysticks all
drive the same system pointer, and Dwell Control turns a resting pointer
into a tap. Brickson's part is placement: large targets, nothing harmful
where a pointer rests, and no scrolling for the starter library
(invariants 10 and 11; AGENTS.md, *Design rules for dwell, switch and
pointer input*).

| API or feature | What it is for | Stage | iOS | Status in Brickson | Checked by |
|---|---|---|---|---|---|
| Eye Tracking | The front camera moves the pointer; dwell taps | 3–4 | System, since 18.0 | **System.** Standard buttons and the screen kept awake: in place. Chains of held activations scored on Home and Settings' first screens: **in place** (Wave 3 item 2; docs/DECISIONS.md, "One chain engine for dwell safety"). Gaze profile and its dwell-safety scoring: **R1**. Setup text: **in place**, in Reaching the Screen, with Dwell Control's written path | Unit: gaze floors, positions equal across profiles; `ChainEngineTests`. Device: re-firing, Snap to Item |
| External eye trackers made for iPad | A tracker bar driving the AssistiveTouch pointer | 3–4 | System (iPad) | **System.** Setup text: **in place**, in Reaching the Screen's *Eye trackers for iPad*, which says Apple describes it for iPad only. Brickson never talks to the tracker (invariant 9) | Device, with a tracker |
| Head Tracking | Head movement moves the pointer; expressions can act | 2–3 | System, since 26.0 | **System.** Head profile: **R1**. Setup text: **in place**, in Reaching the Screen, with Dwell Control's written path | Unit: head floors. Device |
| Dwell Control (dwell time, Movement Tolerance, Fallback Action, hot corners) | A resting pointer taps | 2–4 | System, since 13.0 | **In place**: a repeat of the phrase still speaking is absorbed (`SpokenUtteranceTracker`). Get Attention start-only, Stop elsewhere, scored after each: **in place** (R0-4); the top of Stop's well, nearest Again, is an open hazard (docs/DECISIONS.md, "Get Attention and Stop on Home"). Chains of held activations, by nearest centre and edge, with the pointer staying or going back to the look: **in place** for Home's states and Settings' first screens, where a held look can save a setup answer and Settings can close under the look (docs/DECISIONS.md, "One chain engine for dwell safety"). Dwell-safety scoring per profile: **R1** | Unit: `SpokenUtteranceTrackerTests`, `ChainEngineTests`, `HomeLayoutEngineTests` (after Get Attention and Stop, every width; chains in every Home state, on the layout engine's frames Home uses). UI: `SettingsOnHomeTests` (chains through Settings). Device |
| AssistiveTouch menu, custom gestures, Sound Actions | Gestures and buttons for people who cannot make them | 2–4 | System | **System.** The starter library without scrolling, since each scroll is several menu trips: **in place** where the layout engine fits it, which Home uses since 2026-10-24; phones at the largest text sizes and 320-point windows: **R0-3** | Unit: layout fits without scrolling (`HomeLayoutEngineTests` pins where the layout engine fits it and where it cannot; docs/DECISIONS.md, "The layout engine", *Where the starter library fits*). UI: `HomeLayoutTests` on CI's iPhone and iPad. Device: where the menu button rests over Home |
| Pointer devices and Pointer Control | Mouse, trackpad, joystick, head mouse | 1–3 | System, since 13.0 | **System.** Hit shapes on the custom button style: in place | Audit: hit regions. Device |
| Touch Accommodations (Hold Duration, Ignore Repeat, Tap Assistance) | Shaky or slow touches read as one tap | 1–2 | System | **System.** Setup text: **in place**, in Reaching the Screen's Touch section, with the caution that quick taps can seem to do nothing. Brickson never adds its own delay or confirm step (invariant 2). A vertical phrase-grid drag uses native pan cancellation even where all tiles fit (2026-10-26; docs/DECISIONS.md, "Phrase-grid drag cancellation") | UI regressions: first tap and slow press (`SlowPressTests`); `PhraseDragTests` adds a 1.5s hold, silent gutter/tile drags, the first tap after each drag and unchanged static/fitting settled frames. Pre-extra-batch selected runs pass all five drag-class and two existing slow-press cases on each of Duo, iPad and iPhone, with no skips/expected failures. Pre-extra-batch units pass 778 total (769 passed, zero failed, one existing skip and eight strict expected failures), catalog current; hosted Unit/UI checks pass, while complete local UI fails only the existing AX5 Speaking waits. The extra batch's default light/dark cases now require actual eight-tile fit and unconditional settled comparisons. The affected final-source iPad selection passes 10/10; a viewport-only 1pt-clipping variant passes with required-fit flags off and fails before input with them on. All 153 frozen Swift/project-source hashes are restored. The affected final iPhone selection also passes 10/10 with retained audio-session diagnostics; extra-batch units pass 781 total (772 passed, zero failed, one existing skip and eight strict expected failures), catalog current. The final affected Duo selection passes 7/7 with seven retained runtime audio warnings on actual OS-reported opposite-tall open/flat space, without the synthetic reservation fixture; coordinate and default fitting guards pass. At the recorded pre-push checkpoint, new-head hosted CI and review resolution remain pending after the single authorized push; live PR state provides the later result. These selections are not complete ordinary UI or device-input verification. AX5 may still overflow in the touch profile without weakening future-profile no-scroll requirements. [Native results and remaining gates](log/2026-10-25-duo-fold-design.md#pr-58-continuation-and-drag-investigation-2026-10-26). AXPress was not attempted because the auxiliary bridge returned no usable elements. Device: Hold Duration, Ignore Repeat, Tap Assistance and Dwell remain unverified |
| Back Tap | Tapping the back of an iPhone runs an action | 1–2 | System, since 14.0 | **System.** Can run a Brickson shortcut once **R2** ships them | Device |
| Hover Text | A larger copy of the text under the pointer | 1–2 | System, since 18.0 | **System.** Works because labels are real text | Audit. Device |
| `hoverEffect(_:)`, `contentShape(_:_:eoFill:)` | How a control looks and where it can be hit under a pointer | 1–3 | 13.4; 15.0 | **In place** (`HomeButtonStyle`): `.contentShape(shape)`, `.contentShape(.hoverEffect, shape)` and `.hoverEffect(.highlight)`. Never act on hover alone | Audit: hit regions. Review |
| Custom eye, head or pointer tracking | Brickson's own camera or dwell code | 3–4 | — | **Never** (invariant 9) | Review |

## 3. Voice in: Voice Control and Siri

| API or feature | What it is for | Stage | iOS | Status in Brickson | Checked by |
|---|---|---|---|---|---|
| Voice Control | Running the device by voice ("Tap Yes", "Show numbers") | 1–2 | System, since 13.0 | **System.** Every Home control is a labelled standard button: in place. Setup text: **in place**, in Reaching the Screen | Audit (in place). Device: "Show numbers" numbers every control |
| Voice Control flexible item names ("say what you see") | Naming a control in your own words | 1–2 | System, 27.0 | **System.** Nothing to build; good labels are what it needs | Device |
| `accessibilityInputLabels(_:)` | Extra names to say or type, the visible words first | 1–2 | 14.0 | **In place** on Yes, No, Emergency, Again, Get Attention, Stop and Settings (`HomeControlNames`): the visible words first; Again also answers to "Repeat", Get Attention to "Help", Stop to "Stop Alert", and Settings answers to "Settings" even when narrow width shows the gear alone; in Voice Settings (`VoiceSettingsView`), each voice's buttons answer to "Hear \<Name\>" / "Hear" and "Use \<Name\>" / "Use". Categories, phrases, Phrases, Type, Speak, Clear and Put Back answer to their own words only | Unit: `ControlNamesTests` (the visible words first, no repeated or empty name). UI: `SettingsTests` |
| Voice Control name collisions | Two visible controls answering to one name | 1–2 | — | **In place** for the starter set: no two controls on Home, input labels included, share a name in any category's state (`HomeNameCollisionTests`, comparing names without case, accents or punctuation); no "Yes." or "No." tiles, unique category names (`StarterPhrasesTests`). For a library a family has grown: **R0-6**, with `HomeControlNames.collisions`. Never rename a person's phrase (invariant 7) | Unit. Device |
| Vocal Shortcuts | A person's own sound runs an action | 1–2 | System, since 18.0 | **System.** Setup text: **in place**, in Calls, Siri and Shortcuts (2026-10-23). A Get Attention shortcut to run: **R2** | Device |
| Listen for Atypical Speech | Siri listens for a wider range of speech; Apple names ALS | 1–2 | System, since 18.0 | **System.** Setup text: **in place**, in Calls, Siri and Shortcuts, with Apple's English (U.S.) limit and Siri Pause Time | Device: the guide's steps |
| Siri and Type to Siri | "Open Brickson", by voice or typed | 1–2 | System | **System.** Opening the app works now. Fixed actions: **R2** | Device |
| `CFBundleSpokenName` | How text-to-speech says the app's name | 1–4 | 2.0 | **In place** (`APP_SPOKEN_NAME` in `project.yml`) | Unit: `AppBundleTests`. Device: VoiceOver reads the icon |
| `INAlternativeAppNames` | Other names Siri accepts ("Brick Son") | 1–2 | Info.plist key (no version on Apple's page) | **In place** in the Info.plist, but **not yet effective**: Apple says Siri recognizes alternative names only for apps with an Intents app extension, and Brickson has none. Revisit with **R2** | Unit: `AppBundleTests` (well-formed). Device: "Open Brick Son" |
| `AppIntent`, `supportedModes` | Actions Siri, Shortcuts and the Action button can run | 1–3 | 16.0; `supportedModes` 26.0 | **R2** "Siri and Shortcuts": Speak, Get Attention, Emergency, each through the same resolver as its button | Unit: an intent and its button do the same. Device: from the Lock Screen |
| `AudioPlaybackIntent` | Tells the system an intent plays sound, so Siri does not talk over it | 1–3 | 17.0 | **R2**, for Get Attention | Unit. Device |
| `IntentExecutionTargets` (`allowedExecutionTargets`) | Which process may run an intent | 1–3 | 27.0 **`#available`** | **Later**, only if Controls are built: the app itself, never an extension | Unit |
| `AppShortcutsProvider`, `AppShortcut`, `AppShortcutPhrase` | Ready-made Siri phrases that work after install | 1–3 | 16.0 | **R2**, fixed phrases only: no phrase words (AGENTS.md, *The privacy policy is a promise*) | Unit: phrases from a fixed list. Device |
| Action button | A side button on newer iPhones runs a shortcut | 1–2 | System (iPhone) | **System.** Setup text: **in place**, in Calls, Siri and Shortcuts, for an iPhone with an Action button. A Get Attention target: **R2**. Never the only way to a safety action | Device |
| `ControlWidget`, `ControlWidgetButton` | A button in Control Center, the Lock Screen or the Action button | 1–2 | 18.0 | **Later**: a start-only Get Attention button, never a toggle (invariant 10) | Unit. Device |
| Phrases as `AppEntity` | Letting Shortcuts list a person's phrases | — | 16.0 | **Never** while R2's fixed-phrases rule stands: the system would show the person's words | Review |
| Spotlight: `IndexedEntity`, `CSSearchableIndex` | Putting phrases in system search | — | 18.0; 9.0 | **Never**: a person's words stay out of system search | Review |

## 4. Speech out: the voice, the audio session and calls

| API or feature | What it is for | Stage | iOS | Status in Brickson | Checked by |
|---|---|---|---|---|---|
| `AVSpeechSynthesizer` | Apple's speech engine | 1–4 | 7.0 | **In place** (`SpeechService`, `SpeechSynthesizing`) | Unit: `SpeechServiceTests`, `SpokenUtteranceTrackerTests`. Device: sound |
| `AVSpeechUtterance` rate, pitch, volume, delays | How each phrase sounds | 1–4 | 7.0 | **In place**: rate in five fixed steps (`SpeechRateSteps`, `SpeedChoice`) and the voice picker (`VoiceSettingsView`, `VoiceSelection`, 2026-10-21). Never a delay before speaking (invariant 2) | Unit: `SpeechRateStepsTests`, `VoiceSelectionTests`. UI: `SettingsTests` |
| `usesApplicationAudioSession` | Speech uses Brickson's own audio session | 1–4 | 13.0 | **In place** (set to true in `SpeechSynthesizing`) | Review. Device: speech follows the session's silent-switch and interruption handling |
| `prefersAssistiveTechnologySettings` | Lets VoiceOver's voice settings replace the phrase's voice | 1–4 | 14.0 | **Not set, on purpose** (false): a phrase is for the listener, in the person's voice. A test pinning it: **R0-4** | Unit. Device: with VoiceOver on, a phrase still uses the Personal Voice |
| Voices: `speechVoices()`, `quality`, `voiceTraits`, `availableVoicesDidChangeNotification` | Listing voices and noticing new ones | 1–4 | 7.0; 9.0; 17.0; 17.0 | **In place** (`VoiceSelection`) | Unit: `VoiceSelectionTests`. Device: a downloaded voice appears without relaunch |
| `AVSpeechUtterance(ssmlRepresentation:)` (`init?(ssmlRepresentation:)`) | Pauses, emphasis and pronunciation by markup | 1–4 | 16.0 | **Later**. Never built from a person's words without escaping | Unit: bad markup still speaks. Device |
| `AVSpeechSynthesisIPANotationAttribute` | Saying a name the right way | 1–4 | 10.0 | **Later**. Never changes the person's text (invariant 7) | Unit. Device |
| `write(_:toBufferCallback:)` | Speech rendered into audio buffers | 1–2 | 13.0; with markers 16.0 | **N/A**: a Personal Voice is never written to a file (docs/DECISIONS.md) | Review |
| Personal Voice | A synthetic voice that sounds like the person | 1–2 | System, since 17.0 (10-phrase creation in 26.0) | **System.** Guidance in setup: **in place** (`PersonalVoiceGuidance`, `VoiceSettingsView`, `CallsSiriAndShortcutsGuide`, `GuidedSetupView`, 2026-10-21) | Unit: `PersonalVoiceGuidanceTests`. UI: `SettingsTests`. Device: create one and hear it in Brickson (D1) |
| `requestPersonalVoiceAuthorization`, `personalVoiceAuthorizationStatus` | Permission to speak in it | 1–4 | 17.0 | **In place**: explained before asking in Voice Settings and Set Up Step by Step (`PersonalVoiceGuidance`, `VoiceSettingsView`, 2026-10-21), and still asked at launch until device check D1 verifies whether iOS 26 lists Personal Voices before authorization (docs/DECISIONS.md) | Unit: `VoiceSelectionTests`, `PersonalVoiceGuidanceTests`; `OffMainThreadCallbackTests` for the answer through `SpeechService`. UI: `SettingsTests`. Device: D1 |
| `AccessibilitySettings.Feature.personalVoiceAllowAppsToRequestToUse` | Opens the switch that lets apps ask | 1–4 | 18.0 | **In place**, in Voice Settings when permission is denied; inside Assistive Access only the written path (2026-10-23) | Unit: `PersonalVoiceGuidanceTests`, `SettingsAppLinkTests`. Device |
| Live Speech | Apple's type-to-speak, also into calls | 1–3 | System, since 17.0 | **System.** Setup text: **in place**, in Calls, Siri and Shortcuts, and on Apple Watch. No API to write its saved phrases was found, so the guide asks families to type in a few by hand | Device: Live Speech and Brickson do not cut each other off |
| Add Audio in Calls, `AccessibilitySettings.Feature.allowAppsToAddAudioToCalls` | The system switch for apps' audio in calls, and a link to it | 2–4 | System, 18.2; the link 18.2 | **R0-8**, held until a device build | Device: a real call heard on both ends |
| `AVAudioApplication.microphoneInjectionPermission`, `requestMicrophoneInjectionPermission(completionHandler:)` | Permission to add Brickson's speech to calls; on its own it adds nothing | 2–4 | 18.2 | **R0-8**, held | Unit: every permission state. Device |
| `AVAudioSession.setPreferredMicrophoneInjectionMode(_:)` with `.spokenAudio`, and `.none` to stop | The call that actually adds Brickson's speech to a call, made once permission is granted (Apple's sample, "Adding synthesized speech to calls") | 2–4 | 18.2 | **R0-8**, held | Unit: a setter that throws shows passive text and the phrase still speaks in the room (invariants 4 and 5). Device: the far end hears the phrase |
| `isMicrophoneInjectionAvailable`, `microphoneInjectionCapabilitiesChangeNotification`, `AVAudioSessionMicrophoneInjectionIsAvailableKey` | Whether a call that can take Brickson's speech is in progress | 2–4 | 18.2 | **R0-8**, held | Unit: the notice's value read into the call state. Device: a call starting and ending |
| `NSMicrophoneInjectionUsageDescription` | The sentence the system shows when asking | 2–4 | 18.2 (Apple's sample; no reference page) | **R0-8**, held | Unit: `AppBundleTests` once the request exists |
| `mixToTelephonyUplink` | An older way to send speech into a call | 2–4 | 13.0 | **N/A**: calls go through microphone injection | — |
| `.playback` category, with `.mixWithOthers` as a fallback | Speech with the silent switch on and the screen locked | 1–4 | 3.0 | **In place** (`AudioSessionCoordinator`; invariant 4) | Unit: `AudioSessionCoordinatorTests`. Device: silent switch |
| `.spokenAudio` mode (`AVAudioSession.Mode.spokenAudio`) | Continuous spoken-content mode that tells the system to pause this app when another app speaks | 1–4 | 9.0 | **Not used, on purpose**: Brickson uses `.default` mode (`AudioSessionCoordinator`) so another app's prompt never pauses a spoken phrase or the Get Attention alarm (docs/DECISIONS.md, "Background audio") | Unit: `AudioSessionCoordinatorTests`. Device: another app's audio during a phrase |
| Life-cycle notices: `didBecomeInactiveNotification`, `didBecomeActiveNotification`, `resumptionRecommendationNotification` | The iOS 27 replacement for interruption notices | 1–4 | 27.0 **`#available`** | **In place** for `didBecomeInactiveNotification` (`AudioSessionEvents`; docs/DECISIONS.md, "Audio session notices"). The other two are not used: Brickson never resumes by itself | Unit: `AudioSessionEventsTests`. Device: a call during a phrase on iOS 27 |
| `interruptionNotification` | A call or Siri cut the audio | 1–4 | 6.0 | **In place**, alongside the iOS 27 notice | Unit. Device |
| `routeChangeNotification`, `mediaServicesWereLostNotification`, `mediaServicesWereResetNotification` | Headphones out; the audio system restarted | 1–4 | 6.0; 7.0; 6.0 | **In place** (`AudioSessionEvents`, `AudioSafetyMonitor`) | Unit: `AudioSafetyMonitorTests`, `AudioSessionEventsTests`. Device |
| `UIBackgroundModes` `audio` | Speech goes on when the screen locks | 1–4 | 4.0 | **In place** | Unit: `AppBundleTests`. Device |
| Read & Speak (Speak Screen, Speak Selection, Typing Feedback, Highlight Content) | The system reads text aloud | 1–2 | System | **System.** A setup note: **R0-7**. Never the way phrases are spoken | Device: Speak Screen and Brickson do not talk over each other |

## 5. VoiceOver

| API or feature | What it is for | Stage | iOS | Status in Brickson | Checked by |
|---|---|---|---|---|---|
| VoiceOver with standard controls | Apple's screen reader | 1–2 | System | **In place** on Home through standard buttons. A full VoiceOver pass on a device comes before the App Store label (APP-STORE.md, section 4) | Audit (in place). Device |
| `accessibilityLabel`, `accessibilityValue`, `accessibilityHint` | What an element is, its state, what it does | 1–4 | 14.0 to 16.0 | **In place**: labels on Home, the audio and draft warning strips, the gear-only Settings button at narrow width, and throughout Settings / Voice Settings; `"In Use"` value on the chosen voice in `VoiceSettingsView`; hint on Home's `Type` button when dimmed because the software keyboard would reach the safety row | UI: controls found by label, `SettingsTests`, `TypingOnHomeTests`. Audit |
| Traits: `isButton`, `isSelected`, `isHeader`; `accessibilityHidden(_:)` | Kind and state; hiding decoration | 1–4 | 13.0; 14.0 | **In place**: Selected on the chosen category, Emergency, the active mode (`Phrases` or `Type`), and the chosen speaking speed; decoration hidden. Headers: **in place** on the safety row, every Settings heading (`SettingsHeading`, since PR #23) and the privacy policy's headings | UI: the Selected trait follows the choice. Review: headers |
| `startsMediaSession` trait | Asks VoiceOver to stay quiet while the control's sound plays | 1–2 | 13.0 | **R0-4**, after a device check of what VoiceOver does with synthesized speech | Device |
| `playsSound` trait | Tells VoiceOver a control makes its own sound | 1–2 | 13.0 | **In place** on Home's Get Attention (R0-4) | Device |
| `accessibilityRotor`, `AccessibilityRotorEntry` | Jumping between categories or phrases | 1–2 | 15.0; 16.0 | **Later**. Never ordered by use (invariant 8) | Unit: entries in stored order. Device |
| `AccessibilityNotification.Announcement` with a priority | Telling a VoiceOver user about a sound or draft problem without moving focus | 1–2 | 17.0 | **In place** (`AudioSafetyPolicy`, `DraftIssue`, `HomeView`) | Unit: `AudioSafetyPolicyTests`, `DraftStoreTests`. Device: heard once, in full |
| `AccessibilityNotification.ScreenChanged`, `LayoutChanged` | Moving VoiceOver to a new screen | 1–2 | 17.0 | **Not posted on Home, on purpose.** Typing posts none either (2026-10-24): Type moves the text cursor into the field, not VoiceOver's place; whether VoiceOver should follow is a device check. Settings decides for its screens (R0-7) | Review. Device |
| `AccessibilityFocusState` | Reading or moving VoiceOver's focus | 1–2 | 15.0 | **Never on Home**: focus never moves when a phrase speaks or a warning shows | Review. Device |
| `accessibilityCustomContent`, `AXCustomContent` | Extra facts read on request | 1–2 | 16.0; 14.0 | **R1**: "recorded" on a recorded phrase's tile | Unit. Device |
| Accessibility Reader | A system reading view of any app's text | 1–2 | System, since 26.0 | **System.** Works because the setup guide is real text | Device |
| Braille displays, Braille Access, `AXBrailleTranslator` | Braille input and output | — | System; 26.0 | **N/A**: VoiceOver drives braille displays through standard controls; Brickson does not translate braille itself | Device, if a braille user joins TestFlight |
| `Text(verbatim:)` and the String Catalog | A person's words shown exactly; app words translatable | 1–4 | 13.0 | **In place** | Unit: the String Catalog check in CI. Device: a tile reads the person's exact words |

## 6. Display, text and motion

| API or feature | What it is for | Stage | iOS | Status in Brickson | Checked by |
|---|---|---|---|---|---|
| Larger Text and Larger Accessibility Sizes | The person's reading size | 1–4 | System | **In place**: text styles on Home; reachability, fixed frames and whole quick-control words checked at the largest size; every starter label fitted whole in its narrowest slot with Bold Text off and on (`StarterLabelFitTests`, `HomeLayoutEngineFontTests`, 2026-10-24) | UI: `HomeReachabilityTests`, `LaunchTests`. Audit. Device |
| `Font.TextStyle`, `ScaledMetric`, `DynamicTypeSize`, `dynamicTypeSize(_:)` | Text and spacing that grow with the setting | 1–4 | 13.0; 14.0; 15.0 | **In place**: text styles, and Settings' gear where it shows alone on Home (`@ScaledMetric`, 2026-10-23). Other non-text sizes with `@ScaledMetric`: **R0-3**; the layout engine sizes Home's controls from one line of their words at the person's size instead (`HomeLayout.Text`, 2026-10-23), and Home uses it since 2026-10-24. Never a cap on Home or Settings | Unit: the fitting type at every size. UI |
| `accessibilityShowsLargeContentViewer(_:)` | A large copy of a label that cannot grow | 1–2 | 15.0 | **In place** only for Settings' gear where it shows alone on Home (PR #33, 2026-10-23); Settings never speaks. Measured there (iPhone Duo's outer display, Bold Text, AX5, 2026-10-23): a tap opens Settings; a held press, lifted or slid onto a neighbour, opens and changes nothing. **Never on Home's other controls** (measured on Yes, No and the phrase tiles, 2026-10-23): at AX5, a test build with the viewer on them said nothing for a press on Yes of 0.2 s or longer, a half-second press on No or a tile, or a held slide; it never activated the control a slide ended on. That breaks invariant 2 for slow presses (docs/DECISIONS.md, "Show Borders and the Large Content Viewer on Home") | Unit (the gear's layout). UI: `SlowPressTests` (a half-second press on Yes and on a tile speaks at AX5; a slide from Yes onto No never says No). Opt-in probe: `HeldSlideProbeTests`. Device, not yet run: a real finger, Hold Duration and Dwell (docs/HANDOFF.md, *Checks that need a real device*) |
| Bold Text (`legibilityWeight`) | Heavier text | 1–4 | 13.0 | **In place** through system fonts; the fitting type measures at a weight never narrower than the one drawn (PR #22). Home's safety row, categories and Settings take wider minimum widths with Bold Text on, checked with Bold Text on and off (`HomeLayout.MinimumWidths`, 2026-10-24); on 375 and 390pt phones Settings shows its gear alone, so Bold Text never adds a row above the phrases (`HomeLayoutEngineTests`). Phrase tiles with Bold Text on: **in place** (2026-10-24): a tile's floor follows its width, every starter phrase is measured at each with Bold Text on, and 375 and 390pt phones take two columns | Unit (`StarterLabelFitTests`). Device |
| Increase Contrast (`colorSchemeContrast`) | Stronger contrast | 1–4 | 13.0 | **In place**: every fill measured in light, dark and Increase Contrast (invariant 6) | Unit: `PaletteTests`. Device: rendered pixels |
| Reduce Transparency (`accessibilityReduceTransparency`) | Solid instead of see-through | 1–4 | 13.0 | **In place** on Home (`HomeButtonStyle` draws opaque `Color` fills directly inside a `RoundedRectangle` with no materials); Settings and setup use `.borderedProminent` with measured tints. Rendered check across screens: **R0-9** | Device: rendered pixels with the setting on and off |
| Liquid Glass styles: `.glass`, `.glassProminent`, `glassEffect(_:in:)` | Apple's glass look | 1–4 | 26.0 | **Never on Home's speaking and safety controls**: their contrast would depend on what is behind them. The system's glass elsewhere (Figma and Claude Design screens) | Review |
| Liquid Glass look setting | Clearer or more tinted glass; a slider in iOS 27 | 1–4 | System, 26; slider 27 | **System.** System sheets and bars over Brickson stay readable | Device |
| Reduce Motion (`accessibilityReduceMotion`) | Fewer large animations | 1–4 | 13.0 | **In place**: Home has no custom animation. A motion policy when one is added: **R0-3** | Unit. Device |
| Prefer Cross-Fade Transitions: UIKit `prefersCrossFadeTransitions`; SwiftUI `accessibilityPrefersCrossFadeTransitions` | Fades instead of slides | 1–4 | 14.0; SwiftUI 26.4 **`#available`** | **R0-3**, with the motion policy; the UIKit value before 26.4 | Unit. Device |
| Differentiate Without Color (`accessibilityDifferentiateWithoutColor`) | Meaning not shown by colour alone | 1–4 | 13.0 | **In place**: a check mark and the Selected trait on the chosen category and on Emergency | UI. Device: Grayscale |
| Show Borders (`accessibilityShowBorders`, `@backDeployed(before: iOS 26.1)`; `AccessibilitySettings.showBordersEnabled`) | Visible edges on buttons | 1–4 | 14.0 (back-deployed); `AccessibilitySettings.showBordersEnabled` 26.1 **`#available`** | **In place** (2026-10-23): Home's button style draws a 2pt primary-ink border inside every control's frame, a pressed ring twice as wide, and the selection ring in the screen's colour (`HomeButtonLook`). Settings and setup use the system's bordered style. `accessibilityShowButtonShapes` and UIKit's `buttonShapesEnabled` (deprecated in 26.1) are deprecated; never use them | Unit: `HomeButtonLookTests`; every ring colour on every fill in `PaletteTests`. Device: rendered, and Settings' system buttons |
| On/Off Labels | Shapes on switches, not just green | 1–3 | System; flag 13.0 | **R0-7**: standard toggles in Settings. Never a toggle for start and stop on Home (invariant 10) | UI. Device |
| Smart Invert, Classic Invert (`accessibilityInvertColors`, `accessibilityIgnoresInvertColors(_:)`) | Inverted colours | 1–4 | 13.0; 14.0 | **Later**: decide whether any image needs excluding (none today) | Device |
| Dark Mode (`colorScheme`) | The dark appearance | 1–4 | 13.0 | **In place**: system colours, audits in dark, the `--appearance` test option | Unit: `PaletteTests`. UI. Device |
| Dim Flashing Lights (`accessibilityDimFlashingLights`) | Dimming flashes in video | 1–4 | 17.0 | **N/A**: Brickson never flashes. Get Attention's look stays steady (**R0-4**) | Unit: a steady alarm style. Review |
| Reduce Bright Effects (`accessibilityReduceHighlightingEffects`) | Fewer bright highlights | 1–4 | 26.4 **`#available`** | **R0-4** and **R0-3**: pressed and alarm styles stay steady whatever the setting | Unit. Device |
| Auto-Play Animated Images | Stops animated images | 1–4 | 17.0 | **N/A**: no animated images | — |
| Zoom | A screen magnifier | 1–2 | System | **System.** Setup text: **in place**, in More Accessibility Settings, with the Accessibility Shortcut and Zoom Controller for when three-finger gestures are hard. No three-finger gestures in Brickson | Device |
| Display Zoom | A bigger interface in a smaller window | 1–3 | System | **R1**: layout tests at zoomed window sizes. Sizes come from the window, so no device table is needed. The layout engine's tests include the zoomed 320×568 phone and 1032×774 iPad windows (2026-10-23) | Unit. Device |
| Color Filters, Grayscale, Color Tint, Reduce White Point | Display filters | 1–4 | System | **System.** Nothing changes when a filter is on | Device |
| Per-App Settings | Brickson's own text size, contrast and motion | 1–4 | System, since 15.0 | **In place**: Brickson reads no global accessibility flag; display choices come from SwiftUI's environment and system styles, which follow the per-app values | Review. Device |

## 7. Device setup: Guided Access, Assistive Access, settings links and status

| API or feature | What it is for | Stage | iOS | Status in Brickson | Checked by |
|---|---|---|---|---|---|
| Guided Access | Locks the device to Brickson | 2–4 | System | **System.** Setup text, with its warnings: **in place**, in Keep Brickson Open, with keeping the Accessibility Shortcut during a session | Device: with each input method |
| `UIGuidedAccessRestrictionDelegate` | Brickson's own switches in Guided Access options | 2–4 | 7.0 | **Later**. Never one that can turn off speech, Emergency, Get Attention, Yes or No | Unit. Device |
| `isGuidedAccessEnabled`, `GuidedAccessStatusDidChangeMessage` | Whether a Guided Access session runs | 2–4 | 6.0; message 26.0 | **Later**, for setup text only. Never changes Home | Unit: `OffMainThreadCallbackTests` |
| `requestGuidedAccessSession(enabled:completionHandler:)` | An app locking the device itself | — | 7.0 | **Never**: only for supervised devices, and it could trap a person | — |
| `configureForGuidedAccess(features:enabled:completionHandler:)` | An app turning accessibility features on or off | — | 12.2 | **Never**: it could turn off the person's only way in | — |
| Assistive Access | A simplified iPhone and iPad | 2–4 | System, since 17.0 | **System.** Setup text: **in place**, in Keep Brickson Open: adding Brickson, leaving Assistive Access, and that most settings change only outside it | Device |
| `UISupportsFullScreenInAssistiveAccess` | Brickson full screen inside Assistive Access | 2–4 | 17.0 | **In place** (2026-10-23), and `UISupportsAssistiveAccess` stays absent | Unit: `AppBundleTests` (`assistiveAccessShowsBricksonFullScreenInItsOwnLayout`). Device: the window's size |
| `AssistiveAccess` scene, `UISupportsAssistiveAccess` | A separate, system-styled interface for Assistive Access | — | 26.0 | **Never** for the main interface: its controls would sit elsewhere (docs/DECISIONS.md, "Accessibility API coverage") | Unit: `AppBundleTests` checks the key is absent |
| `accessibilityAssistiveAccessEnabled`, `AccessibilitySettings.isAssistiveAccessEnabled` | Whether Brickson runs inside Assistive Access | 2–4 | 18.0 | **In place** (2026-10-23), the SwiftUI value: written Settings paths instead of links there, and a line saying to leave Assistive Access first. Never changes Home | Unit: `SettingsAppLinkTests`. Device |
| Accessibility Shortcut (triple-click) | Turns accessibility features on and off | 1–4 | System | **System.** Setup text: **in place**, in More Accessibility Settings, with Guided Access's and Assistive Access's own settings and the slower click speed | Device: reachable without pressing a button |
| `AccessibilitySettings.openSettings(for:)` | Opens Settings at one accessibility setting | 1–3 | 18.0; `.personalVoiceAllowAppsToRequestToUse` and `.captionStyles` 18.0; `.allowAppsToAddAudioToCalls` 18.2; `.dwellControl`, `.assistiveTouch` and `.assistiveTouchDevices` 26.0 | **In place**, from family setup only, never on Home, and never inside Assistive Access (`SettingsAppLink`, 2026-10-23) | Unit: `SettingsAppLinkTests`. Review: a failed open shows text. Device: where each link lands |
| `AccessibilitySettings.canOpenSettings(for:)` | Whether a link will work | 1–3 | 26.4 **`#available`** | **In place**; before 26.4, the link is offered and a failure shows text | Unit: `SettingsAppLinkTests` |
| `isVoiceOverRunning`, `isSwitchControlRunning`, `isAssistiveTouchRunning` and their notices | Whether an assistive technology is on | 1–4 | 4.0; 8.0; 10.0; typed messages 26.0 | **R1**: may suggest a profile, never switch it (docs/DECISIONS.md) | Unit: the suggestion never changes the profile. Device: which flags each input method sets |
| `accessibilityEnabled`, `accessibilityVoiceOverEnabled`, `accessibilitySwitchControlEnabled` | The same, in SwiftUI | 1–4 | 13.0; 15.0 | **R1**, same rule; never read by Home's layout | Unit |
| Voice Control, Eye Tracking, Head Tracking, Dwell, Full Keyboard Access status | Whether they are on | — | — | **N/A**: Apple offers no flag; the family chooses the profile | — |
| Share Accessibility Settings | One person's settings on another device for a while | 1–2 | System, 26 | **System.** A setup note: **in place**, in More Accessibility Settings | Device |
| `UIApplication.isIdleTimerDisabled` | The screen never locks | 1–4 | 2.0 | **In place** (`ScreenWakePolicy`; invariant 12) | Unit: `ScreenWakePolicyTests`. Device |
| Auto-Lock, and Guided Access's Display Auto-Lock | The system's own lock timers | 1–4 | System | **System.** Setup text: **in place**, in Keep Brickson Open's *Screen lock*: Low Power Mode's 30 seconds, and Display Auto-Lock at the longest time offered | Device: whether Guided Access locks the screen anyway |

## 8. Typing

| API or feature | What it is for | Stage | iOS | Status in Brickson | Checked by |
|---|---|---|---|---|---|
| Typing on Apple's keyboard by eye, head or dwell (Zoom on Keyboard Keys, Key Dwell Time, Extended Predictions) | Faster pointer typing | 2–3 | System, 18.0 and 26 | **In place** (R0-5): Home types with Apple's keyboard. Gaze and head typing sizes: **R1** | UI: the keyboard probe. Device |
| Slide to Type with the dwell pointer | Drawing a word with the pointer | 1–3 | System, 26.0 (iPhone) | **System.** The composer takes whole-word changes: **in place** (R0-5) | Unit. Device |
| Hover Typing | A larger copy of what is typed | 1–3 | System, since 18.0 | **System.** A standard text field: **in place** (R0-5) | UI. Device: it never covers the quick controls |
| Key Repeat, Slow Keys, Sticky Keys | Physical-keyboard settings | 1–2 | System | **System.** Return speaks once: **in place** (R0-5) | Unit. Device |
| QuickType and inline predictions | Apple's word suggestions | 1–3 | System; inline 17.0 | **In place** (R0-5), left on (Typing foundation's decision) | UI: the keyboard height includes the bar. Device |
| `inlinePredictionType` | Turning inline predictions off in one field | 2–3 | 17.0 (UIKit) | **Later**, only if a device check shows they confuse gaze typing | Unit |
| `autocorrectionDisabled`, `textInputAutocapitalization`, `keyboardType` | How Apple's keyboard behaves in the field | 1–3 | 13.0; 15.0; 13.0 | **In place** (R0-5): sentences capitalized and the default keyboard, autocorrection left on (`typingFieldTraits()`) | UI |
| `submitLabel`, `onSubmit`, or a typed line break | Return speaks | 1–3 | 15.0 | **In place** (R0-5, "Return speaks"): a typed line break | Unit. UI. Device |
| Writing Tools; `writingToolsBehavior(_:)` | Apple Intelligence rewriting text | 1–3 | 18.0 | **In place** on Home's field (R0-5, "Writing Tools off while typing"), and the phrase editor: **R0-6**. Brickson never rewrites what a person says (invariant 9) | Review. Device |
| Write with Siri | Siri composes or rewrites selected text | 1–3 | System, 27.0 | **System.** A device check of whether it can reach Brickson's field | Device |
| `UIConversationContext`, `UITextInputDelegate.conversationContext(_:didChange:)` | Giving the keyboard a conversation for smart replies | — | 18.4 | **Never**: it invites system-written replies | Review |
| `application(_:shouldAllowExtensionPointIdentifier:)` | Refusing third-party keyboards | 1–3 | 8.0 | **In place** (R0-5): `BricksonAppDelegate`, through `UIApplicationDelegateAdaptor`, refuses custom keyboards only ("Third-party keyboards refused in 1.0") | Unit: `BricksonAppDelegateTests`, the running app's delegate included. Device: a third-party keyboard does not appear |
| `ignoresSafeArea(_:edges:)` with `.keyboard` | Nothing moves when the keyboard shows | 1–3 | 14.0 | **In place** on Home and Settings (R0-5, invariant 11) | UI: frames equal before and after the keyboard (`TypingOnHomeTests`) |
| Keyboard frame notices, `UIKeyboardLayoutGuide` | Measuring the real keyboard | 1–3 | 3.2; 15.0 | **Not used**: the keyboard probe reads SwiftUI's own keyboard edge instead, and the room Home keeps is a tested rule (`KeyboardAllowance`, R0-5) | UI: `KeyboardProbeTests` on every UI run. Device: real keyboard heights |
| `GCKeyboard.coalesced` | Whether a hardware keyboard is connected | 1–2 | 14.0 | **Later**, only if the layout needs it. Never moves a control | Unit. Device |
| Dictation | Speech to text in the field | 1–2 | System; clean-up 27 | **System.** The composer accepts whole-field changes: **in place** (`MessageField`, `MessageComposer`, R0-5), and the privacy policy explains on-device and server-assisted Dictation settings | Unit: `MessageComposerTests`. UI: `TypingOnHomeTests`, `SettingsTests`. Device |
| `UITextChecker.completions(forPartialWordRange:in:language:)` | Word endings from a word list, no model | 2–3 | 3.2 | **R2** prediction strip, in fixed slots | Unit: slots never re-sort by use. Device |
| `textInputSuggestions`, `textInputCompletion` | SwiftUI completions | — | macOS 15 only | **N/A** on iOS | — |
| `isKeyboardKey` trait | Brickson's own keys acting as keys | 3 | 13.0 | **Later**, only if Brickson ever builds its own keys | UI. Device |
| Foundation Models (`SystemLanguageModel`) | On-device generated text | — | 26.0 | **Never**: no AI-generated replies (invariant 9) | Review |

## 9. Testing and the App Store

| API or feature | What it is for | Stage | iOS | Status in Brickson | Checked by |
|---|---|---|---|---|---|
| Accessibility Nutrition Labels | The App Store's list of supported features | 1–4 | Shown on 26 | **R0-10**: the nine labels, the evidence each needs and the 1.0 proposal are in [`APP-STORE.md`](APP-STORE.md), section 4 | Store. Device runs before VoiceOver and Voice Control are claimed |
| Accessibility URL | A page on the product page for input methods without a label | 1–4 | — | **In place** (2026-10-23): [`site/accessibility/`](../site/accessibility/index.html) says what is in place for each input method and display setting, how each was checked, and that nothing has yet been checked on a real device (APP-STORE.md, section 4). Entering the URL in App Store Connect: **R0-10** | Unit: `scripts/test-site.py` (every page links to it, no price words). Store |
| `XCUIApplication.performAccessibilityAudit(for:_:)` | Apple's automatic audit in UI tests | 1–4 | 17.0 | **In place** on Home, light and dark (and at the largest text size), while Typing is open (`TypingOnHomeTests`), and while Get Attention sounds, light (at the default and the largest text sizes, and at the default size in landscape on the iPad); on the emergency phrases and Voice Settings, light; on Settings' first screen, Family Setup and the privacy policy, light and dark (checked 2026-10-23); on every Family Setup guide, each step of Set Up Step by Step and About, light (2026-10-23). Each new screen adds one (R0-6) | UI |
| Accessibility Inspector | The Mac tool that inspects elements | 1–4 | Xcode | Used on Mac runs. Never presented as proof of gaze or Snap to Item | — |
| `-UIPreferredContentSizeCategoryName` launch argument | Starting a UI test at a text size | 1–4 | Not documented by Apple | **In place** (`launchedApp`); the largest-size tests show it takes effect | UI |
| `XCUIDevice.appearance`, and Brickson's `--appearance` option | Light or dark in UI tests | 1–4 | 15.0 | **In place** through `--appearance`, because `XCUIDevice.appearance` proved unreliable (AGENTS.md, *Gotchas*) | UI: a screenshot sample checks the rendered colour |
| Increase Contrast, Reduce Motion, Reduce Transparency, Bold Text in UI tests | Running UI tests with these on | 1–4 | No documented API | Contrast at unit level (`PaletteTests`); the rest by device check | Device |
| `XCUIDevice.voiceOverService` (`XCUIVoiceOverService`) | Driving VoiceOver in a UI test (instance property on `XCUIDevice`) | 1–4 | 27.0 **`#available`** (Xcode 16.3+) | **R0-2 follow-up**: a VoiceOver walk of Home on the iOS 27 simulators, once Home's slots land (R0-3) | UI. Device: the spoken order matches |

## 10. Outside the screen: alerts, recordings, the home and the watch

| API or feature | What it is for | Stage | iOS | Status in Brickson | Checked by |
|---|---|---|---|---|---|
| Get Attention (`AttentionAlertPlayer`) | A start-only alarm, with Stop elsewhere | 3–4 | — | **In place** on Home (R0-4): Get Attention under Emergency, Stop in its own well with a category under it. In Settings: scored 2026-10-24 and not added, because its place would sound the alarm unasked; the owner decides (docs/DECISIONS.md, "Get Attention in Settings' bar: the owner decides") | Unit: `AttentionAlertPlayerTests`, `HomeLayoutEngineTests` (what a held look meets). UI: `GetAttentionOnHomeTests`. Device: heard from the next room |
| Emergency SOS | The iPhone's own emergency call | 1–2 | System | **N/A**: no public API to start it was found, and Brickson's Emergency never calls anyone | Review |
| Recorded phrases: `AVAudioPlayer`, `fileImporter` | Playing and importing a person's own recordings | 1–4 | 2.2; 14.0 | **R1** "Recorded phrases, first two stages" | Unit: a missing file speaks the text instead. Device |
| In-app recorder: `AVAudioRecorder`, `AVAudioApplication.requestRecordPermission`, `NSMicrophoneUsageDescription` | Banking messages inside Brickson | 1–2 | 3.0; 17.0; 7.0 | **R2** "The in-app recorder" | Unit. Device: recording never disturbs speech or calls |
| AlarmKit (`AlarmManager`) | System alarms that sound when the app is closed | 3–4 | 26.0 | **N/A for 1.0**: Get Attention plays inside Brickson and needs no permission. Revisit if it must sound with Brickson closed | Review |
| Critical alerts | Notifications that sound through the silent switch | 3–4 | 12.0 | **N/A**: Brickson sends no notifications | — |
| Caregiver alerts over the local network: Multipeer Connectivity, Bonjour (`NSLocalNetworkUsageDescription`), Wi-Fi Aware | Reaching a phone in another room | 3–4 | 7.0, deprecated 27.0; 14.0; 26.0 | **Not in 1.0**: network code is a hard stop (invariant 9) and the owner's decision (docs/DECISIONS.md, *Caregiver alerts*) | — |
| HomeKit: `HMHomeManager`, `NSHomeKitUsageDescription` | Lights, doors and thermostat from a tile | 2–3 | 8.0 | **Not in 1.0**: it controls devices beyond the iPhone or iPad, so whether it may be built at all is the owner's decision under invariant 9, as for caregiver alerts (docs/DECISIONS.md, *Accessibility API coverage*). If the owner records an exception: a work file first, a permission, an entitlement and a privacy-policy section, and its tiles count as position-changing for dwell scoring | Review |
| Live Speech on Apple Watch | Type-to-speak on the wrist | 1–2 | watchOS 10 | **System.** Setup text: **in place**, in Calls, Siri and Shortcuts | Device |
| AssistiveTouch on Apple Watch | Hand gestures for the watch | 1–2 | watchOS 8 | **System**; nothing until a watch app exists | — |
| A Brickson watch app | A few phrases and Get Attention on the wrist | 1–2 | watchOS 10 (Personal Voice) | **Later**. Moving phrases to the watch needs a decision, since there is no iCloud sync | — |
| iPhone Duo: `ReservedRegion`, `reservedRegions(kind:options:layoutDirectionBehavior:)`, `onHingeChange(isEnabled:_:)` | Keeping controls off the hinge and the camera | 1–4 | 27.1 **`#available`** | **R0-13** "Ready for iPhone Duo": the layout engine takes reserved regions as part of the space available, keeping Home's controls off the fold and its column count even on a display that folds (docs/DECISIONS.md, "iPhone Duo", *The fold*). Item 6 now allocates Home from typed division/occlusion rectangles, including inactive regions, using even phrase lanes and fixed viewport clipping (2026-10-25, local PR #58). Static controls and cropped tiles clear the raw rectangles in six native pose diagnostics; full AX tile camera overlaps beyond the viewport and existing AX5 Settings row/fold intersections remain. `onHingeChange` drives nothing (same entry) | Unit: `HomeReservedRegionTests`, Home/Settings chain regressions. [Native geometry and limits](evidence/2026-10-25-duo-design/native-frame-comparison.md); earlier local ordinary UI suites failed a Speaking-wait case also reproduced on main; earlier `35bed06` hosted unit/UI checks pass. The AX3 growth correction has two focused light/dark native passes and a green 778-case native unit gate; its full standard UI run completed 51 cases per family with one failed AX5 Speaking-wait case each and no other unexpected assertion. AX3 tall-to-wide typing retains a visible keyboard on baseline and candidate; a baseline-only trace reports focus false, with cause unresolved. The same PR's verified short-drag speech bug is repaired through standard ScrollView pan handling; [counterfactual evidence](evidence/2026-10-26-pr58-drag/original-counterfactual.json) does not select or validate the private AX5 capacity alternative. The owner-authorized extra batch has a failing-first light/dark iPad renderer reproduction (0 passed / 2 failed, eight intended assertions) with a synthetic top reservation. The renderer now consumes the engine's initial first-region top inset without changing allocation or floors; guaranteed-fitting native checks are strengthened. The affected iPad selection passes 10/10 with seven retained runtime audio diagnostics, and 40 ordinary zero-inset frame comparisons match exactly. The fitting-guard mutation is detected before input. The affected final iPhone selection passes 10/10, and full units pass 781 total with zero failures and a current catalog; the allocator mathematics are unchanged. The final affected Duo selection passes 7/7 (no failures/skips/expected failures, seven retained runtime audio warnings) on actual OS space in the opposite tall open/flat 180-degree pose; coordinate and default fitting guards pass. New-head hosted CI and review resolution remain pending at the recorded pre-push checkpoint ([plan and evidence](work/layout-engine.md#owner-authorized-renderer-and-fitting-test-review-batch)). These synthetic checks do not establish a real OS fold pose. Physical fold/input, clipping/Snap and camera dark-area match remain unverified; broader R0-13 Settings/setup is open |

## Newer than iOS 26.0

Everything else above works on iOS 26.0. These need `#available`, with
the fallback given:

| API | iOS | Fallback before it |
|---|---|---|
| `AccessibilitySettings.showBordersEnabled`, `prefersActionSliderAlternative` | 26.1 | SwiftUI's `@Environment(\.accessibilityShowBorders)` is `@backDeployed(before: iOS 26.1)` to 14.0; Home draws borders in every state (`HomeButtonLook`) and never uses slide-to-act controls |
| `AccessibilitySettings.canOpenSettings(for:)` | 26.4 | Offer the link and show the written Settings path if opening fails |
| `EnvironmentValues.accessibilityPrefersCrossFadeTransitions` | 26.4 | UIKit's `UIAccessibility.prefersCrossFadeTransitions` (14.0) |
| `EnvironmentValues.accessibilityReduceHighlightingEffects`, `AccessibilitySettings.isReduceHighlightingEffectsEnabled` | 26.4 | Nothing needed: Brickson's styles are steady anyway |
| `AVAudioSession.didBecomeInactiveNotification` (in place), `didBecomeActiveNotification`, `resumptionRecommendationNotification` | 27.0 | `interruptionNotification` (in place) |
| `AVAudioSession.activate(options:completionHandler:)` | 27.0 on iOS | `setActive(_:options:)` (in place) |
| `XCUIDevice.voiceOverService`, `XCUIVoiceOverService` | 27.0 (Xcode 16.3+) | Test code only; skipped on older simulators |
| `IntentExecutionTargets`, `allowedExecutionTargets` | 27.0 | Not needed until Controls exist |
| `GestureInputKinds`, `NavigationTransition.crossFade`, `UIDragInteraction.allowsPointerDragBeforeLiftDelay` | 27.0 | Standard button taps and `UIAccessibility.prefersCrossFadeTransitions` |
| `ReservedRegion`, `GeometryProxy.reservedRegions(…)`, `onHingeChange(isEnabled:_:)` | 27.1 | Only folding iPhones have a hinge, and they run 27.1 or later |
| Voice Control flexible item names; Write with Siri; Dictation clean-up; the Liquid Glass slider | System, 27.0 | System features with no app code |

None of them needs a minimum above 26.0, so the deployment target stands
(docs/DECISIONS.md, "Minimum iOS, iPhone and iPad").

## New since this list was written

Audited on 2026-10-27 against Apple's framework update pages
(`https://developer.apple.com/documentation/updates/{accessibility,swiftui,uikit,avfaudio,appintents,xcuiautomation}.md`)
and individual `.md` symbol pages on `developer.apple.com`:

| API or feature | Framework and iOS | What it does | What Brickson should do with it |
|---|---|---|---|
| `AccessibilitySettings.prefersActionSliderAlternative`, `prefersActionSliderAlternativeDidChangeNotification` | `Accessibility`, 26.1 **`#available`** | Reports whether the person prefers single-tap or button alternatives to slide-to-act controls | **Already followed by design**: Brickson never uses a slide-to-act gesture (invariant 1). If any future caregiver confirmation considers a slider, use buttons instead |
| `AccessibilitySettings.showBordersEnabled`, `showBordersEnabledStatusDidChangeNotification` | `Accessibility`, 26.1 **`#available`** | Imperative replacement for `UIAccessibility.buttonShapesEnabled` (deprecated in 26.1), paired with SwiftUI's `@backDeployed(before: iOS 26.1)` `@Environment(\.accessibilityShowBorders)` | **In place on Home** through `HomeButtonLook` and `@Environment(\.accessibilityShowBorders)` (section 6); never call deprecated `buttonShapesEnabled` |
| `AccessibilitySettings.isReduceHighlightingEffectsEnabled`, `reduceHighlightingEffectsEnabledDidChangeNotification` | `Accessibility`, 26.4 **`#available`** | Imperative counterpart to SwiftUI's `@Environment(\.accessibilityReduceHighlightingEffects)` | **Note for R0-9**: available in non-view code if needed alongside `@Environment(\.accessibilityReduceHighlightingEffects)` |
| `AccessibilitySettings.isApplicationAccessibilityEnabled`, `applicationAccessibilityEnabledDidChangeNotification`, `ApplicationAccessibilityEnabledDidChangeMessage` | `Accessibility`, 26.0 | Reports whether an assistive client is actively querying the app's accessibility tree | **Diagnostic only**: Brickson keeps its full accessibility hierarchy and sort order active at all times rather than gating behaviour on whether a client is attached |
| `AccessibilitySettings.Feature.assistiveTouchDevices`, `.captionStyles` | `Accessibility`, 26.0; 18.0 | Additional deep-link cases for `AccessibilitySettings.openSettings(for:)`: `.assistiveTouchDevices` opens `AssistiveTouch > Devices` (switches, pointers, game controllers); `.captionStyles` opens `Subtitles & Captioning > Style` | **Candidate for setup guides**: `.assistiveTouchDevices` can link families straight to external pointer or joystick setup in `Reaching the Screen` |
| `View.accessibilityLabel(content:)` | `SwiftUI`, 18.0 | Closure modifier (`accessibilityLabel { label in … }`) that wraps or appends to SwiftUI's default label instead of replacing it | **Candidate for R0-6**: lets a control keep its visible words first while appending edit-mode context without repeating strings |
| `View.accessibilityDirectTouch(_:options:)` (`.silentOnTouch`, `.requiresActivation`), `View.accessibilityZoomAction(_:)` | `SwiftUI`, 17.0 | VoiceOver direct-touch pass-through and custom Zoom rotor actions | **Not used**: standard VoiceOver focus and double-tap activation are more predictable for scanning and low-vision users |
| `HoverEffectGroup`, `View.hoverEffect(in:isEnabled:body:)`, `View.pointerStyle(_:)`, `View.pointerVisibility(_:)` | `SwiftUI`, 18.0 | Coordinated pointer or gaze hover highlights across grouped subviews and custom pointer shapes | **Not needed on Home**: each Home button is a single self-contained target with `.hoverEffect(.highlight)` (`HomeButtonStyle`) |
| `GestureInputKinds` (`.directTouch`, `.indirectTouch`, `.pencil`, `.pointer`) | `SwiftUI`, 27.0 **`#available`** | Restricts which physical input mechanisms a gesture recognizer responds to | **Candidate for R0-6**: if phrase reordering ever uses drag gestures alongside Move Up / Move Down buttons, `GestureInputKinds` (or UIKit's `UIDragInteraction.allowsPointerDragBeforeLiftDelay`, 27.0) can keep pointer and dwell input separate |
| `NavigationTransition.crossFade` | `SwiftUI`, 27.0 **`#available`** | Built-in cross-fade navigation transition | **Candidate for R0-3 / R0-9**: pairs with `accessibilityPrefersCrossFadeTransitions` and `accessibilityReduceMotion` under `#available(iOS 27.0, *)` |
| `ArrangementView`, `UIArrangementViewController`, `toolbarVerticalEdge`, `toolbarVerticalBehavior(_:)` | `SwiftUI` / `UIKit`, 27.1 **`#available`** | Adaptive split container and vertical-axis toolbars introduced alongside `ReservedRegion(.hinge)` for iPhone Duo | **Not needed on Home**: `HomeView` uses the single tested `HomeLayout` engine (invariant 11) |
| Strongly-typed `NotificationCenter.MainActorMessage` types on `UIAccessibility` (`VoiceOverStatusDidChangeMessage`, `SwitchControlStatusDidChangeMessage`, `AssistiveTouchStatusDidChangeMessage`, `AnnouncementDidFinishMessage`, `ReduceMotionStatusDidChangeMessage`, `ReduceTransparencyStatusDidChangeMessage`) | `UIKit`, 26.0 | Type-safe, `@MainActor`-isolated messages replacing untyped `Notification` names (`GuidedAccessStatusDidChangeMessage` is already in section 7) | **Note for R0-9 and R1**: `AnnouncementDidFinishMessage` can confirm on a device whether a high-priority `AccessibilityNotification.Announcement` finished speaking or was cut off |
| `UIMainMenuSystem` | `UIKit`, 26.0 | Configures the iPadOS swipe-down and hardware-keyboard menu bar | **Later (R1 keyboard profile)**: Full Keyboard Access and Switch Control users on iPad already reach every Home button through the accessibility tree |
| `AVAudioSession.DidBecomeActiveMessage`, `DidBecomeInactiveMessage`, `ResumptionRecommendationMessage`, `DeactivationContext`, `InterruptionContext`, `ResumptionContext` | `AVFAudio`, 27.0 **`#available`** | Strongly-typed `NotificationCenter` messages and context payloads for the iOS 27 audio session life cycle | **Evaluate in R0-9** under `#available(iOS 27.0, *)` alongside `didBecomeInactiveNotification` in `AudioSessionEvents` |
| `AVAudioSession.prefersNoInterruptionsFromSystemAlerts`, `setPrefersNoInterruptionsFromSystemAlerts(_:)` | `AVFAudio`, 14.5 | Requests that incoming system alert tones not interrupt the active audio session | **Evaluate on a device**: check whether setting `setPrefersNoInterruptionsFromSystemAlerts(true)` while speaking a phrase or sounding Get Attention keeps notification chimes from cutting speech off |
| `AVAudioSession.isOutputMuted`, `outputMuteStateChangeNotification`, `userIntentToUnmuteOutputNotification` | `AVFAudio`, 17.0 | Reports system output mute state and user unmute actions alongside `outputVolume` | **Evaluate on a device**: `AudioSafetyMonitor` already watches `outputVolume`; check on iPhone and iPad hardware whether `isOutputMuted` surfaces any mute state not reflected in `outputVolume` |
| `LongRunningIntent`, `CancellableIntent`, `UndoableIntent`, `RunSystemShortcutIntent`, `IndexedEntityQuery`, `IntentSystemContext.currentMode` | `AppIntents`, 27.0 **`#available`** | New intent execution protocols and context inspection in iOS 27 | **Later (R2)**: `LongRunningIntent` and `CancellableIntent` are relevant if a future Shortcut starts Get Attention |
| `XCUIDevice.Button.volumeUp`, `.volumeDown` in Simulator | `XCUIAutomation`, 26.0 | Presses hardware volume buttons in iOS Simulator UI tests | **Useful for UI tests**: lets Simulator UI tests step hardware volume down and back up to exercise `AudioSafetyMonitor`'s low-volume warning |

## Keeping this list current

- A pull request that adopts, changes or drops an API here edits its row
  in the same pull request, and its *Checked by* names the real test.
  Where that makes a sentence of the website's accessibility page
  (`site/accessibility/index.html`) untrue, or adds something in place
  worth telling families, it edits the page and its "Last updated" date
  too.
- When Apple ships a new major iOS, the pull request that moves Brickson
  to the new Xcode also reads Apple's accessibility, SwiftUI, UIKit,
  AVFAudio and App Intents update pages
  (`https://developer.apple.com/documentation/updates/<framework>.md`) and
  adds what is new (docs/DECISIONS.md, "Build with Apple's current Xcode").
- Device results go in a `docs/log/` file and the handoff's device table,
  then the row here says what was found.
