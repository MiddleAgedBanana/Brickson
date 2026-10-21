# Settings, Family Setup and the first run

*2026-10-21. Pull request #<n> (`claude/project-thread-j7207m`). The
"Settings and first run" thread.*

## What changed and why

Brickson now has Settings, for the family, and a first run that never
stands between someone and their voice. Decisions in docs/DECISIONS.md:
"First launch opens Home; setup lives in Settings", "Settings is a cover
with a fixed safety bar", "Settings resets when idle and never closes",
"Setup answers are kept as offered, never as completed", "Check-ins come
every three months" and "The privacy policy ships inside the app".

- **Settings** (`Brickson/Settings/SettingsView.swift`): a full-screen
  cover with a fixed safety bar (Get Attention's place, kept empty until
  the alarm lands, and Back to Talking), a root with one Family Setup row,
  and an idle reset to the root after 90 seconds that never closes it.
- **Family Setup** (`FamilySetupView.swift`): Set Up Step by Step, Voice
  and Speed, Reaching the Screen, Keep Brickson Open, Privacy Policy and
  About, plus the three-monthly check-in card.
- **Voice and Speed** (`VoiceSettingsView.swift`): Personal Voice guidance
  for every permission state (`PersonalVoiceGuidance`), with Open
  Personal Voice Settings when iOS can open it and the written path
  always shown; the voice list (`VoiceList`: Automatic, Personal Voices,
  then this language's voices, best first, no novelty voices, unique
  button names); Slower and Faster.
- **Privacy Policy** (`PrivacyPolicyView.swift`): the bundled copy of
  `site/privacy/index.html` shown natively (`PrivacyPolicyDocument`), and
  the web version in an in-app Safari sheet. project.yml copies
  `site/privacy` into the app.
- **Guides** (`SetupGuides.swift`): turning on each input method, Guided
  Access and Assistive Access, checked against Apple's support pages on
  2026-10-21.
- **First run** (`Brickson/FirstRun/`): `SetupRecord`, `SetupStore`,
  `CheckInPolicy`, `FirstRunHint` and Set Up Step by Step
  (`GuidedSetupView`). `BricksonApp` creates the store and sets
  `showsSetupHint`.
- `AppName.display` (`Brickson/App/AppName.swift`) reads the name under
  the icon from the bundle, so words people see never spell the name out.

## Commits

<filled in when the pull request opens>

## Verified

- The pure types and their tests (`SettingsIdleClockTests`,
  `SetupRecordTests`, `VoiceListTests`, `PersonalVoiceGuidanceTests`,
  `PrivacyPolicyDocumentTests`, 39 tests) compiled and passed on a Linux
  Swift 6.3.3 toolchain with default main-actor isolation, with
  `String(localized:)` stubbed and the policy page as a package resource.
  That run found one bug, now fixed: a voice whose identifier was
  "automatic" collided with the Automatic row.
- Failing first: `SetupStoreTests.aFailedSaveChangesNothingAndSaysSo`
  fails if `update` assigns before saving;
  `PrivacyPolicyDocumentTests.textOutsideAnyBlockIsDetected` shows the
  "no text lost" check can fail.
- Nothing else was built or run here: this was written where Xcode is not
  available. The SwiftUI views, `SetupStoreTests` (it needs `os`), the
  project.yml resource and the bundled-page tests are untested until CI
  passes.

## Not verified

- Any screen in the running app, on any device, text size or appearance.
- How Back to Talking and Get Attention land over Home's controls
  (that depends on Home's planned layout).
- Whether Guided Access and Assistive Access steps read the same on
  iPadOS 26 and 27 (checked against the iPhone guide).

## Follow-ups

- Phone layout thread: place `SettingsButton` on Home with
  `.settingsCover(isPresented:)`, and show `FirstRunHint.text` while
  `showsSetupHint` is true.
- This thread, after the Speech thread's PRs: Get Attention in the safety
  bar (with the `.alarm` hold), Normal Speed, the Personal Voice Ask
  button and its `.personalVoiceRequest` hold.
- This thread, after the test seams PR: UI tests that open Settings with
  `--screen=settings`, and the 3-second idle limit under
  `--short-timeouts`.
- Library thread: `SettingsRoute.library` and its Family Setup row.
- Accessibility thread: whether to set `UISupportsFullScreenInAssistiveAccess`.
