# Handoff

The current state of Brickson and what to do next. **Start every working
session here**, after `git status` and `git log --oneline -15`. Update this
file at the end of every session (AGENTS.md, "Document every change").

## State on 2026-10-10: the starting files

The first pull request (branch `claude/new-app-scaffold-op8g1g`) adds the
project, the foundations ported from the reference app, a stand-in Home
screen, tests, CI and these documents.

### What the app does today

It opens on a Home screen with Yes, No and Emergency, a row of categories,
and phrase tiles from a neutral starter set. Choosing a tile speaks it at
once; the sentence stays on screen with Again beside it. Emergency switches
to the emergency phrases and says nothing itself. If audio fails, the volume
is very low, or the library cannot be saved, a passive warning appears at
the bottom.

### What came over from the reference app

See `docs/PORTING.md` → *Ported so far*. In short: the speech engine
(survives the silent switch, interruptions and media-services resets;
Personal Voice preferred; repeat absorption on `ContinuousClock`), audio
safety warnings, the screen-wake policy, and the phrase models, now in a
versioned schema without cascade deletes.

### Verification

- **Written on a cloud machine that cannot compile Swift.** Nothing was
  built or run where it was written.
- **GitHub CI** (`.github/workflows/tests.yml`) builds the app and runs
  the unit and UI tests on GitHub's Mac machines for every pull request.
  The result for this first pull request is recorded on the pull request
  itself; until the owner has run it on a Mac, treat CI as the only
  evidence.
- **No physical-device evidence of any kind.** See *Checks that need a
  real device* below.

### Known gaps in this first version

- Home's sizes are plain defaults, not measured gaze, switch or touch
  sizes, and the phrase grid scrolls. Fine for a stand-in, not for a
  release (invariant 11).
- No Get Attention alarm yet, so `AudioSafetyPolicy` runs with the alarm
  always idle.
- No typing, editing, Settings, voice choice or backup.
- Personal Voice permission is asked at first launch without explanation
  (docs/DECISIONS.md).
- English only; the String Catalog fills itself as Xcode builds.
- The app icon is a placeholder (a white speech bubble on blue).
- No license file: the code is public but, without a license, all rights
  are reserved. The owner decides.

## Next steps, in order

1. **Owner:** open and run the app on a Mac (README → *First time on your
   Mac*), and run the tests once (⌘U).
2. **Owner:** review the starter phrases
   (`Brickson/Resources/StarterPhrases.json`).
3. **Owner:** choose the developer account (personal or organization).
   Then set `DEVELOPMENT_TEAM` and the final `APP_BUNDLE_ID` in
   `project.yml` (docs/DECISIONS.md, "App identity").
4. Port step 1's remainder: the Get Attention alarm (`AttentionAlertPlayer`
   and its tone) with Stop Alert in a different place, and the audio
   warning strip.
5. Port step 2: editing logic and backup, with a failure-injection test for
   every save (docs/LESSONS.md, "Never roll back a cascade delete").
6. Port step 3, then design the generalized layout engine (step 4) before
   replacing Home.

## Checks that need a real device

Simulator runs cannot show any of these. Record each result here with the
device, OS version, settings and date.

| Check | What it decides |
|---|---|
| Speech plays with the silent switch on, and after a phone call | Audio session handling (invariant 4) |
| Personal Voice appears and is chosen once permission is given | Voice choice and when to ask for permission |
| Each input method reaches every control: touch, Voice Control, Switch Control, Full Keyboard Access, AssistiveTouch Dwell, head tracking, Eye Tracking | That standard buttons are the whole integration (invariant 1) |
| How far Snap to Item jumps, and whether the pointer stays on an activated control or follows the gaze | Spacing and placement for dwell profiles |
| Whether a lingering look re-fires a dwell | How much repeat protection matters |
| Whether Snap to Item ignores controls scrolled off screen | Whether scrolling can keep family controls out of reach |
| What the real software keyboard covers in each orientation | The typing layout (docs/LESSONS.md, "Test with the real software keyboard") |
| Get Attention heard from the next room, on the speaker and over Bluetooth | The alarm's sound and level (once ported) |
| Comfortable dwell time and movement tolerance | Setup recommendations per profile |
| Whether Guided Access works together with Eye Tracking | Setup recommendations |
| Which phrases people reach for, and how many categories can be scanned by eye | The starter library |

## Record of changes

| Date | Commit | Change | Verified by |
|---|---|---|---|
| 2026-10-10 | *(this pull request)* | Starting files: project, speech, storage, stand-in Home, tests, CI, docs | GitHub CI only |
