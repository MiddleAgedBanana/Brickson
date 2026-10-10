# Decisions

Binding choices for Brickson, with the reason for each. Code comments point
here by section title, so keep titles stable. A settled decision is not
reopened without new evidence; to change one, edit its entry, say what
changed and why, and keep the old reasoning in a "Before" line.

"Owner" means the repository owner decided; "default" means an agent chose
a reasonable default that the owner can overrule.

## App identity

*2026-10-10. Name: owner. Other values: default.*

Everything that identifies the app sits in one block at the top of
`project.yml`, so changing it means changing one line:

| Setting | Value | Notes |
|---|---|---|
| `APP_DISPLAY_NAME` | `Brickson` | The name under the icon. The working name, chosen by the owner. |
| `APP_SPOKEN_NAME` | `Brickson` | How VoiceOver and other text-to-speech say the app's name (`CFBundleSpokenName`). If they say it wrong, use a sound-alike spelling here; the name under the icon stays as it is. |
| `APP_BUNDLE_ID` | `family.avery.brickson` | The identifier the owner was advised to register for the App Store. It **cannot change after the first App Store upload**, and it is public, so any change happens before that upload. Someone building for their own device changes it locally (it belongs to one team) and does not commit that. |
| `DEVELOPMENT_TEAM` | empty | Needed only to run on a real device or upload. Left empty until the developer account is chosen (personal or organization). A team ID is not secret; it is in every signed app. |
| `MARKETING_VERSION` | `0.1.0` | The version people see. |
| `CURRENT_PROJECT_VERSION` | `1` | Must go up with every upload to App Store Connect. |

Siri also accepts the alternative name "Brick Son" (`INAlternativeAppNames`
under the app's `info` in `project.yml`; at most three, never another app's
name), because "Brickson" is in no pronunciation dictionary. Whether Siri,
Voice Control and VoiceOver handle the name well is a device check.

The Xcode project, targets and folders are also called Brickson. Renaming
those is a larger change (folders, target names, `@testable import`), and is
not needed to change the name people see.

## Generated Xcode project

*2026-10-10. Default, from the reference app.*

`Brickson.xcodeproj` is generated from `project.yml` by XcodeGen and is not
committed (it is in `.gitignore`). Every machine, and CI, generates it.
This keeps project settings reviewable as plain text and avoids merge
conflicts in the project file. Agents never open the project in Xcode
(docs/LESSONS.md, "Never open the project in Xcode from an agent").

## Minimum iOS 26, iPhone and iPad

*2026-10-10. Default, from the reference app.*

iOS and iPadOS 26.0 or later, on iPhone and iPad. Mac ("Designed for
iPad"), Mac Catalyst and Vision Pro are switched off until someone decides
to support them. iOS 26 brings the current SwiftUI, SwiftData and
accessibility APIs, and Eye Tracking needs a recent iPad anyway.

## No outside packages

*2026-10-10. Default, from the reference app and invariant 9.*

Only Apple's frameworks. No Swift packages, no SDKs. Every dependency is
code that can break, track or change under the person relying on it.

## No servers, accounts, ads or analytics

*Invariant 9.* Everything stays on the device. The privacy manifest
(`Brickson/Resources/PrivacyInfo.xcprivacy`) declares no tracking and no
collected data; `AppBundleTests` pins it.

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

## No iCloud sync in 1.0

*2026-10-10. Default; recommended to the owner.*

The library stays on the device (`cloudKitDatabase: .none`). Sync brings
conflicts, account states and failure modes that a person who cannot speak
must never meet mid-sentence. The models already follow SwiftData's iCloud
rules (defaults on every property, optional relationships, nothing unique),
so sync could be added later without a migration. Backup by file comes
first (docs/PORTING.md, step 2).

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

**Open, decide with the Get Attention port (step 1):** when to release the
audio session. Today `SpeechService` activates it before speaking and never
deactivates it, as the reference app did, so music or a podcast that speech
interrupted does not resume on its own. Releasing it after speech ends
(with `.notifyOthersOnDeactivation`) is kinder to other apps, but it must
never happen while the alarm sounds, must not delay the next phrase
(invariant 2), and needs a device check. The alarm shares the session, so
both are designed together.

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
with Yes and No alone and a warning.

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
- **Messages never shrink.** The message row always reserves two lines of
  its font; a longer message scrolls inside them at full size (the reference
  app's phone layout did the same), and a new message starts at the top.
- **Audio warnings keep their space.** The warning area always holds the
  height of the tallest short audio warning ("Volume low", "Audio failed"),
  so a warning appearing hides no phrase tile (invariant 4). The short text
  is what people see; VoiceOver reads the full sentence. The two library
  warnings are decided at launch and never appear later.
- **Accepted for the stand-in only:**
  - No Get Attention yet, so invariant 10's "reachable in one dwell" holds
    only for Emergency, Yes and No. Get Attention comes in port step 1.
  - Again sits beside the message text the person reads, and the phrase
    grid ends just above the warning text: under a gaze profile a look
    that rests on the text could snap to them.
  - The selected category swaps its symbol for a check mark; symbols
    differ in width, so the buttons after it can shift slightly.
  - CI tests the iPad only. On a narrow iPhone the three quick-control
    labels may not fit at larger text sizes.

## Personal Voice permission is asked at launch, for now

*2026-10-10. Default, from the reference app.*

`SpeechService` asks for Personal Voice permission when the app starts.
The reference app did the same, with a comment saying that asking after
the first sentence can hide personal voices for the rest of the session;
Apple's documentation does not say so, so treat that as unverified. As a
result the system question appears on first launch with no explanation.
Onboarding should explain Personal Voice first and then ask; that comes
with Settings and setup (docs/PORTING.md, step 7).

No Info.plist key is needed for the request. If **Allow Apps to Request to
Use** is off (Settings → Accessibility → Personal Voice), the system denies
the request without asking. `AccessibilitySettings.openSettings(for:
.personalVoiceAllowAppsToRequestToUse)` opens that switch directly; the
voice picker should offer it when permission is denied.

## Tests

*2026-10-10. Default.*

Unit tests use Swift Testing and run inside the app on a simulator
(`BricksonTests`, scheme `Brickson`). UI tests use XCTest and launch the
real app (`BricksonUITests`, scheme `Brickson-UI`). GitHub runs both on
every pull request (`.github/workflows/tests.yml`); a pull request merges
only when they pass.
