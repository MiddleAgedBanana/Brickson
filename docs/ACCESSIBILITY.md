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

**Checked on 2026-10-21** against Apple's developer documentation (each
symbol page read in its Markdown form, which carries the availability
data), Apple's user guides and the 2026-10-15 research
([`docs/recon/`](recon/README.md)). Brickson's status is as of `main` on
that date. How the check was done, and what it could not settle, is in
[`log/2026-10-21-accessibility-coverage.md`](log/2026-10-21-accessibility-coverage.md).

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
| Listen for Atypical Speech (1; system) | System | Setup text: R0-7 | 3 |
| Siri and App Intents (1; add) | Nothing yet | R2 "Siri and Shortcuts", fixed phrases only | 3 |
| Vocal Shortcuts (1; system) | System | Setup text: R0-7; a Get Attention shortcut to point it at: R2 | 3 |
| Dynamic Type, Bold Text, Reduce Motion (1; has it) | Text styles on Home; UI tests at the largest size | Word fitting: R0-3 | 6 |
| Phrase board and typing (2; has it) | The board is on Home; typing is not on `main` yet | Typing: R0-5. A touch profile: R1 | 8 |
| Live Speech (2; system) | System | Setup text: R0-7. Being heard on calls: R0-8, held | 4 |
| Voice Control (2; has it) | Every Home control is a labelled standard button | Extra spoken names and a name-collision test: R0-3 | 3 |
| AssistiveTouch, Touch Accommodations (2; system) | Standard buttons | Setup text: R0-7 | 2 |
| Word prediction (2; add) | Nothing yet | Apple's keyboard suggestions with typing: R0-5. A prediction strip: R2 | 8 |
| HomeKit (2; add, needs a decision) | Nothing yet | Not in 1.0; controlling devices beyond the iPhone or iPad is the owner's decision under invariant 9 | 10 |
| Apple Watch (2; system, a watch app later) | System | Live Speech on the watch in the setup text: R0-7. A watch app: Later | 10 |
| Text size, contrast (2; has it) | Contrast measured in `PaletteTests` | Kept | 6 |
| Eye Tracking and Dwell (3; has it) | Standard buttons; repeats of a phrase absorbed | Gaze profile and dwell-safety scoring: R1 | 2 |
| Head Tracking (3; system) | System | Head profile: R1. Setup text: R0-7 | 2 |
| Switch Control (3; system) | Standard buttons | A fixed scan order with the quick controls first: R0-3. Switch profile: R1 | 1 |
| Guided Access (3; system) | System | Setup text: R0-7, and a device check with Eye Tracking | 7 |
| Assistive Access (3; add) | Nothing yet | Full screen in Assistive Access: R0-7 | 7 |
| Get Attention and Emergency (3; has it) | Emergency on Home; Get Attention built, not yet on screen | Get Attention and Stop on Home: R0-4, after Home's slots (R0-3) | 4, 5 |
| Alert someone in another room (3; add, needs a decision) | Sound in the room only | Not in 1.0; anything that reaches another device is the owner's decision | 10 |
| Screen never locks (3; has it) | In place | Kept | 7 |
| Audio safety (3; has it) | In place | Device checks | 4 |
| Brain-computer interfaces through Switch Control (4; system) | Standard buttons | Covered by the scan-order work (R0-3, R1) | 1 |
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
| The reference app's two safety bugs: the keyboard covering Get Attention, and a crash deleting a category (all; must fix) | Not ported; each became a rule | Typing never hides the call for help (R0-5); never roll back a cascade delete (R0-6; docs/LESSONS.md) | 8 |

## 1. Switch Control, Full Keyboard Access and scan order

Switch Control moves a highlight through the screen and a switch press
chooses; Full Keyboard Access does the same with Tab and Space. Both
follow the accessibility tree, so every standard button is reachable. What
Brickson adds is order: with auto scanning, every item before Emergency,
Get Attention, Yes and No is waiting time, so they come first and stay in
the same place in the order in every state.

| API or feature | What it is for | Stage | iOS | Status in Brickson | Checked by |
|---|---|---|---|---|---|
| Switch Control: item scanning, auto scanning, timing | Running the device with one or two switches | 2–4 | System, since iOS 8 or earlier | **System.** Standard buttons: in place. Quick controls first in the scan order, the same in every state: **R0-3**. Setup advice (Auto Tap, scanning time, Ignore Repeat): **R0-7** | UI: Home's elements in order in every category and state. Device: scan steps to each quick control |
| Scanning groups (Group Items) | Choosing a region first, then an item in it | 3–4 | System | **R0-3**: Home's regions as containers. Whether a SwiftUI container becomes a scan group is not documented by Apple | UI: region order. Device: the groups Switch Control forms |
| Point scanning (Gliding Cursor), head and eye modes inside Switch Control | Picking a point instead of an item | 3–4 | System; the eye mode since iOS 26 | **R1** profile layout engine: switch, head and gaze floors | Unit: each profile's floors. Device: presses per control |
| Switch sources (external switch, screen, camera, sound, Back Tap, AirPods nod) | What counts as a switch | 2–4 | System | **System.** Setup text: **R0-7**. Brickson never reads switch hardware (invariant 9) | Device: Brickson's own speech does not fire a sound switch |
| Recipes, switch sets, saved gestures | A switch press that taps a fixed spot | 3–4 | System | **System.** Works because controls never move (invariant 8) | Unit: frames equal across states (R1 engine). Device: a saved tap on Yes still lands on Yes |
| Switch Control typing options (Scan Same Key After Tap, Always Tap Keyboard Keys, Extended Predictions) | Fewer presses per letter on Apple's keyboard | 2–3 | System, on the iOS 26 and 27 setup pages | **R0-5** keeps Apple's keyboard; setup text **R0-7** | UI: quick controls stay above the keyboard. Device: presses per letter |
| Brain-computer interface protocol | A brain implant acting as a switch | 4 | 26.0 | **System**, through Switch Control. Nothing beyond the scan-order work | Device: no hardware available; Switch Control item mode stands in |
| Full Keyboard Access | Running the device from a physical keyboard | 1–2 | System, since 13.4.1 | **System.** Standard buttons: in place. Focus order test: **R1** (keyboard and Voice Control profile) | UI: Tab order with `typeKey`. Device |
| Full Keyboard Access status | Knowing whether it is on | 1–2 | — | **N/A**: Apple offers no flag; the family chooses the profile | — |
| `accessibilityElement(children:)` | `.contain` makes a region; `.combine` merges passive text | 1–4 | 13.0 | **In place**: `.combine` on passive text only (Speaking indicator, warnings). `.contain` regions: **R0-3**. Never `.combine` or `.ignore` over buttons | UI: every control is its own button. Review |
| `accessibilitySortPriority(_:)` | Order among elements at the same level | 2–4 | 14.0 | **R0-3**, only if view order cannot put the quick controls first; never from usage (invariant 8) | UI: element order. Device: whether Switch Control and Full Keyboard Access follow it (Apple does not say) |
| `accessibilityRespondsToUserInteraction(_:)` | Telling the switch and keyboard cursor to skip passive text | 2–4 | 15.0 | **R0-3**, if a device check finds the cursor stopping on the message, the Speaking indicator or a warning. Never on a button | Device. Review |
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
| Eye Tracking | The front camera moves the pointer; dwell taps | 3–4 | System, since 18.0 | **System.** Standard buttons and the screen kept awake: in place. Gaze profile and dwell-safety scoring: **R1**. Setup text: **R0-7** | Unit: gaze floors, positions equal across profiles. Device: re-firing, Snap to Item |
| External eye trackers made for iPad | A tracker bar driving the AssistiveTouch pointer | 3–4 | System (iPad) | **System.** Setup text: **R0-7**. Brickson never talks to the tracker (invariant 9) | Device, with a tracker |
| Head Tracking | Head movement moves the pointer; expressions can act | 2–3 | System, since 26.0 | **System.** Head profile: **R1**. Setup text: **R0-7** | Unit: head floors. Device |
| Dwell Control (dwell time, Movement Tolerance, Fallback Action, hot corners) | A resting pointer taps | 2–4 | System, since 13.0 | **In place**: a repeat of the phrase still speaking is absorbed (`SpokenUtteranceTracker`). Dwell-safety scoring: **R1**. Get Attention start-only, Stop elsewhere: **R0-4** | Unit: `SpokenUtteranceTrackerTests`; chains of activations scored (R1). Device |
| AssistiveTouch menu, custom gestures, Sound Actions | Gestures and buttons for people who cannot make them | 2–4 | System | **System.** The starter library without scrolling, since each scroll is several menu trips: **R0-3** | Unit: layout fits without scrolling. Device: where the menu button rests over Home |
| Pointer devices and Pointer Control | Mouse, trackpad, joystick, head mouse | 1–3 | System, since 13.0 | **System.** Hit shapes on the custom button style: in place | Audit: hit regions. Device |
| Touch Accommodations (Hold Duration, Ignore Repeat, Tap Assistance) | Shaky or slow touches read as one tap | 1–2 | System | **System.** Setup text: **R0-7**. Brickson never adds its own delay or confirm step (invariant 2) | UI: a phrase speaks on the first tap (in place). Device |
| Back Tap | Tapping the back of an iPhone runs an action | 1–2 | System, since 14.0 | **System.** Can run a Brickson shortcut once **R2** ships them | Device |
| Hover Text | A larger copy of the text under the pointer | 1–2 | System, since 18.0 | **System.** Works because labels are real text | Audit. Device |
| `hoverEffect(_:)`, `contentShape(_:_:eoFill:)` | How a control looks and where it can be hit under a pointer | 1–3 | 13.4; 15.0 | **In place**: `contentShape` on the custom button style. Never act on hover alone | Audit: hit regions. Review |
| Custom eye, head or pointer tracking | Brickson's own camera or dwell code | 3–4 | — | **Never** (invariant 9) | Review |

## 3. Voice in: Voice Control and Siri

| API or feature | What it is for | Stage | iOS | Status in Brickson | Checked by |
|---|---|---|---|---|---|
| Voice Control | Running the device by voice ("Tap Yes", "Show numbers") | 1–2 | System, since 13.0 | **System.** Every Home control is a labelled standard button: in place. Setup text: **R0-7** | Audit (in place). Device: "Show numbers" numbers every control |
| Voice Control flexible item names ("say what you see") | Naming a control in your own words | 1–2 | System, 27.0 | **System.** Nothing to build; good labels are what it needs | Device |
| `accessibilityInputLabels(_:)` | Extra names to say or type, the visible words first | 1–2 | 14.0 | **R0-3** | Unit: every fixed control has its visible words among its names |
| Voice Control name collisions | Two visible controls answering to one name | 1–2 | — | **In place** for the starter set: no "Yes." or "No." tiles, unique category names (`StarterPhrasesTests`). A whole-screen collision test: **R0-3**; for a library a family has grown: **R0-6**. Never rename a person's phrase (invariant 7) | Unit. Device |
| Vocal Shortcuts | A person's own sound runs an action | 1–2 | System, since 18.0 | **System.** Setup text: **R0-7**. A Get Attention shortcut to run: **R2** | Device |
| Listen for Atypical Speech | Siri listens for a wider range of speech; Apple names ALS | 1–2 | System, since 18.0 | **System.** Setup text: **R0-7** | — |
| Siri and Type to Siri | "Open Brickson", by voice or typed | 1–2 | System | **System.** Opening the app works now. Fixed actions: **R2** | Device |
| `CFBundleSpokenName` | How text-to-speech says the app's name | 1–4 | 2.0 | **In place** (`APP_SPOKEN_NAME` in `project.yml`) | Unit: `AppBundleTests`. Device: VoiceOver reads the icon |
| `INAlternativeAppNames` | Other names Siri accepts ("Brick Son") | 1–2 | Info.plist key (no version on Apple's page) | **In place** in the Info.plist, but **not yet effective**: Apple says Siri recognizes alternative names only for apps with an Intents app extension, and Brickson has none. Revisit with **R2** | Unit: `AppBundleTests` (well-formed). Device: "Open Brick Son" |
| `AppIntent`, `supportedModes` | Actions Siri, Shortcuts and the Action button can run | 1–3 | 16.0; `supportedModes` 26.0 | **R2** "Siri and Shortcuts": Speak, Get Attention, Emergency, each through the same resolver as its button | Unit: an intent and its button do the same. Device: from the Lock Screen |
| `AudioPlaybackIntent` | Tells the system an intent plays sound, so Siri does not talk over it | 1–3 | 17.0 | **R2**, for Get Attention | Unit. Device |
| `IntentExecutionTargets` (`allowedExecutionTargets`) | Which process may run an intent | 1–3 | 27.0 **`#available`** | **Later**, only if Controls are built: the app itself, never an extension | Unit |
| `AppShortcutsProvider`, `AppShortcut`, `AppShortcutPhrase` | Ready-made Siri phrases that work after install | 1–3 | 16.0 | **R2**, fixed phrases only: no phrase words, as the privacy policy promises | Unit: phrases from a fixed list. Device |
| Action button | A side button on newer iPhones runs a shortcut | 1–2 | System (iPhone) | **System.** Setup text: **R0-7**. A Get Attention target: **R2**. Never the only way to a safety action | Device |
| `ControlWidget`, `ControlWidgetButton` | A button in Control Center, the Lock Screen or the Action button | 1–2 | 18.0 | **Later**: a start-only Get Attention button, never a toggle (invariant 10) | Unit. Device |
| Phrases as `AppEntity` | Letting Shortcuts list a person's phrases | — | 16.0 | **Never** while R2's fixed-phrases rule stands: the system would show the person's words | Review |
| Spotlight: `IndexedEntity`, `CSSearchableIndex` | Putting phrases in system search | — | 18.0; 9.0 | **Never**: a person's words stay out of system search | Review |

## 4. Speech out: the voice, the audio session and calls

| API or feature | What it is for | Stage | iOS | Status in Brickson | Checked by |
|---|---|---|---|---|---|
| `AVSpeechSynthesizer` | Apple's speech engine | 1–4 | 7.0 | **In place** (`SpeechService`, `SpeechSynthesizing`) | Unit: `SpeechServiceTests`, `SpokenUtteranceTrackerTests`. Device: sound |
| `AVSpeechUtterance` rate, pitch, volume, delays | How each phrase sounds | 1–4 | 7.0 | **In place**: rate in fixed steps (`SpeechRateSteps`); the voice picker: **R0-7**. Never a delay before speaking (invariant 2) | Unit: `SpeechRateStepsTests` |
| `usesApplicationAudioSession` | Speech uses Brickson's own audio session | 1–4 | 13.0 | **In place** (set to true in `SpeechSynthesizing`) | Review. Device: speech follows the session's silent-switch and interruption handling |
| `prefersAssistiveTechnologySettings` | Lets VoiceOver's voice settings replace the phrase's voice | 1–4 | 14.0 | **Not set, on purpose** (false): a phrase is for the listener, in the person's voice. A test pinning it: **R0-4** | Unit. Device: with VoiceOver on, a phrase still uses the Personal Voice |
| Voices: `speechVoices()`, `quality`, `voiceTraits`, `availableVoicesDidChangeNotification` | Listing voices and noticing new ones | 1–4 | 7.0; 9.0; 17.0; 17.0 | **In place** (`VoiceSelection`) | Unit: `VoiceSelectionTests`. Device: a downloaded voice appears without relaunch |
| `AVSpeechUtterance(ssmlRepresentation:)` | Pauses, emphasis and pronunciation by markup | 1–4 | 16.0 | **Later**. Never built from a person's words without escaping | Unit: bad markup still speaks. Device |
| `AVSpeechSynthesisIPANotationAttribute` | Saying a name the right way | 1–4 | 10.0 | **Later**. Never changes the person's text (invariant 7) | Unit. Device |
| `write(_:toBufferCallback:)` | Speech rendered into audio buffers | 1–2 | 13.0; with markers 16.0 | **N/A**: a Personal Voice is never written to a file (docs/DECISIONS.md) | Review |
| Personal Voice | A synthetic voice that sounds like the person | 1–2 | System, since 17.0 | **System.** Guidance in setup: **R0-7** | Device: create one and hear it in Brickson |
| `requestPersonalVoiceAuthorization`, `personalVoiceAuthorizationStatus` | Permission to speak in it | 1–4 | 17.0 | **In place**, asked at launch for now (docs/DECISIONS.md); explained before asking: **R0-7** | Unit: `VoiceSelectionTests`; `OffMainThreadCallbackTests` for the answer through `SpeechService`. Device |
| `AccessibilitySettings.Feature.personalVoiceAllowAppsToRequestToUse` | Opens the switch that lets apps ask | 1–4 | 18.0 | **R0-7**, in the voice picker when permission is denied | Unit: the settings-link resolver. Device |
| Live Speech | Apple's type-to-speak, also into calls | 1–3 | System, since 17.0 | **System.** Setup text: **R0-7**. No API to write its saved phrases was found, so families copy a few by hand | Device: Live Speech and Brickson do not cut each other off |
| Add Audio in Calls, `AccessibilitySettings.Feature.allowAppsToAddAudioToCalls` | The system switch for apps' audio in calls, and a link to it | 2–4 | System, 18.2; the link 18.2 | **R0-8**, held until a device build | Device: a real call heard on both ends |
| `AVAudioApplication.microphoneInjectionPermission`, `requestMicrophoneInjectionPermission(completionHandler:)` | Permission to add Brickson's speech to calls; on its own it adds nothing | 2–4 | 18.2 | **R0-8**, held | Unit: every permission state. Device |
| `AVAudioSession.setPreferredMicrophoneInjectionMode(_:)` with `.spokenAudio`, and `.none` to stop | The call that actually adds Brickson's speech to a call, made once permission is granted (Apple's sample, "Adding synthesized speech to calls") | 2–4 | 18.2 | **R0-8**, held | Unit: a setter that throws shows passive text and the phrase still speaks in the room (invariants 4 and 5). Device: the far end hears the phrase |
| `isMicrophoneInjectionAvailable`, `microphoneInjectionCapabilitiesChangeNotification`, `AVAudioSessionMicrophoneInjectionIsAvailableKey` | Whether a call that can take Brickson's speech is in progress | 2–4 | 18.2 | **R0-8**, held | Unit: the notice's value read into the call state. Device: a call starting and ending |
| `NSMicrophoneInjectionUsageDescription` | The sentence the system shows when asking | 2–4 | 18.2 (Apple's sample; no reference page) | **R0-8**, held | Unit: `AppBundleTests` once the request exists |
| `mixToTelephonyUplink` | An older way to send speech into a call | 2–4 | 13.0 | **N/A**: calls go through microphone injection | — |
| `.playback` category, with `.mixWithOthers` as a fallback | Speech with the silent switch on and the screen locked | 1–4 | 3.0 | **In place** (`AudioSessionCoordinator`; invariant 4) | Unit: `AudioSessionCoordinatorTests`. Device: silent switch |
| `.spokenAudio` mode | Speech, not music, to the system | 1–4 | 9.0 | **In place** | Unit. Device: another app's audio during a phrase |
| Life-cycle notices: `didBecomeInactiveNotification`, `didBecomeActiveNotification`, `resumptionRecommendationNotification` | The iOS 27 replacement for interruption notices | 1–4 | 27.0 **`#available`** | **In place** for `didBecomeInactiveNotification` (`AudioSessionEvents`; docs/DECISIONS.md, "Audio session notices"). The other two are not used: Brickson never resumes by itself | Unit: `AudioSessionEventsTests`. Device: a call during a phrase on iOS 27 |
| `interruptionNotification` | A call or Siri cut the audio | 1–4 | 6.0 | **In place**, alongside the iOS 27 notice | Unit. Device |
| `routeChangeNotification`, `mediaServicesWereLostNotification`, `mediaServicesWereResetNotification` | Headphones out; the audio system restarted | 1–4 | 6.0; 7.0; 6.0 | **In place** (`AudioSessionEvents`, `AudioSafetyMonitor`) | Unit: `AudioSafetyMonitorTests`, `AudioSessionEventsTests`. Device |
| `UIBackgroundModes` `audio` | Speech goes on when the screen locks | 1–4 | 4.0 | **In place** | Unit: `AppBundleTests`. Device |
| Read & Speak (Speak Screen, Speak Selection, Typing Feedback, Highlight Content) | The system reads text aloud | 1–2 | System | **System.** A setup note: **R0-7**. Never the way phrases are spoken | Device: Speak Screen and Brickson do not talk over each other |

## 5. VoiceOver

| API or feature | What it is for | Stage | iOS | Status in Brickson | Checked by |
|---|---|---|---|---|---|
| VoiceOver with standard controls | Apple's screen reader | 1–2 | System | **In place** on Home through standard buttons. A full VoiceOver pass on a device comes before the App Store label (APP-STORE.md, section 4) | Audit (in place). Device |
| `accessibilityLabel`, `accessibilityValue`, `accessibilityHint` | What an element is, its state, what it does | 1–4 | 14.0 to 16.0 | **In place**: labels on Home and the audio warning. Values and hints with Settings: **R0-7** | UI: controls found by label. Audit |
| Traits: `isButton`, `isSelected`, `isHeader`; `accessibilityHidden(_:)` | Kind and state; hiding decoration | 1–4 | 13.0; 14.0 | **In place**: Selected on the chosen category and on Emergency; decoration hidden. Headers: **R0-7** | UI: the Selected trait follows the choice |
| `startsMediaSession` trait | Asks VoiceOver to stay quiet while the control's sound plays | 1–2 | 13.0 | **R0-4**, after a device check of what VoiceOver does with synthesized speech | Device |
| `playsSound` trait | Tells VoiceOver a control makes its own sound | 1–2 | 13.0 | **R0-4**, on Get Attention when it reaches Home | Device |
| `accessibilityRotor`, `AccessibilityRotorEntry` | Jumping between categories or phrases | 1–2 | 15.0; 16.0 | **Later**. Never ordered by use (invariant 8) | Unit: entries in stored order. Device |
| `AccessibilityNotification.Announcement` with a priority | Telling a VoiceOver user about a sound problem without moving focus | 1–2 | 17.0 | **In place** (`AudioSafetyPolicy`, `HomeView`) | Unit: `AudioSafetyPolicyTests`. Device: heard once, in full |
| `AccessibilityNotification.ScreenChanged`, `LayoutChanged` | Moving VoiceOver to a new screen | 1–2 | 17.0 | **Not posted on Home, on purpose.** Typing and Settings decide for their screens (R0-5, R0-7) | Review. Device |
| `AccessibilityFocusState` | Reading or moving VoiceOver's focus | 1–2 | 15.0 | **Never on Home**: focus never moves when a phrase speaks or a warning shows | Review. Device |
| `accessibilityCustomContent`, `AXCustomContent` | Extra facts read on request | 1–2 | 16.0; 14.0 | **R1**: "recorded" on a recorded phrase's tile | Unit. Device |
| Accessibility Reader | A system reading view of any app's text | 1–2 | System, since 26.0 | **System.** Works because the setup guide is real text | Device |
| Braille displays, Braille Access, `AXBrailleTranslator` | Braille input and output | — | System; 26.0 | **N/A**: VoiceOver drives braille displays through standard controls; Brickson does not translate braille itself | Device, if a braille user joins TestFlight |
| `Text(verbatim:)` and the String Catalog | A person's words shown exactly; app words translatable | 1–4 | 13.0 | **In place** | Unit: the String Catalog check in CI. Device: a tile reads the person's exact words |

## 6. Display, text and motion

| API or feature | What it is for | Stage | iOS | Status in Brickson | Checked by |
|---|---|---|---|---|---|
| Larger Text and Larger Accessibility Sizes | The person's reading size | 1–4 | System | **In place**: text styles on Home; reachability, fixed frames and whole quick-control words checked at the largest size. Word fitting for phrases: **R0-3** | UI: `HomeReachabilityTests`, `LaunchTests`. Audit. Device |
| `Font.TextStyle`, `ScaledMetric`, `DynamicTypeSize`, `dynamicTypeSize(_:)` | Text and spacing that grow with the setting | 1–4 | 13.0; 14.0; 15.0 | **In place**: text styles. Non-text sizes with `@ScaledMetric`: **R0-3**. Never a cap on Home or Settings | Unit: the fitting type at every size. UI |
| `accessibilityShowsLargeContentViewer()` | A large copy of a label that cannot grow | 1–2 | 15.0 | **R0-3**, for any label the fitting type limits | Unit. Device |
| Bold Text (`legibilityWeight`) | Heavier text | 1–4 | 13.0 | **In place** through system fonts. Fitting measured in bold: **R0-3** | Unit. Device |
| Increase Contrast (`colorSchemeContrast`) | Stronger contrast | 1–4 | 13.0 | **In place**: every fill measured in light, dark and Increase Contrast (invariant 6) | Unit: `PaletteTests`. Device: rendered pixels |
| Reduce Transparency (`accessibilityReduceTransparency`) | Solid instead of see-through | 1–4 | 13.0 | **In place** in part: Home uses `.borderedProminent` with measured fills and no materials, but Apple does not say whether the system draws those fills fully opaque on iOS 26 and 27. A rendered check: **R0-9** | Device: rendered pixels with the setting on and off |
| Liquid Glass styles: `.glass`, `.glassProminent`, `glassEffect(_:in:)` | Apple's glass look | 1–4 | 26.0 | **Never on Home's speaking and safety controls**: their contrast would depend on what is behind them. The system's glass elsewhere (Figma and Claude Design screens) | Review |
| Liquid Glass look setting | Clearer or more tinted glass; a slider in iOS 27 | 1–4 | System, 26; slider 27 | **System.** System sheets and bars over Brickson stay readable | Device |
| Reduce Motion (`accessibilityReduceMotion`) | Fewer large animations | 1–4 | 13.0 | **In place**: Home has no custom animation. A motion policy when one is added: **R0-3** | Unit. Device |
| Prefer Cross-Fade Transitions: UIKit `prefersCrossFadeTransitions`; SwiftUI `accessibilityPrefersCrossFadeTransitions` | Fades instead of slides | 1–4 | 14.0; SwiftUI 26.4 **`#available`** | **R0-3**, with the motion policy; the UIKit value before 26.4 | Unit. Device |
| Differentiate Without Color (`accessibilityDifferentiateWithoutColor`) | Meaning not shown by colour alone | 1–4 | 13.0 | **In place**: a check mark and the Selected trait on the chosen category and on Emergency | UI. Device: Grayscale |
| Show Borders (`accessibilityShowBorders`) | Visible edges on buttons | 1–4 | 14.0 (back-deployed) | **R0-3**: the custom button style draws its border inside its frame. `accessibilityShowButtonShapes` and UIKit's `buttonShapesEnabled` are deprecated; never use them | Unit: the border colour in `PaletteTests`. Device |
| On/Off Labels | Shapes on switches, not just green | 1–3 | System; flag 13.0 | **R0-7**: standard toggles in Settings. Never a toggle for start and stop on Home (invariant 10) | UI. Device |
| Smart Invert, Classic Invert (`accessibilityInvertColors`, `accessibilityIgnoresInvertColors(_:)`) | Inverted colours | 1–4 | 13.0; 14.0 | **Later**: decide whether any image needs excluding (none today) | Device |
| Dark Mode (`colorScheme`) | The dark appearance | 1–4 | 13.0 | **In place**: system colours, audits in dark, the `--appearance` test option | Unit: `PaletteTests`. UI. Device |
| Dim Flashing Lights (`accessibilityDimFlashingLights`) | Dimming flashes in video | 1–4 | 17.0 | **N/A**: Brickson never flashes. Get Attention's look stays steady (**R0-4**) | Unit: a steady alarm style. Review |
| Reduce Bright Effects (`accessibilityReduceHighlightingEffects`) | Fewer bright highlights | 1–4 | 26.4 **`#available`** | **R0-4** and **R0-3**: pressed and alarm styles stay steady whatever the setting | Unit. Device |
| Auto-Play Animated Images | Stops animated images | 1–4 | 17.0 | **N/A**: no animated images | — |
| Zoom | A screen magnifier | 1–2 | System | **System.** Setup text: **R0-7**. No three-finger gestures in Brickson | Device |
| Display Zoom | A bigger interface in a smaller window | 1–3 | System | **R1**: layout tests at zoomed window sizes. Sizes come from the window, so no device table is needed | Unit. Device |
| Color Filters, Grayscale, Color Tint, Reduce White Point | Display filters | 1–4 | System | **System.** Nothing changes when a filter is on | Device |
| Per-App Settings | Brickson's own text size, contrast and motion | 1–4 | System, since 15.0 | **In place**: Brickson reads no global accessibility flag; display choices come from SwiftUI's environment and system styles, which follow the per-app values | Review. Device |

## 7. Device setup: Guided Access, Assistive Access, settings links and status

| API or feature | What it is for | Stage | iOS | Status in Brickson | Checked by |
|---|---|---|---|---|---|
| Guided Access | Locks the device to Brickson | 2–4 | System | **System.** Setup text, with its warnings: **R0-7** | Device: with each input method |
| `UIGuidedAccessRestrictionDelegate` | Brickson's own switches in Guided Access options | 2–4 | 7.0 | **Later**. Never one that can turn off speech, Emergency, Get Attention, Yes or No | Unit. Device |
| `isGuidedAccessEnabled`, `GuidedAccessStatusDidChangeMessage` | Whether a Guided Access session runs | 2–4 | 6.0; message 26.0 | **Later**, for setup text only. Never changes Home | Unit: `OffMainThreadCallbackTests` |
| `requestGuidedAccessSession(enabled:completionHandler:)` | An app locking the device itself | — | 7.0 | **Never**: only for supervised devices, and it could trap a person | — |
| `configureForGuidedAccess(features:enabled:completionHandler:)` | An app turning accessibility features on or off | — | 12.2 | **Never**: it could turn off the person's only way in | — |
| Assistive Access | A simplified iPhone and iPad | 2–4 | System, since 17.0 | **System.** Setup text: **R0-7** | Device |
| `UISupportsFullScreenInAssistiveAccess` | Brickson full screen inside Assistive Access | 2–4 | 17.0 | **R0-7**: declare it | Unit: `AppBundleTests` pin. Device: the window's size |
| `AssistiveAccess` scene, `UISupportsAssistiveAccess` | A separate, system-styled interface for Assistive Access | — | 26.0 | **Never** for the main interface: its controls would sit elsewhere (docs/DECISIONS.md, "Accessibility API coverage") | Unit: `AppBundleTests` checks the key is absent |
| `accessibilityAssistiveAccessEnabled`, `AccessibilitySettings.isAssistiveAccessEnabled` | Whether Brickson runs inside Assistive Access | 2–4 | 18.0 | **R0-7**: written Settings paths instead of links there. Never changes Home | Unit |
| Accessibility Shortcut (triple-click) | Turns accessibility features on and off | 1–4 | System | **System.** Setup text: **R0-7** | Device: reachable without pressing a button |
| `AccessibilitySettings.openSettings(for:)` | Opens Settings at one accessibility setting | 1–3 | 18.0; the `.dwellControl`, `.assistiveTouch` and `.assistiveTouchDevices` cases 26.0 | **R0-7**, from family setup only, never on Home | Unit: a failed open shows text. Device: where each link lands |
| `AccessibilitySettings.canOpenSettings(for:)` | Whether a link will work | 1–3 | 26.4 **`#available`** | **R0-7**; before 26.4, offer the link and catch a failure | Unit |
| `isVoiceOverRunning`, `isSwitchControlRunning`, `isAssistiveTouchRunning` and their notices | Whether an assistive technology is on | 1–4 | 4.0; 8.0; 10.0; typed messages 26.0 | **R1**: may suggest a profile, never switch it (docs/DECISIONS.md) | Unit: the suggestion never changes the profile. Device: which flags each input method sets |
| `accessibilityEnabled`, `accessibilityVoiceOverEnabled`, `accessibilitySwitchControlEnabled` | The same, in SwiftUI | 1–4 | 13.0; 15.0 | **R1**, same rule; never read by Home's layout | Unit |
| Voice Control, Eye Tracking, Head Tracking, Dwell, Full Keyboard Access status | Whether they are on | — | — | **N/A**: Apple offers no flag; the family chooses the profile | — |
| Share Accessibility Settings | One person's settings on another device for a while | 1–2 | System, 26 | **System.** A setup note: **R0-7** | Device |
| `UIApplication.isIdleTimerDisabled` | The screen never locks | 1–4 | 2.0 | **In place** (`ScreenWakePolicy`; invariant 12) | Unit: `ScreenWakePolicyTests`. Device |
| Auto-Lock, and Guided Access's Display Auto-Lock | The system's own lock timers | 1–4 | System | **System.** Setup text: **R0-7** | Device: whether Guided Access locks the screen anyway |

## 8. Typing

| API or feature | What it is for | Stage | iOS | Status in Brickson | Checked by |
|---|---|---|---|---|---|
| Typing on Apple's keyboard by eye, head or dwell (Zoom on Keyboard Keys, Key Dwell Time, Extended Predictions) | Faster pointer typing | 2–3 | System, 18.0 and 26 | **R0-5** keeps Apple's keyboard. Gaze and head typing sizes: **R1** | UI: the keyboard probe. Device |
| Slide to Type with the dwell pointer | Drawing a word with the pointer | 1–3 | System, 26.0 (iPhone) | **System.** The composer takes whole-word changes: **R0-5** | Unit. Device |
| Hover Typing | A larger copy of what is typed | 1–3 | System, since 18.0 | **System.** A standard text field: **R0-5** | UI. Device: it never covers the quick controls |
| Key Repeat, Slow Keys, Sticky Keys | Physical-keyboard settings | 1–2 | System | **System.** Return speaks once: **R0-5** | Unit. Device |
| QuickType and inline predictions | Apple's word suggestions | 1–3 | System; inline 17.0 | **R0-5**, left on (Typing foundation's decision) | UI: the keyboard height includes the bar. Device |
| `inlinePredictionType` | Turning inline predictions off in one field | 2–3 | 17.0 (UIKit) | **Later**, only if a device check shows they confuse gaze typing | Unit |
| `autocorrectionDisabled`, `textInputAutocapitalization`, `keyboardType` | How Apple's keyboard behaves in the field | 1–3 | 13.0; 15.0; 13.0 | **R0-5** | UI |
| `submitLabel`, `onSubmit`, or a typed line break | Return speaks | 1–3 | 15.0 | **R0-5** ("Return speaks") | Unit. UI. Device |
| Writing Tools; `writingToolsBehavior(_:)` | Apple Intelligence rewriting text | 1–3 | 18.0 | **R0-5** ("Writing Tools off while typing"), and the phrase editor: **R0-6**. Brickson never rewrites what a person says (invariant 9) | Review. Device |
| Write with Siri | Siri composes or rewrites selected text | 1–3 | System, 27.0 | **System.** A device check of whether it can reach Brickson's field | Device |
| `conversationContext` (`UIConversationContext`) | Giving the keyboard a conversation for smart replies | — | 18.4 | **Never**: it invites system-written replies | Review |
| `application(_:shouldAllowExtensionPointIdentifier:)` | Refusing third-party keyboards | 1–3 | 8.0 | **R0-5** ("Third-party keyboards refused in 1.0") | Unit. Device |
| `ignoresSafeArea(_:edges:)` with `.keyboard` | Nothing moves when the keyboard shows | 1–3 | 14.0 | **R0-5** (invariant 11) | UI: frames equal before and after the keyboard |
| Keyboard frame notices, `UIKeyboardLayoutGuide` | Measuring the real keyboard | 1–3 | 3.2; 15.0 | **R0-5** (the keyboard probe) | UI. Device: real keyboard heights |
| `GCKeyboard.coalesced` | Whether a hardware keyboard is connected | 1–2 | 14.0 | **Later**, only if the layout needs it. Never moves a control | Unit. Device |
| Dictation | Speech to text in the field | 1–2 | System; clean-up 27 | **System.** The composer accepts whole-field changes: **R0-5** | Unit. Device |
| `UITextChecker.completions(forPartialWordRange:in:language:)` | Word endings from a word list, no model | 2–3 | 3.2 | **R2** prediction strip, in fixed slots | Unit: slots never re-sort by use. Device |
| `textInputSuggestions`, `textInputCompletion` | SwiftUI completions | — | macOS 15 only | **N/A** on iOS | — |
| `isKeyboardKey` trait | Brickson's own keys acting as keys | 3 | 13.0 | **Later**, only if Brickson ever builds its own keys | UI. Device |
| Foundation Models (`SystemLanguageModel`) | On-device generated text | — | 26.0 | **Never**: no AI-generated replies (invariant 9) | Review |

## 9. Testing and the App Store

| API or feature | What it is for | Stage | iOS | Status in Brickson | Checked by |
|---|---|---|---|---|---|
| Accessibility Nutrition Labels | The App Store's list of supported features | 1–4 | Shown on 26 | **R0-10**: the nine labels, the evidence each needs and the 1.0 proposal are in [`APP-STORE.md`](APP-STORE.md), section 4 | Store. Device runs before VoiceOver and Voice Control are claimed |
| Accessibility URL | A page on the product page for input methods without a label | 1–4 | — | **R0-10** (a `site/accessibility/` page, APP-STORE.md section 4) | Store |
| `XCUIApplication.performAccessibilityAudit(for:_:)` | Apple's automatic audit in UI tests | 1–4 | 17.0 | **In place** on Home and the emergency phrases, light and dark. Each new screen adds one (R0-5, R0-6, R0-7) | UI |
| Accessibility Inspector | The Mac tool that inspects elements | 1–4 | Xcode | Used on Mac runs. Never presented as proof of gaze or Snap to Item | — |
| `-UIPreferredContentSizeCategoryName` launch argument | Starting a UI test at a text size | 1–4 | Not documented by Apple | **In place** (`launchedApp`); the largest-size tests show it takes effect | UI |
| `XCUIDevice.appearance`, and Brickson's `--appearance` option | Light or dark in UI tests | 1–4 | 15.0 | **In place** through `--appearance`, because `XCUIDevice.appearance` proved unreliable (AGENTS.md, *Gotchas*) | UI: a screenshot sample checks the rendered colour |
| Increase Contrast, Reduce Motion, Reduce Transparency, Bold Text in UI tests | Running UI tests with these on | 1–4 | No documented API | Contrast at unit level (`PaletteTests`); the rest by device check | Device |
| `XCUIDevice.voiceOverService`, `XCUIVoiceOverService` | Driving VoiceOver in a UI test | 1–4 | 27.0 **`#available`** | **R0-2 follow-up**: a VoiceOver walk of Home on the iOS 27 simulators, once Home's slots land (R0-3) | UI. Device: the spoken order matches |

## 10. Outside the screen: alerts, recordings, the home and the watch

| API or feature | What it is for | Stage | iOS | Status in Brickson | Checked by |
|---|---|---|---|---|---|
| Get Attention (`AttentionAlertPlayer`) | A start-only alarm, with Stop elsewhere | 3–4 | — | Built and tested, not yet on Home: **R0-4** | Unit: `AttentionAlertPlayerTests`. Device: heard from the next room |
| Emergency SOS | The iPhone's own emergency call | 1–2 | System | **N/A**: no public API to start it was found, and Brickson's Emergency never calls anyone | Review |
| Recorded phrases: `AVAudioPlayer`, `fileImporter` | Playing and importing a person's own recordings | 1–4 | 2.2; 14.0 | **R1** "Recorded phrases, first two stages" | Unit: a missing file speaks the text instead. Device |
| In-app recorder: `AVAudioRecorder`, `AVAudioApplication.requestRecordPermission`, `NSMicrophoneUsageDescription` | Banking messages inside Brickson | 1–2 | 3.0; 17.0; 7.0 | **R2** "The in-app recorder" | Unit. Device: recording never disturbs speech or calls |
| AlarmKit (`AlarmManager`) | System alarms that sound when the app is closed | 3–4 | 26.0 | **N/A for 1.0**: Get Attention plays inside Brickson and needs no permission. Revisit if it must sound with Brickson closed | Review |
| Critical alerts | Notifications that sound through the silent switch | 3–4 | 12.0 | **N/A**: Brickson sends no notifications | — |
| Caregiver alerts over the local network: Multipeer Connectivity, Bonjour (`NSLocalNetworkUsageDescription`), Wi-Fi Aware | Reaching a phone in another room | 3–4 | 7.0, deprecated 27.0; 14.0; 26.0 | **Not in 1.0**: network code is a hard stop (invariant 9) and the owner's decision (docs/DECISIONS.md, *Caregiver alerts*) | — |
| HomeKit: `HMHomeManager`, `NSHomeKitUsageDescription` | Lights, doors and thermostat from a tile | 2–3 | 8.0 | **Not in 1.0**: it controls devices beyond the iPhone or iPad, so whether it may be built at all is the owner's decision under invariant 9, as for caregiver alerts (docs/DECISIONS.md, *Accessibility API coverage*). If the owner records an exception: a work file first, a permission, an entitlement and a privacy-policy section, and its tiles count as position-changing for dwell scoring | Review |
| Live Speech on Apple Watch | Type-to-speak on the wrist | 1–2 | watchOS 10 | **System.** Setup text: **R0-7** | Device |
| AssistiveTouch on Apple Watch | Hand gestures for the watch | 1–2 | watchOS 8 | **System**; nothing until a watch app exists | — |
| A Brickson watch app | A few phrases and Get Attention on the wrist | 1–2 | watchOS 10 (Personal Voice) | **Later**. Moving phrases to the watch needs a decision, since there is no iCloud sync | — |
| iPhone Duo: `ReservedRegion`, `reservedRegions(kind:options:layoutDirectionBehavior:)`, `onHingeChange(isEnabled:_:)` | Keeping controls off the hinge and the camera | 1–4 | 27.1 **`#available`** | **R1** "The phone as a first-class device": the layout engine takes reserved regions as part of the space available | Unit. Device: a folding iPhone, open and folded |

## Newer than iOS 26.0

Everything else above works on iOS 26.0. These need `#available`, with
the fallback given:

| API | iOS | Fallback before it |
|---|---|---|
| `AccessibilitySettings.canOpenSettings(for:)` | 26.4 | Offer the link and show the written Settings path if opening fails |
| `EnvironmentValues.accessibilityPrefersCrossFadeTransitions` | 26.4 | UIKit's `UIAccessibility.prefersCrossFadeTransitions` (14.0) |
| `EnvironmentValues.accessibilityReduceHighlightingEffects` | 26.4 | Nothing needed: Brickson's styles are steady anyway |
| `AVAudioSession.didBecomeInactiveNotification` (in place), `didBecomeActiveNotification`, `resumptionRecommendationNotification` | 27.0 | `interruptionNotification` (in place) |
| `AVAudioSession.activate(options:completionHandler:)` | 27.0 on iOS | `setActive(_:options:)` (in place) |
| `XCUIDevice.voiceOverService`, `XCUIVoiceOverService` | 27.0 | Test code only; skipped on older simulators |
| `IntentExecutionTargets`, `allowedExecutionTargets` | 27.0 | Not needed until Controls exist |
| `ReservedRegion`, `GeometryProxy.reservedRegions(…)`, `onHingeChange(isEnabled:_:)` | 27.1 | Only folding iPhones have a hinge, and they run 27.1 or later |
| Voice Control flexible item names; Write with Siri; Dictation clean-up; the Liquid Glass slider | System, 27.0 | System features with no app code |

None of them needs a minimum above 26.0, so the deployment target stands
(docs/DECISIONS.md, "Minimum iOS, iPhone and iPad").

## Keeping this list current

- A pull request that adopts, changes or drops an API here edits its row
  in the same pull request, and its *Checked by* names the real test.
- When Apple ships a new major iOS, the pull request that moves Brickson
  to the new Xcode also reads Apple's accessibility, SwiftUI, UIKit,
  AVFAudio and App Intents update pages
  (`https://developer.apple.com/documentation/updates/<framework>.md`) and
  adds what is new (docs/DECISIONS.md, "Build with Apple's current Xcode").
- Device results go in a `docs/log/` file and the handoff's device table,
  then the row here says what was found.
