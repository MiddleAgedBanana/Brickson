# Decisions

Binding choices for Brickson, with the reason for each. Code comments point
here by section title, so keep titles stable. A settled decision is not
reopened without new evidence; to change one, edit its entry, say what
changed and why, and keep the old reasoning in a "Before" line.

"Owner" means the repository owner decided; "default" means an agent chose
a reasonable default that the owner can overrule.

## Waiting on the owner

*2026-10-21.* On 2026-10-21 the owner asked to focus on building the app
and to leave the logistics to the project. These are the only questions
left for the owner, because each is personal, sets a price, or cannot be
taken back. Until one is answered, nothing hard to undo is done under it.

| Question | Recommended | Why |
|---|---|---|
| Is "Brickson" the final name, and so what is the bundle identifier? | Keep Brickson (retained publicly on 2026-10-12), with a bundle identifier that contains no personal name | The bundle identifier is public and can never change after the first upload; today's `family.avery.brickson` contains the owner's first name (*App identity*) |
| What does Brickson cost? | No recommendation: the owner's call, before the first submission | Until then nothing anywhere states a price (*Price not decided*), and no purchase code is built |
| How is "Brickson" said? | Tell an agent how it sounds; it sets a sound-alike spelling in `APP_SPOKEN_NAME` | VoiceOver and Siri say the name; only the owner knows how it should sound |
| Should the code have a license? | Not yet: keep all rights reserved | A license can be added later, but one that has been granted cannot be withdrawn from copies already taken |
| Is the owner a "trader" under the EU's Digital Services Act? | Decide when the App Store Connect record is made; if yes, publish a dedicated contact rather than a home address | App Store Connect asks before the app can be offered in the EU, and a trader's contact details are shown publicly |

Owner steps that are actions, not decisions: the Team ID in
`project.yml`, device runs, committing workflow files (docs/SDLC.md,
*Deploy*), and every step in App Store Connect.

## Decided by default on 2026-10-21

*Default, adopted 2026-10-21: the owner left these choices to the
project. Reversible if the owner objects.* Each was the recommended option
of the research of 2026-10-15 (`docs/recon/`) or of the work that owns it.
Decisions with their own entry are listed by title; the rest are recorded
here. Entries kept by other work arrive with its pull request: until it
merges, the entry and its reasons are in that pull request, or, where none
is open yet, in the owning thread's work, and the summary here is what
holds.

| Decision | Where it is recorded |
|---|---|
| The releases and their order: R0, R1, R2 | `docs/ROADMAP.md` |
| Layouts from the space available, with floors set without a device table | "Layouts from the space available", below |
| When Personal Voice permission is asked, Automatic keeping the person's Personal Voice, no Personal Voice without permission | "Personal Voice permission is asked at launch, for now", "Automatic keeps the person's Personal Voice", "A Personal Voice is used only while it is allowed" (Personal Voice foundation; `claude/project-thread-1ly6dd`) |
| Minimum iOS 26.0, iPhone and iPad, set by two rules: every device that can use eye tracking runs the app, and every mapped accessibility API stays reachable behind `#available` | "Minimum iOS, iPhone and iPad" (Toolchain and iOS version targets; PR #12, merged) |
| Home's slot plan with stable slot identifiers | "Home's slot plan" (Phone layout and word fitting; PR #22) |
| Solid fills on Home with one measured colour per role, and the system's Liquid Glass elsewhere once each component measures | "Solid fills on Home, system glass elsewhere" (Figma and Claude Design screens; `docs/log/2026-10-21-design-screens.md`) |
| The App Store category is Utilities, with no secondary category; the age-rating answers give 4+ | "App Store category", "Age rating answers" (App Store readiness and ASO; PR #18) |
| Home's stand-in layout, labels that fit themselves and Home's button style | "Home's stand-in layout", next to "Home version 0 is a stand-in" (Phone layout and word fitting) |
| Typing as a state of Home under a band Apple's keyboard never covers, Apple's keyboard in 1.0, Writing Tools off, third-party keyboards refused, Return speaks, the typed message | "Typing is a state of Home", "Typing uses Apple's keyboard", "Writing Tools off while typing", "Third-party keyboards refused in 1.0", "Return speaks", "The typed message" (Typing foundation; its pull request from `claude/project-thread-dsbkry`) |
| Explicit saves, an Emergency category that is always there, fixed starter identities, editing, import, replace, the backup format, an unreadable library reported and never replaced | "Every save is explicit", "Starter phrases", "The emergency category is always there", "Editing the library", "Importing a backup", "Replacing the library", "Backup file format", "An unreadable library is reported, never replaced" (Library editing and backup format; PR #14, open) |
| When the audio session is released, the alarm's sound, start-only Get Attention, no automatic resume, Personal Voice never written to a file | "Background audio", "Get Attention", "A phrase the system cuts off", "Audio session notices", "Personal Voice is never written to a file" (Speech engine and Get Attention; PR #16) |
| Home first with setup as a place in Settings, the Settings root, the voice picker, the Privacy row, the largest sizes when nobody answers setup, an "Anything changed?" check-in every three months that waits 30 days after Not Now | "First launch opens Home; setup lives in Settings", "Settings is a cover with a fixed safety bar", "Settings resets when idle and never closes", "Setup answers are kept as offered, never as completed", "Check-ins come every three months", "The privacy policy ships inside the app", "Speed is a set of fixed choices" (Settings and first run; PR #23) |
| Voice Settings keeping its rows and words in place while voices change, and an explained Ask button for Personal Voice that moves nothing and adds no button on the visit that asked (switched on after device check D1) | "Voice Settings keeps its places while it is open", "Asking for Personal Voice from Voice Settings", and a paragraph in "A Personal Voice is used only while it is allowed" (Voice screen in Settings, 2026-10-22) |
| Home's scan order (Yes, No and Emergency first, regions as containers) and the names Voice Control and Full Keyboard Access use, the visible words first | "Home's scan order and names" (Accessibility implementation, first pass) |
| Home's border, pressed and selection rings under Show Borders, and the Large Content Viewer held back from Home's speaking controls until a device check | "Show Borders and the Large Content Viewer on Home" (Accessibility pass two) |
| Get Attention on Home under Emergency, Stop in a well of its own with a category under it, "Help" as Get Attention's other name, the status line's order, a silent stand-in tone for UI tests | "Get Attention and Stop on Home" (Get Attention and Stop on Home; PR #38) |
| The exceptions to Apple's current frameworks first, and the moves made and planned | "Apple's current frameworks first" (the rule is the owner's, 2026-10-22) |
| The accessibility coverage list and its choices: full screen in Assistive Access and no separate scene, no programmatic Guided Access, assistive-technology flags that only suggest, phrases in the person's voice with VoiceOver on, late-stage boards as an R1 profile, and what waits or is never used | "Accessibility API coverage" (Accessibility coverage checklist) |

Recorded here:

- **iPhone orientations.** Portrait and both landscape orientations, not
  upside down, from the pull request whose layout tests show a landscape
  phone with no scrolling for the starter library; until then portrait
  only. A phone on a wheelchair or bed mount is often sideways, and the
  person may not be able to turn their head. That pull request updates
  *Orientations*.
- **No iCloud sync in 1.0** stands as recorded below.
- **Caregiver alerts:** 1.0 alerts only with sound in the room (Get
  Attention), and the privacy policy's caregiver-alerts section is deleted
  before release. Anything that reaches another device needs network code,
  which invariant 9 forbids, so it stays the owner's decision.
- **Recorded phrases, in stages:** guidance for recording elsewhere first,
  then importing and playing recordings (R1), then an in-app recorder
  after device checks (R2).
- **No purchase code** (StoreKit) until the owner decides a price.
- **Who chooses the input profile:** the family, in Settings. Accessibility
  features the system reports may suggest a profile, never switch it.
- **No rating prompt on Home.** Brickson never asks for a review on its
  own; a "Rate Brickson" row, if added, lives on a family Settings screen.
- **Copilot's "Review new pushes" stays off.** Each review spends the
  owner's AI credits, and Codex already reviews every push.
- **No `REVIEW.md`.** AGENTS.md, *Code Review Rules*, is the review policy
  every reviewer reads.
- **The research is public** in `docs/recon/`, with personal details and
  local paths removed.
- **If storage cannot start at all,** the app still stops
  (`PhraseLibraryStore.openForApp`), as the reference app did: no real way
  for it to happen was found. Revisit if one is.
- **At release, Mac and Apple Vision Pro availability are switched off**
  in App Store Connect, matching *Minimum iOS, iPhone and iPad*.
- **At most three pull requests wait for the owner's review at once**
  (docs/SDLC.md, *Build*); other work continues on its branch.

## Layouts from the space available

*Default, adopted 2026-10-21: the owner left these choices to the
project. Reversible if the owner objects.* The owner's goal of 2026-10-21
asks for interfaces built from the space available with standard SwiftUI
containers, "instead of building device-specific interfaces" (AGENTS.md,
*Layout on every device and window*).

- Layout code and the layout engine take the window's size, its safe
  areas, Dynamic Type, the input profile and the library's shape, and
  nothing that names a device: no device model, no table of screens, no
  check of the screen's physical size. Size classes are hints, never the
  reason a control moves. Test matrices and dated measurements may name
  devices.
- **Floors without a device table.** iOS does not report a screen's
  physical density, so each profile's floors are physical sizes converted
  to points once, at the densest supported screens (about 163 points per
  inch, the 326 ppi screens at 2x), and used everywhere. A target is then
  at least its physical size on every screen, and larger on most. The
  reference app's gaze floors of 110, 88 and 72pt were sized on a 13-inch
  iPad (about 132 points per inch); held at the densest screen they are
  about 136, 109 and 89pt. Where a window cannot hold them, the
  arrangement changes (fewer tiles to a screen, a different split), never
  the floor: invariant 11 forbids shrinking a target below its profile's
  floor, and only the owner can change a floor.
- The 2026-10-15 layout blueprint
  (`docs/recon/2026-10-15/layout-blueprint.md`) keyed density, profiles and
  the keyboard band to device tables; those parts are replaced by this
  entry. Before: AGENTS.md said floors were "computed in physical size per
  device".

## App identity

*2026-10-10. Name: owner. Other values: default.*

Everything that identifies the app sits in one block at the top of
`project.yml`, so changing it means changing one line:

| Setting | Value | Notes |
|---|---|---|
| `APP_DISPLAY_NAME` | `Brickson` | The name under the icon. The name retained by the owner on 2026-10-12. |
| `APP_SPOKEN_NAME` | `Brickson` | How VoiceOver and other text-to-speech say the app's name (`CFBundleSpokenName`). If they say it wrong, use a sound-alike spelling here; the name under the icon stays as it is. |
| `APP_BUNDLE_ID` | `family.avery.brickson` | The identifier the owner was advised to register for the App Store. It **cannot change after the first App Store upload**, and it is public, so any change happens before that upload. Someone building for their own device changes it locally (it belongs to one team) and does not commit that. |
| `DEVELOPMENT_TEAM` | empty | Needed only to run on a real device or upload. The owner chose the personal (individual) membership on 2026-10-10; the field stays empty until the owner enters that team's ID. A team ID is not secret; it is in every signed app. |
| `MARKETING_VERSION` | `0.1.0` | The version people see. |
| `CURRENT_PROJECT_VERSION` | `1` | Must go up with every upload to App Store Connect. |

The alternative name "Brick Son" is declared for Siri
(`INAlternativeAppNames` under the app's `info` in `project.yml`; at most
three, never another app's name), because "Brickson" is in no pronunciation
dictionary. It has no effect yet: Apple says Siri "recognizes alternative
app names only for apps that include an Intents app extension with support
for one or more intents" ("Specifying Synonyms for Your App Name", read
2026-10-21), and Brickson has none. It stays declared for when Siri support
comes (docs/ROADMAP.md, R2), and whether App Intents count is checked then.
Whether Siri, Voice Control and VoiceOver handle the name well is a device
check. Before (2026-10-10): this entry said Siri accepts "Brick Son"; the
2026-10-21 accessibility coverage check found Apple's condition.

The Xcode project, targets and folders are also called Brickson. Renaming
those is a larger change (folders, target names, `@testable import`), and is
not needed to change the name people see.

## Brand name and founder story

*2026-10-12. Owner.*

Keep **Brickson**, styled **brickson** in the website wordmark. Before:
Brickson was a working name and alternatives were being explored. The owner
chose to retain it because his brother invented the name as a teenager;
it became a family joke more than twenty years ago. His brother later died
of ALS. The owner authorized a short public founder note on the website and
README and specifically requested that it avoid a detailed backstory.

Use the concise first-person note attributed to Avery Dedmon. Do not invent
biographical details, testimonials, treatment benefits or reliability claims.
The name decision is not legal clearance or an App Store reservation; see
[the availability screen](NAME_AVAILABILITY.md).

## Generated Xcode project

*2026-10-10. Default, from the reference app.*

`Brickson.xcodeproj` is generated from `project.yml` by XcodeGen and is not
committed (it is in `.gitignore`). Every machine, and CI, generates it.
This keeps project settings reviewable as plain text and avoids merge
conflicts in the project file. Agents never open the project in Xcode
(docs/LESSONS.md, "Never open the project in Xcode from an agent").

## Build with Apple's current Xcode

*2026-10-21. Owner.*

Brickson is built with the Xcode Apple currently recommends: its newest
release (never a beta or a release candidate) and the SDKs and Swift
compiler that come with it. Nothing in the repository pins an Xcode, SDK,
simulator or runner version the owner did not ask for. When Apple releases
a new Xcode, the build moves to it in a pull request, which also fixes
anything the new Xcode reports.

- **Two different versions.** The *toolchain* (Xcode, its SDKs and its
  Swift compiler) builds the app, and is always Apple's newest release.
  The *deployment target* is the oldest iOS and iPadOS the app runs on;
  it is a product decision with its own rules (*Minimum iOS, iPhone and
  iPad*, below). Building with a newer SDK does not stop the app running on an
  older system: the deployment target decides that.
- **Look it up, never recall it.** An agent's training data is older than
  Apple's newest release. What is current comes from Apple's releases
  page (https://developer.apple.com/news/releases/) and Xcode's system
  requirements (https://developer.apple.com/xcode/system-requirements/),
  read at the time.
- **CI** picks its Xcode with `scripts/select-xcode.py`: `choose` takes
  the newest release installed on GitHub's Mac machine, whatever the
  machine's default is, and `check` compares it with Apple's releases feed
  and puts a warning on the run when Apple has a newer one. It warns
  instead of failing because GitHub adds a new Xcode to its machines some
  days after Apple releases it, and a safety fix must not wait for that.
  Apple's feed decides whether an installed build is a release, by its
  build number; only a build the feed does not list goes by its app's
  name. GitHub's names are not reliable: on 2026-10-21 the released 27.1
  sat in `Xcode_27.1_Release_Candidate.app`, because Apple released the
  release candidate unchanged, and `Xcode_27.2.app` led to a beta. A
  version newer than the feed's newest release is never taken, whatever
  its name. When the feed cannot be read, or lists no Xcode release,
  `choose` goes by names and warns on the run, in every job.
- **Runner image.** GitHub now publishes one Mac image per major Xcode
  (`xcode-27` carries Xcode 27 on macOS 27; generally available since
  2026-10-15, GitHub's changelog). The older `macos-26` image that CI used
  until 2026-10-21 had Xcode 26.6 as its default and no iOS 27 simulators.
  `runs-on` names the image for the current major Xcode; when Apple
  releases the next one and GitHub publishes its image, the `check`
  warning says so, and a pull request moves both jobs to it. Cloud agents
  cannot change workflow files (AGENTS.md, *Gotchas*), so the owner, or an
  agent on the owner's Mac, commits that change.
- **Simulators.** `scripts/test.sh` tests on the newest iPad simulator,
  and runs UI tests on the newest standard iPhone too, each between the
  deployment target and the SDK of the Xcode in use. No version is
  written into it.
- **Documents** say "the current Xcode release", not a number. A dated
  record of what something was checked on (the tables in
  docs/HANDOFF.md) keeps its version: that is history, not a pin.
- **Swift language mode.** `SWIFT_VERSION: "6.0"` in `project.yml` chooses
  the Swift 6 language mode, not a compiler. On 2026-10-21 Swift 6 was the
  newest mode in the current Xcode (its system requirements page). Move
  to a newer mode in a pull request when Apple ships one.
- **Why.** The owner asked for it on 2026-10-21, after seeing "26.0"
  throughout the repository without having chosen it. Apple's rules point
  the same way: from April 2027, App Store uploads must be built with the
  iOS and iPadOS 27 SDK or later (Apple's submitting page, read
  2026-10-21), and new Xcode releases add support for new devices.

## Minimum iOS, iPhone and iPad

*2026-10-10 default, from the reference app. Decided 2026-10-21 from two
rules, after the owner set the first and left the rest to the project.
Reversible if the owner objects.*

iOS and iPadOS 26.0 or later, on iPhone and iPad. Mac ("Designed for
iPad"), Mac Catalyst and Vision Pro are switched off until someone decides
to support them.

The number follows from two rules. Check them again when Apple's next
major release drops devices, and move the number only as they allow.

1. **Brickson supports every device that can use eye tracking** (owner,
   2026-10-21: the app has to serve every stage of ALS). That means
   Apple's built-in Eye Tracking and the third-party eye trackers made for
   iPad. Both drive the system pointer (AssistiveTouch and Dwell Control),
   which finds standard controls through the accessibility tree. No app
   code takes part: invariant 1, standard `Button`s, is what makes eye
   tracking work, and custom gaze code is a hard stop.
2. **Every accessibility API in the project's map of Apple features by ALS
   stage stays reachable.** An API newer than the minimum is used behind
   `if #available`, with a path for older systems, never by raising the
   minimum.

What the rules gave on 2026-10-21, from Apple's and the vendors' pages:

- **Built-in Eye Tracking** runs on named models, not on a chip class
  (iPhone and iPad User Guides for iOS and iPadOS 18, 26 and 27, "Models
  that support Eye Tracking"). On iPhone: iPhone 12 and later, and iPhone
  SE (3rd generation). On iPad: iPad (10th generation) and later, iPad
  mini (6th generation) and later, iPad Air (4th generation) and later,
  iPad Pro 11-inch (3rd generation) and later, iPad Pro 12.9-inch (5th
  generation) and later. Every one of them runs iOS or iPadOS 27, so rule
  1 for Apple's feature alone would allow 27.0.
- **Third-party trackers** set the floor. eyeV's Skyle 3 works with
  "iPads with USB Type C" and "an iPad Pro of the 3rd generation or
  newer" (eyev.de), which includes the 2018 iPad Pro 11-inch (1st
  generation) and 12.9-inch (3rd generation). Those run iPadOS 26 but not
  27 (Apple's iPadOS 27 compatibility list). Tobii Dynavox's TD Pilot
  ships with an iPad Pro 12.9-inch and needs iPadOS 15.1 or later (its
  user's manual). No current tracker found supports a Lightning iPad, so
  none needs a system older than 26. Hence **26.0**: 27.0 would cut off a
  Skyle user on a 2018 iPad Pro.
- **APIs in the map** that are newer than 26.0 sit behind `#available`:
  `AccessibilitySettings.canOpenSettings(for:)` and two SwiftUI display
  values (26.4), the iOS 27 audio-session life-cycle notifications and
  VoiceOver test service (27.0), and the iPhone Duo reserved regions
  (27.1). Nothing the map needs requires more than 26.0 to build on
  (re-checked on Apple's pages on 2026-10-21: docs/ACCESSIBILITY.md,
  *Newer than iOS 26.0*).
- Also gained at 26.0: iOS 26 runs on iPhone 11 and later and iPhone SE
  (2nd generation), and iPadOS 26 on iPad (8th generation) and later and
  the 2018 iPads above, so people using touch, switches or Voice Control
  on those keep the app too.

## No outside packages

*2026-10-10. Default, from the reference app and invariant 9.*

Only Apple's frameworks. No Swift packages, no SDKs. Every dependency is
code that can break, track or change under the person relying on it.

## Apple's current frameworks first

*2026-10-22. The rule: owner. The exceptions and moves below: default,
adopted 2026-10-23; reversible if the owner objects.*

The owner asked on 2026-10-22 to build on the frameworks Apple is
investing in for the future: SwiftData, not Core Data; SwiftUI, not UIKit
"unless ABSOLUTELY necessary"; Swift Testing, not XCTest; App Intents, not
SiriKit. And to do it now, because "the longer it takes to do, the harder
it will be to update everything". AGENTS.md, *Apple's current frameworks
first*, holds the rule. This entry lists every exception, and a pull
request that adds or removes one edits its row.

**The audit of 2026-10-23** read every Swift file in the app, unit-test
and UI-test targets, and `project.yml`, against Apple's documentation for
the Xcode then current (27.1, with the iOS 27.1 SDK and Swift 6.4). There
was no Core Data, SiriKit, Combine, `ObservableObject` or deprecated API,
and the unit tests used only Swift Testing. It moved:

- The UI tests' check that quick-control words are drawn whole, from
  `VNRecognizeTextRequest` to Vision's Swift API, `RecognizeTextRequest`
  (iOS 18), in one helper (`RenderedWords`) that the unit tests share.
  There `RenderedWordsTests` runs it on kept captures, so a recognizer
  that stops reading whole labels, or a match that accepts part of a
  word, fails on every run; it also pins the request's settings (fast,
  English only, no language correction, no supplied words).
- The audit runner's six tests, from XCTest in the UI tests to Swift
  Testing in the unit tests: they drive no app.
- The Personal Voice stand-in's answer, from `DispatchQueue.global()` to a
  detached task.
- Settings' inline titles, from `navigationBarTitleDisplayMode` to
  `toolbarTitleDisplayMode` (iOS 17).
- Three copies of UIKit's system background, into one: `Palette.screen`.

**Imports say what a file uses.** A file that uses UIKit's own types
imports UIKit by name, even where `import SwiftUI` or `import XCTest`
would bring it in; a file that uses none does not import it. SwiftUI's
bridges to UIKit (`UIHostingController`, `UIViewControllerRepresentable`)
and its modifiers typed with UIKit values (`keyboardType`) are SwiftUI's
own API and need no UIKit import. The table below, not a search for
imports, is the complete record.

**Kept, and why.** Each row is a legacy framework or API that no current
one replaces with no loss.

| What | Where | Why | Revisit when |
|---|---|---|---|
| XCTest and XCUIAutomation | UI tests | Swift Testing cannot launch or drive an app. Apple: "UI automation and performance testing APIs are only available in XCTest" (WWDC26, "Migrate to Swift Testing"), and the XCTest page says to "continue to use XCTest for user interface tests". | Swift Testing can drive an app |
| UIKit types in UI tests: `UIDevice` (its idiom and system version), `UIDeviceOrientation`, a screenshot's `UIImage` | `GetAttentionOnHomeTests`, `HomeAccessibilityOrderTests`, `HomeLayoutTests`, `HomeReachabilityTests`, `KeyboardProbeTests`, `LaunchHelpers`, `LaunchTests`, `SettingsOnHomeTests` | XCUIAutomation's own API uses these types (`XCUIDevice.orientation`, `XCUIScreenshot.image`) and reports no device idiom. | With the row above |
| `UIApplication.isIdleTimerDisabled` | `BricksonApp` | Invariant 12. SwiftUI has no way to keep the screen awake; Apple documents this property for it. | SwiftUI gains one |
| `UIFont` (text-style sizes, weights, line heights), `NSString.size(withAttributes:)`, `UIImage.SymbolConfiguration` | `LabelFont` | `WordFit` measures words before layout, as a plain tested type. SwiftUI measures text only inside a view hierarchy (`Text.Layout`; `ViewThatFits` failed Apple's accessibility audit). iOS 26's `Font.resolve(in:)` gives a point size and a Core Text font, but measuring a word still needs UIKit or Core Text, and resolving a font outside a view is undocumented. | Under *Planned moves* |
| `UIColor.systemBackground` | `Palette.screen` | The colour `PaletteTests` measures as "the screen", and pins `Palette.screen` to. SwiftUI has no colour of its own for it, and its background style changes with the container. | SwiftUI gains a system background colour |
| `SFSafariViewController` in a `UIViewControllerRepresentable` | `PrivacyPolicyView` | The web version opens in Safari's in-app view (*The privacy policy ships inside the app*). SafariServices has no SwiftUI view. iOS 26's `OpenURLAction.Result.systemAction(_:prefersInApp:)` only prefers an in-app browser: Apple does not say how it is presented or when it opens Safari outside Brickson instead, and it gives Settings no state to hold its idle reset while the page is open. | Apple documents that presentation |
| `DispatchQueue.main.async` | `SpeechSynthesizing` (`forward`) | The main queue runs blocks in order; separate tasks do not. A finish that overtook the progress report before it would make a cut-off phrase read as complete (*A phrase the system cuts off*; `OffMainThreadCallbackTests`). An `AsyncStream` keeps order but changes how speech reports interleave with the session's notices. | — |
| `NotificationCenter.addObserver(forName:object:queue:using:)` | `AudioSessionEvents`, `SpeechService` | Foundation's typed messages (iOS 26) exist for none of these notices: interruption, route change, media services, available voices. iOS 27's life-cycle notice has one (`AVAudioSession.DidBecomeInactiveMessage`), but Apple does not say what it does with a notice that has no context, and `AudioSessionEventsTests` posts one. | Under *Planned moves* |
| Key-value observation of `outputVolume` | `AudioSafetyMonitor` | Apple offers no other way to observe the system volume. | — |
| `UIColor` and `UITraitCollection` | `PaletteTests` | Invariant 6 measures every pair under Increase Contrast too. SwiftUI's `colorSchemeContrast` "depends entirely on user settings, and you can't change it", so SwiftUI cannot resolve a colour for Increase Contrast. | SwiftUI can |
| `UIImage(systemName:)` | `StarterPhrasesTests`, `LibraryRulesTests` | Only UIKit reports a symbol name that does not exist; SwiftUI's `Image(systemName:)` cannot fail. | — |
| `UIHostingController.sizeThatFits(in:)` | `StarterLabelFitTests` | The exact size SwiftUI gives a label, to within half a point. SwiftUI's `ImageRenderer` draws pixels, and Apple does not say its size is unrounded. | — |
| A `UIHostingController` shown in a `UIWindow` | `SwiftDataBehaviourTests` | Checks that SwiftUI's `modelContainer` leaves the library's autosave off, which happens only for a view on screen; a unit test has no SwiftUI way to put a view in a window. | — |
| `INAlternativeAppNames`, SiriKit's Info.plist key | `project.yml` | App Intents has no way to give the app other names. Apple's App Shortcuts sessions say `.applicationName` includes these names; SiriKit's article says they need an Intents extension (*App identity*). | R2's Siri device check |

Siri and Shortcuts (R2) are built with App Intents and App Shortcuts. A
SiriKit Intents extension is added only if R2's device check shows the
app's other names need one, with its row here.

Not legacy, so not listed: AVFoundation's speech, player and audio
session, with their delegates (Apple has nothing newer for them); the
Accessibility framework; `Logger`; Foundation, including its
`NSString`-bridged methods; Vision; SwiftUI modifiers typed with UIKit
values.

**Planned moves.** Current APIs that can replace a legacy one, each
needing a Mac or its own pull request:

- Personal Voice permission through `AVSpeechSynthesizer`'s async
  `requestPersonalVoiceAuthorization()` instead of its completion handler,
  which would retire the off-main closure `forwardingAnswer` guards. *(the
  next speech or Voice Settings thread)*
- `LabelFont` measuring with SwiftUI's resolved font (`Font.Resolved`,
  iOS 26) instead of building its own `UIFont`, which could replace the
  Bold Text guess (`boldTextUIFontWeight`) with the font SwiftUI draws;
  `StarterLabelFitTests` decides on a Mac. *(the layout engine)*
- UI tests waiting with XCUIAutomation's `wait(for:toEqual:timeout:)`
  where a wait watches one property, and AGENTS.md's gotcha with them.
  *(Test seams and CI evidence)*
- iOS 27's typed audio-session messages, once the minimum iOS is 27 or a
  Mac check shows a notice without context still arrives (*Audio session
  notices*). *(the speech engine)*

**Planned uses, not built yet.** Each gets its row when it lands, after
checking SwiftUI still lacks the API: a wrapped UIKit text view to turn
off inline predictions (*Typing uses Apple's keyboard*), and UIKit's
`prefersCrossFadeTransitions` before iOS 26.4
([`ACCESSIBILITY.md`](ACCESSIBILITY.md)).

## No servers, accounts, ads or analytics

*Invariant 9.* Everything stays on the device. The privacy manifest
(`Brickson/Resources/PrivacyInfo.xcprivacy`) declares no tracking and no
collected data; `AppBundleTests` pins it.

## Price not decided

*2026-10-12. Owner.*

The owner has not decided Brickson's price. Until they do, nothing in the
repository, the website (`site/`), the app or the project's documents
states one: not "free", not "paid", no amount. Describe Brickson by what it
does ("an iPhone and iPad app that speaks for people living with ALS").
"Free" about other things, such as Xcode, a free Apple Account or GitHub
Pages, is fine. The reference app's handoff called its successor free, and
earlier documents here copied that; the owner never decided it.

## App Store category

*2026-10-21. Default, adopted 2026-10-21: the owner left these choices to
the project. Reversible if the owner objects.*

Brickson's primary App Store category is **Utilities**, with no secondary
category. Apple defines Utilities as apps that "solve a problem or complete
a specific task", which speaking for someone is; Medical is for medical
education, information management or health reference, which Brickson is
not. A primary or secondary category of Medical or Health & Fitness would
also require declaring, on the product page, whether the app is a regulated
medical device in the US, UK and EEA, a legal question an individual
developer should not answer alone. People find AAC apps by searching, so
the category costs little in discovery. The reasons and Apple's sources are
in docs/APP-STORE.md, section 5. The reference app's release checklist
proposed Medical; this replaces it.

## Age rating answers

*2026-10-21. Default, adopted 2026-10-21: the owner left these choices to
the project. Reversible if the owner objects.*

Brickson answers every age-rating question No or None, which gives 4+.
The one question that needs care is Medical or Treatment Information:
the answer is None, because starter phrases such as "I need my medication."
are the person's own words to the people nearby, not guidance on managing a
condition. Infrequent would make the app 13+. The full answers are in
docs/APP-STORE.md, section 6. Re-answer when the starter phrases, an in-app
web view or caregiver alerts change what the app contains. Whether US state
age-assurance laws require the Declared Age Range API is **not** decided
here; any age check must never cover or block communication (invariants 2
and 10).

## Versioned storage

*2026-10-10. Default.*

The phrase library is stored with SwiftData in a versioned schema
(`PhraseLibrarySchemaV1`) with a migration plan
(`PhraseLibraryMigrationPlan`), from the very first release. Every later
version must migrate from whatever 1.0 ships. To change a stored model:
add `PhraseLibrarySchemaV2` with copies of the models, add a migration
stage, move the `PhraseCategory` and `Phrase` type aliases, and never edit
V1. Models carry a stable `uuid` for backups, restores and (later) Siri and
Shortcuts.

Deleting a category does not cascade to its phrases (`.nullify`); the code
that deletes a category deletes its phrases in the same save
(docs/LESSONS.md, "Never roll back a cascade delete").

## Every save is explicit

*Default, adopted 2026-10-21: the owner left these choices to the project.
Reversible if the owner objects.*

SwiftData saves a container's main context by itself ("autosave") unless
told not to. Brickson turns that off on every path out of
`PhraseLibraryLaunch.prepare` (pinned by `PhraseLibraryTests` and, through
SwiftUI, by `SwiftDataBehaviourTests`), and Home only reads through that
context. Every change to the library is planned first as plain values
(`LibraryEdit`), then written by `LibraryEditor.apply` in a context of its
own and saved once. If the save fails, that context is thrown away:
nothing reached the store, Home never saw the change, and `rollback()` is
never called (docs/LESSONS.md, "Never roll back a cascade delete"). Before
writing, the applier checks that the store still matches the library the
plan was made from, so a plan made before another edit landed is refused
instead of undoing that edit.

Screens keep identities (`uuid`) and fetch afresh across an edit, never a
model object. What SwiftData does when a held object is deleted elsewhere,
and the other SwiftData behaviours this rests on, are probed by
`SwiftDataBehaviourTests` (questions S1 to S4 in
`docs/log/2026-10-21-library-core.md`).

Rejected: editing in the main context and undoing a failed save with
`rollback()` or with hand-written inverse edits. The first crashes after
a delete, even without a cascade (S4, issue #19); the second is more code with more ways to half-change.

## No iCloud sync in 1.0

*2026-10-10. Default; recommended to the owner.*

The library stays on the device (`cloudKitDatabase: .none`). Sync brings
conflicts, account states and failure modes that a person who cannot speak
must never meet mid-sentence. The models already follow SwiftData's iCloud
rules (defaults on every property, optional relationships, nothing unique),
so sync could be added later without a migration. Backup by file comes
first (docs/PORTING.md, step 2). `PhraseLibraryTests` pins `.none` on the
app's store.

## The screen stays awake

*Invariant 12.* While Brickson is open, the screen never dims or locks
(`ScreenWakePolicy`): many people using it cannot unlock their device. It
is not a setting on the person's path. Whether touch users, who can unlock
their own device, should be able to turn this off is an open question for
the stage profiles.

## Background audio

*2026-10-10.* `UIBackgroundModes` includes `audio`, and speech uses the
`.playback` audio session, so a sentence keeps playing when the device
locks or another app opens, and the Get Attention alarm (once ported)
keeps sounding until it is stopped. App Review allows background audio
only for its intended purpose (guideline 2.5.4), so:

- never play silent audio to keep the app alive;
- in the App Review notes, give steps that show it, for example: "Choose a
  long phrase, then lock the device: speech continues."

**When the session is released.** *2026-10-21. Default, adopted
2026-10-21: the owner left these choices to the project. Reversible if the
owner objects.*

One object owns the shared audio session, `AudioSessionCoordinator`.
Speech and the Get Attention alarm each hold it while they play
(`acquire(for:)` and `release(for:)`), so neither can configure or release
it underneath the other. In 1.0 it is never deactivated
(`AudioSessionLeasePolicy.keepActive`): the next phrase never waits for
activation (invariant 2) and a release can never cut the alarm off. The
cost: music or a podcast that speech interrupted does not resume by itself.
`.releaseWhenIdle` (deactivate with `.notifyOthersOnDeactivation` once
nobody holds the session) is built and tested but unused until a device
check shows the first syllable is not lost over Bluetooth and the next
phrase does not wait.

The session is `.playback` in mode `.default`, set at launch without
activating. The reference app used `.spokenAudio`, which lets another app's
spoken prompt (a navigation direction, say) pause the person's sentence or
the alarm. When an activation is refused (during a phone or FaceTime call),
it is retried mixing with other audio, so the sound plays rather than
failing silently; a refusal of both shows "Audio failed".

Before: "Open, decide with the Get Attention port (step 1): when to release
the audio session." The reference app activated before speaking and never
deactivated; Brickson keeps that behaviour, now in one place.

## Get Attention

*2026-10-21. Default, adopted 2026-10-21: the owner left these choices to
the project. Reversible if the owner objects.*

The alarm (`AttentionAlertPlayer`, rules in `AttentionAlertStatus`) is a
looping tone, `Brickson/Resources/AttentionTone.wav`, ported from the
reference app.

- **Start-only.** Get Attention only starts it; a second activation while
  the tone really plays changes nothing. Only Stop, a separate control in a
  different place, ends it (invariant 10). On Home, Get Attention sits
  directly under Emergency and Stop in a well of its own at the top of
  the categories' leading column, with a category under it (*Get
  Attention and Stop on Home*; the slot plan put Stop directly below
  Emergency, and this said "above" under an earlier order of Home's
  regions).
- **Speaking never silences it.** While a phrase speaks, the tone drops to
  `AttentionAlertStatus.toneVolumeWhileSpeaking` (0.32, about 10 dB down),
  and comes back to full when the phrase ends, however it ends. The level
  is not measured yet: a listening check on a device sets it.
- **Never resumes by itself.** An interruption (a call, Siri, another app's
  alarm), a lost output, a media-services loss or reset, or a player error
  stops it and shows "Alert stopped"; one Get Attention activation
  restarts it (invariant 4). A lost output stops it too, as in the
  reference app, because the tone would otherwise move to a speaker no one
  chose.
- **Checked every second while it sounds, and on returning to the
  foreground.** A tone that went quiet without a report shows "Alert
  stopped" rather than "Sounding" over silence, and a repeat activation
  restarts a quiet tone instead of being absorbed. When the session could
  not be activated, the tone is tried anyway (it may still play), Home
  shows "Audio failed", and a repeat activation retries the session
  instead of being absorbed, since the tone may be muted by the silent
  switch (Codex review of PR #16).
- **No time limit and no flashing.** It sounds until someone chooses Stop.
- **The tone itself is a placeholder.** Before release it is replaced with
  a harmonic-rich tone that carries through a closed door and is easy to
  locate, checked on a device from the next room.

## A phrase the system cuts off

*2026-10-21. Default, adopted 2026-10-21: the owner left these choices to
the project. Reversible if the owner objects.*

The system can report a phrase it stopped as finished, and can do so before
its interruption notice arrives (code audit M1). Speech therefore records
how far the synthesizer said it got (`speechSynthesizer(_:willSpeakRangeOfSpeechString:utterance:)`,
generally once per word), and `SpokenUtteranceTracker` reads a finish whose
reports never reached the final word as an early ending. An early ending
alone shows nothing, because some voices skip reporting the last word; an
interruption or media-services reset within 3 seconds
(`cutOffCorrelationWindow`) confirms it, and Home shows "Stopped — Again".
A lost output confirms it too, but a phrase still speaking when the output
vanishes carries on through the new one and shows nothing. A phrase that
reported no progress at all is trusted.

If the session could not activate for the phrase, an unexpected end shows
nothing new: "Audio failed" is already showing, and replacing it with
"Stopped — Again" sent the reference app round a loop of Again activations
that failed the same way (code audit L3).

## Audio session notices

*2026-10-21. Default, adopted 2026-10-21: the owner left these choices to
the project. Reversible if the owner objects.*

One adapter, `AudioSessionEvents`, observes the session's notices and hands
each subscriber (the audio warnings, the coordinator, speech, the alarm) a
plain `AudioSessionEvent`. iOS 27 deprecates the interruption notice in
favour of life-cycle notices, because the old notice can lose its ending
(Apple, "Handling audio interruptions"). Built with the iOS 27 SDK (Swift
6.4, Xcode 27) and running on iOS 27, the adapter also observes
`didBecomeInactiveNotification` and reads its `DeactivationContext`: a
deactivation the app did not ask for is an interruption. It keeps the old
notice too, which Apple still documents; every subscriber treats a second
report of the same interruption as nothing new. Only an interruption's
beginning matters, since its ending would only be a cue to resume, which
Brickson never does by itself. Drop the old notice once the minimum iOS
version is 27.

## Orientations

*2026-10-10. Default, from the reference app (its D2).*

iPhone: portrait only, for now. iPad: all four orientations (iPadOS
multitasking requires them). The reference app locked the phone to portrait
because its phone layout lost Emergency off screen in landscape at large
text sizes. Brickson revisits this when the layout engine is ported
(docs/PORTING.md, step 4); until then, `AppBundleTests` pins it.

## Starter phrases

*2026-10-10. Default; for the owner to review.*

New libraries start with five categories and 34 neutral, practical phrases
(`Brickson/Resources/StarterPhrases.json`): Basics, Emergency, Needs,
Conversation and Feelings. Yes and No are quick controls, so they are not
tiles too. Nothing about anyone's condition and nothing self-deprecating
(invariant 7). The wording is a draft to review with people living with
ALS and their families; the category count matters for scanning by eye.

At launch, `PhraseLibraryLaunch` fills an empty store with them. If the
store opens but cannot be filled (a full disk, say), the app speaks from a
filled in-memory library and shows that changes will not be kept, rather
than open on a Home where Emergency has nothing to show. Only an unreadable
starter file, which the tests rule out for a passing build, leaves Home
with Yes and No alone and a warning. Saved phrases that exist but cannot
be opened are never filled over ("An unreadable library is reported,
never replaced").

*Default, adopted 2026-10-21: the owner left these choices to the project.
Reversible if the owner objects.* The starter file is a backup in the
format below ("Backup file format"), and every starter category and
phrase has a fixed identity in it. Identities let a replace, a merge
and a later "Restore starter phrases" tell an untouched starter item from
the person's own words. An identity is never reused for different words:
a starter phrase whose wording changes gets a new identity, and
`StarterPhrasesTests` lists every identity ever shipped with its words.
The starter phrases also follow the editor's rules ("Editing the
library"), which `StarterPhrasesTests` checks.

## The emergency category is always there

*Default, adopted 2026-10-21: the owner left these choices to the project.
Reversible if the owner objects. Decision E1 in the editing and backup
memo.*

Every library has exactly one emergency category, and it keeps at least
one phrase. No edit can delete it, make another category an emergency
one, or delete or move away its last phrase; the family changes its
phrases' words instead, and the editor says why (`LibraryEditRejection`).
`LibraryEdit` has no case that sets or clears the emergency flag, and a
check at the end of `LibraryEdit.plan` refuses any edit, including kinds
added later, that would leave a working Emergency without phrases. Import
only adds to it: every emergency category in a backup feeds the one
emergency category, and replacing with a backup that has none keeps the
current emergency phrases.

So editing can never empty a library. An empty store can only mean a new
install or a lost store, which is why the seeder fills any empty store and
needs no stored "already seeded" flag. A store damaged so that the
emergency category is gone still needs a launch repair that only adds
(the memo's R4). Not built.

## Editing the library

*Default, adopted 2026-10-21: the owner left these choices to the project.
Reversible if the owner objects.*

The rules a family's edits follow live in `LibraryRules` and
`LibraryEdit.plan`, each with a test in `LibraryEditTests`:

- Names and phrases are trimmed at both ends and may not be empty.
- Category names must differ, ignoring case, accents, width, punctuation
  and spaces ("Basics" and "basics!" are one name). Symbols remain
  significant, so distinct emoji names can coexist. A category may not
  take any input name of a Home control (Yes, No, Emergency, Again,
  Repeat, Get Attention, Stop Alert, Settings, Speak): two buttons with one name
  confuse Voice Control and VoiceOver. The emergency category is exempt,
  because it has no button of its own. The fixed controls' names come
  from `HomeControlNames`, including their Voice Control aliases. This
  reservation uses Home's spoken form and also ignores symbols and spaces,
  so adding emoji does not disguise a reserved control name. Import still
  preserves names byte for byte and does not apply these editing rules.
- A category's phrases must differ, ignoring case and width. Punctuation
  counts: "Okay." and "Okay?" are different sentences.
- Pictures come from a fixed list of SF Symbols (`LibraryRulesTests`
  checks each exists).
- After every edit, each item's sort order becomes its place (0, 1, 2 and
  so on), so tied orders from an older store are settled once.
- Moves are absolute: "place before this one", or "at the end". Repeating
  a move changes nothing, so a lingering dwell cannot walk an item along
  (invariant 10).
- Deleting a category deletes its phrases in the same save.
- No edit may leave a library with no categories
  (`LibraryEditRejection.libraryNeedsACategory`). The emergency category can
  never be deleted, so this is a backstop for a store that has lost it.
- Deletes, merges and replaces ask first (invariant 3);
  `LibraryPlan.asksFirst` says which. Where each question appears is
  decided with the screens.
- No PIN or password on the family area: placement keeps family controls
  out of the person's path, and a forgotten PIN would lock a family out of
  the person's words.

*Default, adopted 2026-10-22: reversible if the owner objects.* Category
comparison also ignores standalone blank characters, so a WORD JOINER,
BOM, soft hyphen or control code cannot make a second copy of a visible
name. The check uses Swift Characters (extended grapheme clusters): a
blank-only character is omitted from the comparison key, while joiners,
variation selectors and emoji tags attached to meaningful characters
remain significant. This extends the listed comparison rules without
rewriting stored or imported names. It does not change phrase validation
or declare Unicode punctuation silent.

The editing screens are not built. They live in a Library screen inside
Settings for 1.0 (the memo's recommendation); an edit mode on Home may
come later, for touch only.

## Importing a backup

*Default, adopted 2026-10-21: the owner left these choices to the project.
Reversible if the owner objects.*

- A backup comes in only through the system file picker, from inside the
  family area (built later). Brickson registers no document type in 1.0,
  so no file can open Brickson by itself or put an import question over
  Home, where it could cover Emergency, Yes and No.
- Import keeps the backup's words exactly, byte for byte. It never trims,
  renames or drops them, even where the editor would refuse them (a
  repeated phrase, a Home control's name, an unknown picture), because
  invariant 7 forbids it. The one thing skipped is a phrase with no
  characters at all, which has no words to lose; a phrase of only spaces
  comes in as it is.
- **Add** (`LibraryImport.merge`) only adds: nothing already in the
  library moves, changes or goes away. An incoming category joins a local
  category only when their names are the same, byte for byte (first the
  one with the same identity, then any other), so no name in the backup
  is lost; a renamed category comes in as a new one at the end. The one
  exception is the emergency category: every incoming emergency category
  joins the local one, which keeps its name, because there is always
  exactly one and it has no button of its own. A phrase is skipped when
  its exact words were already in that category before the import, or
  the library already has it (same identity, same words), so adding the
  same backup twice adds nothing the second time, while a backup that
  says the same thing twice in one category keeps both. A phrase whose
  identity is already used gets a new one. A deletion made on another
  device does not travel; to make two devices match, use Replace.
- **Replace** (`LibraryImport.replace`) builds the library from the
  backup as it is: its categories, names, repeats and order. Several
  emergency categories become one, in the first one's place, and a
  repeated identity gets a new one.
- What was skipped or given a new identity is counted
  (`LibraryImportReport`) for the question and the result screen.

## Replacing the library

*Default, adopted 2026-10-21: the owner left these choices to the project.
Reversible if the owner objects. The memo's reading (a) of invariant 7;
reading (b) is the owner's to decide.*

Replace makes the library match a backup, so it removes words the backup
does not have, and invariant 7 says nothing may delete a person's own
words. So:

- Replace runs freely when it removes nothing the person wrote: the
  library is empty, or every name and phrase in it is an untouched
  starter item (known by its identity and exact words), or every word the
  person wrote is also in the backup.
- Otherwise it is refused (`LibraryEditError.safetyCopyRequired`). The
  memo's reading (b) would let it run after a safety copy of the current
  library has been written on the device (memo, section 5.5). That is an
  exception to invariant 7, which says nothing may delete a person's own
  words, so it is **the owner's decision and not adopted**; until the
  owner decides, such a replace stays refused, and a family can use Add
  instead. Safety copies are not built either. If the owner adopts (b),
  the pull request that builds safety copies records it here and in
  invariant 7, and checks the privacy policy and updates it and its
  Effective date, because safety copies keep more of the person's words
  on the device.
- A backup whose emergency category has no phrase with words keeps the
  current emergency phrases, so Emergency always opens to something to
  say.

Correction, 2026-10-22: later branch text had treated the safety-copy
exception as adopted by default. That reversed the owner-only restriction
without an owner decision. The restriction is restored here; building
safety copies alone does not authorize replacing the person's own words.

## Backup file format

*Default, adopted 2026-10-21: the owner left these choices to the project.
Reversible if the owner objects. The names become permanent once the
first backup file exists, which needs an export screen.*

One JSON file, read and written by `BackupCodec`:

```json
{
  "categories" : [
    {
      "isEmergency" : false,
      "name" : "Basics",
      "phrases" : [ { "text" : "Hello.", "uuid" : "…" } ],
      "symbolName" : "bubble.left.and.bubble.right.fill",
      "uuid" : "…"
    }
  ],
  "format" : "brickson.library",
  "formatVersion" : 1
}
```

- `format` is `brickson.library`, not taken from the bundle identifier,
  which can still change. If the app's name changes before the first
  backup exists, change this string with it; after that it stays,
  whatever the app is called. `formatVersion` is 1.
- The order of the arrays is the order on screen. Only categories and
  phrases: no settings, draft, device name or time, so the same library
  always gives the same bytes (sorted keys, one layout). A date belongs in
  the file name.
- Words go out and come back byte for byte. Nothing is normalized, and
  the tests compare UTF-8 bytes, because Swift's `==` calls "é" and "e"
  plus a combining accent equal.
- A file over 8 MB, a file that is not JSON, JSON that is not a backup, a
  backup from a newer version, and a damaged backup are each refused with
  their own sentence ending "Nothing was changed." A newer version is
  never read on a best guess.
- The starter phrases are a file in this format, so one reader serves
  both.
- In 1.0 a backup is a plain `.json` file. Recordings, once built, need
  version 2 (a package with the audio files). A custom file type, if one
  is ever declared, takes its identifier from a name the owner controls.

## An unreadable library is reported, never replaced

*Default, adopted 2026-10-21: the owner left these choices to the project.
Reversible if the owner objects. Code audit M2.*

If a saved library exists but will not open (a damaged file, or one
written by a newer version), or opens but its phrases cannot be read, the
person's words may still be in it. Brickson leaves the file exactly as it
is, speaks from starter phrases held in memory so that Emergency works,
tries the file again at the next launch, and Home says: "Your saved
phrases couldn't be opened. They haven't been deleted. Restart the app to
try again. Don't delete the app: that would erase them." The file is
looked for before opening, so a failed open that leaves a file behind is
not mistaken for saved phrases. A first launch that cannot create the
store has no phrases to lose and only says changes won't be kept. Before
this, every case showed only that message, which did not tell the family
that saved phrases existed or warn them off deleting the app.

Not built: a way for the family to rescue the phrases from a file that
will not open.

## Home version 0 is a stand-in

*2026-10-10. Default.*

The first Home screen (`HomeView`) proves the foundations end to end:
quick controls (Yes, No, Emergency), categories, phrase tiles that speak on
the first activation, Again, and passive warnings. Its sizes are plain
defaults, not the measured gaze, switch and touch sizes. It is replaced
when the layout engine and Home are ported (docs/PORTING.md, steps 4 and
5).

How it behaves, and where it knowingly falls short:

- **One Emergency button.** The emergency category has no button in the
  category row; the Emergency quick control opens it and shows a check
  mark while it is open. Two buttons with the same name confused Voice
  Control and the UI tests, and the reference app did the same.
- **Messages shrink only for their widest word.** The message row always
  reserves two lines of its font at the person's text size; a longer
  message scrolls inside them. It steps down through Apple's text sizes
  only while its widest word is wider than the row, never below the
  default size (2026-10-21, *Home's stand-in layout*). Every phrase start,
  including Again and the same phrase chosen again, shows the message from
  the top. *Before:* it never shrank (`0260099`, which reversed shrinking
  to half), and on 2026-10-21 PR #13 gave compact widths one reserved line
  with a full-width Again below it, because at the largest text sizes on a
  phone a long word was wider than the row and broke.
- **Speech and audio share one status line that keeps its space.** The line
  under the message always holds the height of the tallest of "Speaking"
  and the short audio warnings ("Volume low", "Audio failed"), so nothing
  moves when one appears (invariant 4), and it sits in the part of Home the
  software keyboard never reaches. A warning takes the line over from
  "Speaking", because when something cannot be heard that is what the
  person needs to know (2026-10-21; before, "Speaking" sat under the
  message and the warnings in an area under the grid). The short text is
  what people see; VoiceOver reads the full sentence. The two library
  warnings are decided at launch and never appear later; they sit under
  the phrase grid, which gives up the room they need, so a long one at a
  large text size never pushes Yes, No or Emergency off the screen.
- **Quick controls in one row, at every width.** Yes, No and Emergency, with
  Emergency twice as wide, and each label fitted by the steps in *Home's
  stand-in layout*. Yes, No and Again carry no icon; Emergency keeps its
  warning symbol (a check mark while its phrases show) and drops it before
  its word shrinks, so an icon never splits a word. *Before:* PR #13
  (2026-10-21) put Emergency on a row of its own at compact widths, removed
  the icons from Yes, No and Again, and kept Emergency's in a slot above
  its word, because the labels had no way to fit themselves and broke at
  AX5. The first CI run of this layout put a thumbs-down beside No, and the
  screenshot text-recognition test (`testLargestTextKeepsQuickControlWordsVisible`)
  read it as part of the word ("g)No"), so those three icons stay off. The
  test is unchanged.
- **VoiceOver is told about audio problems.** Text appearing on screen is
  not announced, so Home posts an announcement when an audio problem
  appears (including one present at launch) and on every cut-off phrase.
  It says the full sentence, which names the control to use; the reference
  app announced the short text instead. Cut-off phrases and audio failures
  interrupt what VoiceOver is saying and cannot be cut off (high priority);
  low volume waits until VoiceOver has finished (low priority, where the
  reference app used the default). Focus does not move.
- **Accepted for the stand-in only:**
  - No Get Attention yet, so invariant 10's "reachable in one dwell" holds
    only for Emergency, Yes and No. Get Attention comes in port step 1.
  - Again sits beside the message text the person reads, and Yes sits
    just under it: under a gaze profile a look that rests on the text could
    snap to them. *Home's slot plan* moves Again into the safety row.
    *2026-10-23:* done (*Settings on Home*); Yes, No and Again still
    border the message.
  - The selected category swaps its symbol for a check mark; symbols
    differ in width, so the words beside it can shift slightly inside
    their button. The button itself does not move.
  - The phrase grid scrolls on some phone windows at large text sizes
    (*Home's stand-in layout*, "Where the grid still scrolls").

*2026-10-21 correction:* PR #13 initially treated the iPhone's clipped-text
and Dynamic Type audit findings as strict expected failures pending a new
phone layout. That exception has been withdrawn: the owner requested a
root-cause fix without weakening tests. Labels now retain their full
vertical size, and eager phrase rows remain present while the audit
changes text size. Both device families run the same strict audits.
Those changes initially passed all 16 UI tests on each local device, but
inspection of the AX5 screenshots still found clipped quick-control
words on the phone. The accessibility labels and button frames were
complete even when their visible text was not. A new screenshot-based
text-recognition test reproduced all 24 label checks failing before the
compact arrangement was implemented. It checks Yes, No, Emergency
and Again in three states, in light and dark, without language correction
or expected words supplied to the recognizer. The same test also exposed
Emergency's word splitting on iPad. It uses Vision's fast recognizer
because the accurate mode returned `ON` for a visibly clear `No`;
the fast mode read `No` and still rejected all four old clipped captures.
Matching still requires a whole word, ignoring case only. The four
reachability tests now compare every primary-control edge with its launch
frame after Emergency and speech, allowing 1pt for rounding.
`docs/log/2026-10-21-ui-test-diagnosis.md` records the failing reproductions,
the separate appearance-harness defect and subsequent verification. Later
the same day *Home's stand-in layout* replaced that compact arrangement and
the one-column phone grid with labels that fit themselves; it keeps the
eager rows, the strict audits and the text-recognition test.

## Home's stand-in layout

*2026-10-21. Default, adopted 2026-10-21: the owner left these choices to
the project. Reversible if the owner objects.*

How the stand-in Home fits the space it is given until the layout engine
replaces its fixed sizes (docs/PORTING.md, step 4). Everything comes from
the width and height Home is given (`HomeShape`), never from a device
model, as the owner asked: "For SwiftUI development, standard layout and
navigation primitives remain the appropriate default, using adaptive
layouts and standard SwiftUI containers, instead of building
device-specific interfaces."

- **Regions, top to bottom: the message and its status line, the quick
  controls, the categories, the phrase grid.** Everything a person needs
  while typing sits in the top part, which the software keyboard never
  reaches, and the harmless categories are what sits nearest the keyboard's
  edge (agreed with the Typing and design threads). Gaps are 12pt between
  regions and 8pt between controls inside one.
- **Four category buttons, never scrolled sideways.** Two by two on narrow
  windows, one row of four from a 560pt content width. The region keeps its
  height for four whatever the library holds; a library with more scrolls
  inside it, vertically.
- **Three phrase columns wherever three tiles of 107pt fit** (content of
  337pt or more: every iPhone the app supports and every iPad window but
  the narrowest), two below that. The count depends only on the width,
  never on content or use (invariant 8); 107pt is the narrowest tile that
  holds the starter library's widest word, "understand.", at its default
  size. Rows come from the largest category, so a tile keeps its place in
  every category. Tiles share the height left; the grid scrolls only where
  they would be shorter than the minimum (99pt narrow, 110pt wide, which
  holds the tallest starter phrase). *Before:* PR #13 used one column on
  compact widths and three on regular ones, chosen by size class, because
  two columns split `Maybe.` at AX5 when labels could not fit themselves.
- **Rows are built eagerly.** The grids are plain stacks, not lazy grids:
  lazy rows disappear while Apple's accessibility audit increases the text
  size, so it cannot compare them (PR #13,
  docs/log/2026-10-21-ui-test-diagnosis.md). A short last row keeps its
  tiles at the full rows' width and place.
- **Sizes.** Narrow windows (under 560pt of content): quick controls 64pt,
  categories 48pt, touch sizes that leave the grid room. Wide windows: the
  gaze floors AGENTS.md names, 88pt and 72pt, and tiles of at least 110pt.
  Those are floors: a quick control or category grows to hold one line of
  its words at the person's text size (`LabelFont.lineHeight(at:)`), so a
  short word keeps the person's size. Fixed heights made "No" and "Needs"
  step down at larger sizes, which Apple's accessibility audit reported as
  text that does not follow Dynamic Type (CI, 2026-10-21). These are the
  stand-in's numbers; the engine sets floors per profile.
- **Labels step through Apple's text sizes.** Every Home label is drawn
  with its text style at one of Apple's sizes: the person's own, with its
  icon if it fits; then without the icon; then each smaller size down to
  the default (Large), never below it (`WordFit`, `FittedLabel`). UIKit
  measures each size: word widths, which CI checks against SwiftUI's, and
  the height of the words set in whole-word lines, giving each extra line
  15% more than UIKit's line height because SwiftUI adds the style's line
  spacing (22pt per line at 17pt, not 20.3, measured on CI). CI checks
  that height against SwiftUI's for every starter label at every size
  (`StarterLabelFitTests`). The label is then drawn at the person's own
  size in the lines set for the chosen size, one line each, and SwiftUI
  shrinks the words just enough to fit (`minimumScaleFactor`, never below
  the default size); a line that wrapped would need a line more than the
  label allows, so no word breaks. Two earlier ways failed Apple's
  accessibility audit on CI (2026-10-21), which grows the text and checks
  that each text follows it: drawing a stepped-down label at a smaller
  text size (`dynamicTypeSize`) was reported as not supporting Dynamic
  Type, and letting `ViewThatFits` pick the size swapped the label for
  another view as the text grew, reported as clipped. The phrase grid is
  always a scroll view, turned off where the tiles fit, for the same
  reason.
- **Home's own button style.** Home's controls use `HomeButtonStyle`
  instead of `.borderedProminent`: that style's margins left too little
  width in a phone's three-column grid for the starter words at their
  default size, and its dimmed disabled look fails Apple's contrast audit,
  as Again's did. The style is a standard `ButtonStyle` on standard
  `Button`s (invariant 1): white words on a measured fill, a 4pt margin, a
  white ring when selected, a primary-ink ring when pressed (3:1 on every
  fill, `PaletteTests.pressedRingStandsOutFromEveryFill`) and the system's
  pointer highlight for trackpads, AssistiveTouch and head or eye
  tracking. Disabled is PR #13's look: primary-ink words and border,
  unfilled.

### Where the grid still scrolls

This is part of the stand-in's known gap, "the phrase grid scrolls
(invariant 11)" (docs/HANDOFF.md, *Known gaps*), not an exception to the
invariant: iPhones run Switch Control, AssistiveTouch with Dwell, head
tracking and Eye Tracking, so invariant 11 covers phones too. The layout
engine closes it. Worked out from CI's text measurements (not yet seen
running on these windows):

- A 375×667pt phone window (iPhone SE class): fits at the default text size
  and through xxxLarge (by under a point there); the grid scrolls from AX1.
  The two-row safety row in *Home's slot plan* makes it scroll at the
  default size too, until the engine: since *Get Attention and Stop on
  Home* (2026-10-23) it does, with tiles of about 83pt against the 99pt
  minimum. The starter library needs three grid
  rows there (Basics and Needs hold eight phrases each): in touch that is
  tiles of about 109×68pt, but three floor-sized rows do not fit under
  this arrangement in dwell, switch or gaze profiles, so the engine needs
  another arrangement for this window, never scrolling.
- A 375×667pt phone window with Bold Text on (2026-10-23, *Settings on
  Home*): fits at the default size like the same window without it
  (tiles about 107pt), with Yes and No narrower and Settings showing its
  gear alone. A first draft gave the heavier words a second safety row
  and Settings a row of its own there, and the grid scrolled (tiles
  about 64pt against the 99pt minimum); Codex's review of PR #33 caught
  it.
- A 320pt phone window (2026-10-23): an iPhone with Display Zoom set to
  Larger Text, 320×568pt on a 375×667 phone and 320×693pt on a 6.1-inch
  one. It scrolls at the default size, with two columns and four rows of
  at least 99pt to show. *Settings on Home* made it worse: at 288pt of
  content the safety row's words need two rows and Settings a row of its
  own, so the grid's height falls from about 240 to 110pt and from about
  315 to 190pt (a model of the frames, safe areas of the zoomed 6.1-inch
  phone estimated). The engine needs another arrangement for these
  windows. *Get Attention and Stop on Home* keeps the same heights there:
  two safety rows, and three category rows (Stop's well, four categories
  and Settings in two columns).
- A 402×874pt phone window (iPhone 17 class): fits at the default text
  size, which `HomeLayoutTests` checks (tiles about 126pt since *Get
  Attention and Stop on Home*). At AX5 the grid scrolls: the quick
  controls and categories grow to hold one line of their words at the
  person's size (below), so the tiles left were about 94pt, under the
  99pt minimum, and fewer still with the second safety row. `HomeLayoutTests`
  still checks there that every tile keeps its slot and that the quick
  controls and categories are on screen.
- An 11-inch iPad in landscape and an iPad mini in landscape
  (2026-10-23, by the model of the frames, not seen running): fit before
  *Get Attention and Stop on Home*; at the default size the grid now
  scrolls, with tiles of about 95pt and 65pt against the 110pt minimum,
  because the second safety row and the categories' second row take
  about 176pt. Portrait fits on both.
- Every iPad window CI runs, both orientations, default and AX5: expected to
  fit; `HomeLayoutTests` checks them. On the 13-inch iPad the tiles are
  about 276, 236, 161 and 121pt (portrait and landscape, default and
  AX5) since *Get Attention and Stop on Home*, against 110pt.

## Home's slot plan

*2026-10-21. Default, adopted 2026-10-21: the owner left these choices to
the project. Reversible if the owner objects.* Agreed between the Phone
layout and design threads (the Figma and Claude Design screens). Not built
yet: the stand-in above has regions A to D in this order but not the
wells. This is the contract the next Home work builds on, Get Attention
and Stop Alert on Home first. *2026-10-23:* Get Attention and Stop's well
are built, in places adapted while A's trailing column (Phrases and Type)
is missing: *Get Attention and Stop on Home* says where and why.

**Every control on Home has a slot: a fixed place with a stable
identifier.** The slot's frame comes from the space available, the input
profile and the text size (the layout engine), never from the state of
Home, the library's contents or use. A state changes what a slot shows,
never where it is.

- **Regions, top to bottom: A, C, B, D.**
  - **A, the message.** The message with its status line, and a trailing
    column of two controls that are there in every state: Phrases above
    Type. On regular widths the message spans three of C's five columns
    and the trailing column the other two, so Emergency, Yes and No sit
    under the message and Again and Get Attention under the trailing
    column; over four columns, Again was nearest the message's trailing
    end on both iPad windows the design thread sampled. They work like the segments of a segmented control: each only
    picks its own mode (browsing phrases, or typing) and shows selected
    while that mode is on, so a repeat meets the same control and changes
    nothing.
  - **C, the safety row.** Compact widths, two rows: Yes, No and
    Again; then Emergency across the first two columns and Get Attention
    in the third. Regular widths, one row: Emergency, Yes, No, Again,
    Get Attention. While typing, Again's well shows Speak; both speak the
    message, so neither is the other's opposite.
  - **B, the categories.** Stop Alert's well first, in the leading
    column directly below Emergency (about 95pt wide on a 375pt phone);
    a category in the cell under it; then the other categories, at least
    116pt wide; Settings in the last cell, at the trailing end. Compact
    widths, two rows: Stop Alert, category 1, category 2; then category 3
    (under Stop Alert), category 4, Settings. Regular widths, one band:
    Stop Alert above category 1 in the leading column, categories 2 to 4
    at full height, then Settings. While typing, the draft's Clear and Put
    Back each take a fixed category slot here, away from the draft and
    from Speak.
  - **D, the phrase grid.** Fixed columns; rows from the largest category
    (invariant 8).
- **Wells.** A control that only applies in some states (Stop Alert,
  Speak, and the draft's Clear and Put Back) has a well that keeps its frame in every state. While the
  control does not apply, its well is empty: no control, hidden from
  accessibility, so there is nothing there for VoiceOver, Voice Control or
  a pointer to choose, and nothing else moves into it.
- **Start and stop live apart** (invariant 10). Get Attention is in C, at
  the trailing end; Stop Alert is the top well of B's leading column,
  directly below Emergency, in another region and on another row. A
  repeated activation on Get Attention can never stop the alarm, and one
  on Stop Alert can never restart it. The design drawings
  use these slot names as their layer names.
- **What a held activation meets next** (invariant 10, chains scored on
  the drawn frames for an iPhone 17, a 375×667pt phone and a 13-inch iPad
  in both orientations, by nearest centre and by nearest edge with ties
  counted). After Stop Alert, its well empties and the nearest control is
  the category under it or Emergency; a repeat on either only changes
  which phrases show. After Phrases or Type, the nearest control is the
  same one, now selected, so a repeat does nothing. *Before:* Stop Alert
  sat above Settings, so a repeat after Stop could open the Settings
  cover; and the way out of typing was a well above Type, so a repeat
  after leaving typing could reopen it. The design thread's chain scores
  found both; the table is in the design document, *What a held
  activation meets next*.
- **Open hazard, not accepted: Yes and No border the message**
  (invariant 10; design rule "Wherever a pointer rests can activate"). On
  every window the design thread measured (an iPhone 17, a 375×667pt
  phone, the 13-inch iPad in both orientations), Yes and No are the
  nearest controls to the message, one gap (10 to 16pt) from its edge,
  with Emergency too on the iPads; a look resting on the message can
  therefore speak Yes or No. Something in C has to border the message, and
  every control in C is one the person must reach in one activation, so
  the plan alone cannot remove it. It is not an accepted exception:
  invariant 10's exceptions are the owner's to accept. The layout engine's
  thread measures it per profile and either removes it by placement (a
  wider gap, or a harmless control nearest the message) or brings the
  measured cost to the owner to accept or reject, before the slot plan
  ships in a dwell, switch, head or gaze profile. *2026-10-23:* reduced,
  still open; *Settings on Home* says by how much and what decides the
  rest.
- **Open: a library with more than four everyday categories.** Region B
  is an L (Stop Alert's column beside the categories), which cannot scroll
  as one standard container, so the stand-in's answer (the category
  region scrolls) does not carry over. Whatever is chosen must keep every
  category reachable through standard containers, never scroll Stop
  Alert, Settings or their neighbours away, leave the starter library
  unscrolled in every profile, scroll a grown library at the floor at
  most, and score the chain after any new control. Neither thread found
  an arrangement that meets all of these. The layout engine's thread
  decides it, before editing or import can add a fifth everyday category.
  *2026-10-23:* until then, Home keeps the fourth and later categories in
  the fourth category's cell, which scrolls on its own
  (`CategorySelection.inCell`); Stop, Settings and the other cells never
  scroll. No screen can add a fifth category yet, so nobody meets it.
- **Get Attention, Emergency, Yes and No are in C in every state**,
  including typing: C is above the worst-case software keyboard
  (invariants 2 and 10; the Typing thread's measured keyboard tops).
- **Settings covers Home with its own safety bar at Home's frames:** Back
  to Talking over A's trailing column (so it closes onto Phrases or Type)
  and Get Attention over the message's footprint, so the controls a look reaches when Settings opens or closes
  are the harmless ones.
- **Identifiers.** Each slot has a stable accessibility identifier, named
  for the slot, not for its label (for example the Again well keeps its
  identifier while it shows Speak). UI tests and captures compare frames by
  identifier across states, as `HomeReachabilityTests` does today by label.

*Before:* none; the stand-in Home had no wells (*Home version 0 is a
stand-in*).

## Home's scan order and names

*2026-10-22. Default, adopted 2026-10-22: the owner left these choices to
the project. Reversible if the owner objects.* The first part of ROADMAP
R0 item 3's accessibility work (docs/ACCESSIBILITY.md, sections 1 and 3;
[`log/2026-10-22-home-scan-order-and-names.md`](log/2026-10-22-home-scan-order-and-names.md)).

- **Yes, No and Emergency first.** VoiceOver, Switch Control and Full
  Keyboard Access reach Home's regions in a fixed order: C (Yes, No,
  Emergency), then A (the message, its status line and Again), then B
  (the categories), then D (the phrases), then the library warnings. With
  auto scanning, every step before Emergency, Yes and No is time spent
  waiting. On screen A stands above C, and SwiftUI orders elements of
  equal priority by where they are, so each region carries a fixed
  accessibility sort priority (`HomeRegion`). The order never depends on
  Home's state, the library or use (invariant 8). A VoiceOver user's
  first swipe now lands on Yes, not on the message. When the slot plan's
  wells are built, the controls that join C (Get Attention, and Again
  moving there) and A (Phrases and Type) keep this order of regions.
  *2026-10-23:* Again is in C, reached after Emergency, and Settings in
  B, after the categories (*Settings on Home*). Get Attention is in C,
  after Emergency and before Again; Stop, while it shows, is reached
  first in B (*Get Attention and Stop on Home*).
- **Each region is an accessibility container** (`.contain`), so its
  controls are reached together and Switch Control can offer it as a
  group when Group Items is on. The regions carry identifiers for tests
  and no spoken labels: what VoiceOver and Switch Control say on entering
  a group is a device check first.
- **Names, the visible words first.** Each fixed control's names for Voice
  Control and Full Keyboard Access (`accessibilityInputLabels`) start
  with the words it shows, from one place the view and the tests both
  read (`HomeControlNames`). Another name is added only where people
  commonly use a different word for the same action, never one for a
  different action: Again also answers to "Repeat". "Help" is not given to
  Emergency, which opens the emergency phrases and says nothing, while a
  person saying "Help" may mean Get Attention; the thread that puts Get
  Attention on Home (R0 item 4) decides. *2026-10-23:* Get Attention also
  answers to "Help", and Stop to "Stop Alert" (*Get Attention and Stop
  on Home*). Categories and phrases answer to
  their own words only, and Brickson never renames them (invariant 7).
- **No two controls on Home share a name.** Voice Control stops to ask
  which one is meant when two do. Names are compared as Voice Control
  hears them, without case, accents or punctuation, and a unit test checks
  every state of the starter library (`HomeNameCollisionTests`). When
  editing lets a family add a phrase or category that collides, the
  editing thread (R0 item 6) decides what the editor says; it never
  renames the person's words.

*Before:* none. Home was reached in its order on screen (the message and
Again first), as one flat list, and its controls answered only to their
labels.

## Settings on Home

*2026-10-23. Default: the owner left these choices to the project.
Reversible if the owner objects.* The Settings button that ROADMAP R0
item 7 left for later ([`work/settings-on-home.md`](work/settings-on-home.md),
[`log/2026-10-23-settings-on-home.md`](log/2026-10-23-settings-on-home.md)).
*Later the same day, Get Attention and Stop on Home* replaced the safety
row's and Settings' arrangements below: the safety row is two rows on
every window (Yes, No and Emergency; Again and Get Attention), and
Settings takes the categories' last cell in each of their three
arrangements, showing its gear alone where its word does not fit.
Emergency still ends the first row, under Back to Talking.

- **Settings is the last cell of region B,** at the trailing end of the
  categories, where *Home's slot plan* puts it: a column as tall as the
  category rows where it and the categories fit side by side, otherwise a
  row of its own under them (320pt windows: Slide Over, and an iPhone
  with Display Zoom). Where its word does not fit beside the categories
  but its gear does (a 375pt phone with Bold Text, whose heavier
  "Conversation" needs the room, and windows 328 to 363pt wide without
  it), Settings shows the gear alone and keeps the name "Settings" for
  VoiceOver, Voice Control and Switch Control, with a large copy for the
  large content viewer: a row of its own there would make the starter
  phrases scroll (invariant 11), which is worse than a gear a family
  member recognises. The gear alone departs from AGENTS.md's *Words
  never break* (the icon is decorative and drops first) and from *Names,
  the visible words first* above, so it is named in PR #33 for the
  owner, who decides by merging or objecting. It is a standard `Button`
  styled like Home's other controls, named "Settings" and nothing else,
  and assistive technologies reach it after the categories. A library with more than
  four everyday categories scrolls only the categories; Settings stays.
- **Again joins the safety row, which reads Yes, No, Again, Emergency.**
  The slot plan moves Again into C. Emergency goes at the trailing end
  because Settings' Back to Talking sits over A's trailing end, and until
  A's trailing column (Phrases and Type) is built, what lies nearest under
  Back to Talking is C's trailing control. Beside the message, that was
  Again: a look still resting where Back to Talking was would say the last
  message again. Now it is Emergency, which only shows the emergency
  phrases, by nearest centre and nearest edge on every window scored (the
  work file's table), and `SettingsOnHomeTests` checks the running app on
  CI's iPad and iPhone at the default and largest text sizes. Where the
  row is short of room, Yes and No, the shortest words, narrow first,
  down to their own minimum, with Again and Emergency at theirs; only
  where even that does not fit (the 320pt window) do Yes, No and
  Emergency keep the first row and Again take a row of its own under
  it, because a second row costs the phrases a row's height. The slot plan's regular-width order (Emergency first, Get Attention
  last) comes back with Phrases and Type; until then, whoever puts Get
  Attention and Stop on Home keeps a control that says nothing nearest
  under Back to Talking, or the test fails (it did: Emergency). Again is reached after
  Emergency by assistive technologies, though it sits before it.
- **Widths come from the words.** Each control's minimum is its starter
  word at the default text size, with the label's slack and inset,
  measured with the real fonts, and wider with Bold Text on, which is
  measured at the heaviest weight (`HomeShape.MinimumWidths`, checked by
  `StarterLabelFitTests`; `HomeShapeTests` checks every width from 288 to
  1400pt). Settings' gear alone gets Apple's 44pt minimum target. So Bold Text can change the arrangement, as text size changes
  heights. The Bold Text minimums were first worked out from Apple's SF
  Pro font, whose measured widths matched CI's within half a point.
- **The first-run hint** shows in the message area, in place of the
  placeholder, until Family Setup has been opened once (*First launch
  opens Home; setup lives in Settings*).
- **"Yes and No border the message" stays open, reduced** (*Home's slot
  plan*). The message now spans the width with no control beside it; the
  share of it whose nearest control speaks fell from about 89 to 95% to
  about 61 to 67% on phones, and from about 72 to 75% to about 60 to 65%
  on iPads, by either rule. Yes, No and Again still border it. A device
  check decides the rest: whether Snap to Item and Dwell pick the nearest
  centre or the nearest edge. If the nearest edge, a harmless control
  across the message's full width (Emergency in a row of its own under
  the message) removes it, at about 72pt of height on a phone that the
  engine must find. If the nearest centre, no placement with C under A
  removes it, and the measured cost goes to the owner before a dwell,
  switch, head or gaze profile ships. The layout engine's thread owns it.
- **Bold Text never costs a phone's phrases any height**
  (`HomeShapeTests.boldTextTakesNoHeightFromAPhonesPhrases`): on every
  phone width the app supports, the heavier words narrow Yes and No or
  leave Settings its gear alone, but add no row above the phrases.
- **Settings' first screen starts right under its bar.** The safety bar
  is only as tall as its tallest control, and the sound line sits at the
  foot of the cover (*Settings is a cover with a fixed safety bar*), so
  the root's Family Setup row starts under the bar, over the spot where
  Home's Settings was. Where half the width holds the row's words on one
  line (`SettingsRootColumns`, which measures the row; a `ViewThatFits`
  failed Apple's audit here, as it had for labels), the row takes the bar's
  trailing column, under Back to Talking and as wide, with the note
  beside it; on phones it spans the width. At the foot, the sound line's
  nearest controls are whatever rows a screen has scrolled to its lower
  edge, some of which speak a sample or change a setting; under the bar
  its nearest were Back to Talking and the navigation bar. That costs a
  look that reads a warning, which is rare, to keep a look that opens
  Settings off Back to Talking. *Before:* Get Attention's empty place stretched the bar to
  about a third of the screen (since PR #23), so Back to Talking sat over
  Home's Settings, and a look resting after Settings closed met Home's
  Settings again (`SettingsOnHomeTests` on PR #33's first CI run).
  Modelled from that run's frames, fixing the bar alone still left Back
  to Talking nearest by centre on the iPad, where a full-width row's
  centre is mid-window, and by edge on the iPhone at the largest text
  size, where the sound line, kept tall enough for its longest warning,
  sat between them.
- **The next held activation is scored, not fixed.** After Family
  Setup's row, the chain goes on as the work file's table says: Set Up
  Step by Step on a phone at the default size; Back to Talking by centre
  (Set Up Step by Step by edge) on a wide window; Back to Talking by both
  on an iPad at the largest size, so Settings closes onto Emergency; on a
  phone at the largest size, Back to Talking or the navigation bar's
  back button. None speaks, alarms or deletes. Breaking it needs Family
  Setup's own rows placed for it, which is the Settings chain scoring
  in docs/HANDOFF.md, *Known gaps*.
- **From Settings, Yes, No and Emergency are two activations away:**
  Back to Talking, whose spot lands nearest Emergency on Home, then the
  control. The cover is the family's screen, not a Home state, and opens
  on the way back and Get Attention's place (AGENTS.md, *Family controls
  stay out of the person's path*; *Settings is a cover with a fixed
  safety bar*). Home's Settings button makes that reachable by a stray
  activation; Get Attention joins the bar in its own pull request, now
  that Home has Stop (*Get Attention and Stop on Home*).

*Before:* Home had no Settings button, so only UI tests opened Settings
(`--screen=settings`, which `SettingsTests` still use to start there),
and Again sat beside the message (*Home version 0 is a stand-in*).

## Get Attention and Stop on Home

*2026-10-23. Default: the owner left these choices to the project.
Reversible if the owner objects.* The controls PR #16 left for later,
ROADMAP R0 item 4 ([`work/get-attention-on-home.md`](work/get-attention-on-home.md),
[`log/2026-10-23-get-attention-on-home.md`](log/2026-10-23-get-attention-on-home.md)).

- **Get Attention is in C, directly under Emergency.** The safety row is
  two rows of two equal columns on every window: Yes and No share the
  leading column with Emergency beside them, and Again and Get Attention
  are under them. Get Attention is not in the first row because the
  message spans the full width above it, and a look resting on the
  message must never meet an alarm. Again leaves the message's edge too.
  The slot plan's own C (one row on wide windows, Get Attention at its
  trailing end under Phrases and Type) comes back with A's trailing
  column. Emergency still ends the first row, under Settings' Back to
  Talking (*Settings on Home*).
- **Stop has a well of its own at the categories' leading top, with a
  category directly under it.** Region B takes one of three arrangements
  from the width (`HomeShape.CategoryArrangement`): a band from 584pt of
  content (630pt with Bold Text), where four categories and Settings with
  its word fit in a row, with Stop above the first category and the
  other three and Settings at the band's full height; three columns from
  304pt (328pt), Stop and two categories over two categories and
  Settings; two columns below that. The band is used only where Settings
  keeps its word, so as a window widens Settings' word never shows,
  hides and shows again. The well keeps its frame whether Stop shows or
  not; empty, it is hidden from accessibility and nothing moves into it
  (invariant 8).
- **What a held activation meets** (invariant 10). Stop is never the
  control nearest Get Attention's spot, so a held look on Get Attention
  never stops the alarm; after Stop, its well empties and the nearest
  control is the category under it, which only changes which phrases
  show, never Get Attention. Both rules (nearest centre, nearest edge,
  ties counted) at every content width from 288 to 1400pt, with and
  without Bold Text, at grown text sizes
  (`HomeShapeTests.aHeldLookMeetsNothingHarmfulAfterGetAttentionOrStop`),
  and in the running app on CI's iPad and iPhone
  (`GetAttentionOnHomeTests`). The narrowest margin is after Stop by
  edge: the category under it is 8pt away and Again, above it, 12pt.
- **Get Attention is never disabled.** A second activation while the
  tone plays changes nothing (*Get Attention*), and a control that greyed
  out while the alarm sounds would look broken to the person calling.
- **Names.** Get Attention also answers to "Help" with Voice Control:
  people say it to call for help, and Emergency, which says nothing,
  never takes it (*Home's scan order and names*). Stop shows "Stop", the
  word that fits beside two categories on a 375pt phone with Bold Text,
  and also answers to "Stop Alert". All four are names a category cannot
  take (`LibraryRules`).
- **Colours of their own.** Get Attention `#B45309` and Stop `#0F766E`
  (*Solid fills on Home, system glass elsewhere*; `Palette`, pinned in
  `PaletteTests`), so neither is taken for the other or for Emergency at
  a glance; the words and icons (a bell, a crossed-out bell) say what
  each does, so nothing depends on colour alone.
- **The status line's order:** an audio problem, then "Sounding" while
  the alarm sounds, then "Speaking" (`HomeStatusLine`). "Sounding" has a
  reserved invisible copy like the others, so nothing moves, and
  VoiceOver reads it as "Get Attention is sounding." Every failed or
  cut-off alarm is announced, a retry that fails again included
  (`AttentionAlertPlayer.failureSequence`).
- **Scan order.** C: Yes, No, Emergency, Get Attention, then Again. B:
  Stop while it shows, the first category, the others, then Settings.
  In the band the first category sits under Stop, below the others'
  tops, and SwiftUI orders elements of equal priority by where they are,
  so Stop and the first category carry their own priorities
  (`HomeRegion.firstInRegion`, `secondInRegion`).
- **More than four everyday categories, for now:** the fourth cell holds
  the fourth and later ones and scrolls on its own
  (`CategorySelection.inCell`); nothing else in B scrolls. No screen can
  add a fifth yet; the layout engine's thread decides for good (*Home's
  slot plan*, *Open*).
- **A silent stand-in tone for UI tests.** Debug launches with
  `--attention-tone=silent` play `SilentAttentionTonePlayback`, which
  says it is playing until stopped and makes no sound, so UI tests sound
  and stop the real alarm without depending on the simulator's audio. A
  release build reads no launch arguments.
- **The cost is height.** Phones give up a quick-control row (72pt at
  the default size); wide windows also give the categories a second row
  (176pt in all). CI's windows still fit the starter library; three more
  windows scroll at the default size (*Where the grid still scrolls*).
  The trade is a call for help one activation from every Home state,
  which invariant 10 requires and nothing else gives.
- **Settings' Get Attention place stays empty** in this change. Starting
  the alarm there no longer leaves it with no way to stop, but on wide
  windows Settings' root puts its note under that place, so adding it
  needs its own scoring (docs/HANDOFF.md, *Known gaps*).

*Before:* the alarm was tested code with no control on screen, Home's
status line ran with it always idle, the safety row was one row (Yes,
No, Again, Emergency) wherever it fit, and the categories were two by
two or one row of four with Settings beside or under them (*Settings on
Home*).

## Typing is a state of Home

*Default, adopted 2026-10-21: the owner left these choices to the project. Reversible if the owner objects.*

When someone chooses Type, Home stays on screen and only its lower part
changes: the keyboard appears where the categories and phrase tiles were.
Typing is not a separate screen or a sheet, because either would hide or
duplicate Emergency, Get Attention, Yes and No, which must stay one
activation away in every Home state (invariants 2 and 10).

**The band rule.** A band across the top of Home holds everything the
person must always reach: the message (which shows the words being
typed), Emergency, Get Attention, Yes, No, Speak, the way back to the
phrases and the space for warnings. The band is sized so that **Apple's
keyboard never reaches it**, on the worst screen, in every orientation
and text size. Because controls keep their relative places across
profiles (invariant 8), the room Apple's keyboard leaves is the room
every profile gets, even one that never uses Apple's keyboard.

- Nothing moves when the keyboard appears or hides (invariant 11): the
  keyboard covers the lower part of Home instead of pushing it up.
- An app cannot ask how tall the keyboard will be before it appears. So
  the layout reserves room for it as a function of the window alone (its
  size and the text size), never of the device model. Measured keyboards
  are rows in the tests, and a UI test fails if the live keyboard's top
  crosses the band. `KeyboardProbeTests` measures it; the
  table itself arrives with the layout engine (docs/PORTING.md, step 4).
- The reference app's measurements on iOS 27.0 simulators with the full
  software keyboard: a 13-inch iPad in landscape, keyboard top at 534 of
  1032 points; the same iPad with Display Zoom set to Larger Text, 276 of
  774 (the worst case: one row of 88pt controls fits under the message,
  at the default text size only); an iPhone 17 Pro in portrait, 546 of
  874. Brickson's own numbers are in docs/log/2026-10-21-typing-foundation.md.
- Only controls that are harmless if a look slips up from the keyboard
  sit nearest its edge; Speak, Yes, No, Get Attention, Emergency and
  Clear sit away from the keys. Where the band has room for only one row,
  that cannot be met, and each such screen becomes a named, measured
  exception for the owner.
- While typing, nothing that speaks sits under the keyboard, so hiding
  the keyboard reveals nothing that speaks.

Why: the reference app put its quick controls in a right-hand column, and
the real keyboard covered Speak and Get Attention there (D27,
docs/LESSONS.md, "Test with the real software keyboard"). The rule is set
before Home is laid out, so that mistake cannot be built again.

## Typing uses Apple's keyboard

*Default, adopted 2026-10-21: the owner left these choices to the project. Reversible if the owner objects.*

Version 1.0 types with Apple's own keyboard, everywhere. It brings
QuickType predictions, autocorrection, Text Replacement, dictation, and
the keyboard features Apple builds into Switch Control and Eye Tracking,
and Apple keeps improving them. Two additions may follow, in this order:

1. **A row of Brickson word buttons** just above the keyboard, at the
   profile's target size, wherever the band leaves room (the larger
   iPads). After a word is put in, the word buttons stay empty until the
   next key, so a lingering look cannot keep adding words. Built only
   after the device check on what happens at the keyboard's edge
   (docs/log/2026-10-21-typing-foundation.md, check 5).
2. **A large-key Brickson keyboard** for pointer and gaze users on large
   iPads, only if device checks show Apple's keyboard is too slow or
   unsafe for them. Never on iPhone: ten keys of at least 44 points do not
   fit across any iPhone.

The typing rules live in `MessageComposer`, which does not care which
keyboard feeds it, so either addition reuses them.

Not available in SwiftUI: turning off *inline predictions* (the grey word
that Space accepts). That needs a wrapped UIKit text view; until then it
is a setup tip (Settings › General › Keyboard › Show Predictions Inline).

## Writing Tools off while typing

*Default, adopted 2026-10-21: the owner left these choices to the project. Reversible if the owner objects.*

Every field that types a message to speak turns off Apple Intelligence's
Writing Tools (`typingFieldTraits()`, which applies
`writingToolsBehavior(.disabled)`). A stray look could otherwise let it
rewrite the person's words before they are spoken in the person's own
voice (invariant 7), and AI-written replies are a hard stop (invariant
9). For the same reason no on-device language model predicts words or
finishes sentences.

## Third-party keyboards refused in 1.0

*Default, adopted 2026-10-21: the owner left these choices to the project. Reversible if the owner objects.* *Not built yet.*

Brickson refuses keyboards from other apps, so only Apple's keyboard
appears in it. Reasons: the keyboard table stays true (other keyboards
have other heights, and could cover the band), and the privacy promise
stays simple (a keyboard with Full Access can send what is typed to its
maker). The cost: someone who relies on an accessible keyboard from
another app, such as one with larger keys, could not use it in Brickson.
Revisit if people ask. It is built with the typing state, as
`application(_:shouldAllowExtensionPointIdentifier:)` returning false for
`.keyboard` in an app delegate.

## Return speaks

*Default, adopted 2026-10-21: the owner left these choices to the project. Reversible if the owner objects.*

The keyboard's Return key speaks the whole message, as an extra path;
Speak stays the main one. A typed line break is never kept in the
message. A line break inside pasted text becomes a space. Return with
nothing to say does nothing. `MessageComposer` holds the rule, so it
works the same with any keyboard (docs/LESSONS.md, "The return key must
speak": in the reference app Return added a line break, nothing was
spoken, and the line break was later read as a pause).

Still open for dwell users: Apple's Return key sits among the letter
keys, so a look that slips onto it speaks a half-written message. That
goes against invariant 10 (no speaking control beside where the person
points). Either it becomes a named, measured exception for dwell
profiles, or Return stops speaking in those profiles. That is decided
after the keyboard-edge device check (check 5 in
docs/log/2026-10-21-typing-foundation.md), not before.

## The typed message

*Default, adopted 2026-10-21: the owner left these choices to the project. Reversible if the owner objects.*

How the message being typed behaves (`MessageComposer`, `DraftStore`):

- **Speaking keeps the message**, so it can be said again or added to
  (invariant 3: speaking never changes data). A setting to clear it after
  speaking is built into `MessageComposer` but not offered.
- **Clear can be undone once.** The cleared words stay in memory, never
  on disk, until a later Clear replaces them or the app closes. Nothing
  else may take Clear's place, so there is never an Undo button where
  Clear was (invariant 10). Where the restore control sits is Home's
  layout's decision.
- **At most 2,000 characters** (about two to three minutes of speech), so
  an accidental paste cannot speak for many minutes. An edit that would
  pass the limit is refused whole and nothing is cut short. A longer
  message restored from an older version is kept whole (invariant 7).
- **Kept across launches.** The message is saved after every change to a
  small file, Application Support/Typing/draft.txt, written in one step
  so a crash leaves the old or the new message and never part of either.
  It is restored at launch without speaking and without opening typing,
  and Clear deletes the file. This is what the privacy policy promises
  ("The message you are typing, so it is still there if the app closes.
  It stays until you clear it.").
- **A failed save never loses the words.** They stay on screen and in
  memory, Home shows "Message not saved" as passive text in the warning
  space (invariant 5), and the next change or `retrySave()` tries again.
  A file that cannot be read at launch gives an empty message and
  "Message not restored". The message is never logged and never put in a
  crash message.

## Personal Voice permission is asked at launch, for now

*2026-10-10. Default, from the reference app. 2026-10-21: the moment is
now one policy, and the answer is read again on every return to the
front (Personal Voice foundation).*

`SpeechService` asks for Personal Voice permission when the app starts.
The reference app did the same, with a comment saying that asking after
the first sentence can hide personal voices for the rest of the session;
Apple's documentation does not say so, so treat that as unverified. As a
result the system question appears on first launch with no explanation.
Onboarding should explain Personal Voice first and then ask; that comes
with Settings and setup (docs/PORTING.md, step 7).

When to ask is `PersonalVoiceAskPolicy`, chosen in one line, the first
of `AppAudio.personalVoiceAskPolicy(for:)` (until 2026-10-22, a line in
`AppAudio.makeForApp`). `.atLaunch` is today's behaviour and stays the
app's policy. `.fromSettings` asks only from the Voice screen's explained
button (`SpeechService.requestPersonalVoiceAuthorization()`), and at
launch asks again only once the person has allowed it, which shows no
question (Apple: the person is prompted initially and changes the answer
in the Settings app). Switch to `.fromSettings` when two things are true:
Settings has that button (it has since 2026-10-22: "Asking for Personal
Voice from Voice Settings"), and a device shows that a voice allowed
after the first phrase of a session speaks without a relaunch (check D1
in docs/recon/2026-10-15/directions/onboarding-and-settings.md, 2.5; on
docs/HANDOFF.md's device list). A debug build launched with
`--personal-voice=ask-from-settings` is the build D1 needs, with no
change to the code. If D1 needs a relaunch, keep `.atLaunch` and explain
afterwards on the Voice screen.

Whatever the policy, the service reads the system's status at launch,
before any answer (so someone who allowed it before speaks in their own
voice from the first phrase), after every answer, and each time the app
comes back to the front (`refreshPersonalVoiceAvailability()`), with the
voice list each time: access can be turned on or off, and a voice made,
in the Settings app while Brickson waits.

No Info.plist key is needed for the request. If **Allow Apps to Request to
Use** is off (Settings → Accessibility → Personal Voice), the system denies
the request without asking. `AccessibilitySettings.openSettings(for:
.personalVoiceAllowAppsToRequestToUse)` opens that switch directly; the
Voice Settings screen offers it when permission is denied, except on the
visit whose Ask button was just answered, with the written path always
shown (2026-10-21, `PersonalVoiceGuidance`).

## First launch opens Home; setup lives in Settings

*2026-10-21. Default, adopted 2026-10-21: the owner left these choices to
the project. Reversible if the owner objects.*

Brickson opens straight onto Home on first launch, never onto a setup
screen: someone who needs to speak can do so the moment it opens, and a
setup flow in front of Home would have to be got past by whoever is
holding the device. Setup is a place inside Settings (Family Setup), not
a gate. Until Family Setup has been opened once, Home's empty message
area shows one passive line, `FirstRunHint.text` ("Family: help with
setting up is in Settings."), through the `showsSetupHint` environment
value. The line does not name the app, so it survives a rename.

## Settings is a cover with a fixed safety bar

*2026-10-21. Default, adopted 2026-10-21: the owner left these choices to
the project. Reversible if the owner objects.*

Settings is a full-screen cover. Because it hides Home's quick controls,
every Settings screen sits under one fixed row (`SettingsSafetyBar`): a
start-only Get Attention at the top leading edge and Back to Talking at
the top trailing edge, at the same frames on every screen. Get
Attention's place is kept empty until Home shows Get Attention and Stop:
the alarm exists (`AttentionAlertPlayer`), but starting it here while Home
has no Stop would leave it sounding with no way to stop it. Because the
place is kept, adding it moves nothing. Under the bar is a `NavigationStack(path:)`
whose root holds only a large Family Setup row and a sentence; every
setting is a screen below, so a stray dwell that opens Settings meets
only the way back, Get Attention and one row that navigates. Family
Setup opens on passive text at least as tall as that row
(`FamilySetupView.openingHeight`), so nothing that can be activated sits
under the spot just activated. With Snap to Item the nearest control is
then a row that only navigates on a phone at the default text size, and
can be Back to Talking elsewhere (*Settings on Home*); chains through
Settings are not fully scored yet (docs/HANDOFF.md, *Known gaps*).

Family Setup's rows: Set Up Step by Step, Voice Settings, Reaching the
Screen, Keep Brickson Open (Guided Access and Assistive Access), Privacy
Policy and About. The Library's row joins it as `SettingsRoute.library`
when the Library lands; it never closes Settings or hands over to an edit
mode on Home. Home owns where `SettingsButton` sits; Settings provides the
button and `settingsCover(isPresented:)`.

Every control is a standard `Button` or `NavigationLink` at least 64pt
tall, white on `Palette.controlFill` or `Palette.phraseFill`; text is
primary ink, never the system's secondary gray or grouped-list headers,
which measure under 4.5:1. No toggles and no system alerts. Multiple
choice answers only select; Clear My Choices is a separate button.

At the foot of the cover, below every screen, a line kept for it shows
any sound problem, because the cover hides Home's warnings (invariant 4;
it moved there from under the bar in *Settings on Home*). It uses `AudioSafetyPolicy`
with `.dismissThenRepeat`, the words for a screen over Home ("Stopped —
Back"), and is passive and the same height whether or not it shows
anything. Home's warnings, still alive under the cover, announce each
problem to VoiceOver, so the line does not announce it again. A voice
sample the system cuts off shows nothing, as on Home: the family hears
it stop and chooses Hear again.

Before: the reference app put Back to Talking top-leading and Get
Attention trailing. Brickson swaps them so Back to Talking lands over
Home's trailing column (Clear and Type in the planned Home) and Get
Attention over the message, whose nearest Home control is Yes.

## Speed is a set of fixed choices

*2026-10-21. Default, adopted 2026-10-21: the owner left these choices to
the project. Reversible if the owner objects.*

Voice Settings offers seven speeds, from 60% to 120% of normal in tenths
(`SpeedChoice`). Each is a button that sets that speed and plays the
sample at it; the chosen one is marked and selected. Choosing a speed
again changes nothing, so a held look, a lingering dwell or a switch's
auto-select that fires it again after the sample finished cannot walk the
speed (invariant 10, "chains of several activations are scored"). Each
speed keys its own sample (`VoicePreviewControl.speed`), so another speed
chosen while a sample plays takes effect at once. The speeds sit on
`SpeechRateSteps`' grid; a speed that is not one of them is named
("Speaking at 130% of normal speed") and no choice shows as chosen.

Before: Slower, Faster and Normal Speed buttons, as in the reference app,
were built first and replaced the same day after Codex's review of PR
#23. Their repeat was absorbed only while the sample played, so a look
that stayed on Faster stepped again as each sample ended.

## Settings resets when idle and never closes

*2026-10-21. Default, adopted 2026-10-21: the owner left these choices to
the project. Reversible if the owner objects.*

After 90 seconds with no control used, no screen pushed or popped and no
scrolling while Brickson is active, Settings goes back to its root,
rebuilt scrolled to the top, and **stays open** (`SettingsIdleClock`,
`SettingsActivity`). Closing would put Home's controls under a spot
nobody chose. The clock is held while the privacy policy's web sheet is
open, while iOS asks about Personal Voice, while the alarm sounds, while
a screen is being scrolled, and
while a screen calls `holdsSettingsIdleReset(true)` (for the Library's
editors and backup tasks); when the last hold ends, the full 90 seconds
start again. Time in another app or with the screen off never counts.
Time is `ContinuousClock`; the pure clock takes `now:`.

## Setup answers are kept as offered, never as completed

*2026-10-21. Default, adopted 2026-10-21: the owner left these choices to
the project. Reversible if the owner objects.*

`SetupRecord` keeps what Family Setup learned: whether it was opened, how
the screen is reached (`AccessMethod`: touch, Voice Control, Switch
Control, Eye Tracking, Head Tracking, someone else helps), when that was
answered, and the check-in state. Nothing is recorded as "setup
completed": a family can stop at any step. `plannedAccessMethods` is nil
when nobody answered or every choice was cleared, and the layout then
uses its largest sizes. `SetupStore` keeps the record as JSON in
UserDefaults; a change is saved before it is shown, a failed save changes
nothing and shows a passive line, and an unreadable record is moved to
`setupRecord.unreadable`, never deleted. Each answer is saved the moment
it is chosen, so leaving a step by Back or Back to Talking keeps it; Next
saves the answer once more, even unchanged, because going through the
step again is what a check-in asks for.

Set Up Step by Step has five steps, each a pushed screen with Next in a
fixed bar at the bottom: how the screen is reached, the voice, turning
on what was chosen, keeping Brickson open, and a summary. A held look on
Next can walk the steps; that only navigates, and Back undoes it. Guides
name Apple's own menus, checked against Apple's support pages on
2026-10-21. Guided Access's guide says that emergency calls and Crash
Detection do not work during a session.

## Check-ins come every three months

*2026-10-21. Default, adopted 2026-10-21: the owner left these choices to
the project. Reversible if the owner objects.*

Three calendar months after setup was last answered (or after the first
launch), Family Setup shows a passive card asking whether anything has
changed, with Go Through Setup Again, Not Now (30 days) and Stop Asking
(until the access question is answered again). It never appears on Home
and is never a pop-up (`CheckInPolicy`). Once it is answered on screen,
passive words take its place at the card's own size until Family Setup
closes (`CheckInPolicy.afterword`), so the rows below never move up under
the button just chosen (invariant 10). These times use `Date` and
`Calendar`, an exception to "Time is `ContinuousClock`": they must survive
relaunches and restarts, which `ContinuousClock` does not, and a clock
set backwards only delays a card.

## The privacy policy ships inside the app

*2026-10-21. Default, adopted 2026-10-21: the owner left these choices to
the project. Reversible if the owner objects.*

Guideline 5.1.1(i) requires a link to the policy inside the app "in an
easily accessible manner"; it does not say how the link opens (checked
2026-10-21). Brickson goes further: project.yml copies `site/privacy`
into the app, and Family Setup's Privacy Policy screen shows that page's
own words natively (`PrivacyPolicyDocument` reads its `<main>`), so the
copy in the app can never differ from the web page, reads at the
person's text size, and needs no network. Open the Web Version shows the
live page in an in-app `SFSafariViewController` sheet, which 5.1.1(vii)
says must be visibly presented. A test fails if any text of the page
does not reach the screen, for example if the page gains an element the
parser does not read.

## Automatic keeps the person's Personal Voice

*2026-10-21. Default, adopted 2026-10-21: the owner left these choices to
the project. Reversible if the owner objects. Personal Voice foundation,
from the research of 2026-10-15 (onboarding-and-settings.md, 3.2a).*

A device can hold several Personal Voices, and Apple does not document
the order the system lists them in. Automatic used to take the first one
listed, so a second voice (made by someone else, or restored from
another device) could change a person's voice between two launches,
without anyone choosing it. A voice is part of who someone is.

So once Automatic speaks in a Personal Voice, `SpeechService` keeps that
voice's identifier under the settings key `automaticPersonalVoiceID`, and
Automatic uses it for as long as the system lists it
(`VoiceSelection.select`, `automaticPersonalVoiceID`). Only a Personal
Voice is kept: a system voice never outranks the person's own. The kept
voice is written only when the voice list is read, never cleared while
access is off (so the same voice comes back with access), and replaced
only when it is gone and another Personal Voice is listed. A voice the
person chose still comes first. The Voice screen shows what Automatic
uses (`SpeechService.automaticVoice`); a passive line when it changes is
the Voice screen's to add. Whether identifiers stay the same across a
relaunch, a restore and Share Across Devices is device check D5.

## A Personal Voice is used only while it is allowed

*2026-10-21. Default, adopted 2026-10-21: the owner left these choices to
the project. Reversible if the owner objects. Personal Voice foundation,
from the research of 2026-10-15 (onboarding-and-settings.md, 3.2b).*

Apple makes personal voices available only while the app is allowed to
use them (`AVSpeechSynthesisVoice.Traits.isPersonalVoice`), and one
report on Apple's developer forums, from a Mac, says asking for one
without permission gives no speech at all. A list read before access was
turned off can still show the voice. So no Personal Voice is a candidate
for a phrase, a voice sample or Automatic unless the status read last is
"allowed" (`VoiceSelection.usableVoices`), and the voice list Settings
shows (`SpeechService.availableVoices`) leaves it out; the phrase speaks
in the next voice instead, and the person's choice is kept, so it comes
back with access. What the system really does with a turned-off voice
(silence, a finish, or another voice) is device check D4.

Voice Settings says so in those words: while access is off, a chosen
Personal Voice is never called gone from the device. The note above the
list then says the chosen voice can't be used now and comes back when
Personal Voice is turned on, and a Personal Voice that leaves the list
while the screen is open says it can't be used while Personal Voice is
turned off (`VoiceList.missingVoiceNote`, `VoiceList.goneVoiceNote`;
2026-10-22).

## Voice Settings keeps its places while it is open

*2026-10-22. Default: the owner left these choices to the project.
Reversible if the owner objects. From Codex's fourth review of PR #23.*

The voices can change while Voice Settings is open: a voice downloaded
or deleted, or Personal Voice turned on or off in the Settings app while
Brickson waits, which the speech engine reads again on return to the
front. Rebuilding the list live would move every Hear and Use pair below
the change under a resting pointer (AGENTS.md, invariant 10). So, for
one visit to the screen:

- Each voice row keeps the place it had when the screen opened
  (`VoiceList.keepingPlaces`). A voice that arrives goes after every row
  already shown and keeps that place for the rest of the visit, so
  voices arriving one at a time stay in the order they first appeared
  (`VoiceList.addingArrivals`). A voice that goes keeps its row: its
  name stays, the line under it says it is no longer on the device (or,
  for a Personal Voice whose access was turned off, that it can't be
  used while Personal Voice is off), and its buttons are hidden, so
  nothing is left to activate there. Every row lays out each version of
  that line (`VoiceList.secondLines`), so a voice leaving changes no
  row's height. Each row still shows whether it is chosen now. The next
  time the screen opens, the normal order (`VoiceList.rows`) decides
  again.
- The Personal Voice card keeps its tallest height
  (`settingsKeepsItsTallestHeight()`), so words that get shorter pull
  nothing up.
- "Speaking with …" keeps room for every voice on the device when the
  screen opened, and names only those. A voice that appears while it is
  open, such as a Personal Voice just allowed (iOS hides its name until
  then), is "a newly available voice" until the next visit
  (`VoiceList.speakingName`), so the line never grows.
- The missing-voice note above the list appears only when the chosen
  voice was already missing as the screen opened; a voice that goes later
  says so in its own row.

What this does not cover: words that get longer while the screen is open
still push what is below them down (the card going from ready to turned
off, at sizes where that wraps). Where every version is known, reserve
them all (`SettingsReservedParagraph`), as the Ask button does.

## Asking for Personal Voice from Voice Settings

*2026-10-22. Default: the owner left these choices to the project.
Reversible if the owner objects. From the research of 2026-10-15
(onboarding-and-settings.md, 2 and 3).*

Under `PersonalVoiceAskPolicy.fromSettings`, Voice Settings' Personal
Voice card offers **Ask to Use Personal Voice**, a standard button,
explained in the words above it: what Personal Voice is, to choose Allow
when iOS asks, and that iOS asks only once. The rules:

- **One question.** A second press while iOS still asks (a double tap, or
  a held look before the question covers the screen) asks nothing more
  (`SpeechService.isAskingForPersonalVoice`), and Settings holds its idle
  reset until the answer lands (`SettingsIdleHold.personalVoiceRequest`).
- **The answer moves nothing.** While the button shows, the card's words
  keep room for the words of every answer iOS can give
  (`PersonalVoiceGuidance.outcomesOfAsking()`). Once used, the button's
  place holds passive words ("Answered. …") until the screen closes, laid
  out at the same size, so no control takes its frame.
- **No new button on the visit that asked.** Whatever the answer, the
  card adds no control until the screen opens again
  (`PersonalVoiceGuidance.make`, `askedOnThisVisit`). A refusal shows the
  written path, and Open Personal Voice Settings is back on the next
  visit. A button that leaves Brickson must not appear beside the spot
  just activated; with iOS's question in between, where a dwell user's
  look rests after answering is the question's own button, which only
  chain scoring can follow (docs/HANDOFF.md, *Known gaps*, "Chains of
  activations through Settings' screens").

The app's policy is still `.atLaunch`, so the button does not show to
people yet ("Personal Voice permission is asked at launch, for now").
Debug launches can ask for it: `--personal-voice=ask-from-settings` with
the device's own permission, for device check D1, and
`--personal-voice=stand-in-refuses` with a stand-in that refuses, so the
UI tests reach the button (`LaunchOptions`, `StandInPersonalVoice`). A
release build reads no launch arguments.

## Personal Voice is never written to a file

*2026-10-21. Default, adopted 2026-10-21: the owner left these choices to
the project. Reversible if the owner objects.*

Brickson speaks a Personal Voice live and never renders it into an audio
file or buffer to keep (`AVSpeechSynthesizer.write`). A file of someone's
own voice could leave the device in a backup or a share sheet and be
reused to sound like them; spoken live, it exists only
while they choose to speak. Recorded phrases, when they come, are the
person's own recordings, not synthesized ones. A feature that seems to
need a rendered file (sending a phrase as audio, Calls) is decided again
here first.

## Accessibility API coverage

*2026-10-21. Default, adopted 2026-10-21: the owner left these choices to
the project. Reversible if the owner objects.*

[`docs/ACCESSIBILITY.md`](ACCESSIBILITY.md) lists every Apple
accessibility feature and API in the project's map of Apple features by
ALS stage, with its iOS version, its release and how it is checked. The
choices it makes:

- **The list stays current.** A pull request that adopts, changes or
  drops an API edits its row. The pull request that moves Brickson to a
  new major Xcode also reads Apple's update pages and adds what is new.
- **Full screen in Assistive Access, and no separate scene.** Brickson
  declares `UISupportsFullScreenInAssistiveAccess` (ROADMAP R0, item 7),
  so it keeps its own layout there. It never adopts the `AssistiveAccess`
  scene or `UISupportsAssistiveAccess` for its main interface: the system
  would choose control sizes and placement, so controls would sit
  somewhere else in Assistive Access than everywhere else (invariant 8).
- **Brickson never takes over the device.** It never calls
  `requestGuidedAccessSession` (only for supervised devices, and it could
  trap a person) or `configureForGuidedAccess` (it could turn off the
  person's only way to use the device). Families start Guided Access
  themselves, with setup text.
- **Assistive-technology flags only suggest.** The VoiceOver, Switch
  Control, AssistiveTouch, Guided Access and Assistive Access flags may
  choose setup text or suggest a profile; none changes Home (*Who chooses
  the input profile*, above; invariant 8). Apple offers no flag for Voice
  Control, Eye Tracking, Head Tracking, Dwell or Full Keyboard Access, and
  Brickson never guesses one.
- **Phrases keep the person's voice with VoiceOver on.**
  `prefersAssistiveTechnologySettings` stays false: a phrase is for the
  listener.
- **Late-stage boards are a profile, not new screens.** The map's Yes/No
  mode and rest board become one R1 profile of the layout engine: Yes,
  No, Get Attention and Emergency keep their relative places and grow,
  and the phrase area shows fewer, larger tiles from a category the
  family chooses. Emergency stays visible (invariant 2).
- **Waiting, each with a work file first:** a watch app, a start-only
  Get Attention control (never a toggle), an on-device partner view,
  custom VoiceOver rotors, pronunciation with SSML or IPA, keyboard
  shortcuts, and Guided Access restrictions of Brickson's own.
- **HomeKit tiles wait on the owner.** They would control lights, doors
  and other devices beyond the iPhone or iPad, so whether they fall under
  invariant 9's hard stop on network code is the owner's decision, as for
  caregiver alerts. Nothing is planned or built until the owner records an
  exception here; then they start with a work file and add a permission,
  an entitlement and a privacy-policy section.
- **Not used in 1.0:** AlarmKit and critical alerts (Get Attention plays
  inside Brickson and needs no permission; revisit if it must sound with
  Brickson closed); `mixToTelephonyUplink` (calls go through microphone
  injection, R0 item 8); Liquid Glass styles on Home's speaking and safety
  controls, whose contrast would depend on what is behind them.
- **Never:** a person's phrases as an `AppEntity`, in Spotlight or in the
  keyboard's conversation context; Foundation Models; custom eye, head,
  pointer or switch input (invariant 9).

## Solid fills on Home, system glass elsewhere

*2026-10-21. Default, adopted 2026-10-21: the owner left these choices to
the project. Reversible if the owner objects.*

Home's controls use solid, measured fills, not Liquid Glass. Apple's
guidelines (materials page, read 2026-10-21) keep Liquid Glass for
navigation and controls floating over content and ask for it sparingly in
custom controls; Home's buttons are the content, and glass takes its
colour from what lies beneath, so a contrast ratio measured once could
not be promised (invariant 6). Standard system components on the family
screens (navigation bars, toolbars, sheets, the file picker, the in-app
Safari sheet) keep the glass the system gives them, unstyled, only once
they measure: invariant 6 covers system components too, so each one is
captured in light, dark, Increase Contrast and Reduce Transparency over
the content it floats over, and its words and edges are measured from
the captures. One that fails gets an opaque backing or Brickson's own
measured control instead of glass. None is measured yet.

One measured colour per role, the same value in light and dark: phrase
`#0A60D6` (`AccentColor`), control `#5A6474` (`ControlFill`) and
emergency `#C8161E` (`EmergencyFill`), as `Palette` has them, and two for
the alarm: Get Attention `#B45309` and Stop `#0F766E`. The alarm's two
are hues of their own, so neither reads as a phrase or as Emergency, and
the amber avoids system orange's 2.2:1. White labels on every fill are
5.0:1 or better, and every fill's edge is 3.5:1 or better on white and on
black. The typing field's edge is `#767676` in both appearances, because
the field's own fill barely differs from the screen: 4.07:1 against the
field and 4.54:1 against the screen in light, 3.75:1 and 4.62:1 in dark.
A pair enters the code only with its pin in `PaletteTests`.
Which control takes which role, and where each sits, is "Home's slot
plan". docs/DESIGN.md, *Colour* and *Apple's guidelines and Liquid
Glass*, has the measurements and the review.

Before: `Palette` had the three fills and no rule about glass.

## Show Borders and the Large Content Viewer on Home

*2026-10-23. Default, adopted 2026-10-23: the owner left these choices to
the project. Reversible if the owner objects.* The second part of ROADMAP
R0 item 3's accessibility work (docs/ACCESSIBILITY.md, section 6;
[`log/2026-10-23-show-borders-and-large-content.md`](log/2026-10-23-show-borders-and-large-content.md)).

- **Show Borders draws a border inside every Home control.** With the
  setting on (`accessibilityShowBorders`; Apple deprecates
  `accessibilityShowButtonShapes` and UIKit's `buttonShapesEnabled`),
  Home's button style draws a 2pt primary-ink border inside each
  control's edge, so the edge stands out from the screen at 4.5:1 or
  better (21:1 on Home's screen) instead of a fill's 3.5:1 on black. It
  is drawn inside the frame, so nothing moves or changes size. A control
  that is off has always had this border.
- **The pressed and selection rings change with it,** so that pressed,
  selected and neither still look different in light and dark mode: the
  pressed ring doubles to 4pt, and the selection ring takes the screen's
  colour (still white in light mode, black in dark). In dark mode primary
  ink is white, like the usual selection ring, so without the change a
  selected control would look the same pressed as not. The rings drawn
  from the edge stay within the label inset (4pt), which a label's words
  never cross; the selection ring keeps its place, 2 to 5pt in. With the
  setting off nothing changes.
- **Measured, not eyeballed** (invariant 6). The rings are drawn in plain
  black and white. `HomeButtonLook`, a plain type, says which rings each
  state and setting draws (`HomeButtonLookTests`); `PaletteTests`
  measures every ring colour against every fill in light, dark and
  Increase Contrast, and checks that primary ink and the screen's colour
  are the system's label and background colours. Settings and setup use
  the system's bordered style, which follows the setting itself (a device
  check).
- **No Large Content Viewer on Home's speaking controls yet.** The
  coverage list planned it for every label the fitting type shrinks, and
  this pull request first built it (`accessibilityShowsLargeContentViewer` on each Home button).
  Review found a risk in it. For UIKit's own controls, Apple documents
  that with the viewer on, a touch held on one control that slides onto
  another activates the second when the finger lifts
  (`largeContentViewerInteraction(_:didEndOn:at:)`); that is how a tab
  bar works. Whether SwiftUI buttons do the same has not been seen yet.
  If they do, on Home a touch begun on Yes that drifts 8pt onto No says
  "No.", and a drift from one phrase tile to the next speaks the next
  phrase: words the person did not choose, by a hand that may be weak or
  unsteady. Without the viewer, a touch stays with the view it began in
  (Apple, "Using responders and the responder chain to handle events":
  the touch's view never changes, even when it moves outside), so a
  touch begun on Yes is expected to say Yes or nothing; the same device
  check confirms it.
  `SpokenUtteranceTracker` absorbs only a repeat of the same phrase, so it
  does not help. The viewer stays off them until a device check with a
  test build shows what a slide does in SwiftUI (docs/HANDOFF.md, *Checks
  that need a real device*). If a slide activates the control under the
  finger, Home gets the viewer only where a slide cannot reach a control
  that speaks, or not at all, and the owner hears the trade-off first.
  Settings' gear has the viewer where it shows alone (PR #33, "Settings
  on Home"). Settings never speaks, but a slide from the gear could end
  on a control that does, so the same check slides from the gear onto
  each control beside it, and the same rule decides whether it keeps the
  viewer.
  Meanwhile labels never shrink below the default size, and the system's
  Zoom enlarges any of them.

*Before:* Home's button style did not read Show Borders, and on Home only
Settings' gear had the Large Content Viewer (PR #33); the coverage list
had the rest as R0-3 work.

## Tests

*2026-10-10. Default.*

Unit tests use Swift Testing and run inside the app on a simulator
(`BricksonTests`, scheme `Brickson`). UI tests use XCTest and launch the
real app (`BricksonUITests`, scheme `Brickson-UI`), because only XCTest
can drive an app. A test that drives no app uses Swift Testing in the
unit tests, even when what it checks lives with the UI tests, which is
then compiled into both (*Apple's current frameworks first*). GitHub
runs both on every pull request (`.github/workflows/tests.yml`); a pull
request merges only when they pass.

## Reviews, updates and GitHub settings

*2026-10-10. Default; the owner applies the settings in GitHub, so check
them there before relying on them.*

The repository's settings live on GitHub, not in these files. This is
what they are meant to be, and why, so a change to the workflows or the
review setup does not quietly break them.

### Code review

- Codex reviews every push to a pull request. GitHub Copilot (the owner's
  Copilot Pro plan) reviews each pull request **once, when it opens**,
  through the `main` ruleset's "Automatically request Copilot code review"
  rule, at Balanced effort. It does not review every push: each Copilot
  review is paid from a monthly allowance of AI credits (GitHub estimates
  $0.25 to $5 a review at Balanced; Pro includes $15 a month), and Codex
  already reviews every push. When a pull request changes a lot after
  review, the owner can choose **Re-request review**.
- *Added 2026-10-12.* Dependabot's pull requests get no automatic review
  from Copilot or Codex: PR #7, Dependabot's first, got neither, while
  PR #8, opened by an agent, got both. The owner requests a Copilot review
  of one by hand when wanted. Only the owner requests Copilot reviews;
  agents never add Copilot as a reviewer unless the owner asks, because
  each review spends the owner's credits.
- Review guidance lives in AGENTS.md, *Code Review Rules*, which Codex,
  Copilot and Claude Code all read. `.github/copilot-instructions.md` only
  adds what is specific to Copilot and points back to AGENTS.md, so the
  rules exist in one place.
- *Added 2026-10-12.* `.github/skills/code-review/SKILL.md` gives Copilot
  the steps of a review: learn what is built, find the rules the change
  touches, trace a path from a real input, and write the finding. It holds
  the method only. What counts as a finding is decided in AGENTS.md, which
  the skill cites by invariant number and section title, and the skill
  says nothing about which features are built, how many there are or how
  they are set, so it stays true as the app grows. A new review rule goes
  in AGENTS.md, not the skill, and renaming a section the skill cites
  means updating the skill. GitHub's documentation says Copilot code
  review uses a skill in `.github/skills` when it is relevant to the
  review, and that a review-focused folder name such as `code-review`
  makes that likely; `.github/copilot-instructions.md` also points to it.
  The owner asked for this skill, so it is an accepted reviewer
  instruction file outside AGENTS.md. *Tests, workflows and the rules
  themselves* still flags every change to it and every new file of its
  kind for the owner to decide.
- Copilot's review runs on a Linux machine and cannot build an iOS app, so
  there is no `copilot-code-review.yml`; the Tests workflow is the build.
- Copilot never approves a pull request (its "Auto-approval" settings stay
  off). An AI approval does not stand in for the owner's merge.
- No `CODEOWNERS` file: the owner is the only maintainer and appears as
  the author of every pull request agents open, and GitHub never asks an
  author to review their own pull request.

### Dependencies

Brickson has no packages (invariant 9), so the actions
in `.github/workflows` are its only dependencies. Dependabot proposes new
versions once a month in one grouped pull request, waiting seven days
after each release (`.github/dependabot.yml`); security fixes come at
once through Dependabot security updates. Those need three switches in
Settings → Advanced Security that the file cannot turn on: the dependency
graph, Dependabot alerts and Dependabot security updates. Security
updates were on when checked on 2026-10-10, and GitHub allows that only
with the other two on; keep all three on. Actions are referenced by
version tag, not pinned to commit hashes: GitHub only raises security
alerts for tag references, and all of them are GitHub's own actions.

### Code scanning

*Revised 2026-10-12; languages corrected 2026-10-21.* CodeQL's default
setup scans the workflow files in `.github/workflows` and, since
2026-10-13, the Python scripts in `scripts/` (GitHub added Python by
itself once `scripts/test-site.py` landed; checks "Analyze (actions)" and
"Analyze (python)"). CodeQL does not scan the Swift code, on purpose:

- Default setup can only build Swift that has a committed Xcode project
  or Swift package. Brickson's project is generated by XcodeGen and not
  committed (*Build and test* in AGENTS.md), so default setup's one Swift
  attempt, on 2026-10-10, failed ("`autobuild` detected neither an Xcode
  project or workspace, nor a Swift package"), and GitHub then removed
  Swift from default setup by itself. Ticking Swift there again fails
  the same way.
- Scanning Swift would take advanced setup: a workflow of our own, on a
  Mac runner, that generates the project and builds the app while CodeQL
  watches the compiler. It replaces default setup for every language. Not
  chosen, because:
  - CodeQL's Swift checks (CodeQL 2.27.2, read 2026-10-12) look for code
    Brickson does not have: network requests, web views, regular
    expressions, SQL, `NSPredicate` or `String(format:)` built from
    outside text, running other programs, XML, hashing or encryption,
    links opened from other apps, mixing `String` and `NSString` lengths
    (such as an `NSRange` built from `String.count`), and values whose
    names suggest secrets or private information (a password or token,
    but also a phone number, an emergency contact or a medical detail)
    written to logs, settings or the network. None of them applies to
    today's code.
  - It would add a third Mac job to every pull request, estimated at 10 to
    20 minutes (never run). GitHub runs at most five Mac jobs at a time
    for an account, and the ruleset's code scanning rule would make each
    merge wait for it.
  - CodeQL learns to read each new Swift version weeks or months after
    Xcode ships it: 31 to 115 days for Swift 6.0 to 6.3, and 10 to 45 days for their
    point releases (Swift 6.3.3, in Xcode 26.6, took 24). Today it covers
    Swift up to 6.3, which Xcode 26.6 uses, and not Swift 6.4 (Xcode
    27). Every Xcode upgrade could break the job or hold up merges.
  - Since CI moved to Xcode 27 (*Build with Apple's current Xcode*,
    above), advanced setup could not scan Swift at all: GitHub's changelog
    of 2026-10-19 says that with Xcode 27 installed CodeQL cannot trace a
    Swift build, and that it does not support Swift 6.4 on any platform.
    Its advice to pin macOS 26 and Xcode 26 is not taken, because the
    owner's toolchain decision comes first.
- The earlier text here said CodeQL "cannot follow Xcode 27 builds yet"
  and that GitHub "has announced a Swift scanner that needs no build". The
  first is true, but it does not stop scanning today, because default
  setup scans only the workflow files and the Python scripts, which need
  no build (when this was written, CI also still built with Xcode 26.6);
  it matters only for advanced setup (above).
  The second does not hold for CodeQL, whose Swift support has only the
  `autobuild` and `manual` build modes; no mode that skips the build has
  been announced. It probably meant AI Scan, below.
- GitHub's **AI Scan for pull requests** (a public preview) is on for
  this repository, checked through GitHub's API. It reads each pull
  request's changes without building anything, when the pull request
  opens and after every new commit, and its job logs show it reading
  Swift files. It skips pull requests from forks and from Dependabot.
  Its findings are advice: GitHub's documentation says they do not block
  a merge and no ruleset can require them. By this project's practice,
  each one still gets an answer and is resolved like a review comment.
  GitHub's documentation also says its use spends AI credits, most
  likely from the owner's Copilot allowance (not confirmed).
- Dependabot's first pull request, PR #7, merged with no CodeQL analysis
  of its own: its CodeQL check said "1 configuration not found" and
  analysed nothing, and nothing blocked the merge. Its workflow change was
  scanned after the merge, on `main`. GitHub's documentation does not say
  why; check the next Dependabot pull request.
- Keep default setup on. The ruleset requires CodeQL results, and GitHub
  blocks every merge when a required tool is not set up.
- The failed Swift attempt left an error on the Tool status page (the
  repository's **Security and quality** tab, under the … menu if it is
  hidden, then **Code scanning**, then **Tool status**). It changes
  nothing else: pull request checks leave it out, and the code scanning
  rule passed on the merges after it. It stays until someone deletes it
  there (the Swift configuration, then … → **Delete configuration**).

Revisit when CodeQL can analyse Swift without a build (`none` under
`build_modes` in `swift/codeql-extractor.yml` in `github/codeql`), or
default setup can build a generated project; when Brickson adds code that
CodeQL's Swift checks look at (network code such as caregiver alerts,
opening files or links from other apps, web views, SQL, encryption, or
storing, logging or sending values whose names suggest secrets or private
information, such as an emergency contact's phone number); when AI Scan
stops reading Swift, leaves the preview with new terms, or costs more
than the owner wants; or when a Swift error appears on the Tool status
page again.

### `main` ruleset

Recommended to the owner, and matching GitHub's settings when checked
through its API on 2026-10-15:

| Rule | Setting | Why |
|---|---|---|
| Require a pull request before merging | 0 approvals; merge commits only | Nobody pushes to `main`. The owner cannot approve pull requests that show them as author, so any approval count would block every merge. Merge commits keep the commit hashes HANDOFF cites on `main`. |
| Require status checks to pass | "Unit tests" and "UI tests" | The job names in `tests.yml`. Renaming a job blocks every pull request until the ruleset is changed to match. |
| Require branches to be up to date | Off | Each update reruns the Mac tests; `main` is tested again after every merge anyway. |
| Require conversation resolution | On | Every Codex and Copilot comment, and every CodeQL alert posted on the pull request, gets an answer before a merge. AI Scan findings are answered too, by practice (*Code scanning* above). |
| Require code scanning results | CodeQL: errors, high or higher | A workflow change that CodeQL flags as an error, or as a high or critical security problem, cannot merge. It did not cover Dependabot's first pull request, which got no CodeQL analysis before merging (*Code scanning* above). |
| Automatically request Copilot code review | On; new pushes and drafts off | As above. |
| Block force pushes, restrict deletions | On | History on `main` never changes. |
| Bypass | Repository admin, for pull requests only | The owner can still merge in an emergency, such as GitHub's Mac machines being down, but never push straight to `main`. |
