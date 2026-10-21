# Handoff

The current state of Brickson and what to do next. **Start every session
here**, after `git status` and `git log --oneline -15`. Each pull request
edits this page in place and writes its record in [`docs/log/`](log/README.md);
nothing is appended here. Plan: [`docs/ROADMAP.md`](ROADMAP.md). How the
project runs: [`docs/SDLC.md`](SDLC.md).

**State as of 2026-10-21: `main` at `9362eca` (PR #11, merged 2026-10-14).**
Ten threads are working in parallel on the first release, R0.

## What the app does today

What it is written to do (*Verification* says how much has been seen). A
stand-in Home with Yes, No and Emergency, everyday categories, and tiles
from a neutral starter set. A tile speaks at once, in the person's
Personal Voice when one exists and is allowed; the sentence stays on screen
with Again beside it. Emergency opens the emergency phrases and says
nothing. Audio failures and very low volume show as a short passive
warning in space always kept for it, and VoiceOver announces them. If the
library cannot be saved, the app speaks from a filled in-memory library
and says changes will not be kept. The screen never locks. Ported code:
[`docs/PORTING.md`](PORTING.md).

## Verification

- **GitHub CI on `main` (`9362eca`)**: unit suite, website and script
  checks, and UI tests (Home, a first tap, Emergency, the accessibility
  audit) on Xcode 26.6 with an iPad Pro 13-inch simulator on iOS 26.5; 10
  of 11 runs on `main` green, the failure was simulator infrastructure.
  PR #12 moves CI to Apple's newest released Xcode.
- **The owner's Mac, 2026-10-12 to 2026-10-16**, Xcode 27.0, iOS 27.0
  simulators, run by agents: 113 unit cases and 8 UI tests green on an
  iPad Pro 13-inch (M5). The app was also run on iPad and iPhone 17
  simulators at the default and largest text sizes, which found the phone
  problems under *Known gaps* (docs/recon/2026-10-15/README.md, 2.1). No
  person has yet run the app and heard a phrase on record.
- **Physical devices: none.** See *Checks that need a real device*.
- **No test sees** VoiceOver announcements being posted, the message's
  scroll reset, the missed-callback watchdog, sound, an iPhone, any
  accessibility text size, or dark mode. The first UI test on a
  just-started CI simulator has failed intermittently (AGENTS.md, *Gotchas*).

## Known gaps

Each names who closes it: *(owner)*, the thread working on it, or the
release in docs/ROADMAP.md when no thread has it yet.

- Home's sizes are plain defaults, not measured gaze, switch or touch
  sizes, and the phrase grid scrolls (invariant 11). *(Phone layout and word fitting; R1)*
- On an iPhone at the default text size "Emergency" breaks mid-word, the
  category row scrolls sideways and hides categories, and the starter
  library scrolls; at the largest size the labels clip. *(Phone layout and word fitting)*
- No Get Attention alarm yet, so `AudioSafetyPolicy` runs with the alarm
  always idle, and the VoiceOver warning sentences mention it already. *(Speech engine and Get Attention)*
- A phrase the system cuts off can be recorded as finished, so no
  "Stopped, Again" appears (code audit M1). *(Speech engine and Get Attention)*
- No typing *(Typing foundation)*; no editing or backup *(Library editing
  and backup format)*; no Settings or voice choice *(Settings and first run)*.
- A library the app cannot read is replaced by the starter phrases with a
  message about saving (code audit M2), and an emptied library is refilled
  with the starter set. *(Library editing and backup format)*
- English only. The committed String Catalog has no entries; the
  speech-rate names in `SpeechRateSteps` and the voice sample sentence in
  `SpeechService` are not localizable. *(Test seams and CI evidence)*
- No off-main test reaches the real KVO closure, the Personal Voice
  completion or the synthesizer delegate, and with no seam over the
  synthesizer the watchdog is untested. *(Speech engine and Get Attention)*
- The audio session stays active after speech, so other apps' audio does
  not resume by itself (docs/DECISIONS.md, "Background audio"). *(owner, with the alarm)*
- If SwiftData cannot create even an in-memory library, the app stops
  (`fatalError` in `PhraseLibraryStore.openForApp`). *(owner)*
- `cloudKitDatabase: .none` and the absence of an iCloud capability are
  privacy-policy promises no test pins. *(Test seams and CI evidence)*
- No Privacy row in the app, which App Review requires, and Personal Voice
  permission is asked at first launch without explanation. *(Settings and first run)*
- The privacy policy describes features not built yet; each is built or its
  sentence deleted before release. *(App Store readiness and ASO)*
- The app icon is a placeholder; `design/brand/` is not installed. *(Figma and Claude Design screens)*
- No license file, so all rights are reserved; the bundle identifier
  contains the owner's first name and is permanent after the first upload. *(owner)*

## Next steps, in order

For the owner (the decisions are listed, with recommendations, in
docs/DECISIONS.md, *Proposed decisions*):

1. Answer the open decisions, starting with the minimum iOS version (asked
   on 2026-10-21; it stays 26.0 until then) and the bundle identifier.
2. Run the app once yourself and hear a phrase ([local setup](GETTING_STARTED.md)).
3. Put your Team ID in `project.yml` (`DEVELOPMENT_TEAM`), then run the app
   on your iPhone and iPad and work through *Checks that need a real device*.
4. Review the starter phrases (`Brickson/Resources/StarterPhrases.json`): two
   are near duplicates, and "Please move me." could be clearer.
5. Delete the failed Swift configuration on the Tool status page
   (docs/DECISIONS.md, *Code scanning*).

For agents: R0 in [docs/ROADMAP.md](ROADMAP.md), in order. Calls (R0 item
8) wait for a device build. Files under `.github/workflows` are committed
by the owner (docs/SDLC.md, *Deploy*).

## Checks that need a real device

Simulators cannot show these. Record each result in a `docs/log/` file
(device, OS version, settings, date) and summarise it here.

| Check | What it decides |
|---|---|
| Speech plays with the silent switch on, and after a phone call | Audio session handling (invariant 4) |
| A phrase cut off by a call shows "Stopped, Again" | The cut-off rule (code audit M1) |
| Personal Voice appears and is chosen once permission is given, and keeps speaking after the screen locks | Voice choice and when to ask |
| Each input method reaches every control: touch, Voice Control, Switch Control, Full Keyboard Access, AssistiveTouch Dwell, head tracking, Eye Tracking | That standard buttons are the whole integration (invariant 1) |
| A Switch Control double activation does not make a phrase stutter | Repeat absorption (invariant 10) |
| How far Snap to Item jumps, and whether the pointer stays on an activated control or follows the gaze | Spacing and placement for dwell profiles |
| Whether a lingering look re-fires a dwell | How much repeat protection matters |
| Whether Snap to Item ignores controls scrolled off screen | Whether scrolling can keep family controls out of reach |
| What the real software keyboard covers in each orientation | The typing layout (docs/LESSONS.md, "Test with the real software keyboard") |
| Get Attention heard from the next room, on the speaker and over Bluetooth | The alarm's sound and level (once built) |
| Comfortable dwell time and movement tolerance | Setup recommendations per profile |
| Whether Guided Access works together with Eye Tracking | Setup recommendations |
| Which phrases people reach for, and how many categories can be scanned by eye | The starter library |
| "Open Brickson" by Siri and Voice Control, said by a few people, and how VoiceOver reads the icon | `APP_SPOKEN_NAME` and the alternative names |
| With VoiceOver on, a cut-off phrase or very low volume is announced once, in full, without moving focus | Home's audio announcements (invariant 4) |
| A volume change made while Brickson was in the background shows when it returns | The volume warning (code audit L2) |
| Buttons under Increase Contrast and Reduce Transparency, measured on the rendered pixels | Contrast of system components (invariant 6) |
| The screen never dims or locks during a long session | `ScreenWakePolicy` (invariant 12) |

## Repository, CI and website

- The `main` ruleset matched docs/DECISIONS.md on 2026-10-15 (GitHub's
  API); its required checks are "Unit tests" and "UI tests".
- CodeQL scans the workflow files and the Python scripts, not the Swift
  code, on purpose (docs/DECISIONS.md, *Code scanning*); the failed Swift
  attempt of 2026-10-10 is still listed on the Tool status page.
- Codex reviews every push to a pull request, Copilot each pull request
  once when it opens, AI Scan each push; none reviews Dependabot's pull
  requests by itself. The AI credits they use show only in Settings →
  Billing → AI usage.
- The [website](https://middleagedbanana.github.io/Brickson/) and its
  [privacy policy](https://middleagedbanana.github.io/Brickson/privacy/)
  (Effective October 12, 2026) publish after each merge; on 2026-10-15 they
  matched `site/` byte for byte. The support page's "in development" lines
  change at release.

## History

Before 2026-10-21: [`docs/HANDOFF-LOG.md`](HANDOFF-LOG.md). Since: one file
per pull request in [`docs/log/`](log/README.md). The research behind the
roadmap: [`docs/recon/`](recon/README.md).
