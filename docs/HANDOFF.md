# Handoff

The current state of Brickson and what to do next. **Start every session
here**, after `git status` and `git log --oneline -15`. Each pull request
edits this page in place and writes its record in [`docs/log/`](log/README.md);
nothing is appended here. Plan: [`docs/ROADMAP.md`](ROADMAP.md). How the
project runs: [`docs/SDLC.md`](SDLC.md).

**State as of 2026-10-22: PR #14 (the library core), reconciled with
`main` at `cc35c30`; not merged.**
Ten threads are working in parallel on the first release, R0.

## What the app does today

What it is written to do (*Verification* says how much has been seen). A
stand-in Home with Yes, No, Again and Emergency in one safety row (Again on
a second row only in windows under 328pt wide, 348pt with Bold Text, such
as Slide Over or an iPhone with Display Zoom), everyday categories with
Settings at their trailing end, and tiles from a neutral starter set,
sized from the space the window gives it (docs/DECISIONS.md, "Home's
stand-in layout"): four category buttons that never scroll sideways, and
three phrase columns on every iPhone at its standard Display Zoom. A tile
speaks at once, in the person's Personal Voice when one exists and is
allowed; the sentence stays on screen in two reserved lines across the
width, and a longer message scrolls inside them. No label breaks a
word: each drops its icon first, then shrinks only as far as it must,
never below the default size, in lines of whole words. A phrase the system cuts off (a call, Siri, lost
headphones) shows "Stopped" with Again to repeat it. Emergency opens the
emergency phrases and says nothing. VoiceOver, Switch Control and Full
Keyboard Access reach Yes, No and Emergency first, then Again, the
message, the categories and Settings, and the phrases, each region as a
group, and Voice Control also takes "Repeat" for Again (docs/DECISIONS.md,
"Home's scan order and names" and "Settings on Home"). The start-only Get Attention alarm is
built and waiting for its place on Home (docs/DECISIONS.md, "Home's slot
plan"). Settings, for the family (a
full-screen cover with Back to Talking, Family Setup, Voice Settings,
guides, the privacy policy and step-by-step setup), opens from Home's
Settings button; until Family Setup has been opened once, Home's message
area says where setup is. Back to Talking closes onto Emergency, never
onto a control that speaks (docs/DECISIONS.md, "Settings on Home"). "Speaking", audio failures and very low volume share
one passive status line under the message, in space always kept for it,
and VoiceOver announces the warnings. If the
library cannot be saved, the app speaks from a filled in-memory library
and says changes will not be kept. If saved phrases exist but cannot be
opened or read, the file is left untouched and a second warning says so
and warns against deleting the app. A saved library damaged so that
Emergency has nothing to open gets the starter emergency phrases back at
launch, added after what is already there, with nothing of the
person's changed ([`log/2026-10-23-emergency-repair.md`](log/2026-10-23-emergency-repair.md)).
Editing and backup exist as tested code with no screens yet
([`log/2026-10-21-library-core.md`](log/2026-10-21-library-core.md)).
The screen never locks. Ported code:
[`docs/PORTING.md`](PORTING.md).

The design reference and its specification are in [DESIGN.md](DESIGN.md)
and [work/design-screens.md](work/design-screens.md). PR #20's
[reconciliation record](log/2026-10-22-design-reconciliation.md) preserves
the landed slot decisions and lists drawings, placement questions and
measurements still pending before implementation follows them. The local
unit gate passed all 460 tests on iPad Pro 13-inch (M5), iOS 27.0, with
Xcode 27.1 (27A9275); final-head CI is pending.

## Verification

- **PR #14 reconciliation, 2026-10-22:** incorporates main `cc35c30`, the
  invisible-text Emergency correction and the bounded category-name fix.
  Standalone invisible decorations no longer create duplicate names;
  composed names and stored/imported bytes remain intact. All 56 pure
  library tests pass. The fresh full native unit gate passed 560 tests,
  zero failures and one existing issue #19 crash-probe skip (561 total);
  the String Catalog is unchanged. Full local UI on `7ec516f` completed
  with 34 passed, one speech-wait failure and four existing probe skips
  per device, alongside the known host-audio limitation. Hosted CI on
  that head passed 560 units (one existing skip) and all 35 enabled UI
  tests per device (four existing probe skips). All 21 existing review
  conversations are resolved; its Codex review still reports running.
  The PR #32 main refresh passed the same 560-unit native gate with one
  existing skip and an unchanged catalog; its new CI run remains required. The older AX5 audit finding remains unexplained. Auto-merge
  is disabled; the owner makes the merge decision. The
  PR #29's CI-artifact documentation is now merged from main `cc35c30`;
  its fresh local gate passed 560 units with the existing issue #19 skip
  and unchanged catalog. New-head CI remains pending.
  [reconciliation record](log/2026-10-22-library-reconciliation.md)
  preserves toolchain/device details, complete history and remaining checks.

- **GitHub CI** since PR #12 (merged 2026-10-21) builds with Apple's
  newest released Xcode, chosen on GitHub's `xcode-27` image (27.1,
  27A9275, on 2026-10-21), and tests on an iPad Pro 13-inch (M5)
  simulator on iOS 27.0, the only iOS runtime there
  ([`log/2026-10-21-toolchain.md`](log/2026-10-21-toolchain.md)). Since
  PR #13 the UI tests run on the newest iPad Pro 13-inch and then the
  newest standard iPhone, after a warm-up launch, and fail when no test
  ran ([`log/2026-10-21-test-seams.md`](log/2026-10-21-test-seams.md)).
  Since PR #28 each job keeps `build/TestResults` as a download on the
  run's page for 14 days, passed or failed, unless the job stopped
  before its tests started (a build failure leaves no bundle)
  ([`log/2026-10-22-ci-test-results.md`](log/2026-10-22-ci-test-results.md)).
  Before PR #12, CI used Xcode 26.6 and iOS 26.5; 10 of 11 runs on
  `9362eca` were green, and the failure was simulator infrastructure.
- **A Mac, 2026-10-21** (PR #13's diagnosis), iPhone 17 and iPad Pro
  13-inch (M5) simulators on iOS 27.0: 17 UI tests passed on each, with
  strict accessibility audits in light and dark, Home's controls
  reachable and in fixed frames at the default and AX5 text sizes, and
  the quick-control words read back whole from screenshots at AX5; 136
  unit tests passed
  ([`log/2026-10-21-ui-test-diagnosis.md`](log/2026-10-21-ui-test-diagnosis.md)).
- **The owner's Mac, 2026-10-12 to 2026-10-16**, Xcode 27.0, iOS 27.0
  simulators, run by agents: 113 unit cases and 8 UI tests green on an
  iPad Pro 13-inch (M5). The app was also run on iPad and iPhone 17
  simulators at the default and largest text sizes, which found the phone
  problems under *Known gaps* (docs/recon/2026-10-15/README.md, 2.1). No
  person has yet run the app and heard a phrase on record.
- **Physical devices: none.** See *Checks that need a real device*.
- **No test sees** VoiceOver announcements being posted, the message's
  scroll reset, the missed-callback watchdog on a real synthesizer (it is
  unit-tested with fakes), or sound. Windowed iPad
  sizes and iPhone Duo poses are untested. The first UI test on a
  just-started CI simulator failed intermittently before PR #13's warm-up
  launch (AGENTS.md, *Gotchas*). Apple's accessibility audit never sees
  Home's "Speaking" line: audits wait for speech to finish, because one
  that ran while the line left reported text with no element (issue #30,
  [`log/2026-10-22-audit-still-screen.md`](log/2026-10-22-audit-still-screen.md)).

## Known gaps

Each names who closes it: *(owner)*, the thread working on it, or the
release in docs/ROADMAP.md when no thread has it yet.

- Home's sizes are the stand-in's, not measured gaze, switch or touch
  floors per input profile, and the phrase grid still scrolls (invariant
  11) on small phone windows at large text sizes: docs/DECISIONS.md,
  "Home's stand-in layout", *Where the grid still scrolls*. Ending the
  scroll is R0 (ROADMAP item 3); measured sizes for each input profile are
  R1. *(the layout engine, a new thread)*
- The slot plan has no answer yet for more than four everyday categories
  (docs/DECISIONS.md, "Home's slot plan", *Open*): editing and import
  must not add a fifth until it does. *(the layout engine, a new thread)*
- Yes, No and Again border the message (12pt away), so a look resting on
  it can speak one of them. Reduced, not removed: with Again out of the
  message's row, about 61 to 67% of the message is nearest one of them,
  down from about 89 to 95% on phones. Recorded as an open hazard, not
  an accepted exception (docs/DECISIONS.md, "Home's slot plan" and
  "Settings on Home"): a device check (Snap to Item by nearest centre or
  nearest edge) decides whether placement can remove it, or its measured
  cost goes to the owner before a dwell, switch, head or gaze profile
  ships. *(the layout engine, a new thread; owner if it stays)*
- Home has no wells yet: Phrases, Type, Get Attention and Stop have no
  place on Home (docs/DECISIONS.md, "Home's slot plan"). Until Phrases and
  Type are built, Emergency stays at the safety row's trailing end, under
  Back to Talking, which `SettingsOnHomeTests` checks (docs/DECISIONS.md,
  "Settings on Home"). *(a new thread: Get Attention and Stop on Home)*
- A label with a word too wide for its slot even at the default text size
  is cut short with an ellipsis when it is one word, but in a phrase of
  several words that word can wrap mid-word. No starter label has one
  (`StarterLabelFitTests`), and nothing can add one until editing or
  import exists; those must keep every word within the narrowest tile, or
  the layout engine must give it room. *(Library editing and backup format,
  with the layout engine)*
- Settings' Back to Talking breaks "Talking" across two lines ("Talk-",
  "ing") on CI's iPhone at the largest text size, in the half of the bar
  it keeps beside Get Attention's place (seen in PR #33's captures; the
  same on the base branch). *(Settings, with the next accessibility pass)*
- The rendered-label test reads the four English quick-control labels
  only, not phrases or categories; `StarterLabelFitTests` measures every
  starter label against its narrowest slot instead. *(Accessibility
  coverage checklist)*
- The Get Attention alarm is built (`AttentionAlertPlayer`, in the
  environment) but not on screen, so `AudioSafetyPolicy` on Home runs with
  the alarm always idle, and the VoiceOver warning sentences mention it
  already. Get Attention and Stop go into Home's slots (docs/DECISIONS.md,
  "Home's slot plan" and "Get Attention"). *(a new thread)*
- The Get Attention tone is the reference app's placeholder; a
  harmonic-rich replacement and its level under speech need a listening
  check on a device (docs/DECISIONS.md, "Get Attention"). *(owner, with a
  device build)*
- No typing on Home. The typing rules (`MessageComposer`), the saved
  message (`DraftStore`) and a keyboard probe are in `Brickson/Typing`,
  waiting for Home's typing state (docs/DECISIONS.md, "Typing is a state
  of Home"; [`log/2026-10-21-typing-foundation.md`](log/2026-10-21-typing-foundation.md),
  *For the next typing thread*). *(a new typing thread, after Phone layout
  and word fitting)*
- No editing, export or import screens. The library core (`LibraryEdit`,
  `LibraryEditor`, `LibraryImport`, `BackupCodec`) is tested code that
  nothing calls yet. A Replace that would remove the person's own words
  is refused. A safety-copy exception is not adopted and requires the
  owner's decision before implementation (docs/DECISIONS.md, "Replacing
  the library"). *(R0, a new library thread)*
- `rollback()` crashes SwiftData after deletes, even without a cascade
  (issue #19, seen with Xcode 26.6 on iOS 26.5). Brickson never calls it;
  the reproduction is disabled and has not been run on the current Xcode
  27 CI. *(R0, a new library thread re-runs it once)*
- Settings' Get Attention place is empty: starting the alarm there before
  Home has Stop would leave it with no way to stop. It goes in with Get
  Attention and Stop on Home. On wide windows, Settings' root puts its
  note under that place, so adding Get Attention means scoring a look
  that reads the note (docs/DECISIONS.md, "Settings on Home"). Settings'
  sound line sits at the foot of the cover, where its nearest controls
  are the rows a screen has scrolled to its lower edge, some of which
  speak a sample or change a setting; the bar's redesign for Get
  Attention should give it a place whose neighbours do neither, without
  putting Back to Talking nearest Home's Settings (`SettingsOnHomeTests`).
  *(the thread that puts them on Home)*
- Chains of activations through Settings' screens are not fully scored.
  From Home's Settings, two steps are (modelled, in
  [`work/settings-on-home.md`](work/settings-on-home.md)):
  the first meets the root's Family Setup row everywhere CI runs; the
  second meets Back to Talking on wide windows by centre and on an iPad
  at the largest text size by both rules, which closes Settings onto
  Emergency. Placing Family Setup's own rows for it is the fix. A
  further one is known: a held look can follow Family Setup's first row into Set Up Step
  by Step and save Touch, its first answer, which is then nearest (it
  adds Touch and restarts the check-in clock; nothing reads the answers
  yet). Home's Settings button now starts that chain on a phone at the
  default text size. Another
  runs through iOS's Personal Voice question, once the Ask button shows:
  after answering, the look rests where the question's button was, over
  whatever Voice Settings has there. Answers
  change no size yet; scoring and a fix come before they do
  ([`log/2026-10-21-settings-and-first-run.md`](log/2026-10-21-settings-and-first-run.md),
  follow-up 10). *(Dwell-safety scoring)*
- English only. `scripts/test.sh unit` brings the String Catalog up to
  date (xcodebuild alone does not), and CI fails when the committed one
  is stale. The voice sample sentence in `SpeechService` is not in it
  yet (Voice Settings no longer shows `SpeechRateSteps`' rate names). *(Test seams and CI evidence)*
- No off-main test reaches the real KVO closure (the volume handler is
  called directly). The synthesizer and tone-player delegates, the
  Personal Voice answer (the closure handed to the system, built by
  `SystemPersonalVoice.forwardingAnswer`, and the answer awaited through
  `SpeechService`) and a session notice are tested from a background
  thread (docs/LESSONS.md). *(R0, item 4)*
- The audio session stays active after speech, so other apps' audio does
  not resume by itself. This is a decision, not an oversight
  (docs/DECISIONS.md, "Background audio"); `.releaseWhenIdle` waits on a
  device check. *(owner, with a device build)*
- If SwiftData cannot create even an in-memory library, the app stops
  (`fatalError` in `PhraseLibraryStore.openForApp`). *(owner)*
- `cloudKitDatabase: .none` and the absence of an iCloud capability are
  privacy-policy promises no test pins. *(Test seams and CI evidence)*
- Personal Voice permission is still asked at first launch without
  explanation. Voice Settings' explained Ask button is built
  (docs/DECISIONS.md, "Asking for Personal Voice from Voice Settings") but
  shows only under `.fromSettings`, which waits for device check D1; a
  debug build launched with `--personal-voice=ask-from-settings` is the
  build D1 needs. If D1 passes, the switch is the first line of
  `AppAudio.personalVoiceAskPolicy(for:)` ("Personal Voice permission is
  asked at launch, for now"). *(owner, with a device build; then an
  agent)*
- Words that get longer while Voice Settings is open still push what is
  below them down: the Personal Voice card going from ready to turned
  off (docs/DECISIONS.md, "Voice Settings keeps its places while it is
  open"). When Automatic moves to another Personal Voice
  because the kept one is gone, no line says so yet
  ([`log/2026-10-22-voice-screen.md`](log/2026-10-22-voice-screen.md),
  *Follow-ups*). *(the next Settings thread)*
- The privacy policy describes features not built yet; each is built or its
  sentence deleted before release (docs/APP-STORE.md, section 3, lists
  each sentence). *(App Store readiness and ASO)*
- The app icon is a placeholder; `design/brand/` is not installed. *(Release chores, R0 item 11)*
- Siri's alternative name "Brick Son" (`INAlternativeAppNames`) has no
  effect yet: Apple applies it only to apps with Siri support, which
  Brickson does not have (docs/DECISIONS.md, "App identity"). *(R2 Siri
  and Shortcuts)*
- No license file, so all rights are reserved; the bundle identifier
  contains the owner's first name and is permanent after the first upload. *(owner)*

## Next steps, in order

For the owner (everything else was decided on 2026-10-21 by default and
can be reversed; docs/DECISIONS.md):

1. Answer the few questions that are yours, in docs/DECISIONS.md,
   *Waiting on the owner*: the final name (and with it the bundle
   identifier), the price, how the name is said, the license, and your
   EU trader status (needed before the App Store release in the EU).
   Everything App Store Connect will ask, in order, is in
   [docs/APP-STORE.md](APP-STORE.md), section 1.
2. Run the app once yourself and hear a phrase ([local setup](GETTING_STARTED.md)).
3. Put your Team ID in `project.yml` (`DEVELOPMENT_TEAM`), then run the app
   on your iPhone and iPad and work through *Checks that need a real device*.
4. Review the starter phrases (`Brickson/Resources/StarterPhrases.json`): two
   are near duplicates, and "Please move me." could be clearer.
5. Delete the failed Swift configuration on the Tool status page
   (docs/DECISIONS.md, *Code scanning*).

For agents: R0 in [docs/ROADMAP.md](ROADMAP.md), in order; the owner's
long-term vision, the direction behind it, is its *Where this goes*.
Every change follows AGENTS.md, *Apple's current frameworks first*: the
legacy uses kept, and the moves still planned with who owns each, are in
docs/DECISIONS.md under that title
([`log/2026-10-23-current-frameworks.md`](log/2026-10-23-current-frameworks.md)).
The library core landed with PR #14, and the launch repair that keeps
Emergency working after it; the next library pull request starts from the
*Follow-ups* in [`log/2026-10-23-emergency-repair.md`](log/2026-10-23-emergency-repair.md),
in order (the rollback probe on the current Xcode, stores from every
schema version, safety copies, export and import, the editing screens). Calls (R0 item 8) wait for a device build. Files under
`.github/workflows` are committed by the owner (docs/SDLC.md, *Deploy*). The toolchain's follow-ups
(Xcode's recommended settings, iPhone Duo, iOS 27 APIs behind
`#available`) are in [`log/2026-10-21-toolchain.md`](log/2026-10-21-toolchain.md);
recheck the minimum iOS against its two rules whenever Apple's next major
release drops devices (docs/DECISIONS.md, "Minimum iOS, iPhone and
iPad").
The speech work's next pull request, Get Attention and Stop on Home
(building the wells of docs/DECISIONS.md, "Home's slot plan"), is described for a fresh thread in
[`log/2026-10-21-speech-and-get-attention.md`](log/2026-10-21-speech-and-get-attention.md),
*Follow-ups*. Voice Settings' explained Ask button is built; switching the app to
asking from Settings waits for device check D1, and what the Voice
screen still lacks is in
[`log/2026-10-22-voice-screen.md`](log/2026-10-22-voice-screen.md),
*Follow-ups*.
Every accessibility API in the map of Apple features by ALS stage has a
row in [`ACCESSIBILITY.md`](ACCESSIBILITY.md), with its release and
roadmap item; what each R0 item picks up from it, in order, is in
[`log/2026-10-21-accessibility-coverage.md`](log/2026-10-21-accessibility-coverage.md),
*Follow-ups*. Item 3's scan order, regions and Voice Control names are
done; what is left of item 3's list, in order, is in
[`log/2026-10-22-home-scan-order-and-names.md`](log/2026-10-22-home-scan-order-and-names.md),
*Follow-ups*.
The layout's next steps (the wells, then the engine with input
profiles) are in
[`log/2026-10-21-phone-layout.md`](log/2026-10-21-phone-layout.md).

## Checks that need a real device

Simulators cannot show these. Record each result in a `docs/log/` file
(device, OS version, settings, date) and summarise it here.

| Check | What it decides |
|---|---|
| Speech plays with the silent switch on, and after a phone call | Audio session handling (invariant 4) |
| A phrase cut off by a call shows "Stopped, Again" | The cut-off rule (code audit M1) |
| D1: with no question at launch, a Personal Voice allowed after a phrase has been spoken speaks in the next phrase, after a voice-list refresh, a rebuilt synthesizer or only a relaunch (docs/recon/2026-10-15/directions/onboarding-and-settings.md, 2.5). Run from Xcode with `--personal-voice=ask-from-settings` added to the scheme's arguments (Product > Scheme > Edit Scheme > Run > Arguments), and ask with Voice Settings' Ask to Use Personal Voice | Whether the app may switch to `PersonalVoiceAskPolicy.fromSettings` (docs/DECISIONS.md, "Personal Voice permission is asked at launch, for now") |
| In the same run: iOS's question appears over Voice Settings, which is still there after a wait of over 90 seconds; after Allow or Don't Allow the card shows the answer, "Answered. …" sits where the button was, nothing below the card moved, and Open Personal Voice Settings appears only after leaving and reopening Voice Settings | "Asking for Personal Voice from Voice Settings" |
| D4: Personal Voice access turned off in the Settings app while Brickson waits in the background; on return a phrase speaks in another voice, and turning access back on brings the Personal Voice back | "A Personal Voice is used only while it is allowed" |
| D5: with two Personal Voices, the order the system lists them in, and whether each keeps its identifier across a relaunch, a restore and Share Across Devices | "Automatic keeps the person's Personal Voice" |
| Personal Voice appears and is chosen once permission is given, and keeps speaking after the screen locks | Voice choice and when to ask |
| Opening Settings by a stray dwell, and leaving it by Back to Talking, lands on nothing that speaks or alarms (`SettingsOnHomeTests` scores it on the simulator's frames); the idle reset under real dwell | Settings' safety bar and root (docs/DECISIONS.md, "Settings is a cover with a fixed safety bar") |
| Guided Access and Assistive Access steps match the device, and Brickson works inside both | Family Setup's Keep Brickson Open guide |
| Open Personal Voice Settings and Open Dwell Control Settings open the right page | `AccessibilitySettings.openSettings(for:)` |
| Each input method reaches every control: touch, Voice Control, Switch Control, Full Keyboard Access, AssistiveTouch Dwell, head tracking, Eye Tracking | That standard buttons are the whole integration (invariant 1) |
| A Switch Control double activation does not make a phrase stutter | Repeat absorption (invariant 10) |
| How far Snap to Item jumps, and whether the pointer stays on an activated control or follows the gaze | Spacing and placement for dwell profiles |
| Whether Snap to Item and Dwell pick a target by its nearest centre or its nearest edge, and which control a look resting on the message selects | What removes "Yes, No and Again border the message" (docs/DECISIONS.md, "Settings on Home") |
| Whether a lingering look re-fires a dwell | How much repeat protection matters |
| Whether Snap to Item ignores controls scrolled off screen | Whether scrolling can keep family controls out of reach |
| What the real software keyboard covers in each orientation, and typing checks 1–8 in [`log/2026-10-21-typing-foundation.md`](log/2026-10-21-typing-foundation.md) | The typing layout (docs/LESSONS.md, "Test with the real software keyboard"), the word row, Return under dwell, and whether Brickson needs its own keyboard |
| Get Attention heard from the next room, on the speaker and over Bluetooth | The alarm's sound and level, and the replacement tone |
| A phrase spoken while Get Attention sounds is understood over the tone at 0.32 | `AttentionAlertStatus.toneVolumeWhileSpeaking` |
| A phone call, Siri and another app's alarm during a phrase and during Get Attention: each stops and shows "Stopped — Again" or "Alert stopped", and nothing restarts by itself, on iOS 26 and iOS 27 | Interruption handling and the iOS 27 notices (docs/DECISIONS.md, "Audio session notices") |
| Lock the device during a long phrase and while Get Attention sounds: both carry on | Background audio, before the App Review notes promise it |
| Whether a voice reports its final word before finishing, and whether the system reports a cut-off phrase as finished | How often "A phrase the system cuts off" relies on its 3-second window |
| Unplugging headphones during a phrase and during Get Attention | Output loss: speech carries on, the alarm stops and says so |
| Whether the tone player ever reads as not playing for a moment while it plays (route changes, Bluetooth) | Whether the once-a-second health check needs a second look before stopping the alarm |
| Comfortable dwell time and movement tolerance | Setup recommendations per profile |
| Whether Guided Access works together with Eye Tracking | Setup recommendations |
| Which phrases people reach for, and how many categories can be scanned by eye | The starter library |
| "Open Brickson" by Siri and Voice Control, said by a few people, and how VoiceOver reads the icon | `APP_SPOKEN_NAME` and the alternative names |
| With VoiceOver on, a cut-off phrase or very low volume is announced once, in full, without moving focus | Home's audio announcements (invariant 4) |
| A volume change made while Brickson was in the background shows when it returns | The volume warning (code audit L2) |
| Buttons under Increase Contrast and Reduce Transparency, measured on the rendered pixels | Contrast of system components (invariant 6) |
| The screen never dims or locks during a long session | `ScreenWakePolicy` (invariant 12) |
| On a folding iPhone, open and folded, and in Stage Manager, Slide Over and iPhone Mirroring windows: nothing safety-critical is hidden or split | Layouts from the space available |
| Eye Tracking and Dwell on an external display | Whether gaze profiles hold off the built-in screen |
| Switch Control with Auto Scanning, Group Items on and off, and Auto Tap: the scan steps to Emergency, Yes and No from every Home state, and whether Home's regions become scan groups | Scan order and grouping (docs/ACCESSIBILITY.md, section 1) |
| With VoiceOver, Switch Control (item and group scanning) and Full Keyboard Access, Home is reached as Yes, No, Emergency, Again, then the message, the categories and Settings, the phrases, in every state; what each says on entering a region; whether the cursor stops on the message or the status line; Voice Control's "Show names" shows each control's visible words and "Tap Repeat" presses Again | "Home's scan order and names": the order, unlabelled regions, and whether `accessibilityRespondsToUserInteraction` is needed |
| With VoiceOver on, a phrase tile with and without the `startsMediaSession` trait: does VoiceOver stay quiet while the phrase speaks | Whether phrase tiles carry the trait (R0 item 4) |
| Brickson inside Assistive Access with `UISupportsFullScreenInAssistiveAccess`: its window size, and whether Eye Tracking and Switch Control work there | Assistive Access support (R0 item 7) |
| Guided Access with each input method, and with a short Display Auto-Lock while Brickson keeps the screen awake | Setup advice, and invariant 12 under Guided Access |
| Which of the VoiceOver, Switch Control and AssistiveTouch flags each input method turns on | Profile suggestions (R1) |

## Repository, CI and website

- The `main` ruleset matched docs/DECISIONS.md on 2026-10-15 (GitHub's
  API); its required checks are "Unit tests" and "UI tests".
  The UI job now allows 75 minutes for both device families, and Home's
  layout test uses bounded live queries while retaining every tile's
  visibility and position checks. After incorporating `main` at `d79d836`,
  its audit helper also keeps issue-time captures and native XCTest
  findings. CI reported an unidentified AX5/light text-accessibility
  finding; the unchanged focused local test passed, but no cause is
  established. A temporary contrast defect failed as expected and retained
  issue-time and native evidence; its app mutation was removed. Final
  units passed 460/460; iPad and iPhone UI each passed 33 tests with four
  existing probe skips on the tree incorporating `d79d836`. A further
  merge incorporates `main` at `479175d` (PR #31): its still-screen waits
  and two runner tests remain alongside the diagnostic captures and native
  findings. Its unit gate passed 460/460 with the catalog unchanged;
  both combined UI suites completed with 34 passed, one failed and four
  existing skips per device. The AX5 light/dark Speaking waits failed,
  with the status visibly still present and CoreAudio startup errors in
  the iPad app logs. Focused local checks reproduced the known host-audio
  limitation. Exact-head CI on `f1f7954` passed 460 units and 35 enabled UI
  tests per device (four existing probe skips); the owner merged PR #32
  as `313de2c`. No host audio service or setting was changed.
  Earlier-head CI also failed, with its native audit evidence now retained
  ([`log/2026-10-22-ci-home-test.md`](log/2026-10-22-ci-home-test.md)).
- CodeQL scans the workflow files and the Python scripts, not the Swift
  code, on purpose (docs/DECISIONS.md, *Code scanning*); the failed Swift
  attempt of 2026-10-10 is still listed on the Tool status page.
- Codex reviews every push to a pull request, Copilot each pull request
  once when it opens, AI Scan each push; none reviews Dependabot's pull
  requests by itself. The AI credits they use show only in Settings →
  Billing → AI usage.
- The [website](https://middleagedbanana.github.io/Brickson/) and its
  [privacy policy](https://middleagedbanana.github.io/Brickson/privacy/)
  (Effective October 21, 2026, since PR #18) publish after each merge; on 2026-10-15 they
  matched `site/` byte for byte. The support page's "in development" lines
  change at release.

## History

Before 2026-10-21: [`docs/HANDOFF-LOG.md`](HANDOFF-LOG.md). Since: one file
per pull request in [`docs/log/`](log/README.md). The research behind the
roadmap: [`docs/recon/`](recon/README.md).
