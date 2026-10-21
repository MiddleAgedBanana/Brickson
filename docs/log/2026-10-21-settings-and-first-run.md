# Settings, Family Setup and the first run

*2026-10-21. PR #23, branch `claude/project-thread-j7207m`. The
"Settings and first run" thread, which ends with this pull request.*

## What changed and why

Brickson now has Settings, for the family, and a first run that never
stands between someone and their voice. The decisions are in
docs/DECISIONS.md: "First launch opens Home; setup lives in Settings",
"Settings is a cover with a fixed safety bar", "Speed is a set of fixed
choices", "Settings resets when idle and never closes", "Setup answers
are kept as offered, never as completed", "Check-ins come every three
months" and "The privacy policy ships inside the app".

- **Settings** (`Brickson/Settings/SettingsView.swift`): a full-screen
  cover. A fixed safety bar keeps Get Attention's place (empty, see
  *Follow-ups*) at the top leading edge and Back to Talking at the top
  trailing edge, at the same frames on every screen, and under it a line
  kept for sound problems, since the cover hides Home's. The root holds
  one Family Setup row and a sentence. After 90 seconds with nothing used it
  goes back to the root and stays open (`SettingsIdleClock`,
  `SettingsActivity`); UI tests get 3 seconds through `AppTimeouts`. The
  reset is held while the policy's web sheet is open, while Get Attention
  sounds, and while a screen calls `holdsSettingsIdleReset(true)`.
- **Family Setup** (`FamilySetupView.swift`): Set Up Step by Step, Voice
  Settings, Reaching the Screen, Keep Brickson Open, Privacy Policy and
  About, plus the three-monthly check-in card (`CheckInPolicy`). It opens
  on passive text as tall as the root's row. Opening it once ends Home's
  first-run hint.
- **Voice Settings** (`VoiceSettingsView.swift`): which voice is speaking
  now; Personal Voice guidance for every permission state
  (`PersonalVoiceGuidance`), with Open Personal Voice Settings where iOS
  can open it and the written path always shown; seven fixed speeds,
  60% to 120% of normal (`SpeedChoice`); the voice list (`VoiceList`: Automatic, Personal Voices,
  then this language's voices, best first, never a novelty voice), each
  with separate Hear and Use buttons whose names are unique.
- **Privacy Policy** (`PrivacyPolicyView.swift`): project.yml copies
  `site/privacy` into the app; the screen shows that page's own words
  (`PrivacyPolicyDocument`), and Open the Web Version shows the live page
  in an in-app Safari sheet.
- **Guides** (`SetupGuides.swift`): turning on each input method, Guided
  Access and Assistive Access, checked against Apple's support pages on
  2026-10-21 (Guided Access disables emergency calls and Crash Detection;
  the guide says so).
- **First run** (`Brickson/FirstRun/`): `SetupRecord`, `SetupStore` (JSON
  in `launch.settings`, so UI tests never touch a person's record),
  `FirstRunHint` and Set Up Step by Step (`GuidedSetupView`, five steps;
  answers only select, Clear My Choices is separate).
- **App and tests:** `AppName.display` reads the name under the icon, so
  no text spells it out. `BricksonApp` creates the setup store, sets
  `showsSetupHint`, and opens Settings at launch for `--screen=settings`
  (a new `LaunchOptions.StartScreen` case). `launchedApp` takes
  `shortTimeouts:` so a slow test can keep the real idle limits. The
  String Catalog has the new strings, written by hand because nothing
  here could build; a few strings were worded so their sort order is the
  same under every collation.

## Commits

- `c511e29` The tested logic behind Settings and the first run.
- `1e63cea` The Settings, Family Setup and step-by-step screens.
- `50154a4` The decisions and this record.
- `002f3f8` Which voice is speaking, on Voice Settings.
- `5228bd4` and `695d765` Codex's first review and the first CI run.
- The commit after them: Codex's second review.
- The merge of `main` (PRs #13, #15, #16 and #18), which moves the setup
  store onto `launch.settings`, takes Settings' idle limit from
  `AppTimeouts`, adds `--screen=settings`, Normal Speed, the alarm hold
  and the UI tests, and fills the String Catalog.

- The review round (Codex and the first CI run on `6dbb62f`), in the
  commits after the merge:
  - Apple's audit on the iPhone 17 found Back to Talking's words clipped
    beside its icon in half the bar's width. A label that dropped the icon
    when the words did not fit (`ViewThatFits`) then failed the audit's
    Dynamic Type check on the iPad ("partially unsupported", CI on
    `695d765`). Buttons that share a row (Back to Talking, Hear and Use,
    Not Now and Stop Asking) now put the icon above the words, as Home's
    quick controls do (`SettingsPairLabel`); full-width rows keep it
    beside them. Words wrap between words and never shrink.
  - Answering the check-in card left the rows below to move up under the
    button just chosen. Its place is now kept, with passive words, until
    Family Setup closes (`CheckInPolicy.afterword`).
  - Slower and Faster could walk the speed once each sample ended. Speeds
    are now fixed choices (`SpeedChoice`, "Speed is a set of fixed
    choices"); this also fixed the English-only "90% of normal" line,
    which is now a localized percent.
  - About and the Personal Voice note said everything stays on the
    device, which the policy's Backups and Personal Voice sections
    contradict. Both now say what Brickson itself keeps and never sends.
  - Sound problems were shown only on Home, which the cover hides. Settings
    now has its own passive line (`AudioSafetyPolicy`, `.dismissThenRepeat`).
  - Button taps did not count as activity, so the idle reset could fire
    during use. Every Settings button now records activity.
  - Step 1's answers lived in a draft until Next, so Back lost them. Each
    answer is now saved when chosen.
  - Not fixed here: Personal Voice's permission state is read once at
    launch, so allowing it in the Settings app shows only after a
    relaunch. That is the speech engine's, and the Personal Voice
    foundation thread has it (*Follow-ups*).
- Codex's second review, on `695d765`:
  - Choosing a speed could change how many lines the speed sentence
    takes at large text sizes, moving every speed choice under a resting
    pointer. The same held for "Speaking with …" when a voice was chosen,
    the missing-voice note disappearing, the voice row's checkmark
    narrowing its name, "Use" becoming "In Use", and "Settings could not
    be opened" appearing. Each now keeps its size in every state
    (`SettingsReservedParagraph`, kept places, a label laid out in both
    versions), and `SettingsTests.testChoosingASpeedMovesNoSpeedChoice`
    checks the speeds at the largest text size.
  - VoiceOver read numbered steps without their numbers. Each step is now
    read number first (`testNumberedStepsAreReadWithTheirNumbers`).
  - Not fixed here: a held look can follow Family Setup's first row into
    Set Up Step by Step and save Touch, the first answer, which is then
    nearest (follow-up 10); and one word wider than half the safety bar
    can still break on narrow phones at accessibility sizes (follow-up 8).

## Verified

- The pure types and their tests (`SettingsIdleClockTests`,
  `SetupRecordTests`, `VoiceListTests`, `PersonalVoiceGuidanceTests`,
  `PrivacyPolicyDocumentTests`, and `SpeedChoiceTests` without its two
  speech-service tests, 45 tests) compiled and passed on a Linux
  Swift 6.3.3 toolchain with default main-actor isolation, with
  `String(localized:)` stubbed and the policy page as a package resource.
  That run found a bug, now fixed: a voice whose identifier was
  "automatic" collided with the Automatic row.
- Tests that can fail: `SetupStoreTests.aFailedSaveChangesNothingAndSaysSo`
  fails if `update` shows a change before saving it;
  `PrivacyPolicyDocumentTests.textOutsideAnyBlockIsDetected` shows the "no
  text lost" check can fail; `SpeedChoiceTests.choosingASpeedSetsItWhateverTheRateWas`
  and `aSpeedChosenAgainAfterItsSampleChangesNothing` fail if a choice
  steps from the current rate, as Slower and Faster did; `SettingsTests.testAnIdleSettingsReturnsToItsFirstScreenAndStaysOpen`
  fails if the reset closes Settings or never happens.
- CI on `6dbb62f`: unit tests passed, so the screens and the String
  Catalog built. UI tests: 24 of 25 passed on the iPad Pro 13-inch and 23
  of 25 on the iPhone 17 (both iOS 27.0 simulators, portrait, default
  text). The iPhone failures were the clipped Back to Talking and the old
  Slower and Faster rows below the screen, both fixed after. The iPad's
  one failure was the first app-launching test,
  `HomeReachabilityTests.testEveryHomeStateAtDefaultTextInLandscape`,
  with "kAXErrorServerNotFound" after a 60-second automation setup. That
  matches the cold-simulator failure in AGENTS.md's Gotchas, on Home code
  this pull request does not change.
- CI on `695d765`: unit tests passed. UI tests: 24 of 26 on the iPad and
  25 of 26 on the iPhone. The iPad's first launch passed this time, so the
  earlier failure was the cold-simulator flake. Every failure was Apple's
  audit on Settings labels built with `ViewThatFits`: Dynamic Type
  "partially unsupported" on both devices and Text clipped on the iPhone,
  on rows that had passed as plain labels. Fixed after, with Home's
  label pattern; the next run is the check.
- Nothing else was built or run where this was written (no Xcode). The
  views, `SetupStoreTests`, `SettingsTests` (UI), the project.yml resource,
  the bundled-page tests and the String Catalog are first checked by CI.

## Not verified

- Any screen on a real device, and how Back to Talking and the root's row
  land over Home's controls under Snap to Item.
- Whether the Guided Access and Assistive Access steps read the same on
  iPadOS (checked against the iPhone guides).
- The interpolated keys in the String Catalog (`%@`, `%lld`) are written
  the way Xcode writes them as far as known; CI's catalog check prints the
  difference if not.

## Follow-ups

For the next Settings thread, in order:

1. **Home's Settings button** *(Phone layout and word fitting, or whoever
   lands Home's slot model)*: place `SettingsButton(isPresented:)` on Home
   with `.settingsCover(isPresented:)` applied before Home's environment
   modifiers, and show `FirstRunHint.text` in the message area while
   `showsSetupHint` is true. Then remove the `--screen=settings` cover in
   `BricksonApp` only if UI tests can reach Settings from Home.
2. **Get Attention in the safety bar**, once Home has Get Attention and
   Stop: put a start-only `attention.start()` button in
   `SettingsSafetyBar`'s empty leading slot, at the same frame. Never put
   Stop in Settings. The `.alarm` hold is already wired.
3. **Ask for Personal Voice from Settings** *(Personal Voice
   foundation)*: when the engine exposes a request, pass `canAsk: true` to
   `PersonalVoiceGuidance.make`, add the Ask button for `.askPermission`
   (its text explains first), and hold the idle reset with
   `.personalVoiceRequest` while iOS asks. Keep the launch-time ask until
   that lands. The engine should also read the permission state again
   when Brickson becomes active, so Voice Settings shows a change made in
   the Settings app without a relaunch (Codex, PR #23).
4. **Library** *(Library editing and backup format)*: add
   `case library` to `SettingsRoute` and a Family Setup row; editors and
   backup tasks call `holdsSettingsIdleReset(_:)`.
5. **Layout sizes**: `SetupRecord.plannedAccessMethods` is ready for the
   layout engine; nil means the largest sizes.
6. Decide whether to set `UISupportsFullScreenInAssistiveAccess`
   *(Accessibility API coverage)*.
7. When Get Attention joins the safety bar, check that the sound line's
   words still fit Settings: "Stopped — Back" names Back, then Again.
8. On narrow phones at accessibility text sizes, one word wider than half
   the safety bar (such as "Talking") can still break inside the word.
   Use the word fitting the Phone layout thread is building, or give Back
   to Talking a row of its own at those sizes, kept the same with Get
   Attention.
9. Keep one UI test on the real 90-second idle limit (docs/LESSONS.md,
   "Machine load causes false failures") once CI time allows.
10. **Score chains through Settings** *(Dwell-safety scoring, ROADMAP)*
   before follow-up 5 lets access answers change sizes. Under Snap to
   Item, the control nearest the spot just activated on a pushed screen
   is often that screen's first control: Family Setup's opening text
   covers the root's row, but Set Up Step by Step is then nearest, and
   on step 1 the first answer, Touch, is nearest that row (Codex, PR
   #23). Opening each screen on a window of passive text, as the
   reference app did, depends on Snap to Item ignoring controls scrolled
   off screen, which nobody has checked (docs/LESSONS.md, "Unverified
   assumptions about Snap to Item"), so score the screens under both
   answers before choosing a fix.
